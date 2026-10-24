# =============================================================
#  本机系统检测 · 判断该装哪个版本
#  用法：双击「双击检测.bat」，或在 PowerShell 里跑本文件
#  作用：查 CPU 架构（x64 / ARM64 / x86）、系统版本、内存、磁盘，
#        然后告诉你每个软件该下哪个版本、能不能装
# =============================================================

param(
    [switch]$NoPause,
    [switch]$Quiet
)

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$JsonPath = Join-Path $Root "sources.json"
$OutFile  = Join-Path $Root "本机检测报告.txt"
$Report   = New-Object System.Collections.ArrayList

# ---------- 输出（同时收集到报告） ----------
function Out-Line($text, $color) {
    if (-not $Quiet) {
        if ($color) { Write-Host $text -ForegroundColor $color } else { Write-Host $text }
    }
    [void]$Report.Add($text)
}

# ---------- 中文宽度对齐 ----------
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
function Pad($s, $width) {
    $s = [string]$s
    $w = Get-DisplayWidth $s
    if ($w -ge $width) { return $s }
    return $s + (" " * ($width - $w))
}

# =============================================================
#  一、架构检测
# =============================================================

function Get-OsArch {
    # 主判据：Win32_ComputerSystem.SystemType
    # 这是最可靠的 —— 即使在 ARM64 机器上跑 32 位 PowerShell 也不会误判
    try {
        $st = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).SystemType
        if ($st -match "ARM64") { return @{ arch = "arm64"; src = "Win32_ComputerSystem"; raw = $st } }
        if ($st -match "x64")   { return @{ arch = "x64";   src = "Win32_ComputerSystem"; raw = $st } }
        if ($st -match "x86")   { return @{ arch = "x86";   src = "Win32_ComputerSystem"; raw = $st } }
    } catch { }

    # 次判据：.NET RuntimeInformation（.NET 4.7.1+ / PowerShell 6+）
    try {
        $a = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        if ($a -eq "Arm64") { return @{ arch = "arm64"; src = "RuntimeInformation"; raw = $a } }
        if ($a -eq "X64")   { return @{ arch = "x64";   src = "RuntimeInformation"; raw = $a } }
        if ($a -eq "X86")   { return @{ arch = "x86";   src = "RuntimeInformation"; raw = $a } }
    } catch { }

    # 兜底：环境变量。PROCESSOR_ARCHITEW6432 有值说明是 32 位进程跑在 64 位系统上
    $p = $env:PROCESSOR_ARCHITEW6432
    if (-not $p) { $p = $env:PROCESSOR_ARCHITECTURE }
    switch ($p.ToUpper()) {
        "AMD64" { return @{ arch = "x64";   src = "环境变量"; raw = $p } }
        "ARM64" { return @{ arch = "arm64"; src = "环境变量"; raw = $p } }
        "X86"   { return @{ arch = "x86";   src = "环境变量"; raw = $p } }
    }
    return @{ arch = "unknown"; src = "无法判断"; raw = $p }
}

function Get-CpuInfo {
    try {
        $c = Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1
        return @{
            name   = ($c.Name -replace "\s+", " ").Trim()
            cores  = $c.NumberOfCores
            threads= $c.NumberOfLogicalProcessors
            clock  = $c.MaxClockSpeed
        }
    } catch { return $null }
}

function Get-MemGB {
    try {
        $b = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).TotalPhysicalMemory
        return [math]::Round($b / 1GB, 1)
    } catch { return 0 }
}

function Get-FreeDiskGB($drive) {
    try {
        $d = Get-CimInstance Win32_LogicalDisk -Filter ("DeviceID='" + $drive + "'") -ErrorAction Stop
        if ($d) { return [math]::Round($d.FreeSpace / 1GB, 1) }
    } catch { }
    return 0
}

function Get-OsInfo {
    try {
        $o = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        return @{
            caption = $o.Caption
            version = $o.Version
            build   = $o.BuildNumber
            arch    = $o.OSArchitecture
        }
    } catch { return $null }
}

# =============================================================
#  一·五、运行环境（运行库）检测
# =============================================================
# 这些不是软件本身，而是软件运行要依赖的底层组件。
# 缺了通常不会立刻报错，表现往往是「双击没反应」「窗口一片白」
# 「计算机中丢失 xxx.dll」——客户很难自己判断，所以先检测出来。

