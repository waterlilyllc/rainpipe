#!/usr/bin/env ruby
# バックグラウンドで本文取得ジョブを処理
# cron: */5 * * * * (5分ごと)

require 'dotenv/load'
require_relative 'bookmark_content_fetcher'

puts "=" * 80
puts "📚 本文取得ジョブ処理開始"
puts "   時刻: #{Time.now}"
puts "=" * 80

fetcher = BookmarkContentFetcher.new

# 1. pending状態のジョブを確認して本文を保存
puts "\n📥 1. pending状態のジョブを確認中..."
update_stats = fetcher.update_pending_jobs

if update_stats && update_stats[:updated] && update_stats[:updated] > 0
  puts "✅ #{update_stats[:updated]}件の本文を保存しました"
  puts "   - 成功: #{update_stats[:completed]}件"
  puts "   - 失敗: #{update_stats[:failed]}件"
  puts "   - 処理中: #{update_stats[:still_pending]}件"
else
  puts "ℹ️ 処理対象のジョブなし"
end

# 2. 失敗したジョブを再試行
puts "\n🔄 2. 失敗したジョブを再試行中..."
retried_count = fetcher.retry_failed_jobs

if retried_count && retried_count > 0
  puts "✅ #{retried_count}件のジョブを再試行しました"
else
  puts "ℹ️ 再試行対象のジョブなし"
end

# 3. タイムアウトしたジョブを失敗にする
puts "\n⏱️ 3. タイムアウトジョブを確認中..."
timeout_count = fetcher.handle_timeout_jobs

if timeout_count && timeout_count > 0
  puts "⚠️ #{timeout_count}件のジョブがタイムアウトしました"
else
  puts "ℹ️ タイムアウトなし"
end

# 4. 統計情報を表示
puts "\n📊 4. 統計情報"
stats = fetcher.print_stats

puts "\n" + "=" * 80
puts "✅ 処理完了"
puts "=" * 80
