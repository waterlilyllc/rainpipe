#!/usr/bin/env ruby
# 先週のブックマークで要約が無いものを再取得

require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'bookmark_content_fetcher'

puts "=" * 80
puts "📅 先週のブックマーク - 要約がないものを再取得"
puts "=" * 80
puts ""

client = RaindropClient.new
content_manager = BookmarkContentManager.new
fetcher = BookmarkContentFetcher.new

# 最新のブックマークをロード
all_bookmarks = client.load_all_bookmarks

puts "📚 ブックマーク総数: #{all_bookmarks.length}件"
puts ""

# 先週の期間を計算（日曜日から土曜日まで）
today = Date.today
current_week_start = today - today.wday  # 今週の日曜日
last_week_start = current_week_start - 7  # 先週の日曜日
last_week_end = current_week_start - 1    # 先週の土曜日

week_start_time = Time.new(last_week_start.year, last_week_start.month, last_week_start.day, 0, 0, 0)
week_end_time = Time.new(last_week_end.year, last_week_end.month, last_week_end.day, 23, 59, 59)

puts "📅 対象期間: #{last_week_start.strftime('%Y-%m-%d')}（日） ～ #{last_week_end.strftime('%Y-%m-%d')}（土）"
puts ""

# 先週のブックマークで要約がないものを検索
last_week_bookmarks = []
last_week_with_content = 0
missing_in_week = []

all_bookmarks.each do |bookmark|
  created_time = Time.parse(bookmark['created'])
  next if created_time < week_start_time || created_time > week_end_time

  raindrop_id = bookmark['_id']
  title = bookmark['title']
  url = bookmark['link']

  last_week_bookmarks << bookmark

  # 本文データを確認
  content = content_manager.get_content(raindrop_id)

  if content
    last_week_with_content += 1
  elsif url && !url.empty? && !content_manager.fetch_failed?(raindrop_id)
    missing_in_week << {
      raindrop_id: raindrop_id,
      title: title,
      url: url,
      created: created_time
    }
  end
end

puts "📊 結果分析"
puts "-" * 80
puts "先週のブックマーク: #{last_week_bookmarks.length}件"
puts "  - 要約あり: #{last_week_with_content}件"
puts "  - 要約なし（再取得対象）: #{missing_in_week.length}件"
puts ""

if missing_in_week.empty?
  puts "✅ 先週のブックマークは全て要約があります！"
  exit 0
end

# 再取得対象を時系列で表示
puts "🔍 再取得対象のブックマーク"
puts "-" * 80
missing_in_week.sort_by { |x| x[:created] }.reverse.each_with_index do |item, idx|
  puts "#{idx + 1}. #{item[:title][0..50]}..."
  puts "   URL: #{item[:url][0..60]}..."
  puts "   作成: #{item[:created].strftime('%Y-%m-%d %H:%M')}"
  puts ""
end

puts "=" * 80
puts "📥 本文を再取得します..."
puts "=" * 80
puts ""

jobs_created = 0
jobs_skipped = 0

missing_in_week.each_with_index do |item, index|
  puts "[#{index + 1}/#{missing_in_week.length}] #{item[:title][0..40]}..."
  puts "   URL: #{item[:url]}"

  raindrop_id = item[:raindrop_id]
  url = item[:url]

  begin
    job_uuid = fetcher.fetch_content(raindrop_id, url)

    if job_uuid
      puts "   ✅ ジョブ作成: #{job_uuid}"
      jobs_created += 1
    else
      puts "   ⚠️ ジョブ作成スキップ"
      jobs_skipped += 1
    end
  rescue => e
    puts "   ❌ エラー: #{e.message}"
    jobs_skipped += 1
  end

  # API制限対策
  sleep 0.5
  puts ""
end

puts "=" * 80
puts "✅ 再取得ジョブ作成完了"
puts "=" * 80
puts "作成したジョブ: #{jobs_created}件"
puts "スキップ: #{jobs_skipped}件"
puts ""

if jobs_created > 0
  puts "💡 ジョブは数分後に完了します。"
  puts "   1. ruby process_content_jobs.rb（本文処理）"
  puts "   2. ruby weekly_pdf_generator.rb（PDF生成・Kindle送信）"
else
  puts "⚠️ 新しいジョブは作成されませんでした"
  puts "既存ジョブが進行中の可能性があります。"
  puts "ruby process_content_jobs.rb を実行してください。"
end

puts "=" * 80
