require 'net/http'
require 'json'
require 'uri'

class ContentSummarizer
  def initialize
    @api_key = ENV['OPENAI_API_KEY']
    raise 'OPENAI_API_KEY not found in environment' unless @api_key
  end

  # 本文を5行の箇条書きに要約
  # @param content [String] 元の本文
  # @param title [String] タイトル（オプション）
  # @return [String] 箇条書き要約
  def summarize_to_bullet_points(content, title: nil)
    return nil if content.nil? || content.strip.empty?

    prompt = build_prompt(content, title)

    begin
      response = call_openai_api(prompt)
      summary = extract_summary(response)

      # 箇条書きを整形
      format_bullet_points(summary)
    rescue => e
      puts "❌ 要約エラー: #{e.message}"
      nil
    end
  end

  private

  def build_prompt(content, title)
    prompt = "以下の記事を読んで、重要なポイントを5つの箇条書きにまとめてください。\n\n"
    prompt += "【タイトル】\n#{title}\n\n" if title
    prompt += "【本文】\n#{content[0..3000]}\n\n"  # 最初の3000文字のみ使用
    prompt += "【要件】\n"
    prompt += "- 必ず5つの箇条書きで出力してください\n"
    prompt += "- 各項目は簡潔に（1-2行程度）\n"
    prompt += "- 記事の核心的な内容を抽出してください\n"
    prompt += "- 箇条書きは「- 」で始めてください\n"
    prompt
  end

  def call_openai_api(prompt)
    uri = URI.parse('https://api.openai.com/v1/chat/completions')
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{@api_key}"

    request.body = {
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'あなたは記事の要約を作成する専門家です。与えられた記事を5つの箇条書きにまとめます。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3,
      max_tokens: 500
    }.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    response = http.request(request)

    if response.code.to_i != 200
      raise "OpenAI API error: #{response.code} - #{response.body}"
    end

    JSON.parse(response.body)
  end

  def extract_summary(response)
    response.dig('choices', 0, 'message', 'content')
  end

  def format_bullet_points(summary)
    return nil unless summary

    # 既に箇条書き形式の場合はそのまま
    if summary.include?('- ')
      summary.strip
    else
      # 行ごとに分割して箇条書きに変換
      lines = summary.strip.split("\n").reject(&:empty?)
      lines.map { |line| line.start_with?('-') ? line : "- #{line}" }.join("\n")
    end
  end
end
