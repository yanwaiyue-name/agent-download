#Requires -Version 7.0
<#
    sources.json 版本新鲜度检查：钉死的版本 vs 上游 latest Release
    ------------------------------------------------------------------
    背景：清单里大量 GitHub 条目钉着具体版本（链接里含 v4.0.18 这种 tag），
    或者用 releases/latest/download/ 但文件名里带版本号——上游一发新版，
    旧资产名就从 latest 里消失，链接随之失效。链接检查只能等失效后报警，
    这个脚本在失效之前就发现"上游有新版了"。

    判定（只查带 github 字段的应用）：
      - URL 形如 /releases/download/<tag>/  → 钉住了 tag，与上游 latest tag 比较
      - URL 形如 /releases/latest/download/<文件名> → 从文件名提取版本号比较；
        文件名里提不出版本（如 opencode-desktop-win-x64.exe）→ AUTO（自动跟随 latest，无需关注）
      - 没有 github 字段（官网 CDN / npm / pip / web）→ SKIP

    版本比较：两边都归一化成"去掉前导非数字字符后的字符串"
      （v2.1.7 → 2.1.7；desktop-v0.0.48 → 0.0.48；1.52.0 → 1.52.0）

    用法：
      pwsh -File .\scripts\check-versions.ps1
      pwsh -File .\scripts\check-versions.ps1 -Token ghp_xxx   # 免得撞匿名 API 限额

    退出码：
      0  全部为最新（或有 AUTO / SKIP，不算问题）
      1  存在落后于上游的钉版本（DRIFT）
      2  上游 API 查询失败（网络问题，不是版本问题）
#>
param(
    [string]$Token = $env:GITHUB_TOKEN,
    [int]$TimeoutSec = 20
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$JsonPath = Join-Path $Root 'sources.json'
$ReportPath = Join-Path $Root 'version-report.txt'

$cfg = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

function Get-NormalizedVersion([string]$s) {
    if (-not $s) { return '' }
    return ([string]$s -replace '^[^\d]+', '').Trim()
}

# 从单个 URL 里提取"钉住的版本"：返回 @{ kind='tag'|'file'; raw=... } 或 $null
function Get-PinnedVersion([string]$url) {
    if (-not $url) { return $null }
    if ($url -match '/releases/download/([^/]+)/') { return @{ kind = 'tag'; raw = $Matches[1] } }
    if ($url -match '/releases/latest/download/([^/?]+)') {
        $file = [uri]::UnescapeDataString($Matches[1])
        if ($file -match '(\d+(?:\.\d+)+)') { return @{ kind = 'file'; raw = $Matches[1] } }
        return @{ kind = 'auto' }   # latest 直链且文件名无版本号：自动跟随上游
    }
    return $null
}

$Headers = @{ 'User-Agent' = 'agent-download-version-check' }
if ($Token) { $Headers['Authorization'] = "Bearer $Token" }

$apiFailures = 0
$results = New-Object System.Collections.ArrayList

foreach ($a in @($cfg.apps)) {
    if (-not $a.github) { continue }
    # 个别仓库的 releases/latest 不指向应用本体（如 qwen-code 指向 sdk 子包 tag），
    # 在该条目里写 "versionCheck": "skip" 跳过，避免误报
    if ($a.versionCheck -eq 'skip') {
        [void]$results.Add([pscustomobject]@{ app = $a.id; repo = [string]$a.github; status = 'SKIP'; pinned = ''; latest = '' })
        continue
    }
    $repo = [string]$a.github

    # 上游 latest tag（一次/app，不按 variant 重复查）
    $latestRaw = $null
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" `
            -Headers $Headers -TimeoutSec $TimeoutSec
        $latestRaw = [string]$rel.tag_name
    } catch {
        $apiFailures++
        [void]$results.Add([pscustomobject]@{ app = $a.id; repo = $repo; status = 'API_FAIL'; pinned = ''; latest = '' })
        continue
    }
    $latest = Get-NormalizedVersion $latestRaw

    # 该应用所有 variant / mac 里能提取到的钉版本（同一应用可能全一致，取集合去重）
    $pinned = @{}
    $auto = $false
    foreach ($v in (@($a.variants) + @($a.mac))) {
        if (-not $v) { continue }
        foreach ($u in @($v.urls)) {
            $p = Get-PinnedVersion $u
            if ($null -eq $p) { continue }
            if ($p.kind -eq 'auto') { $auto = $true; continue }
            $nv = Get-NormalizedVersion $p.raw
            if ($nv) { $pinned[$nv] = $true }
        }
    }

    if ($pinned.Count -eq 0) {
        $st = if ($auto) { 'AUTO' } else { 'NO_VERSION' }
        [void]$results.Add([pscustomobject]@{ app = $a.id; repo = $repo; status = $st; pinned = ''; latest = $latestRaw })
        continue
    }

    $drift = @($pinned.Keys | Where-Object { $_ -ne $latest })
    if ($drift.Count -gt 0) {
        [void]$results.Add([pscustomobject]@{ app = $a.id; repo = $repo; status = 'DRIFT'; pinned = ($drift -join ', '); latest = $latestRaw })
    } else {
        [void]$results.Add([pscustomobject]@{ app = $a.id; repo = $repo; status = 'OK'; pinned = ($pinned.Keys -join ', '); latest = $latestRaw })
    }
}

