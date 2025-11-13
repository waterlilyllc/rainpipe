class BookmarkCategorizer
  # カテゴリー定義（優先順位順）
  CATEGORIES = {
    '🔧 技術・開発' => {
      tags: ['programming', 'dev-tools', 'cloud-infra', 'web-development', 
             'security', 'data-knowledge', 'seo'],
      keywords: ['API', 'GitHub', 'Docker', 'JavaScript', 'Ruby', 'Python', 
                 'React', 'Vue', 'Node.js', 'AWS', 'GCP', 'Azure']
    },
    
    '🤖 AI・機械学習' => {
      tags: ['ai-ml'],
      keywords: ['ChatGPT', 'Claude', 'AI', 'LLM', 'GPT', 'OpenAI', 'Anthropic', 
                 '機械学習', 'ディープラーニング', 'Copilot', 'Gemini']
    },
    
    '💼 ビジネス・仕事' => {
      tags: ['business', 'technology'],
      keywords: ['経営', 'マネジメント', 'プロジェクト', 'ビジネス', '仕事術', 
                 'キャリア', '転職', 'フリーランス']
    },
    
    '🎨 デザイン・UI' => {
      tags: ['ui-design'],
      keywords: ['デザイン', 'UI', 'UX', 'Figma', 'Sketch', 'CSS', 'Tailwind', 
                 'Material', 'Bootstrap']
    },
    
    '👨‍👩‍👧‍👦 家庭・子育て' => {
      tags: ['parenting', 'lifestyle'],
      keywords: ['子育て', '育児', '教育', '家族', '子ども', 'キッズ', 
                 '赤ちゃん', '保育園', '幼稚園', '小学校']
    },
    
    '🍳 料理・食事' => {
      tags: ['food-delivery', 'nutrition'],
      keywords: ['料理', 'レシピ', '食事', 'グルメ', '飲食', 'カフェ', 
                 'レストラン', '宅配', 'デリバリー', '栄養']
    },
    
    '🎮 エンタメ・趣味' => {
      tags: ['entertainment'],
      keywords: ['ゲーム', '映画', 'アニメ', '漫画', '音楽', 'YouTube', 
                 'Netflix', 'Steam', 'Switch', 'PlayStation']
    },
    
    '🏕️ アウトドア・旅行' => {
      tags: ['outdoor', 'camping'],
      keywords: ['キャンプ', 'アウトドア', '登山', 'ハイキング', '旅行', 
                 '観光', 'ホテル', '温泉', 'BBQ']
    },
    
    '📚 学習・自己啓発' => {
      tags: ['learning', 'psychology'],
      keywords: ['勉強', '学習', '資格', '英語', 'TOEIC', '自己啓発', 
                 '読書', '本', 'Kindle', 'Obsidian']
    },
    
    '🛍️ ショッピング・ガジェット' => {
      tags: ['smartphones', 'gadgets'],
      keywords: ['iPhone', 'Android', 'iPad', 'Mac', 'Windows', 'ガジェット', 
                 '家電', 'Amazon', '楽天', 'メルカリ']
    },
    
    '🌿 健康・ライフスタイル' => {
      tags: ['sustainability', 'communication'],
      keywords: ['健康', 'フィットネス', 'ヨガ', 'ダイエット', '睡眠', 
                 'メンタルヘルス', 'サステナブル', 'エコ']
    }
  }
  
  def initialize
    # カテゴリーごとのカウンタ（デバッグ用）
    @category_counts = Hash.new(0)
  end
  
  def categorize_bookmarks(bookmarks)
    categorized = {}
    
    # 各カテゴリーの配列を初期化
    CATEGORIES.keys.each do |category|
      categorized[category] = []
    end
    
    # その他カテゴリーも追加
    categorized['📌 その他'] = []
    
    # 各ブックマークをカテゴリーに振り分け
    bookmarks.each do |bookmark|
      category = determine_category(bookmark)
      categorized[category] << bookmark
      @category_counts[category] += 1
    end
    
    # 空のカテゴリーを削除
    categorized.delete_if { |_, bookmarks| bookmarks.empty? }
    
    # カテゴリー内でブックマークを日付順にソート
    categorized.each do |category, bookmarks|
      categorized[category] = bookmarks.sort_by { |b| Date.parse(b['created']) }.reverse
    end
    
    categorized
  end
  
  def determine_category(bookmark)
    title = bookmark['title'] || ''
    tags = bookmark['tags'] || []
    excerpt = bookmark['excerpt'] || ''
    
    # タグとキーワードでスコアリング
    category_scores = {}
    
    CATEGORIES.each do |category, criteria|
      score = 0
      
      # タグマッチング（重み: 3）
      if criteria[:tags]
        matching_tags = tags.count { |tag| criteria[:tags].include?(tag) }
        score += matching_tags * 3
      end
      
      # キーワードマッチング（重み: 1）
      if criteria[:keywords]
        text = "#{title} #{excerpt}".downcase
        matching_keywords = criteria[:keywords].count do |keyword|
          text.include?(keyword.downcase)
        end
        score += matching_keywords
      end
      
      category_scores[category] = score if score > 0
    end
    
    # 最高スコアのカテゴリーを選択
    if category_scores.empty?
      '📌 その他'
    else
      category_scores.max_by { |_, score| score }[0]
    end
  end
  
  def get_category_stats
    @category_counts
  end
end