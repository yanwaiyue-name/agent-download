# =============================================================
#  补全安装包（给卖家自己用，不随包发给买家）
#  用法：
#    powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1
#        按 sources.json 把「Windows 的每一种格式」都下到 安装包\<应用>\
#    powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Mac
#        连 macOS 的 dmg 一起下，放到 安装包\<应用>\mac\
#    powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Only cherry,hermes
#        只补某几个应用（用 sources.json 里的 id）
#    powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Force
#        已存在的文件也重新下一遍
#    powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -DryRun
#        只列出「要下哪些、下到哪、多大」，不真的下载（验证配置用）
#    powershell -ExecutionPolicy Bypass -File .\补全安装包.ps1 -Proxy http://127.0.0.1:7897
#        走指定代理；不写就自动探测本机常见代理端口
#  说明：下完跑 launcher.ps1 -Check 看是否全部「已就绪」。
# =============================================================

param(
    [switch]$Mac,
    [switch]$Force,
    [switch]$DryRun,
    [string]$Proxy = "",
    [string[]]$Only = @()
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$PkgDir  = Join-Path $Root "安装包"
$JsonPath = Join-Path $Root "sources.json"
$LogFile = Join-Path $Root "下载日志.txt"

if (-not (Test-Path $JsonPath)) {
    Write-Host "找不到 sources.json" -ForegroundColor Red
    exit 1
}
$cfg  = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$Apps = @($cfg.apps)

# GitHub 加速前缀，按顺序试；非 GitHub 直链不加前缀。
# 优先读 sources.json 顶层 mirrors（空串 = 直连），镜像站挂了改 JSON 即可
$Mirrors = @("https://gh-proxy.com/", "https://ghfast.top/", "", "https://gh.llkk.cc/")
if ($cfg.mirrors) { $Mirrors = @($cfg.mirrors) }

# ---------- 代理自动探测 ----------
# 国内直连 GitHub / downloads.claude.ai 基本不通，必须走本机代理。
# 优先级：-Proxy 参数 > 环境变量 > 系统代理设置 > 常见本地端口探测
function Get-AutoProxy {
    if ($Proxy) { return $Proxy }
    foreach ($e in @($env:HTTPS_PROXY, $env:HTTP_PROXY, $env:ALL_PROXY)) {
        if ($e) { return $e }
    }
    try {
        $k = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction Stop
        if ($k.ProxyEnable -eq 1 -and $k.ProxyServer) {
            $ps = [string]$k.ProxyServer
            if ($ps -notmatch "://") { $ps = "http://" + $ps }
            return $ps
        }
    } catch { }
    foreach ($port in @(7897, 7890, 10809, 1080, 8080)) {
        try {
            $c = New-Object System.Net.Sockets.TcpClient
            $ar = $c.BeginConnect("127.0.0.1", $port, $null, $null)
            if ($ar.AsyncWaitHandle.WaitOne(250) -and $c.Connected) { $c.Close(); return ("http://127.0.0.1:" + $port) }
            $c.Close()
        } catch { }
    }
    return ""
}
$ProxyUrl = Get-AutoProxy

function Say($m, $c) { if ($c) { Write-Host $m -ForegroundColor $c } else { Write-Host $m } }

function Test-Magic($path) {
    # exe = MZ；msi = OLE 复合文档 D0CF11E0（不是 MZ）；zip = PK；7z = 377ABCAF271C；
    # dmg = UDIF，末尾 512 字节 trailer 的开头 4 字节恒为 "koly"（识别加速站返回的 HTML 错误页）
    try {
        $ext = [System.IO.Path]::GetExtension($path).ToLowerInvariant()
        if ($ext -notin @(".exe", ".msi", ".zip", ".7z", ".dmg")) { return $true }
        if ($ext -eq ".7z") {
            $fs7 = [System.IO.File]::OpenRead($path)
            try {
                $b6 = New-Object byte[] 6
                if ($fs7.Read($b6, 0, 6) -lt 6) { return $false }
                return (($b6[0] -eq 0x37) -and ($b6[1] -eq 0x7A) -and ($b6[2] -eq 0xBC) -and
                        ($b6[3] -eq 0xAF) -and ($b6[4] -eq 0x27) -and ($b6[5] -eq 0x1C))
            } finally { $fs7.Close() }
        }
        if ($ext -eq ".dmg") {
            $fs2 = [System.IO.File]::OpenRead($path)
            try {
                if ($fs2.Length -lt 512) { return $false }
                [void]$fs2.Seek(-512, [System.IO.SeekOrigin]::End)
                $tb = New-Object byte[] 4
                if ($fs2.Read($tb, 0, 4) -lt 4) { return $false }
                return (($tb[0] -eq 0x6B) -and ($tb[1] -eq 0x6F) -and ($tb[2] -eq 0x6C) -and ($tb[3] -eq 0x79))
            } finally { $fs2.Close() }
        }
        $fs = [System.IO.File]::OpenRead($path)
        try {
            $buf = New-Object byte[] 2
            if ($fs.Read($buf, 0, 2) -lt 2) { return $false }
            if ($ext -eq ".zip") { return (($buf[0] -eq 0x50) -and ($buf[1] -eq 0x4B)) }
            if ($ext -eq ".msi") { return ((($buf[0] -eq 0xD0) -and ($buf[1] -eq 0xCF)) -or (($buf[0] -eq 0x4D) -and ($buf[1] -eq 0x5A))) }
            return (($buf[0] -eq 0x4D) -and ($buf[1] -eq 0x5A))
        } finally { $fs.Close() }
    } catch { return $false }
}

function Save-One($url, $dest) {
    # 走代理时跳过 BITS（BITS 不吃 -Proxy），改用带超时和代理的 Invoke-WebRequest
    if ($ProxyUrl -and $url -notmatch "^https://(gh-proxy|ghfast|gh\.llkk)") {
        try {
            # 用 Invoke-WebRequest 而不是 WebClient：后者没有超时，代理挂起时会永久卡死
            Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 1800 -Proxy $ProxyUrl -Headers @{ "User-Agent" = "Mozilla/5.0 pack-fetcher" } -ErrorAction Stop
            if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 200KB) -and (Test-Magic $dest)) { return $true }
            if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
        } catch {
            if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
        }
        return $false
    }
    try {
        Start-BitsTransfer -Source $url -Destination $dest -ErrorAction Stop
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 200KB) -and (Test-Magic $dest)) { return $true }
        if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    } catch { }
    try {
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -TimeoutSec 1800 -ErrorAction Stop
        if ((Test-Path $dest) -and ((Get-Item $dest).Length -gt 200KB) -and (Test-Magic $dest)) { return $true }
        if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    } catch {
        if (Test-Path $dest) { Remove-Item $dest -Force -ErrorAction SilentlyContinue }
    }
    return $false
}

