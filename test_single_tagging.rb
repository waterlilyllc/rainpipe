#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'date'
require_relative 'auto_tagger'

puts "🏷️ 単体タグ付けテスト"
puts "=" * 30

# データ読み込み
data = JSON.parse(File.read('./data/all_bookmarks_20250708_092315.json'))

# 2025年の最新のブックマークを1件取得
test_bookmark = data.select do |bookmark|
  created_date = Date.parse(bookmark['created'])
  created_date.year == 2025
end.first

if test_bookmark.nil?
  puts "❌ 2025年のブックマークが見つかりません"
  exit 1
end

puts "\n📄 テスト対象ブックマーク:"
puts "タイトル: #{test_bookmark['title']}"
puts "URL: #{test_bookmark['link']}"
puts "ID: #{test_bookmark['_id']}"
puts "既存タグ: #{test_bookmark['tags'] || '未設定'}"

puts "\n🤖 自動タグ付け開始..."

begin
  auto_tagger = AutoTagger.new
  
  # タグ生成のみテスト（Raindrop更新はしない）
  puts "\n1️⃣ タグ生成テスト:"
  tags = auto_tagger.generate_tags(test_bookmark)
  
  if tags.any?
    puts "✅ タグ生成成功: #{tags.join(', ')}"
    
    puts "\n2️⃣ Raindrop.io 更新テスト:"
    success = auto_tagger.update_bookmark_tags(test_bookmark['_id'], tags)
    
    if success
      puts "✅ Raindrop.io 更新成功"
      
      # ローカルデータも更新
      test_bookmark['tags'] = tags
      puts "✅ ローカルデータ更新成功"
      
      puts "\n🎉 完全なタグ付けテスト成功！"
      puts "設定されたタグ: #{tags.join(', ')}"
      
    else
      puts "❌ Raindrop.io 更新失敗"
    end
    
  else
    puts "❌ タグ生成失敗"
  end
  
rescue => e
  puts "❌ エラー発生: #{e.class}: #{e.message}"
  puts "スタックトレース:"
  puts e.backtrace.first(5)
end

puts "\n📝 テスト完了"