require 'json'
require 'date'
require 'fileutils'

class ArchiveManager
  ARCHIVE_DIR = './data/archives'
  INTERESTS_DIR = './data/interests'
  OBSERVATIONS_DIR = './data/daily_observations'
  
  def initialize
    FileUtils.mkdir_p(ARCHIVE_DIR)
    FileUtils.mkdir_p(File.join(ARCHIVE_DIR, 'interests'))
    FileUtils.mkdir_p(File.join(ARCHIVE_DIR, 'observations'))
  end
  
  # アーカイブ処理（30日以上前のファイルを移動）
  def archive_old_files
    cutoff_date = Date.today - 30
    
    # 関心ワード分析ファイルのアーカイブ
    archive_interest_files(cutoff_date)
    
    # 定点観測ファイルのアーカイブ
    archive_observation_files(cutoff_date)
  end
  
  # 全アーカイブデータを取得
  def get_all_archives
    {
      interests: get_archived_interests,
      observations: get_archived_observations,
      statistics: calculate_archive_statistics
    }
  end
  
  # 期間指定でアーカイブを取得
  def get_archives_by_period(start_date, end_date)
    all_archives = get_all_archives
    
    # 期間でフィルタリング
    filtered_interests = all_archives[:interests].select do |item|
      date = Date.parse(item[:date])
      date >= start_date && date <= end_date
    end
    
    filtered_observations = all_archives[:observations].select do |item|
      date = Date.parse(item[:date])
      date >= start_date && date <= end_date
    end
    
    {
      interests: filtered_interests,
      observations: filtered_observations,
      period: {
        start: start_date.iso8601,
        end: end_date.iso8601
      }
    }
  end
  
  # キーワードの履歴を全期間で取得
  def get_keyword_full_history(keyword)
    history = []
    
    # 現在のデータから
    Dir.glob(File.join(INTERESTS_DIR, 'interest_analysis_*.json')).each do |file|
      data = JSON.parse(File.read(file))
      add_keyword_to_history(history, data, keyword, false)
    end
    
    # アーカイブから
    Dir.glob(File.join(ARCHIVE_DIR, 'interests', 'interest_analysis_*.json')).each do |file|
      data = JSON.parse(File.read(file))
      add_keyword_to_history(history, data, keyword, true)
    end
    
    history.sort_by { |item| item[:date] }
  end
  
  # キーワードの観測履歴を取得
  def get_keyword_observations(keyword)
    observations = []
    
    # 現在のデータから
    Dir.glob(File.join(OBSERVATIONS_DIR, 'daily_observation_*.json')).each do |file|
      data = JSON.parse(File.read(file))
      add_keyword_observations(observations, data, keyword, false)
    end
    
    # アーカイブから
    Dir.glob(File.join(ARCHIVE_DIR, 'observations', 'daily_observation_*.json')).each do |file|
      data = JSON.parse(File.read(file))
      add_keyword_observations(observations, data, keyword, true)
    end
    
    observations.sort_by { |item| item[:date] }.reverse
  end
  
  private
  
  def archive_interest_files(cutoff_date)
    Dir.glob(File.join(INTERESTS_DIR, 'interest_analysis_*.json')).each do |file|
      next if File.basename(file) == 'latest_analysis.json'
      
      # ファイル名から日付を抽出
      if match = File.basename(file).match(/interest_analysis_(\d{8})/)
        file_date = Date.parse(match[1])
        
        if file_date < cutoff_date
          # アーカイブディレクトリに移動
          archive_path = File.join(ARCHIVE_DIR, 'interests', File.basename(file))
          FileUtils.mv(file, archive_path)
          puts "📦 Archived: #{File.basename(file)}"
        end
      end
    end
  end
  
  def archive_observation_files(cutoff_date)
    Dir.glob(File.join(OBSERVATIONS_DIR, 'daily_observation_*.json')).each do |file|
      next if File.basename(file) == 'latest_observation.json'
      
      # ファイル名から日付を抽出
      if match = File.basename(file).match(/daily_observation_(\d{8})/)
        file_date = Date.parse(match[1])
        
        if file_date < cutoff_date
          # アーカイブディレクトリに移動
          archive_path = File.join(ARCHIVE_DIR, 'observations', File.basename(file))
          FileUtils.mv(file, archive_path)
          puts "📦 Archived: #{File.basename(file)}"
        end
      end
    end
  end
  
  def get_archived_interests
    interests = []
    
    Dir.glob(File.join(ARCHIVE_DIR, 'interests', 'interest_analysis_*.json')).each do |file|
      data = JSON.parse(File.read(file))
      
      interests << {
        date: data['generated_at'],
        file: File.basename(file),
        period: data['analysis_period'],
        total_keywords: data.dig('analysis', 'core_interests')&.length || 0,
        top_keywords: extract_top_keywords(data),
        archived: true
      }
    end
    
    interests.sort_by { |item| item[:date] }.reverse
  end
  
  def get_archived_observations
    observations = []
    
    Dir.glob(File.join(ARCHIVE_DIR, 'observations', 'daily_observation_*.json')).each do |file|
      data = JSON.parse(File.read(file))
      
      observations << {
        date: data['observed_at'],
        file: File.basename(file),
        total_keywords: data['total_keywords'],
        total_articles: data['total_valuable_articles'],
        keywords_with_articles: extract_keywords_with_articles(data),
        archived: true
      }
    end
    
    observations.sort_by { |item| item[:date] }.reverse
  end
  
  def extract_top_keywords(data)
    interests = data.dig('analysis', 'core_interests') || []
    interests.first(5).map do |interest|
      {
        keyword: interest['keyword'],
        importance: interest['importance'],
        category: interest['category']
      }
    end
  end
  
  def extract_keywords_with_articles(data)
    observations = data['observations'] || []
    observations.select { |o| o['valuable_count'] > 0 }
               .map { |o| { keyword: o['keyword'], count: o['valuable_count'] } }
  end
  
  def calculate_archive_statistics
    all_interests = []
    all_observations = []
    
    # 全アーカイブファイルを読み込んで統計を計算
    Dir.glob(File.join(ARCHIVE_DIR, 'interests', '*.json')).each do |file|
      data = JSON.parse(File.read(file))
      interests = data.dig('analysis', 'core_interests') || []
      all_interests.concat(interests)
    end
    
    Dir.glob(File.join(ARCHIVE_DIR, 'observations', '*.json')).each do |file|
      data = JSON.parse(File.read(file))
      all_observations << data
    end
    
    # キーワードの出現頻度を計算
    keyword_frequency = Hash.new(0)
    all_interests.each { |i| keyword_frequency[i['keyword']] += 1 }
    
    # カテゴリ分布
    category_distribution = Hash.new(0)
    all_interests.each { |i| category_distribution[i['category']] += 1 }
    
    {
      total_archive_files: {
        interests: Dir.glob(File.join(ARCHIVE_DIR, 'interests', '*.json')).length,
        observations: Dir.glob(File.join(ARCHIVE_DIR, 'observations', '*.json')).length
      },
      total_unique_keywords: keyword_frequency.keys.length,
      total_articles_found: all_observations.sum { |o| o['total_valuable_articles'] || 0 },
      most_frequent_keywords: keyword_frequency.sort_by { |_, v| -v }.first(10),
      category_distribution: category_distribution,
      oldest_archive: find_oldest_archive,
      newest_archive: find_newest_archive
    }
  end
  
  def add_keyword_to_history(history, data, keyword, archived)
    interests = data.dig('analysis', 'core_interests') || []
    interest = interests.find { |i| i['keyword'].downcase == keyword.downcase }
    
    if interest
      history << {
        date: data['generated_at'],
        importance: interest['importance'],
        frequency: interest['frequency'],
        category: interest['category'],
        context: interest['context'],
        archived: archived
      }
    end
  end
  
  def add_keyword_observations(observations, data, keyword, archived)
    obs_list = data['observations'] || []
    keyword_obs = obs_list.find { |o| o['keyword'].downcase == keyword.downcase }
    
    if keyword_obs && keyword_obs['valuable_count'] > 0
      observations << {
        date: data['observed_at'],
        articles_count: keyword_obs['valuable_count'],
        articles: keyword_obs['articles'],
        archived: archived
      }
    end
  end
  
  def find_oldest_archive
    oldest = nil
    
    Dir.glob(File.join(ARCHIVE_DIR, '**', '*.json')).each do |file|
      data = JSON.parse(File.read(file))
      date = data['generated_at'] || data['observed_at']
      next unless date
      
      if oldest.nil? || date < oldest
        oldest = date
      end
    end
    
    oldest
  end
  
  def find_newest_archive
    newest = nil
    
    Dir.glob(File.join(ARCHIVE_DIR, '**', '*.json')).each do |file|
      data = JSON.parse(File.read(file))
      date = data['generated_at'] || data['observed_at']
      next unless date
      
      if newest.nil? || date > newest
        newest = date
      end
    end
    
    newest
  end
end