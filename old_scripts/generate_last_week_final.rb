#!/usr/bin/env ruby
# 先週のブックマーク - 最終版（週間サマリー＆キーワード付き）

require 'dotenv/load'
require 'json'
require 'fileutils'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "先週のブックマーク - Final Edition"
puts "=" * 80
puts ""

client = RaindropClient.new
content_manager = BookmarkContentManager.new
email_sender = KindleEmailSender.new

# 週間サマリーデータをロード
summary_path = File.join(File.dirname(__FILE__), 'data', 'weekly_summaries', 'latest.json')
weekly_summary = nil

if File.exist?(summary_path)
  weekly_summary = JSON.parse(File.read(summary_path))
  puts "✓ 週間サマリーを読み込みました"
else
  puts "⚠️ 週間サマリーが見つかりません: #{summary_path}"
end

puts ""

# ブックマークをロード
all_bookmarks = client.load_all_bookmarks

# 先週の期間を計算
today = Date.today
current_week_start = today - today.wday
last_week_start = current_week_start - 7
last_week_end = current_week_start - 1

week_start_time = Time.new(last_week_start.year, last_week_start.month, last_week_start.day, 0, 0, 0)
week_end_time = Time.new(last_week_end.year, last_week_end.month, last_week_end.day, 23, 59, 59)

# 先週のブックマークをフィルタ
last_week_bookmarks = all_bookmarks.select do |bookmark|
  created_time = Time.parse(bookmark['created'])
  created_time >= week_start_time && created_time <= week_end_time
end.sort_by { |b| Time.parse(b['created']) }.reverse

puts "Bookmarks: #{last_week_bookmarks.length} items (#{last_week_start.strftime('%m/%d')} - #{last_week_end.strftime('%m/%d')})"

with_content = 0
last_week_bookmarks.each do |b|
  content_data = content_manager.get_content(b['_id'])
  if content_data && content_data.is_a?(Hash) && content_data['content']
    with_content += 1
  end
end

without_content = last_week_bookmarks.length - with_content
puts ""

# レポート生成
report_path = File.join(File.dirname(__FILE__), 'data', "weekly_final_#{last_week_end.strftime('%Y%m%d')}.txt")
FileUtils.mkdir_p(File.dirname(report_path))

puts "Generating: #{report_path}"
puts ""

File.open(report_path, 'w:UTF-8') do |f|
  # ヘッダー
  f.puts "WEEKLY BOOKMARKS DIGEST"
  f.puts "=" * 70
  f.puts ""
  f.puts "Period: #{last_week_start.strftime('%Y-%m-%d')} - #{last_week_end.strftime('%Y-%m-%d')}"
  f.puts "Total Items: #{last_week_bookmarks.length}"
  f.puts "With Summary: #{with_content}/#{last_week_bookmarks.length}"
  f.puts ""

  # 週間サマリーセクション
  if weekly_summary && weekly_summary['overall_insights']
    f.puts "=" * 70
    f.puts "WEEKLY INSIGHTS"
    f.puts "=" * 70
    f.puts ""
    f.puts weekly_summary['overall_insights']
    f.puts ""
  end

  # 周辺キーワードセクション
  if weekly_summary && weekly_summary['related_clusters'] && weekly_summary['related_clusters'].any?
    f.puts "=" * 70
    f.puts "PERIPHERAL KEYWORDS / RELATED TOPICS"
    f.puts "=" * 70
    f.puts ""

    weekly_summary['related_clusters'].each do |cluster|
      f.puts "• #{cluster['main_topic']}"
      if cluster['related_words'] && cluster['related_words'].any?
        f.puts "  Related: #{cluster['related_words'].join(', ')}"
      end
      f.puts ""
    end

    f.puts ""
  end

  # キーワード・トピックセクション
  if weekly_summary && weekly_summary['keywords']
    f.puts "=" * 70
    f.puts "TOP TOPICS THIS WEEK"
    f.puts "=" * 70
    f.puts ""

    weekly_summary['keywords'].each do |keyword, data|
      f.puts "TOPIC: #{keyword} (#{data['article_count']} articles)"
      f.puts ""

      if data['summary']
        # サマリーを改行して読みやすくする
        summary = data['summary']
        # ### で始まるセクションを処理
        summary.split("\n").each do |line|
          if line.start_with?('###')
            f.puts ""
            f.puts line
            f.puts ""
          elsif line.start_with?('- ')
            f.puts "  " + line
          elsif line.start_with?('**')
            f.puts ""
            f.puts line
            f.puts ""
          else
            f.puts line if line.strip.length > 0
          end
        end
      end

      f.puts ""
      f.puts "-" * 70
      f.puts ""
    end
  end

  # ブックマーク詳細セクション
  f.puts "=" * 70
  f.puts "BOOKMARKS IN DETAIL"
  f.puts "=" * 70
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
    f.puts "Date: #{created.strftime('%m/%d %H:%M')}"
    f.puts "Link: #{url}"
    f.puts ""

    if content_data && content_data.is_a?(Hash) && content_data['content']
      summary = content_data['content']
      f.puts "Summary:"
      f.puts ""

      # 箇条書きを改行して読みやすくする
      summary.split("\n").each do |line|
        if line.start_with?('- ')
          f.puts "  #{line}"
        else
          f.puts line if line.strip.length > 0
        end
      end
    else
      f.puts "[Summary not available]"
    end
  end

  f.puts ""
  f.puts "=" * 70
  f.puts "END OF REPORT"
  f.puts "=" * 70
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
    puts "Success! Sent to: #{ENV['KINDLE_EMAIL']}"
  else
    puts "Send failed"
  end
rescue => e
  puts "Error: #{e.message}"
end

puts ""
