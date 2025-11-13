#!/usr/bin/env ruby

require 'dotenv/load'
require_relative 'raindrop_client'

puts "📚 Rainpipe - 全ブックマーク一覧"
puts "=" * 50

begin
  client = RaindropClient.new
  puts "🔍 全ブックマークを取得中..."
  
  # Get all bookmarks (no date filter)
  bookmarks = client.send(:get_raindrops)
  
  if bookmarks.any?
    puts "✅ 合計 #{bookmarks.length} 件のブックマークを取得"
    puts
    
    bookmarks.each_with_index do |bookmark, i|
      puts "#{i+1}. #{bookmark['title']}"
      puts "   #{bookmark['link']}"
      puts "   作成日: #{bookmark['created']}"
      
      if bookmark['tags'] && bookmark['tags'].any?
        puts "   タグ: #{bookmark['tags'].map { |tag| "##{tag}" }.join(' ')}"
      end
      
      if bookmark['excerpt'] && !bookmark['excerpt'].empty?
        excerpt = bookmark['excerpt'].length > 100 ? 
                  bookmark['excerpt'][0..100] + "..." : 
                  bookmark['excerpt']
        puts "   メモ: #{excerpt}"
      end
      
      puts
    end
  else
    puts "❌ ブックマークが見つかりませんでした"
  end
  
rescue => e
  puts "❌ エラー: #{e.message}"
  exit 1
end