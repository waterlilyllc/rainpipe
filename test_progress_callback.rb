#!/usr/bin/env ruby
# Test: ProgressCallback Interface
#
# 目的: ProgressCallback クラスの検証
#       サービスレイヤーに進捗更新を注入するためのインターフェース

require 'sqlite3'
require 'tempfile'
require 'fileutils'
require 'json'
require_relative 'progress_callback'

class TestProgressCallback
  def initialize
    @tempfile = Tempfile.new('test_callback.db')
    @db_path = @tempfile.path
    @tempfile.close
    FileUtils.rm(@db_path) if File.exist?(@db_path)

    @db = SQLite3::Database.new(@db_path)
    @db.results_as_hash = true
    setup_database
  end

  def setup_database
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
  end

  def teardown
    @db.close
    FileUtils.rm(@db_path) if File.exist?(@db_path)
  end

  def run_tests
    puts "🧪 ProgressCallback テスト開始\n\n"

    create_test_job

    test_1_initialization
    test_2_report_stage
    test_3_report_event
    test_4_cancellation_requested
    test_5_null_callback_support
    test_6_stage_validation
    test_7_percentage_validation
    test_8_database_persistence
    test_9_json_details_storage

    teardown
    puts "\n✅ 全テスト完了！"
  end

  def create_test_job
    @test_job_id = 'test-job-' + Time.now.to_i.to_s
    @db.execute(
      'INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [@test_job_id, 'test', '2025-01-01', '2025-01-31', 10, 'processing', Time.now.to_s, Time.now.to_s]
    )
  end

  def test_1_initialization
    puts "✅ テスト 1: ProgressCallback 初期化"
    callback = ProgressCallback.new(@test_job_id, @db)
    assert(callback.is_a?(ProgressCallback), "Should be ProgressCallback instance")
    puts "   ✓ 初期化成功\n\n"
  end

  def test_2_report_stage
    puts "✅ テスト 2: report_stage メソッド"
    callback = ProgressCallback.new(@test_job_id, @db)

    details = { bookmarks_retrieved: 150, bookmarks_after_filter: 45 }
    callback.report_stage('filtering', 25, details)

    # DB に記録されたかを確認
    result = @db.execute(
      'SELECT stage, percentage, message, details FROM keyword_pdf_progress_logs WHERE job_id = ? ORDER BY id DESC LIMIT 1',
      [@test_job_id]
    )[0]

    assert(result['stage'] == 'filtering', "Stage should be 'filtering'")
    assert(result['percentage'] == 25, "Percentage should be 25")
    assert(result['details'], "Details should be stored as JSON")

    # job record も更新されたかを確認
    job = @db.execute('SELECT current_stage, current_percentage FROM keyword_pdf_generations WHERE uuid = ?', [@test_job_id])[0]
    assert(job['current_stage'] == 'filtering', "Job current_stage should be updated")
    assert(job['current_percentage'] == 25, "Job current_percentage should be updated")

    puts "   ✓ report_stage 機能正常"
    puts "   ✓ DB に段階的ログが記録\n\n"
  end

  def test_3_report_event
    puts "✅ テスト 3: report_event メソッド"
    callback = ProgressCallback.new(@test_job_id, @db)

    callback.report_event('retry', 'Retrying GPT API call')

    result = @db.execute(
      'SELECT event_type, message FROM keyword_pdf_progress_logs WHERE job_id = ? AND event_type = ? LIMIT 1',
      [@test_job_id, 'retry']
    )[0]

    assert(result['event_type'] == 'retry', "Event type should be 'retry'")
    assert(result['message'].include?('Retrying'), "Message should be stored")

    puts "   ✓ report_event 機能正常\n\n"
  end

  def test_4_cancellation_requested
    puts "✅ テスト 4: cancellation_requested? メソッド"
    callback = ProgressCallback.new(@test_job_id, @db)

    # キャンセルフラグなし
    is_cancelled = callback.cancellation_requested?
    assert(!is_cancelled, "Should return false when not cancelled")

    # キャンセルフラグを設定
    @db.execute('UPDATE keyword_pdf_generations SET cancellation_flag = 1 WHERE uuid = ?', [@test_job_id])

    # キャンセルフラグあり
    is_cancelled = callback.cancellation_requested?
    assert(is_cancelled, "Should return true when cancelled")

    puts "   ✓ キャンセルフラグ検出正常\n\n"
  end

  def test_5_null_callback_support
    puts "✅ テスト 5: NULL callback サポート"
    callback = ProgressCallback.null_callback

    # NULL callback は何もしない
    callback.report_stage('filtering', 25, {})
    callback.report_event('info', 'Test')
    is_cancelled = callback.cancellation_requested?

    assert(callback.is_a?(ProgressCallback), "NULL callback should be ProgressCallback")
    assert(!is_cancelled, "NULL callback should return false for cancellation")

    puts "   ✓ NULL callback 正常（CLI モードで使用可能）\n\n"
  end

  def test_6_stage_validation
    puts "✅ テスト 6: ステージ名検証"
    callback = ProgressCallback.new(@test_job_id, @db)

    valid_stages = ['filtering', 'content_fetching', 'summarization', 'pdf_generation', 'email_sending']
    valid_stages.each do |stage|
      begin
        callback.report_stage(stage, 50, {})
      rescue => e
        flunk("Should accept valid stage '#{stage}': #{e.message}")
      end
    end

    # 無効なステージで例外発生
    begin
      callback.report_stage('invalid_stage', 50, {})
      flunk("Should raise error for invalid stage")
    rescue ArgumentError => e
      assert(e.message.include?('invalid_stage'), "Should mention invalid stage")
    end

    puts "   ✓ ステージ名検証正常\n\n"
  end

  def test_7_percentage_validation
    puts "✅ テスト 7: パーセンテージ範囲検証"
    callback = ProgressCallback.new(@test_job_id, @db)

    # 有効な範囲
    [0, 50, 100].each do |percentage|
      begin
        callback.report_stage('filtering', percentage, {})
      rescue => e
        flunk("Should accept percentage #{percentage}: #{e.message}")
      end
    end

    # 無効な範囲
    [-1, 101].each do |percentage|
      begin
        callback.report_stage('filtering', percentage, {})
        flunk("Should reject percentage #{percentage}")
      rescue ArgumentError => e
        assert(e.message.include?('0-100'), "Should mention valid range 0-100")
      end
    end

    puts "   ✓ パーセンテージ範囲検証正常\n\n"
  end

  def test_8_database_persistence
    puts "✅ テスト 8: DB 永続性"
    callback = ProgressCallback.new(@test_job_id, @db)

    # 複数のステージを報告
    callback.report_stage('filtering', 10, { count: 150 })
    callback.report_stage('content_fetching', 30, { jobs: 3 })
    callback.report_stage('summarization', 60, { progress: '30/50' })

    # ログが全て記録されているか確認
    logs = @db.execute(
      'SELECT COUNT(*) as count FROM keyword_pdf_progress_logs WHERE job_id = ?',
      [@test_job_id]
    )[0]['count']

    assert(logs >= 3, "Should have at least 3 log entries")

    puts "   ✓ 全ログが DB に記録\n\n"
  end

  def test_9_json_details_storage
    puts "✅ テスト 9: JSON詳細情報ストレージ"
    callback = ProgressCallback.new(@test_job_id, @db)

    details = {
      bookmarks_retrieved: 150,
      bookmarks_after_filter: 45,
      filtering_time_ms: 1234
    }

    callback.report_stage('filtering', 20, details)

    # JSON が正しく保存されているか確認
    result = @db.execute(
      'SELECT details FROM keyword_pdf_progress_logs WHERE job_id = ? ORDER BY id DESC LIMIT 1',
      [@test_job_id]
    )[0]

    assert(result['details'], "Details should be stored")
    parsed_details = JSON.parse(result['details'])
    assert(parsed_details['bookmarks_retrieved'] == 150, "JSON should contain correct data")

    puts "   ✓ JSON 詳細情報が正しく保存\n\n"
  end

  private

  def assert(condition, message)
    unless condition
      puts "   ❌ アサーション失敗: #{message}"
      raise AssertionError, message
    end
  end

  def flunk(message)
    puts "   ❌ テスト失敗: #{message}"
    raise TestError, message
  end
end

class AssertionError < StandardError; end
class TestError < StandardError; end

# テスト実行
if __FILE__ == $0
  tester = TestProgressCallback.new
  tester.run_tests
end
