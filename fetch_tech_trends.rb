#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load('/var/git/rainpipe/.env')

require 'json'
require 'net/http'
require 'uri'
require 'time'

class TechTrendsFetcher
  TREND_SOURCES = [
    "GitHub Trending",
    "HackerNews",
    "Dev.to",
    "Stack Overflow trends",
    "Reddit programming"
  ]
  
  def fetch_programming_trends
    puts "🔍 プログラミング業界のトレンドを収集中..."
    
    # 複数のクエリで最新トレンドを検索
    trend_queries = [
      "programming trends 2025 最新",
      "GitHub trending this week",
      "新しいプログラミング言語 フレームワーク 2025",
      "開発者 注目 技術 トレンド",
      "エンジニア 話題 ツール 最新"
    ]
    
    all_trends = {}
    
    trend_queries.each do |query|
      trends = search_trends(query)
      analyze_trends(trends, all_trends)
      sleep(1) # API制限対策
    end
    
    # トレンドワードを抽出してランキング
    trending_keywords = extract_trending_keywords(all_trends)
    
    # GPTでトレンドを分析
    analyzed_trends = analyze_with_gpt(trending_keywords)
    
    save_trends(analyzed_trends)
    analyzed_trends
  end
  
  private
  
  def search_trends(query)
    uri = URI('https://www.googleapis.com/customsearch/v1')
    params = {
      key: ENV['GOOGLE_API_KEY'],
      cx: ENV['GOOGLE_CUSTOM_SEARCH_CX'],
      q: query,
      num: 10,
      dateRestrict: 'd7',
      lr: 'lang_ja'
    }
    uri.query = URI.encode_www_form(params)
    
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      data['items'] || []
    else
      []
    end
  rescue => e
    puts "検索エラー: #{e.message}"
    []
  end
  
  def analyze_trends(items, all_trends)
    items.each do |item|
      # タイトルとスニペットから技術用語を抽出
      text = "#{item['title']} #{item['snippet']}".downcase
      
      # 技術関連のキーワードパターン
      tech_patterns = [
        /\b(rust|go|golang|python|javascript|typescript|ruby|java|kotlin|swift)\b/,
        /\b(react|vue|angular|svelte|nextjs|nuxt)\b/,
        /\b(ai|ml|machine learning|llm|gpt|claude|gemini)\b/,
        /\b(docker|kubernetes|k8s|cloud|aws|gcp|azure)\b/,
        /\b(wasm|webassembly|blockchain|web3|defi)\b/,
        /\b(devops|ci\/cd|github actions|gitlab)\b/,
        /\b(graphql|rest api|grpc|websocket)\b/,
        /\b(microservices|serverless|edge computing)\b/
      ]
      
      tech_patterns.each do |pattern|
        matches = text.scan(pattern)
        matches.each do |match|
          keyword = match.is_a?(Array) ? match[0] : match
          all_trends[keyword] ||= 0
          all_trends[keyword] += 1
        end
      end
    end
  end
  
  def extract_trending_keywords(all_trends)
    # 出現頻度でソートして上位を取得
    all_trends.sort_by { |_, count| -count }
              .first(20)
              .map { |keyword, count| { keyword: keyword, frequency: count } }
  end
  
  def analyze_with_gpt(trending_keywords)
    return [] if trending_keywords.empty?
    
    prompt = build_trend_analysis_prompt(trending_keywords)
    
    uri = URI('https://api.openai.com/v1/chat/completions')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{ENV['OPENAI_API_KEY']}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: ENV['GPT_MODEL'] || 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: 'あなたはプログラミング業界のトレンドアナリストです。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.5,
      max_tokens: 2000,
      response_format: { type: "json_object" }
    }.to_json
    
    response = http.request(request)
    
    if response.code == '200'
      data = JSON.parse(response.body)
      content = data.dig('choices', 0, 'message', 'content')
      JSON.parse(content) rescue {}
    else
      {}
    end
  rescue => e
    puts "GPT分析エラー: #{e.message}"
    {}
  end
  
  def build_trend_analysis_prompt(keywords)
    keyword_list = keywords.map { |k| "- #{k[:keyword]} (出現: #{k[:frequency]}回)" }.join("\n")
    
    <<~PROMPT
      以下は今週のプログラミング関連記事から抽出したキーワードです：
      
      #{keyword_list}
      
      これらから今週のプログラミング業界のトレンドを分析し、
      開発者が注目すべきトップ10のトレンドワードを選んでください。
      
      JSON形式で回答してください：
      {
        "trends": [
          {
            "keyword": "トレンドワード",
            "category": "カテゴリ（language/framework/tool/concept）",
            "importance": 1-10の重要度,
            "reason": "なぜ今注目すべきか",
            "related_topics": ["関連トピック1", "関連トピック2"],
            "use_cases": ["具体的な使用例や応用分野"]
          }
        ],
        "summary": "今週のトレンド全体のサマリー（2-3文）",
        "emerging": ["今後注目されそうな新しい技術"],
        "analysis_date": "#{Date.today}"
      }
    PROMPT
  end
  
  def save_trends(analyzed_trends)
    return if analyzed_trends.empty?
    
    data = {
      fetched_at: Time.now.iso8601,
      trends: analyzed_trends['trends'] || [],
      summary: analyzed_trends['summary'],
      emerging: analyzed_trends['emerging'] || []
    }
    
    Dir.mkdir('./data/tech_trends') unless Dir.exist?('./data/tech_trends')
    
    filename = "./data/tech_trends/trends_#{Time.now.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(filename, JSON.pretty_generate(data))
    
    # 最新版も保存
    File.write('./data/tech_trends/latest.json', JSON.pretty_generate(data))
    
    puts "✅ トレンド分析を保存しました"
    
    # トレンドワードを表示
    if data[:trends].any?
      puts "\n📈 今週のプログラミングトレンド TOP10:"
      data[:trends].each_with_index do |trend, idx|
        puts "\n#{idx + 1}. #{trend['keyword']} (重要度: #{trend['importance']}/10)"
        puts "   理由: #{trend['reason']}"
      end
      
      puts "\n💡 サマリー: #{data[:summary]}"
    end
  end
end

# 実行
if __FILE__ == $0
  fetcher = TechTrendsFetcher.new
  fetcher.fetch_programming_trends
end