#!/usr/bin/env ruby

require 'json'
require 'time'
require 'openai'
require 'dotenv'
require_relative 'raindrop_client'
require_relative 'interest_manager'
require_relative 'article_content_fetcher'
require_relative 'gpt_keyword_extractor'

Dotenv.load('/var/git/rainpipe/.env')

class WeeklySummaryGenerator
  SUMMARY_DIR = './data/weekly_summaries'
  
  def initialize
    @client = RaindropClient.new
    @interest_manager = InterestManager.new
    @content_fetcher = ArticleContentFetcher.new
    @openai = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    
    FileUtils.mkdir_p(SUMMARY_DIR) unless Dir.exist?(SUMMARY_DIR)
  end
  
  def generate_weekly_summary(week_start_date)
    puts "📊 週次サマリーを生成中: #{week_start_date}"
    
    # 1. その週のブックマークを取得
    week_end_date = Date.parse(week_start_date) + 6
    bookmarks = @client.get_bookmarks_by_date_range(week_start_date, week_end_date.to_s)
    
    puts "📚 #{bookmarks.length}件のブックマークを取得"
    
    # 2. 関心ワードを取得
    latest_analysis = @interest_manager.get_latest_analysis
    keywords = extract_active_keywords(latest_analysis)
    
    puts "🎯 アクティブなキーワード: #{keywords.join(', ')}"
    
    # 3. キーワードごとにブックマークをグループ化
    grouped_bookmarks = group_bookmarks_by_keywords(bookmarks, keywords)
    
    # 4. 各キーワードの記事内容を取得してサマリー生成
    summary_data = {
      week_start: week_start_date,
      week_end: week_end_date.to_s,
      generated_at: Time.now.iso8601,
      keywords: {}
    }
    
    grouped_bookmarks.each do |keyword, keyword_bookmarks|
      puts "\n🔍 #{keyword}のサマリーを生成中..."
      
      # 記事内容を取得
      articles_with_content = fetch_articles_content(keyword_bookmarks)
      
      # サマリーと洞察を生成
      if articles_with_content.any?
        summary_data[:keywords][keyword] = generate_keyword_summary(keyword, articles_with_content)
      end
    end
    
    # 5. 全体の総括を生成
    summary_data[:overall_insights] = generate_overall_insights(summary_data[:keywords])

    # 6. 周辺キーワード（related_clusters）を抽出
    begin
      puts "\n🔍 周辺キーワードを抽出中..."
      week_key = "#{week_start_date}～#{week_end_date}"
      extractor = GPTKeywordExtractor.new
      analysis = extractor.extract_keywords_from_bookmarks(bookmarks, week_key)

      if analysis && analysis['related_clusters']
        summary_data[:related_clusters] = analysis['related_clusters']
        puts "✓ #{analysis['related_clusters'].length}個の周辺キーワードを追加しました"
      end
    rescue => e
      puts "⚠️  周辺キーワード抽出スキップ: #{e.message}"
    end

    # 7. 結果を保存
    save_summary(week_start_date, summary_data)
    
    summary_data
  end
  
  private
  
  def extract_active_keywords(analysis)
    return [] unless analysis
    
    keywords = []
    
    # core_interestsから抽出
    core_interests = analysis.dig('analysis', 'core_interests') || []
    keywords.concat(core_interests.map { |i| i['keyword'] })
    
    # emerging_interestsから抽出
    emerging_interests = analysis.dig('analysis', 'emerging_interests') || []
    keywords.concat(emerging_interests.map { |i| i['keyword'] })
    
    keywords.uniq
  end
  
  def group_bookmarks_by_keywords(bookmarks, keywords)
    grouped = {}
    
    keywords.each do |keyword|
      keyword_lower = keyword.downcase
      related_bookmarks = bookmarks.select do |bookmark|
        title = (bookmark['title'] || '').downcase
        tags = bookmark['tags'] || []
        
        # タイトルまたはタグにキーワードが含まれるか
        title.include?(keyword_lower) || 
        tags.any? { |tag| tag.downcase.include?(keyword_lower) }
      end
      
      grouped[keyword] = related_bookmarks if related_bookmarks.any?
    end
    
    grouped
  end
  
  def fetch_articles_content(bookmarks)
    articles = []
    
    bookmarks.first(5).each do |bookmark|  # 最大5記事まで
      url = bookmark['link']
      next unless url
      
      begin
        content_data = @content_fetcher.fetch_content(url)
        articles << {
          title: bookmark['title'],
          url: url,
          content: content_data,
          created_at: bookmark['created']
        }
      rescue => e
        puts "⚠️  記事取得スキップ: #{e.message}"
      end
    end
    
    articles
  end
  
  def generate_keyword_summary(keyword, articles)
    return nil if articles.empty?
    
    # プロンプトを構築
    articles_text = articles.map.with_index do |article, idx|
      content_text = article[:content] && article[:content][:text] ? article[:content][:text][0..500] : "内容を取得できませんでした"
      "記事#{idx + 1}: #{article[:title]}\n内容: #{content_text}..."
    end.join("\n\n")
    
    prompt = <<~PROMPT
      以下は「#{keyword}」に関する今週の記事です。
      
      #{articles_text}
      
      これらの記事から以下を生成してください：
      
      1. 今週の主要な動向（3-5つの箇条書き）
      2. 技術的な重要ポイント
      3. 実用的な洞察（エンジニアが知っておくべきこと）
      4. 来週以降の注目点
      
      簡潔で実用的な内容にしてください。
    PROMPT
    
    begin
      response = @openai.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.7,
          max_tokens: 800
        }
      )
      
      summary_text = response.dig("choices", 0, "message", "content")
      
      {
        article_count: articles.length,
        articles: articles.map { |a| { title: a[:title], url: a[:url] } },
        summary: summary_text,
        generated_at: Time.now.iso8601
      }
    rescue => e
      puts "❌ サマリー生成エラー: #{e.message}"
      nil
    end
  end
  
  def generate_overall_insights(keywords_data)
    return nil if keywords_data.empty?
    
    keywords_summary = keywords_data.map do |keyword, data|
      "#{keyword}: #{data[:article_count]}記事"
    end.join(", ")
    
    prompt = <<~PROMPT
      今週の技術トレンドサマリー:
      #{keywords_summary}
      
      全体的な技術トレンドの洞察を200文字程度で生成してください。
      エンジニアが今週注目すべきポイントを簡潔にまとめてください。
    PROMPT
    
    begin
      response = @openai.chat(
        parameters: {
          model: "gpt-4o-mini",
          messages: [{ role: "user", content: prompt }],
          temperature: 0.7,
          max_tokens: 300
        }
      )
      
      response.dig("choices", 0, "message", "content")
    rescue => e
      puts "❌ 総括生成エラー: #{e.message}"
      nil
    end
  end
  
  def save_summary(week_start_date, summary_data)
    filename = File.join(SUMMARY_DIR, "summary_#{week_start_date}.json")
    File.write(filename, JSON.pretty_generate(summary_data))
    
    # 最新版も保存
    latest_file = File.join(SUMMARY_DIR, "latest.json")
    File.write(latest_file, JSON.pretty_generate(summary_data))
    
    puts "✅ サマリーを保存しました: #{filename}"
  end
end

# テスト実行
if __FILE__ == $0
  generator = WeeklySummaryGenerator.new
  
  # 今週の月曜日を計算
  today = Date.today
  monday = today - (today.wday - 1) % 7
  
  puts "テスト実行: #{monday}の週のサマリーを生成"
  summary = generator.generate_weekly_summary(monday.to_s)
  
  if summary
    puts "\n✅ サマリー生成完了"
    puts "キーワード数: #{summary[:keywords].keys.length}"
  end
end