function Get-WebView2 {
    # WebView2 Runtime：Tauri 框架应用（CC Switch 等）的网页渲染内核
    $ids = @(
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
        "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}",
        "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
    )
    foreach ($p in $ids) {
        try {
            $k = Get-ItemProperty $p -ErrorAction Stop
            if ($k.pv -and $k.pv -ne "0.0.0.0") { return @{ ok = $true; ver = [string]$k.pv } }
        } catch { }
    }
    # 注册表读不到时，兜底看安装目录（有些精简版系统会清掉 Edge 的注册表项）
    $bases = @()
    if ($env:ProgramFiles) { $bases += (Join-Path $env:ProgramFiles "Microsoft\EdgeWebView\Application") }
    if (${env:ProgramFiles(x86)}) { $bases += (Join-Path ${env:ProgramFiles(x86)} "Microsoft\EdgeWebView\Application") }
    foreach ($b in $bases) {
        if (-not (Test-Path $b)) { continue }
        $exe = Get-ChildItem -Path $b -Recurse -Filter "msedgewebview2.exe" -ErrorAction SilentlyContinue |
               Select-Object -First 1
        if ($exe) { return @{ ok = $true; ver = (Split-Path -Leaf (Split-Path -Parent $exe.FullName)) } }
    }
    return @{ ok = $false; ver = "" }
}

function Get-VCRuntime {
    # Visual C++ 2015-2022 运行库（x64）
    $paths = @(
        "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64"
    )
    foreach ($p in $paths) {
        try {
            $k = Get-ItemProperty $p -ErrorAction Stop
            if ($k.Installed -eq 1) { return @{ ok = $true; ver = [string]$k.Version } }
        } catch { }
    }
    return @{ ok = $false; ver = "" }
}

function Get-DotNetFramework {
    # .NET Framework 4.x：部分安装器（不是应用本体）会要求 4.7.2 以上
    try {
        $k = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction Stop
        $rel = [int]$k.Release
        $ver = "4.x"
        if ($rel -ge 533320) { $ver = "4.8.1" }
        elseif ($rel -ge 528040) { $ver = "4.8" }
        elseif ($rel -ge 461808) { $ver = "4.7.2" }
        elseif ($rel -ge 394802) { $ver = "4.6.2" }
        else { $ver = "低于 4.6.2" }
        return @{ ok = ($rel -ge 461808); ver = $ver }
    } catch {
        return @{ ok = $false; ver = "未检测到" }
    }
}

function Get-NodePython {
    # 只做说明用：本清单里的桌面软件都不依赖系统 Python / Node
    $node = Get-Command node -ErrorAction SilentlyContinue
    $py   = Get-Command python -ErrorAction SilentlyContinue
    if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
    $nodeVer = ""
    if ($node) { try { $nodeVer = (& node --version 2>$null) } catch { } }
    $pyVer = ""
    if ($py) { try { $pyVer = (& $py.Source --version 2>&1 | Select-Object -First 1) } catch { } }
    return @{ node = $nodeVer; py = $pyVer }
}

# =============================================================
#  二、已安装软件检测
# =============================================================

function Get-InstalledNames {
    $keys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $names = New-Object System.Collections.ArrayList
    foreach ($k in $keys) {
        try {
            $items = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
            foreach ($i in $items) {
                if ($i.DisplayName) { [void]$names.Add([string]$i.DisplayName) }
            }
        } catch { }
    }
    return $names
}

# 每个应用用于匹配已安装软件的关键词（与 sources.json 的 apps id 一一对应，v4 共 38 项）
# 注意：trae / trae-cn 在注册表里都叫 Trae，分不出来，命中即两个都算已安装
$InstallKeywords = @{
    "workbuddy"        = @("WorkBuddy")
    "claude"           = @("Claude")
    "codex"            = @("ChatGPT", "Codex")
    "opencode"         = @("OpenCode")
    "dsh"              = @("DeepSeek Harness", "DSH")
    "cherry"           = @("Cherry Studio")
    "lobehub"          = @("LobeHub", "Lobe Chat")
    "ccswitch"         = @("CC Switch")
    "opencowork"       = @("Open Cowork")
    "runjam"           = @("RunJam")
    "ccgui"            = @("CC GUI", "Desktop CC GUI")
    "hermes"           = @("Hermes")
    "watt"             = @("Watt Toolkit", "Steam++")
    "webview2-online"  = @("WebView2")
    "webview2-offline" = @("WebView2")
    "vcredist"         = @("Visual C++ 2015")
    "python"           = @("Python 3")
    "nodejs"           = @("Node.js")
    "git"              = @("Git")
    "7zip"             = @("7-Zip")
    "cursor"           = @("Cursor")
    "trae"             = @("Trae")
    "trae-cn"          = @("Trae")
    "windsurf"         = @("Windsurf")
    "vscode"           = @("Visual Studio Code")
    "claude-code"      = @("Claude Code")
    "gemini-cli"       = @("Gemini CLI")
    "qwen-code"        = @("Qwen Code")
    "kimi-cli"         = @("Kimi")
    "codex-cli"        = @("Codex CLI")
    "openclaw"         = @("OpenClaw")
    "aider"            = @("Aider")
    "iflow-cli"        = @("iFlow")
    "goose"            = @("Goose")
    "openhands"        = @("OpenHands")
    "cline"            = @("Cline")
    "grox"             = @("Grox")
}

