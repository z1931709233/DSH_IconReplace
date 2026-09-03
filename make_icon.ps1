# ============================================================================
#  make_icon.ps1
#  功能：从一张图片生成多尺寸 Windows 图标 (.ico)，无需联网、无需额外工具
#        内置尺寸：16 / 24 / 32 / 48 / 64 / 128 / 256 px（全部 PNG 压缩 + 透明）
#
#  运行方式（在 PowerShell 或 CMD 中）：
#     powershell -ExecutionPolicy Bypass -File "make_icon.ps1"
#     powershell -ExecutionPolicy Bypass -File "make_icon.ps1" -Source "d:\logo.png" -Output "d:\logo.ico"
# ============================================================================
param(
    [string]$Source,
    [string]$Output
)

Add-Type -AssemblyName System.Drawing

# ---------- 界面提示 ----------
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  生成多尺寸 Windows 图标 (.ico)" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

Write-Host ""
Write-Host "【源图片要求】" -ForegroundColor Yellow
Write-Host "  1. 格式：PNG / JPG / BMP / GIF（PNG 带透明背景最佳）"
Write-Host "  2. 建议正方形 (1:1)。若不是正方形，程序会自动补透明边，不会裁切画面"
Write-Host "  3. 建议分辨率 >= 512x512（最低 256x256），太小放大会模糊"
Write-Host "  4. 图标主体尽量居中，四周留一点边距"
Write-Host "  5. 需要透明就用 PNG，不要用 JPG"

# ---------- 1. 取源图片路径 ----------
if ([string]::IsNullOrWhiteSpace($Source)) {
    Write-Host ""
    Write-Host "把源图片【直接拖到本窗口】再回车，或手动输入完整路径：" -ForegroundColor Green
    $Source = (Read-Host "源图片路径").Trim().Trim('"')
}
if (-not $Source -or -not [System.IO.File]::Exists($Source)) {
    Write-Host "错误：找不到源图片 -> $Source" -ForegroundColor Red
    exit 1
}

# ---------- 2. 读图 ----------
try {
    $loaded = [System.Drawing.Bitmap]::FromFile($Source)
    $img = New-Object System.Drawing.Bitmap $loaded   # 解除文件占用锁
    $loaded.Dispose()
} catch {
    Write-Host "错误：无法读取该图片（$($_.Exception.Message)）" -ForegroundColor Red
    exit 1
}
$srcW = $img.Width
$srcH = $img.Height
Write-Host ("已读取图片：{0} x {1}，格式 {2}" -f $srcW, $srcH, $img.PixelFormat) -ForegroundColor Green

# ---------- 3. 生成透明方形母版（等比缩放 + 补透明边，不裁切） ----------
$master = 512
if ($srcW -ge 1024 -and $srcH -ge 1024) { $master = 1024 }

$canvas = New-Object System.Drawing.Bitmap $master, $master, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear([System.Drawing.Color]::Transparent)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

$scale = [math]::Min($master / $srcW, $master / $srcH)
$dw = [int][math]::Round($srcW * $scale)
$dh = [int][math]::Round($srcH * $scale)
$dx = [int](($master - $dw) / 2)
$dy = [int](($master - $dh) / 2)
$g.DrawImage($img, $dx, $dy, $dw, $dh)
$g.Dispose()
$img.Dispose()
Write-Host ("已生成 {0} x {0} 透明方形母版" -f $master)

# ---------- 4. 各尺寸转 PNG 字节 ----------
$sizes = @(16, 24, 32, 48, 64, 128, 256)
$pngList = @()
foreach ($s in $sizes) {
    $b = New-Object System.Drawing.Bitmap $s, $s, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gg = [System.Drawing.Graphics]::FromImage($b)
    $gg.Clear([System.Drawing.Color]::Transparent)
    $gg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gg.DrawImage($canvas, 0, 0, $s, $s)
    $gg.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngList += , $ms.ToArray()
    $ms.Dispose()
    $b.Dispose()
}
$canvas.Dispose()

# ---------- 5. 组装 .ico 容器 ----------
if ([string]::IsNullOrWhiteSpace($Output)) {
    Write-Host ""
    $defaultOut = [System.IO.Path]::ChangeExtension($Source, '.ico')
    $out = Read-Host "输出 .ico 路径（直接回车用默认：$defaultOut）"
    if ([string]::IsNullOrWhiteSpace($out)) { $out = $defaultOut }
} else {
    $out = $Output
}
if (-not [System.IO.Path]::IsPathRooted($out)) { $out = [System.IO.Path]::GetFullPath($out) }
$outDir = [System.IO.Path]::GetDirectoryName($out)
if (-not [System.IO.Directory]::Exists($outDir)) { [System.IO.Directory]::CreateDirectory($outDir) | Out-Null }

$count = $sizes.Count
$ico = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $ico
$bw.Write([uint16]0)       # reserved
$bw.Write([uint16]1)       # type = icon
$bw.Write([uint16]$count)  # image count

$offset = 6 + 16 * $count
for ($i = 0; $i -lt $count; $i++) {
    $bytes = $pngList[$i]
    $s = $sizes[$i]
    $dim = if ($s -ge 256) { 0 } else { $s }  # 0 代表 256
    $bw.Write([byte]$dim)
    $bw.Write([byte]$dim)
    $bw.Write([byte]0)                 # color count
    $bw.Write([byte]0)                 # reserved
    $bw.Write([uint16]1)               # planes
    $bw.Write([uint16]32)              # bit count
    $bw.Write([uint32]$bytes.Length)   # 图像字节数
    $bw.Write([uint32]$offset)         # 数据偏移
    $offset += $bytes.Length
}
foreach ($bytes in $pngList) { $bw.Write($bytes) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($out, $ico.ToArray())
$bw.Dispose()
$ico.Dispose()

# ---------- 6. 校验结果 ----------
try {
    $ic = New-Object System.Drawing.Icon $out
    $ok = $true
    $ic.Dispose()
} catch { $ok = $false }

Write-Host ""
if ($ok) {
    Write-Host "成功！已生成 .ico：" -ForegroundColor Green
    Write-Host "  $out"
    Write-Host ("  内置尺寸：{0} px；文件大小：{1:N0} 字节" -f ($sizes -join ' / '), (Get-Item -LiteralPath $out).Length)
} else {
    Write-Host "写入完成但校验失败，请检查输出路径。" -ForegroundColor Red
    exit 1
}
Write-Host ""
Read-Host "按回车键退出"
