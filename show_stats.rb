#!/usr/bin/env ruby

require 'json'
require 'date'

data = JSON.parse(File.read('./data/all_bookmarks_20250708_092315.json'))
puts '📊 統計情報:'
puts "   - 総件数: #{data.length}"

# 年別統計
years = data.group_by { |b| Date.parse(b['created']).year }
years.sort.each do |year, bookmarks|
  puts "   - #{year}年: #{bookmarks.length} 件"
end

# 最古と最新
dates = data.map { |b| Date.parse(b['created']) }.sort
puts "   - 期間: #{dates.first} 〜 #{dates.last}"

# タグ統計（上位10個）
tag_counts = Hash.new(0)
data.each do |bookmark|
  if bookmark['tags'] && bookmark['tags'].any?
    bookmark['tags'].each { |tag| tag_counts[tag] += 1 }
  end
end

if tag_counts.any?
  puts '   - 人気タグ (上位10):'
  tag_counts.sort_by { |_, count| -count }.first(10).each do |tag, count|
    puts "     ##{tag}: #{count} 件"
  end
end