#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'date'
require_relative 'auto_tagger'

puts "🏷️ 既存データ自動タグ付けスクリプト"
puts "=" * 50

# APIキーチェック
unless ENV['OPENAI_API_KEY'] && ENV['RAINDROP_API_TOKEN']
  puts "❌ エラー: 必要な環境変数が設定されていません"
  puts "必要: OPENAI_API_KEY, RAINDROP_API_TOKEN"
  exit 1
end

# データ読み込み
data_file = './data/all_bookmarks_20250708_092315.json'
unless File.exist?(data_file)
  puts "❌ データファイルが見つかりません: #{data_file}"
  exit 1
end

puts "📚 データ読み込み中..."
all_bookmarks = JSON.parse(File.read(data_file))

# 2025年のデータのみ抽出
bookmarks_2025 = all_bookmarks.select do |bookmark|
  created_date = Date.parse(bookmark['created'])
  created_date.year == 2025
end

puts "📅 2025年ブックマーク: #{bookmarks_2025.length} 件"

# タグが未設定のもののみ処理
untagged_bookmarks = bookmarks_2025.select do |bookmark|
  bookmark['tags'].nil? || bookmark['tags'].empty?
end

puts "🏷️ タグ未設定: #{untagged_bookmarks.length} 件"

if untagged_bookmarks.empty?
  puts "✅ 全てのブックマークにタグが設定済みです"
  exit 0
end

# 確認プロンプト
puts "\n⚠️ この処理は以下を実行します:"
puts "  1. #{untagged_bookmarks.length}件のブックマークにChatGPTでタグ生成"
puts "  2. Raindrop.io APIでタグを更新"
puts "  3. ローカルデータファイルも更新"
puts "\n🚀 自動実行を開始します..."

# 自動タグ付け実行
puts "\n🤖 自動タグ付け開始..."
auto_tagger = AutoTagger.new

tagged_count = 0
failed_count = 0
processed_count = 0

untagged_bookmarks.each_with_index do |bookmark, index|
  processed_count += 1
  
  puts "\n[#{processed_count}/#{untagged_bookmarks.length}] 処理中..."
  puts "タイトル: #{bookmark['title'][0..80]}..."
  
  begin
    result = auto_tagger.process_bookmark_with_tags(bookmark)
    
    if result[:success]
      tagged_count += 1
      puts "✅ 成功: #{result[:tags].join(', ')}"
    else
      failed_count += 1
      puts "❌ 失敗: #{result[:error] || '不明なエラー'}"
    end
    
  rescue => e
    failed_count += 1
    puts "❌ 例外エラー: #{e.message}"
  end
  
  # API制限対策（OpenAI: 3 RPM、Raindrop: 120 RPM）
  if processed_count < untagged_bookmarks.length
    puts "⏱️ 待機中... (API制限対策)"
    sleep(20) # 20秒待機
  end
  
  # 10件ごとに進捗保存
  if processed_count % 10 == 0
    puts "\n💾 中間保存中..."
    backup_filename = "./data/tagged_backup_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(backup_filename, JSON.pretty_generate(all_bookmarks))
    puts "バックアップ保存: #{backup_filename}"
  end
end

# 最終結果保存
puts "\n💾 最終データ保存中..."
final_filename = "./data/all_bookmarks_tagged_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
File.write(final_filename, JSON.pretty_generate(all_bookmarks))

puts "\n🎉 自動タグ付け完了!"
puts "=" * 50
puts "📊 処理結果:"
puts "  処理件数: #{processed_count} 件"
puts "  成功: #{tagged_count} 件"
puts "  失敗: #{failed_count} 件"
puts "  成功率: #{((tagged_count.to_f / processed_count) * 100).round(1)}%"
puts "\n💾 更新ファイル: #{final_filename}"

if failed_count > 0
  puts "\n⚠️ 失敗したブックマークは手動で確認してください"
end