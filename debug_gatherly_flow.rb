#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load

require_relative 'gatherly_client'
require_relative 'raindrop_client'

puts "🔍 Gatherly API フロー デバッグ"
puts "=" * 60

# Obsidian ブックマークを取得
client = RaindropClient.new
date_start = Date.today - 90
date_end = Date.today

bookmarks = client.get_bookmarks_by_date_range(date_start, date_end)
obsidian_bookmarks = bookmarks.select do |b|
  text = [b['title'], (b['tags'] || []).join(' '), b['excerpt']].join(' ').downcase
  text.include?('obsidian')
end

puts "📚 Obsidian ブックマーク: #{obsidian_bookmarks.length} 件"

# 最初の 3 件のURL を取得
urls = obsidian_bookmarks.first(3).map { |b| b['url'] || b['link'] }.compact

puts "🔗 テスト URL:"
urls.each_with_index { |url, idx| puts "  #{idx+1}. #{url[0..60]}..." }

# Gatherly API でジョブ作成
puts "\n🌐 Gatherly API でジョブ作成"
gatherly = GatherlyClient.new

result = gatherly.create_crawl_job_batch(urls)
puts "📝 結果: #{result.inspect}"

if result[:error]
  puts "❌ ジョブ作成失敗: #{result[:error]}"
  exit 1
end

job_uuid = result[:job_uuid]
puts "✅ ジョブ作成成功: #{job_uuid}"

# ジョブ状態を確認
puts "\n⏳ ジョブ状態確認（最大 30 秒ポーリング）"

start_time = Time.now
completed = false
poll_count = 0

while Time.now - start_time < 30
  poll_count += 1
  status_result = gatherly.get_job_status(job_uuid)

  puts "  [#{poll_count}] Status: #{status_result.inspect}"

  if status_result[:status] == 'completed'
    completed = true
    puts "✅ ジョブ完了！"
    break
  elsif status_result[:error]
    puts "⚠️  エラー: #{status_result[:error]}"
    break
  end

  sleep 2
end

if completed
  # ジョブ結果を取得
  puts "\n📄 ジョブ結果取得"
  result_data = gatherly.get_job_result(job_uuid)
  puts "結果: #{result_data.inspect}"

  if result_data[:items]
    puts "\n✅ 取得コンテンツ数: #{result_data[:items].length}"
    result_data[:items].each_with_index do |item, idx|
      puts "\n  #{idx+1}. #{item[:url] || item['url']}"
      content = item[:content] || item['content']
      puts "     Content length: #{content&.length || 0} 字"
    end
  end
else
  puts "\n⏱️  タイムアウト - ジョブが完了しませんでした"
end
