#!/bin/bash
# 毎週月曜朝、先週のブックマーク週刊レポートを Kindle に送信（改善版）
# cron: 0 9 * * 1 /var/git/rainpipe/weekly_kindle_send.sh
#
# 機能:
# 1. サマリーなし記事を検出
# 2. 週間サマリーを再生成（周辺キーワード含む）
# 3. Kindleレポート送信

cd /var/git/rainpipe

echo "=========================================="
echo "Weekly Kindle Report Generator (Improved)"
echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="
echo ""

# 改善版スクリプトで週刊レポート生成＆送信
ruby weekly_kindle_send_improved.rb

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
