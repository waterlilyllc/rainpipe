#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'weekly_pdf_generator'

puts "📄 今週のPDFをテスト生成します"

generator = WeeklyPDFGenerator.new

# 今週の月曜〜日曜
today = Date.today
week_start = today - (today.wday - 1) % 7  # 今週の月曜
week_end = week_start + 6

puts "期間: #{week_start} - #{week_end}"

output_path = generator.generate_weekly_pdf(week_start, week_end, 'data/test_weekly.pdf')

puts "✅ 生成完了: #{output_path}"
puts "サイズ: #{File.size(output_path) / 1024}KB"
