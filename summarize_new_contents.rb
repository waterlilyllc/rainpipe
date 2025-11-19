#!/usr/bin/env ruby
require 'dotenv/load'
require 'sqlite3'
require 'net/http'
require 'json'
require 'uri'

# OpenAI APIで要約を生成
def summarize_with_openai(content, title)
  api_key = ENV['OPENAI_API_KEY']

  uri = URI.parse('https://api.openai.com/v1/chat/completions')

  prompt = <<~PROMPT
    以下の記事を10個程度の箇条書きで要約してください。
    各箇条書きは「- 」で始めてください。
    重要なポイントを簡潔にまとめてください。

    記事タイトル: #{title}

    記事本文:
    #{content[0..3000]}
  PROMPT

  request = Net::HTTP::Post.new(uri)
  request['Content-Type'] = 'application/json'
  request['Authorization'] = "Bearer #{api_key}"

  request.body = {
    model: 'gpt-4o-mini',
    messages: [
      { role: 'system', content: 'あなたは記事を簡潔に要約する専門家です。' },
      { role: 'user', content: prompt }
    ],
    temperature: 0.3,
    max_tokens: 1000
  }.to_json

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 60

  response = http.request(request)

  if response.is_a?(Net::HTTPSuccess)
    result = JSON.parse(response.body)
    result.dig('choices', 0, 'message', 'content')
  else
    puts "  ❌ API Error: #{response.code} #{response.message}"
    nil
  end
rescue => e
  puts "  ❌ Exception: #{e.message}"
  nil
end

# 最新の9件を要約
db = SQLite3::Database.new('data/rainpipe.db')
db.results_as_hash = true

raindrop_ids = [
  1433198671, 1433152770, 1433152562, 1433039470, 1432842749,
  1432189775, 1432059613, 1431668962, 1431664546
]

puts "📝 新規コンテンツを要約中..."
puts "="*80
puts ""

success_count = 0
failed_count = 0

raindrop_ids.each_with_index do |raindrop_id, i|
  row = db.get_first_row(
    "SELECT raindrop_id, title, content FROM bookmark_contents WHERE raindrop_id = ?",
    raindrop_id
  )

  unless row
    puts "[#{i+1}/9] ❌ ID #{raindrop_id}: データなし"
    failed_count += 1
    next
  end

  content = row['content']
  title = row['title']

  # 既に要約済みかチェック（箇条書き形式か）
  if content.start_with?('- ')
    puts "[#{i+1}/9] ⏭️  ID #{raindrop_id}: 既に要約済み"
    success_count += 1
    next
  end

  puts "[#{i+1}/9] 📄 ID #{raindrop_id}"
  puts "  Title: #{title[0..60]}..."
  puts "  Original length: #{content.length} chars"

  # OpenAI APIで要約
  summary = summarize_with_openai(content, title)

  if summary
    puts "  ✅ 要約完了 (#{summary.length} chars)"

    # データベース更新
    db.execute(
      "UPDATE bookmark_contents SET content = ?, updated_at = datetime('now') WHERE raindrop_id = ?",
      summary,
      raindrop_id
    )
    puts "  ✅ DB更新完了"
    success_count += 1
  else
    puts "  ❌ 要約失敗"
    failed_count += 1
  end

  puts ""

  # レート制限対策
  sleep 1 if i < raindrop_ids.length - 1
end

db.close

puts "="*80
puts "結果: 成功 #{success_count}/9, 失敗 #{failed_count}/9"
puts "="*80
