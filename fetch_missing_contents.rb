#!/usr/bin/env ruby
# 最新20件で本文未取得のブックマークを取得

require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'bookmark_content_fetcher'

puts "=" * 80
puts "📚 最新20件の本文未取得ブックマークを取得"
puts "=" * 80
puts ""

client = RaindropClient.new
content_manager = BookmarkContentManager.new
fetcher = BookmarkContentFetcher.new

# 最新のブックマークJSONを読み込み
all_bookmarks = client.load_all_bookmarks

# 最新20件
recent_20 = all_bookmarks.first(20)

puts "📋 最新20件のブックマーク:"
puts ""

# 本文の有無を確認
missing_contents = []

recent_20.each_with_index do |bookmark, index|
  raindrop_id = bookmark['_id']
  title = bookmark['title']
  url = bookmark['link']

  # 本文データを確認
  content = content_manager.get_content(raindrop_id)

  status = content ? "✅ あり" : "❌ なし"
  puts "#{index + 1}. [#{status}] #{title}"

  if !content && url && !url.empty?
    missing_contents << {
      raindrop_id: raindrop_id,
      title: title,
      url: url
    }
  end
end

puts ""
puts "=" * 80
puts "📊 結果"
puts "=" * 80
puts "総数: #{recent_20.length}件"
puts "本文あり: #{recent_20.length - missing_contents.length}件"
puts "本文なし: #{missing_contents.length}件"
puts ""

if missing_contents.empty?
  puts "✅ 全て本文が取得済みです！"
  exit 0
end

puts "📥 本文未取得のブックマークを取得します..."
puts ""

job_count = 0
missing_contents.each_with_index do |item, index|
  puts "[#{index + 1}/#{missing_contents.length}] #{item[:title]}"
  puts "   URL: #{item[:url]}"

  begin
    job_uuid = fetcher.fetch_content(item[:raindrop_id], item[:url])

    if job_uuid
      puts "   ✅ ジョブ作成: #{job_uuid}"
      job_count += 1
    else
      puts "   ⚠️ ジョブ作成スキップ（既存または失敗）"
    end
  rescue => e
    puts "   ❌ エラー: #{e.message}"
  end

  # API制限対策
  sleep 1
  puts ""
end

puts "=" * 80
puts "✅ 完了"
puts "=" * 80
puts "作成したジョブ: #{job_count}件"
puts ""
puts "💡 本文は数分後に取得されます。"
puts "   確認: ruby process_content_jobs.rb"
puts "=" * 80
