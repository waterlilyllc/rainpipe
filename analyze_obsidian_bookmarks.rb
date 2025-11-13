#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load

require 'date'
require_relative 'raindrop_client'

# Obsidian フィルタ後の状態を確認
client = RaindropClient.new
date_start = Date.today - 90
date_end = Date.today

bookmarks = client.get_bookmarks_by_date_range(date_start, date_end)

# Obsidian キーワードでフィルタリング
obsidian_bookmarks = bookmarks.select do |b|
  text = [b['title'], (b['tags'] || []).join(' '), b['excerpt']].join(' ').downcase
  text.include?('obsidian')
end

puts "📊 Obsidian ブックマーク状態分析"
puts "=" * 60
puts "📚 総数: #{obsidian_bookmarks.length} 件"
puts ""

# 最初の3件を確認
obsidian_bookmarks.first(3).each_with_index do |b, idx|
  puts "#{idx+1}. #{b['title']}"
  puts "   URL: #{b['url'] || b['link']}"
  puts "   Content: #{b['content'] ? b['content'][0..80] : 'nil'}"
  puts "   Summary: #{b['summary'] ? b['summary'][0..80] : 'nil'}"
  puts ""
end
