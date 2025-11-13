require 'json'
require 'fileutils'
require_relative 'gpt_keyword_extractor'

class InterestTrackerGPT
  DATA_DIR = './data/interests'
  
  def initialize
    @extractor = GPTKeywordExtractor.new
    FileUtils.mkdir_p(DATA_DIR)
  end
  
  # 週次キーワード分析を実行
  def analyze_weekly(bookmarks, week_key)
    puts "📊 週次分析を開始: #{week_key}"
    
    # 前週のデータを取得
    previous_week_data = load_previous_week_data(week_key)
    
    # GPTでキーワード抽出
    analysis = @extractor.extract_keywords_from_bookmarks(bookmarks, week_key)
    
    return unless analysis
    
    # 結果を保存
    save_analysis(week_key, analysis)
    
    # 関心ワードDBを更新
    update_interest_database(analysis, week_key)
    
    # サマリーを生成
    generate_summary(analysis, week_key)
    
    analysis
  end
  
  # 関心ワードの履歴を取得
  def get_interest_history(keyword)
    history = []
    
    Dir.glob("#{DATA_DIR}/analysis_*.json").sort.each do |file|
      data = JSON.parse(File.read(file))
      week = File.basename(file, '.json').sub('analysis_', '')
      
      # キーワードが含まれているか確認
      primary = data['primary_interests']&.find { |i| i['keyword'] == keyword }
      if primary
        history << {
          week: week,
          frequency: primary['frequency'],
          importance: primary['importance']
        }
      end
    end
    
    history
  end
  
  # トレンド分析
  def analyze_trends
    all_keywords = {}
    weeks = []
    
    # 全週のデータを収集
    Dir.glob("#{DATA_DIR}/analysis_*.json").sort.each do |file|
      data = JSON.parse(File.read(file))
      week = File.basename(file, '.json').sub('analysis_', '')
      weeks << week
      
      data['primary_interests']&.each do |interest|
        keyword = interest['keyword']
        all_keywords[keyword] ||= {}
        all_keywords[keyword][week] = {
          frequency: interest['frequency'],
          importance: interest['importance']
        }
      end
    end
    
    # トレンドを計算
    trends = all_keywords.map do |keyword, weekly_data|
      recent_weeks = weeks.last(4)
      recent_scores = recent_weeks.map { |w| weekly_data[w]&.dig(:importance) || 0 }
      
      trend = calculate_trend(recent_scores)
      
      {
        keyword: keyword,
        total_weeks: weekly_data.keys.count,
        recent_activity: recent_scores,
        trend: trend,
        last_seen: weekly_data.keys.max
      }
    end
    
    trends.sort_by { |t| -t[:total_weeks] }
  end
  
  private
  
  # 前週のデータを読み込み
  def load_previous_week_data(current_week)
    previous_week = get_previous_week(current_week)
    file_path = "#{DATA_DIR}/analysis_#{previous_week}.json"
    
    return nil unless File.exist?(file_path)
    
    JSON.parse(File.read(file_path))
  end
  
  # 分析結果を保存
  def save_analysis(week_key, analysis)
    file_path = "#{DATA_DIR}/analysis_#{week_key}.json"
    File.write(file_path, JSON.pretty_generate(analysis))
    
    # 最新の分析結果も保存
    File.write("#{DATA_DIR}/latest_analysis.json", JSON.pretty_generate({
      week: week_key,
      analyzed_at: Time.now.iso8601,
      data: analysis
    }))
  end
  
  # 関心ワードデータベースを更新
  def update_interest_database(analysis, week_key)
    db_file = "#{DATA_DIR}/interest_words.json"
    db = File.exist?(db_file) ? JSON.parse(File.read(db_file)) : {}
    
    # プライマリキーワードを更新
    analysis['primary_interests']&.each do |interest|
      keyword = interest['keyword']
      db[keyword] ||= {
        'first_seen' => week_key,
        'weekly_data' => {},
        'categories' => []
      }
      
      db[keyword]['last_seen'] = week_key
      db[keyword]['weekly_data'][week_key] = {
        'frequency' => interest['frequency'],
        'importance' => interest['importance']
      }
      
      # カテゴリを追加
      if interest['category'] && !db[keyword]['categories'].include?(interest['category'])
        db[keyword]['categories'] << interest['category']
      end
    end
    
    File.write(db_file, JSON.pretty_generate(db))
  end
  
  # サマリーを生成
  def generate_summary(analysis, week_key)
    summary = []
    summary << "# 週次関心ワード分析 - #{week_key}"
    summary << ""
    summary << "## 📌 主要な関心事"
    
    analysis['primary_interests']&.first(5)&.each do |interest|
      summary << "- **#{interest['keyword']}** (重要度: #{interest['importance']}/10)"
      summary << "  - #{interest['reason']}"
    end
    
    summary << ""
    summary << "## 🚀 新興トピック"
    analysis['emerging_interests']&.each do |emerging|
      summary << "- **#{emerging['keyword']}**: #{emerging['potential']}"
    end
    
    summary << ""
    summary << "## 🔗 関連クラスター"
    analysis['related_clusters']&.each do |cluster|
      summary << "- **#{cluster['main_topic']}**: #{cluster['related_words'].join(', ')}"
    end
    
    summary << ""
    summary << "## 💡 インサイト"
    summary << analysis.dig('insights', 'summary') || ""
    
    File.write("#{DATA_DIR}/summary_#{week_key}.md", summary.join("\n"))
  end
  
  # トレンドを計算
  def calculate_trend(scores)
    return 'new' if scores.count { |s| s > 0 } <= 1
    
    # 簡単な線形回帰
    recent = scores.last(3)
    if recent.last > recent.first * 1.5
      'rising'
    elsif recent.last < recent.first * 0.7
      'declining'
    else
      'stable'
    end
  end
  
  # 前週を計算
  def get_previous_week(week_key)
    year, week = week_key.match(/(\d{4})-W(\d{2})/).captures
    week_num = week.to_i - 1
    
    if week_num < 1
      "#{year.to_i - 1}-W52"
    else
      "#{year}-W#{week_num.to_s.rjust(2, '0')}"
    end
  end
end