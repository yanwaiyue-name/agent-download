#Requires -Version 5.1
<#
    sources.json data validation + script syntax check
    Usage:
      powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1
      powershell -ExecutionPolicy Bypass -File .\scripts\verify.ps1 -SkipSyntax
    Exit code: 0 pass, 1 error
#>
param(
    [switch]$SkipSyntax
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$JsonPath = Join-Path $Root 'sources.json'

$errors   = New-Object System.Collections.ArrayList
$warnings = New-Object System.Collections.ArrayList

function Ok($m)   { Write-Host ('  OK   ' + $m) -ForegroundColor Green }
function Bad($m)  { Write-Host ('  ERR  ' + $m) -ForegroundColor Red;    [void]$errors.Add($m) }
function Warn($m) { Write-Host ('  WARN ' + $m) -ForegroundColor Yellow; [void]$warnings.Add($m) }
function Head($m) { Write-Host ''; Write-Host $m -ForegroundColor Cyan }

Write-Host ''
Write-Host '==============================================================' -ForegroundColor Magenta
Write-Host '  sources.json data validation' -ForegroundColor Magenta
Write-Host '==============================================================' -ForegroundColor Magenta

Head '[1/6] parse sources.json'
if (-not (Test-Path $JsonPath)) {
    Bad 'sources.json not found'
    exit 1
}
try {
    $raw = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8)
    $cfg = $raw | ConvertFrom-Json
    $appCount = @($cfg.apps).Count
    Ok ('JSON valid, apps = ' + $appCount)
} catch {
    Bad ('JSON parse failed: ' + $_.Exception.Message)
    exit 1
}

Head '[2/6] required fields'
$required = @('id', 'name', 'group', 'desc', 'dir', 'arch')
foreach ($a in @($cfg.apps)) {
    foreach ($f in $required) {
        if (-not $a.$f) { Bad ($a.id + ' missing field: ' + $f) }
    }
    $vs = @($a.variants)
    $ms = @($a.mac)
    if ($vs.Count -eq 0 -and $ms.Count -eq 0) {
        # 合法情况：走官网下载或包管理器安装（npm / pip）的项目本来就没有直链二进制
        # 判定依据：必须提供 page 字段，且 install 或 tip 说明安装方式
        $isWebOrPm = ($a.install -eq 'web' -or $a.install -eq 'npm' -or $a.install -eq 'pip')
        if ($isWebOrPm -and $a.page) {
            Ok ($a.id + ' -> ' + $a.install + ' install (no binary, by design)')
        } elseif (-not $a.page) {
            Bad ($a.id + ': no variants AND no page link')
        } else {
            Warn ($a.id + ': no variants, install type not declared (add "install": "web|npm|pip")')
        }
    }
}
if ($errors.Count -eq 0) { Ok 'all app fields present' }

Head '[3/6] dir constraints (no slash, no illegal char, Chinese allowed)'
foreach ($a in @($cfg.apps)) {
    $d = [string]$a.dir
    if ($d.Contains([char]92) -or $d.Contains([char]47)) {
        Bad ($a.id + ' dir contains slash: ' + $d)
    }
    $illegal = @([char]60, [char]62, [char]58, [char]34, [char]124, [char]63, [char]42)
    foreach ($ch in $illegal) {
        if ($d.IndexOf($ch) -ge 0) {
            Bad ($a.id + ' dir contains illegal char: ' + $d)
            break
        }
    }
    if ($d -ne $d.Trim()) { Warn ($a.id + ' dir has leading/trailing space: ' + $d) }
}
Ok 'dir check done'

Head '[4/6] file extension vs format'
$extOk = @{
    'msi'      = @('.msi')
    'setup'    = @('.exe', '.pkg', '.dmg')
    'store'    = @('.exe', '.msix', '.msixbundle', '.appx')
    'portable' = @('.exe')
    'zip'      = @('.zip', '.7z', '.rar', '.tar', '.gz')
    'dmg'      = @('.dmg')
    'sums'     = @('.txt')
}
$fmtChecked = 0
foreach ($a in @($cfg.apps)) {
    $all = @()
    $all += @($a.variants)
    $all += @($a.mac)
    foreach ($v in $all) {
        if ($null -eq $v) { continue }
        $fmt  = [string]$v.format
        $file = [string]$v.file
        if (-not $file) { Bad ($a.id + ' has variant without file'); continue }
        if (-not $extOk.ContainsKey($fmt)) {
            Bad ($a.id + ' invalid format: ' + $fmt)
            continue
        }
        $fmtChecked++
        $ext = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
        if ($extOk[$fmt] -notcontains $ext) {
            Warn ($a.id + ': format=' + $fmt + ' but file is ' + $ext + ' (' + $file + ')')
        }
    }
}
Ok ('extension check done, ' + $fmtChecked + ' entries')

