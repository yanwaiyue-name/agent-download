# =============================================================
#  AI 客户端与命令行工具 安装器  v4.0
#  用法：双击「双击启动.bat」，或在 PowerShell 里跑本文件
#  维护：编辑 sources.json 即可增删应用与下载源
#  说明：启动时自动检测本机架构（x64 / ARM64 / x86），
#        自动挑选对应架构的安装包；同一软件有多种格式
#        （安装版 / MSI / 免安装 / 压缩包 / 商店版）时会让用户选。
# =============================================================

param(
    [switch]$Check,
    [switch]$All,
    [switch]$Verify,
    # 只用 GitHub 官方直链，不走第三方加速站。
    # 加速站能解决国内下不动的问题，但它站在你和官方之间，属于额外的信任面；
    # 需要干净链路（公司电脑、审计环境）时加这个开关。
    [switch]$NoMirror
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$PkgDir  = Join-Path $Root "安装包"
$DlDir   = Join-Path $Root "下载"
$LogFile = Join-Path $Root "日志.txt"

foreach ($d in @($PkgDir, $DlDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# ---------- 输出 ----------
function Say-Step($m) { Write-Host "" ; Write-Host "[>] $m" -ForegroundColor Cyan }
function Say-Ok($m)   { Write-Host "    OK  $m" -ForegroundColor Green }
function Say-Note($m) { Write-Host "    ..  $m" -ForegroundColor Yellow }
function Say-Bad($m)  { Write-Host "    XX  $m" -ForegroundColor Red }
function Write-Log($m) {
    try {
        $line = (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $m
        Add-Content -Path $LogFile -Value $line -Encoding UTF8
    } catch { }
}

# ---------- 格式优先级 ----------
# 数字越小越优先。安装器默认选最小的那个：MSI 最省事，其次是 setup，免安装/压缩包最后。
$FormatRank = @{ "msi" = 1; "setup" = 2; "store" = 3; "portable" = 4; "zip" = 5 }
function Get-FormatRank($f) {
    if ($f -and $FormatRank.ContainsKey([string]$f)) { return $FormatRank[[string]$f] }
    return 9
}
function Get-FormatLabel($f) {
    switch ([string]$f) {
        "setup"    { return "安装版" }
        "msi"      { return "MSI" }
        "store"    { return "商店版" }
        "portable" { return "免安装" }
        "zip"      { return "压缩包" }
        ""         { return "默认" }
        default    { return [string]$f }
    }
}
# 这些后缀不能当安装程序直接跑，要特殊处理
function Test-Installable($v) {
    $f = [string]$v.format
    if ($f -eq "sums" -or $f -eq "dmg" -or $f -eq "pkg") { return $false }
    return $true
}

# ---------- 本机架构检测 ----------
function Get-OsArch {
    # 主判据：Win32_ComputerSystem.SystemType（ARM 机器上跑 x86 进程也不会误判）
    try {
        $st = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).SystemType
        if ($st -match "ARM64") { return "arm64" }
        if ($st -match "x64")   { return "x64" }
        if ($st -match "x86")   { return "x86" }
    } catch { }
    # 次判据：.NET RuntimeInformation
    try {
        $a = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        if ($a -eq "Arm64") { return "arm64" }
        if ($a -eq "X64")   { return "x64" }
        if ($a -eq "X86")   { return "x86" }
    } catch { }
    # 兜底：环境变量
    $p = $env:PROCESSOR_ARCHITEW6432
    if (-not $p) { $p = $env:PROCESSOR_ARCHITECTURE }
    switch ($p.ToUpper()) {
        "AMD64" { return "x64" }
        "ARM64" { return "arm64" }
        "X86"   { return "x86" }
    }
    return "unknown"
}

# ---------- 读取配置 ----------
$jsonPath = Join-Path $Root "sources.json"
if (-not (Test-Path $jsonPath)) {
    Write-Host "找不到 sources.json，请确认整个文件夹是完整拷贝的。" -ForegroundColor Red
    exit 1
}
try {
    $raw = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8)
    $cfg = $raw | ConvertFrom-Json
} catch {
    Write-Host ("sources.json 解析失败：" + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
$Apps   = @($cfg.apps)
$OsArch = Get-OsArch

# ---------- 分组展示顺序 ----------
# 显示序号按「分组首次出现顺序」连续编号。选择逻辑也必须用同一份有序列表，
# 否则一旦在 JSON 中间插入一个不同分组的应用，序号就会错位（选 3 号装出别的软件）。
$Groups  = @($Apps | ForEach-Object { $_.group } | Select-Object -Unique)
$Ordered = New-Object System.Collections.ArrayList
foreach ($g in $Groups) {
    foreach ($a in @($Apps | Where-Object { $_.group -eq $g })) { [void]$Ordered.Add($a) }
}

# 确保每个应用的子目录都在（客户误删了也能自动重建）
foreach ($a in $Apps) {
    $sub = $a.dir
    if (-not $sub) { continue }
    foreach ($scanRoot in @($PkgDir, $DlDir)) {
        $d = Join-Path $scanRoot $sub
        if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
}

# ---------- 按架构选包（同一架构可能有多套格式） ----------
function Get-Variants($app, $arch) {
    $vs = @($app.variants)
    $selectionArch = $arch
    $unknownArch = $false
    if ($arch -eq "unknown") {
        $selectionArch = "x64"
        $unknownArch = $true
    }

    # 兼容 v1 结构（没有 variants，只有 file/urls）
    if ($vs.Count -eq 0) {
        if ($app.file) {
            return @(@{ file = $app.file; urls = $app.urls; assetPattern = $app.assetPattern; arch = "x64"; format = "setup"; mode = "native"; size = ""; sha256 = $app.sha256 })
        }
        return @()
    }

    $matched = New-Object System.Collections.ArrayList
    $mode = if ($unknownArch) { "assumed" } else { "native" }

    # 1) 精确匹配本机架构
    foreach ($v in $vs) {
        if ($v.arch -eq $selectionArch -and (Test-Installable $v)) {
            [void]$matched.Add(@{ file = $v.file; urls = $v.urls; assetPattern = $v.assetPattern; arch = $v.arch; format = $v.format; mode = $mode; size = $v.size; sha256 = $v.sha256 })
        }
    }
    # 2) ARM64 机器可以跑 x64（系统模拟层）
    if ($matched.Count -eq 0 -and $selectionArch -eq "arm64") {
        foreach ($v in $vs) {
            if ($v.arch -eq "x64" -and (Test-Installable $v)) {
                [void]$matched.Add(@{ file = $v.file; urls = $v.urls; assetPattern = $v.assetPattern; arch = $v.arch; format = $v.format; mode = "emulated"; size = $v.size; sha256 = $v.sha256 })
            }
        }
    }
    # 3) x64 / x86 跑不了 arm64 包
    if ($matched.Count -eq 0) { return @() }

    # 按格式优先级排序（稳定排序：同优先级保持 JSON 顺序）
    $sorted = @($matched | Sort-Object -Property @{ Expression = { Get-FormatRank $_.format } })
    return $sorted
}

# ---------- 本地文件索引 ----------
# 老实现：每找一个包就 Get-ChildItem -Recurse 扫一遍，缺包时 40 个 variant
# 会触发几十次全盘递归（客户把安装包放在移动硬盘/网盘映射盘上时非常慢）。
# 现在启动时扫一次，之后全部走内存查表。
$script:FileIndex = $null
function Build-FileIndex {
    $byName = @{}
    $byExt  = @{}
    foreach ($scanRoot in @($PkgDir, $DlDir)) {
        if (-not (Test-Path $scanRoot)) { continue }
        foreach ($f in @(Get-ChildItem -Path $scanRoot -Recurse -File -ErrorAction SilentlyContinue)) {
            if ($f.Length -le 200KB) { continue }
            if (-not $byName.ContainsKey($f.Name)) { $byName[$f.Name] = $f.FullName }
            $ext = $f.Extension.ToLowerInvariant()
            if (-not $byExt.ContainsKey($ext)) { $byExt[$ext] = New-Object System.Collections.ArrayList }
            [void]$byExt[$ext].Add($f)
        }
    }
    return @{ byName = $byName; byExt = $byExt }
}
function Get-FileIndex {
    if ($null -eq $script:FileIndex) { $script:FileIndex = Build-FileIndex }
    return $script:FileIndex
}

# ---------- 查找本地已有安装包 ----------
function Get-LocalInstaller($app, $variant) {
    if (-not $variant -or -not $variant.file) { return $null }

    # 1) 应用专属子目录里的精确文件名（最常见的情况，直接 Test-Path，不扫盘）
    $sub = $app.dir
    if ($sub) {
        foreach ($scanRoot in @($PkgDir, $DlDir)) {
            $p = Join-Path (Join-Path $scanRoot $sub) $variant.file
            if ((Test-Path $p) -and ((Get-Item $p).Length -gt 200KB)) { return $p }
        }
    }

    $ix = Get-FileIndex

    # 2) 索引里的同名文件（客户自己建了别的子文件夹也能找到）
    if ($ix.byName.ContainsKey($variant.file)) { return $ix.byName[$variant.file] }

    # 3) 模糊匹配同扩展名文件，兼容安装包实际发布名与配置目标名不同
    $extension = [System.IO.Path]::GetExtension($variant.file).ToLowerInvariant()
    if (-not $extension) { return $null }
    if (-not $ix.byExt.ContainsKey($extension)) { return $null }
    $key = ($app.id -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()
    foreach ($f in $ix.byExt[$extension]) {
        $normalizedName = ($f.BaseName -replace "[^a-zA-Z0-9]", "").ToLowerInvariant()
        if ($normalizedName.Contains($key)) { return $f.FullName }
    }
    return $null
}

# ---------- GitHub 加速镜像（来自 sources.json 顶层 mirrors，空串 = 直连）----------
# 镜像站会死：改 sources.json 即可，不用动脚本
$script:Mirrors = @("https://gh-proxy.com/", "https://ghfast.top/", "", "https://gh.llkk.cc/")
if ($cfg.mirrors) { $script:Mirrors = @($cfg.mirrors) }

# ---------- GitHub 最新 release 资产解析 ----------
function Resolve-GitHubAsset($repo, $pattern) {
    if (-not $repo) { return $null }
    # API 请求按镜像前缀逐个试（直连兜底放最后）
    $apis = @()
    foreach ($m in $script:Mirrors) {
        if ($m) { $apis += ($m + "https://api.github.com/repos/" + $repo + "/releases/latest") }
    }
    $apis += ("https://api.github.com/repos/" + $repo + "/releases/latest")
    foreach ($api in $apis) {
        try {
            $r = Invoke-RestMethod -Uri $api -TimeoutSec 20 -Headers @{ "User-Agent" = "agent-installer" }
            if ($r.assets) {
                if ($pattern) {
                    foreach ($a in $r.assets) {
                        if ($a.name -match $pattern) { return $a.browser_download_url }
                    }
                }
            }
        } catch { }
    }
    return $null
}

# ---------- 本地安装包查找缓存 ----------
# Show-Table 每轮刷新都会查一遍本地文件，加了缓存避免大目录反复全递归扫盘
$LocalCache = @{}
function Get-LocalCached($app, $variant) {
    $key = $app.id + "|" + $variant.arch + "|" + $variant.file
    if ($LocalCache.ContainsKey($key)) { return $LocalCache[$key] }
    $p = Get-LocalInstaller $app $variant
    $LocalCache[$key] = $p
    return $p
}

# ---------- 校验清单（SHA256） ----------
# 打包时生成的 校验清单.txt，格式：<SHA256>  <相对路径>
# 用途：从网盘/QQ 传过来的包可能被截断，装到一半才报错；先校验能提前发现。
function Get-Manifest {
    $p = Join-Path $Root "校验清单.txt"
    if (-not (Test-Path $p)) { return $null }
    $map = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($p, [System.Text.Encoding]::UTF8)) {
        if (-not $line -or $line.TrimStart().StartsWith("#")) { continue }
        if ($line -match "^([0-9a-fA-F]{64})\s{1,2}(.+)$") {
            $map[$Matches[2].Trim()] = $Matches[1].ToLowerInvariant()
        }
    }
    return $map
}

function Invoke-Verify {
    Write-Host ""
    Write-Host "  校验本地安装包完整性" -ForegroundColor Cyan
    Write-Host ("  清单：" + (Join-Path $Root "校验清单.txt")) -ForegroundColor DarkGray

    $man = Get-Manifest
    if ($null -eq $man) {
        Write-Host "  这个包里没有 校验清单.txt，跳过校验。" -ForegroundColor Yellow
        Write-Host "  （联网下载版本来就没有清单，只有离线包才带）" -ForegroundColor DarkGray
        return
    }
    if ($man.Count -eq 0) {
        Write-Host "  校验清单是空的，跳过。" -ForegroundColor Yellow
        return
    }

    Write-Host ("  清单共 " + $man.Count + " 个文件，开始核对（大包需要一两分钟）...") -ForegroundColor Gray
    Write-Host ""

    $okCount = 0
    $missList = New-Object System.Collections.ArrayList
    $badList  = New-Object System.Collections.ArrayList
    $idx = 0

    foreach ($rel in ($man.Keys | Sort-Object)) {
        $idx++
        $want = $man[$rel]
        $full = Join-Path $Root $rel
        Write-Host ("    [" + $idx + "/" + $man.Count + "] " + $rel) -ForegroundColor DarkGray -NoNewline

        if (-not (Test-Path $full)) {
            Write-Host "  缺失" -ForegroundColor Yellow
            [void]$missList.Add($rel)
            continue
        }
        try {
            $got = (Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant()
        } catch {
            Write-Host "  读不了" -ForegroundColor Red
            [void]$badList.Add($rel)
            continue
        }
        if ($got -eq $want) {
            Write-Host "  OK" -ForegroundColor Green
            $okCount++
        } else {
            Write-Host "  哈希不符" -ForegroundColor Red
            [void]$badList.Add($rel)
        }
    }

    Write-Host ""
    Write-Host "  ----------------------------------------------" -ForegroundColor DarkGray
    Write-Host ("  完好 " + $okCount + " 个    缺失 " + $missList.Count + " 个    损坏 " + $badList.Count + " 个") -ForegroundColor White

    if ($badList.Count -gt 0) {
        Write-Host ""
        Write-Host "  以下文件内容不对，装之前必须重新获取：" -ForegroundColor Red
        foreach ($b in $badList) { Write-Host ("    · " + $b) -ForegroundColor Red }
        Write-Host "  常见原因：下载被截断、网盘同步没完成、被安全软件改过。" -ForegroundColor Yellow
    }
    if ($missList.Count -gt 0) {
        Write-Host ""
        Write-Host "  以下文件不在本地（不影响已就绪的软件，只是少了可选格式）：" -ForegroundColor Yellow
        foreach ($m in $missList) { Write-Host ("    · " + $m) -ForegroundColor DarkGray }
    }
    if ($badList.Count -eq 0 -and $missList.Count -eq 0) {
        Write-Host ""
        Write-Host "  全部文件校验通过，可以放心安装。" -ForegroundColor Green
    }
    Write-Log ("VERIFY  ok=" + $okCount + " missing=" + $missList.Count + " bad=" + $badList.Count)
    Write-Host ""
}

# ---------- 下载 ----------
function Test-InstallerMagic($path) {
    # 用文件头识别加速站故障时返回的 HTML 错误页
    # （那种页面往往也有几百 KB，只靠大小判断会误判为下载成功）
    # exe = MZ；msi = OLE 复合文档 D0CF11E0（不是 MZ，这点很多人会搞错）；
    # zip = PK；7z = 37 7A BC AF 27 1C
    try {
        $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
        if ($ext -notin @(".exe", ".msi", ".zip", ".7z")) { return $true }
        $fs = [System.IO.File]::OpenRead($path)
        try {
            if ($ext -eq ".7z") {
                $b6 = New-Object byte[] 6
                if ($fs.Read($b6, 0, 6) -lt 6) { return $false }
                return (($b6[0] -eq 0x37) -and ($b6[1] -eq 0x7A) -and ($b6[2] -eq 0xBC) -and
                        ($b6[3] -eq 0xAF) -and ($b6[4] -eq 0x27) -and ($b6[5] -eq 0x1C))
            }
            $buf = New-Object byte[] 2
            if ($fs.Read($buf, 0, 2) -lt 2) { return $false }
            if ($ext -eq ".zip") { return (($buf[0] -eq 0x50) -and ($buf[1] -eq 0x4B)) }
            if ($ext -eq ".msi") { return ((($buf[0] -eq 0xD0) -and ($buf[1] -eq 0xCF)) -or (($buf[0] -eq 0x4D) -and ($buf[1] -eq 0x5A))) }
            return (($buf[0] -eq 0x4D) -and ($buf[1] -eq 0x5A))
        } finally { $fs.Close() }
    } catch { return $false }
}

function Save-FromUrl($url, $dest) {
    # 1) 优先 BITS：自带进度条，大文件体验好（不可用时自动回退）
    try {
        Start-BitsTransfer -Source $url -Destination $dest -ErrorAction Stop
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 200KB) -and (Test-InstallerMagic $dest)) {
            return $true
        }
        if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    } catch { }

    # 2) 回退 Invoke-WebRequest
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 900 -ErrorAction Stop
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 200KB) -and (Test-InstallerMagic $dest)) { return $true }
        if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
        return $false
    } catch {
        if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
        return $false
    }
}

function Get-Installer($app, $variant, [switch]$Batch) {
    Say-Step ("准备 " + $app.name + "（" + (Get-FormatLabel $variant.format) + " · " + $variant.arch + "）")
    if ($variant.mode -eq "emulated") {
        Say-Note ("本机是 ARM64，该应用没有原生 ARM 版，将使用 x64 版（系统模拟运行）")
    } elseif ($variant.mode -eq "assumed") {
        Say-Note "本机架构检测失败，当前按 x64 版本处理；安装前请确认系统不是 32 位"
    }

    # 1) 本地已有
    $local = Get-LocalCached $app $variant
    if ($local) {
        Say-Ok ("已找到本地安装包：" + $local)
        return $local
    }

    # 2) 组装候选地址
    $cands = New-Object System.Collections.ArrayList
    if ($app.github) {
        $gh = Resolve-GitHubAsset $app.github $variant.assetPattern
        # API 解析出的资产名和本地目标名不一致时不用它：否则新版内容会被存成
        # 旧版文件名（如 v4.0.19 存成 v4.0.18），日志和校验清单里的名字会骗人。
        # 此时退回 variant.urls 的钉死直链，保证文件名和内容版本一致。
        if ($gh -and $gh -match ("/" + [regex]::Escape($variant.file) + "(?:[?#]|$)")) { [void]$cands.Add($gh) }
    }
    foreach ($u in @($variant.urls)) {
        if ($u) { [void]$cands.Add($u) }
    }

    if ($cands.Count -eq 0) {
        Say-Bad "没有可用的下载直链"
        Say-Note ("官方页面：" + $app.page)
        if ($app.tip) { Say-Note ("提示：" + $app.tip) }
        return $null
    }

    # 3) 逐个尝试（GitHub 链接自动加加速前缀）
    # 加速站优先、直连兜底（与 补全安装包.ps1 的顺序保持一致）：
    # 国内直连 GitHub 基本不通，把直连放第一只会让买家白等一轮超时
    $mirrors = $script:Mirrors

    # 下载到该应用自己的子目录，不跟别的应用混在一起
    $destDir = $DlDir
    if ($app.dir) { $destDir = Join-Path $DlDir $app.dir }
    if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    $dest = Join-Path $destDir $variant.file

    Say-Note "开始下载，大文件（100MB 以上）可能要几分钟，请勿关闭窗口"

    # 期望哈希：sources.json 里维护的官方 SHA256。
    # 有它就必须对上，对不上直接删文件 —— 否则镜像站被投毒或上游文件被替换时，
    # 我们只是把哈希打印到屏幕上，等于没有校验。
    $expect = ""
    if ($variant.sha256) { $expect = ([string]$variant.sha256).ToLowerInvariant() }

    foreach ($c in $cands) {
        $isGitHub = ($c -match "github\.com|githubusercontent\.com")
        foreach ($m in $mirrors) {
            if ($m -ne "" -and -not $isGitHub) { continue }
            if ($m -ne "" -and $NoMirror) { continue }
            $url = if ($m) { $m + $c } else { $c }
            $host_ = ""
            try { $host_ = ([System.Uri]$url).Host } catch { $host_ = "?" }
            $viaMirror = ($m -ne "")
            Say-Note ("尝试 " + $host_ + $(if ($viaMirror) { " （第三方加速站，下载后会校验官方哈希）" } else { "" }) + " ...")
            if (Save-FromUrl $url $dest) {
                $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
                $hash = (Get-FileHash $dest -Algorithm SHA256).Hash.ToLowerInvariant()
                if ($expect) {
                    if ($hash -ne $expect) {
                        Say-Bad ("哈希不符，已丢弃这个文件：" + $host_)
                        Say-Note ("  期望 " + $expect)
                        Say-Note ("  实得 " + $hash)
                        Say-Note "  可能是加速站返回了错误内容，或上游文件已更新（那就该跑 scripts/update-hashes.ps1）。换下一个源重试。"
                        Write-Log ("HASH MISMATCH  " + $app.id + "  " + $url + "  expect=" + $expect + "  got=" + $hash)
                        try { Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue } catch { }
                        continue
                    }
                    Say-Ok ("哈希校验通过（与 sources.json 记录一致）")
                } else {
                    Say-Note "  该条目还没有记录官方哈希，本次只显示不校验（维护者跑 scripts/update-hashes.ps1 可补上）"
                }
                Say-Ok ("下载完成 " + $mb + " MB -> " + $dest)
                Say-Note ("SHA256 " + $hash)
                Write-Log ("DOWNLOAD OK  " + $app.id + "  " + $variant.arch + "  " + $variant.format + "  " + $url + "  " + $hash)
                $LocalCache[($app.id + "|" + $variant.arch + "|" + $variant.file)] = $dest
                # 新文件落盘了，索引要作废，否则同一轮里后续查找看不到它
                $script:FileIndex = $null
                return $dest
            }
        }
    }

    Say-Bad "所有下载源都失败了"
    Say-Note ("官方页面：" + $app.page)
    if ($app.dir) { Say-Note ("离线包可以放到：安装包/" + $app.dir + "/") }
    if ($app.needProxy) { Say-Note "该应用需要代理才能访问官方服务器" }
    if ($app.tip) { Say-Note ("提示：" + $app.tip) }
    Write-Log ("DOWNLOAD FAIL  " + $app.id + "  " + $variant.arch + "  " + $variant.format)

    if ($Batch) {
        Say-Note "批量模式：跳过「打开官网」询问，稍后可手动访问下面的官方页面"
        return $null
    }

    $open = Read-Host "    要现在打开官方下载页吗？(y/N)"
    if ($open -match "^[yY]") { Start-Process $app.page }
    return $null
}

# ---------- 批量下载（-All 参数与交互里的 A 共用，避免两处逻辑不同步） ----------
function Invoke-DownloadAll {
    foreach ($a in $Apps) {
        $picks = @(Get-Variants $a $OsArch)
        if ($picks.Count -eq 0) { continue }
        $p = Get-Installer $a $picks[0] -Batch
        if ($p) { Say-Ok ("就绪：" + $p) }
    }
}

# ---------- 安装 / 打开 ----------
function Expand-ZipPack($zipPath) {
    $ext  = [System.IO.Path]::GetExtension($zipPath).ToLowerInvariant()
    $dest = Join-Path (Split-Path -Parent $zipPath) ([System.IO.Path]::GetFileNameWithoutExtension($zipPath))
    try {
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }

        # .7z 不能用 Expand-Archive（它只认 zip），只能调 7-Zip。
        # 买手机器上不一定装了 7-Zip，所以必须有明确的替代路径，不能只报个错。
        if ($ext -eq ".7z") {
            $sevenZip = $null
            foreach ($p in @(
                (Join-Path $env:ProgramFiles "7-Zip\7z.exe"),
                (Join-Path ${env:ProgramFiles(x86)} "7-Zip\7z.exe"))) {
                if ($p -and (Test-Path $p)) { $sevenZip = $p; break }
            }
            if (-not $sevenZip) {
                Say-Bad "这是 .7z 压缩包，本机没装 7-Zip，无法自动解压"
                Say-Note "两个办法，任选其一："
                Say-Note "  1) 装 7-Zip —— 本包「开发环境」分组里就有（7-Zip 25.01），装完再回来解压"
                Say-Note "     也可以去官网下：https://www.7-zip.org/"
                Say-Note "  2) 别用这个免安装版，改用同目录下的安装版（文件名以 _win_x64.exe 结尾），双击就能装"
                Say-Note ("压缩包已保存在：" + $zipPath)
                return $null
            }
            $out = & $sevenZip x $zipPath ("-o" + $dest) -y 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw ("7-Zip 退出码 " + $LASTEXITCODE + "：" + (($out | Select-Object -First 3) -join " "))
            }
            return $dest
        }

        Expand-Archive -Path $zipPath -DestinationPath $dest -Force -ErrorAction Stop
        return $dest
    } catch {
        Say-Bad ("解压失败：" + $_.Exception.Message)
        return $null
    }
}

