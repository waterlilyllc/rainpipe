#!/usr/bin/env ruby
# retry_count が max_retries に達したジョブに失敗フラグを立てる

require 'dotenv/load'
require_relative 'crawl_job_manager'
require_relative 'bookmark_content_manager'

puts "⛔ 最大リトライ回数に達したジョブに失敗フラグを立てます"
puts ""

job_manager = CrawlJobManager.new
content_manager = BookmarkContentManager.new

# retry_count >= max_retries のジョブを取得
maxed_out_jobs = job_manager.db.execute(
  <<-SQL
    SELECT DISTINCT raindrop_id, url, retry_count, max_retries
    FROM crawl_jobs
    WHERE status = 'failed'
      AND retry_count >= max_retries
  SQL
)

puts "📊 対象ジョブ: #{maxed_out_jobs.length}件"
puts ""

marked_count = 0
maxed_out_jobs.each do |job|
  raindrop_id = job['raindrop_id']
  url = job['url']

  # 既に失敗フラグが立っているかチェック
  if content_manager.fetch_failed?(raindrop_id)
    puts "⏭️  Already marked: #{url&.slice(0, 60)}..."
    next
  end

  # 失敗フラグを立てる
  result = content_manager.mark_fetch_failed(raindrop_id, url)
  if result
    puts "⛔ Marked as failed: #{url&.slice(0, 60)}..."
    marked_count += 1
  else
    puts "❌ Failed to mark: #{url&.slice(0, 60)}..."
  end
end

puts ""
puts "✅ 完了: #{marked_count}件のブックマークに失敗フラグを立てました"
puts ""

# 失敗フラグの統計
stats = content_manager.db.execute(
  'SELECT fetch_failed, COUNT(*) as count FROM bookmark_contents GROUP BY fetch_failed'
)

puts "📊 統計:"
stats.each do |row|
  status = row['fetch_failed'] == 1 ? '失敗フラグ有' : '失敗フラグ無'
  puts "  #{status}: #{row['count']}件"
end