# =============================================================
#  三、读配置（读不到就用内置架构表）
# =============================================================

$Apps = $null
if (Test-Path $JsonPath) {
    try {
        $raw  = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8)
        $cfg  = $raw | ConvertFrom-Json
        $Apps = @($cfg.apps)
    } catch { $Apps = $null }
}

if (-not $Apps) {
    # 内置兜底：只有架构能力，没有下载链接。与 sources.json v4 同步（38 项），
    # 改 sources.json 记得同步这张表，否则 sources.json 丢失时报告会按旧清单给建议
    $Apps = @(
        @{ id="workbuddy"; group="桌面端"; name="WorkBuddy（腾讯）"; desc="全场景 AI 办公工作台"; variants=@(@{arch="x64"; format="setup"; size="420.7 MB"}) },
        @{ id="claude"; group="桌面端"; name="Claude Desktop"; desc="Claude 官方桌面客户端"; variants=@(@{arch="x64"; format="setup"; size="157.6 MB"}) },
        @{ id="codex"; group="桌面端"; name="ChatGPT 桌面端（含 Codex）"; desc="ChatGPT 桌面端，内置 Codex 面板"; variants=@(@{arch="x64"; format="store"; size="0.8 MB"}, @{arch="arm64"; format="store"; size="0.8 MB"}) },
        @{ id="opencode"; group="桌面端"; name="OpenCode Desktop"; desc="开源 AI 编程 Agent"; variants=@(@{arch="x64"; format="setup"; size="120.5 MB"}, @{arch="x64"; format="zip"; size="78.0 MB"}, @{arch="arm64"; format="setup"; size="113.4 MB"}, @{arch="arm64"; format="zip"; size="72.3 MB"}) },
        @{ id="dsh"; group="桌面端"; name="DeepSeek Harness 桌面版"; desc="DeepSeek 智能体桌面平台"; variants=@(@{arch="x64"; format="setup"; size="314.8 MB"}) },
        @{ id="cherry"; group="桌面端"; name="Cherry Studio"; desc="国产多模型聚合客户端"; variants=@(@{arch="x64"; format="setup"; size="296.4 MB"}, @{arch="x64"; format="portable"; size="296.1 MB"}, @{arch="arm64"; format="setup"; size="275.2 MB"}, @{arch="arm64"; format="portable"; size="274.8 MB"}) },
        @{ id="lobehub"; group="桌面端"; name="LobeHub 桌面版"; desc="开源 AI 助手聚合客户端"; variants=@(@{arch="x64"; format="setup"; size="145.5 MB"}) },
        @{ id="ccswitch"; group="Agents"; name="CC Switch"; desc="多 Agent 配置、升级与管理工具"; variants=@(@{arch="x64"; format="msi"; size="16.7 MB"}, @{arch="x64"; format="zip"; size="16.7 MB"}, @{arch="arm64"; format="msi"; size="16.0 MB"}, @{arch="arm64"; format="zip"; size="15.8 MB"}) },
        @{ id="opencowork"; group="Agents"; name="Open Cowork"; desc="图形化 AI Agent 工作台"; variants=@(@{arch="x64"; format="setup"; size="123.1 MB"}) },
        @{ id="runjam"; group="Agents"; name="RunJam"; desc="多 Agent 图形化编程工作台"; variants=@(@{arch="x64"; format="setup"; size="107.3 MB"}) },
        @{ id="ccgui"; group="Agents"; name="Desktop CC GUI"; desc="多引擎 Agent 图形化运行器"; variants=@(@{arch="x64"; format="setup"; size="15.0 MB"}) },
        @{ id="hermes"; group="桌面端"; name="Hermes Agent 桌面版"; desc="NousResearch 官方 Agent 桌面客户端"; variants=@(@{arch="x64"; format="setup"; size="7.6 MB"}) },
        @{ id="webview2-online"; group="运行环境"; name="WebView2 运行时（在线版）"; desc="网页渲染内核，1.8 MB 引导器（安装时要联网）"; variants=@(@{arch="x64"; format="setup"; size="1.8 MB"}); runtimeCheck="webview2" },
        @{ id="webview2-offline"; group="运行环境"; name="WebView2 运行时（离线包）"; desc="完整离线安装包，装的时候不需要联网"; variants=@(@{arch="x64"; format="setup"; size="204.9 MB"}); runtimeCheck="webview2" },
        @{ id="vcredist"; group="运行环境"; name="VC++ 运行库 2015-2022（x64）"; desc="微软 Visual C++ 运行库，多数桌面软件的底层依赖"; variants=@(@{arch="x64"; format="setup"; size="24.4 MB"}); runtimeCheck="vcredist" },
        @{ id="watt"; group="桌面端"; name="Watt Toolkit（瓦特工具箱）"; desc="Steam / GitHub 加速工具箱（原名 Steam++）"; variants=@(@{arch="x64"; format="setup"; size="92.3 MB"}, @{arch="x64"; format="zip"; size="90.3 MB"}) },
        @{ id="python"; group="开发环境"; name="Python 3.13.10"; desc="Python 官方解释器（含 pip）"; variants=@(@{arch="x64"; format="setup"; size="27.4 MB"}, @{arch="arm64"; format="setup"; size="26.8 MB"}); kind="env" },
        @{ id="nodejs"; group="开发环境"; name="Node.js 24.22.1 LTS"; desc="Node.js 长期支持版（含 npm）"; variants=@(@{arch="x64"; format="msi"; size="31.8 MB"}, @{arch="arm64"; format="msi"; size="28.4 MB"}); kind="env" },
        @{ id="git"; group="开发环境"; name="Git for Windows 2.56.0.3"; desc="Git 版本控制（含 Git Bash）"; variants=@(@{arch="x64"; format="setup"; size="63.7 MB"}, @{arch="arm64"; format="setup"; size="61.4 MB"}); kind="env" },
        @{ id="7zip"; group="开发环境"; name="7-Zip 25.01"; desc="开源压缩工具，支持 .7z / .zip / .rar 等"; variants=@(@{arch="x64"; format="setup"; size="1.6 MB"}, @{arch="arm64"; format="setup"; size="1.5 MB"}); kind="env" },
        @{ id="cursor"; group="IDE"; name="Cursor"; desc="AI 原生代码编辑器"; variants=@(); install="web" },
        @{ id="trae"; group="IDE"; name="Trae（国际版）"; desc="AI IDE（国际版，英文界面）"; variants=@(); install="web" },
        @{ id="trae-cn"; group="IDE"; name="Trae CN（国内版）"; desc="AI IDE（国内版，中文界面）"; variants=@(); install="web" },
        @{ id="windsurf"; group="IDE"; name="Windsurf"; desc="AI IDE（原 Codeium）"; variants=@(); install="web" },
        @{ id="vscode"; group="IDE"; name="Visual Studio Code"; desc="微软官方代码编辑器"; variants=@(); install="web" },
        @{ id="claude-code"; group="CLI Code"; name="Claude Code"; desc="Anthropic 官方命令行编程助手"; variants=@(@{arch="x64"; format="zip"; size="127.6 MB"}, @{arch="arm64"; format="zip"; size="122.2 MB"}) },
        @{ id="gemini-cli"; group="CLI Code"; name="Gemini CLI"; desc="Google 官方命令行 AI 助手"; variants=@() },
        @{ id="qwen-code"; group="CLI Code"; name="Qwen Code"; desc="通义千问命令行编程工具"; variants=@(@{arch="x64"; format="zip"; size="69.3 MB"}) },
        @{ id="kimi-cli"; group="CLI Code"; name="Kimi CLI"; desc="Kimi 命令行编程工具"; variants=@(@{arch="x64"; format="zip"; size="68.7 MB"}, @{arch="arm64"; format="zip"; size="64.6 MB"}) },
        @{ id="pi"; group="CLI Code"; name="Pi"; desc="终端 AI agent 工具箱"; variants=@(@{arch="x64"; format="zip"; size="43 MB"}, @{arch="arm64"; format="zip"; size="41.7 MB"}) },
        @{ id="codex-cli"; group="CLI Code"; name="Codex CLI"; desc="OpenAI 官方命令行编程助手"; variants=@(); install="npm" },
        @{ id="openclaw"; group="CLI Code"; name="OpenClaw"; desc="开源个人 AI Agent"; variants=@(); install="npm" },
        @{ id="aider"; group="CLI Code"; name="Aider"; desc="终端 AI 结对编程"; variants=@(); install="pip" },
        @{ id="iflow-cli"; group="CLI Code"; name="iFlow CLI"; desc="心流命令行智能体"; variants=@(); install="npm" },
        @{ id="goose"; group="Agents"; name="Goose"; desc="开源 AI Agent（桌面 + CLI）"; variants=@(@{arch="x64"; format="setup"; size="131.3 MB"}) },
        @{ id="openhands"; group="Agents"; name="OpenHands"; desc="开源 AI 软件工程 Agent"; variants=@(@{arch="x64"; format="setup"; size="135.4 MB"}) },
        @{ id="cline"; group="Agents"; name="Cline（桌面版）"; desc="AI 编码 Agent（独立桌面版）"; variants=@(@{arch="x64"; format="setup"; size="115.8 MB"}) },
        @{ id="grox"; group="Agents"; name="Grox（Grok Build 社区桌面版）"; desc="Grok Build 的桌面封装（非官方）"; variants=@(@{arch="x64"; format="setup"; size="6.3 MB"}) }
    )
}

