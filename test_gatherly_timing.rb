#!/usr/bin/env ruby
require 'date'
require 'stringio'
require 'dotenv'
Dotenv.load

require_relative 'gatherly_timing'

class TestGatherlyTiming
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
    puts "🧪 GatherlyTiming テストを実行中...\n"

    test_timing_initialization
    test_duration_calculation
    test_milliseconds_conversion
    test_timing_logs
    test_elapsed_time_tracking
    test_multiple_job_timing

    puts "\n" + "=" * 50
    puts "📊 テスト結果: #{@tests_passed} 成功, #{@tests_failed} 失敗"
    puts "=" * 50

    exit(@tests_failed > 0 ? 1 : 0)
  end

  # Task 4.4: タイミング初期化テスト
  def test_timing_initialization
    timing = GatherlyTiming.new

    assert(!timing.nil?, "初期化: GatherlyTiming インスタンスが作成されること")
    assert(timing.start_time.is_a?(Time), "初期化: start_time が Time オブジェクトであること")
  end

  # Task 4.4: 期間計算テスト
  def test_duration_calculation
    timing = GatherlyTiming.new
    sleep(0.1)  # 100ms の処理をシミュレート

    duration_ms = timing.elapsed_milliseconds

    assert(duration_ms >= 100, "期間計算: elapsed_milliseconds が 100ms 以上であること")
    assert(duration_ms.is_a?(Integer), "期間計算: elapsed_milliseconds が整数であること")
  end

  # Task 4.4: ミリ秒変換テスト
  def test_milliseconds_conversion
    timing = GatherlyTiming.new
    sleep(0.2)  # 200ms の処理をシミュレート

    duration_ms = timing.elapsed_milliseconds

    assert(duration_ms >= 200, "ミリ秒変換: 200ms 以上として記録されること")
    assert(duration_ms < 1000, "ミリ秒変換: 1 秒以下で測定されること（テスト実行時間）")
  end

  # Task 4.4: タイミングログテスト
  def test_timing_logs
    timing = GatherlyTiming.new
    sleep(0.05)

    original_stdout = $stdout
    captured_output = StringIO.new
    $stdout = captured_output

    log_message = timing.log_message("本文取得")

    $stdout = original_stdout

    assert(log_message.include?("本文取得"), "ログ: メッセージに操作名が含まれること")
    assert(log_message.include?("秒") || log_message.include?("ms"), "ログ: 時間単位が含まれること")
  end

  # Task 4.4: 経過時間トラッキングテスト
  def test_elapsed_time_tracking
    timing = GatherlyTiming.new
    sleep(0.1)

    elapsed = timing.elapsed_milliseconds

    assert(elapsed > 0, "トラッキング: 経過時間が正の値であること")
    assert(elapsed.is_a?(Integer), "トラッキング: ミリ秒単位で記録されること")
  end

  # Task 4.4: 複数ジョブのタイミングテスト
  def test_multiple_job_timing
    timings = [
      GatherlyTiming.new,
      GatherlyTiming.new,
      GatherlyTiming.new
    ]

    sleep(0.05)

    total_time = timings.map(&:elapsed_milliseconds).sum

    assert(total_time >= 150, "複数ジョブ: 合計時間が 150ms 以上であること")
    assert(total_time > 0, "複数ジョブ: 合計時間が正の値であること")
  end
end

# テスト実行
runner = TestGatherlyTiming.new
runner.run_all_tests
