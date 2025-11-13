# gatherly_result_merger.rb
#
# GatherlyResultMerger - Gatherly ジョブ結果の取得と本文マージ
#
# 責務:
#   - ジョブ完了後、GatherlyClient.get_job_result で記事内容を取得（Task 4.3）
#   - 取得した content を対応するブックマークの summary フィールドに統合
#   - マージ失敗（null content など）の場合は "summary unavailable" マーカーを設定
#   - サマリー取得状況（成功・失敗数）をログ出力

require_relative 'gatherly_client'

class GatherlyResultMerger
  def initialize
    @gatherly_client = GatherlyClient.new
  end

  # Task 4.3: Gatherly ジョブ結果の取得と本文マージ
  # @param job_uuids [Array<String>] 完了ジョブの UUID 配列
  # @param bookmarks [Array<Hash>] マージ対象のブックマーク配列
  # @return [Hash] { success_count: Integer, failure_count: Integer, total_processed: Integer, merged_bookmarks: [Hash] }
  def merge_results(job_uuids, bookmarks)
    puts "📄 本文取得結果をマージ中..."

    return {
      success_count: 0,
      failure_count: 0,
      total_processed: 0,
      merged_bookmarks: bookmarks
    } if job_uuids.empty? || bookmarks.empty?

    success_count = 0
    failure_count = 0
    merged_bookmarks = bookmarks.dup

    job_uuids.each_with_index do |job_uuid, job_index|
      # Task 4.3: ジョブ完了後、GatherlyClient.get_job_result で記事内容を取得
      result = @gatherly_client.get_job_result(job_uuid)

      if result[:error]
        puts "⚠️  ジョブ #{job_uuid} の結果取得に失敗: #{result[:error]}"
        failure_count += 1
        next
      end

      items = result[:items] || []

      if items.empty?
        puts "⚠️  ジョブ #{job_uuid} に取得結果がありません"
        failure_count += 1
        next
      end

      items.each do |item|
        # URL でブックマークをマッチング
        external_id = item[:external_id] || item['external_id']
        bookmark = merged_bookmarks.find { |b| b['url'] == external_id || b['link'] == external_id }

        if bookmark
          # Note: content は item[:body][:content] に nested されている
          body = item[:body] || item['body'] || {}
          content = body[:content] || body['content']

          if content && content.to_s.strip.length > 0
            # Task 4.3: 取得した content を対応するブックマークの summary フィールドに統合
            bookmark['summary'] = content
            success_count += 1
          else
            # Task 4.3: マージ失敗（null content など）の場合は "summary unavailable" マーカーを設定
            bookmark['summary'] = 'summary unavailable'
            failure_count += 1
          end
        end
      end
    end

    # Task 4.3: サマリー取得状況（成功・失敗数）をログ出力
    puts "✓ #{success_count} 件のサマリーを取得、✗ #{failure_count} 件失敗"

    {
      success_count: success_count,
      failure_count: failure_count,
      total_processed: success_count + failure_count,
      merged_bookmarks: merged_bookmarks
    }
  end
end
