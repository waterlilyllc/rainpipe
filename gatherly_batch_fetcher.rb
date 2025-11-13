# gatherly_batch_fetcher.rb
#
# GatherlyBatchFetcher - Gatherly API 経由の本文取得ジョブ管理
#
# 責務:
#   - サマリー未取得ブックマークのバッチ分割（Task 4.1）
#   - 15 件ずつのバッチで Gatherly ジョブ作成
#   - ジョブ UUID の記録と管理
#   - API 乱用防止のための最大バッチ数制限

require_relative 'gatherly_client'

class GatherlyBatchFetcher
  def initialize(max_batches: 10)
    @gatherly_client = GatherlyClient.new
    @max_batches = max_batches
    @batch_size = 15
  end

  # Task 4.1: サマリー未取得ブックマークのバッチ本文取得ジョブ作成
  # @param bookmarks [Array<Hash>] サマリー未取得ブックマーク配列
  # @return [Hash] { total_bookmarks: Integer, batch_count: Integer, job_uuids: [String] }
  def create_batch_jobs(bookmarks)
    puts "🌐 本文取得ジョブを作成中..." if bookmarks.any?

    return {
      total_bookmarks: 0,
      batch_count: 0,
      job_uuids: [],
      created_jobs: []
    } if bookmarks.empty?

    # ブックマークを 15 件ずつのバッチに分割
    batches = bookmarks.each_slice(@batch_size).to_a

    # 最大バッチ数に制限（API 乱用防止）
    batches = batches.first(@max_batches) if batches.length > @max_batches

    job_uuids = []
    created_jobs = []

    batches.each_with_index do |batch, index|
      urls = batch.map { |b| b['url'] }.compact

      next if urls.empty?

      # 各バッチごとに GatherlyClient.create_crawl_job を呼び出し
      result = @gatherly_client.create_crawl_job_batch(urls)

      if result[:job_uuid]
        job_uuids << result[:job_uuid]
        created_jobs << {
          batch_index: index + 1,
          job_uuid: result[:job_uuid],
          bookmark_count: urls.length
        }
        puts "🌐 本文取得ジョブを作成: #{result[:job_uuid]}"
      else
        puts "⚠️  バッチ #{index + 1} のジョブ作成に失敗: #{result[:error]}"
      end
    end

    {
      total_bookmarks: bookmarks.length,
      batch_count: batches.length,
      job_uuids: job_uuids,
      created_jobs: created_jobs
    }
  end
end