function Start-Installer($app, $path, $variant) {
    if (-not $path) { return }
    $extension = [System.IO.Path]::GetExtension($path).ToLowerInvariant()

    # 压缩包：解压后打开文件夹，不假装能"安装"
    if ($extension -eq ".zip" -or $extension -eq ".7z") {
        $kind = if ($extension -eq ".7z") { "7z 免安装压缩包" } else { "免安装压缩包" }
        $ans = Read-Host ("    这是" + $kind + "，现在解压吗？(Y/n)")
        if ($ans -match "^[nN]") {
            Say-Note ("压缩包已保存在：" + $path)
            return
        }
        $dir = Expand-ZipPack $path
        if ($dir) {
            Say-Ok ("已解压到：" + $dir)
            Say-Note "打开文件夹后双击里面的 exe 就能用，不用安装"
            Start-Process explorer.exe -ArgumentList ('"{0}"' -f $dir)
            Write-Log ("UNZIP  " + $app.id + "  " + $path + "  ->  " + $dir)
        }
        return
    }

    $ans = Read-Host "    现在安装吗？(Y/n)"
    if ($ans -match "^[nN]") {
        Say-Note "安装包已保存在：" + $path
        return
    }
    if ($variant -and $variant.format -eq "portable") {
        Say-Note "这是免安装版，直接运行程序本体，不会写进「程序和功能」"
    }
    if ($variant -and $variant.format -eq "store") {
        Say-Note "这是微软商店引导器，双击后会联网从商店拉完整应用，请保持联网"
    }
    Say-Note "正在启动安装程序，请按提示下一步..."
    try {
        if ($extension -eq ".msi") {
            Start-Process -FilePath "msiexec.exe" -ArgumentList ('/i "{0}"' -f $path)
        } else {
            Start-Process -FilePath $path
        }
        Write-Log ("INSTALL LAUNCH  " + $app.id + "  " + $path)
        Say-Ok "安装程序已启动（如果弹出权限确认请点「是」）"
    } catch {
        Say-Bad ("启动失败：" + $_.Exception.Message)
        Say-Note "可以手动双击：" + $path
    }
}