# =============================================================
#  四、选版本
# =============================================================

# 同一架构可能有多套格式：MSI 最省事，其次 setup，免安装/压缩包最后
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

function Select-Variant($app, $arch) {
    $vs = @($app.variants | Where-Object { $_.format -ne "sums" -and $_.format -ne "dmg" -and $_.format -ne "pkg" })
    if ($vs.Count -eq 0) { return $null }

    $selectionArch = $arch
    $unknownArch = $false
    if ($arch -eq "unknown") {
        $selectionArch = "x64"
        $unknownArch = $true
    }

    # 1) 精确匹配本机架构；检测失败时按 x64 建议
    $hit = @($vs | Where-Object { $_.arch -eq $selectionArch })
    $mode = if ($unknownArch) { "assumed" } else { "native" }
    # 2) ARM64 机器可以跑 x64（Windows 自带模拟层）
    if ($hit.Count -eq 0 -and $selectionArch -eq "arm64") {
        $hit = @($vs | Where-Object { $_.arch -eq "x64" })
        $mode = "emulated"
    }
    # 3) x64 / x86 机器跑不了 arm64 包
    if ($hit.Count -eq 0) { return $null }

    $best = @($hit | Sort-Object -Property @{ Expression = { Get-FormatRank $_.format } })[0]
    return @{ v = $best; mode = $mode; formats = $hit.Count }
}

