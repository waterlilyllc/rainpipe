# Rainpipeをローカルネットワークからアクセスする設定

## 現在の状況
- WSL内でSinatraサーバーが`0.0.0.0:4568`で稼働中
- WSLのIPアドレス: 172.25.88.93

## Windows側での設定（管理者権限のPowerShellで実行）

### 方法1: netshを使ったポートフォワーディング

```powershell
# 管理者権限でPowerShellを開いて実行

# 既存のルールを削除（存在する場合）
netsh interface portproxy delete v4tov4 listenport=4568 listenaddress=0.0.0.0

# WSLのIPアドレスを取得
wsl hostname -I
# 出力例: 172.25.88.93

# ポートフォワーディングを設定（WSLのIPアドレスを使用）
netsh interface portproxy add v4tov4 listenport=4568 listenaddress=0.0.0.0 connectport=4568 connectaddress=172.25.88.93

# 設定を確認
netsh interface portproxy show all

# Windowsファイアウォールで4568ポートを開放
New-NetFirewallRule -DisplayName "Rainpipe WSL" -Direction Inbound -Protocol TCP -LocalPort 4568 -Action Allow
```

### 方法2: WSL2の場合の簡易アクセス

WSL2の場合、以下のURLでアクセスできる場合があります：
- `http://localhost:4568`
- `http://127.0.0.1:4568`

## ローカルネットワークからのアクセス

設定完了後、以下のURLでアクセス可能：
- **同じPC（Windows）から**: http://localhost:4568
- **ローカルネットワークの他のデバイスから**: http://192.168.0.20:4568

## トラブルシューティング

### 1. アクセスできない場合

```powershell
# Windowsファイアウォールの確認
Get-NetFirewallRule -DisplayName "*Rainpipe*"

# ポートが開いているか確認
Test-NetConnection -ComputerName localhost -Port 4568
```

### 2. WSLのIPアドレスが変わった場合

WSLを再起動するとIPアドレスが変わることがあります。その場合は再度設定が必要です。

```powershell
# WSLの現在のIPを確認
wsl hostname -I

# ポートフォワーディングを更新
netsh interface portproxy delete v4tov4 listenport=4568 listenaddress=0.0.0.0
netsh interface portproxy add v4tov4 listenport=4568 listenaddress=0.0.0.0 connectport=4568 connectaddress=[新しいWSLのIP]
```

### 3. 自動化スクリプト

以下をバッチファイル（`start_rainpipe.bat`）として保存：

```batch
@echo off
echo Starting Rainpipe access setup...

REM Get WSL IP
for /f "tokens=1" %%i in ('wsl hostname -I') do set WSL_IP=%%i
echo WSL IP: %WSL_IP%

REM Remove existing rule
netsh interface portproxy delete v4tov4 listenport=4568 listenaddress=0.0.0.0 2>nul

REM Add new rule
netsh interface portproxy add v4tov4 listenport=4568 listenaddress=0.0.0.0 connectport=4568 connectaddress=%WSL_IP%

echo Port forwarding configured!
echo Access Rainpipe at: http://192.168.0.20:4568
pause
```

## サーバー側の確認

WSL内で以下を実行して、サーバーが正しく起動していることを確認：

```bash
# プロセス確認
ps aux | grep "ruby app.rb"

# ポート確認
netstat -tlnp | grep 4568

# サーバー再起動（必要な場合）
cd /var/git/rainpipe
lsof -ti:4568 | xargs kill -9 2>/dev/null
ruby app.rb -p 4568 &
```

## 注意事項

- Windows Defenderやアンチウイルスソフトがブロックしている可能性もあります
- 企業ネットワークの場合、ファイアウォールポリシーで制限されている可能性があります
- WSL1とWSL2で挙動が異なる場合があります（WSL2の方が簡単にアクセス可能）