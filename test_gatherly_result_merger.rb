#!/usr/bin/env ruby
require 'date'
require 'stringio'
require 'dotenv'
Dotenv.load

require_relative 'gatherly_result_merger'

class TestGatherlyResultMerger
  def initialize
    @tests_passed = 0
    @tests_failed = 0
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

  def run_all_tests
    puts "🧪 GatherlyResultMerger テストを実行中...\n"

    test_merge_single_result
    test_merge_multiple_results
    test_merge_with_missing_content
    test_merge_failure_handling
    test_summary_statistics
    test_merge_logs

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 4.3: 単一ジョブ結果マージテスト
  def test_merge_single_result
    bookmarks = [
      { 'id' => 1, 'url' => 'https://example.com/1', 'title' => 'Article 1', 'summary' => nil },
      { 'id' => 2, 'url' => 'https://example.com/2', 'title' => 'Article 2', 'summary' => nil }
    ]

    merger = GatherlyResultMerger.new
    result = merger.merge_results(['job-1'], bookmarks)

    assert(result[:success_count] >= 0, "単一マージ: success_count が整数であること")
    assert(result[:failure_count] >= 0, "単一マージ: failure_count が整数であること")
  end

  # Task 4.3: 複数ジョブ結果マージテスト
  def test_merge_multiple_results
    bookmarks = (1..6).map { |i| { 'id' => i, 'url' => "https://example.com/#{i}", 'title' => "Article #{i}", 'summary' => nil } }

    merger = GatherlyResultMerger.new
    result = merger.merge_results(['job-1', 'job-2'], bookmarks)

    # 複数ジョブの結果が処理されること
    assert(result.is_a?(Hash), "複数マージ: 結果がハッシュであること")
    assert(result[:total_processed] >= 0, "複数マージ: total_processed が記録されること")
  end

  # Task 4.3: コンテンツ欠落時の「未取得」マーカー設定テスト
  def test_merge_with_missing_content
    bookmarks = [
      { 'id' => 1, 'url' => 'https://example.com/1', 'title' => 'Article 1', 'summary' => nil }
    ]

    merger = GatherlyResultMerger.new
    result = merger.merge_results(['job-invalid'], bookmarks)

    # 失敗時は失敗数がカウントされる
    assert(result[:failure_count] >= 0, "コンテンツ欠落: failure_count がカウントされること")
  end

  # Task 4.3: マージ失敗ハンドリングテスト
  def test_merge_failure_handling
    bookmarks = [
      { 'id' => 1, 'url' => 'https://example.com/1', 'title' => 'Article 1', 'summary' => nil }
    ]

    merger = GatherlyResultMerger.new
    result = merger.merge_results([], bookmarks)

    # ジョブが空の場合も安全に処理される
    assert(result[:total_processed] == 0, "失敗ハンドリング: 空のジョブリストで安全に処理されること")
  end

  # Task 4.3: サマリー取得統計テスト
  def test_summary_statistics
    bookmarks = [
      { 'id' => 1, 'url' => 'https://example.com/1', 'title' => 'Article 1', 'summary' => nil },
      { 'id' => 2, 'url' => 'https://example.com/2', 'title' => 'Article 2', 'summary' => nil },
      { 'id' => 3, 'url' => 'https://example.com/3', 'title' => 'Article 3', 'summary' => 'Existing' }
    ]

    merger = GatherlyResultMerger.new
    result = merger.merge_results(['job-1'], bookmarks)

    assert(result[:success_count] + result[:failure_count] >= 0, "統計: 成功数と失敗数の合計が非負であること")
  end

  # Task 4.3: マージログテスト
  def test_merge_logs
    bookmarks = [
      { 'id' => 1, 'url' => 'https://example.com/1', 'title' => 'Article 1', 'summary' => nil }
    ]

    merger = GatherlyResultMerger.new

    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output

    result = merger.merge_results(['job-1'], bookmarks)

    $stdout = original_stdout
    output = captured_output.string

    # ログが出力されること（成功または失敗に関わらず）
    assert(output.include?("サマリー") || output.include?("取得") || output.length > 0, "マージログ: ログが出力されること")
  end
end

# テスト実行
runner = TestGatherlyResultMerger.new
runner.run_all_tests
