#!/usr/bin/env ruby
require 'dotenv/load'
require_relative 'bookmark_content_fetcher'
require_relative 'crawl_job_manager'
require_relative 'bookmark_content_manager'

puts "🧪 ブックマーク本文取得フロー - 統合テスト\n\n"

# テスト用URL
TEST_URLS = [
  { id: 9999901, url: 'https://example.com', title: 'Example Domain' },
  { id: 9999902, url: 'https://example.org', title: 'Example Org' }
]

begin
  fetcher = BookmarkContentFetcher.new
  job_manager = CrawlJobManager.new
  content_manager = BookmarkContentManager.new

  puts "=" * 70
  puts "Phase 1: ジョブ作成テスト"
  puts "=" * 70

  created_jobs = []

  TEST_URLS.each_with_index do |test_data, index|
    puts "\n#{index + 1}. Creating job for: #{test_data[:title]}"
    puts "   URL: #{test_data[:url]}"

    job_uuid = fetcher.fetch_content(test_data[:id], test_data[:url])

    if job_uuid
      puts "   ✅ Job created: #{job_uuid}"
      created_jobs << { id: test_data[:id], job_uuid: job_uuid, url: test_data[:url] }
    else
      puts "   ⚠️ Job creation failed or skipped"
    end

    sleep 1
  end

  if created_jobs.empty?
    puts "\n⚠️ No jobs created (may already exist). Checking existing jobs..."

    TEST_URLS.each do |test_data|
      if job_manager.job_exists_for_bookmark?(test_data[:id])
        puts "   ℹ️  Job exists for raindrop_id: #{test_data[:id]}"
      end
    end
  end

  puts "\n" + "=" * 70
  puts "Phase 2: ジョブステータス確認（10秒待機）"
  puts "=" * 70

  puts "\nWaiting 10 seconds for Gatherly API to process jobs..."
  10.times do |i|
    print "."
    sleep 1
  end
  puts "\n"

  update_stats = fetcher.update_pending_jobs

  puts "\n" + "=" * 70
  puts "Phase 3: 結果確認"
  puts "=" * 70

  TEST_URLS.each do |test_data|
    raindrop_id = test_data[:id]
    puts "\nChecking raindrop_id: #{raindrop_id}"

    # ジョブ状態確認
    if job_manager.job_exists_for_bookmark?(raindrop_id)
      puts "   ✅ Job exists in database"
    else
      puts "   ❌ No job found"
      next
    end

    # 本文確認
    if content_manager.content_exists?(raindrop_id)
      content = content_manager.get_content(raindrop_id)
      puts "   ✅ Content saved:"
      puts "      Title: #{content['title']}"
      puts "      Word count: #{content['word_count']}"
      puts "      Extracted: #{content['extracted_at']}"
    else
      puts "   ⏳ Content not yet available (still processing or failed)"
    end
  end

  puts "\n" + "=" * 70
  puts "Phase 4: 統計情報"
  puts "=" * 70

  stats = fetcher.print_stats

  puts "\n" + "=" * 70
  puts "Phase 5: クリーンアップ（テストデータ削除）"
  puts "=" * 70

  TEST_URLS.each do |test_data|
    raindrop_id = test_data[:id]

    # ジョブ削除
    job_manager.db.execute('DELETE FROM crawl_jobs WHERE raindrop_id = ?', raindrop_id)
    # 本文削除
    content_manager.db.execute('DELETE FROM bookmark_contents WHERE raindrop_id = ?', raindrop_id)

    puts "   🗑️  Cleaned up test data for raindrop_id: #{raindrop_id}"
  end

  fetcher.close

  puts "\n✅ 統合テスト完了"
  puts "=" * 70

rescue => e
  puts "\n❌ Test failed: #{e.message}"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
