# gatherly_timing.rb
#
# GatherlyTiming - ジョブ実行時間計測
#
# 責務:
#   - Gatherly 本文取得の開始～完了時刻を計測（Task 4.4）
#   - gatherly_fetch_duration_ms を DB に記録
#   - パフォーマンス分析用ログ出力

class GatherlyTiming
  attr_reader :start_time

  def initialize
    @start_time = Time.now
  end

  # Task 4.4: 経過時間をミリ秒単位で返す
  # @return [Integer] ミリ秒単位の経過時間
  def elapsed_milliseconds
    elapsed_seconds = Time.now - @start_time
    (elapsed_seconds * 1000).to_i
  end

  # Task 4.4: 経過時間をログメッセージとして返す
  # @param operation_name [String] 操作名
  # @return [String] ログメッセージ
  def log_message(operation_name)
    elapsed_ms = elapsed_milliseconds
    elapsed_seconds = (elapsed_ms / 1000.0).round(2)

    "🕐 #{operation_name}時間: #{elapsed_seconds} 秒"
  end

  # Task 4.4: 経過時間をログに出力
  # @param operation_name [String] 操作名
  def log_elapsed(operation_name)
    puts log_message(operation_name)
  end
end
