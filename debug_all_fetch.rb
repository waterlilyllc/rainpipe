#!/usr/bin/env ruby

require 'dotenv/load'
require 'json'
require_relative 'raindrop_client'

puts "🔍 全件取得デバッグ"
puts "=" * 30

client = RaindropClient.new

# 最初の3ページのIDを確認
all_ids = []
3.times do |page|
  puts "\n📄 ページ #{page}:"
  bookmarks = client.send(:get_raindrops_with_pagination, nil, page, 5)
  
  puts "   件数: #{bookmarks.length}"
  if bookmarks.any?
    ids = bookmarks.map { |b| b['_id'] }
    puts "   IDs: #{ids}"
    all_ids.concat(ids)
  end
end

puts "\n📊 重複チェック:"
puts "   総ID数: #{all_ids.length}"
puts "   ユニークID数: #{all_ids.uniq.length}"
puts "   重複あり: #{all_ids.length != all_ids.uniq.length}"