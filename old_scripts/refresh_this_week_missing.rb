#!/usr/bin/env ruby
# 今週のブックマークで要約が無いものを再取得

require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'bookmark_content_fetcher'

puts "=" * 80
puts "📅 今週のブックマーク - 要約がないものを再取得"
puts "=" * 80
puts ""

client = RaindropClient.new
content_manager = BookmarkContentManager.new
fetcher = BookmarkContentFetcher.new

# 最新のブックマークをロード
all_bookmarks = client.load_all_bookmarks

puts "📚 ブックマーク総数: #{all_bookmarks.length}件"
puts ""

# 今週の開始日時を計算（日曜日の最後）
today = Date.today
week_start = today - today.wday  # 日曜日
week_start_time = Time.new(week_start.year, week_start.month, week_start.day, 0, 0, 0)

puts "📅 対象期間: #{week_start_time.strftime('%Y-%m-%d')} ～ 今日"
puts ""

# 今週のブックマークで要約がないものを検索
this_week_bookmarks = []
this_week_with_content = 0
missing_in_week = []

all_bookmarks.each do |bookmark|
  created_time = Time.parse(bookmark['created'])
  next if created_time < week_start_time

  raindrop_id = bookmark['_id']
  title = bookmark['title']
  url = bookmark['link']

  this_week_bookmarks << bookmark

  # 本文データを確認
  content = content_manager.get_content(raindrop_id)

  if content
    this_week_with_content += 1
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
puts "今週のブックマーク: #{this_week_bookmarks.length}件"
puts "  - 要約あり: #{this_week_with_content}件"
puts "  - 要約なし（再取得対象）: #{missing_in_week.length}件"
puts ""

if missing_in_week.empty?
  puts "✅ 今週のブックマークは全て要約があります！"
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
  puts "   2. ruby weekly_pdf_generator.rb（PDF生成）"
  puts "   3. PDF がKindleに送信されます"
else
  puts "⚠️ 新しいジョブは作成されませんでした"
end

puts "=" * 80
