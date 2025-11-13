#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'gatherly_client'
require_relative 'bookmark_content_manager'

puts "🧪 Gatherly統合テスト開始\n\n"

# 1. GatherlyClient のテスト
puts "=" * 60
puts "1. GatherlyClient のテスト"
puts "=" * 60

begin
  client = GatherlyClient.new
  puts "✅ GatherlyClient インスタンス作成成功"
  puts "   API URL: #{client.api_base_url}"
  puts "   API Key: #{client.api_key[0..10]}..." if client.api_key
rescue => e
  puts "❌ GatherlyClient インスタンス作成失敗: #{e.message}"
  exit 1
end

# 2. テスト用URLでクロールジョブ作成
puts "\n" + "=" * 60
puts "2. クロールジョブ作成テスト"
puts "=" * 60

test_url = 'https://example.com'
puts "テストURL: #{test_url}"

result = client.create_crawl_job(test_url)

if result[:error]
  puts "⚠️ ジョブ作成エラー: #{result[:error]}"
  puts "   詳細: #{result[:body]}"
  puts "\n💡 Gatherly APIが起動していない可能性があります"
else
  puts "✅ ジョブ作成成功"
  puts "   Job ID: #{result[:job_uuid]}"

  job_id = result[:job_uuid]

  # 3. ジョブステータス確認
  puts "\n" + "=" * 60
  puts "3. ジョブステータス確認"
  puts "=" * 60

  sleep 1 # API負荷軽減
  status_result = client.get_job_status(job_id)

  if status_result[:error]
    puts "⚠️ ステータス取得エラー: #{status_result[:error]}"
  else
    puts "✅ ステータス取得成功"
    puts "   Status: #{status_result[:status]}"
    puts "   Error: #{status_result[:error] || 'なし'}"
  end
end

# 4. BookmarkContentManager のテスト
puts "\n" + "=" * 60
puts "4. BookmarkContentManager のテスト"
puts "=" * 60

begin
  manager = BookmarkContentManager.new
  puts "✅ BookmarkContentManager インスタンス作成成功"

  # 統計情報取得
  stats = manager.get_stats
  puts "\n📊 データベース統計:"
  puts "   総本文数: #{stats[:total_contents]}"
  puts "   平均文字数: #{stats[:avg_word_count] || 'N/A'}"
  puts "   最近1週間の取得数: #{stats[:recent_week_count]}"

  # テストデータ保存
  puts "\n" + "-" * 60
  puts "テストデータ保存"
  puts "-" * 60

  test_raindrop_id = 999999
  test_data = {
    url: 'https://example.com/test',
    title: 'テスト記事',
    content: 'これはテスト用の本文です。',
    content_type: 'text',
    word_count: 15
  }

  success = manager.save_content(test_raindrop_id, test_data)
  if success
    puts "✅ テストデータ保存成功"

    # データ取得テスト
    retrieved = manager.get_content(test_raindrop_id)
    if retrieved
      puts "✅ データ取得成功"
      puts "   Title: #{retrieved['title']}"
      puts "   Word Count: #{retrieved['word_count']}"
    else
      puts "❌ データ取得失敗"
    end

    # 存在確認テスト
    exists = manager.content_exists?(test_raindrop_id)
    puts "✅ 存在確認: #{exists ? 'あり' : 'なし'}"
  else
    puts "❌ テストデータ保存失敗"
  end

  manager.close
rescue => e
  puts "❌ BookmarkContentManager テスト失敗: #{e.message}"
  puts e.backtrace.first(5).join("\n")
end

puts "\n" + "=" * 60
puts "✅ テスト完了"
puts "=" * 60
