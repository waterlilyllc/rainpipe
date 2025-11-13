# ブックマーク本文取得機能 設計書

## 概要
RainpipeにブックマークのWebページ本文を取得・保存する機能を追加します。
Gatherly API（nas.taileef971.ts.net:3002）を使用して非同期で本文を取得します。

## データ保存方針

### 既存システム
- **ブックマークメタデータ**: JSONファイル (`data/all_bookmarks_YYYYMMDD_HHMMSS.json`)
  - Raindrop.ioから取得したタイトル、URL、タグ、作成日時など
  - 日次バッチで更新・保存

### 新規追加（本文取得機能）
- **ブックマーク本文**: SQLite データベース
  - Webページの本文コンテンツ（大容量のため）
  - 取得状態管理（いつ取得したか、成功/失敗）

- **クロールジョブ管理**: SQLite データベース
  - Gatherly APIとの非同期処理状態管理
  - リトライ管理

### データの紐付け
- raindrop_id（Raindrop.ioのブックマークID）をキーとして紐付け
- JSONとDBを両方参照してブックマーク情報を構築

## データベース設計

### 1. bookmark_contents テーブル
ブックマークの本文データを保存

```sql
CREATE TABLE IF NOT EXISTS bookmark_contents (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  raindrop_id INTEGER UNIQUE NOT NULL,  -- Raindrop.io のブックマークID
  url TEXT NOT NULL,                     -- ブックマークのURL
  title TEXT,                            -- ページタイトル
  content TEXT,                          -- 本文（HTML/Markdown/プレーンテキスト）
  content_type VARCHAR(20),              -- 'html', 'markdown', 'text'
  word_count INTEGER,                    -- 文字数
  extracted_at DATETIME,                 -- 本文取得日時
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bookmark_contents_raindrop_id ON bookmark_contents(raindrop_id);
CREATE INDEX idx_bookmark_contents_url ON bookmark_contents(url);
```

### 2. crawl_jobs テーブル
Gatherly APIのジョブ状態管理

```sql
CREATE TABLE IF NOT EXISTS crawl_jobs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  job_id VARCHAR(100) UNIQUE NOT NULL,   -- Gatherly APIのジョブID
  raindrop_id INTEGER,                   -- 対象のブックマークID
  url TEXT NOT NULL,                     -- クロール対象URL
  status VARCHAR(20) NOT NULL,           -- 'pending', 'processing', 'success', 'failed'
  error_message TEXT,                    -- エラー時のメッセージ
  retry_count INTEGER DEFAULT 0,         -- リトライ回数
  max_retries INTEGER DEFAULT 3,         -- 最大リトライ回数
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  completed_at DATETIME,                 -- 完了日時

  FOREIGN KEY (raindrop_id) REFERENCES bookmarks(id)
);

CREATE INDEX idx_crawl_jobs_job_id ON crawl_jobs(job_id);
CREATE INDEX idx_crawl_jobs_status ON crawl_jobs(status);
CREATE INDEX idx_crawl_jobs_raindrop_id ON crawl_jobs(raindrop_id);
```

## クラス設計

### 1. GatherlyClient
Gatherly APIとの通信を担当

```ruby
class GatherlyClient
  API_BASE_URL = ENV['GATHERLY_API_URL'] || 'http://nas.taileef971.ts.net:3002'
  API_KEY = ENV['GATHERLY_API_KEY']

  # クロールジョブを作成
  # @param url [String] クロール対象URL
  # @param options [Hash] オプション
  # @return [Hash] job_id, status
  def create_crawl_job(url, options = {})

  # ジョブの状態を確認
  # @param job_id [String] ジョブID
  # @return [Hash] status, progress
  def get_job_status(job_id)

  # ジョブの結果を取得
  # @param job_id [String] ジョブID
  # @return [Hash] content, metadata
  def get_job_result(job_id)
end
```

### 2. BookmarkContentFetcher
ブックマーク本文取得のメイン処理

