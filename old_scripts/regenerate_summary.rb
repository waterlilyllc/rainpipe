#!/usr/bin/env ruby
$stdout.sync = true

require 'dotenv/load'
require 'date'
require_relative 'weekly_summary_generator'

generator = WeeklySummaryGenerator.new

# 先週の期間（2025-11-09 to 2025-11-15）
week_start = Date.parse('2025-11-09')

puts "週次サマリーを再生成: #{week_start}"
puts ""

summary = generator.generate_weekly_summary(week_start.to_s)

puts ""
puts "=== 生成結果 ==="
puts "keywords: #{summary[:keywords].keys.length}個"
summary[:keywords].each do |keyword, data|
  puts "  - #{keyword}: #{data[:article_count]}記事"
end
puts "overall_insights: #{summary[:overall_insights] ? '生成済み' : 'なし'}"
puts "related_clusters: #{summary[:related_clusters]&.length || 0}個"