# =============================================================
#  五、主流程
# =============================================================

$osArch = Get-OsArch
$arch   = $osArch.arch
$cpu    = Get-CpuInfo
$mem    = Get-MemGB
$freeC  = Get-FreeDiskGB "C:"
$os     = Get-OsInfo

$archLabel = switch ($arch) {
    "x64"   { "x64  (AMD64 / Intel 64)" }
    "arm64" { "ARM64  (Windows on ARM)" }
    "x86"   { "x86  (32 位系统)" }
    default { "无法判断 (" + $osArch.raw + ")" }
}

Out-Line ""
Out-Line ("═" * 64) Magenta
Out-Line "                      本 机 系 统 检 测 报 告" Magenta
Out-Line ("═" * 64) Magenta
Out-Line ""

# --- 系统信息 ---
if ($os) {
    $bit = "64 位"
    if ($arch -eq "x86") { $bit = "32 位" }
    Out-Line ("【系统】  " + $os.caption + "   (Build " + $os.build + ", " + $bit + ")")

    # 系统版本门槛：新版 Electron 和 WebView2 都要求 Win10 1809(Build 17763) 以上。
    # 这一项客户自己装运行库也解决不了，只能升级系统，所以要单独点出来。
    $buildNo = 0
    [void][int]::TryParse([string]$os.build, [ref]$buildNo)
    if ($buildNo -gt 0 -and $buildNo -lt 17763) {
        Out-Line "          警告：系统版本过旧（低于 Windows 10 1809）" Red
        Out-Line "                本清单里的软件基本都要求 1809 以上，先升级系统再装。" Red
    } elseif ($buildNo -gt 0 -and $buildNo -lt 19041) {
        Out-Line "          提示：系统版本偏旧，个别软件可能要求更新的 Windows。" Yellow
    }
} else {
    Out-Line "【系统】  (读取失败)"
}

