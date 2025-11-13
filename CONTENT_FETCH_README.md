# ブックマーク本文取得機能 - セットアップ完了

## ✅ 準備完了項目

### 1. データベース
- ✅ SQLiteデータベース作成: `data/rainpipe.db`
- ✅ `bookmark_contents` テーブル作成
- ✅ `crawl_jobs` テーブル作成
- ✅ インデックス作成

### 2. クラス実装
- ✅ `GatherlyClient` - Gatherly API通信クラス
- ✅ `BookmarkContentManager` - 本文データ管理クラス

### 3. 環境設定
- ✅ `.env.example` に環境変数追加
- ✅ テストスクリプト作成

## 📁 作成されたファイル

```
/var/git/rainpipe/
├── data/
│   └── rainpipe.db                          # SQLiteデータベース
├── db_setup.rb                              # DB初期化スクリプト
├── gatherly_client.rb                       # Gatherly APIクライアント
├── bookmark_content_manager.rb              # 本文データ管理
├── test_gatherly_integration.rb             # 統合テスト
├── bookmark_content_fetch_design.md         # 設計書
└── CONTENT_FETCH_README.md                  # このファイル
```

## 🔧 次のステップ

### 1. 環境変数設定（必須）

`.env` ファイルに以下を追加してください：

```bash
# Gatherly API設定
GATHERLY_API_URL=http://nas.taileef971.ts.net:3002
GATHERLY_API_KEY=your_actual_api_key_here
GATHERLY_CALLBACK_BASE_URL=http://nas.taileef971.ts.net:4567
```

### 2. テスト実行

環境変数を設定したら、統合テストを実行：

```bash
ruby test_gatherly_integration.rb
```

このテストは以下を確認します：
- GatherlyClient の初期化
- クロールジョブの作成
- ジョブステータスの確認
- BookmarkContentManager のCRUD操作

### 3. 次の実装フェーズ

Phase 2として以下を実装する必要があります：

1. **BookmarkContentFetcher** クラス
   - ジョブの作成・管理
   - ステータス更新
   - リトライ処理

2. **バッチスクリプト**
   - `fetch_bookmark_contents.rb` - 本文取得ジョブ作成（日次）
   - `update_crawl_jobs.rb` - ジョブ状態確認・結果保存（5分ごと）

3. **cronジョブ設定**
   - 朝8時: 本文取得バッチ実行
   - 5分ごと: ジョブ更新バッチ実行

## 📊 データベーススキーマ

### bookmark_contents
| カラム | 型 | 説明 |
|--------|-----|------|
| id | INTEGER | プライマリキー |
| raindrop_id | INTEGER | RaindropブックマークID（UNIQUE） |
| url | TEXT | ブックマークURL |
| title | TEXT | ページタイトル |
| content | TEXT | 本文 |
| content_type | VARCHAR(20) | 'html', 'markdown', 'text' |
| word_count | INTEGER | 文字数 |
| extracted_at | DATETIME | 取得日時 |
| created_at | DATETIME | 作成日時 |
| updated_at | DATETIME | 更新日時 |

### crawl_jobs
| カラム | 型 | 説明 |
|--------|-----|------|
| id | INTEGER | プライマリキー |
| job_id | VARCHAR(100) | GatherlyジョブID（UNIQUE） |
| raindrop_id | INTEGER | 対象ブックマークID |
| url | TEXT | クロール対象URL |
| status | VARCHAR(20) | 'pending', 'processing', 'success', 'failed' |
| error_message | TEXT | エラーメッセージ |
| retry_count | INTEGER | リトライ回数 |
| max_retries | INTEGER | 最大リトライ回数 |
| created_at | DATETIME | 作成日時 |
| updated_at | DATETIME | 更新日時 |
| completed_at | DATETIME | 完了日時 |

## 🔌 GatherlyClient API

### メソッド一覧

```ruby
client = GatherlyClient.new

# クロールジョブ作成
result = client.create_crawl_job(url, callback_url: 'http://...')
# => { job_uuid: "550e8400-..." }

# ジョブステータス確認
status = client.get_job_status(job_uuid)
# => { job_uuid: "...", status: "success", error: nil }

# ジョブ結果取得
result = client.get_job_result(job_uuid)
# => { items: [{ id: "...", body: { content: "...", title: "..." } }] }
```

## 📝 BookmarkContentManager API

### メソッド一覧

```ruby
manager = BookmarkContentManager.new

# 本文取得
content = manager.get_content(raindrop_id)

# 本文保存
manager.save_content(raindrop_id, {
  url: 'https://...',
  title: 'タイトル',
  content: '本文...',
  content_type: 'text',
  word_count: 1000
})

# 存在確認
manager.content_exists?(raindrop_id) # => true/false

# 再取得判定（30日以上古い場合true）
manager.should_refetch?(raindrop_id, 30) # => true/false

# 本文未取得のIDリスト取得
missing_ids = manager.get_missing_content_ids([1, 2, 3, 4, 5])

# 統計情報
stats = manager.get_stats
# => { total_contents: 100, avg_word_count: 500.5, recent_week_count: 10 }
```

## 🐛 トラブルシューティング

### Gatherly APIに接続できない

1. Gatherly APIが起動しているか確認：
   ```bash
   curl http://nas.taileef971.ts.net:3002/
   ```

2. API Keyが正しく設定されているか確認：
   ```bash
   echo $GATHERLY_API_KEY
   ```

### データベースエラー

データベースを再作成：
```bash
rm data/rainpipe.db
ruby db_setup.rb
```

## 📖 参考資料

- 設計書: `bookmark_content_fetch_design.md`
- Gatherly API仕様: `/tmp/EXTERNAL_API_SPECIFICATION.md`
- GitHubチケット: https://github.com/waterlilyllc/rainpipe/issues/1
