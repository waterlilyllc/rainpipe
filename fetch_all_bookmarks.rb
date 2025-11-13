#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require 'date'
require_relative 'raindrop_client'

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