#!/usr/bin/env ruby
require 'date'
require 'dotenv'
Dotenv.load

require_relative 'keyword_filtered_pdf_service'
require_relative 'gpt_content_generator'
require_relative 'keyword_pdf_generator'

puts "🔍 Obsidian キーワードで PDF 生成テスト開始"
puts "=" * 60

# キーワード、日付範囲を設定
keywords = "Obsidian"
date_start = (Date.today - 90).to_s  # 3ヶ月前
date_end = Date.today.to_s

puts "📝 キーワード: #{keywords}"
puts "📅 期間: #{date_start} ～ #{date_end}"

begin
  # Task 3: KeywordFilteredPDFService でフィルタリング + Gatherly 本文取得 + サマリー生成
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

  if with_summary.any?
    puts "\n📝 サマリー例（最初のブックマーク）:"
    first_with_summary = with_summary.first
    puts "タイトル: #{first_with_summary['title']}"
    puts "サマリー: #{first_with_summary['summary'][0..200]}..."
  end

  # Task 5: GPT コンテンツ生成
  gpt_generator = GPTContentGenerator.new(ENV['OPENAI_API_KEY'], false)
  summary_result = gpt_generator.generate_overall_summary(filtered_bookmarks, keywords)
  keywords_result = gpt_generator.extract_related_keywords(filtered_bookmarks)
  analysis_result = gpt_generator.generate_analysis(filtered_bookmarks, keywords)

  puts "\n✅ GPT コンテンツ生成完了"

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
  output_path = File.join('data', "test_obsidian_#{Time.now.utc.strftime('%Y%m%d_%H%M%S')}.pdf")
  pdf_result = pdf_generator.generate(pdf_content, output_path)

  puts "\n✅ PDF 生成完了"
  puts "📄 ファイルパス: #{pdf_result[:pdf_path]}"
  puts "⏱️  生成時間: #{pdf_result[:duration_ms]} ms"
  puts "💾 ファイルサイズ: #{(pdf_result[:file_size] / 1024.0).round(2)} KB"

rescue => e
  puts "❌ エラー発生: #{e.message}"
  puts e.backtrace[0..10].join("\n")
  exit 1
end
