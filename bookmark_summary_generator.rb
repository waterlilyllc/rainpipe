# bookmark_summary_generator.rb
#
# BookmarkSummaryGenerator - GPT を使用したブックマークサマリー生成
#
# 責務:
#   - Task 7.1: Gatherly で取得した content から GPT でサマリーを生成
#   - フィルタ済みブックマークのサマリー生成（複数件対応）
#   - 実行時間計測
#   - エラーハンドリング

require 'net/http'
require 'json'

class BookmarkSummaryGenerator
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  MAX_RETRIES = 3
  INITIAL_RETRY_DELAY = 1  # 秒
  BATCH_SIZE = 10  # GPT API 呼び出し間隔制御

  def initialize(api_key = ENV['OPENAI_API_KEY'], use_mock = false)
    @api_key = api_key
    @model = ENV['GPT_MODEL'] || 'gpt-4o-mini'
    @use_mock = use_mock
    @start_time = Time.now
  end

  # Task 7.1: フィルタ済みブックマークのサマリー生成
  # @param bookmarks [Array<Hash>] ブックマーク配列（content フィールド必須）
  # @return [Hash] { summaries: [String], success_count: Integer, failure_count: Integer, duration_ms: Integer }
  def generate_summaries(bookmarks)
    start_time = Time.now

    summaries = []
    success_count = 0
    failure_count = 0

    bookmarks.each_with_index do |bookmark, index|
      content = bookmark['content']
      title = bookmark['title']

      # コンテンツが空または nil の場合は スキップ
      if content.nil? || content.to_s.strip.empty?
        puts "⚠️  ブックマーク \"#{title}\" のコンテンツが空です。スキップ"
        failure_count += 1
        next
      end

      # モック モード チェック（早期リターン）
      if @use_mock
        summary = "テスト要約 (#{title[0...30]}): #{content[0...50]}..."
      else
        # Task 7.1: GPT API でサマリー生成
        summary = generate_single_summary(content, title)
      end

      if summary
        summaries << summary
        success_count += 1
        puts "✅ サマリー生成成功: #{title}"
      else
        failure_count += 1
        puts "⚠️  サマリー生成失敗: #{title}"
      end

      # バッチ処理：処理数が BATCH_SIZE の倍数の時に GC.start()
      if (index + 1) % BATCH_SIZE == 0
        GC.start
      end
    end

    duration_ms = ((Time.now - start_time) * 1000).to_i

    puts "📊 サマリー生成完了: #{success_count} 成功、#{failure_count} 失敗"

    {
      summaries: summaries,
      success_count: success_count,
      failure_count: failure_count,
      duration_ms: duration_ms
    }
  end

  private

  # 単一ブックマークのサマリー生成
  # @param content [String] ブックマークのコンテンツ
  # @param title [String] ブックマークのタイトル
  # @return [String, nil] 生成されたサマリー、失敗時は nil
  def generate_single_summary(content, title)
    # モック モード チェック（早期リターン）
    if @use_mock
      return "テスト要約 (#{title[0...30]}): #{content[0...50]}..."
    end

    # コンテンツを短縮（長すぎる場合は先頭 2000 文字のみ使用）
    short_content = content.to_s[0...2000]

    # プロンプト：「以下の記事の内容を簡潔に要約してください」
    prompt = <<~PROMPT
      記事タイトル: #{title}

      記事の内容:
      #{short_content}

      上記の記事を 1 〜 2 文で簡潔に要約してください。
    PROMPT

    # Task 7.1: exponential backoff でリトライ
    retry_with_backoff do
      call_gpt_api(prompt)
    end
  end

  # GPT API エラーハンドリングと exponential backoff
  # @param block [Proc] 実行するブロック
  # @return [String, nil] GPT レスポンス結果、失敗時は nil
  def retry_with_backoff
    MAX_RETRIES.times do |attempt|
      begin
        return yield
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        if attempt < MAX_RETRIES - 1
          delay = INITIAL_RETRY_DELAY * (2 ** attempt)
          puts "⚠️  API タイムアウト（試行 #{attempt + 1}/#{MAX_RETRIES}）: #{delay} 秒後に再試行..."
          sleep(delay)
        else
          puts "❌ API 最終失敗。プレースホルダーを返却します"
          return nil
        end
      rescue => e
        puts "❌ 予期しないエラー: #{e.message}"
        return nil
      end
    end
    nil
  end

  # GPT API を呼び出し
  # @param prompt [String] プロンプト
  # @return [String, nil] レスポンス、エラー時は nil
  def call_gpt_api(prompt)
    # モックモード用応答
    if @use_mock
      return "テスト要約: #{prompt.split('\n').first[0...50]}..."
    end

    uri = URI.parse(OPENAI_API_URL)

    payload = {
      model: @model,
      messages: [
        { role: 'system', content: 'あなたは有用な AI アシスタントです。日本語で簡潔に要約してください。' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.7,
      max_tokens: 200
    }

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    request.body = payload.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 30

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body, symbolize_names: true)
      data.dig(:choices, 0, :message, :content)
    else
      puts "⚠️  GPT API エラー: #{response.code} #{response.message}"
      nil
    end
  end
end