```ruby
class BookmarkContentFetcher
  def initialize(db, gatherly_client = nil)
    @db = db
    @gatherly_client = gatherly_client || GatherlyClient.new
  end

  # 本文取得ジョブを作成
  # @param raindrop_id [Integer] RaindropブックマークID
  # @param url [String] URL
  # @return [String] job_id
  def fetch_content(raindrop_id, url)

  # 保留中のジョブのステータスを更新
  # @return [Integer] 更新されたジョブ数
  def update_pending_jobs

  # 完了したジョブの結果を保存
  # @param job_id [String] ジョブID
  # @return [Boolean] 成功/失敗
  def save_job_result(job_id)

  # 失敗したジョブをリトライ
  # @return [Integer] リトライしたジョブ数
  def retry_failed_jobs
end
```

### 3. BookmarkContentManager
本文データのCRUD操作

```ruby
class BookmarkContentManager
  def initialize(db)
    @db = db
  end

  # 本文を取得
  # @param raindrop_id [Integer]
  # @return [Hash, nil]
  def get_content(raindrop_id)

  # 本文を保存
  # @param raindrop_id [Integer]
  # @param data [Hash] content, title, etc.
  # @return [Boolean]
  def save_content(raindrop_id, data)

  # 本文が存在するか確認
  # @param raindrop_id [Integer]
  # @return [Boolean]
  def content_exists?(raindrop_id)

  # 古い本文を再取得すべきか判定
  # @param raindrop_id [Integer]
  # @param days [Integer] 日数
  # @return [Boolean]
  def should_refetch?(raindrop_id, days = 30)
end
```

## 処理フロー

### 1. 新規ブックマークの本文取得
```
1. Raindrop.io から新しいブックマークを取得
2. 本文未取得のブックマークを抽出
3. 各ブックマークに対して:
   a. GatherlyClient.create_crawl_job(url) でジョブ作成
   b. crawl_jobs テーブルにジョブ情報を保存 (status: 'pending')
4. 定期バッチで状態確認・結果取得
```

### 2. ジョブ状態確認バッチ
```
1. status='pending' または 'processing' のジョブを取得
2. 各ジョブに対して:
   a. GatherlyClient.get_job_status(job_id) で状態確認
   b. status='success' なら結果を取得・保存
   c. status='failed' ならエラー記録、リトライ判定
   d. crawl_jobs テーブルを更新
```

### 3. 結果保存処理
```
1. GatherlyClient.get_job_result(job_id) で結果取得
2. BookmarkContentManager.save_content() で保存
   - content, title, word_count など
3. crawl_jobs の status を 'success' に更新
4. completed_at を記録
```

## バッチ処理設計

### fetch_bookmark_contents.rb
新しいブックマークの本文取得ジョブを作成

```ruby
# 実行頻度: 1日1回（朝8時）
# 処理内容: 本文未取得のブックマークに対してジョブ作成
```

### update_crawl_jobs.rb
ジョブの状態確認と結果保存

```ruby
# 実行頻度: 5分ごと
# 処理内容:
#   - 保留中ジョブの状態確認
#   - 完了したジョブの結果保存
#   - 失敗したジョブのリトライ
```

## UI/表示機能

### 本文表示ビュー
- `/bookmark/:id/content` - 個別ブックマークの本文表示
- 本文表示、word_count、取得日時を表示
- 本文がない場合は「取得中」または「取得失敗」と表示

### 週次サマリーへの統合
- 各ブックマークに本文がある場合、サマリー生成時に本文も考慮
- GPTへのプロンプトに本文を含めることでより詳細な分析が可能

## Gatherly API 利用詳細

### 使用エンドポイント

#### 1. クロールジョブ作成
```
POST /api/v1/crawl_jobs
Content-Type: application/json
Authorization: Bearer YOUR_API_KEY

{
  "source_type": "blogs",
  "source_payload": {
    "urls": ["https://example.com/article"]
  },
  "callback_url": "http://nas.taileef971.ts.net:4567/api/gatherly/callback"
}

Response:
{
  "job_uuid": "550e8400-e29b-41d4-a716-446655440000"
}
```

#### 2. ジョブ状態確認
```
GET /api/v1/crawl_jobs/{job_uuid}
Authorization: Bearer YOUR_API_KEY

Response:
{
  "job_uuid": "550e8400-e29b-41d4-a716-446655440000",
  "status": "success",  // pending, running, success, failed
  "error": null
}
```

