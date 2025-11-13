# gpt_content_generator.rb
#
# GPTContentGenerator - GPT API を使用した 3 段階コンテンツ生成
#
# 責務:
#   - Task 5.1: 全体サマリーセクション生成（GPT 呼び出し）
#   - Task 5.2: 関連ワード抽出セクション生成（GPTKeywordExtractor）
#   - Task 5.3: 考察セクション生成（動的生成、キャッシュなし）
#   - Task 5.4: GPT API エラーハンドリングと exponential backoff

require 'net/http'
require 'json'
require_relative 'gpt_keyword_extractor'

class GPTContentGenerator
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  MAX_RETRIES = 3
  INITIAL_RETRY_DELAY = 1  # 秒

  def initialize(api_key = ENV['OPENAI_API_KEY'], use_mock = false)
    @api_key = api_key
    @model = ENV['GPT_MODEL'] || 'gpt-4o-mini'
    @use_mock = use_mock

    if use_mock
      @keyword_extractor = Object.const_defined?(:MockGPTKeywordExtractor) ? MockGPTKeywordExtractor.new : nil
    else
      @keyword_extractor = GPTKeywordExtractor.new(api_key)
    end
  end

  # Task 5.1: 全体サマリーセクション生成（GPT 呼び出し）
  # @param bookmarks [Array<Hash>] フィルタ済みブックマーク
  # @param keywords [String] キーワード（カンマ区切り）
  # @return [Hash] { summary: String, duration_ms: Integer }
  def generate_overall_summary(bookmarks, keywords)
    start_time = Time.now

    raise "ブックマークが空です" if bookmarks.empty?

    # ブックマークの context を構築
    context = format_bookmarks_for_prompt(bookmarks)

    # プロンプト: 「以下のキーワード領域のブックマークを分析して、傾向・重要ポイント・実用的な洞察を含むサマリーを生成してください」
    prompt = <<~PROMPT
      以下の「#{keywords}」領域のブックマークを分析して、傾向・重要ポイント・実用的な洞察を含むサマリーを日本語で生成してください。

      ブックマークの内容:
      #{context}

      分析した傾向と重要ポイント、実用的な洞察を含むサマリーを生成してください。
    PROMPT

    # Task 5.4: GPT API エラーハンドリングと exponential backoff
    result = retry_with_backoff do
      call_gpt_api(prompt)
    end

    duration_ms = ((Time.now - start_time) * 1000).to_i

    if result
      puts "✅ 全体サマリー生成成功"
      {
        summary: result,
        duration_ms: duration_ms
      }
    else
      puts "❌ 全体サマリー生成に失敗"
      raise "GPT API によるサマリー生成失敗"
    end
  end

  # Task 5.2: 関連ワード抽出セクション生成（GPTKeywordExtractor）
  # @param bookmarks [Array<Hash>] フィルタ済みブックマーク
  # @return [Hash] { related_clusters: Array, duration_ms: Integer }
  def extract_related_keywords(bookmarks)
    start_time = Time.now

    raise "ブックマークが空です" if bookmarks.empty?

    # Task 5.2: GPTKeywordExtractor.extract_keywords_from_bookmarks を呼び出し
    result = @keyword_extractor.extract_keywords_from_bookmarks(bookmarks, 'filtered')

    # 返却された related_clusters を取得（各要素は { main_topic: String, related_words: [String] }）
    related_clusters = result.dig('related_clusters') || []

    duration_ms = ((Time.now - start_time) * 1000).to_i
    puts "✅ 関連ワード抽出成功: #{related_clusters.length} クラスタ"

    {
      related_clusters: related_clusters,
      duration_ms: duration_ms
    }
  end

  # Task 5.3: 考察セクション生成（動的生成、キャッシュなし）
  # @param bookmarks [Array<Hash>] フィルタ済みブックマーク
  # @param keywords [String] キーワード（カンマ区切り）
  # @return [Hash] { analysis: String, duration_ms: Integer }
  def generate_analysis(bookmarks, keywords)
    start_time = Time.now

    raise "ブックマークが空です" if bookmarks.empty?

    # ブックマークの context を構築
    context = format_bookmarks_for_prompt(bookmarks)

    # Task 5.3: プロンプト：「キーワード領域での今後の注目点・実装への示唆・ベストプラクティスを含める考察を生成」
    # キャッシュなし（毎回実行時に生成）
    prompt = <<~PROMPT
      以下の「#{keywords}」領域のブックマークに基づいて、今後の注目点・実装への示唆・ベストプラクティスを含める考察を日本語で生成してください。

      ブックマークの内容:
      #{context}

      今後の注目点、実装への示唆、ベストプラクティスを含める実用的な考察を生成してください。
    PROMPT

    # Task 5.4: GPT API エラーハンドリングと exponential backoff
    result = retry_with_backoff do
      call_gpt_api(prompt)
    end

    duration_ms = ((Time.now - start_time) * 1000).to_i

    if result
      puts "✅ 考察生成成功"
      {
        analysis: result,
        duration_ms: duration_ms
      }
    else
      puts "❌ 考察生成に失敗"
      raise "GPT API による考察生成失敗"
    end
  end

  # Task 5.4: GPT API エラーハンドリングと exponential backoff
  # @param block [Proc] 実行するブロック
  # @return [String, nil] GPT レスポンス結果、失敗時は nil
  def retry_with_backoff
    MAX_RETRIES.times do |attempt|
      begin
        return yield
      rescue Net::OpenTimeout, Net::ReadTimeout, Net::HTTPError => e
        if attempt < MAX_RETRIES - 1
          # リトライ間隔：1 秒、2 秒、4 秒（exponential backoff）
          delay = INITIAL_RETRY_DELAY * (2 ** attempt)
          puts "⚠️  API エラー（試行 #{attempt + 1}/#{MAX_RETRIES}）: #{e.message}。#{delay} 秒後に再試行..."
          sleep(delay)
        else
          puts "❌ API 最終失敗"
          return nil
        end
      rescue StandardError => e
        puts "❌ エラー: #{e.message}"
        return nil
      end
    end
    nil
  end

  private

  # ブックマークの本文コンテンツをサマリー化（公開メソッド）
  # @param content [String] Gatherlyから取得した本文内容
  # @return [String] サマリー化されたテキスト
  public
  def generate_bookmark_summary(content)
    return '' if content.nil? || content.to_s.strip.empty?

    # 長すぎるテキストは最初の3000文字に制限
    truncated_content = content.to_s.length > 3000 ? content[0..3000] + '...' : content.to_s

    prompt = <<~PROMPT
      以下の記事内容を、箇条書きで300文字程度の簡潔なサマリーに要約してください。日本語で出力してください。

      ---
      #{truncated_content}
      ---

      要約:
    PROMPT

    result = retry_with_backoff do
      call_gpt_api(prompt)
    end

    raise "ブックマークサマリー生成失敗" unless result

    result.strip
  end

  private

  # ブックマークをプロンプト用に整形
  def format_bookmarks_for_prompt(bookmarks)
    bookmarks.map do |bookmark|
      text = []
      text << "タイトル: #{bookmark['title']}" if bookmark['title']
      text << "説明: #{bookmark['excerpt']}" if bookmark['excerpt']
      text << "URL: #{bookmark['url']}" if bookmark['url']
      text.join("\n")
    end.join("\n---\n")
  end

  # GPT API を呼び出し
  def call_gpt_api(prompt)
    # モードテスト用モック応答
    if @use_mock
      return "テスト応答: #{prompt[0..50]}..."
    end

    uri = URI.parse(OPENAI_API_URL)

    payload = {
      model: @model,
      messages: [
        { role: 'system', content: 'あなたは有用な AI アシスタントです。日本語で回答してください。' },
        { role: 'user', content: prompt }
      ],
      temperature: 0.7,
      max_tokens: 1500
    }

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"
    request.body = payload.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 60

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body, symbolize_names: true)
      data.dig(:choices, 0, :message, :content)
    else
      raise "GPT API Error: #{response.code} #{response.message}"
    end
  end
end
