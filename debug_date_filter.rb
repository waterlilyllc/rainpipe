#!/usr/bin/env ruby

require 'dotenv/load'
require 'date'
require_relative 'raindrop_client'

class Date
  def beginning_of_week_monday
    days_since_monday = (self.wday + 6) % 7
    self - days_since_monday
  end
end

puts "🔍 日付フィルタリングデバッグ"
puts "=" * 40

client = RaindropClient.new

# 今週
week_start = Date.today.beginning_of_week_monday
week_end = week_start + 6
puts "\n📅 今週 (#{week_start} - #{week_end}):"
query = "created:#{week_start.strftime('%Y-%m-%d')}..#{week_end.strftime('%Y-%m-%d')}"
puts "   クエリ: #{query}"
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
query = "created:#{prev_week_start.strftime('%Y-%m-%d')}..#{prev_week_end.strftime('%Y-%m-%d')}"
puts "   クエリ: #{query}"
bookmarks = client.get_weekly_bookmarks(prev_week_start, prev_week_end)
puts "   件数: #{bookmarks.length}"
if bookmarks.any?
  bookmarks.first(3).each do |b|
    puts "   - #{b['title'][0..50]}... (#{b['created']})"
  end
end

# 2ヶ月前
old_week_start = Date.new(2025, 5, 5)  # 明示的に古い日付
old_week_end = old_week_start + 6
puts "\n📅 5月第1週 (#{old_week_start} - #{old_week_end}):"
query = "created:#{old_week_start.strftime('%Y-%m-%d')}..#{old_week_end.strftime('%Y-%m-%d')}"
puts "   クエリ: #{query}"
bookmarks = client.get_weekly_bookmarks(old_week_start, old_week_end)
puts "   件数: #{bookmarks.length}"
if bookmarks.any?
  bookmarks.first(3).each do |b|
    puts "   - #{b['title'][0..50]}... (#{b['created']})"
  end
end