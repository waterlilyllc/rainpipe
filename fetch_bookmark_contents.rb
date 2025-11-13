#!/usr/bin/env ruby
require 'dotenv/load'
require 'json'
require_relative 'bookmark_content_fetcher'
require_relative 'bookmark_content_manager'

puts "=" * 70
puts "📚 ブックマーク本文取得バッチ - #{Time.now}"
puts "=" * 70

begin
  fetcher = BookmarkContentFetcher.new
  content_manager = BookmarkContentManager.new

  # 最新のブックマークJSONを読み込み
  data_dir = File.join(File.dirname(__FILE__), 'data')
  json_files = Dir.glob(File.join(data_dir, 'all_bookmarks_*.json')).sort

  if json_files.empty?
    puts "❌ ブックマークJSONファイルが見つかりません"
    exit 1
  end

  latest_json = json_files.last
  puts "\n📂 Reading: #{File.basename(latest_json)}"

  bookmarks = JSON.parse(File.read(latest_json))
  puts "   Total bookmarks: #{bookmarks.length}"

  # raindrop_idのリストを作成
  raindrop_ids = bookmarks.map { |b| b['_id'] }.compact
  puts "   Valid IDs: #{raindrop_ids.length}"

  # 本文未取得のブックマークを抽出
  missing_ids = content_manager.get_missing_content_ids(raindrop_ids)
  puts "\n🔍 Missing content for #{missing_ids.length} bookmarks"

  if missing_ids.empty?
    puts "✅ All bookmarks already have content!"
    fetcher.print_stats
    exit 0
  end

  # 処理するブックマークの上限設定（一度に大量処理しない）
  max_to_process = ENV['MAX_BOOKMARKS_PER_BATCH']&.to_i || 50
  ids_to_process = missing_ids.first(max_to_process)

  puts "📝 Processing #{ids_to_process.length} bookmarks (max: #{max_to_process})"
  puts "-" * 70

  created_jobs = 0
  skipped = 0

  ids_to_process.each_with_index do |raindrop_id, index|
    bookmark = bookmarks.find { |b| b['_id'] == raindrop_id }

    unless bookmark
      puts "#{index + 1}. ⚠️  Bookmark not found for ID: #{raindrop_id}"
      skipped += 1
      next
    end

    url = bookmark['link']
    title = bookmark['title'] || 'Untitled'

    unless url
      puts "#{index + 1}. ⚠️  No URL for: #{title}"
      skipped += 1
      next
    end

    print "#{index + 1}. [#{raindrop_id}] #{title[0..50]}..."

    job_uuid = fetcher.fetch_content(raindrop_id, url)

    if job_uuid
      created_jobs += 1
      puts " ✅"
    else
      skipped += 1
      puts " ⏭️"
    end

    # API負荷軽減のため少し待機
    sleep 1 if (index + 1) % 10 == 0
  end

  puts "-" * 70
  puts "\n📊 Summary:"
  puts "   Created jobs: #{created_jobs}"
  puts "   Skipped: #{skipped}"
  puts "   Total processed: #{ids_to_process.length}"

  if missing_ids.length > max_to_process
    remaining = missing_ids.length - max_to_process
    puts "\n⏭️  #{remaining} bookmarks remaining for next batch"
  end

  # 統計情報表示
  fetcher.print_stats

  fetcher.close

rescue => e
  puts "\n❌ Error: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

puts "\n✅ Batch completed at #{Time.now}"
puts "=" * 70
