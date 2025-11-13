#!/usr/bin/env ruby
require 'sqlite3'
require 'fileutils'

# minitest プラグインをスキップ
ENV['RAILS_ENV'] = nil
require 'minitest/autorun'

# 対象のファイルを require
require_relative 'migrate_add_keyword_pdf_generations'

class TestMigrateKeywordPdfGenerations < Minitest::Test
  TEST_DB_PATH = File.join(File.dirname(__FILE__), 'test_rainpipe.db')

  def setup
    # テスト用DBを削除して初期化
    File.delete(TEST_DB_PATH) if File.exist?(TEST_DB_PATH)
    @db = SQLite3::Database.new(TEST_DB_PATH)
  end

  def teardown
    @db.close if @db
    File.delete(TEST_DB_PATH) if File.exist?(TEST_DB_PATH)
  end

  # テスト 1: keyword_pdf_generations テーブルが存在することを確認
  def test_table_exists
    Migration.new(@db).up

    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_generations';")
    assert_equal 1, tables.length, "keyword_pdf_generations テーブルが存在すること"
  end

  # テスト 2: 必須カラムが存在することを確認
  def test_required_columns_exist
    Migration.new(@db).up

    columns = @db.execute("PRAGMA table_info(keyword_pdf_generations);").map { |col| col[1] }

    required_columns = [
      'id', 'uuid', 'keywords', 'date_range_start', 'date_range_end',
      'bookmark_count', 'status', 'pdf_path', 'kindle_email', 'error_message',
      'gpt_overall_summary_duration_ms', 'gpt_analysis_duration_ms',
      'gpt_keyword_extraction_duration_ms', 'gatherly_fetch_duration_ms',
      'pdf_render_duration_ms', 'total_duration_ms', 'created_at', 'updated_at'
    ]

    required_columns.each do |col|
      assert columns.include?(col), "#{col} カラムが存在すること"
    end
  end

  # テスト 3: uuid カラムが UNIQUE 制約を持つこと
  def test_uuid_unique_constraint
    Migration.new(@db).up

    # 最初のレコードを挿入
    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      ['test-uuid-1', 'Claude', '2025-11-01', '2025-11-13', 10, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
    )

    # 同じ uuid で2番目のレコードを挿入しようとする → 失敗すべき
    assert_raises SQLite3::ConstraintException do
      @db.execute(
        "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ['test-uuid-1', 'AI', '2025-11-01', '2025-11-13', 5, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
      )
    end
  end

  # テスト 4: 日付範囲の制約 (start <= end) が機能すること
  def test_date_range_constraint
    Migration.new(@db).up

    # 無効な日付範囲を挿入 (start > end)
    assert_raises SQLite3::ConstraintException do
      @db.execute(
        "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ['test-uuid-invalid', 'Test', '2025-11-13', '2025-11-01', 10, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
      )
    end
  end

  # テスト 5: status のデフォルト値が 'pending' であること
  def test_status_default_value
    Migration.new(@db).up

    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      ['test-uuid-default', 'Test', '2025-11-01', '2025-11-13', 5, Time.now.utc.iso8601, Time.now.utc.iso8601]
    )

    result = @db.execute("SELECT status FROM keyword_pdf_generations WHERE uuid = 'test-uuid-default';")
    assert_equal 'pending', result[0][0], "status のデフォルト値が 'pending' であること"
  end

  # テスト 6: インデックスが作成されていること
  def test_indexes_exist
    Migration.new(@db).up

    indexes = @db.execute("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='keyword_pdf_generations';").map { |idx| idx[0] }

    assert indexes.include?('idx_keyword_pdf_generations_created_at'), "created_at インデックスが存在すること"
    assert indexes.include?('idx_keyword_pdf_generations_status'), "status インデックスが存在すること"
  end

  # テスト 7: ロールバック機能が動作すること
  def test_rollback_drops_table
    Migration.new(@db).up

    # テーブルが存在することを確認
    tables_before = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_generations';")
    assert_equal 1, tables_before.length

    # ロールバック
    Migration.new(@db).down

    # テーブルが削除されていることを確認
    tables_after = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_generations';")
    assert_equal 0, tables_after.length, "ロールバック後にテーブルが削除されていること"
  end

  # テスト 8: 複数行の挿入が正常に動作すること
  def test_multiple_inserts
    Migration.new(@db).up

    3.times do |i|
      @db.execute(
        "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ["uuid-#{i}", "Keyword#{i}", '2025-11-01', '2025-11-13', 10 + i, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
      )
    end

    count = @db.execute("SELECT COUNT(*) FROM keyword_pdf_generations;")
    assert_equal 3, count[0][0], "3行のレコードが正常に挿入されていること"
  end
end
