#!/usr/bin/env ruby

require 'dotenv/load'
require 'date'
require_relative 'bookmark_exporter'
require_relative 'raindrop_client'

puts "🧪 Notion Export テスト"
puts "=" * 50

# 環境変数チェック
unless ENV['NOTION_API_KEY'] && ENV['NOTION_DATABASE_ID']
  puts "❌ エラー: Notion設定が見つかりません"
  puts "必要: NOTION_API_KEY, NOTION_DATABASE_ID"
  exit 1
end

puts "✅ Notion API Key: #{ENV['NOTION_API_KEY'][0..15]}..."
puts "✅ Notion Database ID: #{ENV['NOTION_DATABASE_ID']}"

# テスト用ブックマークを取得
client = RaindropClient.new
all_bookmarks = client.send(:load_all_bookmarks)

# プログラミング系のブックマークを1つ探す
test_bookmark = all_bookmarks.find do |b|
  b['tags'] && (b['tags'].include?('programming') || b['tags'].include?('dev-tools'))
end

unless test_bookmark
  # なければ最新のブックマークを使用
  test_bookmark = all_bookmarks.first
end

if test_bookmark.nil?
  puts "❌ テスト用ブックマークが見つかりません"
  exit 1
end

puts "\n📌 テストブックマーク:"
puts "タイトル: #{test_bookmark['title']}"
puts "URL: #{test_bookmark['link']}"
puts "タグ: #{test_bookmark['tags']&.join(', ') || 'なし'}"
puts "作成日: #{test_bookmark['created']}"

# エクスポート実行
puts "\n🚀 Notionへエクスポート中..."
exporter = BookmarkExporter.new
result = exporter.export_to_notion(test_bookmark)

if result[:success]
  puts "✅ 成功！"
  puts "Notion Page ID: #{result[:notion_page_id]}"
  puts "\n📝 Notionデータベースを確認してください:"
  puts "https://www.notion.so/#{ENV['NOTION_DATABASE_ID'].gsub('-', '')}"
else
  puts "❌ エクスポート失敗"
  puts "エラー: #{result[:error]}"
end