# ---------- 输出 ----------
$ok      = @($results | Where-Object status -eq 'OK')
$drifts  = @($results | Where-Object status -eq 'DRIFT')
$autos   = @($results | Where-Object status -in 'AUTO','NO_VERSION')
$fails   = @($results | Where-Object status -eq 'API_FAIL')

Write-Host ''
Write-Host '==============================================================' -ForegroundColor Magenta
Write-Host ('  版本新鲜度检查  共 ' + $results.Count + ' 个 GitHub 应用') -ForegroundColor Magenta
Write-Host '==============================================================' -ForegroundColor Magenta
Write-Host ''

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('版本新鲜度检查报告')
[void]$lines.Add('生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
[void]$lines.Add('GitHub 应用：' + $results.Count + '   最新：' + $ok.Count + '   落后：' + $drifts.Count + '   自动跟随：' + $autos.Count + '   API 失败：' + $fails.Count)
[void]$lines.Add('')

foreach ($r in $results) {
    switch ($r.status) {
        'OK'   { Write-Host ('  OK    ' + $r.app + '  ' + $r.pinned) -ForegroundColor Green }
        'DRIFT' {
            Write-Host ('  DRIFT ' + $r.app + '  钉住 ' + $r.pinned + '  上游最新 ' + $r.latest) -ForegroundColor Red
            [void]$lines.Add('=== 落后于上游（需更新 sources.json）===')
            [void]$lines.Add('  ' + $r.app + '  repo: ' + $r.repo + '  钉住: ' + $r.pinned + '  上游最新: ' + $r.latest)
            [void]$lines.Add('  同时更新 variants/mac 的文件名、urls、size（用官方页或 API 确认资产名）')
            [void]$lines.Add('')
        }
        'AUTO'       { Write-Host ('  AUTO  ' + $r.app + '  (latest 直链，自动跟随)') -ForegroundColor DarkGray }
        'NO_VERSION' { Write-Host ('  ?     ' + $r.app + '  (URL 里提不出版本号，无法比对)') -ForegroundColor Yellow }
        'API_FAIL'   { Write-Host ('  ???   ' + $r.app + '  (' + $r.repo + ' 查询失败，网络问题)') -ForegroundColor Yellow }
    }
}

[System.IO.File]::WriteAllLines($ReportPath, $lines, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ''
Write-Host ('  最新 ' + $ok.Count + '  /  落后 ' + $drifts.Count + '  /  自动跟随 ' + $autos.Count + '  /  API 失败 ' + $fails.Count) -ForegroundColor Cyan
Write-Host ('  报告已写入 ' + $ReportPath) -ForegroundColor Gray
Write-Host ''

if ($drifts.Count -gt 0) { exit 1 }
if ($fails.Count -gt 0 -and $ok.Count -eq 0) { exit 2 }
exit 0
