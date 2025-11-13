#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'date'
require 'time'
require 'fileutils'
require 'digest'
require_relative 'interest_manager'
require_relative 'interest_scorer'

class DailyInterestObserver
  GOOGLE_API_URL = 'https://www.googleapis.com/customsearch/v1'
  OPENAI_API_URL = 'https://api.openai.com/v1/chat/completions'
  OUTPUT_DIR = './data/daily_observations'
  CACHE_DIR = './data/observation_cache'
  
  def initialize
    @google_api_key = ENV['GOOGLE_API_KEY']
    @google_cx = ENV['GOOGLE_CUSTOM_SEARCH_CX']
    @openai_api_key = ENV['OPENAI_API_KEY']
    @model = ENV['GPT_MODEL'] || 'gpt-4o-mini'
    
    FileUtils.mkdir_p(OUTPUT_DIR)
    FileUtils.mkdir_p(CACHE_DIR)
    
    @scorer = InterestScorer.new
    @seen_articles_file = File.join(CACHE_DIR, 'seen_articles.json')
    @seen_articles = load_seen_articles
  end
  
  def run_daily_observation
    puts "🔍 関心ワードの定点観測を開始します..."
    puts "実行時刻: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    
    # スコアの高い関心ワードを取得
    scored_interests = @scorer.calculate_scores
    
    # デフォルト推奨キーワード（関心ワードがない場合でも巡回）
    default_keywords = [
      {
        keyword: 'Claude',
        category: 'ai-ml',
        total_score: 9.0,
        context: 'Anthropicの対話型AI。開発支援や創造的タスクで高い評価',
        related_hot_words: [
          { 'word' => 'Claude Code', 'reason' => 'AI駆動の開発環境として注目' },
          { 'word' => 'Opus 4', 'reason' => '最新モデルの性能向上' }
        ]
      },
      {
        keyword: 'Gemini CLI',
        category: 'ai-ml',
        total_score: 8.5,
        context: 'Googleの新しいAIエージェントツール。開発者の生産性向上に注目',
        related_hot_words: [
          { 'word' => 'MCP', 'reason' => 'Model Context Protocol対応で他ツールとの連携が可能' },
          { 'word' => 'AI Agent', 'reason' => 'ターミナルから使えるAIエージェントの代表例' }
        ]
      },
      {
        keyword: 'AI開発',
        category: 'technology',
        total_score: 8.0,
        context: 'AI関連の最新開発動向、ツール、フレームワーク',
        related_hot_words: [
          { 'word' => 'LLM', 'reason' => '大規模言語モデルの進化' },
          { 'word' => 'RAG', 'reason' => '検索拡張生成の実用化' }
        ]
      },
      {
        keyword: 'プログラミング',
        category: 'technology',
        total_score: 7.5,
        context: '新しいプログラミング言語、フレームワーク、開発手法',
        related_hot_words: [
          { 'word' => 'Rust', 'reason' => 'メモリ安全性で注目の言語' },
          { 'word' => 'TypeScript', 'reason' => 'JavaScript開発の標準に' }
        ]
      }
    ]
    
    # 関心ワードがない場合は業界トレンドを取得
    if scored_interests.empty?
      puts "⚠️  関心ワードが見つかりません。業界トレンドを取得します..."
      
      # 最新の業界トレンドを確認
      trends_file = './data/tech_trends/latest.json'
      if File.exist?(trends_file) && File.mtime(trends_file) > (Time.now - 7*24*60*60)
        # 1週間以内のトレンドがあればそれを使用
        puts "📊 保存済みのトレンドを使用"
        trends_data = JSON.parse(File.read(trends_file))
      else
        # 新しくトレンドを取得
        puts "🔄 最新トレンドを取得中..."
        require_relative 'fetch_tech_trends'
        fetcher = TechTrendsFetcher.new
        fetcher.fetch_programming_trends
        
        # 取得したトレンドを読み込み
        if File.exist?(trends_file)
          trends_data = JSON.parse(File.read(trends_file))
        else
          trends_data = nil
        end
      end
      
      # トレンドワードを観測用フォーマットに変換
      if trends_data && trends_data['trends']
        trend_keywords = trends_data['trends'].first(5).map do |trend|
          {
            keyword: trend['keyword'],
            category: trend['category'] || 'technology',
            total_score: trend['importance'] || 7.0,
            context: trend['reason'],
            related_hot_words: (trend['related_topics'] || []).first(3).map do |topic|
              { 'word' => topic, 'reason' => '関連技術として注目' }
            end
          }
        end
        all_keywords = trend_keywords + default_keywords.first(5)
      else
        # トレンド取得に失敗した場合はデフォルトを使用
        puts "⚠️  トレンド取得に失敗。デフォルトキーワードを使用します"
        all_keywords = default_keywords
      end
    else
      # 既存の関心ワードにデフォルトの一部を追加（重複を避ける）
      existing_keywords = scored_interests.map { |s| s[:keyword].downcase }
      additional_defaults = default_keywords.reject do |d|
        existing_keywords.include?(d[:keyword].downcase)
      end
      all_keywords = scored_interests + additional_defaults.first(2)
    end
    
    # 上位10個のキーワードを対象に
    top_keywords = all_keywords.first(10)
    puts "\n📊 観測対象キーワード（トップ10）:"
    top_keywords.each_with_index do |interest, idx|
      puts "#{idx + 1}. #{interest[:keyword]} (スコア: #{interest[:total_score]})"
    end
    
    # 各キーワードで検索
    all_observations = []
    
    top_keywords.each_with_index do |interest, idx|
      puts "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      puts "🔎 検索中 (#{idx + 1}/#{top_keywords.length}): #{interest[:keyword]}"
      
      # 関連ワードも含めて検索クエリを構築
      search_query = build_search_query(interest)
      
      # Google検索実行
      articles = search_google_news(search_query, interest[:keyword])
      
      if articles.empty?
        puts "  → 新しい記事は見つかりませんでした"
        next
      end
      
      puts "  → #{articles.length}件の記事を発見"
      
      # GPTで価値判定
      valuable_articles = evaluate_articles_with_gpt(articles, interest)
      
      if valuable_articles.any?
        observation = {
          keyword: interest[:keyword],
          category: interest[:category],
          search_query: search_query,
          searched_at: Time.now.iso8601,
          total_found: articles.length,
          valuable_count: valuable_articles.length,
          articles: valuable_articles
        }
        
        all_observations << observation
        puts "  ✅ #{valuable_articles.length}件の価値ある記事を保存"
        
        # 見た記事として記録
        valuable_articles.each do |article|
          mark_as_seen(article[:url])
        end
      else
        puts "  → 価値ある記事は見つかりませんでした"
      end
      
      # API制限対策で少し待つ
      sleep(1)
    end
    
    # 結果を保存
    if all_observations.any?
      save_observations(all_observations)
      display_summary(all_observations)
    else
      puts "\n📭 本日は新しい価値ある記事が見つかりませんでした"
    end
    
    # 古いキャッシュをクリーンアップ
    cleanup_old_cache
  end
  
  private
  
  def build_search_query(interest)
    # メインキーワード
    query_parts = [interest[:keyword]]
    
    # 関連ワードを追加（最大3個）
    if interest[:related_hot_words] && interest[:related_hot_words].any?
      related = interest[:related_hot_words].first(3).map { |w| w['word'] }
      query_parts << "(" + related.join(" OR ") + ")"
    end
    
    # 新しいニュースに限定
    query_parts << "最新"
    
    query_parts.join(" ")
  end
  
  def search_google_news(query, keyword)
    return [] unless @google_api_key && @google_cx
    
    # 過去24時間のニュースに限定
    date_restrict = "d1"
    
    uri = URI(GOOGLE_API_URL)
    params = {
      key: @google_api_key,
      cx: @google_cx,
      q: query,
      num: 10,
      dateRestrict: date_restrict,
      lr: 'lang_ja',  # 日本語の結果
      safe: 'active'
    }
    uri.query = URI.encode_www_form(params)
    
    response = Net::HTTP.get_response(uri)
    
    if response.code != '200'
      puts "  ❌ Google API Error: #{response.code} - #{response.body}"
      return []
    end
    
    data = JSON.parse(response.body)
    items = data['items'] || []
    
    # 既に見た記事をフィルタリング
    new_items = items.reject { |item| already_seen?(item['link']) }
    
    new_items.map do |item|
      {
        title: item['title'],
        url: item['link'],
        snippet: item['snippet'],
        source: extract_source(item),
        keyword: keyword
      }
    end
  rescue => e
    puts "  ❌ 検索エラー: #{e.message}"
    []
  end
  
  def extract_source(item)
    # ドメイン名を抽出
    if item['displayLink']
      item['displayLink']
    elsif item['link']
      URI.parse(item['link']).host rescue 'unknown'
    else
      'unknown'
    end
  end
  
  def evaluate_articles_with_gpt(articles, interest)
    # 記事をバッチでGPTに評価してもらう
    prompt = build_evaluation_prompt(articles, interest)
    
    response = call_gpt_api(prompt)
    evaluations = parse_gpt_evaluation(response)
    
    return [] unless evaluations
    
    # 価値があると判定された記事のみ抽出
    valuable_articles = []
    
    articles.each_with_index do |article, idx|
      eval_data = evaluations['articles'][idx] rescue nil
      next unless eval_data && eval_data['is_valuable']
      
      valuable_articles << {
        title: article[:title],
        url: article[:url],
        snippet: article[:snippet],
        source: article[:source],
        keyword: article[:keyword],
        evaluation: {
          relevance_score: eval_data['relevance_score'],
          novelty_score: eval_data['novelty_score'],
          importance_score: eval_data['importance_score'],
          reasoning: eval_data['reasoning'],
          key_points: eval_data['key_points']
        },
        evaluated_at: Time.now.iso8601
      }
    end
    
    # 重複する内容を除外
    deduplicate_articles(valuable_articles)
  end
  
  def build_evaluation_prompt(articles, interest)
    articles_text = articles.map.with_index do |article, idx|
      "記事#{idx + 1}:
タイトル: #{article[:title]}
URL: #{article[:url]}
要約: #{article[:snippet]}
ソース: #{article[:source]}"
    end.join("\n\n")
    
    <<~PROMPT
      あなたは#{interest[:keyword]}に関心のあるユーザーのための記事キュレーターです。
      以下の記事を評価し、価値があるかどうか判定してください。
      
      ユーザーの関心事:
      - キーワード: #{interest[:keyword]}
      - カテゴリ: #{interest[:category]}
      - 文脈: #{interest[:context]}
      
      評価する記事:
      #{articles_text}
      
      以下の基準で各記事を評価してください:
      
      1. 関連性 (1-10): キーワードとの関連度
      2. 新規性 (1-10): 新しい情報や視点を含んでいるか
      3. 重要性 (1-10): ユーザーにとって知るべき重要な情報か
      
      価値がある記事の条件:
      - 3つのスコアの平均が7以上
      - 単なる既存情報の繰り返しではない
      - 実質的な内容がある（単なる予告や噂ではない）
      
      JSON形式で回答してください:
      {
        "articles": [
          {
            "index": 記事番号,
            "is_valuable": true/false,
            "relevance_score": 数値,
            "novelty_score": 数値,
            "importance_score": 数値,
            "reasoning": "判定理由",
            "key_points": ["重要ポイント1", "重要ポイント2"],
            "duplicate_of": null または他の記事番号
          }
        ],
        "summary": "全体的な評価サマリー"
      }
    PROMPT
  end
  
  def call_gpt_api(prompt)
    uri = URI(OPENAI_API_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@openai_api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: @model,
      messages: [
        {
          role: 'system',
          content: '記事の価値を的確に評価する専門家として回答してください。'
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.3,  # より一貫性のある評価のため低めに
      max_tokens: 2000,
      response_format: { type: "json_object" }
    }.to_json
    
    response = http.request(request)
    JSON.parse(response.body)
  rescue => e
    puts "  ❌ GPT API Error: #{e.message}"
    nil
  end
  
  def parse_gpt_evaluation(response)
    return nil unless response
    
    if response['error']
      puts "  ❌ GPT Error: #{response['error']['message']}"
      return nil
    end
    
    content = response.dig('choices', 0, 'message', 'content')
    return nil unless content
    
    JSON.parse(content)
  rescue JSON::ParserError => e
    puts "  ❌ JSON Parse Error: #{e.message}"
    nil
  end
  
  def deduplicate_articles(articles)
    # 重複判定のため、各記事の特徴を抽出
    seen_signatures = {}
    unique_articles = []
    
    articles.each do |article|
      # タイトルの主要キーワードでシグネチャを作成
      signature = create_article_signature(article[:title])
      
      # 既に似た記事がある場合はスキップ
      if seen_signatures[signature]
        puts "  → 重複: #{article[:title][0..50]}..."
        next
      end
      
      seen_signatures[signature] = true
      unique_articles << article
    end
    
    unique_articles
  end
  
  def create_article_signature(title)
    # タイトルから重要な単語を抽出してシグネチャを作成
    # 簡易的な実装
    words = title.gsub(/[「」『』【】\[\]()（）]/, ' ')
                 .split(/[\s、。・]+/)
                 .reject { |w| w.length < 2 }
                 .first(5)
    
    Digest::MD5.hexdigest(words.join('_').downcase)
  end
  
  def already_seen?(url)
    @seen_articles[url] ? true : false
  end
  
  def mark_as_seen(url)
    @seen_articles[url] = Time.now.iso8601
    save_seen_articles
  end
  
  def load_seen_articles
    return {} unless File.exist?(@seen_articles_file)
    JSON.parse(File.read(@seen_articles_file))
  rescue
    {}
  end
  
  def save_seen_articles
    File.write(@seen_articles_file, JSON.pretty_generate(@seen_articles))
  end
  
  def cleanup_old_cache
    # 30日以上前の記録を削除
    cutoff_date = Date.today - 30
    
    @seen_articles.delete_if do |url, timestamp|
      Date.parse(timestamp) < cutoff_date rescue false
    end
    
    save_seen_articles
  end
  
  def save_observations(observations)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    filename = "daily_observation_#{timestamp}.json"
    filepath = File.join(OUTPUT_DIR, filename)
    
    # デイリーサマリーを生成
    daily_summary = generate_daily_summary(observations)
    
    data = {
      observed_at: Time.now.iso8601,
      total_keywords: observations.length,
      total_valuable_articles: observations.sum { |o| o[:valuable_count] },
      observations: observations,
      daily_summary: daily_summary
    }
    
    File.write(filepath, JSON.pretty_generate(data))
    puts "\n💾 観測結果を保存しました: #{filepath}"
    
    # 最新版も保存
    latest_path = File.join(OUTPUT_DIR, 'latest_observation.json')
    File.write(latest_path, JSON.pretty_generate(data))
  end
  
  def generate_daily_summary(observations)
    puts "\n📝 デイリーサマリーを生成中..."
    
    # 価値ある記事だけを抽出
    valuable_articles = []
    observations.each do |obs|
      obs[:new_articles].each do |article|
        if article[:relevance_score] >= 7
          valuable_articles << {
            keyword: obs[:keyword],
            title: article[:title],
            url: article[:url],
            snippet: article[:snippet],
            score: article[:relevance_score]
          }
        end
      end
    end
    
    return nil if valuable_articles.empty?
    
    # プロンプトを構築
    articles_text = valuable_articles.map do |a|
      "【#{a[:keyword]}】#{a[:title]} (スコア: #{a[:score]})\n#{a[:snippet]}"
    end.join("\n\n")
    
    prompt = <<~PROMPT
      以下は本日の技術トレンド観測で発見された重要な記事です。
      
      #{articles_text}
      
      これらの記事から以下を生成してください：
      1. 本日の技術トレンドの要約（200文字程度）
      2. エンジニアが注目すべきポイント（3つ）
      3. 明日以降の動向予測（簡潔に）
      
      簡潔で実用的な内容にしてください。
    PROMPT
    
    # GPTでサマリー生成
    summary = generate_summary_with_gpt(prompt)
    
    {
      generated_at: Time.now.iso8601,
      valuable_articles_count: valuable_articles.length,
      summary: summary,
      top_articles: valuable_articles.first(5)
    }
  rescue => e
    puts "⚠️  サマリー生成エラー: #{e.message}"
    nil
  end
  
  def generate_summary_with_gpt(prompt)
    uri = URI(OPENAI_API_URL)
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{@openai_api_key}"
    request['Content-Type'] = 'application/json'
    
    request.body = {
      model: @model,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.7,
      max_tokens: 500
    }.to_json
    
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end
    
    if response.code == '200'
      data = JSON.parse(response.body)
      data.dig('choices', 0, 'message', 'content')
    else
      raise "GPT API Error: #{response.body}"
    end
  end
  
  def display_summary(observations)
    puts "\n📊 本日の定点観測サマリー"
    puts "="*50
    
    total_articles = observations.sum { |o| o[:valuable_count] }
    puts "✅ 発見した価値ある記事: #{total_articles}件"
    
    puts "\nキーワード別:"
    observations.each do |obs|
      next if obs[:valuable_count] == 0
      puts "\n【#{obs[:keyword]}】 #{obs[:valuable_count]}件"
      obs[:articles].each do |article|
        puts "  - #{article[:title][0..60]}..."
        puts "    #{article[:source]} | 関連性:#{article[:evaluation][:relevance_score]} 新規性:#{article[:evaluation][:novelty_score]} 重要性:#{article[:evaluation][:importance_score]}"
      end
    end
  end
end

# 実行
if __FILE__ == $0
  unless ENV['GOOGLE_API_KEY'] && ENV['GOOGLE_CUSTOM_SEARCH_CX'] && ENV['OPENAI_API_KEY']
    puts "❌ Error: 必要な環境変数が設定されていません"
    puts "必要な環境変数:"
    puts "  - GOOGLE_API_KEY"
    puts "  - GOOGLE_CUSTOM_SEARCH_CX"
    puts "  - OPENAI_API_KEY"
    exit 1
  end
  
  observer = DailyInterestObserver.new
  observer.run_daily_observation
end