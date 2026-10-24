# =============================================================
#  生成买家版（给卖家自己用，不随包发给买家）
#  用法：
#    powershell -File .\打包.ps1                 只做 Windows 版（约 2.8 GB）
#    powershell -File .\打包.ps1 -Mac            全平台版，Win+mac 混在一个包（约 6.1 GB）
#    powershell -File .\打包.ps1 -MacOnly        只做 macOS 版，给 Mac 客户（约 3.2 GB）
#    powershell -File .\打包.ps1 -Slim           精简：每个架构只带默认格式，省 700 MB 左右
#    powershell -File .\打包.ps1 -NoZip          只生成目录，不压缩
#
#  为什么拆成三种：Windows 客户用不到 3.2 GB 的 dmg，Mac 客户也用不到
#  2.5 GB 的 exe；而且不少网盘单文件限制 4 GB，混在一起反而发不出去。
#
#  作用：只复制买家需要的文件到 买家版\，并按需压成 ZIP。
#        不会清理卖家的日志、下载缓存或离线包。
# =============================================================

param(
    [switch]$NoZip,
    [switch]$Force,
    [switch]$Mac,
    [switch]$MacOnly,
    [switch]$Slim
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$CfgPath = Join-Path $Root "sources.json"

# ---------- 平台模式 ----------
# win = 只 Windows；mac = 只 macOS（独立交付）；all = 两者混装
$Mode = if ($MacOnly) { "mac" } elseif ($Mac) { "all" } else { "win" }
if ($Mac -and $MacOnly) { throw "-Mac 和 -MacOnly 不能同时用。要全平台用 -Mac，只要 macOS 用 -MacOnly。" }

$BuyerDirName = if ($Mode -eq "mac") { "买家版_macOS" } else { "买家版" }
$BuyerDir     = Join-Path $Root $BuyerDirName
$PlatLabel    = switch ($Mode) { "mac" { "macOS 版" } "all" { "全平台版" } default { "Windows 版" } }
$PlatTag      = switch ($Mode) { "mac" { "_macOS版" } "all" { "_全平台" } default { "_Windows版" } }

# ---------- 买家需要的文件（白名单） ----------
$BuyerFiles = @(
    "打开资源中心.bat",
    "资源中心.html",
    "资源中心服务.ps1",
    "双击启动.bat",
    "双击检测.bat",
    "launcher.ps1",
    "check-pc.ps1",
    "sources.json",
    "使用说明.txt",
    "软件推荐与官方下载地址.txt"
)

# ---------- 卖家专用，绝不能进包 ----------
$SellerOnly = @(
    "维护说明.md",
    "下载地址总表.md",
    "官方下载地址.txt",
    "gen-dirs.ps1",
    "打包.ps1",
    "补全安装包.ps1",
    "日志.txt",
    "下载日志.txt",
    "本机检测报告.txt",
    "下载",
    "dist",
    "买家版",
    "买家版_macOS"
)

function Say($m, $c) {
    if ($c) { Write-Host $m -ForegroundColor $c } else { Write-Host $m }
}

# 中英混排对齐（一个汉字占两格，否则说明文件里的表格会歪）
function Get-DisplayWidth($s) {
    $w = 0
    foreach ($ch in ([string]$s).ToCharArray()) {
        $c = [int]$ch
        if (($c -ge 0x1100 -and $c -le 0x115F) -or
            ($c -ge 0x2E80 -and $c -le 0xA4CF) -or
            ($c -ge 0xAC00 -and $c -le 0xD7A3) -or
            ($c -ge 0xF900 -and $c -le 0xFAFF) -or
            ($c -ge 0xFE30 -and $c -le 0xFE6F) -or
            ($c -ge 0xFF00 -and $c -le 0xFF60) -or
            ($c -ge 0xFFE0 -and $c -le 0xFFE6)) { $w += 2 } else { $w += 1 }
    }
    return $w
}
function Pad-Right($s, $width) {
    $s = [string]$s
    $w = Get-DisplayWidth $s
    if ($w -ge $width) { return $s }
    return $s + (" " * ($width - $w))
}

# 能进买家包的安装程序后缀（zip/7z = 免安装压缩包，也是真实产物）
$PackExt = @(".exe", ".msi", ".zip", ".7z", ".dmg")

# ---------- 读配置 ----------
if (-not (Test-Path $CfgPath)) { throw "找不到 sources.json" }
$cfg = [System.IO.File]::ReadAllText($CfgPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

# ---------- 精简模式：算出「每个应用每个架构的默认格式文件」 ----------
$FormatRank = @{ "msi" = 1; "dmg" = 1; "setup" = 2; "store" = 3; "portable" = 4; "zip" = 5 }
function Get-Rank($f) {
    if ($f -and $FormatRank.ContainsKey([string]$f)) { return $FormatRank[[string]$f] }
    return 9
}
$DefaultFiles = @{}
foreach ($a in @($cfg.apps)) {
    foreach ($key in @("variants", "mac")) {
        $list = @($a.$key)
        if ($list.Count -eq 0) { continue }
        foreach ($g in @($list | Group-Object -Property arch)) {
            $ranked = @($g.Group | Sort-Object -Property @{ Expression = { Get-Rank $_.format } })
            $win = $ranked[0]
            if ($win -and $win.file) { $DefaultFiles[[string]$win.file] = $true }
        }
    }
}

Write-Host ""
Say "==============================================================" Magenta
Say ("  生成买家版 · " + $PlatLabel) Magenta
Say "==============================================================" Magenta
if ($Slim) { Say "  模式：精简（每个架构只带默认格式）" Yellow }
Write-Host ""

# ---------- 1. 检查买家文件 ----------
if ($Mode -eq "mac") {
    Say "[1/4] macOS 包不需要 Windows 启动器，跳过文件检查" DarkGray
} else {
    Say "[1/4] 检查买家版文件" Cyan
    $missing = @()
    foreach ($f in $BuyerFiles) {
        if (Test-Path (Join-Path $Root $f)) {
            Say ("      OK  " + $f) Green
        } else {
            Say ("      XX  缺少 " + $f) Red
            $missing += $f
        }
    }
    if ($missing.Count -gt 0) {
        throw ("无法生成买家版，缺少：" + ($missing -join "、"))
    }
}

# ---------- 2. 准备买家目录 ----------
Say ""
Say ("[2/4] 准备 " + $BuyerDirName + "/") Cyan
if (Test-Path $BuyerDir) {
    if ($Force) {
        # 自动归档旧交付物，不覆盖、不删除
        $archive = $Root + "\" + $BuyerDirName + "_旧_" + (Get-Date -Format "yyyyMMdd_HHmmss")
        Rename-Item -Path $BuyerDir -NewName (Split-Path -Leaf $archive)
        Say ("      旧目录已归档为 " + (Split-Path -Leaf $archive)) Yellow
    } else {
        throw ($BuyerDirName + " 已存在；为避免覆盖现有交付物，本次未修改它。加 -Force 可自动归档旧目录后重新生成。")
    }
}
New-Item -ItemType Directory -Path $BuyerDir -Force | Out-Null
Say ("      已新建 " + $BuyerDirName) Green

# ---------- 3. 复制文件 ----------
Say ""
Say "[3/4] 复制内容" Cyan
if ($Mode -ne "mac") {
    foreach ($f in $BuyerFiles) {
        Copy-Item (Join-Path $Root $f) -Destination $BuyerDir -Force
        Say ("      + " + $f) Green
    }
}

$pkgRoot = Join-Path $Root "安装包"
$destPkg = Join-Path $BuyerDir "安装包"
$copied  = New-Object System.Collections.ArrayList
$skippedSlim = 0

if (Test-Path $pkgRoot) {
    foreach ($f in @(Get-ChildItem -Path $pkgRoot -Recurse -File -ErrorAction SilentlyContinue)) {
        if ($f.Length -le 200KB) { continue }
        if ($f.Extension.ToLowerInvariant() -notin $PackExt) { continue }

        $isMacFile = ($f.FullName -match "\\mac\\")
        # 平台过滤
        if ($Mode -eq "win" -and $isMacFile) { continue }
        if ($Mode -eq "mac" -and -not $isMacFile) { continue }
        # 精简过滤
        if ($Slim -and -not $DefaultFiles.ContainsKey($f.Name)) { $skippedSlim++; continue }

        # 相对路径：macOS 专用包把 dmg 摊平到 安装包/<App>/，Mac 用户不用再点进 mac 子目录
        if ($Mode -eq "mac") {
            $appDir = Split-Path -Parent (Split-Path -Parent $f.FullName)
            $appName = Split-Path -Leaf $appDir
            $target = Join-Path (Join-Path $destPkg $appName) $f.Name
        } else {
            $rel = $f.FullName.Substring($pkgRoot.Length).TrimStart("\")
            $target = Join-Path $destPkg $rel
        }

        $targetDir = Split-Path -Parent $target
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        Copy-Item $f.FullName -Destination $target -Force
        [void]$copied.Add($target)
    }
}

$installerCount = $copied.Count
if ($installerCount -gt 0) {
    $mb = [math]::Round((($copied | ForEach-Object { (Get-Item $_).Length }) | Measure-Object -Sum).Sum / 1MB, 1)
    Say ("      + 安装包/  " + $installerCount + " 个安装程序，" + $mb + " MB") Green
    if ($skippedSlim -gt 0) { Say ("      - 精简模式跳过了 " + $skippedSlim + " 个非默认格式") Yellow }
} else {
    Say "      本次为联网下载版：没有可复制的安装包" Yellow
}

# 平台兜底：说带了就必须真带
if ($Mode -eq "mac" -or $Mode -eq "all") {
    $dmgCount = @(Get-ChildItem -Path $destPkg -Recurse -File -Filter *.dmg -ErrorAction SilentlyContinue).Count
    if ($dmgCount -eq 0) {
        throw "本次要带 macOS 包，但一个 .dmg 都没复制到。先确认 安装包\<应用>\mac\ 里已有 dmg（可用 补全安装包.ps1 -Mac 下载）。"
    }
    Say ("      + macOS 包 实际 " + $dmgCount + " 个 dmg") Green
}
if ($Mode -eq "win") {
    $dmgCount = @(Get-ChildItem -Path $destPkg -Recurse -File -Filter *.dmg -ErrorAction SilentlyContinue).Count
    if ($dmgCount -gt 0) { throw "Windows 版里混进了 dmg，说明平台过滤有 bug，已中止。" }
}

# ---------- macOS 专用说明 ----------
if ($Mode -eq "mac") {
    $L = New-Object System.Collections.ArrayList
    [void]$L.Add("========================================")
    [void]$L.Add("  AI 桌面下载中心 · macOS 版")
    [void]$L.Add("========================================")
    [void]$L.Add("")
    [void]$L.Add("这是给 Mac 用的安装包集合，共 " + $installerCount + " 个 dmg。")
    [void]$L.Add("")
    [void]$L.Add("【先看芯片】")
    [void]$L.Add("")
    [void]$L.Add("  左上角苹果菜单 -> 关于本机 -> 看「芯片」那一行：")
    [void]$L.Add("    Apple M1 / M2 / M3 / M4  ->  选 arm64 或 aarch64 结尾的文件")
    [void]$L.Add("    Intel Core i5 / i7 / i9  ->  选 x64 或 x86_64 结尾的文件")
    [void]$L.Add("    写着 universal            ->  两种芯片都能用")
    [void]$L.Add("")
    [void]$L.Add("  文件名里没有芯片标记的（如 ChatGPT.dmg、CC-Switch-*-macOS.dmg），")
    [void]$L.Add("  表示只有一个版本，直接装即可。")
    [void]$L.Add("")
    [void]$L.Add("【怎么装】")
    [void]$L.Add("")
    [void]$L.Add("  1. 双击 dmg，会弹出一个窗口")
    [void]$L.Add("  2. 把里面的 App 图标拖到 Applications（应用程序）文件夹")
    [void]$L.Add("  3. 在「启动台」或「应用程序」里打开它")
    [void]$L.Add("  4. 装完可以把 dmg 拖到废纸篓，不影响已装好的程序")
    [void]$L.Add("")
    [void]$L.Add("【首次打开被拦下来】")
    [void]$L.Add("")
    [void]$L.Add("  提示「无法打开，因为无法验证开发者」时：")
    [void]$L.Add("    打开「系统设置」->「隐私与安全性」-> 往下拉到「安全性」")
    [void]$L.Add("    -> 点「仍要打开」，再回应用程序里双击一次。")
    [void]$L.Add("")
    [void]$L.Add("  如果提示「已损坏，应移到废纸篓」，多半是文件没下完整，")
    [void]$L.Add("  用同目录的「校验清单.txt」核对一下 SHA256。")
    [void]$L.Add("")
    [void]$L.Add("【各应用的包】")
    [void]$L.Add("")
    foreach ($a in @($cfg.apps)) {
        $ms = @($a.mac)
        if ($ms.Count -eq 0) { continue }
        [void]$L.Add("  " + $a.name)
        foreach ($m in $ms) {
            $archNote = switch ([string]$m.arch) {
                "arm64" { "Apple 芯片" }
                "x64"   { "Intel 芯片" }
                "any"   { "通用" }
                default { [string]$m.arch }
            }
            [void]$L.Add("    " + (Pad-Right $m.file 52) + "  " + $archNote + "  " + $m.size)
        }
        [void]$L.Add("")
    }
    [void]$L.Add("【注意】")
    [void]$L.Add("")
    [void]$L.Add("  这里的 dmg 是各软件官方发布包，没有做任何修改。")
    [void]$L.Add("  安装前请确认来自官方渠道。")
    [void]$L.Add("")
    $macReadme = Join-Path $BuyerDir "使用说明_macOS.txt"
    ($L -join "`r`n") | Set-Content -Path $macReadme -Encoding UTF8
    Say ("      + 使用说明_macOS.txt") Green
}

# ---------- 校验清单（SHA256） ----------
# 买家从网盘下载、或卖家替换了某个包之后，可以核对文件是否完好。
if ($copied.Count -gt 0) {
    Say ""
    Say "      正在计算 SHA256（大包需要一两分钟）..." DarkGray
    $man = New-Object System.Collections.ArrayList
    [void]$man.Add("# AI 桌面下载中心 校验清单")
    [void]$man.Add("# 生成时间：" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
    [void]$man.Add("# 格式：<SHA256>  <相对路径>")
    [void]$man.Add("# 核对方法：powershell -File .\launcher.ps1 -Verify")
    [void]$man.Add("")
    foreach ($p in $copied) {
        $rel = $p.Substring($BuyerDir.Length).TrimStart("\")
        $h = (Get-FileHash $p -Algorithm SHA256).Hash.ToLowerInvariant()
        [void]$man.Add($h + "  " + $rel)
    }
    ($man -join "`r`n") | Set-Content -Path (Join-Path $BuyerDir "校验清单.txt") -Encoding UTF8
    Say ("      + 校验清单.txt（" + $copied.Count + " 个文件的 SHA256）") Green
}

# ---------- 4. 交付检查 ----------
Say ""
Say "[4/4] 检查买家版内容" Cyan
$leak = @()
foreach ($s in $SellerOnly) {
    if (Test-Path (Join-Path $BuyerDir $s)) { $leak += $s }
}

$buyerFiles = @(Get-ChildItem -Path $BuyerDir -Recurse -File)
foreach ($f in $buyerFiles) {
    if ($f.Extension -in @(".md", ".txt", ".ps1", ".bat", ".json") -and $f.Length -lt 1MB) {
        $txt = [System.IO.File]::ReadAllText($f.FullName, [System.Text.Encoding]::UTF8)
        if ($txt -match "维护说明|报价|客单价|发给买家|不要随包发|价格|定价|货源|策略|元\s*/\s*份") {
            $leak += $f.FullName.Replace($BuyerDir, "").TrimStart("\")
        }
    }
}
if ($leak.Count -gt 0) {
    throw ("买家版发现卖家内容：" + (($leak | Sort-Object -Unique) -join "、"))
}

$version = $cfg.version
$totalMB = [math]::Round((($buyerFiles | Measure-Object -Property Length -Sum).Sum) / 1MB, 2)
Say ("      通过：" + $buyerFiles.Count + " 个文件，" + $totalMB + " MB") Green

if (-not $NoZip) {
    # 文件名带平台标签和精简标记：三种包体积差一倍，名字不区分会发错货
    $slimTag = if ($Slim) { "_精简" } else { "" }
    $baseName = "AI桌面下载中心_买家版_v" + $version + $PlatTag + $slimTag + "_" + (Get-Date -Format "yyyyMMdd_HHmmss")
    $zipName = $baseName + ".zip"
    $zipPath = Join-Path $Root $zipName
    $n = 2
    while (Test-Path $zipPath) {
        $zipName = $baseName + "_" + $n + ".zip"
        $zipPath = Join-Path $Root $zipName
        $n++
    }

    Say ""
    Say "正在压缩买家版..." Cyan
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($BuyerDir, $zipPath)
    $zipMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Say ("      完成：" + $zipName + "  (" + $zipMB + " MB)") Green
    Say ("      位置：" + $zipPath) Gray
}

Write-Host ""
Say "--------------------------------------------------------------" DarkGray
Say ("  买家版内容（" + $PlatLabel + "）：") White
Get-ChildItem $BuyerDir | ForEach-Object {
    $tag = if ($_.PSIsContainer) { "[目录]" } else { "      " }
    Say ("    " + $tag + " " + $_.Name) Gray
}
Write-Host ""
if ($Mode -eq "mac") {
    Say "  这是纯 macOS 包，里面没有 Windows 启动器，Mac 客户解压后看「使用说明_macOS.txt」。" Yellow
} elseif ($Mode -eq "all") {
    Say "  这是全平台混合包（约 6 GB）。只发给单一平台的客户时，建议改用 -MacOnly 或默认的 Windows 版。" Yellow
} else {
    Say "  这是 Windows 版。要给 Mac 客户，用 .\打包.ps1 -MacOnly 单独生成一个包。" Yellow
}
if ($Slim) { Say "  精简模式：每个架构只带默认格式，客户想要别的格式可以再用启动器联网下载。" Yellow }
Write-Host ""
