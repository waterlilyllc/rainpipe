#!/usr/bin/env ruby
# Test: Migration for keyword_pdf_progress_logs table
#
# 目的: keyword_pdf_progress_logs テーブル作成マイグレーションをテストする
#       このテーブルは PDF 生成中の段階的な進捗ログを記録する。

require 'sqlite3'
require 'tempfile'
require 'fileutils'
require 'minitest/autorun'

class TestMigrateKeywordPdfProgressLogs < Minitest::Test
  def setup
    # 一時データベースを作成
    @tempfile = Tempfile.new('test_rainpipe.db')
    @db_path = @tempfile.path
    @tempfile.close
    FileUtils.rm(@db_path) if File.exist?(@db_path)

    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true

    # テストデータ用の keyword_pdf_generations テーブルを先に作成
    create_keyword_pdf_generations_table
  end

  def teardown
    @db.close
    FileUtils.rm(@db_path) if File.exist?(@db_path)
  end

  def create_keyword_pdf_generations_table
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS keyword_pdf_generations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE NOT NULL,
        keywords TEXT NOT NULL,
        date_range_start DATE NOT NULL,
        date_range_end DATE NOT NULL,
        bookmark_count INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        pdf_path TEXT,
        kindle_email TEXT,
        error_message TEXT,
        gpt_overall_summary_duration_ms INTEGER,
        gpt_analysis_duration_ms INTEGER,
        gpt_keyword_extraction_duration_ms INTEGER,
        gatherly_fetch_duration_ms INTEGER,
        pdf_render_duration_ms INTEGER,
        total_duration_ms INTEGER,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL,
        CONSTRAINT date_range_check CHECK (date_range_start <= date_range_end)
      );
    SQL
  end

  def test_table_not_exists_before_migration
    # 初期状態ではテーブルが存在しないことを確認
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_progress_logs'")
    assert_empty(tables, "Table should not exist before migration")
  end

  def test_migration_creates_table_with_correct_schema
    # マイグレーション実行
    run_migration_up

    # テーブルが存在することを確認
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_progress_logs'")
    assert_equal(1, tables.length, "Table should be created")

    # スキーマを確認
    schema = @db.execute("PRAGMA table_info(keyword_pdf_progress_logs)")
    column_names = schema.map { |col| col['name'] }

    # 必須カラムの存在確認
    assert_includes(column_names, 'id', "Should have id column")
    assert_includes(column_names, 'job_id', "Should have job_id column")
    assert_includes(column_names, 'stage', "Should have stage column")
    assert_includes(column_names, 'event_type', "Should have event_type column")
    assert_includes(column_names, 'percentage', "Should have percentage column")
    assert_includes(column_names, 'message', "Should have message column")
    assert_includes(column_names, 'details', "Should have details column")
    assert_includes(column_names, 'timestamp', "Should have timestamp column")
  end

  def test_job_id_is_foreign_key_to_keyword_pdf_generations
    run_migration_up

    # FK 制約を確認（SQLite では PRAGMA foreign_key_list で確認可能）
    constraints = @db.execute("PRAGMA foreign_key_list(keyword_pdf_progress_logs)")

    # FK があることを確認
    assert(constraints.any? { |c| c['from'] == 'job_id' && c['table'] == 'keyword_pdf_generations' },
           "job_id should be foreign key to keyword_pdf_generations")
  end

  def test_stage_enum_constraint
    run_migration_up

    # テーブルに INSERT を試みて制約をテスト
    @db.execute("INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, created_at, updated_at)
                  VALUES (?, ?, ?, ?, ?, ?, ?)",
                ['test-uuid', 'keyword', '2025-01-01', '2025-01-31', 10, Time.now.to_s, Time.now.to_s])

    test_job_id = @db.execute("SELECT uuid FROM keyword_pdf_generations LIMIT 1")[0]['uuid']

    # 有効なステージで INSERT 成功
    valid_stages = ['filtering', 'content_fetching', 'summarization', 'pdf_generation', 'email_sending', 'event']
    valid_stages.each do |stage|
      begin
        @db.execute("INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, message, timestamp)
                     VALUES (?, ?, ?, ?, ?)",
                    [test_job_id, stage, 'stage_update', "Test message for #{stage}", Time.now.to_s])
      rescue => e
        flunk("Should be able to insert valid stage '#{stage}': #{e.message}")
      end
    end

    # 無効なステージで INSERT 失敗（制約エラー）
    assert_raises(SQLite3::ConstraintException) do
      @db.execute("INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, message, timestamp)
                   VALUES (?, ?, ?, ?, ?)",
                  [test_job_id, 'invalid_stage', 'stage_update', 'Invalid stage', Time.now.to_s])
    end
  end

  def test_event_type_enum_constraint
    run_migration_up

    # テストデータ準備
    @db.execute("INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, created_at, updated_at)
                  VALUES (?, ?, ?, ?, ?, ?, ?)",
                ['test-uuid', 'keyword', '2025-01-01', '2025-01-31', 10, Time.now.to_s, Time.now.to_s])
    test_job_id = @db.execute("SELECT uuid FROM keyword_pdf_generations LIMIT 1")[0]['uuid']

    # 有効なイベントタイプで INSERT 成功
    valid_types = ['stage_update', 'retry', 'warning', 'info', 'error']
    valid_types.each do |event_type|
      begin
        @db.execute("INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, message, timestamp)
                     VALUES (?, ?, ?, ?, ?)",
                    [test_job_id, 'filtering', event_type, "Test message for #{event_type}", Time.now.to_s])
      rescue => e
        flunk("Should be able to insert valid event_type '#{event_type}': #{e.message}")
      end
    end

    # 無効なイベントタイプで INSERT 失敗
    assert_raises(SQLite3::ConstraintException) do
      @db.execute("INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, message, timestamp)
                   VALUES (?, ?, ?, ?, ?)",
                  [test_job_id, 'filtering', 'invalid_type', 'Invalid type', Time.now.to_s])
    end
  end

  def test_indexes_created
    run_migration_up

    # インデックスの存在確認
    indexes = @db.execute("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='keyword_pdf_progress_logs'")
    index_names = indexes.map { |idx| idx['name'] }

    # 必須インデックスの確認
    assert(index_names.any? { |name| name.include?('job_id') }, "Should have index on job_id")
    assert(index_names.any? { |name| name.include?('timestamp') }, "Should have index on timestamp")
  end

  def test_timestamp_default_value
    run_migration_up

    # テストデータ準備
    @db.execute("INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, created_at, updated_at)
                  VALUES (?, ?, ?, ?, ?, ?, ?)",
                ['test-uuid', 'keyword', '2025-01-01', '2025-01-31', 10, Time.now.to_s, Time.now.to_s])
    test_job_id = @db.execute("SELECT uuid FROM keyword_pdf_generations LIMIT 1")[0]['uuid']

    # timestamp を指定しない INSERT
    @db.execute("INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, message)
                 VALUES (?, ?, ?, ?)",
                [test_job_id, 'filtering', 'stage_update', 'Test message'])

    # デフォルト値が設定されていることを確認
    result = @db.execute("SELECT timestamp FROM keyword_pdf_progress_logs LIMIT 1")
    assert(result[0]['timestamp'], "Timestamp should have default value")
  end

  def test_migration_rollback
    # UP を実行
    run_migration_up

    # テーブルが存在することを確認
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_progress_logs'")
    assert_equal(1, tables.length)

    # DOWN を実行
    run_migration_down

    # テーブルが削除されたことを確認
    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_progress_logs'")
    assert_empty(tables, "Table should be deleted after rollback")
  end

  private

  def run_migration_up
    # マイグレーションコードを実行
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS keyword_pdf_progress_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        job_id TEXT NOT NULL,
        stage TEXT NOT NULL,
        event_type TEXT DEFAULT 'stage_update',
        percentage INTEGER,
        message TEXT NOT NULL,
        details JSON,
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,

        FOREIGN KEY (job_id) REFERENCES keyword_pdf_generations(uuid),
        CONSTRAINT stage_enum CHECK (stage IN ('filtering', 'content_fetching', 'summarization', 'pdf_generation', 'email_sending', 'event')),
        CONSTRAINT event_enum CHECK (event_type IN ('stage_update', 'retry', 'warning', 'info', 'error'))
      );
    SQL

    @db.execute "CREATE INDEX IF NOT EXISTS idx_keyword_pdf_progress_logs_job_id ON keyword_pdf_progress_logs(job_id, timestamp DESC);"
    @db.execute "CREATE INDEX IF NOT EXISTS idx_keyword_pdf_progress_logs_timestamp ON keyword_pdf_progress_logs(timestamp DESC);"
  end

  def run_migration_down
    @db.execute "DROP TABLE IF EXISTS keyword_pdf_progress_logs;"
  end
end
