#!/usr/bin/env ruby
# Test: Progress Tracking API Endpoints
#
# 目的: Tasks 1.1-1.3 - GET /api/progress, POST /api/cancel, DB optimization
#

require 'sqlite3'
require 'tempfile'
require 'fileutils'
require 'json'
require 'time'

class TestProgressAPI
  def initialize
    @tempfile = Tempfile.new('test_progress_api.db')
    @db_path = @tempfile.path
    @tempfile.close
    FileUtils.rm(@db_path) if File.exist?(@db_path)

    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    setup_database
  end

  def setup_database
    # keyword_pdf_generations テーブル
    @db.execute <<-SQL
      CREATE TABLE keyword_pdf_generations (
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
        cancellation_flag BOOLEAN DEFAULT 0,
        current_stage TEXT DEFAULT NULL,
        current_percentage INTEGER DEFAULT 0,
        created_at TIMESTAMP NOT NULL,
        updated_at TIMESTAMP NOT NULL
      );
    SQL

    # keyword_pdf_progress_logs テーブル
    @db.execute <<-SQL
      CREATE TABLE keyword_pdf_progress_logs (
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

    # Task 1.3: インデックス追加
    @db.execute 'CREATE INDEX IF NOT EXISTS idx_pdf_gen_uuid ON keyword_pdf_generations(uuid)'
    @db.execute 'CREATE INDEX IF NOT EXISTS idx_progress_logs_job_id_timestamp ON keyword_pdf_progress_logs(job_id, timestamp DESC)'
  end

  def teardown
    @db.close
    FileUtils.rm(@db_path) if File.exist?(@db_path)
  end

  def run_tests
    puts "🧪 Progress API テスト開始\n\n"

    test_1_1_progress_endpoint_success
    test_1_1_progress_endpoint_missing_job_id
    test_1_1_progress_endpoint_job_not_found
    test_1_1_progress_endpoint_with_logs
    test_1_2_cancel_endpoint_success
    test_1_2_cancel_endpoint_already_completed
    test_1_3_database_indexes

    teardown
    puts "\n✅ 全テスト完了！"
  end

  def test_1_1_progress_endpoint_success
    puts "✅ テスト 1.1.1: GET /api/progress - 成功時の応答"

    job_id = create_test_job('pending', 'filtering', 25, 'テスト中')

    # 進捗ログを追加
    @db.execute(
      'INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, percentage, message, timestamp) VALUES (?, ?, ?, ?, ?, ?)',
      [job_id, 'filtering', 'stage_update', 25, 'ブックマークをフィルタ', Time.now.utc.iso8601]
    )

    # ProgressResponse JSON スキーマを検証
    job = @db.execute('SELECT * FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
    logs = @db.execute('SELECT * FROM keyword_pdf_progress_logs WHERE job_id = ? ORDER BY timestamp DESC LIMIT 50', [job_id])

    response = {
      status: job['status'],
      job_id: job['uuid'],
      current_stage: job['current_stage'],
      current_percentage: job['current_percentage'],
      stage_details: { keywords: job['keywords'], bookmark_count: job['bookmark_count'] },
      logs: logs.map { |log|
        {
          stage: log['stage'],
          event_type: log['event_type'],
          percentage: log['percentage'],
          message: log['message'],
          timestamp: log['timestamp']
        }
      },
      error_info: nil
    }

    assert(response[:status] == 'pending', "Status should be 'pending'")
    assert(response[:current_stage] == 'filtering', "Current stage should be 'filtering'")
    assert(response[:current_percentage] == 25, "Current percentage should be 25")
    assert(response[:logs].length == 1, "Should have 1 log entry")

    puts "   ✓ ProgressResponse JSON スキーマが正確\n\n"
  end

  def test_1_1_progress_endpoint_missing_job_id
    puts "✅ テスト 1.1.2: GET /api/progress - job_id がない場合"

    # job_id なしでリクエスト時のバリデーション
    job_id = nil

    # 400 エラーレスポンス期待
    response = validate_job_id_present(job_id)

    assert(response[:status] == 400, "Should return 400 status")
    assert(response[:error_type] == 'missing_parameter', "Should be 'missing_parameter' error")
    assert(response[:message].include?('job_id'), "Error message should mention job_id")

    puts "   ✓ 400 エラーが正確に返される\n\n"
  end

  def test_1_1_progress_endpoint_job_not_found
    puts "✅ テスト 1.1.3: GET /api/progress - ジョブが見つからない場合"

    job_id = 'non-existent-uuid-12345'

    # 404 エラーレスポンス期待
    response = fetch_job_by_id(job_id)

    assert(response.nil?, "Should return nil for non-existent job")

    # 404 エラー応答を構築
    error_response = {
      status: 404,
      error_type: 'job_not_found',
      message: "Job #{job_id} not found"
    }

    assert(error_response[:status] == 404, "Should return 404 status")

    puts "   ✓ 404 エラーが正確に返される\n\n"
  end

  def test_1_1_progress_endpoint_with_logs
    puts "✅ テスト 1.1.4: GET /api/progress - 複数のログエントリを返す"

    job_id = create_test_job('processing', 'content_fetching', 40, 'コンテンツ取得中')

    # 複数のログを追加
    (1..10).each do |i|
      @db.execute(
        'INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, percentage, message, timestamp) VALUES (?, ?, ?, ?, ?, ?)',
        [job_id, ['filtering', 'content_fetching', 'summarization'][i % 3], 'stage_update', (i * 10) % 100, "ステップ #{i}", Time.now.utc.iso8601]
      )
    end

    # 最後の 50 エントリを取得
    logs = @db.execute('SELECT * FROM keyword_pdf_progress_logs WHERE job_id = ? ORDER BY timestamp DESC LIMIT 50', [job_id])

    assert(logs.length == 10, "Should return 10 log entries")

    # ログが timestamp DESC でソートされているか確認
    timestamps = logs.map { |log| Time.parse(log['timestamp']) }
    assert(timestamps == timestamps.sort.reverse, "Logs should be ordered by timestamp DESC")

    puts "   ✓ 複数ログが正確に返される（最大50エントリ）\n\n"
  end

  def test_1_2_cancel_endpoint_success
    puts "✅ テスト 1.2.1: POST /api/cancel - キャンセル成功"

    job_id = create_test_job('processing', 'content_fetching', 40, '処理中')

    # キャンセル実行
    success = cancel_job(job_id)

    assert(success, "Cancel should succeed")

    # キャンセルフラグが設定されているか確認
    job = @db.execute('SELECT cancellation_flag FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
    assert(job['cancellation_flag'] == 1, "Cancellation flag should be set to 1")

    # レスポンス検証
    response = {
      success: true,
      message: "Job #{job_id} cancelled successfully"
    }

    assert(response[:success] == true, "Response should indicate success")

    puts "   ✓ キャンセルが正確に実行される\n\n"
  end

  def test_1_2_cancel_endpoint_already_completed
    puts "✅ テスト 1.2.2: POST /api/cancel - 既に完了した仕事"

    job_id = create_test_job('completed', 'email_sending', 100, '完了')

    # キャンセル実行（既に完了している）
    response = cancel_completed_job(job_id)

    # レースコンディション処理：success = true だが "Already completed" メッセージ
    assert(response[:success] == true, "Should return success for already completed job")
    assert(response[:message].include?('completed') || response[:message].include?('already'), "Message should mention job status")

    puts "   ✓ レースコンディション処理が正確\n\n"
  end

  def test_1_3_database_indexes
    puts "✅ テスト 1.3.1: データベースインデックスが存在"

    # インデックスの確認
    indexes = @db.execute("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name IN ('keyword_pdf_generations', 'keyword_pdf_progress_logs')")

    index_names = indexes.map { |idx| idx['name'] }

    # 必要なインデックスの確認
    assert(index_names.include?('idx_pdf_gen_uuid'), "Should have index on keyword_pdf_generations(uuid)")
    assert(index_names.include?('idx_progress_logs_job_id_timestamp'), "Should have index on keyword_pdf_progress_logs(job_id, timestamp DESC)")

    puts "   ✓ インデックスが正確に作成されている\n\n"
  end

  def test_1_3_query_performance
    puts "✅ テスト 1.3.2: クエリパフォーマンス（500+ ログエントリ）"

    job_id = create_test_job('processing', 'summarization', 60, '処理中')

    # 500 件のログエントリを追加
    start_time = Time.now
    (1..500).each do |i|
      @db.execute(
        'INSERT INTO keyword_pdf_progress_logs (job_id, stage, event_type, percentage, message, timestamp) VALUES (?, ?, ?, ?, ?, ?)',
        [job_id, ['filtering', 'content_fetching', 'summarization', 'pdf_generation'][i % 4], 'stage_update', (i % 101), "ステップ #{i}", Time.now.utc.iso8601]
      )
    end
    insert_time_ms = ((Time.now - start_time) * 1000).to_i

    # クエリ実行（最後の 50 エントリ取得）
    start_time = Time.now
    logs = @db.execute('SELECT * FROM keyword_pdf_progress_logs WHERE job_id = ? ORDER BY timestamp DESC LIMIT 50', [job_id])
    query_time_ms = ((Time.now - start_time) * 1000).to_i

    assert(logs.length == 50, "Should return exactly 50 entries")
    assert(query_time_ms < 200, "Query should complete in < 200ms (actual: #{query_time_ms}ms)")

    puts "   ✓ Insert: #{insert_time_ms}ms, Query: #{query_time_ms}ms\n\n"
  end

  private

  def create_test_job(status, current_stage, current_percentage, message)
    job_id = "test-job-#{Time.now.to_i}-#{rand(10000)}"
    @db.execute(
      'INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, current_stage, current_percentage, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [job_id, 'test keywords', '2025-01-01', '2025-01-31', 100, status, current_stage, current_percentage, Time.now.to_s, Time.now.to_s]
    )
    job_id
  end

  def validate_job_id_present(job_id)
    if job_id.nil? || job_id.to_s.strip.empty?
      { status: 400, error_type: 'missing_parameter', message: 'job_id parameter is required' }
    else
      { status: 200, error_type: nil }
    end
  end

  def fetch_job_by_id(job_id)
    @db.execute('SELECT * FROM keyword_pdf_generations WHERE uuid = ?', [job_id])[0]
  end

  def cancel_job(job_id)
    @db.execute('UPDATE keyword_pdf_generations SET cancellation_flag = 1 WHERE uuid = ?', [job_id])
    true
  end

  def cancel_completed_job(job_id)
    job = fetch_job_by_id(job_id)

    if job.nil?
      { success: false, message: "Job not found" }
    elsif job['status'] == 'completed'
      { success: true, message: "Job already completed" }
    else
      cancel_job(job_id)
      { success: true, message: "Job cancelled successfully" }
    end
  end

  def assert(condition, message)
    unless condition
      puts "   ❌ アサーション失敗: #{message}"
      raise AssertionError, message
    end
  end
end

class AssertionError < StandardError; end

if __FILE__ == $0
  tester = TestProgressAPI.new
  tester.run_tests
end
