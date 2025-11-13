#!/bin/bash

# ログディレクトリ
LOG_DIR="/var/git/rainpipe/logs"
mkdir -p "$LOG_DIR"

# 日付
DATE=$(date +%Y%m%d)
LOG_FILE="$LOG_DIR/daily_interest_observer_${DATE}.log"

# 環境変数を読み込む
export $(grep -v '^#' /var/git/rainpipe/.env | xargs)

echo "========================================" >> "$LOG_FILE"
echo "定点観測開始: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Rubyスクリプトを実行
/usr/bin/ruby /var/git/rainpipe/daily_interest_observer.rb >> "$LOG_FILE" 2>&1

# 終了ステータスを記録
if [ $? -eq 0 ]; then
    echo "✅ 定点観測が正常に完了しました: $(date)" >> "$LOG_FILE"
else
    echo "❌ 定点観測でエラーが発生しました: $(date)" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# アーカイブ処理を実行
echo "アーカイブ処理を実行中..." >> "$LOG_FILE"
cd /var/git/rainpipe && /usr/bin/ruby -e "require_relative 'archive_manager'; ArchiveManager.new.archive_old_files" >> "$LOG_FILE" 2>&1

# 古いログファイルをアーカイブ（30日以上のものは圧縮してアーカイブ）
ARCHIVE_DIR="$LOG_DIR/archives"
mkdir -p "$ARCHIVE_DIR"
find "$LOG_DIR" -name "daily_interest_observer_*.log" -mtime +30 -exec gzip {} \; -exec mv {}.gz "$ARCHIVE_DIR/" \;