#!/usr/bin/env ruby
$stdout.sync = true

require 'dotenv/load'
require_relative 'bookmark_content_fetcher'

puts "Qiita記事の新規クロールジョブを作成中..."
puts ""

raindrop_id = 1428368854
url = "https://qiita.com/Satoooon/items/cc6df7679ecd74c2fa11"

fetcher = BookmarkContentFetcher.new

puts "URL: #{url}"
puts "Raindrop ID: #{raindrop_id}"
puts ""

job_uuid = fetcher.fetch_content(raindrop_id, url)

if job_uuid
  puts "✅ クロールジョブ作成成功: #{job_uuid}"

  # ジョブステータスを確認
  require 'sqlite3'
  db = SQLite3::Database.new('data/rainpipe.db')
  db.results_as_hash = true

  result = db.get_first_row("SELECT * FROM crawl_jobs WHERE job_uuid = ?", job_uuid)

  if result
    puts ""
    puts "ジョブ情報:"
    puts "  Status: #{result['status']}"
    puts "  Created: #{result['created_at']}"
  end
else
  puts "❌ クロールジョブ作成失敗"
  exit 1
end
