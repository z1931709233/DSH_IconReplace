# ============================================================================
#  replace_icon.ps1
#  功能：把 .ico 图标写进指定的 .exe（替换其图标资源），并清理 Windows 图标缓存
#  依赖：同目录下的 rcedit.exe（见使用文档"需要下载的工具"）
#
#  运行方式（在 PowerShell 或 CMD 中）：
#     powershell -ExecutionPolicy Bypass -File "replace_icon.ps1"
#     powershell -ExecutionPolicy Bypass -File "replace_icon.ps1" -TargetExe "D:\app.exe" -IconFile "D:\app.ico"
# ============================================================================
param(
    [string]$TargetExe,
    [string]$IconFile
)

# ---------- 0. 定位 rcedit ----------
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rcedit = Join-Path $ScriptDir 'rcedit.exe'
if (-not [System.IO.File]::Exists($rcedit)) {
    Write-Host ""
    Write-Host "缺少依赖：找不到 rcedit.exe" -ForegroundColor Red
    Write-Host "请下载 rcedit-x64.exe 并改名为 rcedit.exe，放到与本脚本相同的目录：" -ForegroundColor Yellow
    Write-Host "  下载地址：https://github.com/electron/rcedit/releases  （rcedit-x64.exe）" -ForegroundColor Yellow
    Read-Host "按回车退出"
    exit 1
}

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  替换 exe 图标 + 清理图标缓存" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# ---------- 1. 目标 exe ----------
if ([string]::IsNullOrWhiteSpace($TargetExe)) {
    Write-Host ""
    Write-Host "把要换图标的 .exe【拖到本窗口】再回车，或输入完整路径：" -ForegroundColor Green
    $TargetExe = (Read-Host "目标 exe 路径").Trim().Trim('"')
}
if (-not $TargetExe -or -not [System.IO.File]::Exists($TargetExe)) {
    Write-Host "错误：找不到 exe -> $TargetExe" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}

# ---------- 2. .ico ----------
if ([string]::IsNullOrWhiteSpace($IconFile)) {
    Write-Host ""
    $defaultIco = Join-Path $ScriptDir (([System.IO.Path]::GetFileNameWithoutExtension($TargetExe)) + '.ico')
    Write-Host "把 .ico 图标拖进来，或输入完整路径（回车用默认：$defaultIco）：" -ForegroundColor Green
    $in = (Read-Host ".ico 路径").Trim().Trim('"')
    if ([string]::IsNullOrWhiteSpace($in)) { $IconFile = $defaultIco } else { $IconFile = $in }
}
if (-not [System.IO.File]::Exists($IconFile)) {
    Write-Host "错误：找不到 .ico -> $IconFile" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}

# ---------- 3. 若 exe 正在运行则先退出 ----------
Write-Host ""
Write-Host "检查目标 exe 是否正在运行..." -ForegroundColor Yellow
$procs = Get-Process | Where-Object { $_.Path -eq $TargetExe }
if ($procs) {
    $ids = ($procs | Select-Object -ExpandProperty Id) -join ', '
    Write-Host ("检测到正在运行：PID {0}" -f $ids) -ForegroundColor Yellow
    $ans = Read-Host "需要先结束这些进程才能替换。输入 Y 结束进程继续，其它任意键退出"
    if ($ans -notmatch '^[Yy]$') {
        Write-Host "已取消。" -ForegroundColor Yellow
        exit 0
    }
    $procs | ForEach-Object { try { Stop-Process -Id $_.Id -Force } catch {} }
    Start-Sleep -Seconds 1
}

# ---------- 4. 执行替换 ----------
$exe = [System.IO.Path]::GetFullPath($TargetExe)
$ico = [System.IO.Path]::GetFullPath($IconFile)
Write-Host ""
Write-Host "正在替换图标资源..." -ForegroundColor Yellow
& $rcedit $exe --set-icon $ico
if ($LASTEXITCODE -ne 0) {
    Write-Host "替换失败：rcedit 返回错误码 $LASTEXITCODE" -ForegroundColor Red
    Read-Host "按回车退出"
    exit 1
}
Write-Host "替换成功（rcedit exit = 0）。" -ForegroundColor Green

# ---------- 5. 清理图标缓存 ----------
Write-Host ""
$ans2 = Read-Host "是否现在清理 Windows 图标缓存？（会短暂重启资源管理器/任务栏闪烁）输入 Y 继续，其它任意键跳过"
if ($ans2 -match '^[Yy]$') {
    Write-Host "正在清理图标缓存（explorer 会短暂重启）..." -ForegroundColor Yellow
    taskkill /f /im explorer.exe | Out-Null
    Start-Sleep -Milliseconds 800
    Remove-Item -LiteralPath "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\iconcache*" -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*" -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe
    Write-Host "缓存已清理，资源管理器已重启。" -ForegroundColor Green
    Write-Host "若桌面/任务栏仍显示旧图标，请重建对应快捷方式（删除后新建），或注销/重启一次。" -ForegroundColor Yellow
} else {
    Write-Host "已跳过清理。若之后图标没变，可运行使用文档中的缓存清理命令。" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "完成。目标：$exe" -ForegroundColor Green
Read-Host "按回车退出"
