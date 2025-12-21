#!/bin/bash
# 毎週月曜朝、先週のブックマーク週刊レポートを Kindle に送信（改善版）
# cron: 0 9 * * 1 /var/git/rainpipe/weekly_kindle_send.sh
#
# 機能:
# 1. サマリーなし記事を検出
# 2. 週間サマリーを再生成（周辺キーワード含む）
# 3. Kindleレポート送信

cd /var/git/rainpipe

# 環境変数を読み込む
export $(grep -v '^#' /var/git/rainpipe/.env | xargs)

# Ruby gemのパスを設定
export GEM_HOME=/home/terubo/.gem
export GEM_PATH=/home/terubo/.gem:/var/lib/gems/3.0.0

echo "=========================================="
echo "Weekly Kindle Report Generator (Improved)"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 週刊PDFレポート生成＆Kindle送信
/usr/bin/bundle exec ruby generate_weekly_pdf.rb

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✓ Report sent successfully to Kindle"
else
    echo ""
    echo "✗ Failed to send report (Exit code: $EXIT_CODE)"
fi

echo ""
echo "=========================================="