function Get-One($urls, $dest) {
    $tmp = $dest + ".part"
    foreach ($u in $urls) {
        if (-not $u) { continue }
        $isGitHub = ($u -match "github\.com|githubusercontent\.com")
        $tries = if ($isGitHub) { @($Mirrors | ForEach-Object { $_ + $u }) } else { @($u) }
        foreach ($t in $tries) {
            try { $h = ([System.Uri]$t).Host } catch { $h = "?" }
            Write-Host ("      尝试 " + $h + " ...") -ForegroundColor DarkGray
            if (Save-One $t $tmp) {
                Move-Item -Path $tmp -Destination $dest -Force
                return $true
            }
            if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        }
    }
    return $false
}

Say ""
Say "==============================================================" Magenta
Say "  补全安装包 · 按 sources.json 下载每一种格式" Magenta
Say "==============================================================" Magenta
Say ("  目标目录：" + $PkgDir) Gray
Say ("  macOS 包：" + $(if ($Mac) { "一起下（安装包\<应用>\mac\）" } else { "跳过（要下加 -Mac）" })) Gray
Say ("  代理    ：" + $(if ($ProxyUrl) { $ProxyUrl } else { "未检测到（直连，GitHub 可能很慢或失败）" })) $(if ($ProxyUrl) { "Gray" } else { "Yellow" })
if ($DryRun) { Say "  模式    ：演练（只看计划，不下载）" Yellow }
Say ""

