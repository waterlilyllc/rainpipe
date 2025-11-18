#!/usr/bin/env ruby
$stdout.sync = true

require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require 'date'

client = RaindropClient.new
content_manager = BookmarkContentManager.new

# 先週の期間
today = Date.today
last_sunday = today - today.wday
week_end = last_sunday - 1
week_start = week_end - 6

puts "期間: #{week_start} - #{week_end}"
puts ""

# ブックマークを取得
bookmarks = client.get_weekly_bookmarks(week_start, week_end)
puts "取得したブックマーク: #{bookmarks.length}件"
puts ""

# 本文データを付加
bookmarks.each_with_index do |bookmark, i|
  puts "=" * 80
  puts "[#{i+1}] #{bookmark['title']}"
  puts "ID: #{bookmark['_id']}"
  puts ""

  content = content_manager.get_content(bookmark['_id'])

  if content
    puts "✅ 本文データあり:"
    puts "  content キー: #{content.keys.join(', ')}"
    puts "  content['content']: #{content['content'] ? "#{content['content'].length}文字" : 'nil'}"
    puts ""
    puts "  内容（最初の200文字）:"
    puts "  #{content['content'][0..200]}" if content['content']
  else
    puts "❌ 本文データなし"
  end

  puts ""
  puts "bookmark['content_data'] に代入後:"

  bookmark['content_data'] = content if content

  if bookmark['content_data']
    puts "  ✅ bookmark['content_data'] あり"
    puts "  キー: #{bookmark['content_data'].keys.join(', ')}"
    puts "  bookmark['content_data']['content']: #{bookmark['content_data']['content'] ? "#{bookmark['content_data']['content'].length}文字" : 'nil'}"
  else
    puts "  ❌ bookmark['content_data'] なし"
  end

  puts ""
end
