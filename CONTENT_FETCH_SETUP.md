# ブックマーク本文取得機能 セットアップガイド

## 概要

新着ブックマーク取得時に自動的に本文も取得する機能です。

## 仕組み

1. **ブックマーク取得時**: `fetch_all_bookmarks.rb` で新着ブックマークを取得
2. **本文取得ジョブ作成**: 各ブックマークの本文取得ジョブをGatherly APIに送信
3. **バックグラウンド処理**: Gatherly APIがWebページから本文を抽出（非同期）
4. **定期チェック**: `process_content_jobs.rb` が5分ごとにジョブの完了を確認
5. **本文保存**: 完了したジョブの本文をデータベースに保存
6. **GUI表示**: Rainpipe画面で本文を閲覧可能

## セットアップ

### 1. 環境変数の確認

`.env`ファイルに以下が設定されていることを確認：

```bash
# Gatherly API設定
GATHERLY_API_URL=http://nas.taileef971.ts.net:3002
GATHERLY_API_KEY=dev_api_key_12345
```

### 2. データベース初期化（初回のみ）

```bash
ruby db_setup.rb
```

### 3. cron設定

#### 方法A: 手動でcrontabに追加

```bash
crontab -e
```

以下を追加：

```cron
# 毎日8時に新着ブックマーク取得（本文取得も自動実行）
0 8 * * * /var/git/rainpipe/daily_bookmark_fetch.sh

# 5分ごとに本文取得ジョブを処理
*/5 * * * * /var/git/rainpipe/process_content_jobs.sh
```

#### 方法B: 自動設定スクリプト

```bash
# 現在のcronジョブをバックアップ
crontab -l > crontab_backup.txt 2>/dev/null || true

# 新しいジョブを追加
(crontab -l 2>/dev/null; echo "0 8 * * * /var/git/rainpipe/daily_bookmark_fetch.sh"; echo "*/5 * * * * /var/git/rainpipe/process_content_jobs.sh") | crontab -
```

### 4. 動作確認

#### テスト実行

```bash
# 新着ブックマーク取得（本文取得ジョブも作成）
ruby fetch_all_bookmarks.rb

# 5分待機
sleep 300

# 本文取得ジョブを処理
ruby process_content_jobs.rb
```

#### ログ確認

```bash
# 本日のログを確認
tail -f logs/daily_bookmark_fetch_$(date +%Y%m%d).log

# 本文取得ジョブのログ
tail -f logs/process_content_jobs_$(date +%Y%m%d).log
```

#### データベース確認

```bash
sqlite3 data/rainpipe.db "SELECT COUNT(*) FROM bookmark_contents;"
sqlite3 data/rainpipe.db "SELECT raindrop_id, title, word_count FROM bookmark_contents ORDER BY extracted_at DESC LIMIT 5;"
```

## 運用

### 自動運用（推奨）

cron設定後は自動的に動作します：

- **毎日8時**: 新着ブックマークを取得 → 本文取得ジョブを作成 → 5分後にジョブ処理
- **5分ごと**: 未完了の本文取得ジョブをチェック → 完了したら本文を保存

### 手動実行

必要に応じて手動実行も可能：

```bash
# 新着ブックマーク取得のみ（本文取得なし）
ruby fetch_all_bookmarks.rb

# 既存ブックマークの本文を取得
ruby fetch_bookmark_contents.rb

# 本文取得ジョブの処理
ruby process_content_jobs.rb
```

### 本文取得の無効化

本文取得を一時的に無効にする場合：

```bash
# .envファイルでAPI KEYをコメントアウト
# GATHERLY_API_KEY=dev_api_key_12345
```

または、`RaindropClient`の呼び出し時に無効化：

```ruby
client.update_bookmarks_data(enable_content_fetch: false)
```

## トラブルシューティング

### 本文が取得されない

1. **環境変数を確認**
   ```bash
   grep GATHERLY .env
   ```

2. **Gatherly APIの接続確認**
   ```bash
   curl -H "Authorization: Bearer dev_api_key_12345" http://nas.taileef971.ts.net:3002/api/v1/health
   ```

3. **ジョブの状態を確認**
   ```bash
   sqlite3 data/rainpipe.db "SELECT status, COUNT(*) FROM crawl_jobs GROUP BY status;"
   ```

4. **ログを確認**
   ```bash
   tail -100 logs/process_content_jobs_$(date +%Y%m%d).log
   ```

### ジョブが失敗する

- **原因1**: URLが取得できない（404, タイムアウトなど）
  - → 自動的に3回まで再試行されます

- **原因2**: Gatherly APIのエラー
  - → ログを確認して原因を特定

- **原因3**: 重複URL
  - → 同じURLは2回目以降エラーになります（正常な動作）

### パフォーマンス調整

ジョブ処理の頻度を調整する場合：

```bash
# 5分ごと → 10分ごとに変更
# crontab -e で以下に変更
*/10 * * * * /var/git/rainpipe/process_content_jobs.sh
```

## ファイル構成

```
rainpipe/
├── raindrop_client.rb              # ブックマーク取得（本文取得統合済み）
├── bookmark_content_fetcher.rb     # 本文取得ジョブ管理
├── bookmark_content_manager.rb     # 本文データ管理
├── gatherly_client.rb              # Gatherly API通信
├── crawl_job_manager.rb            # ジョブDB操作
├── process_content_jobs.rb         # ジョブ処理スクリプト
├── process_content_jobs.sh         # ジョブ処理シェル（cron用）
├── daily_bookmark_fetch.sh         # 日次取得スクリプト（本文対応）
├── db_setup.rb                     # DB初期化
└── data/
    └── rainpipe.db                 # SQLiteデータベース
        ├── bookmark_contents       # 本文データ
        └── crawl_jobs              # ジョブ管理
```

## 統計情報

処理状況の確認：

```bash
ruby -r './bookmark_content_fetcher' -e 'BookmarkContentFetcher.new.print_stats'
```

出力例：
```
📊 本文取得ジョブ統計
総ジョブ数: 150
  ✅ 成功: 142件 (94.7%)
  ❌ 失敗: 5件 (3.3%)
  ⏳ 処理中: 3件 (2.0%)

成功率: 96.6%
```

## 参考

- Gatherly API仕様: `/tmp/EXTERNAL_API_SPECIFICATION.md`
- バグ修正確認: `/tmp/GATHERLY_BUGFIX_VERIFICATION.md`
- Phase 2設計: `bookmark_content_fetch_design.md`

---

**更新日**: 2025-11-08
**バージョン**: 1.0