Head '[5/6] filename uniqueness and url scheme'
$seen = @{}
foreach ($a in @($cfg.apps)) {
    $all = @()
    $all += @($a.variants)
    $all += @($a.mac)
    foreach ($v in $all) {
        if ($null -eq $v) { continue }
        $file = [string]$v.file
        if (-not $file) { continue }
        $key = [string]$a.id + '|' + $file
        if ($seen.ContainsKey($key)) {
            Warn ('duplicate file within same app: ' + $file + ' (' + $a.id + ')')
        } else {
            $seen[$key] = $a.id
        }
        foreach ($u in @($v.urls)) {
            if (-not $u) { continue }
            if (-not $u.StartsWith('https://')) { Bad ($a.id + ' url not https: ' + $u) }
        }
    }
}
Ok ('file entries = ' + $seen.Count)

# app id 唯一性：Web 服务的 /dl 路由和启动器缓存都按 id 索引，重复 id 会静默错乱
Head '[5.5/6] app id uniqueness'
$idSeen = @{}
$idDup = 0
foreach ($a in @($cfg.apps)) {
    $id = [string]$a.id
    if (-not $id) { continue }
    if ($idSeen.ContainsKey($id)) {
        Bad ('duplicate app id: ' + $id)
        $idDup++
    } else {
        $idSeen[$id] = $true
    }
}
if ($idDup -eq 0) { Ok ($idSeen.Count.ToString() + ' app ids all unique') }

# sha256 字段：格式必须合法，否则 launcher 的比对会永远失败，把所有下载都判成"哈希不符"。
Head '[5.7/6] sha256 fields'
$shaTotal = 0; $shaBad = 0; $shaMissing = 0
foreach ($a in @($cfg.apps)) {
    foreach ($key in @('variants', 'mac')) {
        $list = @($a.$key)
        if (-not $list) { continue }
        foreach ($v in $list) {
            if ($null -eq $v) { continue }
            $shaTotal++
            $s = [string]$v.sha256
            if (-not $s) { $shaMissing++; continue }
            if ($s -notmatch '^[0-9a-f]{64}$') {
                Bad ('bad sha256 for ' + $a.id + ' / ' + $v.file + ': ' + $s)
                $shaBad++
            }
        }
    }
}
if ($shaBad -eq 0) {
    Ok ('sha256 format OK; ' + ($shaTotal - $shaMissing).ToString() + '/' + $shaTotal.ToString() + ' entries pinned')
    if ($shaMissing -gt 0) {
        Warn ($shaMissing.ToString() + ' entries have no sha256 yet — run scripts/update-hashes.ps1 to pin them')
    }
}

if (-not $SkipSyntax) {
    Head '[6/6] PowerShell syntax and BOM'
    $psFiles = @(Get-ChildItem -Path $Root -Recurse -Filter '*.ps1' -File -ErrorAction SilentlyContinue)

    $bomFail = 0
    foreach ($f in $psFiles) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $hasBom = $false
        if ($bytes.Length -ge 3) {
            if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) { $hasBom = $true }
        }
        if (-not $hasBom) {
            Bad ('missing UTF-8 BOM: ' + $f.Name)
            $bomFail++
        }
    }
    if ($bomFail -eq 0) { Ok ($psFiles.Count.ToString() + ' ps1 files all have BOM') }

    $syntaxFail = 0
    foreach ($f in $psFiles) {
        $e = @()
        [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$e)
        if ($e.Count -gt 0) {
            Bad ('syntax error in ' + $f.Name + ': ' + $e[0].Message)
            $syntaxFail++
        }
    }
    if ($syntaxFail -eq 0) { Ok ($psFiles.Count.ToString() + ' ps1 files syntax OK') }
} else {
    Head '[6/6] syntax check skipped'
}

Write-Host ''
Write-Host '==============================================================' -ForegroundColor Magenta
if ($errors.Count -eq 0) {
    Write-Host ('  PASS   errors=0  warnings=' + $warnings.Count) -ForegroundColor Green
    Write-Host '==============================================================' -ForegroundColor Magenta
    Write-Host ''
    exit 0
} else {
    Write-Host ('  FAIL   errors=' + $errors.Count + '  warnings=' + $warnings.Count) -ForegroundColor Red
    Write-Host '==============================================================' -ForegroundColor Magenta
    Write-Host ''
    exit 1
}