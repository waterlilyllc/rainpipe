#!/usr/bin/env ruby
require 'dotenv/load'
require 'sqlite3'
require_relative 'gatherly_client'
require_relative 'bookmark_content_manager'

client = GatherlyClient.new
content_manager = BookmarkContentManager.new

# pending状態のジョブを取得
db = SQLite3::Database.new('data/rainpipe.db')
pending_jobs = db.execute(
  "SELECT raindrop_id, job_id FROM crawl_jobs WHERE status = 'pending' ORDER BY created_at DESC LIMIT 9"
)

puts "pending状態のジョブ: #{pending_jobs.length}件"
puts "="*80
puts ""

saved_count = 0
failed_count = 0

pending_jobs.each_with_index do |(raindrop_id, job_id), i|
  puts "[#{i+1}/#{pending_jobs.length}] Job ID: #{job_id}"
  puts "  Raindrop ID: #{raindrop_id}"

  # Gatherly APIから結果を取得
  result = client.get_job_result(job_id)

  if result[:error]
    puts "  ❌ 結果取得失敗: #{result[:error]}"
    failed_count += 1
    next
  end

  if result[:items].nil? || result[:items].empty?
    puts "  ⚠️  結果が空です"
    failed_count += 1
    next
  end

  # 最初の結果を取得
  first_item = result[:items].first
  content = first_item.dig(:body, :content)

  if content.nil? || content.empty?
    puts "  ⚠️  コンテンツが空です"
    failed_count += 1
    next
  end

  puts "  ✅ コンテンツ取得: #{content[0..100]}..."

  # データベースに保存（Hashとして渡す）
  data = {
    content: content,
    title: first_item.dig(:body, :title),
    url: first_item[:external_id],
    content_type: 'text',
    word_count: content.length,
    extracted_at: first_item[:fetched_at]
  }
  success = content_manager.save_content(raindrop_id, data)

  if success
    puts "  ✅ データベース保存成功"

    # ジョブステータスを更新
    db.execute(
      "UPDATE crawl_jobs SET status = 'success', updated_at = datetime('now') WHERE job_id = ?",
      job_id
    )
    puts "  ✅ ジョブステータス更新: success"
    saved_count += 1
  else
    puts "  ❌ データベース保存失敗"
    failed_count += 1
  end

  puts ""
end

db.close

puts "="*80
puts "結果: 保存成功 #{saved_count}/#{pending_jobs.length}, 失敗 #{failed_count}/#{pending_jobs.length}"
puts "="*80
