#!/usr/bin/env ruby
$stdout.sync = true
$stderr.sync = true

require 'dotenv/load'
require_relative 'weekly_pdf_generator'

puts "=" * 80
puts "週間PDF生成テスト（本文取得待機機能付き）"
puts "=" * 80
puts ""

generator = WeeklyPDFGenerator.new

# 先週の期間
today = Date.today
last_sunday = today - today.wday
week_end = last_sunday - 1
week_start = week_end - 6

puts "📅 期間: #{week_start} - #{week_end}"
puts ""

begin
  output_path = generator.generate_last_week_pdf
  puts ""
  puts "=" * 80
  puts "✅ PDF生成完了: #{output_path}"
  puts "📏 サイズ: #{File.size(output_path) / 1024}KB"

  # PDFの内容確認
  require 'sqlite3'
  db = SQLite3::Database.new('data/rainpipe.db')
  db.results_as_hash = true

  puts ""
  puts "📊 本文取得状況:"
  result = db.execute("SELECT COUNT(*) as total FROM bookmark_contents")
  puts "  データベース内の本文数: #{result[0]['total']}件"

  puts "=" * 80
rescue => e
  puts ""
  puts "=" * 80
  puts "❌ エラー: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  puts "=" * 80
  exit 1
end
