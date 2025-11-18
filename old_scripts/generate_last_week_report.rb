#!/usr/bin/env ruby
# 先週のブックマークをレポート生成してKindleに送信（改善版）

require 'dotenv/load'
require 'json'
require 'fileutils'
require_relative 'raindrop_client'
require_relative 'bookmark_content_manager'
require_relative 'kindle_email_sender'

puts "=" * 80
puts "先週のブックマーク - レポート生成＆Kindle送信"
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

puts "📅 対象期間: #{last_week_start.strftime('%Y-%m-%d')}（日） ～ #{last_week_end.strftime('%Y-%m-%d')}（土）"
puts ""

# 先週のブックマークをフィルタ
last_week_bookmarks = all_bookmarks.select do |bookmark|
  created_time = Time.parse(bookmark['created'])
  created_time >= week_start_time && created_time <= week_end_time
end.sort_by { |b| Time.parse(b['created']) }.reverse

puts "📚 先週のブックマーク: #{last_week_bookmarks.length}件"

with_content = 0
without_content = 0
last_week_bookmarks.each do |b|
  content_data = content_manager.get_content(b['_id'])
  if content_data && content_data.is_a?(Hash) && content_data['content']
    with_content += 1
  else
    without_content += 1
  end
end

puts "  - 要約あり: #{with_content}件"
puts "  - 要約なし: #{without_content}件"
puts ""

if last_week_bookmarks.empty?
  puts "⚠️ 先週のブックマークがありません"
  exit 0
end

# テキストベースのレポート生成
report_path = File.join(File.dirname(__FILE__), 'data', "weekly_report_#{last_week_end.strftime('%Y%m%d')}_v2.txt")
FileUtils.mkdir_p(File.dirname(report_path))

puts "📝 テキストレポート生成中: #{report_path}"
puts ""

File.open(report_path, 'w') do |f|
  f.puts ""
  f.puts "=" * 80
  f.puts "📅 週間ブックマークレポート"
  f.puts "=" * 80
  f.puts ""
  f.puts "期間: #{last_week_start.strftime('%Y年%m月%d日')}（日） ～ #{last_week_end.strftime('%Y年%m月%d日')}（土）"
  f.puts "生成日時: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  f.puts "アイテム数: #{last_week_bookmarks.length}件"
  f.puts ""

  last_week_bookmarks.each_with_index do |bookmark, idx|
    f.puts ""
    f.puts "=" * 80
    f.puts "[#{idx + 1}/#{last_week_bookmarks.length}] #{bookmark['title']}"
    f.puts "=" * 80
    f.puts ""

    created = Time.parse(bookmark['created'])
    url = bookmark['link']

    f.puts "📅 日時: #{created.strftime('%Y-%m-%d %H:%M')}"
    f.puts "🔗 URL: #{url}"
    f.puts ""

    content_data = content_manager.get_content(bookmark['_id'])

    if content_data && content_data.is_a?(Hash) && content_data['content']
      summary = content_data['content']
      f.puts "📝 要約:"
      f.puts "-" * 80
      f.puts summary
      f.puts "-" * 80
    else
      f.puts "⚠️ 要約なし（コンテンツが取得されていません）"
    end

    f.puts ""
  end

  # 最後のページに統計
  f.puts ""
  f.puts "=" * 80
  f.puts "📊 統計情報"
  f.puts "=" * 80
  f.puts ""
  f.puts "総ブックマーク数: #{last_week_bookmarks.length}件"
  f.puts "要約あり: #{with_content}件 (#{(with_content.to_f / last_week_bookmarks.length * 100).round(1)}%)"
  f.puts "要約なし: #{without_content}件 (#{(without_content.to_f / last_week_bookmarks.length * 100).round(1)}%)"
  f.puts ""
  f.puts "生成: Rainpipe Weekly Report Generator"
  f.puts ""
end

puts "✅ テキストレポート作成完了: #{File.size(report_path) / 1024}KB"
puts ""

# HTML版も生成
html_path = File.join(File.dirname(__FILE__), 'data', "weekly_report_#{last_week_end.strftime('%Y%m%d')}_v2.html")

puts "🌐 HTMLレポート生成中: #{html_path}"
puts ""