Out-Line ("【架构】  " + $archLabel + "     <- 决定装哪个版本") Cyan
Out-Line ("          判断依据：" + $osArch.src + " = " + $osArch.raw) DarkGray

if ($cpu) {
    $ghz = ""
    if ($cpu.clock) { $ghz = " " + [math]::Round($cpu.clock / 1000, 2) + "GHz" }
    Out-Line ("【CPU】   " + $cpu.name + $ghz)
    Out-Line ("          " + $cpu.cores + " 核 / " + $cpu.threads + " 线程")
} else {
    Out-Line "【CPU】   (读取失败)"
}

$memNote = ""
if ($mem -gt 0 -and $mem -lt 8) { $memNote = "   <- 偏小，跑大模型客户端会比较卡" }
Out-Line ("【内存】  " + $mem + " GB" + $memNote)

$diskNote = ""
if ($freeC -gt 0 -and $freeC -lt 5) { $diskNote = "   <- 空间不足，装完这些约需 1.5 GB" }
Out-Line ("【硬盘】  C 盘剩余 " + $freeC + " GB" + $diskNote)
Out-Line ""

# --- 运行环境（运行库） ---
$wv2 = Get-WebView2
$vc  = Get-VCRuntime
$nfx = Get-DotNetFramework
$np  = Get-NodePython

Out-Line "【运行环境】  <- 装软件之前先看这几项" Cyan
if ($wv2.ok) {
    Out-Line ("          WebView2       已装 " + $wv2.ver)
} else {
    Out-Line "          WebView2       缺失   <- CC Switch 等应用会白屏或双击没反应" Yellow
}
if ($vc.ok) {
    Out-Line ("          VC++ 运行库    已装 " + $vc.ver)
} else {
    Out-Line "          VC++ 运行库    缺失   <- 部分软件启动会报「缺少 VCRUNTIME140.dll」" Yellow
}
if ($nfx.ok) {
    Out-Line ("          .NET Framework 已装 " + $nfx.ver)
} else {
    Out-Line ("          .NET Framework " + $nfx.ver + "   <- 少数安装器会要求 4.7.2 以上") Yellow
}

# 这两项不是必需，只是把常见误解说清楚。桌面客户端都自带运行环境；
# 但「CLI Code」分组里走 npm / pip 的工具需要它们（安装包在「开发环境」分组）
$npNote = "          说明：桌面客户端都自带运行环境；npm / pip 类 CLI 工具才需要 Node.js / Python"
if ($np.node -or $np.py) {
    $have = @()
    if ($np.node) { $have += ("Node " + $np.node) }
    if ($np.py) { $have += $np.py }
    Out-Line ($npNote + "（本机已有 " + ($have -join "、") + "，与本包无关）") DarkGray
} else {
    Out-Line $npNote DarkGray
}

if (-not $wv2.ok -or -not $vc.ok) {
    Out-Line "          缺的这两项已经在「安装包\运行环境\」里，先装运行库再装软件" White
}
Out-Line ""

# --- 架构专项提示 ---
if ($arch -eq "x86") {
    Out-Line ("─" * 62) Red
    Out-Line "  ⚠ 这是一台 32 位系统" Red
    Out-Line ("─" * 62) Red
    Out-Line "  下面这些软件**全部只提供 64 位版本**，这台机器装不了。" Red
    Out-Line "  原因：32 位 Windows 最多用 4GB 内存，且无法运行 64 位程序。" Gray
    Out-Line "  建议：换一台 64 位系统的电脑，或先重装 64 位 Windows。" Gray
    Out-Line ""
} elseif ($arch -eq "arm64") {
    Out-Line ("─" * 62) Yellow
    Out-Line "  ⚠ 这是一台 ARM64 电脑（骁龙 / 麒麟等 ARM 芯片）" Yellow
    Out-Line ("─" * 62) Yellow
    Out-Line "  ARM 机器能跑 x64 程序，但属于「模拟运行」，速度会慢一些、也更耗电。" Gray
    Out-Line "  下面会优先给你原生 ARM64 版；没有原生版的才用 x64 模拟。" Gray
    Out-Line ""
} elseif ($arch -eq "unknown") {
    Out-Line ("─" * 62) Red
    Out-Line "  ⚠ 架构检测失败，下面按 x64 给建议。请人工确认系统位数。" Red
    Out-Line ""
}