# ---------- 中文对齐辅助 ----------
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
function Pad-Display($s, $width) {
    $s = [string]$s
    $w = Get-DisplayWidth $s
    if ($w -ge $width) { return $s }
    return $s + (" " * ($width - $w))
}

# ---------- 列表 ----------
function Show-Table {
    Write-Host ""
    $i = 1
    foreach ($group in $Groups) {
        Write-Host ("  " + ("=" * 82)) -ForegroundColor DarkCyan
        Write-Host ("  " + $group) -ForegroundColor Cyan
        Write-Host ("  " + ("=" * 82)) -ForegroundColor DarkCyan
        Write-Host ("  " + (Pad-Display "序号" 5) + (Pad-Display "应用" 26) + (Pad-Display "架构" 7) + (Pad-Display "格式" 14) + (Pad-Display "大小" 10) + (Pad-Display "状态" 11) + "用途") -ForegroundColor White

        foreach ($a in @($Ordered | Where-Object { $_.group -eq $group })) {
            $picks = @(Get-Variants $a $OsArch)
            $vArch = "-"
            $vSize = "-"
            $vFmt  = "-"
            if ($picks.Count -gt 0) {
                $primary = $picks[0]
                $vArch = $primary.arch
                if ($primary.mode -eq "emulated") { $vArch = $primary.arch + "*" }
                elseif ($primary.mode -eq "assumed") { $vArch = $primary.arch + "?" }
                if ($primary.size) { $vSize = $primary.size }
                $vFmt = Get-FormatLabel $primary.format
                if ($picks.Count -gt 1) { $vFmt = $vFmt + "+" + ($picks.Count - 1) }
            }

            $ready = 0
            if ($picks.Count -gt 0) {
                foreach ($p in $picks) { if (Get-LocalCached $a $p) { $ready++ } }
            }

            if ($picks.Count -eq 0) {
                # install 字段优先：web / npm / pip 是「官方就该这样装」，不是缺文件
                if ($a.install -eq "npm")     { $st = "npm 安装" }
                elseif ($a.install -eq "pip") { $st = "pip 安装" }
                elseif ($a.install -eq "web") { $st = "官网下载" }
                elseif (@($a.variants).Count -eq 0 -and -not $a.file) { $st = "无桌面版" }
                else { $st = "装不了" }
            } elseif ($ready -gt 0) {
                $st = "已就绪"
            } else {
                $st = "需下载"
            }

            $color = "White"
            if ($st -eq "已就绪") { $color = "Green" }
            elseif ($st -eq "需下载") { $color = "Yellow" }
            elseif ($st -eq "装不了") { $color = "Red" }
            elseif ($st -eq "无桌面版") { $color = "DarkGray" }

            $purpose = $a.desc
            if ($a.recommend) { $purpose = "[推荐] " + $purpose }
            $line = "  " + (Pad-Display $i 5) + (Pad-Display $a.name 26) + (Pad-Display $vArch 7) + (Pad-Display $vFmt 14) + (Pad-Display $vSize 10) + (Pad-Display $st 11) + $purpose
            Write-Host $line -ForegroundColor $color
            if ($a.audience) { Write-Host ("      · " + $a.audience) -ForegroundColor DarkGray }
            $i++
        }
        Write-Host ""
    }

    # 图例
    Write-Host "  状态说明：" -ForegroundColor DarkGray -NoNewline
    Write-Host " 已就绪" -ForegroundColor Green -NoNewline
    Write-Host " = 本地已有安装包，直接装    " -ForegroundColor DarkGray -NoNewline
    Write-Host "需下载" -ForegroundColor Yellow -NoNewline
    Write-Host " = 联网下载" -ForegroundColor DarkGray
    Write-Host "           " -ForegroundColor DarkGray -NoNewline
    Write-Host "装不了" -ForegroundColor Red -NoNewline
    Write-Host " = 本机没有可用版本    " -ForegroundColor DarkGray -NoNewline
    Write-Host "无桌面版" -ForegroundColor DarkGray -NoNewline
    Write-Host " = 只有命令行" -ForegroundColor DarkGray
    Write-Host "  格式说明：" -ForegroundColor DarkGray -NoNewline
    Write-Host "安装版" -ForegroundColor White -NoNewline
    Write-Host " = 双击装到系统里    " -ForegroundColor DarkGray -NoNewline
    Write-Host "MSI" -ForegroundColor White -NoNewline
    Write-Host " = 系统安装包    " -ForegroundColor DarkGray -NoNewline
    Write-Host "免安装" -ForegroundColor White -NoNewline
    Write-Host " = 单文件绿色版" -ForegroundColor DarkGray
    Write-Host "           " -ForegroundColor DarkGray -NoNewline
    Write-Host "压缩包" -ForegroundColor White -NoNewline
    Write-Host " = 解压即用    " -ForegroundColor DarkGray -NoNewline
    Write-Host "商店版" -ForegroundColor White -NoNewline
    Write-Host " = 微软商店引导器（需联网）    " -ForegroundColor DarkGray -NoNewline
    Write-Host "格式+N" -ForegroundColor White -NoNewline
    Write-Host " = 还有 N 种格式可选" -ForegroundColor DarkGray

    if ($OsArch -eq "arm64") {
        Write-Host "  架构带 * 号 = 该应用没有 ARM 原生版，用 x64 版模拟运行（能用，稍慢）" -ForegroundColor DarkGray
    } elseif ($OsArch -eq "unknown") {
        Write-Host "  架构带 ? 号 = 检测失败后暂按 x64 建议，请安装前人工确认系统位数" -ForegroundColor DarkGray
    }
}

