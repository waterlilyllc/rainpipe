#!/usr/bin/env ruby

require 'dotenv/load'
require 'date'
require_relative 'bookmark_exporter'
require_relative 'raindrop_client'

puts "🧪 Obsidian Export テスト"
puts "=" * 50

# 環境変数チェック
unless ENV['OBSIDIAN_VAULT_PATH']
  puts "❌ エラー: Obsidian設定が見つかりません"
  puts "必要: OBSIDIAN_VAULT_PATH"
  exit 1
end

puts "✅ Obsidian Vault Path: #{ENV['OBSIDIAN_VAULT_PATH']}"

# パスの存在確認
unless Dir.exist?(ENV['OBSIDIAN_VAULT_PATH'])
  puts "⚠️  警告: Obsidian Vaultディレクトリが存在しません"
  puts "ディレクトリを作成しますか？ (y/n)"
  # 自動で作成を試みる
end

# テスト用ブックマークを取得
client = RaindropClient.new
all_bookmarks = client.send(:load_all_bookmarks)

# エンタメ系のブックマークを1つ探す
test_bookmark = all_bookmarks.find do |b|
  b['tags'] && (b['tags'].include?('entertainment') || b['tags'].include?('lifestyle'))
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
puts "\n🚀 Obsidianへエクスポート中..."
exporter = BookmarkExporter.new
result = exporter.export_to_obsidian(test_bookmark)

if result[:success]
  puts "✅ 成功！"
  puts "ファイルパス: #{result[:filepath]}"
  puts "\n📝 作成されたファイルを確認してください"
else
  puts "❌ エクスポート失敗"
  puts "エラー: #{result[:error]}"
end