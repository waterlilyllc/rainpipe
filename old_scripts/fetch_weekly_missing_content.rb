#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'bookmark_content_fetcher'

client = RaindropClient.new
content_manager = BookmarkContentManager.new
fetcher = BookmarkContentFetcher.new

week_start = Date.parse('2025-11-02')
week_end = Date.parse('2025-11-08')

bookmarks = client.get_weekly_bookmarks(week_start, week_end)

puts "📝 先週（#{week_start} ~ #{week_end}）の要約なしブックマークに対してジョブ作成:"
puts ""

job_count = 0
skipped_count = 0

bookmarks.each_with_index do |bookmark, i|
  raindrop_id = bookmark['_id']
  url = bookmark['link']
  title = bookmark['title']

  next unless url && !url.empty?

  # 既に要約があるかチェック
  content = content_manager.get_content(raindrop_id)
  if content && content['content']
    puts "[#{i+1}/#{bookmarks.length}] ✅ 既に要約あり: #{title&.slice(0, 50)}..."
    next
  end

  puts "[#{i+1}/#{bookmarks.length}] 📥 ジョブ作成: #{title&.slice(0, 50)}..."

  job_uuid = fetcher.fetch_content(raindrop_id, url)
  if job_uuid
    job_count += 1
    puts "   ✅ ジョブID: #{job_uuid}"
  else
    skipped_count += 1
    puts "   ⏭️  スキップ（失敗済みまたは既存）"
  end

  sleep 1
end

puts ""
puts "=" * 80
puts "✅ 完了"
puts "=" * 80
puts "作成したジョブ: #{job_count}件"
puts "スキップ: #{skipped_count}件"
puts ""
puts "💡 20秒後にジョブ処理を実行します..."
sleep 20
puts ""
system("ruby process_content_jobs.rb")