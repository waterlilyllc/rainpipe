# Rainpipeサーバーへのアクセス方法

## WSL環境からのアクセス

サーバーはWSL内で動作しています。正しいアクセスURLは:

**http://172.25.88.93:4567/**

## Windows（ホスト）からのアクセス

### 方法1: localhostを使用（推奨）
Windowsからは以下のURLでアクセスできます:
- http://localhost:4567/

### 方法2: WSL IPアドレスを使用
1. WSLのIPアドレスを確認:
   ```powershell
   wsl hostname -I
   ```

2. 表示されたIPアドレス（例: 172.25.88.93）を使用:
   - http://172.25.88.93:4567/

## 外部ネットワークからのアクセス

外部からアクセスする場合は、Windowsでポートフォワーディング設定が必要です:

### PowerShell（管理者権限）で実行:
```powershell
# ポートフォワーディングを追加
netsh interface portproxy add v4tov4 listenport=4567 listenaddress=0.0.0.0 connectport=4567 connectaddress=172.25.88.93

# Windows Defenderファイアウォールでポートを開く
New-NetFirewallRule -DisplayName "Rainpipe Server" -Direction Inbound -LocalPort 4567 -Protocol TCP -Action Allow
```

### 設定確認:
```powershell
netsh interface portproxy show all
```

### 設定削除（必要な場合）:
```powershell
netsh interface portproxy delete v4tov4 listenport=4567 listenaddress=0.0.0.0
```

## サーバー状態の確認

サーバーが正常に動作しているか確認:
```bash
curl http://172.25.88.93:4567/
```

## 自動再起動

サーバーは5分ごとに自動チェックされ、停止している場合は自動的に再起動されます。

手動でサーバーを再起動する場合:
```bash
/var/git/rainpipe/auto_restart_check.sh
```