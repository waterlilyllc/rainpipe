#!/bin/bash

# ログディレクトリ
LOG_DIR="/var/git/rainpipe/logs"
mkdir -p "$LOG_DIR"

# 日付
DATE=$(date +%Y%m%d)
LOG_FILE="$LOG_DIR/weekly_interest_update_${DATE}.log"

# 環境変数を読み込む
export $(grep -v '^#' /var/git/rainpipe/.env | xargs)

echo "========================================" >> "$LOG_FILE"
echo "週次関心ワード更新開始: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# 過去1週間のブックマークから関心ワードを抽出
echo "📚 過去1週間のブックマークから関心ワードを抽出中..." >> "$LOG_FILE"
cd /var/git/rainpipe && /usr/bin/ruby -e "
require_relative 'extract_interests_from_bookmarks'
extractor = InterestExtractor.new
# 過去7日間のブックマークから抽出
extractor.extract_from_recent_bookmarks(days: 7)
" >> "$LOG_FILE" 2>&1

# 抽出結果を確認
if [ $? -eq 0 ]; then
    echo "✅ 関心ワードの更新が完了しました: $(date)" >> "$LOG_FILE"
    
    # 新しい関心ワードがあれば、推奨キーワードリストを更新
    echo "🔄 推奨キーワードリストを更新中..." >> "$LOG_FILE"
    cd /var/git/rainpipe && /usr/bin/ruby -e "
require 'json'
require_relative 'interest_manager'

manager = InterestManager.new
latest = manager.get_latest_analysis

if latest
  interests = latest.dig('analysis', 'core_interests') || []
  emerging = latest.dig('analysis', 'emerging_interests') || []
  
  puts \"\\n📊 今週の関心ワード:\"
  interests.first(5).each do |i|
    puts \"- #{i['keyword']} (重要度: #{i['importance']})\"
  end
  
  if emerging.any?
    puts \"\\n🌱 新しい興味:\"
    emerging.each do |e|
      puts \"- #{e['keyword']}\"
    end
  end
end
" >> "$LOG_FILE" 2>&1
    
else
    echo "❌ 関心ワードの更新でエラーが発生しました: $(date)" >> "$LOG_FILE"
fi

echo "" >> "$LOG_FILE"

# 週次サマリーを自動生成
echo "========================================" >> "$LOG_FILE"
echo "週次サマリー生成開始: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# 今週の月曜日を計算
MONDAY=$(date -d "last monday" +%Y-%m-%d)
if [ $(date +%u) -eq 1 ]; then
    # 今日が月曜日の場合は先週のサマリーを生成
    MONDAY=$(date -d "last monday - 7 days" +%Y-%m-%d)
fi

echo "対象週: $MONDAY" >> "$LOG_FILE"

cd /var/git/rainpipe && /usr/bin/ruby -e "
require_relative 'weekly_summary_generator'
generator = WeeklySummaryGenerator.new
summary = generator.generate_weekly_summary('$MONDAY')
if summary
  puts '✅ 週次サマリーを生成しました'
else
  puts '❌ 週次サマリー生成に失敗しました'
end
" >> "$LOG_FILE" 2>&1

echo "" >> "$LOG_FILE"

# 古いログファイルを削除（30日以上）
find "$LOG_DIR" -name "weekly_interest_update_*.log" -mtime +30 -delete