# ---------- 架构提示 ----------
function Show-ArchInfo {
    $label = switch ($OsArch) {
        "x64"   { "x64  (AMD64 / Intel 64)" }
        "arm64" { "ARM64  (Windows on ARM)" }
        "x86"   { "x86  (32 位系统)" }
        default { "无法判断" }
    }
    Write-Host ("  本机架构：" + $label) -ForegroundColor Cyan

    if ($OsArch -eq "x86") {
        Write-Host "  注意：这是 32 位系统，下面所有软件都只发 64 位版本，一台都装不了。" -ForegroundColor Red
        Write-Host "        建议换 64 位系统的机器，或先重装 64 位 Windows。" -ForegroundColor Red
    } elseif ($OsArch -eq "arm64") {
        Write-Host "  已按 ARM64 优先挑选版本：有原生版用原生版，没有的用 x64 模拟。" -ForegroundColor Yellow
    } elseif ($OsArch -eq "unknown") {
        Write-Host "  注意：架构检测失败，下面按 x64 给建议，请人工确认系统位数。" -ForegroundColor Red
    }
}

# ---------- 让用户选格式 ----------
function Select-Format($app, $picks) {
    if ($picks.Count -le 1) { return $picks[0] }

    Write-Host ""
    Say-Note ($app.name + " 有 " + $picks.Count + " 种格式可选：")
    for ($k = 0; $k -lt $picks.Count; $k++) {
        $pv = $picks[$k]
        $localTag = ""
        if (Get-LocalCached $app $pv) { $localTag = "  [本地已有]" }
        $mark = ""
        if ($k -eq 0) { $mark = "   <- 默认" }
        $line = "        " + ($k + 1) + ". " + (Pad-Display (Get-FormatLabel $pv.format) 8) + (Pad-Display $pv.arch 7) + (Pad-Display $pv.size 10) + $pv.file + $localTag + $mark
        Write-Host $line -ForegroundColor Gray
    }
    $fs = Read-Host "    选第几种（直接回车 = 1）"
    if ($fs -match "^\s*$") { return $picks[0] }
    $n = 0
    if (-not [int]::TryParse($fs, [ref]$n)) { return $picks[0] }
    if ($n -lt 1 -or $n -gt $picks.Count) { return $picks[0] }
    return $picks[$n - 1]
}

