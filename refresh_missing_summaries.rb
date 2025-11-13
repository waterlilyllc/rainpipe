#!/usr/bin/env ruby
# 要約が無いブックマークを再度取得する
# 新しいGatherly API v2.1のジョブ管理機能を活用

require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'bookmark_content_fetcher'
require_relative 'gatherly_client'
require_relative 'crawl_job_manager'

puts "=" * 80
puts "🔄 要約が無いブックマークの再取得"
puts "=" * 80
puts ""

client = RaindropClient.new
content_manager = BookmarkContentManager.new
fetcher = BookmarkContentFetcher.new
gatherly = GatherlyClient.new
job_manager = CrawlJobManager.new

# 最新のブックマークを読み込み
all_bookmarks = client.load_all_bookmarks

puts "📚 ブックマーク総数: #{all_bookmarks.length}件"
puts ""

# 本文が無いものを検索
missing_summaries = []

all_bookmarks.each do |bookmark|
  raindrop_id = bookmark['_id']
  title = bookmark['title']
  url = bookmark['link']

  # 本文データを確認
  content = content_manager.get_content(raindrop_id)

  # 本文がない、かつfetch_failedでない場合
  if !content && url && !url.empty? && !content_manager.fetch_failed?(raindrop_id)
    missing_summaries << {
      raindrop_id: raindrop_id,
      title: title,
      url: url
    }
  end
end

puts "📊 結果分析"
puts "-" * 80
puts "本文あり: #{all_bookmarks.length - missing_summaries.length}件"
puts "本文なし（再取得対象）: #{missing_summaries.length}件"
puts ""

if missing_summaries.empty?
  puts "✅ すべてのブックマークに要約があります！"
  exit 0
end

# Gatherly APIで現在のジョブを確認
puts "🔍 既存のジョブをチェック中..."
puts ""

all_jobs = gatherly.get_crawl_jobs(status: 'pending', limit: 100)
existing_jobs = if all_jobs[:error]
  puts "⚠️ ジョブ取得エラー: #{all_jobs[:error]}"
  []
else
  all_jobs[:jobs] || []
end

puts "既存のpendingジョブ: #{existing_jobs.length}件"
puts ""

# 既存のジョブをURLでマッピング
existing_job_map = {}
existing_jobs.each do |job|
  if job[:source_payload]&.dig(:urls)
    job[:source_payload][:urls].each do |url|
      existing_job_map[url] = job
    end
  end
end

# 再取得ロジック
puts "=" * 80
puts "📥 再取得処理を開始します"
puts "=" * 80
puts ""

jobs_created = 0
jobs_already_pending = 0
jobs_skipped = 0

missing_summaries.each_with_index do |item, index|
  puts "[#{index + 1}/#{missing_summaries.length}] #{item[:title]}"
  puts "   URL: #{item[:url]}"

  raindrop_id = item[:raindrop_id]
  url = item[:url]

  # 既にpendingジョブがあるか確認
  if existing_job_map[url]
    job = existing_job_map[url]
    puts "   ⏳ 既存のジョブが進行中: #{job[:job_uuid]}"
    jobs_already_pending += 1
    puts ""
    next
  end

  # DBに既存ジョブがあるか確認
  if job_manager.job_exists_for_bookmark?(raindrop_id)
    existing_job = job_manager.get_job_by_raindrop_id(raindrop_id)
    if existing_job
      job_id = existing_job['job_id']
      job_status = existing_job['status']

      # 古いpendingジョブは削除
      if job_status == 'pending' || job_status == 'running'
        puts "   🗑️  古いジョブをクリーンアップ: #{job_id}"
        delete_result = gatherly.delete_crawl_job(job_id)
        if !delete_result[:error]
          job_manager.delete_job(job_id)
          puts "   ✅ ジョブを削除しました"
        else
          puts "   ⚠️ 削除失敗: #{delete_result[:error]}"
        end
      end
    end
  end

  # 新しいジョブを作成
  begin
    job_uuid = fetcher.fetch_content(raindrop_id, url)

    if job_uuid
      puts "   ✅ 新規ジョブ作成: #{job_uuid}"
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
puts "✅ 処理完了"
puts "=" * 80
puts "新規作成: #{jobs_created}件"
puts "既に進行中: #{jobs_already_pending}件"
puts "スキップ: #{jobs_skipped}件"
puts ""

if jobs_created > 0
  puts "💡 ジョブは数分後に完了します。"
  puts "   確認: ruby process_content_jobs.rb"
  puts ""
  puts "📝 その後、PDFを再生成してください:"
  puts "   ruby weekly_pdf_generator.rb"
else
  puts "⚠️ 新しいジョブは作成されませんでした"
end

puts "=" * 80
