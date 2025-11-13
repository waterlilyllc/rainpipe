require 'net/http'
require 'json'
require 'uri'

class GPTKeywordExtractor
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  
  def initialize(api_key = ENV['OPENAI_API_KEY'])
    @api_key = api_key
    @model = ENV['GPT_MODEL'] || 'gpt-4o-mini'
  end
  
  # 週次ブックマークからキーワードを抽出
  def extract_keywords_from_bookmarks(bookmarks, week_key)
    # ブックマークデータを整形
    bookmark_texts = format_bookmarks_for_gpt(bookmarks)
    
    # GPTに送信するプロンプト
    prompt = build_extraction_prompt(bookmark_texts, week_key)
    
    # GPT APIを呼び出し
    response = call_gpt_api(prompt)
    
    # レスポンスをパース
    parse_gpt_response(response)
  end
  
  private
  
  # ブックマークデータをGPT用に整形
  def format_bookmarks_for_gpt(bookmarks)
    bookmarks.map do |bookmark|
      text = []
      text << "タイトル: #{bookmark['title']}" if bookmark['title']
      text << "タグ: #{bookmark['tags'].join(', ')}" if bookmark['tags'] && bookmark['tags'].any?
      text << "説明: #{bookmark['excerpt']}" if bookmark['excerpt']
      text << "URL: #{bookmark['link']}" if bookmark['link']
      text.join("\n")
    end.join("\n---\n")
  end
  
  # GPT用のプロンプトを構築
  def build_extraction_prompt(bookmark_texts, week_key)
    <<~PROMPT
      以下は#{week_key}の私のブックマーク一覧です。
      これらのブックマークから、私の関心事や興味のあるトピックを分析してください。

      ブックマーク:
      #{bookmark_texts}

      以下の形式でJSONを返してください：
      {
        "primary_interests": [
          {
            "keyword": "キーワード",
            "frequency": 出現回数,
            "importance": 1-10の重要度スコア,
            "category": "カテゴリ名",
            "reason": "なぜ重要か"
          }
        ],
        "emerging_interests": [
          {
            "keyword": "新しく現れたキーワード",
            "potential": "今後の可能性"
          }
        ],
        "related_clusters": [
          {
            "main_topic": "メイントピック",
            "related_words": ["関連ワード1", "関連ワード2"]
          }
        ],
        "weekly_trend": {
          "focus_shift": "先週と比べた関心の変化",
          "new_areas": ["新しい関心分野"],
          "declining_areas": ["関心が薄れた分野"]
        },
        "insights": {
          "summary": "全体的な傾向の要約",
          "recommendations": ["今後チェックすべきトピック"]
        }
      }

      注意事項:
      - 技術用語は正確に抽出してください
      - 日本語と英語の両方を考慮してください
      - 一般的すぎる単語は除外してください
      - 製品名、サービス名、技術名を重視してください
    PROMPT
  end
  
  # GPT APIを呼び出し
  def call_gpt_api(prompt)
    uri = URI(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: @model,
      messages: [
        {
          role: 'system',
          content: 'あなたは優秀なデータアナリストです。ユーザーのブックマークから関心事を分析し、構造化されたJSONで返答してください。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      response_format: { type: "json_object" }
    }.to_json
    
    response = http.request(request)
    JSON.parse(response.body)
  end
  
  # GPTのレスポンスをパース
  def parse_gpt_response(response)
    return nil if response['error']
    
    content = response.dig('choices', 0, 'message', 'content')
    return nil unless content
    
    begin
      JSON.parse(content)
    rescue JSON::ParserError => e
      puts "JSON parse error: #{e.message}"
      nil
    end
  end
  
  # 週次比較用の高度な分析
  def analyze_weekly_changes(current_week_bookmarks, previous_week_data)
    prompt = <<~PROMPT
      現在の週のブックマークと前週のキーワードデータを比較して、
      変化やトレンドを分析してください。

      今週のブックマーク:
      #{format_bookmarks_for_gpt(current_week_bookmarks)}

      前週の主要キーワード:
      #{previous_week_data.to_json}

      以下を分析してください：
      1. 継続している関心事
      2. 新しく出現した関心事
      3. 関心が薄れた分野
      4. 関心の深まり（同じトピックでもより専門的になっているか）
      5. 予想される今後のトレンド
    PROMPT
    
    response = call_gpt_api(prompt)
    parse_gpt_response(response)
  end
end

# 使用例
=begin
extractor = GPTKeywordExtractor.new
bookmarks = RaindropClient.new.get_weekly_bookmarks(start_date, end_date)
keywords = extractor.extract_keywords_from_bookmarks(bookmarks, "2025-W28")

if keywords
  puts "主要な関心事："
  keywords['primary_interests'].each do |interest|
    puts "- #{interest['keyword']} (重要度: #{interest['importance']})"
  end
end
=end