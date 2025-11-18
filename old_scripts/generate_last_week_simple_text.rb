#!/usr/bin/env ruby
# 先週のブックマークをシンプルなテキストで Kindle に送信

require 'dotenv/load'
require 'fileutils'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "先週のブックマーク - シンプルテキスト版"
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

puts "対象期間: #{last_week_start.strftime('%Y-%m-%d')} - #{last_week_end.strftime('%Y-%m-%d')}"
puts ""

# 先週のブックマークをフィルタ
last_week_bookmarks = all_bookmarks.select do |bookmark|
  created_time = Time.parse(bookmark['created'])
  created_time >= week_start_time && created_time <= week_end_time
end.sort_by { |b| Time.parse(b['created']) }.reverse

puts "先週のブックマーク: #{last_week_bookmarks.length}件"

with_content = 0
last_week_bookmarks.each do |b|
  content_data = content_manager.get_content(b['_id'])
  if content_data && content_data.is_a?(Hash) && content_data['content']
    with_content += 1
  end
end

without_content = last_week_bookmarks.length - with_content
puts "  - 要約あり: #{with_content}件"
puts "  - 要約なし: #{without_content}件"
puts ""

if last_week_bookmarks.empty?
  puts "先週のブックマークがありません"
  exit 0
end

# シンプルなテキストレポート生成
report_path = File.join(File.dirname(__FILE__), 'data', "weekly_simple_#{last_week_end.strftime('%Y%m%d')}.txt")
FileUtils.mkdir_p(File.dirname(report_path))

puts "レポート生成中: #{report_path}"
puts ""

File.open(report_path, 'w', encoding: 'ASCII-8BIT') do |f|
  # ヘッダー（ASCII のみ）
  f.puts "Weekly Bookmarks Report"
  f.puts "=" * 60
  f.puts ""
  f.puts "Period: #{last_week_start.strftime('%Y-%m-%d')} - #{last_week_end.strftime('%Y-%m-%d')}"
  f.puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  f.puts "Total: #{last_week_bookmarks.length} items"
  f.puts ""
  f.puts "=" * 60
  f.puts ""

  last_week_bookmarks.each_with_index do |bookmark, idx|
    created = Time.parse(bookmark['created'])
    url = bookmark['link']
    content_data = content_manager.get_content(bookmark['_id'])

    # タイトル（エスケープ）
    title = bookmark['title'].to_s.encode('ASCII', invalid: :replace, undef: :replace, replace: '?')

    f.puts "[#{idx + 1}] #{title}"
    f.puts ""
    f.puts "Date: #{created.strftime('%Y-%m-%d %H:%M')}"
    f.puts "URL: #{url}"
    f.puts ""

    if content_data && content_data.is_a?(Hash) && content_data['content']
      summary = content_data['content'].to_s.encode('ASCII', invalid: :replace, undef: :replace, replace: '?')
      f.puts "Summary:"
      f.puts summary
    else
      f.puts "[No summary available]"
    end

    f.puts ""
    f.puts "-" * 60
    f.puts ""
  end

  # 統計
  f.puts "Statistics"
  f.puts "=" * 60
  f.puts "Total bookmarks: #{last_week_bookmarks.length}"
  f.puts "With summary: #{with_content} (#{(with_content.to_f / last_week_bookmarks.length * 100).round(1)}%)"
  f.puts "Without summary: #{without_content}"
  f.puts ""
end

puts "レポート作成完了: #{File.size(report_path)} bytes"
puts ""

# Kindle に送信
puts "=" * 80
puts "Sending to Kindle..."
puts "=" * 80
puts ""

begin
  result = email_sender.send_pdf(report_path)

  if result
    puts "Success!"
    puts "Recipient: #{ENV['KINDLE_EMAIL']}"
  else
    puts "Failed to send"
  end
rescue => e
  puts "Error: #{e.message}"
end

puts ""
puts "Report: #{report_path}"
puts ""
