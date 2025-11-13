require 'json'
require 'date'

class InterestManager
  INTERESTS_DIR = './data/interests'
  
  def initialize
    @interests_dir = INTERESTS_DIR
  end
  
  # 最新の分析結果を取得
  def get_latest_analysis
    latest_file = File.join(@interests_dir, 'latest_analysis.json')
    return nil unless File.exist?(latest_file)
    
    JSON.parse(File.read(latest_file))
  rescue => e
    puts "Error loading latest analysis: #{e.message}"
    nil
  end
  
  # すべての分析履歴を取得
  def get_all_analyses
    files = Dir.glob(File.join(@interests_dir, 'interest_analysis_*.json'))
    files.map do |file|
      data = JSON.parse(File.read(file))
      {
        filename: File.basename(file),
        generated_at: data['generated_at'],
        period: data['analysis_period'],
        keyword_count: data.dig('analysis', 'core_interests')&.length || 0
      }
    end.sort_by { |a| a[:generated_at] }.reverse
  rescue => e
    puts "Error loading analyses: #{e.message}"
    []
  end
  
  # キーワードのランキングを取得
  def get_keyword_ranking
    latest = get_latest_analysis
    return [] unless latest
    
    interests = latest.dig('analysis', 'core_interests') || []
    interests.sort_by { |i| -i['importance'] }
  end
  
  # カテゴリ別にグループ化
  def get_keywords_by_category
    latest = get_latest_analysis
    return {} unless latest
    
    interests = latest.dig('analysis', 'core_interests') || []
    interests.group_by { |i| i['category'] || 'uncategorized' }
  end
  
  # 新興キーワードを取得
  def get_emerging_keywords
    latest = get_latest_analysis
    return [] unless latest
    
    latest.dig('analysis', 'emerging_interests') || []
  end
  
  # 技術スタックを取得
  def get_technology_stack
    latest = get_latest_analysis
    return {} unless latest
    
    latest.dig('analysis', 'technology_stack') || {}
  end
  
  # 学習フェーズを取得
  def get_learning_phases
    latest = get_latest_analysis
    return {} unless latest
    
    latest.dig('analysis', 'learning_phases') || {}
  end
  
  # キーワードの履歴を取得（全分析ファイルから）
  def get_keyword_history(keyword)
    files = Dir.glob(File.join(@interests_dir, 'interest_analysis_*.json'))
    history = []
    
    files.each do |file|
      data = JSON.parse(File.read(file))
      generated_at = data['generated_at']
      
      # core_interestsから検索
      core_interests = data.dig('analysis', 'core_interests') || []
      interest = core_interests.find { |i| i['keyword'].downcase == keyword.downcase }
      
      if interest
        history << {
          date: generated_at,
          importance: interest['importance'],
          frequency: interest['frequency'],
          context: interest['context']
        }
      end
    end
    
    history.sort_by { |h| h[:date] }
  rescue => e
    puts "Error getting keyword history: #{e.message}"
    []
  end
  
  # インサイトを取得
  def get_insights
    latest = get_latest_analysis
    return {} unless latest
    
    latest.dig('analysis', 'insights') || {}
  end
end