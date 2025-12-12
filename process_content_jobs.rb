#!/usr/bin/env ruby
# バックグラウンドで本文取得ジョブを処理
# cron: */5 * * * * (5分ごと)

require 'dotenv/load'
require_relative 'bookmark_content_fetcher'

puts "=" * 80
puts "📚 本文取得ジョブ処理開始"
puts "   時刻: #{Time.now}"
puts "=" * 80

fetcher = BookmarkContentFetcher.new

# 1. pending状態のジョブを確認して本文を保存
puts "\n📥 1. pending状態のジョブを確認中..."
update_stats = fetcher.update_pending_jobs

if update_stats && update_stats[:updated] && update_stats[:updated] > 0
  puts "✅ #{update_stats[:updated]}件の本文を保存しました"
  puts "   - 成功: #{update_stats[:completed]}件"
  puts "   - 失敗: #{update_stats[:failed]}件"
  puts "   - 処理中: #{update_stats[:still_pending]}件"
else
  puts "ℹ️ 処理対象のジョブなし"
end

# 2. 失敗したジョブを再試行
puts "\n🔄 2. 失敗したジョブを再試行中..."
retried_count = fetcher.retry_failed_jobs

if retried_count && retried_count > 0
  puts "✅ #{retried_count}件のジョブを再試行しました"
else
  puts "ℹ️ 再試行対象のジョブなし"
end

# 3. タイムアウトしたジョブを失敗にする
puts "\n⏱️ 3. タイムアウトジョブを確認中..."
timeout_count = fetcher.handle_timeout_jobs

if timeout_count && timeout_count > 0
  puts "⚠️ #{timeout_count}件のジョブがタイムアウトしました"
else
  puts "ℹ️ タイムアウトなし"
end

# 4. 本文取得済みだが未要約のコンテンツを要約
puts "\n📝 4. 未要約コンテンツをChatGPTで要約中..."

require 'sqlite3'
require 'net/http'
require 'json'
require 'uri'

api_key = ENV['OPENAI_API_KEY']

if api_key
  db = SQLite3::Database.new('data/rainpipe.db')
  db.results_as_hash = true

  # 本文があり、要約されていない（箇条書き形式でない）ものを取得
  # 直近7日間に作成されたジョブに限定
  unsummarized = db.execute(<<-SQL)
    SELECT bc.raindrop_id, bc.title, bc.content
    FROM bookmark_contents bc
    INNER JOIN crawl_jobs cj ON bc.raindrop_id = cj.raindrop_id
    WHERE bc.content IS NOT NULL
      AND LENGTH(bc.content) > 100
      AND bc.content NOT LIKE '- %'
      AND cj.created_at > datetime('now', '-7 days')
    ORDER BY cj.created_at DESC
    LIMIT 20
  SQL

  if unsummarized.any?
    puts "⚠️  #{unsummarized.length}件の未要約コンテンツがあります"

    unsummarized.each_with_index do |row, i|
      raindrop_id = row['raindrop_id']
      title = row['title']
      content = row['content']

      puts "[#{i+1}/#{unsummarized.length}] #{title[0..50]}..."

      # OpenAI APIで要約
      uri = URI.parse('https://api.openai.com/v1/chat/completions')
      prompt = <<~PROMPT
        以下の記事を日本語で要約してください。
        - 箇条書き形式（各項目を「- 」で始める）
        - 3〜5項目程度
        - 重要なポイントを簡潔に

        タイトル: #{title}

        本文:
        #{content[0..3000]}
      PROMPT

      request_body = {
        model: 'gpt-4o-mini',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 500,
        temperature: 0.3
      }

      begin
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 60

        request = Net::HTTP::Post.new(uri.path)
        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{api_key}"
        request.body = request_body.to_json

        response = http.request(request)

        if response.code == '200'
          result = JSON.parse(response.body)
          summary = result.dig('choices', 0, 'message', 'content')
          if summary
            db.execute(
              "UPDATE bookmark_contents SET content = ?, updated_at = datetime('now') WHERE raindrop_id = ?",
              [summary, raindrop_id]
            )
            puts "  ✅ 要約完了"
          end
        else
          puts "  ❌ API Error: #{response.code}"
        end
      rescue => e
        puts "  ❌ Error: #{e.message}"
      end

      sleep 0.5  # レート制限対策
    end
  else
    puts "✅ 全てのコンテンツが要約済みです"
  end

  db.close
else
  puts "⚠️  OPENAI_API_KEY が設定されていないため要約をスキップ"
end

# 5. 統計情報を表示
puts "\n📊 5. 統計情報"
stats = fetcher.print_stats

puts "\n" + "=" * 80
puts "✅ 処理完了"
puts "=" * 80
