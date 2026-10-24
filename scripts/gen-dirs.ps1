# =============================================================
#  生成「安装包」子目录（给卖家自己用，不随包发给买家）
#  用法：powershell -ExecutionPolicy Bypass -File .\gen-dirs.ps1
#  作用：按 sources.json 给每个应用建独立文件夹，
#        并在每个文件夹里写一份「放这里.txt」，说明该放哪个文件、从哪下
#  可以重复运行，不会删掉已放进去的安装包
# =============================================================

param(
    [switch]$Force
)

$ErrorActionPreference = "Continue"

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$JsonPath = Join-Path $Root "sources.json"
$PkgRoot = Join-Path $Root "安装包"
$DlRoot  = Join-Path $Root "下载"

if (-not (Test-Path $JsonPath)) {
    Write-Host "找不到 sources.json" -ForegroundColor Red
    exit 1
}

$raw  = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8)
$cfg  = $raw | ConvertFrom-Json
$Apps = @($cfg.apps)

function Ensure-Dir($p) {
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-Host ("  新建  " + $p) -ForegroundColor Green
    }
}

# ---------- 生成单个文件夹的说明文件 ----------
$FormatLabel = @{ "msi" = "MSI 安装包"; "setup" = "安装版 exe"; "store" = "微软商店引导器"; "portable" = "免安装单文件"; "zip" = "免安装压缩包"; "dmg" = "macOS 磁盘映像" }

# ---------- 多个应用共用一个目录时的合并说明 ----------
# 典型情况：「运行环境」目录里同时放 WebView2 和 VC++ 运行库。
# 如果按应用逐个写 放这里.txt，后写的会把先写的覆盖掉，只剩最后一个应用的信息。
function Build-ReadmeMulti($apps, $dirName) {
    $L = New-Object System.Collections.ArrayList
    $bar = "=" * 56

    [void]$L.Add($bar)
    [void]$L.Add("  " + $dirName + "  ·  安装包存放位置")
    [void]$L.Add($bar)
    [void]$L.Add("")
    [void]$L.Add("这个文件夹里是 " + $apps.Count + " 个安装包，都放到本文件夹下：")
    [void]$L.Add("")
    foreach ($a in $apps) { [void]$L.Add("    · " + $a.name) }
    [void]$L.Add("")

    $n = 1
    foreach ($a in $apps) {
        [void]$L.Add("【" + $n + "】" + $a.name)
        [void]$L.Add("")
        if ($a.desc) { [void]$L.Add("    用途：" + $a.desc) }
        foreach ($v in @($a.variants)) {
            [void]$L.Add("    文件名：" + $v.file)
            if ($v.size) { [void]$L.Add("    大小  ：" + $v.size) }
            $urls = @($v.urls)
            if ($urls.Count -gt 0) { [void]$L.Add("    下载  ：" + $urls[0]) }
        }
        if ($a.tip) {
            [void]$L.Add("    提示  ：" + $a.tip)
        }
        [void]$L.Add("")
        $n++
    }

    [void]$L.Add("【放好之后】")
    [void]$L.Add("")
    [void]$L.Add("  回到上一层文件夹，双击「双击启动.bat」，")
    [void]$L.Add("  这些条目会显示「已就绪」，点一下就能装，全程不联网。")
    [void]$L.Add("")
    [void]$L.Add("【注意】")
    [void]$L.Add("")
    [void]$L.Add("  文件名必须完全一致，大小写和空格都算。")
    [void]$L.Add("")

    return ($L -join "`r`n")
}

