#!/bin/bash
# 5分ごとに実行して本文取得ジョブを処理
# cron: */5 * * * *

LOG_DIR="/var/git/rainpipe/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d)
LOG_FILE="$LOG_DIR/process_content_jobs_${DATE}.log"

# 環境変数を読み込む
export $(grep -v '^#' /var/git/rainpipe/.env | xargs)

echo "[$(date)] 本文取得ジョブ処理開始" >> "$LOG_FILE"

cd /var/git/rainpipe && /usr/bin/ruby process_content_jobs.rb >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date)] ✅ 処理完了" >> "$LOG_FILE"
else
    echo "[$(date)] ❌ エラー発生" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# 古いログファイルを削除（7日以上）
find "$LOG_DIR" -name "process_content_jobs_*.log" -mtime +7 -delete