# --- 已安装检测 ---
$installed = Get-InstalledNames
function Test-Installed($id) {
    $kws = $InstallKeywords[$id]
    if (-not $kws) { return $false }
    foreach ($n in $installed) {
        foreach ($k in $kws) {
            if ($n -like ("*" + $k + "*")) { return $true }
        }
    }
    return $false
}

# --- 推荐表 ---
Out-Line ("─" * 62)
Out-Line "  推荐软件与本机适配情况"
Out-Line ("─" * 62)

$i = 1
$okCount = 0; $emuCount = 0; $assumedCount = 0; $noCount = 0
$totalMB = 0
$dlLines = New-Object System.Collections.ArrayList
$groups = @($Apps | ForEach-Object { $_.group } | Select-Object -Unique)

foreach ($group in $groups) {
    Out-Line ("【" + $group + "】") Cyan
    foreach ($a in @($Apps | Where-Object { $_.group -eq $group })) {
        $pick = Select-Variant $a $arch
        $already = Test-Installed $a.id
        # 运行环境类条目用真实检测结果判断，不能靠「已安装程序」列表（它们不在那里登记）
        if ($a.runtimeCheck) {
            switch ([string]$a.runtimeCheck) {
                "webview2" { $already = $wv2.ok }
                "vcredist" { $already = $vc.ok }
                "netfx"    { $already = $nfx.ok }
                default    { $already = $false }
            }
        }
        $note = ""

        if ($a.variants.Count -eq 0) {
            # install 字段优先：web / npm / pip 是「官方就该这样装」，不是缺文件
            if ($a.install -eq "npm")     { $st = "npm 安装"; $color = "White"; $note = "官方走 npm，无直链包（需 Node.js）" }
            elseif ($a.install -eq "pip") { $st = "pip 安装"; $color = "White"; $note = "官方走 pip，无直链包（需 Python）" }
            elseif ($a.install -eq "web") { $st = "官网下载"; $color = "White"; $note = "官网直下，无固定直链" }
            else                          { $st = "无桌面版"; $color = "DarkGray"; $note = "只有命令行" }
            $noCount++
        } elseif (-not $pick) {
            $st = "装不了"; $color = "Red"; $note = "无适配版本"
            $noCount++
        } elseif ($pick.mode -eq "emulated") {
            $st = "可装(模拟)"; $color = "Yellow"; $note = "无原生版，走 x64 模拟"
            $emuCount++
        } elseif ($pick.mode -eq "assumed") {
            $st = "按 x64"; $color = "Yellow"; $note = "架构检测失败，请人工确认"
            $assumedCount++
        } else {
            $st = "可装"; $color = "Green"
            # 运行库和开发环境不算「软件」，不计入能装数量，否则结论会虚高
            if (-not $a.runtimeCheck -and $a.kind -ne "env") { $okCount++ }
        }

        if ($already) { $note = ($note + " 已安装").Trim() }
        if ($a.recommend) { $note = ("推荐；" + $note).TrimEnd("；") }

        $vArch = "-"; $vSize = "-"; $vFmt = "-"
        if ($pick) {
            $vArch = $pick.v.arch
            if ($pick.v.size) { $vSize = $pick.v.size }
            $vFmt = Get-FormatLabel $pick.v.format
            if ($pick.formats -gt 1) { $vFmt = $vFmt + "+" + ($pick.formats - 1) }
            if ($pick.v.size -match "([\d\.]+)\s*MB") { $totalMB += [double]$Matches[1] }
        }

        Out-Line ((Pad $i 6) + (Pad $a.name 28) + (Pad $vArch 8) + (Pad $vFmt 14) + (Pad $vSize 12) + (Pad $st 14) + $note) $color
        if ($a.audience) { Out-Line ("      适合：" + $a.audience) DarkGray }
        if ($a.reason) { Out-Line ("      用途：" + $a.reason) DarkGray }

        if ($pick) {
            $url = ""
            if ($pick.v.urls -and @($pick.v.urls).Count -gt 0) { $url = @($pick.v.urls)[0] }
            [void]$dlLines.Add([pscustomobject]@{
                idx    = $i
                name   = $a.name
                arch   = $pick.v.arch
                fmt    = (Get-FormatLabel $pick.v.format)
                fmts   = $pick.formats
                size   = $vSize
                file   = $pick.v.file
                dir    = $a.dir
                url    = $url
                page   = $a.page
            })
        }
        $i++
    }
    Out-Line ""
}

Out-Line ("─" * 62) DarkGray
Out-Line ""

# --- 结论 ---
Out-Line ("─" * 62)
Out-Line "  结论"
Out-Line ("─" * 62)

