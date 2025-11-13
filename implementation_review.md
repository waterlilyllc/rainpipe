# 実装状況レビュー - ブックマーク本文取得機能

## ✅ Phase 1: 完了済み（基盤実装）

### データベース
- ✅ `data/rainpipe.db` - SQLiteデータベース作成
- ✅ `bookmark_contents` テーブル - 本文データ保存用
- ✅ `crawl_jobs` テーブル - ジョブ管理用
- ✅ インデックス作成済み

### クラス実装
- ✅ **GatherlyClient** (`gatherly_client.rb`)
  - `create_crawl_job(url, options)` - ジョブ作成
  - `get_job_status(job_id)` - 状態確認
  - `get_job_result(job_id)` - 結果取得
  - エラーハンドリング実装済み

- ✅ **BookmarkContentManager** (`bookmark_content_manager.rb`)
  - `get_content(raindrop_id)` - 本文取得
  - `save_content(raindrop_id, data)` - 本文保存
  - `content_exists?(raindrop_id)` - 存在確認
  - `should_refetch?(raindrop_id, days)` - 再取得判定
  - `get_missing_content_ids(ids)` - 未取得ID抽出
  - `get_stats()` - 統計情報

### 環境設定
- ✅ `.env.example` に環境変数追加
- ✅ テストスクリプト作成 (`test_gatherly_integration.rb`)
- ✅ セットアップガイド作成 (`CONTENT_FETCH_README.md`)

## 🚧 Phase 2: 未実装（ジョブ管理・バッチ処理）

### 必要なクラス

#### 1. BookmarkContentFetcher
**目的**: ジョブのライフサイクル管理

**必要なメソッド**:
```ruby
class BookmarkContentFetcher
  # ジョブ作成とDB記録
  def fetch_content(raindrop_id, url)
    # 1. Gatherly APIにジョブ作成
    # 2. crawl_jobsテーブルに保存 (status: 'pending')
  end

  # 保留中ジョブの状態更新
  def update_pending_jobs
    # 1. status='pending'/'running'のジョブ取得
    # 2. 各ジョブのステータス確認
    # 3. 完了したジョブの結果保存
    # 4. DBステータス更新
  end

  # 完了ジョブの結果保存
  def save_job_result(job_id)
    # 1. Gatherly APIから結果取得
    # 2. body.content, body.title などを抽出
    # 3. BookmarkContentManager.save_content()
    # 4. crawl_jobs.status = 'success'
  end

  # 失敗ジョブのリトライ
  def retry_failed_jobs
    # 1. status='failed' && retry_count < max_retries
    # 2. 新しいジョブ作成
    # 3. retry_count++
  end

  # タイムアウトジョブの処理
  def handle_timeout_jobs
    # created_at から 24時間経過したジョブを 'failed' に
  end
end
```

#### 2. CrawlJobManager（新規提案）
**目的**: crawl_jobsテーブルのCRUD操作を分離

```ruby
class CrawlJobManager
  def create_job(raindrop_id, url, job_uuid)
  def get_job(job_id)
  def update_job_status(job_id, status, error_message = nil)
  def get_pending_jobs
  def get_failed_jobs_for_retry
  def get_timeout_jobs
end
```

### 必要なバッチスクリプト

#### 1. fetch_bookmark_contents.rb
**実行頻度**: 1日1回（朝8時）

```ruby
# 処理内容:
# 1. 最新のブックマークJSON読み込み
# 2. BookmarkContentManager.get_missing_content_ids() で未取得ID抽出
# 3. 各ブックマークに対してBookmarkContentFetcher.fetch_content()
# 4. 作成したジョブ数をログ出力
```

#### 2. update_crawl_jobs.rb
**実行頻度**: 5分ごと

```ruby
# 処理内容:
# 1. BookmarkContentFetcher.update_pending_jobs()
#    - 保留中ジョブの状態確認・結果保存
# 2. BookmarkContentFetcher.retry_failed_jobs()
#    - リトライ可能な失敗ジョブを再実行
# 3. BookmarkContentFetcher.handle_timeout_jobs()
#    - 24時間経過したジョブを失敗扱い
# 4. 統計情報をログ出力（成功/失敗/保留中の数）
```

