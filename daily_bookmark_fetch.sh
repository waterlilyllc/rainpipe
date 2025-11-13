#!/bin/bash

# ログディレクトリ
LOG_DIR="/var/git/rainpipe/logs"
mkdir -p "$LOG_DIR"

# 日付
DATE=$(date +%Y%m%d)
LOG_FILE="$LOG_DIR/daily_bookmark_fetch_${DATE}.log"

# 環境変数を読み込む
export $(grep -v '^#' /var/git/rainpipe/.env | xargs)

echo "========================================" >> "$LOG_FILE"
echo "新着ブックマーク取得開始: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Rubyスクリプトを実行（新着取得と自動タグ付け）
cd /var/git/rainpipe && /usr/bin/ruby fetch_all_bookmarks.rb >> "$LOG_FILE" 2>&1

# 終了ステータスを記録
if [ $? -eq 0 ]; then
    echo "✅ 新着ブックマーク取得が正常に完了しました: $(date)" >> "$LOG_FILE"
else
    echo "❌ 新着ブックマーク取得でエラーが発生しました: $(date)" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# 本文取得ジョブの処理（新着取得時に作成されたジョブを処理）
echo "========================================" >> "$LOG_FILE"
echo "本文取得ジョブ処理開始: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# 5分待機（Gatherlyがページを取得する時間を確保）
sleep 300

cd /var/git/rainpipe && /usr/bin/ruby process_content_jobs.rb >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ 本文取得ジョブ処理が正常に完了しました: $(date)" >> "$LOG_FILE"
else
    echo "❌ 本文取得ジョブ処理でエラーが発生しました: $(date)" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# 古いログファイルをアーカイブ（30日以上のものは圧縮してアーカイブ）
ARCHIVE_DIR="$LOG_DIR/archives"
mkdir -p "$ARCHIVE_DIR"
find "$LOG_DIR" -name "daily_bookmark_fetch_*.log" -mtime +30 -exec gzip {} \; -exec mv {}.gz "$ARCHIVE_DIR/" \;