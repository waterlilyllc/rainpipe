# 関心ワード定点観測システム 詳細設計書

## 1. システム概要

### 1.1 目的
- ユーザーのブックマーク履歴から関心分野を自動的に抽出
- 抽出した関心ワードを定期的に観測し、関連する最新情報を収集
- 週次でパーソナライズされたトピックレポートを生成

### 1.2 主要コンポーネント
```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Bookmark DB   │────▶│ Keyword Extractor│────▶│  Interest DB    │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                          │
┌─────────────────┐     ┌──────────────────┐             │
│ External APIs   │────▶│  Topic Observer  │◀────────────┘
└─────────────────┘     └────────┬─────────┘
                                 │
┌─────────────────┐     ┌────────▼─────────┐     ┌─────────────────┐
│   Report View   │◀────│ Report Generator │────▶│  Notification   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## 2. データモデル設計

### 2.1 関心ワード (interest_words)
```ruby
{
  id: "uuid",
  word: "ChatGPT",
  normalized_word: "chatgpt",  # 正規化版（検索用）
  
  # 統計情報
  first_seen_date: "2025-01-15",
  last_seen_date: "2025-07-20",
  total_frequency: 156,
  bookmark_count: 45,  # 含まれるブックマーク数
  
  # 週次データ
  weekly_stats: {
    "2025-W28": {
      frequency: 8,
      bookmarks: ["id1", "id2"],
      sources: ["title": 5, "tags": 2, "excerpt": 1]
    }
  },
  
  # 関連情報
  related_words: ["AI", "GPT-4", "OpenAI", "LLM"],
  categories: ["ai-ml", "technology"],
  
  # トレンド分析
  trend: {
    status: "rising",  # rising/stable/declining/spike
    momentum: 2.5,     # 増加率
    forecast: "継続上昇予想"
  },
  
  # メタデータ
  language: "en",
  word_type: "product_name",  # generic/brand/person/technology
  importance_score: 8.5,
  
  created_at: "2025-01-15T10:00:00Z",
  updated_at: "2025-07-20T15:30:00Z"
}
```

### 2.2 観測トピック (observed_topics)
```ruby
{
  id: "uuid",
  interest_word_id: "uuid",
  
  # ソース情報
  source: "hackernews",  # hackernews/reddit/gnews/rss/twitter
  source_url: "https://news.ycombinator.com/item?id=123456",
  
  # コンテンツ
  title: "ChatGPT achieves new milestone",
  summary: "...",
  content: "...",  # 全文（可能な場合）
  author: "username",
  
  # メタデータ
  published_at: "2025-07-20T12:00:00Z",
  fetched_at: "2025-07-20T13:00:00Z",
  
  # 関連性スコア
  relevance_score: 0.85,  # 関心ワードとの関連度
  
  # エンゲージメント指標
  engagement: {
    views: 10000,
    comments: 234,
    shares: 567,
    upvotes: 890
  },
  
  # 分析結果
  sentiment: "positive",  # positive/neutral/negative
  tags: ["breakthrough", "ai", "technology"],
  mentioned_words: ["ChatGPT", "OpenAI", "GPT-4"]
}
```

### 2.3 週次レポート (weekly_reports)
```ruby
{
  id: "uuid",
  week_key: "2025-W28",
  generated_at: "2025-07-21T09:00:00Z",
  
  # サマリー統計
  stats: {
    total_topics: 156,
    new_topics: 45,
    trending_words: 12,
    declining_words: 3
  },
  
  # ハイライト
  highlights: [
    {
      type: "trending",
      word: "ChatGPT",
      reason: "300% increase in mentions",
      topics: ["topic_id1", "topic_id2"]
    }
  ],
  
  # カテゴリ別サマリー
  categories: {
    "ai-ml": {
      topic_count: 45,
      top_words: ["ChatGPT", "LLM", "Claude"],
      summary: "AI分野では..."
    }
  },
  
  # 推奨事項
  recommendations: [
    {
      type: "new_trend",
      message: "「AI Agent」が急上昇中です",
      action: "関連記事を確認"
    }
  ]
}
```

## 3. 機能設計

### 3.1 キーワード抽出エンジン

#### 3.1.1 抽出アルゴリズム
```ruby
class KeywordExtractor
  # 1. 形態素解析（日本語対応）
  # - MeCab/Sudachiを使用
  # - 名詞、固有名詞を重点的に抽出
  
  # 2. 重要度計算
  def calculate_importance(word, context)
    score = base_score(word)
    score *= position_weight(context)  # タイトル: 3.0, タグ: 2.0, 本文: 1.0
    score *= frequency_weight(word)
    score *= idf_weight(word)  # 逆文書頻度
    score *= recency_weight(word)  # 最新性
    score
  end
  
  # 3. フィルタリング
  # - ストップワード除外
  # - 最小文字数（2文字以上）
  # - 最大文字数（30文字以下）
  # - 数字のみ除外
  # - URL除外
