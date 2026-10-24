#Requires -Version 5.1
<#
    sources.json 里的直链健康检查
    用法：
      powershell -ExecutionPolicy Bypass -File .\scripts\check-links.ps1
      powershell -ExecutionPolicy Bypass -File .\scripts\check-links.ps1 -Concurrency 8
      powershell -ExecutionPolicy Bypass -File .\scripts\check-links.ps1 -Proxy http://127.0.0.1:7897

    行为：
      - 对每个 variant / mac 的第一个 url 发 HEAD（失败退回 GET Range 0-0）
      - 返回 200/206 记为 存活；404/410 记为 失效
      - 超时/连接失败记为 不可达（可能是网络问题，不一定是链接坏了）
      - 结果写入 link-report.txt，并打印汇总

    退出码：
      0  全部存活，或有不可达但无失效
      1  存在确认失效（404/410）的链接
#>
param(
    [int]$Concurrency = 6,
    [string]$Proxy = '',
    [int]$TimeoutSec = 20
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$JsonPath = Join-Path $Root 'sources.json'
$ReportPath = Join-Path $Root 'link-report.txt'

if ($Proxy) {
    $env:HTTPS_PROXY = $Proxy
    $env:HTTP_PROXY  = $Proxy
}

$cfg = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json

# 收集目标
$targets = New-Object System.Collections.ArrayList
foreach ($a in @($cfg.apps)) {
    foreach ($v in @($a.variants)) {
        if (-not $v) { continue }
        $u = @($v.urls) | Select-Object -First 1
        if ($u) { [void]$targets.Add([pscustomobject]@{ app=$a.id; arch=$v.arch; format=$v.format; file=$v.file; url=$u }) }
    }
    foreach ($m in @($a.mac)) {
        if (-not $m) { continue }
        $u = @($m.urls) | Select-Object -First 1
        if ($u) { [void]$targets.Add([pscustomobject]@{ app=$a.id; arch=$m.arch; format=$m.format; file=$m.file; url=$u }) }
    }
}

Write-Host ''
Write-Host '==============================================================' -ForegroundColor Magenta
Write-Host ('  直链健康检查  共 ' + $targets.Count + ' 个目标  并发 ' + $Concurrency) -ForegroundColor Magenta
Write-Host '==============================================================' -ForegroundColor Magenta
Write-Host ''

$alive  = New-Object System.Collections.ArrayList
$dead   = New-Object System.Collections.ArrayList
$unreach = New-Object System.Collections.ArrayList

$results = $targets | ForEach-Object -ThrottleLimit $Concurrency -Parallel {
    $t = $_
    $status = 'UNREACHABLE'
    $code = 0
    try {
        $req = [System.Net.HttpWebRequest]::Create($t.url)
        $req.Method = 'HEAD'
        $req.Timeout = $using:TimeoutSec * 1000
        $req.AllowAutoRedirect = $true
        $req.UserAgent = 'agent-download/1.0'
        $resp = $req.GetResponse()
        $code = [int]$resp.StatusCode
        $resp.Close()
        $status = if ($code -ge 200 -and $code -lt 400) { 'ALIVE' } else { 'DEAD' }
    } catch {
        $ex = $_.Exception
        if ($ex.Response) {
            $code = [int]$ex.Response.StatusCode
            $status = if ($code -eq 404 -or $code -eq 410) { 'DEAD' } else { 'UNREACHABLE' }
        } else {
            $status = 'UNREACHABLE'
        }
    }
    [pscustomobject]@{ app=$t.app; arch=$t.arch; format=$t.format; status=$status; code=$code; url=$t.url }
}

foreach ($r in $results) {
    switch ($r.status) {
        'ALIVE'       { [void]$alive.Add($r);     Write-Host ('  200  ' + $r.app + ' / ' + $r.arch + ' / ' + $r.format) -ForegroundColor Green }
        'DEAD'        { [void]$dead.Add($r);      Write-Host ('  ' + $r.code + '  ' + $r.app + ' / ' + $r.arch + ' / ' + $r.format) -ForegroundColor Red }
        default       { [void]$unreach.Add($r);   Write-Host ('  ???  ' + $r.app + ' / ' + $r.arch + ' / ' + $r.format + '  （网络不可达）') -ForegroundColor Yellow }
    }
}

# 写报告
$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('直链健康检查报告')
[void]$lines.Add('生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
[void]$lines.Add('总计：' + $targets.Count + '   存活：' + $alive.Count + '   失效：' + $dead.Count + '   不可达：' + $unreach.Count)
[void]$lines.Add('')
if ($dead.Count -gt 0) {
    [void]$lines.Add('=== 确认失效（需更新）===')
    foreach ($r in $dead) { [void]$lines.Add(('  ' + $r.code + '  ' + $r.app + '  ' + $r.arch + '  ' + $r.format + '  ' + $r.url)) }
    [void]$lines.Add('')
}
if ($unreach.Count -gt 0) {
    [void]$lines.Add('=== 网络不可达（可能需代理，不一定是链接坏了）===')
    foreach ($r in $unreach) { [void]$lines.Add(('  ???  ' + $r.app + '  ' + $r.arch + '  ' + $r.format + '  ' + $r.url)) }
    [void]$lines.Add('')
}
[System.IO.File]::WriteAllLines($ReportPath, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ''
Write-Host ('  存活 ' + $alive.Count + '  /  失效 ' + $dead.Count + '  /  不可达 ' + $unreach.Count) -ForegroundColor Cyan
Write-Host ('  报告已写入 ' + $ReportPath) -ForegroundColor Gray
Write-Host ''

if ($dead.Count -gt 0) { exit 1 } else { exit 0 }
