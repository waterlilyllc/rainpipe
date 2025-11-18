#!/usr/bin/env ruby
# 先週のブックマーク - クリーンなテキスト版（改ページなし）

require 'dotenv/load'
require 'fileutils'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "先週のブックマーク - Clean Text Edition"
puts "=" * 80
puts ""

client = RaindropClient.new
content_manager = BookmarkContentManager.new
email_sender = KindleEmailSender.new

# ブックマークをロード
all_bookmarks = client.load_all_bookmarks

# 先週の期間を計算
today = Date.today
current_week_start = today - today.wday
last_week_start = current_week_start - 7
last_week_end = current_week_start - 1

week_start_time = Time.new(last_week_start.year, last_week_start.month, last_week_start.day, 0, 0, 0)
week_end_time = Time.new(last_week_end.year, last_week_end.month, last_week_end.day, 23, 59, 59)

puts "Period: #{last_week_start.strftime('%Y-%m-%d')} - #{last_week_end.strftime('%Y-%m-%d')}"
puts ""

# 先週のブックマークをフィルタ
last_week_bookmarks = all_bookmarks.select do |bookmark|
  created_time = Time.parse(bookmark['created'])
  created_time >= week_start_time && created_time <= week_end_time
end.sort_by { |b| Time.parse(b['created']) }.reverse

puts "Bookmarks: #{last_week_bookmarks.length} items"

with_content = 0
last_week_bookmarks.each do |b|
  content_data = content_manager.get_content(b['_id'])
  if content_data && content_data.is_a?(Hash) && content_data['content']
    with_content += 1
  end
end

without_content = last_week_bookmarks.length - with_content
puts "  - With summary: #{with_content}"
puts "  - Without summary: #{without_content}"
puts ""

if last_week_bookmarks.empty?
  puts "No bookmarks"
  exit 0
end

# テキストレポート生成（UTF-8、改ページなし）
report_path = File.join(File.dirname(__FILE__), 'data', "weekly_clean_#{last_week_end.strftime('%Y%m%d')}.txt")
FileUtils.mkdir_p(File.dirname(report_path))

puts "Generating: #{report_path}"
puts ""

File.open(report_path, 'w:UTF-8') do |f|
  f.puts "WEEKLY BOOKMARKS"
  f.puts "=" * 70
  f.puts ""
  f.puts "Period: #{last_week_start.strftime('%Y-%m-%d')} - #{last_week_end.strftime('%Y-%m-%d')}"
  f.puts "Total: #{last_week_bookmarks.length} items"
  f.puts ""

  last_week_bookmarks.each_with_index do |bookmark, idx|
    created = Time.parse(bookmark['created'])
    url = bookmark['link']
    title = bookmark['title']
    content_data = content_manager.get_content(bookmark['_id'])

    f.puts ""
    f.puts "---"
    f.puts ""
    f.puts "[#{idx + 1}] #{title}"
    f.puts ""
    f.puts "Date: #{created.strftime('%Y-%m-%d %H:%M')}"
    f.puts "Link: #{url}"
    f.puts ""

    if content_data && content_data.is_a?(Hash) && content_data['content']
      summary = content_data['content']
      f.puts "Summary:"
      f.puts summary
    else
      f.puts "[Summary not available]"
    end
  end

  f.puts ""
  f.puts "=" * 70
  f.puts "Stats: #{with_content}/#{last_week_bookmarks.length} with summary"
  f.puts ""
end

puts "Done: #{File.size(report_path)} bytes"
puts ""

# Kindle に送信
puts "=" * 80
puts "Sending to Kindle"
puts "=" * 80
puts ""

begin
  result = email_sender.send_pdf(report_path)

  if result
    puts "Sent to: #{ENV['KINDLE_EMAIL']}"
  else
    puts "Send failed"
  end
rescue => e
  puts "Error: #{e.message}"
end

puts ""