end
```

#### 3.1.2 関連ワード検出
```ruby
# 共起分析
def find_related_words(target_word)
  # 同じブックマークに頻繁に出現する単語を検出
  # PMI (Pointwise Mutual Information) を使用
end

# カテゴリ推定
def estimate_category(word, related_words)
  # 事前定義カテゴリとのマッチング
  # 関連ワードからの推定
end
```

### 3.2 定点観測エンジン

#### 3.2.1 データソース
```yaml
sources:
  # ニュースソース
  google_news:
    api: Google News API
    rate_limit: 100/day
    languages: [ja, en]
    
  hackernews:
    api: HN API
    endpoints: [top, new, best]
    rate_limit: unlimited
    
  reddit:
    api: Reddit API
    subreddits: [technology, programming, japan]
    rate_limit: 60/min
    
  # RSSフィード
  rss_feeds:
    - url: https://b.hatena.ne.jp/hotentry/it.rss
      name: はてなブックマーク IT
    - url: https://techcrunch.com/feed/
      name: TechCrunch
    - url: https://www.publickey1.jp/atom.xml
      name: Publickey
      
  # Twitter/X (要API key)
  twitter:
    api: Twitter API v2
    search_types: [recent, popular]
    rate_limit: 300/15min
```

#### 3.2.2 観測スケジュール
```ruby
# Sidekiq/Whenever での実装
every 6.hours do
  runner "TopicObserver.fetch_hackernews"
  runner "TopicObserver.fetch_reddit"
end

every 12.hours do
  runner "TopicObserver.fetch_rss_feeds"
  runner "TopicObserver.fetch_google_news"
end

every :sunday, at: '9am' do
  runner "WeeklyReportGenerator.generate"
end
```

### 3.3 レポート生成エンジン

#### 3.3.1 レポート構成
```markdown
# 週次関心トピックレポート（2025年第28週）

## 📈 トレンド概要
- **急上昇ワード**: ChatGPT (+300%), AI Agent (+250%)
- **注目の新規ワード**: GPT-4o, Anthropic Claude
- **継続的関心**: Ruby, AWS, Docker

## 🔥 今週のハイライト

### 1. ChatGPT関連（8件）
- [重要] ChatGPTに新機能「Code Interpreter」が追加
- OpenAIが企業向けプランを大幅値下げ
- 日本企業のChatGPT活用事例が急増

### 2. Ruby/Rails関連（5件）
- Rails 8.0のロードマップが公開
- Hotwireの新機能で開発効率が向上

## 📊 カテゴリ別サマリー

### AI・機械学習（15件）
今週はChatGPTを中心に...

### Web開発（12件）
Railsコミュニティでは...

## 💡 来週の注目ポイント
- AI Agentの実装事例が増加傾向
- 「GPT-4o」の一般公開が予想される

## 📈 統計情報
- 総トピック数: 156件（先週比 +23%）
- 情報ソース: 12サイト
- 最も活発な時間: 火曜日14時
```

#### 3.3.2 配信方法
- Web UI での表示
- メール配信（週次）
- Slack/Discord 通知
- RSS フィード生成

## 4. 実装計画

### Phase 1: 基礎機能（1-2週間）
1. キーワード抽出エンジンの実装
2. 関心ワードDBの構築
3. 管理画面の作成

### Phase 2: 観測機能（2-3週間）
1. 外部API連携
2. スケジューラー設定
3. トピック収集・保存

### Phase 3: レポート機能（1-2週間）
1. レポート生成ロジック
2. 配信システム
3. UI/UXの改善

### Phase 4: 高度化（継続的）
1. 機械学習による精度向上
2. パーソナライゼーション強化
3. 予測機能の追加

## 5. 技術スタック

```yaml
backend:
  language: Ruby
  framework: Sinatra/Rails
  database: PostgreSQL
  cache: Redis
  queue: Sidekiq
  
frontend:
  framework: Vue.js/React
  charts: Chart.js
  
external:
  nlp: MeCab/Sudachi
  ml: Python (scikit-learn)
  
infrastructure:
  hosting: AWS/GCP
  monitoring: Datadog
  ci_cd: GitHub Actions
```

## 6. セキュリティ・プライバシー

- APIキーの暗号化保存
- レート制限の実装
- 個人情報の匿名化
- データ保持期間の設定（6ヶ月）

## 7. 拡張可能性

- プラグインアーキテクチャで新規ソース追加可能
- 多言語対応（英語・日本語以外）
- チーム共有機能
- エクスポート機能（Notion, Obsidian連携）