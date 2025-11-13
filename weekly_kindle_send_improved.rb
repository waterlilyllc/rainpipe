#!/usr/bin/env ruby
# 毎週Kindleに週次ブックマークレポートを送信（改善版）
# 1. サマリーなし記事の再取得
# 2. 週間サマリーの再生成
# 3. 周辺キーワードの追加

require 'dotenv/load'
require 'json'
require 'fileutils'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'kindle_email_sender'
require_relative 'weekly_summary_generator'

puts "=" * 80
puts "📧 Weekly Kindle Report Generator - Improved Edition"
puts "Time: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
puts "=" * 80
puts ""

# 初期化
client = RaindropClient.new
content_manager = BookmarkContentManager.new
email_sender = KindleEmailSender.new
summary_generator = WeeklySummaryGenerator.new

# ========================================
# STEP 1: 先週のブックマークを取得
# ========================================
puts "📚 Step 1: Loading bookmarks..."

all_bookmarks = client.load_all_bookmarks

# 先週の期間を計算
today = Date.today
current_week_start = today - today.wday
last_week_start = current_week_start - 7
last_week_end = current_week_start - 1

week_start_time = Time.new(last_week_start.year, last_week_start.month, last_week_start.day, 0, 0, 0)
week_end_time = Time.new(last_week_end.year, last_week_end.month, last_week_end.day, 23, 59, 59)

last_week_bookmarks = all_bookmarks.select do |bookmark|
  created_time = Time.parse(bookmark['created'])
  created_time >= week_start_time && created_time <= week_end_time
end.sort_by { |b| Time.parse(b['created']) }.reverse

puts "✓ 先週のブックマーク: #{last_week_bookmarks.length}件"
puts "  期間: #{last_week_start.strftime('%Y-%m-%d')} ～ #{last_week_end.strftime('%Y-%m-%d')}"
puts ""

# ========================================
# STEP 2: サマリーなし記事を再取得
# ========================================
puts "📥 Step 2: Re-fetching missing summaries..."

missing_count = 0
last_week_bookmarks.each do |bookmark|
  content_data = content_manager.get_content(bookmark['_id'])
  unless content_data && content_data.is_a?(Hash) && content_data['content']
    missing_count += 1
    puts "  ⚠️  Missing: #{bookmark['title'][0..50]}..."
  end
end

if missing_count > 0
  puts "✓ #{missing_count}件のサマリーが足りません"
  puts "  処理: refresh_last_week_missing.rb を実行してください"
  puts ""
else
  puts "✓ すべてのブックマークにサマリーがあります"
  puts ""
end

# ========================================
# STEP 3: 週間サマリーを再生成
# ========================================
puts "🔄 Step 3: Regenerating weekly summary..."

week_start_str = last_week_start.strftime('%Y-%m-%d')
week_end_str = last_week_end.strftime('%Y-%m-%d')

begin
  # 古いサマリーを削除
  summary_file = "./data/weekly_summaries/summary_#{week_start_str}.json"
  File.delete(summary_file) if File.exist?(summary_file)
  
  # 新しいサマリーを生成
  summary_data = summary_generator.generate_weekly_summary(week_start_str)
  
  if summary_data
    puts "✓ 週間サマリーを再生成しました"
    
    # latest.json を更新
    latest_path = './data/weekly_summaries/latest.json'
    File.write(latest_path, JSON.pretty_generate(summary_data))
    puts "✓ latest.json を更新しました"
  else
    puts "⚠️ サマリー生成に失敗しました"
  end
rescue => e
  puts "❌ エラー: #{e.message}"
end

puts ""

# ========================================
# STEP 4: 周辺キーワードを抽出
# ========================================
puts "🔍 Step 4: Extracting peripheral keywords..."

begin
  require_relative 'gpt_keyword_extractor'
  
  extractor = GPTKeywordExtractor.new
  week_key = "#{week_start_str}～#{week_end_str}"
  
  analysis = extractor.extract_keywords_from_bookmarks(last_week_bookmarks, week_key)
  
  if analysis && analysis['related_clusters']
    puts "✓ 周辺キーワード: #{analysis['related_clusters'].length}個"
    analysis['related_clusters'].each do |cluster|
      puts "  - #{cluster['main_topic']}: #{cluster['related_words'].join(', ')}"
    end
  else
    puts "⚠️ 周辺キーワードの抽出に失敗しました"
  end
rescue => e
  puts "⚠️ 周辺キーワード抽出スキップ: #{e.message}"
end

puts ""

# ========================================
# STEP 5: Kindleレポートを生成＆送信
# ========================================
puts "=" * 80
puts "📧 Sending to Kindle"
puts "=" * 80
puts ""

begin
  require_relative 'generate_last_week_final'
  
  puts "✅ Report sent successfully to Kindle"
rescue => e
  puts "❌ エラーが発生しました: #{e.message}"
end

puts ""
puts "=" * 80
puts "✓ 処理完了"
puts "=" * 80
