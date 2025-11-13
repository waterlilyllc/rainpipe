#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load

require 'json'
require_relative 'keyword_filtered_pdf_service'

# Obsidianキーワードで検索
service = KeywordFilteredPDFService.new(keywords: 'Obsidian', date_start: '2025-08-16', date_end: '2025-11-14')
result = service.execute

puts "\n=== ブックマークサマリー統計 ==="
bookmarks = result[:bookmarks]

with_summary = bookmarks.select { |b| b['summary'] && b['summary'].to_s.strip.length > 20 }
without_summary = bookmarks.select { |b| !b['summary'] || b['summary'].to_s.strip.length <= 20 }

puts "✅ サマリーあり: #{with_summary.length} 件"
puts "❌ サマリーなし: #{without_summary.length} 件"
puts "合計: #{bookmarks.length} 件"

puts "\n=== サマリーなし詳細 ==="
without_summary.each do |b|
  puts "- #{b['title']}"
end
