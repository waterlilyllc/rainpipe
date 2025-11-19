#!/usr/bin/env ruby

require 'dotenv/load'
require 'date'
require_relative 'raindrop_client'

client = RaindropClient.new

# 先週の期間（2025-11-09 - 2025-11-15）
today = Date.today
last_sunday = today - today.wday
week_end = last_sunday - 1
week_start = week_end - 6

puts "期間: #{week_start} - #{week_end}"
puts ""

# APIから直接取得
bookmarks = client.get_weekly_bookmarks(week_start, week_end)
puts "取得件数: #{bookmarks.length}件"
puts ""

if bookmarks.any?
  puts "ブックマーク一覧:"
  bookmarks.each_with_index do |bm, i|
    created = Time.parse(bm['created']).strftime('%Y-%m-%d %H:%M')
    puts "#{i+1}. [#{created}] #{bm['title']}"
  end
else
  puts "ブックマークが見つかりません"
end

# 最新のブックマークも確認（過去7日分）
puts ""
puts "=" * 50
puts "参考: 最新のブックマーク（過去7日分）"
puts "=" * 50

recent_start = Date.today - 7
recent_end = Date.today
recent_bookmarks = client.get_weekly_bookmarks(recent_start, recent_end)
puts "取得件数: #{recent_bookmarks.length}件"
puts ""

if recent_bookmarks.any?
  recent_bookmarks.first(10).each_with_index do |bm, i|
    created = Time.parse(bm['created']).strftime('%Y-%m-%d %H:%M')
    puts "#{i+1}. [#{created}] #{bm['title']}"
  end
end