# ---------- 运行库提醒 ----------
# 不装运行库也能「安装成功」，但打开时可能白屏 / 报缺少 dll，客户会以为包是坏的。
# 所以启动时先快速查一遍，缺了就在最上面提醒（不阻塞使用）。
function Test-WebView2 {
    $ids = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
        "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    )
    foreach ($p in $ids) {
        try {
            $k = Get-ItemProperty $p -ErrorAction Stop
            if ($k.pv -and $k.pv -ne "0.0.0.0") { return $true }
        } catch { }
    }
    $bases = @()
    if ($env:ProgramFiles) { $bases += (Join-Path $env:ProgramFiles "Microsoft\EdgeWebView\Application") }
    if (${env:ProgramFiles(x86)}) { $bases += (Join-Path ${env:ProgramFiles(x86)} "Microsoft\EdgeWebView\Application") }
    foreach ($b in $bases) {
        if (-not (Test-Path $b)) { continue }
        if (Get-ChildItem -Path $b -Recurse -Filter "msedgewebview2.exe" -ErrorAction SilentlyContinue | Select-Object -First 1) { return $true }
    }
    return $false
}
function Test-VCRuntime {
    foreach ($p in @(
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64")) {
        try {
            $k = Get-ItemProperty $p -ErrorAction Stop
            if ($k.Installed -eq 1) { return $true }
        } catch { }
    }
    return $false
}
function Show-RuntimeHint {
    $miss = @()
    if (-not (Test-WebView2)) { $miss += "WebView2 运行时" }
    if (-not (Test-VCRuntime)) { $miss += "VC++ 运行库" }
    if ($miss.Count -eq 0) { return }
    Write-Host ""
    Write-Host ("  提醒：本机缺少 " + ($miss -join "、")) -ForegroundColor Yellow
    Write-Host "        装软件前建议先装它们，否则个别应用可能白屏或提示缺少 dll。" -ForegroundColor Yellow
    Write-Host "        列表最后有「运行环境」分组，安装包就在里面。" -ForegroundColor Gray
}

# ---------- 主流程 ----------
Clear-Host
Write-Host ""
Write-Host "  ==============================================================" -ForegroundColor Magenta
Write-Host "            AI 客户端与命令行工具 安装器  v" -ForegroundColor Magenta -NoNewline
Write-Host $cfg.version -ForegroundColor Magenta
Write-Host "  ==============================================================" -ForegroundColor Magenta
Show-ArchInfo
Write-Host "  提示：如果「安装包」文件夹里已有安装程序，会直接安装，不联网。" -ForegroundColor Gray
Write-Host "        同一软件有多种格式时，会让你选装哪一种。" -ForegroundColor Gray
Show-RuntimeHint

if ($Check) {
    Show-Table
    Write-Host ""
    Write-Host ("安装包目录：" + $PkgDir) -ForegroundColor DarkGray
    Write-Host ("下载目录  ：" + $DlDir) -ForegroundColor DarkGray
    exit 0
}

if ($Verify) {
    Invoke-Verify
    exit 0
}

if ($All) {
    Invoke-DownloadAll
    Write-Host ""
    Say-Ok "全部处理完毕，安装包在「下载」文件夹"
    exit 0
}

while ($true) {
    Show-Table
    Write-Host ""
    Write-Host "  操作：" -ForegroundColor White -NoNewline
    Write-Host " 输入序号" -ForegroundColor Cyan -NoNewline
    Write-Host " 下载/安装单个软件    " -ForegroundColor White -NoNewline
    Write-Host "A" -ForegroundColor Cyan -NoNewline
    Write-Host " = 下载全部可下载桌面软件    " -ForegroundColor White -NoNewline
    Write-Host "V" -ForegroundColor Cyan -NoNewline
    Write-Host " = 校验安装包是否完好    " -ForegroundColor White -NoNewline
    Write-Host "Q" -ForegroundColor Cyan -NoNewline
    Write-Host " = 退出" -ForegroundColor White
    Write-Host "  注意：A 会下载多个大文件（合计约 2 GB），建议按需输入单个序号。" -ForegroundColor Yellow
    $sel = Read-Host "  请选择"

    if ($sel -match "^[qQ]$") { break }

    if ($sel -match "^[vV]$") { Invoke-Verify; continue }

    if ($sel -match "^[aA]$") {
        Invoke-DownloadAll
        continue
    }

    $n = 0
    if (-not [int]::TryParse($sel, [ref]$n)) { Say-Bad "请输入数字"; continue }
    if ($n -lt 1 -or $n -gt $Ordered.Count) { Say-Bad "序号超出范围"; continue }

    $app   = $Ordered[$n - 1]
    $picks = @(Get-Variants $app $OsArch)

    if ($picks.Count -eq 0) {
        if (@($app.variants).Count -eq 0 -and -not $app.file) {
            Say-Note ($app.name + " 没有桌面版")
        } else {
            Say-Bad ($app.name + " 没有适配本机（" + $OsArch + "）的版本")
            Say-Note ("该应用只提供：" + ((@($app.variants) | ForEach-Object { $_.arch }) -join " / "))
        }
        if ($app.tip) { Say-Note $app.tip }
        if ($app.page) {
            $o = Read-Host "    打开项目页面看看？(y/N)"
            if ($o -match "^[yY]") { Start-Process $app.page }
        }
        continue
    }

    $pick = Select-Format $app $picks
    $path = Get-Installer $app $pick
    if ($path) {
        Write-Log ("READY  " + $app.id + "  " + $pick.arch + "  " + $pick.format + "  " + $path)
        Start-Installer $app $path $pick
    }
    Start-Sleep -Milliseconds 600
}

Write-Host ""
Write-Host "  已退出。安装包都在：" -ForegroundColor Gray
Write-Host ("  " + $DlDir) -ForegroundColor DarkGray
Write-Host ("  运行日志：" + $LogFile) -ForegroundColor DarkGray
Write-Host ""
