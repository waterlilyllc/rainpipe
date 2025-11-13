require 'json'
require 'date'

class InterestScorer
  def initialize
    @interest_manager = InterestManager.new
  end
  
  # 総合スコアを計算
  def calculate_scores
    latest = @interest_manager.get_latest_analysis
    return [] unless latest
    
    interests = latest.dig('analysis', 'core_interests') || []
    
    interests.map do |interest|
      keyword = interest['keyword']
      
      # 各種スコアを計算
      scores = {
        importance_score: interest['importance'] || 0,
        frequency_score: calculate_frequency_score(interest['frequency']),
        freshness_score: calculate_freshness_score(interest),
        trend_score: calculate_trend_score(keyword),
        related_words_score: calculate_related_words_score(interest),
        context_depth_score: calculate_context_depth_score(interest)
      }
      
      # 総合スコア計算（重み付け）
      total_score = (
        scores[:importance_score] * 0.3 +
        scores[:frequency_score] * 0.2 +
        scores[:freshness_score] * 0.15 +
        scores[:trend_score] * 0.15 +
        scores[:related_words_score] * 0.1 +
        scores[:context_depth_score] * 0.1
      ).round(2)
      
      {
        keyword: keyword,
        category: interest['category'],
        total_score: total_score,
        scores: scores,
        context: interest['context'],
        related_hot_words: interest['related_hot_words'] || []
      }
    end.sort_by { |item| -item[:total_score] }
  end
  
  # スコアの統計情報を計算
  def calculate_statistics
    scores = calculate_scores
    return {} if scores.empty?
    
    total_scores = scores.map { |s| s[:total_score] }
    
    {
      average_score: (total_scores.sum / total_scores.length.to_f).round(2),
      max_score: total_scores.max,
      min_score: total_scores.min,
      median_score: median(total_scores),
      top_categories: top_categories(scores),
      score_distribution: score_distribution(total_scores)
    }
  end
  
  private
  
  # 頻度スコア（正規化）
  def calculate_frequency_score(frequency)
    return 0 unless frequency
    # 対数スケールで正規化（最大10）
    [(Math.log(frequency + 1) * 2).round(2), 10].min
  end
  
  # 新鮮度スコア（最近の興味ほど高い）
  def calculate_freshness_score(interest)
    # 実装簡略化のため、現在は一律高スコア
    # TODO: 実際の日付データから計算
    8.0
  end
  
  # トレンドスコア（履歴から上昇/下降を判定）
  def calculate_trend_score(keyword)
    history = @interest_manager.get_keyword_history(keyword)
    return 5.0 if history.length < 2
    
    # 最近の重要度の変化を見る
    recent = history.last(3).map { |h| h[:importance] }
    if recent.length >= 2
      trend = recent.last - recent.first
      # -5 to +5 の範囲で正規化して、5を中心に
      5.0 + (trend.clamp(-5, 5))
    else
      5.0
    end
  end
  
  # 関連ワードスコア（関連ワードの質と量）
  def calculate_related_words_score(interest)
    related = interest['related_hot_words'] || []
    return 0 if related.empty?
    
    # 関連ワードの数（最大5）と理由の質で評価
    count_score = [related.length * 2, 10].min
    quality_score = related.count { |w| w['reason'] && w['reason'].length > 20 } * 2
    
    [(count_score + quality_score) / 2.0, 10].min
  end
  
  # 文脈の深さスコア
  def calculate_context_depth_score(interest)
    context = interest['context'] || ''
    examples = interest['examples'] || []
    
    # 文脈の長さと例の数で評価
    context_score = [context.length / 20.0, 5].min
    example_score = [examples.length * 1.5, 5].min
    
    context_score + example_score
  end
  
  # 中央値計算
  def median(array)
    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end
  
  # カテゴリ別スコア集計
  def top_categories(scores)
    category_scores = {}
    
    scores.each do |item|
      category = item[:category] || 'uncategorized'
      category_scores[category] ||= []
      category_scores[category] << item[:total_score]
    end
    
    category_scores.map do |category, scores|
      {
        category: category,
        average_score: (scores.sum / scores.length.to_f).round(2),
        count: scores.length
      }
    end.sort_by { |c| -c[:average_score] }
  end
  
  # スコア分布
  def score_distribution(scores)
    {
      '0-2': scores.count { |s| s >= 0 && s < 2 },
      '2-4': scores.count { |s| s >= 2 && s < 4 },
      '4-6': scores.count { |s| s >= 4 && s < 6 },
      '6-8': scores.count { |s| s >= 6 && s < 8 },
      '8-10': scores.count { |s| s >= 8 && s <= 10 }
    }
  end
end