#!/usr/bin/env ruby
$stdout.sync = true

require 'dotenv/load'
require 'date'
require_relative 'weekly_pdf_generator'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "📄 週間ブックマークPDF生成（コンテンツフェッチスキップ）"
puts "=" * 80
puts ""

generator = WeeklyPDFGenerator.new

# 先週の期間
today = Date.today
last_sunday = today - today.wday
week_end = last_sunday - 1
week_start = week_end - 6

puts "📅 期間: #{week_start.strftime('%Y/%m/%d')} - #{week_end.strftime('%Y/%m/%d')}"
puts ""

# コンテンツフェッチをスキップするため、enrich_bookmarks_with_contentを呼ばない
# 代わりに直接PDFを生成
output_path = generator.generate_weekly_pdf(week_start, week_end)

puts "✅ PDF生成完了！"
puts "   ファイル: #{output_path}"
puts "   サイズ: #{File.size(output_path) / 1024}KB"
puts ""

# Kindleに送信
if ENV['GMAIL_ADDRESS'] && ENV['GMAIL_APP_PASSWORD'] && ENV['KINDLE_EMAIL']
  sender = KindleEmailSender.new
  subject = "週間ブックマーク #{week_start.strftime('%m/%d')}-#{week_end.strftime('%m/%d')}"

  if sender.send_pdf(output_path, subject: subject)
    puts "✅ Kindle送信成功！"
  else
    puts "⚠️  PDF生成は成功しましたが、メール送信に失敗しました"
  end
end

puts "=" * 80
