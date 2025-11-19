#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'crawl_job_manager'
require 'sqlite3'

job_manager = CrawlJobManager.new

# 先週の未取得ブックマークのID
raindrop_ids = [1433198671, 1433152770, 1433152562, 1433039470, 1432842749, 1432189775, 1432059613, 1431668962, 1431664546]

puts "🧹 先週の#{raindrop_ids.length}件のブックマークに関する古いジョブをクリーンアップします"
puts ""

db = SQLite3::Database.new('./data/rainpipe.db')
db.results_as_hash = true

raindrop_ids.each do |raindrop_id|
  # このraindrop_idに関する全てのジョブを取得
  rows = db.execute("SELECT job_id, status FROM crawl_jobs WHERE raindrop_id = ?", raindrop_id)

  if rows.any?
    puts "📌 Raindrop #{raindrop_id}: #{rows.length}件のジョブ"
    rows.each do |row|
      if row['status'] != 'completed'
        db.execute("UPDATE crawl_jobs SET status = 'failed', error_message = 'Cleaned up for retry' WHERE job_id = ?", row['job_id'])
        puts "  ✅ #{row['job_id'][0..8]}... (#{row['status']} → failed)"
      else
        puts "  ⏭️  #{row['job_id'][0..8]}... (already completed)"
      end
    end
  end
end

db.close

puts ""
puts "=" * 60
puts "✅ クリーンアップ完了"
puts "=" * 60
