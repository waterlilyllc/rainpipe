#!/usr/bin/env ruby

require 'dotenv'
Dotenv.load('/var/git/rainpipe/.env')

require 'json'
require 'net/http'
require 'uri'
require 'date'
require 'time'
require 'fileutils'
require_relative 'raindrop_client'

class InterestExtractor
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  OUTPUT_DIR = './data/interests'
  
  def initialize
    @api_key = ENV['OPENAI_API_KEY']
    @model = ENV['GPT_MODEL'] || 'gpt-4o-mini'
    FileUtils.mkdir_p(OUTPUT_DIR)
  end
  
  def extract_from_recent_bookmarks(days: 30)
    puts "📚 直近#{days}日間のブックマークを取得中..."
    
    # Raindropから全ブックマークを取得して日付でフィルタ
    client = RaindropClient.new
    end_date = Date.today
    start_date = end_date - days
    
    # 全ブックマークを取得（キャッシュされたJSONから）
    all_bookmarks = client.load_all_bookmarks
    
    # 日付でフィルタリング
    bookmarks = all_bookmarks.select do |bookmark|
      created_date = Date.parse(bookmark['created'])
      created_date >= start_date && created_date <= end_date
    rescue
      false
    end
    puts "✅ #{bookmarks.length}件のブックマークを取得しました"
    
    # GPTで分析
    puts "\n🤖 GPTで関心ワードを抽出中..."
    analysis = analyze_bookmarks_with_gpt(bookmarks, start_date, end_date)
    
    if analysis
      # 結果を保存
      save_analysis(analysis, start_date, end_date)
      display_results(analysis)
    else
      puts "❌ 分析に失敗しました"
    end
  end
  
  private
  
  def analyze_bookmarks_with_gpt(bookmarks, start_date, end_date)
    # ブックマークデータを整形
    bookmark_text = format_bookmarks_for_gpt(bookmarks)
    
    # プロンプト構築
    prompt = build_analysis_prompt(bookmark_text, start_date, end_date)
    
    # GPT APIを呼び出し
    response = call_gpt_api(prompt)
    
    # レスポンスをパース
    parse_gpt_response(response)
  end
  
  def format_bookmarks_for_gpt(bookmarks)
    # 最新の50件に絞る（トークン制限対策）
    recent_bookmarks = bookmarks.sort_by { |b| b['created'] }.reverse.first(50)
    
    recent_bookmarks.map do |bookmark|
      parts = []
      parts << "【#{format_date(bookmark['created'])}】"
      parts << "タイトル: #{bookmark['title']}" if bookmark['title']
      parts << "URL: #{bookmark['link']}" if bookmark['link']
      parts << "タグ: #{bookmark['tags'].join(', ')}" if bookmark['tags'] && bookmark['tags'].any?
      parts << "説明: #{bookmark['excerpt']}" if bookmark['excerpt'] && !bookmark['excerpt'].empty?
      parts.join("\n")
    end.join("\n\n---\n\n")
  end
  
  def build_analysis_prompt(bookmark_text, start_date, end_date)
    <<~PROMPT
      あなたは優秀なデータアナリストです。
      以下は私の#{start_date}から#{end_date}までの#{30}日間のブックマークです。
      これらから私の関心事、興味のパターン、知識欲求の方向性を分析してください。

      ＜ブックマーク一覧＞
      #{bookmark_text}

      以下の観点で分析し、JSONフォーマットで回答してください：

      1. **コアな関心事** - 繰り返し現れる中心的なテーマ
      2. **新しい興味** - 最近になって現れた新しいトピック
      3. **技術スタック** - 興味を持っている技術・ツール・サービス
      4. **学習フェーズ** - 各トピックの学習段階（初心者/実践/深掘り）
      5. **関連性マップ** - トピック間の関連性

      JSON形式：
      {
        "analysis_period": {
          "start": "#{start_date}",
          "end": "#{end_date}",
          "total_bookmarks": 数値
        },
        "core_interests": [
          {
            "keyword": "キーワード（英語の場合はそのまま、日本語も可）",
            "frequency": 出現回数,
            "importance": 1-10の重要度,
            "category": "カテゴリ（technology/business/lifestyle/learning等）",
            "context": "なぜこれに興味があるのか、どういう文脈か",
            "examples": ["関連するブックマークのタイトル例を2-3個"],
            "related_hot_words": [
              {
                "word": "関連する注目ワード",
                "reason": "なぜ関連していて注目すべきか"
              }
            ]
          }
        ],
        "emerging_interests": [
          {
            "keyword": "新しく出現したキーワード",
            "first_seen": "初出日",
            "growth_rate": "急速/通常/緩やか",
            "potential": "今後の発展可能性",
            "related_to": ["既存の関心事との関連"]
          }
        ],
        "technology_stack": {
          "languages": ["プログラミング言語"],
          "frameworks": ["フレームワーク/ライブラリ"],
          "tools": ["ツール/サービス"],
          "platforms": ["プラットフォーム"]
        },
        "learning_phases": {
          "exploring": ["探索段階のトピック"],
          "practicing": ["実践段階のトピック"],
          "deepening": ["深掘り段階のトピック"]
        },
        "interest_clusters": [
          {
            "cluster_name": "関連トピックのグループ名",
            "keywords": ["含まれるキーワード"],
            "theme": "共通テーマ"
          }
        ],
        "insights": {
          "summary": "全体的な興味の傾向（2-3文）",
          "recommendations": ["今後チェックすべきトピック"],
          "blind_spots": ["見落としている可能性のある関連分野"]
        }
      }

      注意事項：
      - 製品名、サービス名は正確に抽出
      - 技術用語は略語も正式名称も考慮
      - 日本語と英語の両方を適切に扱う
      - あまりに一般的な単語（例：「使い方」「方法」）は除外
      - 重要度は出現頻度だけでなく、文脈での重要性も考慮
      - **重要**: 各core_interestには必ず5個のrelated_hot_wordsを含めてください
      - related_hot_wordsは、そのキーワードと一緒に注目すべき最新のトレンドワードを選んでください
      - 例: "AI"なら→["RAG", "Agent", "Fine-tuning", "Multimodal", "Local LLM"]のような関連ワード
    PROMPT
  end
  
  def call_gpt_api(prompt)
    uri = URI(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60  # タイムアウトを60秒に設定
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: @model,
      messages: [
        {
          role: 'system',
          content: 'あなたはブックマークデータから洞察を導き出す専門家です。構造化されたJSONで分析結果を提供してください。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.7,
      max_tokens: 4000,
      response_format: { type: "json_object" }
    }.to_json
    
    response = http.request(request)
    JSON.parse(response.body)
  rescue => e
    puts "API Error: #{e.message}"
    nil
  end
  
  def parse_gpt_response(response)
    return nil unless response
    
    if response['error']
      puts "GPT Error: #{response['error']['message']}"
      return nil
    end
    
    content = response.dig('choices', 0, 'message', 'content')
    return nil unless content
    
    JSON.parse(content)
  rescue JSON::ParserError => e
    puts "JSON Parse Error: #{e.message}"
    puts "Content: #{content}"
    nil
  end
  
  def save_analysis(analysis, start_date, end_date)
    # タイムスタンプ付きファイル名
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "interest_analysis_#{timestamp}.json"
    filepath = File.join(OUTPUT_DIR, filename)
    
    # メタデータを追加
    full_data = {
      'generated_at' => Time.now.iso8601,
      'analysis_period' => {
        'start' => start_date.to_s,
        'end' => end_date.to_s
      },
      'analysis' => analysis
    }
    
    # 保存
    File.write(filepath, JSON.pretty_generate(full_data))
    puts "\n💾 分析結果を保存しました: #{filepath}"
    
    # 最新版としても保存
    latest_path = File.join(OUTPUT_DIR, 'latest_analysis.json')
    File.write(latest_path, JSON.pretty_generate(full_data))
  end
  
  def display_results(analysis)
    puts "\n📊 分析結果"
    puts "="*50
    
    # コア関心事
    puts "\n🎯 コアな関心事 TOP5"
    analysis['core_interests'].first(5).each do |interest|
      puts "- #{interest['keyword']} (重要度: #{interest['importance']}/10)"
      puts "  カテゴリ: #{interest['category']}"
      puts "  文脈: #{interest['context']}"
      puts ""
    end
    
    # 新しい興味
    if analysis['emerging_interests'] && analysis['emerging_interests'].any?
      puts "\n🌱 新しく現れた興味"
      analysis['emerging_interests'].each do |interest|
        puts "- #{interest['keyword']}"
        puts "  可能性: #{interest['potential']}"
        puts ""
      end
    end
    
    # 技術スタック
    if tech = analysis['technology_stack']
      puts "\n🛠 技術スタック"
      puts "言語: #{tech['languages'].join(', ')}" if tech['languages']
      puts "フレームワーク: #{tech['frameworks'].join(', ')}" if tech['frameworks']
      puts "ツール: #{tech['tools'].join(', ')}" if tech['tools']
    end
    
    # インサイト
    if insights = analysis['insights']
      puts "\n💡 インサイト"
      puts insights['summary']
      
      if insights['recommendations'] && insights['recommendations'].any?
        puts "\n推奨トピック:"
        insights['recommendations'].each { |r| puts "- #{r}" }
      end
    end
  end
  
  def format_date(date_string)
    Date.parse(date_string).strftime('%m/%d')
  rescue
    date_string
  end
end

# 実行
if __FILE__ == $0
  unless ENV['OPENAI_API_KEY']
    puts "❌ Error: OPENAI_API_KEY environment variable is not set"
    puts "Please set it in your .env file or export it"
    exit 1
  end
  
  extractor = InterestExtractor.new
  extractor.extract_from_recent_bookmarks(days: 30)
end