#### 3. 結果取得
```
GET /api/v1/crawl_jobs/{job_uuid}/items
Authorization: Bearer YOUR_API_KEY

Response:
{
  "items": [
    {
      "id": "...",
      "external_id": "...",
      "body": {
        "url": "https://example.com/article",
        "title": "記事タイトル",
        "content": "本文...",
        "html": "<html>...</html>",
        "text": "プレーンテキスト..."
      },
      "fetched_at": "2024-01-01T12:00:00Z"
    }
  ]
}
```

### Webhook コールバック（オプション）
ジョブ完了時にRainpipeが受け取る通知:
```json
{
  "job_uuid": "550e8400-e29b-41d4-a716-446655440000",
  "status": "success",
  "finished_at": "2024-01-01T12:00:00Z",
  "items_count": 1
}
```

### API連携設定

#### 環境変数
```bash
GATHERLY_API_URL=http://nas.taileef971.ts.net:3002
GATHERLY_API_KEY=your_api_key_here
GATHERLY_CALLBACK_BASE_URL=http://nas.taileef971.ts.net:4567
```

#### .env.example に追加
```
# Gatherly API for content fetching
GATHERLY_API_URL=http://nas.taileef971.ts.net:3002
GATHERLY_API_KEY=
GATHERLY_CALLBACK_BASE_URL=http://nas.taileef971.ts.net:4567
```

## エラーハンドリング

### リトライ戦略
- 最大3回まで自動リトライ
- リトライ間隔: 初回5分、2回目30分、3回目2時間
- 3回失敗したらステータスを 'failed' に固定

### タイムアウト処理
- ジョブ作成から24時間経過しても完了しない場合はタイムアウト
- タイムアウトしたジョブは 'failed' として記録

### 通知
- 大量の失敗が発生した場合はログに警告
- 成功率が50%を下回る場合は調査が必要

## 実装の優先順位

1. **Phase 1**: データベース・基本クラス実装
   - テーブル作成
   - GatherlyClient, BookmarkContentManager 実装

2. **Phase 2**: ジョブ管理・バッチ処理
   - BookmarkContentFetcher 実装
   - バッチスクリプト作成

3. **Phase 3**: UI統合
   - 本文表示ビュー
   - 週次サマリーへの統合

## システム全体フロー

```
┌─────────────────────────────────────────────────────────────┐
│                   Rainpipe                                  │
│                                                             │
│  ┌─────────────────┐      ┌──────────────────┐            │
│  │ Raindrop.io API │      │ Gatherly API     │            │
│  │ (メタデータ)     │      │ (本文取得)        │            │
│  └────────┬────────┘      └────────┬─────────┘            │
│           │                        │                       │
│           v                        v                       │
│  ┌─────────────────┐      ┌──────────────────┐            │
│  │ JSON Files      │      │ SQLite Database  │            │
│  │ - タイトル       │      │ - 本文コンテンツ  │            │
│  │ - URL           │      │ - ジョブ管理      │            │
│  │ - タグ          │      │ - 取得履歴        │            │
│  │ - 作成日時      │      │                  │            │
│  └────────┬────────┘      └────────┬─────────┘            │
│           │                        │                       │
│           └────────┬───────────────┘                       │
│                    v                                       │
│           ┌──────────────────┐                             │
│           │  統合ビュー        │                             │
│           │ (raindrop_id で紐付け)                          │
│           └──────────────────┘                             │
└─────────────────────────────────────────────────────────────┘

【処理フロー】

1. 日次バッチ（朝7時）
   - Raindrop.ioから最新ブックマーク取得 → JSON保存

2. 本文取得バッチ（朝8時）
   - 本文未取得のブックマークを抽出
   - 各URLに対してGatherly APIにジョブ作成
   - crawl_jobs テーブルに記録

3. ジョブ監視バッチ（5分ごと）
   - pending/running状態のジョブをチェック
   - 完了したジョブの結果を取得・保存
   - 失敗したジョブをリトライ

4. ユーザーリクエスト時
   - JSONからメタデータ取得
   - SQLiteから本文取得
   - 統合して表示
```

## 今後の拡張

- 本文の全文検索機能
- 本文からのキーワード自動抽出
- 本文の要約生成（GPT利用）
- PDFやドキュメントファイルの対応
- 本文の差分検出（更新検知）