$totalGB = [math]::Round($totalMB / 1024, 2)
if ($arch -eq "x86") {
    Out-Line ("  ✗ 本机是 32 位系统，这 " + $Apps.Count + " 个软件一个都装不了。") Red
    Out-Line "    要么换机器，要么先把系统重装成 64 位。" Gray
} else {
    Out-Line ("  ✓ 可安装软件：" + $okCount + " 个（原生版本）") Green
    $envCount = @($Apps | Where-Object { $_.runtimeCheck -or $_.kind -eq "env" }).Count
    if ($envCount -gt 0) {
        Out-Line ("  + 运行环境 / 开发环境：" + $envCount + " 项（可选，见上面两个分组）") DarkGray
    }
    if ($emuCount -gt 0) { Out-Line ("  ~ 能装但走模拟：" + $emuCount + " 个（ARM 机器跑 x64，会慢一点）") Yellow }
    if ($assumedCount -gt 0) { Out-Line ("  ? 按 x64 建议：" + $assumedCount + " 个（架构检测失败，请人工确认）") Yellow }
    if ($noCount -gt 0) { Out-Line ("  - 装不了/没有桌面版：" + $noCount + " 个") DarkGray }
    Out-Line ("  合计需要下载约 " + $totalGB + " GB，硬盘至少要留 " + [math]::Round($totalGB * 1.6, 1) + " GB（含安装解压空间）") White
    if (-not $wv2.ok -or -not $vc.ok) {
        Out-Line "  ! 本机缺运行库（上面【运行环境】标黄的项），建议先装好再装软件，" Yellow
        Out-Line "    否则 CC Switch 这类应用可能出现白屏、双击没反应。" Yellow
    }
    if ($freeC -gt 0 -and $freeC -lt ($totalGB * 1.6)) {
        Out-Line ("  ⚠ C 盘只剩 " + $freeC + " GB，空间可能不够，建议先清理") Red
    }
}

if ($mem -gt 0 -and $mem -lt 8) {
    Out-Line ("  ⚠ 内存只有 " + $mem + " GB，同时开多个客户端可能卡，建议一次只开一个") Yellow
}

Out-Line ""

# --- 下载清单 ---
if ($dlLines.Count -gt 0 -and $arch -ne "x86") {
    Out-Line ("─" * 62)
    Out-Line "  下载清单（按本机架构选好的版本）"
    Out-Line ("─" * 62)
    foreach ($d in $dlLines) {
        $fmtTag = $d.fmt
        if ($d.fmts -gt 1) { $fmtTag = $fmtTag + "（另有 " + ($d.fmts - 1) + " 种格式可选）" }
        Out-Line ("  " + $d.idx + ". " + $d.name + "   [" + $d.arch + ", " + $d.size + "]  " + $fmtTag) Cyan
        Out-Line ("     保存为：" + $d.file) Gray
        if ($d.dir) { Out-Line ("     放到  ：安装包/" + $d.dir + "/") Gray }
        if ($d.url) { Out-Line ("     直链  ：" + $d.url) DarkGray }
        if ($d.page) { Out-Line ("     官网  ：" + $d.page) DarkGray }
    }
    Out-Line ""
    Out-Line "  （放好安装包后，双击「双击启动.bat」就会显示「已就绪」，点一下直接装，不用联网）" DarkGray
    Out-Line ""
}

Out-Line ("─" * 62)
Out-Line "  下一步怎么做"
Out-Line ("─" * 62)
Out-Line "  1. 把本报告发给卖家（或自己对照），按上面「下载清单」下载对应版本"
Out-Line "  2. 下载好的文件放进「安装包」里对应的软件文件夹"
Out-Line "  3. 双击「双击启动.bat」，软件显示「已就绪」后点一下就直接安装"
Out-Line ""

Out-Line ("─" * 62)
Out-Line ("  检测时间：" + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
Out-Line ("─" * 62)

# ---------- 写报告文件 ----------
try {
    $Report -join "`r`n" | Set-Content -Path $OutFile -Encoding UTF8
    if (-not $Quiet) {
        Write-Host ""
        Write-Host ("  报告已保存：" + $OutFile) -ForegroundColor DarkGray
        Write-Host "  可以把「本机检测报告.txt」发给卖家，对方就知道该给你哪个版本。" -ForegroundColor DarkGray
    }
} catch { }

if (-not $NoPause -and -not $Quiet) {
    Write-Host ""
    Write-Host "  按任意键关闭..." -ForegroundColor DarkGray
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch { Start-Sleep -Seconds 5 }
}
