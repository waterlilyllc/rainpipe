#!/bin/bash

# 関心ワード抽出バッチスクリプト

# スクリプトのディレクトリに移動
cd /var/git/rainpipe

# ログディレクトリ作成
LOG_DIR="./logs/interest_extraction"
mkdir -p "$LOG_DIR"

# タイムスタンプ
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/extraction_${TIMESTAMP}.log"

echo "=== 関心ワード抽出開始 ===" | tee -a "$LOG_FILE"
echo "実行時刻: $(date)" | tee -a "$LOG_FILE"

# 環境変数の読み込み
if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
    echo "✅ 環境変数を読み込みました" | tee -a "$LOG_FILE"
else
    echo "❌ .envファイルが見つかりません" | tee -a "$LOG_FILE"
    exit 1
fi

# OpenAI APIキーの確認
if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OPENAI_API_KEYが設定されていません" | tee -a "$LOG_FILE"
    exit 1
fi

# Rubyスクリプトの実行
echo "" | tee -a "$LOG_FILE"
echo "📚 ブックマーク分析を開始します..." | tee -a "$LOG_FILE"

ruby extract_interests_from_bookmarks.rb 2>&1 | tee -a "$LOG_FILE"

# 実行結果の確認
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "" | tee -a "$LOG_FILE"
    echo "✅ 関心ワード抽出が正常に完了しました" | tee -a "$LOG_FILE"
    
    # 最新の分析結果を表示
    LATEST_FILE="./data/interests/latest_analysis.json"
    if [ -f "$LATEST_FILE" ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "📄 最新の分析結果: $LATEST_FILE" | tee -a "$LOG_FILE"
        echo "キーワード数: $(jq '.analysis.core_interests | length' "$LATEST_FILE")" | tee -a "$LOG_FILE"
    fi
else
    echo "" | tee -a "$LOG_FILE"
    echo "❌ エラーが発生しました" | tee -a "$LOG_FILE"
    exit 1
fi

echo "" | tee -a "$LOG_FILE"
echo "=== 処理完了 ===" | tee -a "$LOG_FILE"
echo "ログファイル: $LOG_FILE"