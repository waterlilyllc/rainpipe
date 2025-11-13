# gatherly_job_poller.rb
#
# GatherlyJobPoller - Gatherly ジョブのポーリングと完了待機
#
# 責務:
#   - 2-3 秒間隔でジョブ状態を確認（Task 4.2）
#   - ジョブ完了（status='completed'）まで待機
#   - 5 分経過時点でタイムアウト判定
#   - タイムアウト時は warning log を出力して処理継続

require_relative 'gatherly_client'

class GatherlyJobPoller
  def initialize(timeout_seconds: 300, poll_interval_seconds: 2)
    @gatherly_client = GatherlyClient.new
    @timeout_seconds = timeout_seconds
    @poll_interval_seconds = poll_interval_seconds
  end

  # Task 4.2: Gatherly ジョブのポーリングと完了待機（5 分タイムアウト）
  # @param job_uuids [Array<String>] ジョブ UUID 配列
  # @return [Hash] { total_jobs: Integer, completed: [String], timed_out: [String] }
  def poll_until_completed(job_uuids)
    return {
      total_jobs: 0,
      completed: [],
      timed_out: [],
      polling_results: []
    } if job_uuids.empty?

    completed_jobs = []
    timed_out_jobs = []
    start_time = Time.now

    job_uuids.each do |job_uuid|
      puts "⏳ ジョブ #{job_uuid} のポーリングを開始（タイムアウト: #{@timeout_seconds} 秒）"

      job_completed = false
      poll_count = 0

      while Time.now - start_time < @timeout_seconds
        poll_count += 1

        # ジョブ状態を確認（GatherlyClient.get_job_status）
        status_result = @gatherly_client.get_job_status(job_uuid)

        if status_result[:error]
          puts "⚠️  ジョブ #{job_uuid} の状態確認に失敗: #{status_result[:error]}"
        elsif status_result[:status] == 'completed'
          puts "✅ ジョブ #{job_uuid} が完了"
          completed_jobs << job_uuid
          job_completed = true
          break
        else
          current_status = status_result[:status] || 'unknown'
          puts "⏳ ジョブ #{job_uuid} ステータス: #{current_status}（ポーリング #{poll_count} 回）"
        end

        # 2-3 秒間隔でポーリング
        sleep(@poll_interval_seconds)
      end

      unless job_completed
        # タイムアウト判定
        puts "⏱️  本文取得ジョブがタイムアウト。サマリー未取得として継続"
        timed_out_jobs << job_uuid
      end
    end

    {
      total_jobs: job_uuids.length,
      completed: completed_jobs,
      timed_out: timed_out_jobs,
      polling_results: {
        completed_count: completed_jobs.length,
        timed_out_count: timed_out_jobs.length,
        elapsed_seconds: (Time.now - start_time).round(2)
      }
    }
  end
end
