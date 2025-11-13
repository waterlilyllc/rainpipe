#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'bookmark_content_fetcher'

puts "=" * 70
puts "🔄 クロールジョブ更新バッチ - #{Time.now}"
puts "=" * 70

begin
  fetcher = BookmarkContentFetcher.new

  # 1. 保留中のジョブのステータス確認と結果保存
  puts "\n[1/3] Updating pending jobs..."
  update_stats = fetcher.update_pending_jobs

  # 2. 失敗したジョブのリトライ
  puts "\n[2/3] Retrying failed jobs..."
  retried_count = fetcher.retry_failed_jobs

  # 3. タイムアウトしたジョブの処理
  puts "\n[3/3] Handling timeout jobs..."
  timeout_count = fetcher.handle_timeout_jobs

  # 統計情報表示
  stats = fetcher.print_stats

  # 成功率が低い場合は警告
  if stats[:jobs][:success_rate] < 50 && stats[:jobs][:total] > 10
    puts "\n🚨 ALERT: Low success rate detected!"
    puts "   Please investigate Gatherly API issues or bookmark URLs"
  end

  fetcher.close

rescue => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

puts "\n✅ Batch completed at #{Time.now}"
puts "=" * 70
