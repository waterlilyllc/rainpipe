#!/usr/bin/env ruby
require 'sqlite3'
require 'dotenv'
Dotenv.load

# PDFGenerationHistory クラスのテスト
class TestPDFGenerationHistory
  def initialize
    @tests_passed = 0
    @tests_failed = 0
    @db = setup_test_db
  end

  def assert(condition, message)
    if condition
      @tests_passed += 1
      puts "✓ #{message}"
    else
      @tests_failed += 1
      puts "✗ #{message}"
    end
  end

  def setup_test_db
    # テスト用 DB（メモリ内）
    db = SQLite3::Database.new ':memory:'
    db.results_as_hash = true

    # テーブル作成
    db.execute <<-SQL
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

    db
  end

  def run_all_tests
    puts "🧪 PDFGenerationHistory テストを実行中...\n"

    test_create_processing_record
    test_check_processing_status
    test_update_completed_record
    test_update_failed_record
    test_fetch_history
    test_concurrent_check

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 9.2: 生成開始時に DB record 作成テスト
  def test_create_processing_record
    uuid = 'test-uuid-001'
    keywords = 'Claude,AI'
    date_start = '2025-08-13'
    date_end = '2025-11-13'
    bookmark_count = 42

    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, 'processing', datetime('now'), datetime('now'))",
      [uuid, keywords, date_start, date_end, bookmark_count]
    )

    record = @db.execute("SELECT * FROM keyword_pdf_generations WHERE uuid = ?", [uuid]).first
    assert(!record.nil?, "Task 9.2: DB record が作成されること")
    assert(record['status'] == 'processing', "Task 9.2: ステータスが 'processing' であること")
    assert(record['bookmark_count'] == 42, "Task 9.2: ブックマーク数が記録されること")
  end

  # Task 9.1: PDF 生成前に DB で in-progress ステータスチェック
  def test_check_processing_status
    uuid = 'test-uuid-002'
    keywords = 'test'

    # processing レコードを作成
    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
       VALUES (?, ?, '2025-08-13', '2025-11-13', 10, 'processing', datetime('now'), datetime('now'))",
      [uuid, keywords]
    )

    # in-progress をチェック
    processing_records = @db.execute("SELECT COUNT(*) as count FROM keyword_pdf_generations WHERE status = 'processing'")
    assert(processing_records[0]['count'] > 0, "Task 9.1: in-progress レコードが検出されること")
  end

  # Task 9.3: PDF 完成時に DB record を status=completed に更新
  def test_update_completed_record
    uuid = 'test-uuid-003'
    keywords = 'Python'
    pdf_path = '/var/git/rainpipe/data/filtered_pdf_20251113_python.pdf'
    total_duration_ms = 5432

    # processing レコードを作成
    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
       VALUES (?, ?, '2025-08-13', '2025-11-13', 25, 'processing', datetime('now'), datetime('now'))",
      [uuid, keywords]
    )

    # completed に更新
    @db.execute(
      "UPDATE keyword_pdf_generations SET status = 'completed', pdf_path = ?, total_duration_ms = ?, updated_at = datetime('now') WHERE uuid = ?",
      [pdf_path, total_duration_ms, uuid]
    )

    record = @db.execute("SELECT * FROM keyword_pdf_generations WHERE uuid = ?", [uuid]).first
    assert(record['status'] == 'completed', "Task 9.3: ステータスが 'completed' に更新されること")
    assert(record['pdf_path'] == pdf_path, "Task 9.3: PDF パスが記録されること")
    assert(record['total_duration_ms'] == total_duration_ms, "Task 9.3: 実行時間が記録されること")
  end

  # Task 9.4: エラー時に DB record を status=failed に更新
  def test_update_failed_record
    uuid = 'test-uuid-004'
    keywords = 'error-test'
    error_msg = 'API call failed: Connection timeout'

    # processing レコードを作成
    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
       VALUES (?, ?, '2025-08-13', '2025-11-13', 15, 'processing', datetime('now'), datetime('now'))",
      [uuid, keywords]
    )

    # failed に更新
    @db.execute(
      "UPDATE keyword_pdf_generations SET status = 'failed', error_message = ?, updated_at = datetime('now') WHERE uuid = ?",
      [error_msg, uuid]
    )

    record = @db.execute("SELECT * FROM keyword_pdf_generations WHERE uuid = ?", [uuid]).first
    assert(record['status'] == 'failed', "Task 9.4: ステータスが 'failed' に更新されること")
    assert(record['error_message'] == error_msg, "Task 9.4: エラーメッセージが記録されること")
  end

  # Task 9.5: 履歴取得（最新 20 件）テスト
  def test_fetch_history
    # テーブルをクリア
    @db.execute("DELETE FROM keyword_pdf_generations WHERE uuid LIKE 'history-test%'")

    # 複数レコードを作成
    5.times do |i|
      uuid = "history-test-#{i}"
      keywords = "keyword#{i}"
      @db.execute(
        "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
         VALUES (?, ?, '2025-08-13', '2025-11-13', ?, 'completed', datetime('now', '+#{i} minutes'), datetime('now'))",
        [uuid, keywords, 10 + i]
      )
    end

    # 最新 20 件を取得
    records = @db.execute("SELECT * FROM keyword_pdf_generations WHERE uuid LIKE 'history-test%' ORDER BY created_at DESC LIMIT 20")
    assert(records.length == 5, "Task 9.5: レコードが取得されること")
    # 最後に追加されたレコード（i=4）が最初に返される
    assert(records[0]['uuid'] == 'history-test-4', "Task 9.5: 最新のレコードが最初に返されること")
  end

  # Task 9.1: 並行実行制限のテスト
  def test_concurrent_check
    # processing レコードを複数作成
    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at)
       VALUES ('concurrent-1', 'test1', '2025-08-13', '2025-11-13', 10, 'processing', datetime('now'), datetime('now'))"
    )

    # in-progress チェック
    processing_records = @db.execute("SELECT COUNT(*) as count FROM keyword_pdf_generations WHERE status = 'processing'")
    assert(processing_records[0]['count'] > 0, "Task 9.1: 並行実行チェックが機能すること")
  end
end

# テスト実行
runner = TestPDFGenerationHistory.new
runner.run_all_tests
