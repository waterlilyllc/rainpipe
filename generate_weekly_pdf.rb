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

  # PDF内容検証
  puts "🔍 PDF内容を検証中..."
  pdf_text = `pdftotext "#{output_path}" - 2>/dev/null`

  has_keywords = pdf_text.include?('Claude Code') || pdf_text.include?('AI') || pdf_text.lines.any? { |l| l.match?(/^[A-Za-z\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FAF]+$/) && l.strip.length > 1 }
  has_insights = pdf_text.include?('WEEKLY INSIGHTS')
  has_peripheral = pdf_text.include?('PERIPHERAL KEYWORDS')
  has_toc = pdf_text.include?('TABLE OF CONTENTS')

  puts "   ✓ 表紙キーワード: #{has_keywords ? 'あり' : 'なし'}"
  puts "   ✓ WEEKLY INSIGHTS: #{has_insights ? 'あり' : 'なし'}"
  puts "   ✓ PERIPHERAL KEYWORDS: #{has_peripheral ? 'あり' : 'なし'}"
  puts "   ✓ TABLE OF CONTENTS: #{has_toc ? 'あり' : 'なし'}"
  puts ""

  unless has_insights && has_peripheral
    puts "⚠️  サマリーセクションが不完全です。再生成を試みます..."
    puts ""

    # サマリーファイルを削除して再生成
    summary_file = "./data/weekly_summaries/summary_#{week_start.strftime('%Y-%m-%d')}.json"
    if File.exist?(summary_file)
      File.delete(summary_file)
      puts "   サマリーファイルを削除: #{summary_file}"
    end

    # PDF再生成
    output_path = generator.generate_weekly_pdf(week_start, week_end, nil)
    puts ""
    puts "✅ PDF再生成完了！"
    puts "   ファイル: #{output_path}"

    # 再検証
    pdf_text = `pdftotext "#{output_path}" - 2>/dev/null`
    has_insights = pdf_text.include?('WEEKLY INSIGHTS')
    has_peripheral = pdf_text.include?('PERIPHERAL KEYWORDS')

    puts "   ✓ WEEKLY INSIGHTS: #{has_insights ? 'あり' : 'なし'}"
    puts "   ✓ PERIPHERAL KEYWORDS: #{has_peripheral ? 'あり' : 'なし'}"

    unless has_insights && has_peripheral
      puts ""
      puts "❌ サマリーセクションの生成に失敗しました"
      exit 1
    end
  end

  puts "✅ PDF検証完了！"
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
