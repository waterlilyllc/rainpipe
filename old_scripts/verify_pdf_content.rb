#!/usr/bin/env ruby
$stdout.sync = true

require 'dotenv/load'
require 'sqlite3'
require 'json'

puts "=" * 80
puts "PDF内容検証"
puts "=" * 80
puts ""

# 1. データベース内の本文を確認
db = SQLite3::Database.new('data/rainpipe.db')
db.results_as_hash = true

raindrop_ids = [1428543902, 1428368854]

puts "📊 データベース内の本文状況:"
puts ""

raindrop_ids.each do |id|
  content = db.get_first_row("SELECT * FROM bookmark_contents WHERE raindrop_id = ?", id)

  if content
    puts "✅ ID: #{id}"
    puts "   タイトル: #{content['title'][0..50]}..."
    puts "   本文長: #{content['content']&.length || 0}文字"
    puts "   取得日時: #{content['extracted_at']}"
  else
    puts "❌ ID: #{id} - 本文なし"
  end
  puts ""
end

puts "=" * 80
puts ""

# 2. 週次サマリーの内容を確認
summary_file = './data/weekly_summaries/summary_2025-11-09.json'

if File.exist?(summary_file)
  summary = JSON.parse(File.read(summary_file))

  puts "📊 週次サマリー内容:"
  puts ""
  puts "  期間: #{summary['week_start']} - #{summary['week_end']}"
  puts "  生成日時: #{summary['generated_at']}"
  puts ""

  if summary['keywords'] && summary['keywords'].any?
    puts "  キーワード数: #{summary['keywords'].length}"
    summary['keywords'].each do |keyword, data|
      puts "    - #{keyword}: #{data['article_count']}記事"
    end
  else
    puts "  ⚠️  キーワードなし"
  end
  puts ""

  if summary['related_clusters'] && summary['related_clusters'].any?
    puts "  周辺キーワード: #{summary['related_clusters'].length}個"
    summary['related_clusters'].each do |cluster|
      puts "    - #{cluster['main_topic']}: #{cluster['related_words'].join(', ')}"
    end
  else
    puts "  ⚠️  周辺キーワードなし"
  end
  puts ""

  if summary['overall_insights']
    puts "  総括あり: #{summary['overall_insights'][0..80]}..."
  else
    puts "  ⚠️  総括なし"
  end
else
  puts "❌ サマリーファイルが見つかりません: #{summary_file}"
end

puts ""
puts "=" * 80
puts ""

# 3. PDFファイルの確認
pdf_file = 'data/weekly_summary_20251109.pdf'

if File.exist?(pdf_file)
  size_kb = File.size(pdf_file) / 1024
  puts "📄 PDFファイル: #{pdf_file}"
  puts "   サイズ: #{size_kb}KB"
  puts "   生成日時: #{File.mtime(pdf_file)}"

  # PDF情報を取得
  info = `file "#{pdf_file}"`.strip
  puts "   形式: #{info.split(':')[1]&.strip}"
else
  puts "❌ PDFファイルが見つかりません: #{pdf_file}"
end

puts ""
puts "=" * 80