function Build-Readme($app) {
    $L = New-Object System.Collections.ArrayList
    $bar = "=" * 56

    [void]$L.Add($bar)
    [void]$L.Add("  " + $app.name + "  ·  安装包存放位置")
    [void]$L.Add($bar)
    [void]$L.Add("")

    $vs = @($app.variants)

    if ($vs.Count -eq 0) {
        [void]$L.Add("这个文件夹留空即可 —— 该应用没有桌面安装包。")
        [void]$L.Add("")
        if ($app.tip) {
            [void]$L.Add("  安装方式（命令行）：")
            [void]$L.Add("    " + $app.tip)
            [void]$L.Add("")
        }
        return ($L -join "`r`n")
    }

    [void]$L.Add("这个文件夹只放 " + $app.name + " 的安装包，")
    [void]$L.Add("其它软件的包请放到各自的文件夹里，不要混在一起。")
    [void]$L.Add("")

    [void]$L.Add("【该放哪些文件】")
    [void]$L.Add("")

    foreach ($v in $vs) {
        $archName = $v.arch
        switch ($v.arch) {
            "x64"   { $archName = "Windows x64（Intel / AMD，最常见的电脑）" }
            "arm64" { $archName = "Windows ARM64（骁龙 / 麒麟等 ARM 芯片）" }
            "any"   { $archName = "任意架构" }
        }
        $fmtName = $v.format
        if ($FormatLabel.ContainsKey([string]$v.format)) { $fmtName = $FormatLabel[[string]$v.format] }
        [void]$L.Add("  " + $archName + "  ·  " + $fmtName)
        [void]$L.Add("    文件名：" + $v.file)
        if ($v.size) { [void]$L.Add("    大小  ：" + $v.size) }
        $urls = @($v.urls)
        if ($urls.Count -gt 0) {
            [void]$L.Add("    下载  ：" + $urls[0])
        } elseif ($app.page) {
            [void]$L.Add("    下载  ：" + $app.page + "  （打开页面手动下载）")
        }
        [void]$L.Add("")
    }

    $macs = @($app.mac)
    if ($macs.Count -gt 0) {
        [void]$L.Add("【macOS 包】放到本文件夹下的 mac\ 子目录")
        [void]$L.Add("")
        foreach ($m in $macs) {
            [void]$L.Add("  macOS " + $m.arch + "  ·  dmg")
            [void]$L.Add("    文件名：mac\" + $m.file)
            if ($m.size) { [void]$L.Add("    大小  ：" + $m.size) }
            $urls = @($m.urls)
            if ($urls.Count -gt 0) { [void]$L.Add("    下载  ：" + $urls[0]) }
            [void]$L.Add("")
        }
        [void]$L.Add("  mac\ 里的包 Windows 启动器不会读，只用于给 Mac 客户单独发。")
        [void]$L.Add("  打包脚本默认不带上它们，需要时用 打包.ps1 -Mac。")
        [void]$L.Add("")
    }

    if ($vs.Count -gt 1) {
        [void]$L.Add("【重要】同一个架构有多种格式时，文件名不同，可以全部放进来，")
        [void]$L.Add("        安装器会让你选装哪一种（默认选 MSI / 安装版）。")
        [void]$L.Add("")
    }

    if ($app.tip) {
        [void]$L.Add("【提示】")
        [void]$L.Add("  " + $app.tip)
        [void]$L.Add("")
    }

    [void]$L.Add("【放好之后】")
    [void]$L.Add("")
    [void]$L.Add("  回到上一层文件夹，双击「双击启动.bat」，")
    [void]$L.Add("  这个应用会显示「已就绪」，点一下就能装，全程不联网。")
    [void]$L.Add("")
    [void]$L.Add("【注意】")
    [void]$L.Add("")
    [void]$L.Add("  文件名必须完全一致，大小写和空格都算。")
    [void]$L.Add("  改名不对的话，安装器会以为没准备好，又去联网下载。")
    [void]$L.Add("")

    return ($L -join "`r`n")
}

# ---------- 主流程 ----------
Write-Host ""
Write-Host "==============================================================" -ForegroundColor Magenta
Write-Host "  生成安装包子目录" -ForegroundColor Magenta
Write-Host "==============================================================" -ForegroundColor Magenta
Write-Host ""

Ensure-Dir $PkgRoot
Ensure-Dir $DlRoot

# 按目录分组：多个应用可能共用一个目录（例如「运行环境」里的三个运行库），
# 这种目录只写一份说明，把所有应用都列进去，否则后写的会覆盖先写的。
$dirGroups = @{}
$dirOrder  = New-Object System.Collections.ArrayList
foreach ($a in $Apps) {
    $dirName = $a.dir
    if (-not $dirName) { $dirName = $a.id }
    if (-not $dirGroups.ContainsKey($dirName)) {
        $dirGroups[$dirName] = New-Object System.Collections.ArrayList
        [void]$dirOrder.Add($dirName)
    }
    [void]$dirGroups[$dirName].Add($a)
}

$i = 1
foreach ($dirName in $dirOrder) {
    $group = @($dirGroups[$dirName])

    $pkgSub = Join-Path $PkgRoot $dirName
    $dlSub  = Join-Path $DlRoot  $dirName

    $label = ($group | ForEach-Object { $_.name }) -join " + "
    Write-Host ("[" + $i + "] " + $label + "  ->  安装包/" + $dirName) -ForegroundColor Cyan
    Ensure-Dir $pkgSub
    Ensure-Dir $dlSub
    foreach ($a in $group) {
        if (@($a.mac).Count -gt 0) { Ensure-Dir (Join-Path $pkgSub "mac") }
    }

    $readmePath = Join-Path $pkgSub "放这里.txt"
    if ((Test-Path $readmePath) -and -not $Force) {
        Write-Host ("      说明文件已存在，跳过（要覆盖加 -Force）") -ForegroundColor DarkGray
    } else {
        if ($group.Count -gt 1) {
            $content = Build-ReadmeMulti $group $dirName
        } else {
            $content = Build-Readme $group[0]
        }
        $content | Set-Content -Path $readmePath -Encoding UTF8
        Write-Host ("      已写入 放这里.txt") -ForegroundColor Green
    }
    $i++
}

Write-Host ""
Write-Host "--------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host ("  完成，共 " + $Apps.Count + " 个应用目录") -ForegroundColor Green
Write-Host ("  安装包位置：" + $PkgRoot) -ForegroundColor Gray
Write-Host ""
Write-Host "  接下来：把下载好的 exe 按各自文件夹里的「放这里.txt」放进去，" -ForegroundColor Gray
Write-Host "  然后跑 launcher.ps1 -Check 看是否全部「已就绪」。" -ForegroundColor Gray
Write-Host ""