$total = 0; $okCount = 0; $skipCount = 0; $failCount = 0
$failList = New-Object System.Collections.ArrayList

foreach ($a in $Apps) {
    if ($Only.Count -gt 0 -and ($Only -notcontains $a.id)) { continue }
    $dirName = $a.dir; if (-not $dirName) { $dirName = $a.id }

    $jobs = New-Object System.Collections.ArrayList
    foreach ($v in @($a.variants)) {
        if ($v.format -eq "sums") { continue }
        [void]$jobs.Add(@{ file = $v.file; urls = @($v.urls); sub = ""; tag = ("Windows " + $v.arch + " · " + $v.format) })
    }
    if ($Mac) {
        foreach ($m in @($a.mac)) {
            [void]$jobs.Add(@{ file = $m.file; urls = @($m.urls); sub = "mac"; tag = ("macOS " + $m.arch + " · " + $m.format) })
        }
    }
    if ($jobs.Count -eq 0) { continue }

    Say ("[" + $a.name + "]") Cyan
    foreach ($j in $jobs) {
        $total++
        $targetDir = Join-Path $PkgDir $dirName
        if ($j.sub) { $targetDir = Join-Path $targetDir $j.sub }
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
        $dest = Join-Path $targetDir $j.file

        if ((Test-Path $dest) -and -not $Force) {
            $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
            # 不只看「文件在不在」，还要过文件头校验：上次中断的残包、
            # 加速站返回的 HTML 错误页都会在这里被识别出来并重下
            if (((Get-Item $dest).Length -gt 200KB) -and (Test-Magic $dest)) {
                Say ("      = " + $j.tag + "  已有 " + $mb + " MB") DarkGray
                $skipCount++
                continue
            }
            Say ("      ! " + $j.tag + "  已有文件损坏或不完整（" + $mb + " MB），重新下载") Yellow
            Remove-Item $dest -Force -ErrorAction SilentlyContinue
        }

        Say ("      > " + $j.tag + "  " + $j.file) White
        if ($DryRun) {
            Say ("        [演练] 目标：" + $dest) Yellow
            Say ("        [演练] 来源：" + (@($j.urls)[0])) DarkGray
            $okCount++
            continue
        }
        if (Get-One $j.urls $dest) {
            $mb = [math]::Round((Get-Item $dest).Length / 1MB, 1)
            $hash = (Get-FileHash $dest -Algorithm SHA256).Hash
            Say ("        OK " + $mb + " MB  SHA256 " + $hash.Substring(0, 16) + "...") Green
            Add-Content -Path $LogFile -Value ((Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  " + $a.id + "  " + $j.file + "  " + $mb + "MB  " + $hash) -Encoding UTF8
            $okCount++
        } else {
            Say ("        XX 全部源失败，请手动下载：" + $a.page) Red
            Add-Content -Path $LogFile -Value ((Get-Date -Format "yyyy-MM-dd HH:mm:ss") + "  FAIL  " + $a.id + "  " + $j.file) -Encoding UTF8
            [void]$failList.Add($a.name + " / " + $j.file)
            $failCount++
        }
    }
    Say ""
}

Say "--------------------------------------------------------------" DarkGray
Say ("  共 " + $total + " 个文件：新下载 " + $okCount + "，已有 " + $skipCount + "，失败 " + $failCount) White
if ($failCount -gt 0) {
    Say "  失败清单（按官方页面手动补）：" Red
    foreach ($f in $failList) { Say ("    · " + $f) Red }
}
Say ""
Say "  下一步：powershell -ExecutionPolicy Bypass -File .\launcher.ps1 -Check" Gray
Say "          全部显示「已就绪」就可以打包了：.\打包.ps1" Gray
Say ""
