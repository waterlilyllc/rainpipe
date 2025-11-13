# シンプル版：Google検索による日次観測システム

## コンセプト
- 1日1回、関心ワードをGoogle検索
- 新しいトピックだけをピックアップ
- 既に見たものは除外

## 1. システム構成

```
毎朝9時に実行:
1. アクティブな関心ワード取得（5-10個）
2. 各ワードをGoogle検索（過去24時間）
3. GPTで新規性判定
4. 新しいトピックだけ保存
5. 週末にサマリー生成
```

## 2. Google Custom Search API設定

```yaml
設定:
  api_key: GOOGLE_API_KEY
  search_engine_id: CUSTOM_SEARCH_ENGINE_ID
  
制限:
  - 100クエリ/日まで無料
  - それ以降は$5/1000クエリ
  
検索パラメータ:
  - dateRestrict: "d1"  # 過去24時間
  - num: 10  # 結果数
  - lr: "lang_ja"  # 日本語優先
  - sort: "date"  # 新しい順
```

## 3. 実装フロー

### 3.1 日次観測タスク
```ruby
class DailyObserver
  def run
    # 1. アクティブワード取得（最大10個）
    keywords = get_active_keywords(limit: 10)
    
    # 2. 各キーワードを検索
    keywords.each do |keyword|
      results = google_search(keyword, date_restrict: 'd1')
      
      # 3. 既読チェック
      new_results = filter_unseen(results)
      
      # 4. GPTで関連性・重要度判定
      if new_results.any?
        analysis = gpt_analyze_relevance(keyword, new_results)
        save_topics(analysis[:relevant_topics])
      end
    end
  end
  
  private
  
  def google_search(query, date_restrict:)
    # Google Custom Search API
    response = RestClient.get(
      "https://www.googleapis.com/customsearch/v1",
      params: {
        key: ENV['GOOGLE_API_KEY'],
        cx: ENV['SEARCH_ENGINE_ID'],
        q: query,
        dateRestrict: date_restrict,
        num: 10
      }
    )
    JSON.parse(response.body)['items'] || []
  end
end
```

### 3.2 GPTによる新規性・重要度判定
```ruby
def gpt_analyze_relevance(keyword, search_results)
  prompt = <<~PROMPT
    関心ワード: #{keyword}
    
    以下の検索結果から、新しく重要な情報だけを抽出してください：
    #{format_results(search_results)}
    
    判定基準:
    1. 本当に新しい情報か（既存情報の焼き直しではない）
    2. ユーザーにとって価値があるか
    3. アクションを起こす価値があるか（読む/試す）
    
    出力:
    {
      "relevant_topics": [
        {
          "title": "タイトル",
          "url": "URL",
          "summary": "なぜ重要か",
          "relevance_score": 85,
          "is_actionable": true
        }
      ]
    }
  PROMPT
  
  gpt_response(prompt)
end
```

## 4. データ管理

### 4.1 既読管理（シンプル版）
```yaml
seen_urls:
  - url_hash: "md5_hash"
    seen_at: "2025-07-20"
    keyword: "ChatGPT"

# 30日で自動削除（同じ記事が再度話題になることもあるため）
```

### 4.2 日次トピック保存
```yaml
daily_topics:
  date: "2025-07-20"
  topics:
    - keyword: "Rust"
      title: "Rust 1.80の新機能"
      url: "https://..."
      relevance: 90
      summary: "async trait が安定化"
```

## 5. 週次サマリー生成

### 5.1 シンプルなフォーマット
```markdown
# 今週の新着トピック（7/14-7/20）

## 🎯 ChatGPT
- **GPT-4o-miniが50%高速化** - 推論速度が大幅改善
- **Code Interpreterに新機能** - グラフ描画が可能に

## 🦀 Rust  
- **Rust 1.80リリース** - async trait finally!

## 見つかった新トピック
- **Claude Projects** - Anthropicの新機能
```

## 6. コスト計算

```yaml
1日あたり:
  - 関心ワード: 10個
  - Google検索: 10クエリ（無料枠内）
  - GPT判定: 10回 × $0.001 = $0.01
  
月間コスト:
  - Google: $0（無料枠内）
  - GPT: $0.30
  - 合計: $0.30（約45円）
```

## 7. 実装の簡略化ポイント

1. **統計不要** - GPTが都度判定
2. **複雑なDB不要** - JSONファイルで十分
3. **UIシンプル** - 週次メールのみでOK
4. **手動調整可** - 関心ワードは手動追加/削除可能

## 8. cron設定

```bash
# 毎日朝9時に実行
0 9 * * * cd /var/git/rainpipe && ruby daily_observer.rb

# 毎週日曜10時にサマリー送信
0 10 * * 0 cd /var/git/rainpipe && ruby weekly_summary.rb
```

## 9. 最小実装プラン

### Phase 1（3日で実装可能）
1. Google Custom Search API設定
2. 基本的な検索・保存機能
3. 既読URL管理

### Phase 2（+2日）
1. GPT統合
2. 関連性判定
3. 週次サマリー

### Phase 3（オプション）
1. Web UI
2. 関心ワード自動調整
3. Slack/Discord通知

## メリット
- シンプルで理解しやすい
- 低コスト（月45円程度）
- メンテナンスが楽
- 本当に新しい情報だけ届く