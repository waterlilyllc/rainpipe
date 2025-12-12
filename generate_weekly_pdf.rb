#!/usr/bin/env ruby
# 先週のブックマークをPDFにまとめてKindleに送信
# 実行: ruby generate_weekly_pdf.rb
# cron: 0 9 * * 1  # 毎週月曜9時に実行

require 'dotenv/load'
require_relative 'weekly_pdf_generator'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "📄 週間ブックマークPDF生成 & Kindle送信"
puts "=" * 80
puts ""

generator = WeeklyPDFGenerator.new

begin
  puts "📅 先週のブックマークを集計中..."

  # 先週の期間を計算（月曜開始）
  today = Date.today
  this_monday = today - (today.wday - 1) % 7  # 今週の月曜
  last_monday = this_monday - 7                # 先週の月曜
  last_sunday = last_monday + 6                # 先週の日曜
  week_start = last_monday
  week_end = last_sunday

  puts "   期間: #{week_start.strftime('%Y/%m/%d')} - #{week_end.strftime('%Y/%m/%d')}"
  puts ""

  # PDF生成
  output_path = generator.generate_last_week_pdf

  puts "✅ PDF生成完了！"
  puts "   ファイル: #{output_path}"
  puts "   サイズ: #{File.size(output_path) / 1024}KB"
  puts ""

  # ファイル情報
  file_info = `file "#{output_path}"`.strip
  puts "   詳細: #{file_info}"
  puts ""

  # Kindleに送信
  if ENV['GMAIL_ADDRESS'] && ENV['GMAIL_APP_PASSWORD'] && ENV['KINDLE_EMAIL']
    puts "=" * 80
    sender = KindleEmailSender.new
    subject = "週間ブックマーク #{week_start.strftime('%m/%d')}-#{week_end.strftime('%m/%d')}"

    if sender.send_pdf(output_path, subject: subject)
      puts "=" * 80
      puts "✅ 全ての処理が完了しました！"
    else
      puts "=" * 80
      puts "⚠️  PDF生成は成功しましたが、メール送信に失敗しました"
      exit 1
    end
  else
    puts "⚠️  メール設定が不完全なため、送信をスキップしました"
    puts "   設定方法: .env.example を参照"
  end

rescue => e
  puts "❌ エラー発生: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

puts ""
puts "=" * 80
