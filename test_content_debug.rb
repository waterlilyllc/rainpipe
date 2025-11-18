#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'bookmark_content_manager'
require_relative 'raindrop_client'
require 'date'

client = RaindropClient.new
bookmarks = client.get_weekly_bookmarks(Date.parse('2025-11-09'), Date.parse('2025-11-15'))

puts "先週のブックマーク数: #{bookmarks.length}"
puts ""

manager = BookmarkContentManager.new

bookmarks.each do |bm|
  puts "ID: #{bm['_id']} - #{bm['title']}"
  content = manager.get_content(bm['_id'])

  if content && content['content']
    puts "  ✅ 本文あり (#{content['content'].length}文字)"
    puts "  内容: #{content['content'][0..100]}..."
  else
    puts "  ❌ 本文なし"
    puts "  content_data: #{content.inspect}"
  end
  puts ""
end
