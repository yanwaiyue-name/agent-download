#Requires -Version 7.0
<#
.SYNOPSIS
  刷新 sources.json 里每个安装包的官方 SHA256。

.DESCRIPTION
  为什么要有这个脚本：
    launcher.ps1 下载完会拿 sources.json 里的 sha256 去比对，对不上就删文件重试。
    所以哈希必须跟着版本走 —— 版本一升，旧哈希就全错，用户会被误拦。

  ★ 默认只抓上游发布的校验清单（几 KB 的文本），不下载任何安装包。
    上游清单里没写到的条目，这里直接跳过并在末尾列出来 —— 不替你偷偷下 6GB。

  为什么优先清单而不是自己算：
    自己下载后算哈希，只能证明"从我下载到现在这个文件没变"，
    证明不了"它和官方发布的一致"——如果下到的本身就是篡改版，
    自己算出来的值就是篡改版的哈希，自己校验自己永远通过。
    上游清单是作者自己发布的，才构成外部锚点。

  只有明确加 -DownloadMissing 时，才对清单里没有的条目下载安装包并自算，
  且结果会标成「自算（非官方清单）」，可信度低于清单来源。

  用法：
    pwsh -File ./scripts/update-hashes.ps1                       # 只读清单，不下载（推荐）
    pwsh -File ./scripts/update-hashes.ps1 -Proxy http://127.0.0.1:7897
    pwsh -File ./scripts/update-hashes.ps1 -DownloadMissing       # 允许为缺失项下载（慢、占带宽、耗磁盘）
    pwsh -File ./scripts/update-hashes.ps1 -Force                # 连已有哈希也按清单重刷
#>
param(
    [switch]$Force,
    [string]$Proxy = '',
    # 危险开关：允许下载安装包来算哈希。默认关闭，避免无谓的流量与磁盘占用。
    [switch]$DownloadMissing
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

$updated = 0; $skipped = 0; $failed = 0; $noManifest = 0
$rows = New-Object System.Collections.ArrayList

foreach ($app in $cfg['apps']) {
    foreach ($key in @('variants', 'mac')) {
        if (-not $app.ContainsKey($key) -or -not $app[$key]) { continue }
        foreach ($v in @($app[$key])) {
            $url = @($v['urls'])[0]
            if (-not $url) { continue }
            if (-not $Force -and $v['sha256']) { $skipped++; continue }

            # -split 走正则，'?' 在这里是量词会直接报错；去查询串只需要按字符切
            $fname = $url.Split([char]63)[0]
            $fname = $fname.Substring($fname.LastIndexOf('/') + 1)
            Write-Host ('  ' + $app['id'] + ' / ' + $v['file']) -NoNewline

            $got = Get-UpstreamHash $url $fname
            if ($null -eq $got) {
                if (-not $DownloadMissing) {
                    # 默认不下载：上游没发清单就是没发，如实记为"无官方清单"。
                    Write-Host '  —（上游没有校验清单，跳过；要强补加 -DownloadMissing）' -ForegroundColor DarkGray
                    $noManifest++
                    [void]$rows.Add(('| {0} | {1} | — |' -f $app['id'], $v['file']))
                    continue
                }
                $got = Get-DownloadedHash $url
            }
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
Write-Host ('  更新 ' + $updated + ' 个，跳过 ' + $skipped + ' 个，无官方清单 ' + $noManifest + ' 个，失败 ' + $failed + ' 个') -ForegroundColor Cyan
if ($noManifest -gt 0 -and -not $DownloadMissing) {
    Write-Host '  上游没发校验清单的条目不会被固定 —— 这是如实状态，不是失败。' -ForegroundColor DarkGray
    Write-Host '  确认要下载这些包自行计算（耗流量/磁盘/时间），再跑一次加 -DownloadMissing。' -ForegroundColor DarkGray
}
Write-Host '  下一步：跑 ./scripts/verify.ps1 确认数据结构没坏，再提交。' -ForegroundColor DarkGray
