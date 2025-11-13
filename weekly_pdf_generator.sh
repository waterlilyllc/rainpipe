#!/bin/bash
# 週次PDF生成（毎週月曜 9時に実行）
# cron: 0 9 * * 1

LOG_DIR="/var/git/rainpipe/logs"
mkdir -p "$LOG_DIR"

DATE=$(date +%Y%m%d)
LOG_FILE="$LOG_DIR/weekly_pdf_${DATE}.log"

# 環境変数を読み込む
export $(grep -v '^#' /var/git/rainpipe/.env | xargs)

echo "========================================" >> "$LOG_FILE"
echo "週次PDF生成開始: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

cd /var/git/rainpipe && /usr/bin/ruby generate_weekly_pdf.rb >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "✅ PDF生成が正常に完了しました: $(date)" >> "$LOG_FILE"

    # 生成されたPDFのパスを記録
    LATEST_PDF=$(ls -t data/weekly_summary_*.pdf 2>/dev/null | head -1)
    if [ -n "$LATEST_PDF" ]; then
        echo "生成されたPDF: $LATEST_PDF" >> "$LOG_FILE"
        echo "サイズ: $(du -h "$LATEST_PDF" | cut -f1)" >> "$LOG_FILE"
    fi
else
    echo "❌ PDF生成でエラーが発生しました: $(date)" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# 古いPDFファイルを削除（30日以上）
find /var/git/rainpipe/data -name "weekly_summary_*.pdf" -mtime +30 -delete

# 古いログファイルを削除（14日以上）
find "$LOG_DIR" -name "weekly_pdf_*.log" -mtime +14 -delete
