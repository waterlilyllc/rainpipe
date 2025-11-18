#!/usr/bin/env ruby
$stdout.sync = true

require 'dotenv/load'
require 'sqlite3'

raindrop_id = 1428368854
max_wait_seconds = 600 # 10分
check_interval = 10 # 10秒ごと

db = SQLite3::Database.new('data/rainpipe.db')
db.results_as_hash = true

puts "Qiita記事の本文取得を待機中..."
puts "Raindrop ID: #{raindrop_id}"
puts "最大待機時間: #{max_wait_seconds / 60}分"
puts ""

start_time = Time.now
elapsed = 0

while elapsed < max_wait_seconds
  # 本文が取得されたか確認
  content = db.get_first_row("SELECT * FROM bookmark_contents WHERE raindrop_id = ?", raindrop_id)

  if content
    puts ""
    puts "✅ 本文取得完了！"
    puts "  タイトル: #{content['title']}"
    puts "  本文長: #{content['content']&.length || 0}文字"
    puts "  取得時刻: #{content['extracted_at']}"
    exit 0
  end

  # クロールジョブのステータス確認
  job = db.get_first_row("SELECT status, error_message FROM crawl_jobs WHERE raindrop_id = ? ORDER BY created_at DESC LIMIT 1", raindrop_id)

  if job
    if job['status'] == 'failed'
      puts ""
      puts "❌ クロールジョブが失敗しました"
      puts "  エラー: #{job['error_message']}"
      exit 1
    end
  end

  sleep check_interval
  elapsed = (Time.now - start_time).to_i

  # 1分ごとに進捗表示
  if elapsed % 60 == 0 && elapsed > 0
    puts "  待機中... (経過: #{elapsed / 60}分)"
  elsif elapsed % 10 == 0
    print "."
  end
end

puts ""
puts "⚠️  タイムアウト: #{max_wait_seconds / 60}分経過しても本文が取得できませんでした"
exit 1
