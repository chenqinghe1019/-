# 启动带 CDP 调试端口的 Chrome，并将 viewport 设为 1920x1080
# 用法：
#   .\ta_start_cdp.ps1              → 启动 Chrome + 设 viewport，打印就绪提示
#   .\ta_start_cdp.ps1 -Navigate    → 同上，并自动导航到数数后台登录页
#   .\ta_start_cdp.ps1 -Check       → 仅检查 CDP 是否在线，不启动 Chrome

param(
    [switch]$Navigate,
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

$CdpUrl     = 'http://127.0.0.1:9222'
$ChromeExe  = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$UserData   = "$env:TEMP\chrome-cdp-debug"
$TaUrl      = 'https://ta-data.feiyu.com'

function Test-Cdp {
    try {
        $targets = Invoke-RestMethod -Uri "$CdpUrl/json/list" -TimeoutSec 3
        return $targets
    } catch {
        return $null
    }
}

function Set-Viewport1920 {
    param([string]$WsUrl)
    $socket = [System.Net.WebSockets.ClientWebSocket]::new()
    $socket.ConnectAsync([Uri]$WsUrl, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $payload = '{"id":1,"method":"Emulation.setDeviceMetricsOverride","params":{"width":1920,"height":1080,"deviceScaleFactor":1,"mobile":false}}'
    $bytes   = [Text.Encoding]::UTF8.GetBytes($payload)
    $socket.SendAsync([ArraySegment[byte]]::new($bytes), [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $buf = New-Object byte[] 4096; $sb = [Text.StringBuilder]::new()
    do {
        $r = $socket.ReceiveAsync([ArraySegment[byte]]::new($buf), [Threading.CancellationToken]::None).GetAwaiter().GetResult()
        [void]$sb.Append([Text.Encoding]::UTF8.GetString($buf, 0, $r.Count))
    } while (-not $r.EndOfMessage)
    $socket.Dispose()
    return $sb.ToString()
}

# --- 仅检查 ---
if ($Check) {
    $targets = Test-Cdp
    if ($targets) {
        Write-Output "CDP 在线，共 $($targets.Count) 个 target"
        $ta = $targets | Where-Object { $_.url -like '*ta-data*' } | Select-Object -First 1
        if ($ta) { Write-Output "数数 tab: $($ta.url)" }
        else      { Write-Output "未找到数数 tab，请手动导航到 $TaUrl" }
    } else {
        Write-Output "CDP 未在线，请运行 .\ta_start_cdp.ps1 启动"
    }
    return
}

# --- 检查 CDP 是否已在线 ---
$targets = Test-Cdp
if (-not $targets) {
    Write-Output "启动 Chrome（调试端口 9222）..."
    Start-Process $ChromeExe "--remote-debugging-port=9222 --user-data-dir=`"$UserData`" --no-first-run --no-default-browser-check"
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 500
        $targets = Test-Cdp
        if ($targets) { break }
    }
    if (-not $targets) {
        throw "Chrome 启动超时，CDP 无法连接：$CdpUrl"
    }
    Write-Output "Chrome 已启动"
} else {
    Write-Output "Chrome CDP 已在线（$($targets.Count) 个 target），跳过启动"
}

# --- 设置 viewport 1920x1080 ---
$target = $targets | Select-Object -First 1
Set-Viewport1920 -WsUrl $target.webSocketDebuggerUrl | Out-Null
Write-Output "Viewport 已设为 1920x1080"

# --- 可选：导航到数数 ---
if ($Navigate) {
    $scriptPath = Join-Path $PSScriptRoot '..\..\..\ta_cdp_tool.ps1'
    if (-not (Test-Path $scriptPath)) {
        $scriptPath = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) 'ta_cdp_tool.ps1'
    }
    if (Test-Path $scriptPath) {
        Write-Output "导航到 $TaUrl ..."
        & $scriptPath -Action navigate -Url $TaUrl | Out-Null
        Write-Output "请在 Chrome 窗口中完成登录，登录完成后继续操作。"
    } else {
        Write-Output "未找到 ta_cdp_tool.ps1，请手动导航到 $TaUrl"
    }
}

Write-Output ""
Write-Output "就绪。后续用 ta_cdp_tool.ps1 操作数数后台即可。"
Write-Output "  截图：.\ta_cdp_tool.ps1 -Action screenshot -Out screenshots\snap.png"
Write-Output "  执行脚本：.\ta_cdp_tool.ps1 -Action eval -ExpressionFile your_script.js"
