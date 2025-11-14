#!/usr/bin/env ruby
require 'dotenv'
Dotenv.load

require 'date'
require_relative 'progress_reporter'
require_relative 'keyword_filtered_pdf_service'
require_relative 'gpt_content_generator'
require_relative 'keyword_pdf_generator'
require_relative 'kindle_email_sender'

puts "🔍 Obsidian キーワードで PDF 生成・Kindle 送信テスト"
puts "=" * 60

# キーワード、日付範囲を設定
keywords = "Obsidian"
date_start = (Date.today - 90).to_s
date_end = Date.today.to_s

puts "📝 キーワード: #{keywords}"
puts "📅 期間: #{date_start} ～ #{date_end}"

# PDF検証メソッド
def validate_pdf(pdf_path, bookmarks)
  # ファイルが存在するか確認
  unless File.exist?(pdf_path)
    puts "❌ PDFファイルが見つかりません: #{pdf_path}"
    raise "PDF validation failed"
  end

  # ファイルサイズを確認
  file_size = File.size(pdf_path)
  file_size_mb = file_size / (1024 * 1024.0)

  puts "✅ ファイルが存在します"
  puts "📏 ファイルサイズ: #{file_size_mb.round(2)} MB"

  # ファイルサイズ制限チェック（Kindle送信上限は25MB）
  if file_size_mb > 25
    puts "❌ ファイルサイズが大きすぎます（最大25MB）"
    raise "PDF file size exceeds limit"
  elsif file_size_mb > 20
    puts "⚠️  ファイルサイズが大きめです（20MB超過）"
  else
    puts "✅ ファイルサイズは正常範囲内です"
  end

  # ブックマークの要約有無を確認
  with_summary = bookmarks.select { |b| b['summary'] && b['summary'].to_s.strip.length > 10 }
  without_summary = bookmarks.select { |b| !b['summary'] || b['summary'].to_s.strip.length <= 10 }

  puts "📊 ブックマーク要約確認: #{with_summary.length}/#{bookmarks.length} 件に要約がります"

  if without_summary.length > 0
    puts "⚠️  #{without_summary.length} 件のブックマークに要約がありません"
    without_summary.each do |b|
      puts "   - #{b['title']}"
    end
  end

  puts "✅ PDF検証完了 - メール送信準備完了"
end

begin
  # Task 3: KeywordFilteredPDFService でフィルタリング + Gatherly 本文取得
  service = KeywordFilteredPDFService.new(
    keywords: keywords,
    date_start: date_start,
    date_end: date_end
  )

  result = service.execute

  if result[:status] == 'error'
    puts "❌ エラー: #{result[:error]}"
    exit 1
  end

  filtered_bookmarks = result[:bookmarks]
  puts "✅ フィルタリング完了: #{filtered_bookmarks.length} 件"

  # サマリーの状態を確認
  with_summary = filtered_bookmarks.select { |b| b['summary'] && b['summary'] != '（サマリー未取得）' }
  without_summary = filtered_bookmarks.select { |b| !b['summary'] || b['summary'] == '（サマリー未取得）' }

  puts "📊 サマリー状態: #{with_summary.length} 件取得済み, #{without_summary.length} 件未取得"

  # Task 5: GPT コンテンツ生成
  gpt_generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], false)
  summary_result = gpt_generator.generate_overall_summary(filtered_bookmarks, keywords)
  keywords_result = gpt_generator.extract_related_keywords(filtered_bookmarks)
  analysis_result = gpt_generator.generate_analysis(filtered_bookmarks, keywords)

  puts "✅ GPT コンテンツ生成完了"

  # Task 6: PDF 生成
  pdf_content = {
    overall_summary: summary_result[:summary],
    summary: summary_result[:summary],
    related_clusters: keywords_result[:related_clusters],
    analysis: analysis_result[:analysis],
    bookmarks: filtered_bookmarks,
    keywords: keywords,
    date_range: result[:date_range]
  }

  pdf_generator = KeywordPDFGenerator.new
  output_path = File.join('data', "obsidian_final_#{Time.now.utc.strftime('%Y%m%d_%H%M%S')}.pdf")
  pdf_result = pdf_generator.generate(pdf_content, output_path)

  puts "✅ PDF 生成完了"
  puts "📄 ファイルパス: #{pdf_result[:pdf_path]}"
  puts "💾 ファイルサイズ: #{(pdf_result[:file_size] / 1024.0).round(2)} KB"

  # PDF検証：ファイルサイズとシェアの確認
  puts "\n📋 PDF 検証中..."
  validate_pdf(pdf_result[:pdf_path], filtered_bookmarks)

  # Task 8.3: Kindle メール送信
  puts "\n📧 Kindle メール送信中..."
  email_sender = KindleEmailSender.new
  send_result = email_sender.send_pdf(pdf_result[:pdf_path], subject: "Obsidian キーワード検索 PDF")

  if send_result
    puts "✅ Kindle メール送信成功！"
    puts "🎉 完了！PDF が terubi_z_wp@kindle.com に送信されました"
  else
    puts "❌ Kindle メール送信に失敗しました"
    exit 1
  end

rescue => e
  puts "❌ エラー発生: #{e.message}"
  puts e.backtrace[0..5].join("\n")
  exit 1
end
