#!/usr/bin/env ruby
# 先週のブックマークをPDFに生成してKindleに送信（シンプル版）

require 'dotenv/load'
require 'json'
require 'fileutils'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "Last Week's Bookmarks - PDF & Kindle Email Test"
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

puts "Target Period: #{last_week_start.strftime('%Y-%m-%d')} (Sun) ~ #{last_week_end.strftime('%Y-%m-%d')} (Sat)"
puts ""

# 先週のブックマークをフィルタ
last_week_bookmarks = all_bookmarks.select do |bookmark|
  created_time = Time.parse(bookmark['created'])
  created_time >= week_start_time && created_time <= week_end_time
end.sort_by { |b| Time.parse(b['created']) }.reverse

puts "Last Week Bookmarks: #{last_week_bookmarks.length} items"

with_content = last_week_bookmarks.count { |b| content_manager.get_content(b['_id']) }
without_content = last_week_bookmarks.length - with_content

puts "  - With summary: #{with_content} items"
puts "  - Without summary: #{without_content} items"
puts ""

if last_week_bookmarks.empty?
  puts "No bookmarks found for last week"
  exit 0
end

# テキストベースのレポート生成
report_path = File.join(File.dirname(__FILE__), 'data', "weekly_report_#{last_week_end.strftime('%Y%m%d')}.txt")
FileUtils.mkdir_p(File.dirname(report_path))

puts "Generating report: #{report_path}"
puts ""

File.open(report_path, 'w') do |f|
  f.puts "=" * 80
  f.puts "WEEKLY BOOKMARKS REPORT"
  f.puts "=" * 80
  f.puts ""
  f.puts "Period: #{last_week_start.strftime('%Y-%m-%d')} - #{last_week_end.strftime('%Y-%m-%d')}"
  f.puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  f.puts "Total Items: #{last_week_bookmarks.length}"
  f.puts ""
  f.puts "-" * 80
  f.puts ""

  last_week_bookmarks.each_with_index do |bookmark, idx|
    raindrop_id = bookmark['_id']
    title = bookmark['title']
    url = bookmark['link']
    created = Time.parse(bookmark['created'])

    content = content_manager.get_content(raindrop_id)

    f.puts "#{idx + 1}. #{title}"
    f.puts "   URL: #{url}"
    f.puts "   Date: #{created.strftime('%Y-%m-%d %H:%M')}"
    f.puts ""

    if content
      summary = content.length > 500 ? "#{content[0..500]}..." : content
      f.puts "   Summary:"
      f.puts "   #{summary}"
    else
      f.puts "   [No summary available]"
    end

    f.puts ""
    f.puts "-" * 80
    f.puts ""
  end

  # 統計情報
  f.puts "STATISTICS"
  f.puts "-" * 80
  f.puts "Total Bookmarks: #{last_week_bookmarks.length}"
  f.puts "With Summary: #{with_content} (#{(with_content.to_f / last_week_bookmarks.length * 100).round}%)"
  f.puts "Without Summary: #{without_content}"
  f.puts ""
end

puts "Report generated: #{File.size(report_path)} bytes"
puts ""

# HTML形式でもエクスポート（メール送信用）
html_path = File.join(File.dirname(__FILE__), 'data', "weekly_report_#{last_week_end.strftime('%Y%m%d')}.html")

puts "Generating HTML version: #{html_path}"
puts ""

File.open(html_path, 'w') do |f|
  f.puts "<!DOCTYPE html>"
  f.puts "<html>"
  f.puts "<head>"
  f.puts "<meta charset='UTF-8'>"
  f.puts "<title>Weekly Bookmarks Report</title>"
  f.puts "<style>"
  f.puts "body { font-family: Arial, sans-serif; margin: 20px; }"
  f.puts "h1 { color: #333; }"
  f.puts ".bookmark { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }"
  f.puts ".title { font-weight: bold; font-size: 16px; color: #0066cc; }"
  f.puts ".url { color: #666; font-size: 12px; margin: 5px 0; }"
  f.puts ".date { color: #999; font-size: 11px; }"
  f.puts ".summary { color: #333; margin-top: 10px; }"
  f.puts ".stats { border-top: 2px solid #ddd; margin-top: 30px; padding-top: 20px; }"
  f.puts "</style>"
  f.puts "</head>"
  f.puts "<body>"
  f.puts "<h1>Weekly Bookmarks Report</h1>"
  f.puts "<p>Period: #{last_week_start.strftime('%Y-%m-%d')} to #{last_week_end.strftime('%Y-%m-%d')}</p>"
  f.puts "<p>Total Items: #{last_week_bookmarks.length}</p>"
  f.puts "<hr>"

  last_week_bookmarks.each_with_index do |bookmark, idx|
    raindrop_id = bookmark['_id']
    title = bookmark['title']
    url = bookmark['link']
    created = Time.parse(bookmark['created'])
    content = content_manager.get_content(raindrop_id)

    f.puts "<div class='bookmark'>"
    f.puts "<div class='title'>#{idx + 1}. #{title}</div>"
    f.puts "<div class='url'>URL: <a href='#{url}' target='_blank'>#{url}</a></div>"
    f.puts "<div class='date'>Date: #{created.strftime('%Y-%m-%d %H:%M')}</div>"

    if content
      summary = content.length > 500 ? "#{content[0..500]}..." : content
      f.puts "<div class='summary'><strong>Summary:</strong><br>#{summary}</div>"
    else
      f.puts "<div class='summary'><em>[No summary available]</em></div>"
    end

    f.puts "</div>"
  end

  f.puts "<div class='stats'>"
  f.puts "<h2>Statistics</h2>"
  f.puts "<p>Total Bookmarks: #{last_week_bookmarks.length}</p>"
  f.puts "<p>With Summary: #{with_content} (#{(with_content.to_f / last_week_bookmarks.length * 100).round}%)</p>"
  f.puts "<p>Without Summary: #{without_content}</p>"
  f.puts "</div>"

  f.puts "</body>"
  f.puts "</html>"
end

puts "HTML report generated: #{File.size(html_path)} bytes"
puts ""

# メール送信テスト
puts "=" * 80
puts "Testing Kindle Email Send"
puts "=" * 80
puts ""

begin
  # HTML版をメール送信（テスト用）
  puts "Sending HTML report to Kindle..."
  result = email_sender.send_pdf(html_path)

  if result
    puts "✓ Email sent successfully!"
    puts "  To: #{ENV['KINDLE_EMAIL']}"
    puts "  File: #{File.basename(html_path)}"
    puts ""
    puts "The email will be delivered to your Kindle device shortly."
  else
    puts "✗ Failed to send email"
  end
rescue => e
  puts "✗ Error: #{e.message}"
  puts "  Please check your email configuration:"
  puts "  - GMAIL_ADDRESS: #{ENV['GMAIL_ADDRESS'] ? 'configured' : 'MISSING'}"
  puts "  - GMAIL_APP_PASSWORD: #{ENV['GMAIL_APP_PASSWORD'] ? 'configured' : 'MISSING'}"
  puts "  - KINDLE_EMAIL: #{ENV['KINDLE_EMAIL'] ? 'configured' : 'MISSING'}"
end

puts ""
puts "=" * 80
puts "COMPLETE"
puts "=" * 80
puts ""
puts "Files generated:"
puts "  1. Text report: #{report_path}"
puts "  2. HTML report: #{html_path}"
puts ""
