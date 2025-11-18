#!/usr/bin/env ruby
$stdout.sync = true

require 'dotenv/load'
require 'net/http'
require 'json'
require_relative 'bookmark_content_manager'
require_relative 'content_summarizer'

job_uuid = "1b9959b0-9e51-4639-8ff2-509ea7f8813b"
raindrop_id = 1428368854

puts "Gatherly APIから本文を手動取得中..."
puts "Job UUID: #{job_uuid}"
puts ""

# Gatherly APIからジョブ詳細を取得
api_url = ENV['GATHERLY_API_URL'] || 'http://nas.taileef971.ts.net:3002'
api_key = ENV['GATHERLY_API_KEY']

uri = URI.parse("#{api_url}/api/v1/crawl_jobs/#{job_uuid}")
request = Net::HTTP::Get.new(uri)
request['Authorization'] = "Bearer #{api_key}"

response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
  http.request(request)
end

if !response.is_a?(Net::HTTPSuccess)
  puts "❌ ジョブ情報の取得に失敗: #{response.code} #{response.message}"
  exit 1
end

job_data = JSON.parse(response.body)
puts "ジョブステータス: #{job_data['status']}"

if job_data['status'] != 'completed'
  puts "⚠️  ジョブが完了していません"
  exit 1
end

# 本文データを直接取得（DB から fetched_pages を取得）
# または Web UI から直接コピー
# 今回は簡易的に Qiita API を使って本文を取得

puts ""
puts "Qiita記事の本文を取得中..."

url = "https://qiita.com/Satoooon/items/cc6df7679ecd74c2fa11"

# Qiita APIではなくHTMLをパース（簡易版）
require 'open-uri'
require 'nokogiri'

begin
  html = URI.open(url, 'User-Agent' => 'Mozilla/5.0').read
  doc = Nokogiri::HTML(html)

  title = doc.css('h1.css-ew20hi').text.strip

  # 記事本文を抽出
  content_nodes = doc.css('.it-MdContent')

  if content_nodes.empty?
    puts "❌ 本文が見つかりませんでした"
    exit 1
  end

  # 段落ごとに箇条書きに変換
  content_parts = []
  content_nodes.css('h2, h3, p, pre, li').each do |node|
    text = node.text.strip
    next if text.empty?

    case node.name
    when 'h2', 'h3'
      content_parts << "■ #{text}"
    when 'p', 'li'
      content_parts << "- #{text[0..150]}#{'...' if text.length > 150}"
    when 'pre'
      content_parts << "- [コード省略]"
    end
  end

  content = content_parts[0..10].join("\n") # 最初の10項目のみ

  puts "✅ 本文取得完了"
  puts "  タイトル: #{title}"
  puts "  本文長: #{content.length}文字"
  puts ""

  # データベースに保存
  manager = BookmarkContentManager.new

  data = {
    url: url,
    title: title,
    content: content,
    content_type: 'text',
    word_count: content.length,
    extracted_at: Time.now.utc.iso8601
  }

  if manager.save_content(raindrop_id, data)
    puts "✅ データベースに保存しました"

    # クロールジョブのステータスを更新
    require 'sqlite3'
    db = SQLite3::Database.new('data/rainpipe.db')
    db.execute("UPDATE crawl_jobs SET status = 'completed', updated_at = CURRENT_TIMESTAMP WHERE job_id = ?", job_uuid)

    puts "✅ クロールジョブステータスを更新しました"
  else
    puts "❌ データベースへの保存に失敗しました"
    exit 1
  end

rescue => e
  puts "❌ エラー: #{e.message}"
  puts e.backtrace.first(5)
  exit 1
end
