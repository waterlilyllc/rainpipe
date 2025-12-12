#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'date'
require_relative 'raindrop_client'
require_relative 'bookmark_content_fetcher'
require_relative 'bookmark_content_manager'

puts "🌧️  Rainpipe - 全ブックマーク取得スクリプト"
puts "=" * 60

# 開始時間を記録
start_time = Time.now

begin
  client = RaindropClient.new
  puts "🔗 API接続確認中..."
  
  # 最初に少しだけ取得して接続確認
  test_bookmarks = client.send(:get_raindrops_with_pagination, nil, 0, 1)
  if test_bookmarks.empty?
    puts "⚠️  ブックマークが見つからないか、API接続に問題があります"
    exit 1
  end
  
  puts "✅ API接続成功"
  puts "📚 全ブックマークの取得を開始します..."
  puts

  # 全ブックマークを取得
  all_bookmarks = client.get_all_bookmarks
  
  if all_bookmarks.any?
    # データディレクトリを作成
    data_dir = File.join(File.dirname(__FILE__), 'data')
    Dir.mkdir(data_dir) unless Dir.exist?(data_dir)
    
    # JSONファイルに保存
    filename = File.join(data_dir, "all_bookmarks_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json")
    File.write(filename, JSON.pretty_generate(all_bookmarks))
    
    puts
    puts "💾 ブックマークを保存しました: #{filename}"
    puts "📊 統計情報:"
    puts "   - 総件数: #{all_bookmarks.length}"
    
    # 年別統計
    years = all_bookmarks.group_by { |b| Date.parse(b['created']).year }
    years.sort.each do |year, bookmarks|
      puts "   - #{year}年: #{bookmarks.length} 件"
    end
    
    # 最古と最新
    dates = all_bookmarks.map { |b| Date.parse(b['created']) }.sort
    puts "   - 期間: #{dates.first} 〜 #{dates.last}"
    
    # タグ統計（上位10個）
    tag_counts = Hash.new(0)
    all_bookmarks.each do |bookmark|
      if bookmark['tags'] && bookmark['tags'].any?
        bookmark['tags'].each { |tag| tag_counts[tag] += 1 }
      end
    end
    
    if tag_counts.any?
      puts "   - 人気タグ (上位10):"
      tag_counts.sort_by { |_, count| -count }.first(10).each do |tag, count|
        puts "     ##{tag}: #{count} 件"
      end
    end

    # 新着ブックマーク（本文未取得）を検出して本文取得ジョブを作成
    puts
    puts "=" * 60
    puts "📥 新着ブックマークの本文取得を開始..."

    content_manager = BookmarkContentManager.new
    content_fetcher = BookmarkContentFetcher.new

    # 直近7日間のブックマークで本文がないものを検出
    recent_cutoff = Date.today - 7
    recent_bookmarks = all_bookmarks.select do |b|
      created = Date.parse(b['created'])
      created >= recent_cutoff
    end

    missing_content = recent_bookmarks.select do |b|
      !content_manager.content_exists?(b['_id'])
    end

    if missing_content.any?
      puts "⚠️  直近7日間で本文未取得: #{missing_content.length}件"
      puts

      created_jobs = []
      missing_content.each_with_index do |bookmark, i|
        puts "[#{i+1}/#{missing_content.length}] #{bookmark['title'][0..50]}..."
        job_uuid = content_fetcher.fetch_content(bookmark['_id'], bookmark['link'])
        if job_uuid
          puts "  ✅ ジョブ作成: #{job_uuid}"
          created_jobs << { raindrop_id: bookmark['_id'], job_uuid: job_uuid }
        else
          puts "  ⏭️  スキップ"
        end
        sleep 0.2  # API レート制限対策
      end

      puts
      puts "📊 ジョブ作成結果: #{created_jobs.length}/#{missing_content.length} 件"
    else
      puts "✅ 直近7日間の新着ブックマークは全て本文取得済みです"
    end

    content_manager.close

  else
    puts "❌ ブックマークを取得できませんでした"
    exit 1
  end
  
rescue => e
  puts "❌ エラーが発生しました: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end

# 処理時間を表示
end_time = Time.now
duration = end_time - start_time
puts
puts "⏱️  処理時間: #{duration.round(2)} 秒"
puts "🎉 全ブックマーク取得完了！"