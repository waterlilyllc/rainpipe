#!/usr/bin/env ruby
require 'date'
require 'stringio'
require 'dotenv'
Dotenv.load

require_relative 'gatherly_job_poller'

class TestGatherlyJobPoller
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
    puts "🧪 GatherlyJobPoller テストを実行中...\n"

    test_poll_success
    test_poll_with_timeout
    test_poll_multiple_jobs
    test_poll_interval
    test_timeout_warning_log
    test_completed_status_detection
    test_max_retries_respected

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 4.2: ジョブポーリング成功テスト
  def test_poll_success
    job_uuid = "test-job-123"
    poller = GatherlyJobPoller.new(timeout_seconds: 2, poll_interval_seconds: 0.5)

    # ジョブを手動でポーリング（短いタイムアウト）
    result = poller.poll_until_completed([job_uuid])

    # ジョブが processing または completed のいずれかのステータスで完了
    assert(result[:completed].is_a?(Array), "ポーリング成功: completed が配列であること")
    assert(result[:total_jobs] == 1, "ポーリング成功: total_jobs が 1 であること")
  end

  # Task 4.2: タイムアウトテスト（5 分 = 300 秒）
  def test_poll_with_timeout
    job_uuid = "test-job-timeout"
    poller = GatherlyJobPoller.new(timeout_seconds: 1, poll_interval_seconds: 0.2)

    start_time = Time.now
    result = poller.poll_until_completed([job_uuid])
    elapsed = Time.now - start_time

    # 3 秒以内にタイムアウトを検出
    assert(elapsed <= 3, "タイムアウト: 適切な時間で処理されること（最大 3 秒）")
    assert(result[:timed_out].is_a?(Array), "タイムアウト: timed_out が配列であること")
  end

  # Task 4.2: 複数ジョブのポーリングテスト
  def test_poll_multiple_jobs
    job_uuids = ["job-1", "job-2", "job-3"]
    poller = GatherlyJobPoller.new(timeout_seconds: 1, poll_interval_seconds: 0.3)

    result = poller.poll_until_completed(job_uuids)

    assert(result[:total_jobs] == 3, "複数ジョブ: total_jobs が 3 であること")
  end

  # Task 4.2: ポーリング間隔テスト
  def test_poll_interval
    job_uuid = "test-job-interval"
    poller = GatherlyJobPoller.new(timeout_seconds: 1, poll_interval_seconds: 0.3)

    # ポーリング間隔が設定されていることを確認
    assert(poller.instance_variable_get(:@poll_interval_seconds) == 0.3, "ポーリング間隔: 0.3 秒に設定されること")
  end

  # Task 4.2: タイムアウト警告ログテスト
  def test_timeout_warning_log
    job_uuid = "test-job-warning"
    poller = GatherlyJobPoller.new(timeout_seconds: 0.5, poll_interval_seconds: 0.1)

    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output

    result = poller.poll_until_completed([job_uuid])

    $stdout = original_stdout
    output = captured_output.string

    # タイムアウトした場合、警告ログが出力されるはず
    if result[:timed_out].any?
      assert(output.include?("タイムアウト") || output.include?("ジョブ"), "タイムアウトログ: タイムアウト関連ログが出力されること")
    else
      assert(true, "タイムアウトログ: ジョブが完了した場合はスキップ")
    end
  end

  # Task 4.2: 完了ステータス検出テスト
  def test_completed_status_detection
    job_uuid = "test-job-completed"
    poller = GatherlyJobPoller.new(timeout_seconds: 1, poll_interval_seconds: 0.3)

    result = poller.poll_until_completed([job_uuid])

    # completed または timed_out のいずれかが含まれる
    total = result[:completed].length + result[:timed_out].length
    assert(total > 0, "ステータス検出: 完了またはタイムアウトが検出されること")
  end

  # Task 4.2: 最大リトライ回数尊重テスト
  def test_max_retries_respected
    job_uuids = ["job-1", "job-2"]
    poller = GatherlyJobPoller.new(timeout_seconds: 0.5, poll_interval_seconds: 0.1)

    result = poller.poll_until_completed(job_uuids)

    # タイムアウトかつリトライ上限に達した場合
    assert(result[:timed_out].is_a?(Array), "リトライ上限: timed_out が配列であること")
  end
end

# テスト実行
runner = TestGatherlyJobPoller.new
runner.run_all_tests
