#!/bin/bash

# 自動復旧スクリプト - cronで5分ごとに実行

LOG_FILE="/var/git/rainpipe/logs/auto_restart.log"
PID_FILE="/var/git/rainpipe/rainpipe.pid"
PORT=4567

# ログディレクトリ作成
mkdir -p /var/git/rainpipe/logs

# 現在時刻
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# サーバーの状態をチェック
check_server() {
    # ポートが開いているか確認
    if netstat -tlnp 2>/dev/null | grep -q ":$PORT"; then
        return 0
    fi

    # curlでレスポンスを確認
    if curl -s -f -m 5 http://localhost:$PORT > /dev/null 2>&1; then
        return 0
    fi

    return 1
}

# サーバーを起動
start_server() {
    echo "[$TIMESTAMP] サーバーが停止しています。再起動します..." >> "$LOG_FILE"

    # 古いプロセスを念のため殺す
    pkill -f "ruby.*app.rb.*4568" 2>/dev/null
    sleep 2

    # サーバーを起動
    cd /var/git/rainpipe
    nohup ruby app.rb -p $PORT >> /var/git/rainpipe/logs/server.log 2>&1 &
    NEW_PID=$!
    echo $NEW_PID > "$PID_FILE"

    echo "[$TIMESTAMP] サーバーを起動しました (PID: $NEW_PID)" >> "$LOG_FILE"

    # 起動確認
    sleep 5
    if check_server; then
        echo "[$TIMESTAMP] ✅ サーバーが正常に起動しました" >> "$LOG_FILE"
    else
        echo "[$TIMESTAMP] ❌ サーバーの起動に失敗しました" >> "$LOG_FILE"
    fi
}

# メイン処理
if check_server; then
    # サーバーは正常に動作中（ログは出力しない - ログが膨大になるのを防ぐ）
    exit 0
else
    # サーバーが停止している
    start_server
fi