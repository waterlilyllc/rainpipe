#!/usr/bin/env ruby
require 'sqlite3'
require 'fileutils'

# 対象のファイルを require
require_relative 'migrate_add_keyword_pdf_generations'

class SimpleTestRunner
  def initialize
    @tests_passed = 0
    @tests_failed = 0
    @test_db_path = File.join(File.dirname(__FILE__), 'test_rainpipe.db')
  end

  def setup
    File.delete(@test_db_path) if File.exist?(@test_db_path)
    @db = SQLite3::Database.new(@test_db_path)
    @db.results_as_hash = true
  end

  def teardown
    @db.close if @db
    File.delete(@test_db_path) if File.exist?(@test_db_path)
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

  def assert_raises(error_class, message)
    begin
      yield
      @tests_failed += 1
      puts "✗ #{message} (expected #{error_class.name} but nothing was raised)"
    rescue error_class
      @tests_passed += 1
      puts "✓ #{message}"
    rescue => e
      @tests_failed += 1
      puts "✗ #{message} (got #{e.class.name} instead of #{error_class.name})"
    end
  end

  def run_all_tests
    puts "🧪 テストを実行中...\n"

    test_table_exists
    test_required_columns_exist
    test_uuid_unique_constraint
    test_date_range_constraint
    test_status_default_value
    test_indexes_exist
    test_rollback_drops_table
    test_multiple_inserts

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  def test_table_exists
    setup
    Migration.new(@db).up

    tables = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_generations';")
    assert(tables.length == 1, "keyword_pdf_generations テーブルが存在すること")

    teardown
  end

  def test_required_columns_exist
    setup
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
      assert(columns.include?(col), "#{col} カラムが存在すること")
    end

    teardown
  end

  def test_uuid_unique_constraint
    setup
    Migration.new(@db).up

    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
      ['test-uuid-1', 'Claude', '2025-11-01', '2025-11-13', 10, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
    )

    assert_raises(SQLite3::ConstraintException, "uuid ユニーク制約が機能すること") do
      @db.execute(
        "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ['test-uuid-1', 'AI', '2025-11-01', '2025-11-13', 5, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
      )
    end

    teardown
  end

  def test_date_range_constraint
    setup
    Migration.new(@db).up

    assert_raises(SQLite3::ConstraintException, "日付範囲制約 (start <= end) が機能すること") do
      @db.execute(
        "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ['test-uuid-invalid', 'Test', '2025-11-13', '2025-11-01', 10, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
      )
    end

    teardown
  end

  def test_status_default_value
    setup
    Migration.new(@db).up

    @db.execute(
      "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)",
      ['test-uuid-default', 'Test', '2025-11-01', '2025-11-13', 5, Time.now.utc.iso8601, Time.now.utc.iso8601]
    )

    result = @db.execute("SELECT status FROM keyword_pdf_generations WHERE uuid = 'test-uuid-default';")
    assert(result[0][0] == 'pending', "status のデフォルト値が 'pending' であること")

    teardown
  end

  def test_indexes_exist
    setup
    Migration.new(@db).up

    indexes = @db.execute("SELECT name FROM sqlite_master WHERE type='index' AND tbl_name='keyword_pdf_generations';").map { |idx| idx[0] }

    assert(indexes.include?('idx_keyword_pdf_generations_created_at'), "created_at インデックスが存在すること")
    assert(indexes.include?('idx_keyword_pdf_generations_status'), "status インデックスが存在すること")

    teardown
  end

  def test_rollback_drops_table
    setup
    Migration.new(@db).up

    tables_before = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_generations';")
    assert(tables_before.length == 1, "アップ後にテーブルが存在すること")

    Migration.new(@db).down

    tables_after = @db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='keyword_pdf_generations';")
    assert(tables_after.length == 0, "ロールバック後にテーブルが削除されていること")

    teardown
  end

  def test_multiple_inserts
    setup
    Migration.new(@db).up

    3.times do |i|
      @db.execute(
        "INSERT INTO keyword_pdf_generations (uuid, keywords, date_range_start, date_range_end, bookmark_count, status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        ["uuid-#{i}", "Keyword#{i}", '2025-11-01', '2025-11-13', 10 + i, 'completed', Time.now.utc.iso8601, Time.now.utc.iso8601]
      )
    end

    count = @db.execute("SELECT COUNT(*) FROM keyword_pdf_generations;")
    assert(count[0][0] == 3, "3行のレコードが正常に挿入されていること")

    teardown
  end
end

# テスト実行
runner = SimpleTestRunner.new
runner.run_all_tests
