# 関心ワード定点観測システム設計

## 概要
ユーザーの週次ブックマークから関心ワードを自動抽出し、それらのワードを定期的に観測して、トレンドやトピックを追跡するシステム。

## 主要機能

### 1. 関心ワード抽出機能
- 週次ブックマークのタイトル、タグ、説明文から重要キーワードを抽出
- TF-IDF、出現頻度、共起分析を使用
- 週ごとの新規ワード、継続ワード、消失ワードを追跡

### 2. 関心ワードデータベース
```ruby
# interest_words テーブル
{
  word: "AI",
  first_seen: "2025-07-01",
  last_seen: "2025-07-20",
  frequency: 45,
  weekly_counts: { "2025-W27": 5, "2025-W28": 12, ... },
  related_words: ["ChatGPT", "機械学習", "LLM"],
  categories: ["technology", "ai-ml"],
  trend: "rising" # rising/stable/declining
}
```

### 3. 定点観測機能
- Google News API / RSS feeds
- Hacker News API
- Reddit API
- X (Twitter) トレンド
- 技術ブログのRSS

### 4. 週次トピックレポート
- 関心ワードに関連する今週のニュース
- トレンドの変化（急上昇/下降）
- 新しく出現した関連ワード
- 要約とインサイト

## 実装フェーズ

### Phase 1: キーワード抽出（今回実装）
1. `keyword_extractor.rb` - ブックマークからキーワード抽出
2. `interest_word.rb` - 関心ワードモデル
3. `/interests` エンドポイント - 関心ワード表示

### Phase 2: 定点観測
1. `topic_observer.rb` - 外部ソースからの情報収集
2. `weekly_report_generator.rb` - レポート生成
3. cron jobで自動実行

### Phase 3: インテリジェント化
1. 機械学習による重要度スコアリング
2. 自動カテゴリ分類
3. トレンド予測

## データフロー
```
ブックマーク → キーワード抽出 → 関心ワードDB
                                    ↓
外部ソース → 定点観測 → マッチング → 週次レポート
```