### Webhookエンドポイント（オプション）

#### app.rb に追加
```ruby
post '/api/gatherly/callback' do
  # Gatherly APIからのコールバック受信
  # job_uuid, status を受け取る
  # DBのステータスを更新
  # status='success'なら結果取得を即座に実行
end
```

### Cronジョブ設定

```bash
# /etc/crontab または crontab -e

# 本文取得ジョブ作成（朝8時）
0 8 * * * cd /var/git/rainpipe && /usr/bin/ruby fetch_bookmark_contents.rb >> logs/fetch_contents.log 2>&1

# ジョブ状態更新（5分ごと）
*/5 * * * * cd /var/git/rainpipe && /usr/bin/ruby update_crawl_jobs.rb >> logs/update_jobs.log 2>&1
```

## 🔍 発見された課題と改善点

### 1. API レスポンスのbody構造が不明瞭
**問題**: Gatherly APIの結果から `body.content`, `body.title` を抽出する必要があるが、正確な構造が未検証

**解決策**:
- テストスクリプトで実際のAPIレスポンスを確認
- `body`フィールドの構造をドキュメント化

### 2. リトライ間隔の実装
**設計**: リトライ間隔を 5分→30分→2時間 と設定

**実装方法**:
- `crawl_jobs.last_retry_at` カラム追加を検討
- または `updated_at` を使用して経過時間を判定

### 3. 成功率モニタリング
**設計**: 成功率50%以下で警告

**実装**:
- `update_crawl_jobs.rb` で統計計算
- ログに警告出力
- 将来的には通知機能（メール/Slack）

### 4. Webhookの優先度
**現状**: オプション扱い

**推奨**: Phase 2.5 として実装
- リアルタイム性向上
- API負荷軽減（ポーリング頻度削減）

## 📋 Phase 2 実装チェックリスト

### コアクラス
- [ ] `CrawlJobManager` クラス作成
- [ ] `BookmarkContentFetcher` クラス作成
- [ ] リトライロジック実装
- [ ] タイムアウト処理実装

### バッチスクリプト
- [ ] `fetch_bookmark_contents.rb` 作成
- [ ] `update_crawl_jobs.rb` 作成
- [ ] ログ出力・エラーハンドリング
- [ ] 統計情報の計算・出力

### インフラ
- [ ] `logs/` ディレクトリ作成
- [ ] cronジョブ設定
- [ ] ログローテーション設定

### テスト
- [ ] 単体テスト作成（各クラス）
- [ ] 統合テスト作成（バッチ全体フロー）
- [ ] エラーケーステスト

### ドキュメント
- [ ] API仕様の明確化（実際のレスポンス確認）
- [ ] 運用手順書作成
- [ ] トラブルシューティングガイド

## 🎯 Phase 3: UI統合（未着手）

### 必要な実装
- [ ] `/bookmark/:id/content` エンドポイント追加
- [ ] 本文表示ビュー作成
- [ ] 週次サマリーへの統合
- [ ] 取得状態の表示UI

## 📊 データベース改善提案

### オプションカラム追加を検討
```sql
ALTER TABLE crawl_jobs ADD COLUMN last_retry_at DATETIME;
ALTER TABLE crawl_jobs ADD COLUMN api_response TEXT; -- デバッグ用
```

## 🚀 次のアクション

1. **即座に実装すべき**: Phase 2のコアクラス
   - `CrawlJobManager`
   - `BookmarkContentFetcher`

2. **その後実装**: バッチスクリプト
   - `fetch_bookmark_contents.rb`
   - `update_crawl_jobs.rb`

3. **最後に設定**: インフラ
   - cronジョブ
   - ログ管理

## 📝 メモ

- Phase 1の実装品質は高い（エラーハンドリング、統計機能含む）
- 設計とPhase 1実装の整合性は取れている
- Phase 2の実装により、エンドツーエンドの本文取得が可能になる
