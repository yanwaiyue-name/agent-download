#Requires -Version 7.0
<#
.SYNOPSIS
  刷新 sources.json 里每个安装包的官方 SHA256。

.DESCRIPTION
  为什么要有这个脚本：
    launcher.ps1 下载完会拿 sources.json 里的 sha256 去比对，对不上就删文件重试。
    所以哈希必须跟着版本走 —— 版本一升，旧哈希就全错，用户会被误拦。

  取哈希的两条路（按优先级）：
    1. 上游官方校验清单（SHA256SUMS.txt / SHASUMS256.txt / sha256.sum 等）——
       这是最可信的来源，谁也没法替上游伪造；
    2. 没有清单就整包下载后自己算 —— 只能证明"当时下到的是什么"，
       属于自己给自己作证，所以会在报告里单独标出来。

  用法：
    pwsh -File ./scripts/update-hashes.ps1              # 只补缺失的
    pwsh -File ./scripts/update-hashes.ps1 -Force       # 全部重算
    pwsh -File ./scripts/update-hashes.ps1 -Proxy http://127.0.0.1:7897
#>
param(
    [switch]$Force,
    [string]$Proxy = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$jsonPath = Join-Path $root 'sources.json'

if ($Proxy) {
    $env:HTTPS_PROXY = $Proxy
    $env:HTTP_PROXY  = $Proxy
}

$cfg = [System.IO.File]::ReadAllText($jsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -AsHashtable
$UA = 'agent-download-hash/1.0'
$checkNames = @('SHA256SUMS.txt', 'SHASUMS256.txt', 'sha256.sum', 'SHA256SUMS', 'checksums.txt', 'SHA256.txt', 'sha256sums.txt', 'sha256sum.txt')

function Get-UpstreamHash([string]$Url, [string]$FileName) {
    if ($Url -notmatch '/releases/download/') { return $null }
    $base = $Url.Substring(0, $Url.LastIndexOf('/') + 1)
    foreach ($n in $checkNames) {
        try {
            $body = (Invoke-WebRequest -Uri ($base + $n) -Headers @{ 'User-Agent' = $UA } -TimeoutSec 45 -ErrorAction Stop).Content
        } catch { continue }
        if (-not $body -or $body.Length -gt 500000) { continue }
        foreach ($line in ($body -split "`n")) {
            if ($line -notlike ('*' + $FileName + '*')) { continue }
            $m = [regex]::Match($line, '([0-9a-fA-F]{64})')
            if ($m.Success) { return @{ Hash = $m.Groups[1].Value.ToLowerInvariant(); Source = 'upstream:' + $n } }
        }
    }
    return $null
}

function Get-DownloadedHash([string]$Url) {
    $tmp = [System.IO.Path]::GetTempFileName()
    try {
        Invoke-WebRequest -Uri $Url -Headers @{ 'User-Agent' = $UA } -OutFile $tmp -TimeoutSec 1200 -ErrorAction Stop
        return @{ Hash = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant(); Source = 'downloaded' }
    } catch {
        Write-Host ('    ! 下载失败：' + $_.Exception.Message) -ForegroundColor DarkYellow
        return $null
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue }
    }
}

$updated = 0; $skipped = 0; $failed = 0
$rows = New-Object System.Collections.ArrayList

foreach ($app in $cfg['apps']) {
    foreach ($key in @('variants', 'mac')) {
        if (-not $app.ContainsKey($key) -or -not $app[$key]) { continue }
        foreach ($v in @($app[$key])) {
            $url = @($v['urls'])[0]
            if (-not $url) { continue }
            if (-not $Force -and $v['sha256']) { $skipped++; continue }

            $fname = ($url -split '?')[0]
            $fname = $fname.Substring($fname.LastIndexOf('/') + 1)
            Write-Host ('  ' + $app['id'] + ' / ' + $v['file']) -NoNewline

            $got = Get-UpstreamHash $url $fname
            if ($null -eq $got) { $got = Get-DownloadedHash $url }
            if ($null -eq $got) {
                Write-Host '  FAIL' -ForegroundColor Red
                $failed++
                continue
            }
            $v['sha256'] = $got['Hash']
            $updated++
            $tag = if ($got['Source'] -eq 'downloaded') { '已下载计算（非官方清单）' } else { $got['Source'] }
            Write-Host ('  ' + $got['Hash'].Substring(0, 12) + '  ' + $tag) -ForegroundColor Green
            [void]$rows.Add(('| {0} | {1} | {2} |' -f $app['id'], $v['file'], $tag))
        }
    }
}

$cfg['updated'] = (Get-Date).ToString('yyyy-MM-dd')
[System.IO.File]::WriteAllText($jsonPath, ($cfg | ConvertTo-Json -Depth 12), (New-Object System.Text.UTF8Encoding($false)))

Write-Host ''
Write-Host ('  更新 ' + $updated + ' 个，跳过 ' + $skipped + ' 个，失败 ' + $failed + ' 个') -ForegroundColor Cyan
Write-Host '  下一步：跑 ./scripts/verify.ps1 确认数据结构没坏，再提交。' -ForegroundColor DarkGray
