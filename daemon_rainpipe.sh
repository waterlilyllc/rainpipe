#!/bin/bash

# Rainpipe デーモン管理スクリプト

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PID_FILE="$SCRIPT_DIR/rainpipe.pid"
LOG_FILE="$SCRIPT_DIR/logs/rainpipe_daemon.log"
ERROR_LOG="$SCRIPT_DIR/logs/rainpipe_daemon_error.log"

# ログディレクトリ作成
mkdir -p "$SCRIPT_DIR/logs"

# 環境変数を読み込む
export $(grep -v '^#' $SCRIPT_DIR/.env | xargs)

start_server() {
    echo "Starting Rainpipe server..."
    cd "$SCRIPT_DIR"
    nohup ruby app.rb -o 0.0.0.0 -p 4567 >> "$LOG_FILE" 2>> "$ERROR_LOG" &
    echo $! > "$PID_FILE"
    echo "Server started with PID: $(cat $PID_FILE)"
}

stop_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        echo "Stopping Rainpipe server (PID: $PID)..."
        kill $PID 2>/dev/null
        rm -f "$PID_FILE"
        echo "Server stopped."
    else
        echo "PID file not found. Trying to find process..."
        pkill -f "ruby app.rb"
        echo "All Ruby app.rb processes killed."
    fi
}

check_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p $PID > /dev/null; then
            echo "Server is running (PID: $PID)"
            return 0
        else
            echo "Server is not running (stale PID file)"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        echo "Server is not running (no PID file)"
        return 1
    fi
}

restart_server() {
    stop_server
    sleep 2
    start_server
}

monitor_server() {
    echo "Starting server monitor..."
    echo "Server will be automatically restarted if it crashes."
    echo "Press Ctrl+C to stop monitoring."
    
    while true; do
        if ! check_server > /dev/null; then
            echo "[$(date)] Server is down. Restarting..." | tee -a "$LOG_FILE"
            start_server
        fi
        sleep 30  # チェック間隔30秒
    done
}

case "$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        restart_server
        ;;
    status)
        check_server
        ;;
    monitor)
        # 最初にサーバーを起動
        if ! check_server > /dev/null; then
            start_server
        fi
        # モニタリング開始
        monitor_server
        ;;
    daemon)
        # バックグラウンドでモニタリング
        nohup bash "$0" monitor >> "$LOG_FILE" 2>&1 &
        echo "Daemon monitor started in background (PID: $!)"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|monitor|daemon}"
        echo "  start   - Start the server"
        echo "  stop    - Stop the server"
        echo "  restart - Restart the server"
        echo "  status  - Check server status"
        echo "  monitor - Monitor and auto-restart (foreground)"
        echo "  daemon  - Monitor and auto-restart (background)"
        exit 1
        ;;
esac