File.open(html_path, 'w', encoding: 'UTF-8') do |f|
  f.puts "<!DOCTYPE html>"
  f.puts "<html lang='ja'>"
  f.puts "<head>"
  f.puts "<meta charset='UTF-8'>"
  f.puts "<meta name='viewport' content='width=device-width, initial-scale=1.0'>"
  f.puts "<title>週間ブックマークレポート</title>"
  f.puts "<style>"
  f.puts "body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }"
  f.puts "h1 { color: #333; text-align: center; border-bottom: 3px solid #0066cc; padding-bottom: 10px; }"
  f.puts ".header { background-color: white; padding: 20px; margin-bottom: 20px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }"
  f.puts ".header p { margin: 5px 0; color: #666; }"
  f.puts ".bookmark { background-color: white; margin: 20px 0; padding: 25px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); page-break-inside: avoid; }"
  f.puts ".bookmark-title { font-weight: bold; font-size: 18px; color: #0066cc; margin-bottom: 10px; }"
  f.puts ".meta { color: #999; font-size: 13px; margin: 8px 0; }"
  f.puts ".url { color: #0066cc; text-decoration: none; word-break: break-all; }"
  f.puts ".summary { margin-top: 15px; padding: 15px; background-color: #f9f9f9; border-left: 4px solid #0066cc; line-height: 1.6; }"
  f.puts ".summary-label { font-weight: bold; color: #0066cc; margin-bottom: 10px; }"
  f.puts ".no-content { color: #ff6600; font-style: italic; }"
  f.puts ".stats { background-color: white; padding: 20px; margin-top: 40px; border-radius: 5px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }"
  f.puts ".stats h2 { color: #333; border-bottom: 2px solid #0066cc; padding-bottom: 10px; }"
  f.puts ".stat-item { margin: 10px 0; font-size: 16px; }"
  f.puts "@media print { body { background-color: white; } .bookmark { page-break-inside: avoid; } }"
  f.puts "</style>"
  f.puts "</head>"
  f.puts "<body>"

  f.puts "<h1>📅 週間ブックマークレポート</h1>"
  f.puts "<div class='header'>"
  f.puts "<p><strong>期間:</strong> #{last_week_start.strftime('%Y年%m月%d日')}（日） ～ #{last_week_end.strftime('%Y年%m月%d日')}（土）</p>"
  f.puts "<p><strong>生成日時:</strong> #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>"
  f.puts "<p><strong>アイテム数:</strong> #{last_week_bookmarks.length}件</p>"
  f.puts "</div>"

  last_week_bookmarks.each_with_index do |bookmark, idx|
    created = Time.parse(bookmark['created'])
    url = bookmark['link']
    content_data = content_manager.get_content(bookmark['_id'])

    f.puts "<div class='bookmark'>"
    f.puts "<div class='bookmark-title'>#{idx + 1}. #{bookmark['title']}</div>"
    f.puts "<div class='meta'>📅 #{created.strftime('%Y-%m-%d %H:%M')}</div>"
    f.puts "<div class='meta'>🔗 <a href='#{url}' class='url' target='_blank'>#{url}</a></div>"

    if content_data && content_data.is_a?(Hash) && content_data['content']
      summary = content_data['content']
      summary_html = summary.gsub("\n", "<br>")
      f.puts "<div class='summary'>"
      f.puts "<div class='summary-label'>📝 要約</div>"
      f.puts "<div>#{summary_html}</div>"
      f.puts "</div>"
    else
      f.puts "<div class='summary'>"
      f.puts "<div class='no-content'>⚠️ 要約が利用できません</div>"
      f.puts "</div>"
    end

    f.puts "</div>"
  end

  # 統計情報
  f.puts "<div class='stats'>"
  f.puts "<h2>📊 統計情報</h2>"
  f.puts "<div class='stat-item'>総ブックマーク数: <strong>#{last_week_bookmarks.length}件</strong></div>"
  f.puts "<div class='stat-item'>要約あり: <strong>#{with_content}件</strong> (#{(with_content.to_f / last_week_bookmarks.length * 100).round(1)}%)</div>"
  f.puts "<div class='stat-item'>要約なし: <strong>#{without_content}件</strong> (#{(without_content.to_f / last_week_bookmarks.length * 100).round(1)}%)</div>"
  f.puts "</div>"

  f.puts "</body>"
  f.puts "</html>"
end

puts "✅ HTMLレポート作成完了: #{File.size(html_path) / 1024}KB"
puts ""

# メール送信
puts "=" * 80
puts "📧 Kindle へのメール送信"
puts "=" * 80
puts ""

begin
  puts "HTML版をKindleに送信中..."
  result = email_sender.send_pdf(html_path)

  if result
    puts "✅ 送信成功！"
    puts "  宛先: #{ENV['KINDLE_EMAIL']}"
    puts "  ファイル: #{File.basename(html_path)}"
    puts ""
    puts "数分以内にKindleデバイスに配信されます。"
  else
    puts "⚠️ 送信に失敗しました"
  end
rescue => e
  puts "❌ エラー: #{e.message}"
end

puts ""
puts "=" * 80
puts "✅ 完了"
puts "=" * 80
puts ""
puts "生成されたファイル:"
puts "  1. #{report_path}"
puts "  2. #{html_path}"
puts ""
