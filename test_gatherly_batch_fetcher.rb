#!/usr/bin/env ruby
require 'date'
require 'stringio'
require 'dotenv'
Dotenv.load

require_relative 'gatherly_batch_fetcher'

class TestGatherlyBatchFetcher
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
    puts "🧪 GatherlyBatchFetcher テストを実行中...\n"

    test_batch_creation_with_single_batch
    test_batch_creation_with_multiple_batches
    test_batch_creation_respects_max_batches
    test_batch_splitting_by_15_items
    test_job_uuid_recording
    test_empty_bookmarks_handling
    test_batch_fetch_logs
    test_job_creation_failure_handling

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 4.1: 単一バッチの作成テスト
  def test_batch_creation_with_single_batch
    bookmarks = (1..10).map { |i| { 'id' => i, 'url' => "https://example.com/#{i}", 'title' => "Article #{i}" } }

    fetcher = GatherlyBatchFetcher.new
    result = fetcher.create_batch_jobs(bookmarks)

    assert(result[:total_bookmarks] == 10, "単一バッチ: 10 件のブックマークが記録されること")
    assert(result[:batch_count] == 1, "単一バッチ: バッチ数が 1 であること")
    assert(result[:job_uuids].length == 1, "単一バッチ: ジョブ UUID が 1 件であること")
  end

  # Task 4.1: 複数バッチの作成テスト
  def test_batch_creation_with_multiple_batches
    bookmarks = (1..40).map { |i| { 'id' => i, 'url' => "https://example.com/#{i}", 'title' => "Article #{i}" } }

    fetcher = GatherlyBatchFetcher.new
    result = fetcher.create_batch_jobs(bookmarks)

    assert(result[:total_bookmarks] == 40, "複数バッチ: 40 件のブックマークが記録されること")
    assert(result[:batch_count] == 3, "複数バッチ: 15+15+10 で 3 バッチに分割されること")
    assert(result[:job_uuids].length == 3, "複数バッチ: ジョブ UUID が 3 件であること")
  end

  # Task 4.1: 最大バッチ数制限テスト
  def test_batch_creation_respects_max_batches
    # 161 件 = 11 バッチ分（11 * 15 = 165）
    bookmarks = (1..161).map { |i| { 'id' => i, 'url' => "https://example.com/#{i}", 'title' => "Article #{i}" } }

    fetcher = GatherlyBatchFetcher.new(max_batches: 10)
    result = fetcher.create_batch_jobs(bookmarks)

    assert(result[:batch_count] == 10, "最大バッチ制限: max_batches=10 で 10 バッチまでに制限されること")
    assert(result[:job_uuids].length == 10, "最大バッチ制限: ジョブ UUID が 10 件であること")
  end

  # Task 4.1: 15 件ごとのバッチ分割テスト
  def test_batch_splitting_by_15_items
    bookmarks = (1..50).map { |i| { 'id' => i, 'url' => "https://example.com/#{i}", 'title' => "Article #{i}" } }

    fetcher = GatherlyBatchFetcher.new
    result = fetcher.create_batch_jobs(bookmarks)

    # 50 件 = 15 + 15 + 20 で 3 バッチ
    assert(result[:batch_count] == 4, "15 件分割: 50 件が 15+15+15+5 で 4 バッチに分割されること")
  end

  # Task 4.1: ジョブ UUID 記録テスト
  def test_job_uuid_recording
    bookmarks = (1..15).map { |i| { 'id' => i, 'url' => "https://example.com/#{i}", 'title' => "Article #{i}" } }

    fetcher = GatherlyBatchFetcher.new
    result = fetcher.create_batch_jobs(bookmarks)

    assert(!result[:job_uuids].empty?, "ジョブ UUID: job_uuids が空でないこと")
    assert(result[:job_uuids].all? { |uuid| uuid.is_a?(String) && !uuid.empty? }, "ジョブ UUID: すべてが文字列であること")
  end

  # Task 4.1: 空のブックマーク配列ハンドリングテスト
  def test_empty_bookmarks_handling
    fetcher = GatherlyBatchFetcher.new
    result = fetcher.create_batch_jobs([])

    assert(result[:total_bookmarks] == 0, "空配列: total_bookmarks が 0 であること")
    assert(result[:batch_count] == 0, "空配列: batch_count が 0 であること")
    assert(result[:job_uuids].empty?, "空配列: job_uuids が空であること")
  end

  # Task 4.1: ログ出力テスト（キャプチャ）
  def test_batch_fetch_logs
    bookmarks = (1..30).map { |i| { 'id' => i, 'url' => "https://example.com/#{i}", 'title' => "Article #{i}" } }

    fetcher = GatherlyBatchFetcher.new

    # ログ出力をキャプチャするため、標準出力をリダイレクト
    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output

    result = fetcher.create_batch_jobs(bookmarks)

    $stdout = original_stdout
    output = captured_output.string

    assert(output.include?("本文取得ジョブ"), "ログ: 本文取得ジョブについて言及されること")
    assert(result[:batch_count] == 2, "ログ: 30 件が 15+15 で 2 バッチに分割されること")
  end

  # Task 4.1: ジョブ作成失敗ハンドリングテスト
  def test_job_creation_failure_handling
    # GatherlyClient がエラーを返すケースをシミュレート
    bookmarks = [{ 'id' => 1, 'url' => 'https://invalid.example.com', 'title' => 'Invalid' }]

    fetcher = GatherlyBatchFetcher.new
    result = fetcher.create_batch_jobs(bookmarks)

    # ジョブ作成に失敗してもバッチは記録されるはず
    assert(result[:total_bookmarks] == 1, "失敗ハンドリング: total_bookmarks は記録されること")
    assert(result[:batch_count] == 1, "失敗ハンドリング: batch_count は記録されること")
  end
end

# テスト実行
runner = TestGatherlyBatchFetcher.new
runner.run_all_tests
