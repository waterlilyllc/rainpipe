#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_exporter'

# テスト用にいくつかのブックマークを確認
client = RaindropClient.new
bookmarks = client.get_monthly_bookmarks(Date.new(2025, 7, 1), Date.new(2025, 7, 31))

exporter = BookmarkExporter.new

puts "📊 7月のブックマーク振り分けテスト"
puts "=" * 50

bookmarks.first(10).each_with_index do |bookmark, idx|
  destination = exporter.determine_destination(bookmark)
  tags = bookmark['tags'] || []
  
  puts "\n[#{idx + 1}] #{bookmark['title'][0..50]}..."
  puts "タグ: #{tags.join(', ')}"
  puts "振り分け先: #{destination == :notion ? 'Notion' : destination == :obsidian ? 'Obsidian' : 'なし'}"
end

puts "\n\n📊 タグ別集計:"
notion_tags = BookmarkExporter::TAG_ROUTING_RULES[:notion]
obsidian_tags = BookmarkExporter::TAG_ROUTING_RULES[:obsidian]

puts "\nNotion向けタグ: #{notion_tags.join(', ')}"
puts "Obsidian向けタグ: #{obsidian_tags.join(', ')}"