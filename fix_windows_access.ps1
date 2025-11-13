# PowerShellスクリプト（Windows側で管理者権限で実行）

# WSLのIPアドレスを取得
$wslIp = wsl hostname -I | ForEach-Object { $_.Trim().Split(' ')[0] }
Write-Host "WSL IP Address: $wslIp"

# 既存のポートプロキシルールを削除
netsh interface portproxy delete v4tov4 listenport=4568 listenaddress=* 2>$null

# 新しいポートプロキシルールを追加
netsh interface portproxy add v4tov4 listenport=4568 listenaddress=0.0.0.0 connectport=4568 connectaddress=$wslIp
netsh interface portproxy add v4tov4 listenport=4568 listenaddress=192.168.0.20 connectport=4568 connectaddress=$wslIp

# ファイアウォールルールを追加（既にある場合はスキップ）
New-NetFirewallRule -DisplayName "Rainpipe WSL Port 4568" -Direction Inbound -Protocol TCP -LocalPort 4568 -Action Allow -ErrorAction SilentlyContinue

# 設定を表示
Write-Host "`n現在のポートプロキシ設定:"
netsh interface portproxy show v4tov4

Write-Host "`n以下のURLでアクセスできます:"
Write-Host "- http://localhost:4568"
Write-Host "- http://192.168.0.20:4568"
Write-Host "- http://${wslIp}:4568 (WSL直接)"