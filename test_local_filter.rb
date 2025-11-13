#!/usr/bin/env ruby

require 'json'
require 'date'
require_relative 'raindrop_client'

class Date
  def beginning_of_week_monday
    days_since_monday = (self.wday + 6) % 7
    self - days_since_monday
  end
end

puts "🔍 ローカルファイルフィルタリングテスト"
puts "=" * 50

client = RaindropClient.new

# 今週
week_start = Date.today.beginning_of_week_monday
week_end = week_start + 6
puts "\n📅 今週 (#{week_start} - #{week_end}):"
bookmarks = client.get_weekly_bookmarks(week_start, week_end)
puts "   件数: #{bookmarks.length}"
if bookmarks.any?
  bookmarks.first(3).each do |b|
    puts "   - #{b['title'][0..50]}... (#{b['created']})"
  end
end

# 先週
prev_week_start = week_start - 7
prev_week_end = prev_week_start + 6
puts "\n📅 先週 (#{prev_week_start} - #{prev_week_end}):"
bookmarks = client.get_weekly_bookmarks(prev_week_start, prev_week_end)
puts "   件数: #{bookmarks.length}"
if bookmarks.any?
  bookmarks.first(3).each do |b|
    puts "   - #{b['title'][0..50]}... (#{b['created']})"
  end
end

# 全データ数確認
all_data = client.send(:load_all_bookmarks)
puts "\n📊 全データ:"
puts "   総件数: #{all_data.length}"
puts "   最新: #{all_data.first['created']}" if all_data.any?
puts "   最古: #{all_data.last['created']}" if all_data.any?