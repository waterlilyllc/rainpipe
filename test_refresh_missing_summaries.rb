#!/usr/bin/env ruby
# refresh_missing_summaries.rb のテスト
# Gatherly APIなしでロジックを検証

require 'dotenv/load'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'crawl_job_manager'

puts "=" * 80
puts "🧪 refresh_missing_summaries.rb のロジックテスト"
puts "=" * 80
puts ""

# DBマネージャー
content_manager = BookmarkContentManager.new
job_manager = CrawlJobManager.new

# ブックマークをロード
client = RaindropClient.new
all_bookmarks = client.load_all_bookmarks

puts "📚 総ブックマーク数: #{all_bookmarks.length}件"
puts ""

# 本文が無いものを検索（同じロジック）
missing_summaries = []
has_content = 0
fetch_failed = 0

all_bookmarks.each do |bookmark|
  raindrop_id = bookmark['_id']
  url = bookmark['link']

  # 本文データを確認
  content = content_manager.get_content(raindrop_id)

  if content
    has_content += 1
  elsif content_manager.fetch_failed?(raindrop_id)
    fetch_failed += 1
  elsif url && !url.empty?
    missing_summaries << {
      raindrop_id: raindrop_id,
      title: bookmark['title'],
      url: url
    }
  end
end

puts "📊 分析結果"
puts "-" * 80
puts "本文あり: #{has_content}件"
puts "本文なし（再取得対象）: #{missing_summaries.length}件"
puts "永続失敗フラグ付き: #{fetch_failed}件"
puts "合計: #{has_content + missing_summaries.length + fetch_failed}件"
puts ""

if missing_summaries.empty?
  puts "✅ 全て本文があります！"
  exit 0
end

# DBのジョブ状況を確認
puts "🔍 DB内のジョブ状況"
puts "-" * 80

job_stats = job_manager.get_stats
puts "総ジョブ数: #{job_stats[:total]}件"
puts "  - 成功: #{job_stats[:success]}件"
puts "  - 失敗: #{job_stats[:failed]}件"
puts "  - 実行中: #{job_stats[:running]}件"
puts "  - 保留中: #{job_stats[:pending]}件"
puts ""

# 本文が無いものの中で、既存ジョブがあるかチェック
already_has_job = 0
missing_summaries.first(10).each_with_index do |item, idx|
  raindrop_id = item[:raindrop_id]
  if job_manager.job_exists_for_bookmark?(raindrop_id)
    already_has_job += 1
    job = job_manager.get_job_by_raindrop_id(raindrop_id)
    if job
      puts "[#{idx + 1}] #{item[:title][0..40]}... → 既存ジョブ: #{job['job_id'][0..8]}... (#{job['status']})"
    end
  end
end

if already_has_job == 0 && missing_summaries.first(10).length > 0
  puts "最初の10件にはジョブがありません"
end

puts ""
puts "=" * 80
puts "✅ ロジックテスト完了"
puts "=" * 80
puts ""
puts "📋 要約"
puts "  再取得対象: #{missing_summaries.length}件"
puts "  既存ジョブ: #{already_has_job}件（確認した範囲）"
puts "  新規作成対象: 約#{missing_summaries.length - already_has_job}件"
puts ""
puts "💡 実行時の注意:"
puts "  - Gatherly APIが接続可能であることを確認してください"
puts "  - ruby refresh_missing_summaries.rb で実際に実行"
puts "  - 実行後、ruby process_content_jobs.rb で結果を処理"
puts "=" * 80
