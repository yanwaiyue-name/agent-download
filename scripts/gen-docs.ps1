#Requires -Version 5.1
<#
    从 sources.json 生成「软件推荐与官方下载地址.txt」
    （图形界面「官方下载地址」弹窗和离线用户的数据源）

    用法：powershell -ExecutionPolicy Bypass -File .\scripts\gen-docs.ps1
    改 sources.json 之后跑一次，或在 更新.ps1 里加 -GenDocs。

    说明：本文件全部条目数据自动生成；「格式怎么选 / 按架构选择 / 下载后」
    三个说明块是固定文案，随脚本维护。
#>
param(
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$JsonPath = Join-Path $Root 'sources.json'
$OutPath  = Join-Path $Root '软件推荐与官方下载地址.txt'

$cfg = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$apps = @($cfg.apps)
$groups = @($apps | ForEach-Object { $_.group } | Select-Object -Unique)

$fmtLabel = @{ setup = '安装版'; msi = 'MSI'; store = '商店版'; portable = '免安装'; zip = '压缩包'; dmg = 'dmg' }
$installLabel = @{ npm = 'npm 安装'; pip = 'pip 安装'; web = '官网下载' }

function Join-Cn($arr) { return ($arr -join '、') }

# 每个应用的一行「格式」描述
function Get-FmtLine($a) {
    if ($a.install) {
        return "    格式：无 Windows 直链安装包，官方发布方式为「" + $installLabel[[string]$a.install] + "」。"
    }
    $winArchParts = @()
    foreach ($arch in @('x64', 'arm64')) {
        $fmts = @($a.variants | Where-Object { $_.arch -eq $arch } | ForEach-Object { $fmtLabel[[string]$_.format] } | Select-Object -Unique)
        if ($fmts.Count -gt 0) { $winArchParts += ($arch + "：" + (Join-Cn $fmts)) }
    }
    $parts = @()
    if ($winArchParts.Count -gt 0) { $parts += ("Windows——" + (Join-Cn $winArchParts)) }
    if (@($a.mac).Count -gt 0) {
        $macArches = @($a.mac | ForEach-Object { $_.arch } | Select-Object -Unique)
        $macDesc = if ($macArches -contains 'any') { "通用 dmg" } else { "dmg（" + (Join-Cn $macArches) + "）" }
        $parts += ("macOS——" + $macDesc)
    }
    if ($parts.Count -eq 0) { return "    格式：无桌面安装包。" }
    return "    格式：" + ($parts -join "；") + "。"
}

$L = New-Object System.Collections.ArrayList

# ---------- 头部 ----------
[void]$L.Add('========================================')
[void]$L.Add('  AI 桌面下载中心 · 推荐软件与官方下载地址')
[void]$L.Add('========================================')
[void]$L.Add('')
[void]$L.Add(('更新时间：' + $cfg.updated + '    清单版本 v' + $cfg.version + '    共 ' + $apps.Count + ' 项 / ' + $groups.Count + ' 个分组'))
[void]$L.Add('本文件由 scripts/gen-docs.ps1 从 sources.json 自动生成，请勿手工编辑。')
[void]$L.Add('')
[void]$L.Add('这个包自带离线安装包（在「安装包」文件夹里），也支持联网补下。')
[void]$L.Add('使用方法：')
[void]$L.Add('  1. 不确定电脑架构时，先双击「双击检测.bat」')
[void]$L.Add('  2. 双击「双击启动.bat」，按编号下载或启动安装')
[void]$L.Add('  3. 同一软件有多种格式时，按提示选一种（回车 = 默认格式）')
[void]$L.Add('  4. 自动下载失败时，可从本文件的“官网”或“当前直链”手动下载')
[void]$L.Add('')

# ---------- 推荐区 ----------
[void]$L.Add('【全部软件一览】')
[void]$L.Add('')
foreach ($g in $groups) {
    [void]$L.Add($g)
    [void]$L.Add('')
    foreach ($a in @($apps | Where-Object { $_.group -eq $g })) {
        $star = if ($a.recommend) { ' ⭐推荐' } else { '' }
        [void]$L.Add(('  ' + $a.name + $star))
        if ($a.audience) { [void]$L.Add(('    适合：' + $a.audience)) }
        if ($a.reason)   { [void]$L.Add(('    用途：' + $a.reason)) }
        [void]$L.Add((Get-FmtLine $a))
        if ($a.needProxy) { [void]$L.Add('    注意：官方源在国内直连不稳，可能需要代理。') }
        [void]$L.Add('')
    }
}

# ---------- 格式说明（固定文案） ----------
[void]$L.Add('【格式怎么选】')
[void]$L.Add('')
[void]$L.Add('  安装版    双击装到系统里，装完开始菜单有图标。绝大多数人选这个。')
[void]$L.Add('  MSI       系统级安装包，适合公司电脑批量部署 / 域环境推送。')
[void]$L.Add('  免安装    单个 exe，双击就能用，不写注册表，拷到 U 盘就能带走。')
[void]$L.Add('  压缩包    解压后双击里面的 exe，不用安装（zip 直接右键解压；7z 需要装 7-Zip）。')
[void]$L.Add('  商店版    微软商店引导器，双击后要联网拉完整应用（目前只有 ChatGPT 这样）。')
[void]$L.Add('')
[void]$L.Add('  同一软件选哪种都能用，功能一样，差别只在“装进系统”还是“绿色免安装”。')
[void]$L.Add('')

# ---------- 直链区 ----------
[void]$L.Add('【官方下载页和当前直链】')
[void]$L.Add('')
$i = 0
foreach ($a in $apps) {
    $i++
    $indent = if ($i -ge 10) { ' ' } else { '  ' }
    [void]$L.Add('')
    [void]$L.Add($i.ToString() + '. ' + $a.name)
    if ($a.page)   { [void]$L.Add($indent + '官网：' + $a.page) }
    if ($a.github) { [void]$L.Add($indent + '官方 Release：https://github.com/' + $a.github + '/releases') }
    foreach ($v in @($a.variants)) {
        if (-not $v) { continue }
        [void]$L.Add($indent + 'Windows ' + $v.arch + ' ' + $fmtLabel[[string]$v.format] + '（' + $v.size + '）：')
        foreach ($u in @($v.urls)) { [void]$L.Add($indent + '  ' + $u) }
    }
    foreach ($m in @($a.mac)) {
        if (-not $m) { continue }
        $mDesc = if ($m.arch -eq 'any') { '通用' } else { $m.arch }
        [void]$L.Add($indent + 'macOS ' + $mDesc + ' dmg（' + $m.size + '）：')
        foreach ($u in @($m.urls)) { [void]$L.Add($indent + '  ' + $u) }
    }
    if ($a.install -and -not @($a.variants).Count) {
        [void]$L.Add($indent + '无直链安装包，安装方式：' + $installLabel[[string]$a.install] + '（见官网指引）。')
    }
    if ($a.tip) { [void]$L.Add($indent + '注意：' + $a.tip) }
}

# ---------- 架构与收尾（固定文案） ----------
[void]$L.Add('')
[void]$L.Add('【按 Windows 架构选择】')
[void]$L.Add('')
[void]$L.Add('  Intel / AMD 普通电脑：选择 x64')
[void]$L.Add('  骁龙 / 麒麟等 Windows ARM 电脑：优先选 ARM64；没有 ARM64 的软件可使用 x64 模拟运行')
[void]$L.Add('  32 位 Windows（x86）：本清单中的桌面软件均无适配版本')
[void]$L.Add('')
[void]$L.Add('【下载后】')
[void]$L.Add('')
[void]$L.Add('启动器下载的文件会放在「下载」文件夹，可以重复安装或留作备份。')
[void]$L.Add('如果这个包里带有「安装包」文件夹，里面的文件已经是放好的，')
[void]$L.Add('启动器会优先使用本地文件，显示「已就绪」后点一下就能装，不用联网。')
[void]$L.Add('「安装包\<软件名>\mac\」里的 dmg 是给 Mac 用的，Windows 上用不到。')
[void]$L.Add('')
[void]$L.Add('请从以上官网或官方 Release 页面确认软件来源。Windows 对未签名安装包可能显示提示；')
[void]$L.Add('请先核对下载页面、文件名和发布者，再决定是否继续安装。')

[System.IO.File]::WriteAllLines($OutPath, $L, (New-Object System.Text.UTF8Encoding($false)))
if (-not $Quiet) {
    Write-Host ('生成完成：' + $OutPath + '  共 ' + $apps.Count + ' 项') -ForegroundColor Green
}
