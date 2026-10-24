# =============================================================
#  清理项目里的可再生文件
#  用法：
#    powershell -File .\清理.ps1              只列出要删什么，不动手（默认）
#    powershell -File .\清理.ps1 -Force       真的删
#    powershell -File .\清理.ps1 -KeepZip 1   每个平台只留最新 1 个 zip（默认 1）
#
#  只删这三类，全部可以从 安装包/ + 脚本重新生成：
#    1. 买家版\ 和 买家版_macOS\        —— 打包中间产物，内容已在 zip 里
#    2. 买家版*_旧_*\                  —— 打包脚本自动归档的旧目录
#    3. 老 zip 和 _scratch\backups\stale_*\ —— 历史交付包
#
#  绝不碰：安装包\、脚本、文档、sources.json
# =============================================================

param(
    [switch]$Force,
    [int]$KeepZip = 1
)

$ErrorActionPreference = "Continue"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Say($m, $c) { if ($c) { Write-Host $m -ForegroundColor $c } else { Write-Host $m } }
function Get-SizeMB($p) {
    try {
        $b = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue |
              Measure-Object -Property Length -Sum).Sum
        if (-not $b) { return 0 }
        return [math]::Round($b / 1MB, 1)
    } catch { return 0 }
}

$totalBefore = (Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum / 1GB

Say ""
Say "==============================================================" Magenta
Say "  清理可再生文件" Magenta
Say "==============================================================" Magenta
Say ("  目录：" + $Root) Gray
if (-not $Force) { Say "  模式：演练（只列出，不删除；加 -Force 才真删）" Yellow }
Say ""

$targets = New-Object System.Collections.ArrayList

# ---------- 1. 打包中间目录 ----------
foreach ($d in @("买家版", "买家版_macOS")) {
    $p = Join-Path $Root $d
    if (Test-Path $p) {
        [void]$targets.Add([pscustomobject]@{ kind = "打包中间目录"; path = $p; mb = (Get-SizeMB $p) })
    }
}

# ---------- 2. 自动归档的旧目录 ----------
foreach ($d in @(Get-ChildItem $Root -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match "^买家版(_macOS)?_旧_\d{8}_\d{6}$" })) {
    [void]$targets.Add([pscustomobject]@{ kind = "旧归档目录"; path = $d.FullName; mb = (Get-SizeMB $d.FullName) })
}

# ---------- 3. 老 zip：每个平台只留最新 KeepZip 个 ----------
# 按「文件名里的时间戳」判断新旧，不能用 LastWriteTime：
# 文件被复制/解压过之后修改时间会变，按它排序会删错（我实测踩过这个坑）
$zipGroups = @{}
foreach ($z in @(Get-ChildItem $Root -Filter "AI桌面下载中心_*.zip" -File -ErrorAction SilentlyContinue)) {
    $plat = "其他"
    if ($z.Name -match "_全平台") { $plat = "全平台" }
    elseif ($z.Name -match "_Windows版") { $plat = "Windows" }
    elseif ($z.Name -match "_macOS版") { $plat = "macOS" }

    $stamp = [datetime]::MinValue
    if ($z.Name -match "_(\d{8})_(\d{6})\.zip$") {
        try { $stamp = [datetime]::ParseExact($Matches[1] + $Matches[2], "yyyyMMddHHmmss", $null) } catch { }
    }

    if (-not $zipGroups.ContainsKey($plat)) { $zipGroups[$plat] = New-Object System.Collections.ArrayList }
    [void]$zipGroups[$plat].Add([pscustomobject]@{ file = $z; stamp = $stamp })
}

# 每个平台至少留 1 个，防止 -KeepZip 0 把所有包删光
$keepN = $KeepZip
if ($keepN -lt 1) { $keepN = 1 }

foreach ($plat in $zipGroups.Keys) {
    $sorted = @($zipGroups[$plat] | Sort-Object -Property stamp -Descending)
    $i = 0
    foreach ($item in $sorted) {
        $i++
        if ($i -le $keepN) { continue }
        [void]$targets.Add([pscustomobject]@{
            kind = "旧 zip（每平台保留最新 " + $keepN + " 个）"
            path = $item.file.FullName
            mb   = [math]::Round($item.file.Length / 1MB, 1)
        })
    }
}

# ---------- 4. 历史备份区 ----------
$backupRoot = Join-Path $Root "_scratch\backups"
if (Test-Path $backupRoot) {
    foreach ($d in @(Get-ChildItem $backupRoot -Directory -ErrorAction SilentlyContinue |
                     Where-Object { $_.Name -like "stale_*" })) {
        [void]$targets.Add([pscustomobject]@{ kind = "历史备份"; path = $d.FullName; mb = (Get-SizeMB $d.FullName) })
    }
}

# ---------- 输出清单 ----------
if ($targets.Count -eq 0) {
    Say "  没有需要清理的东西，当前已经是干净的。" Green
    Say ""
    exit 0
}

$sumMB = 0
foreach ($t in $targets) {
    $name = Split-Path -Leaf $t.path
    Say ("  [" + $t.kind + "]") DarkGray
    Say ("    " + $name + "   " + $t.mb + " MB") White
    $sumMB += $t.mb
}
Say ""
Say ("  合计可释放：" + [math]::Round($sumMB / 1024, 2) + " GB（" + $targets.Count + " 项）") Cyan
Say ""

if (-not $Force) {
    Say "  确认无误后执行：powershell -File .\清理.ps1 -Force" Yellow
    Say ""
    exit 0
}

# ---------- 执行删除 ----------
# 安全闸：任何目标路径都不允许落在 安装包\ 里
$pkgPath = (Join-Path $Root "安装包").ToLower()
$blocked = @()
foreach ($t in $targets) {
    if ($t.path.ToLower().StartsWith($pkgPath)) { $blocked += $t.path }
}
if ($blocked.Count -gt 0) {
    Say "  中止：有目标落在 安装包\ 里，这不该发生" Red
    foreach ($b in $blocked) { Say ("    " + $b) Red }
    exit 1
}

$done = 0
foreach ($t in $targets) {
    try {
        Remove-Item -LiteralPath $t.path -Recurse -Force -ErrorAction Stop
        $done++
    } catch {
        Say ("  删除失败：" + $t.path + " —— " + $_.Exception.Message) Red
    }
}

$totalAfter = (Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue |
               Measure-Object -Property Length -Sum).Sum / 1GB
Say ("  已删除 " + $done + " / " + $targets.Count + " 项") Green
Say ("  当前项目占用：" + [math]::Round($totalAfter, 2) + " GB") White
Say ""
Say "  下一步要重新生成交付包：.\打包.ps1 -Force" Gray
Say ""
