#Requires -Version 5.1
<#
    sources.json 直链 + 落地页健康检查（升级版）
    CI 在 PowerShell 7 上跑（-Parallel 并发）；本地用 PS 5.1 时自动降级为顺序探测。

    用法：
      pwsh -File .\scripts\check-links.ps1
      pwsh -File .\scripts\check-links.ps1 -Concurrency 8
      pwsh -File .\scripts\check-links.ps1 -Proxy http://127.0.0.1:7897 -ProxyFirst

    升级内容（吸收 airport-nav 引擎经验）：
      1. HEAD 优先，不支持 HEAD（400/405/501）时退回 GET。判定口径：
         200–399 存活；404/410 确认失效；其余 4xx/5xx（401/403/429/5xx）
         归入「被拦截 / 限流」——反爬和源站故障不能当成死链。
      2. 单轮失败自动重试（-Retry 次，默认 2）。
      3. -Proxy 指定代理；-ProxyFirst 时代理做主口径（境外链接多，更快），否则代理仅作复核。
      4. 确认失效（404/410）用 r.jina.ai 异地复核：异地能取回则降为不可达，避免误杀。
      5. 覆盖 web/npm/pip 类应用：无直链也检查其官方 page 落地页。
    退出码：0 = 无确认失效（存活 / 被拦截 / 不可达都算 0）；1 = 存在确认失效（404/410）。
#>
[CmdletBinding()]
param(
    [int]$Concurrency = 6,
    [string]$Proxy = '',
    [int]$TimeoutSec = 20,
    [int]$Retry = 2,
    [switch]$ProxyFirst
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$Root = Split-Path -Parent $PSScriptRoot
$JsonPath = Join-Path $Root 'sources.json'
$ReportPath = Join-Path $Root 'link-report.txt'
$UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'

if ($Proxy -and -not $ProxyFirst) { $env:HTTPS_PROXY = $Proxy; $env:HTTP_PROXY = $Proxy }

# ---------------- 工具函数（顶层定义，PS5.1 兼容） ----------------

function New-ProbeClient {
    param([int]$Timeout, [string]$ProxyFor)
    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
    $h = [System.Net.Http.HttpClientHandler]::new()
    $h.AllowAutoRedirect = $true
    $h.MaxAutomaticRedirections = 5
    $h.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
    if ($ProxyFor) {
        try { $h.Proxy = [System.Net.WebProxy]::new($ProxyFor); $h.UseProxy = $true } catch { $h.UseProxy = $false }
    } else {
        $h.UseProxy = $false
    }
    $c = [System.Net.Http.HttpClient]::new($h)
    $c.Timeout = [TimeSpan]::FromSeconds($Timeout)
    [void]$c.DefaultRequestHeaders.TryAddWithoutValidation('User-Agent', $UA)
    [void]$c.DefaultRequestHeaders.TryAddWithoutValidation('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
    return $c
}

function Invoke-Probe {
    param($Client, [string]$Url, [string]$Method = 'Head')
    try {
        $verb = [System.Net.Http.HttpMethod]::new($Method.ToUpperInvariant())
        $req = [System.Net.Http.HttpRequestMessage]::new($verb, $Url)
        $resp = $Client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $code = [int]$resp.StatusCode
        $final = $Url
        if ($resp.RequestMessage -and $resp.RequestMessage.RequestUri) { $final = $resp.RequestMessage.RequestUri.AbsoluteUri }
        $resp.Dispose()
        return @{ Code = $code; Final = $final; Error = $null }
    } catch {
        return @{ Code = 0; Final = $null; Error = $_.Exception.Message }
    }
}

function Test-UrlParallel {
    # 供 -Parallel 线程调用：不能访问脚本内变量，全部参数化
    param([pscustomobject]$T, [int]$TO, [int]$RT, [string]$PX, [bool]$PF, [string]$UAA)
    $primary = $null; $secondary = $null
    if ($PF -and $PX) {
        $primary = New-ProbeClient -Timeout $TO -ProxyFor $PX
        $secondary = New-ProbeClient -Timeout $TO
    } else {
        $primary = New-ProbeClient -Timeout $TO
        if ($PX) { $secondary = New-ProbeClient -Timeout $TO -ProxyFor $PX }
    }
    try {
        $res = $null
        # 主口径：重试循环
        $last = @{ Code = 0; Final = $null; Error = $null; Via = if ($PF -and $PX) { 'proxy' } else { 'direct' } }
        for ($i = 1; $i -le [Math]::Max(1, $RT); $i++) {
            $h = Invoke-Probe -Client $primary -Url $T.url -Method 'Head'
            if ($h.Code -gt 0 -and @(400,405,501) -notcontains $h.Code) { $res = $h; break }
            $g = Invoke-Probe -Client $primary -Url $T.url -Method 'Get'
            if ($g.Code -gt 0) { $res = $g; break }
            $last = $g
            if ($i -lt $RT) { Start-Sleep -Milliseconds 500 }
        }
        if (-not $res -and $secondary) {
            $sp = Invoke-Probe -Client $secondary -Url $T.url -Method 'Head'
            if ($sp.Code -le 0) { $sp = Invoke-Probe -Client $secondary -Url $T.url -Method 'Get' }
            if ($sp.Code -gt 0) { $sp.Via = if ($PF -and $PX) { 'direct' } else { 'proxy' }; $res = $sp }
        }
        if (-not $res) { $res = $last }

        $code = $res.Code
        $status = 'UNREACHABLE'
        if ($code -gt 0) {
            if ($code -ge 200 -and $code -lt 400) { $status = 'ALIVE' }
            elseif (@(404,410) -contains $code) { $status = 'DEAD' }
            else { $status = 'BLOCKED' }
        }

        # 异地复核（只对确认 404/410）
        if ($status -eq 'DEAD' -and @(404,410) -contains $code) {
            try {
                $rc = New-ProbeClient -Timeout 25
                $rv = Invoke-Probe -Client $rc -Url ('https://r.jina.ai/' + $T.url) -Method 'Get'
                $rc.Dispose()
                if ($rv.Code -gt 0 -and $rv.Code -lt 500) { $status = 'UNREACHABLE' }
            } catch { }
        }
        return [pscustomobject]@{ app=$T.app; kind=$T.kind; arch=$T.arch; format=$T.format; status=$status; code=$code; url=$T.url }
    } finally {
        if ($primary) { $primary.Dispose() }
        if ($secondary) { $secondary.Dispose() }
    }
}

# ---------------- 收集目标 ----------------
$cfg = [System.IO.File]::ReadAllText($JsonPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
$targets = New-Object System.Collections.ArrayList
foreach ($a in @($cfg.apps)) {
    foreach ($v in @($a.variants)) {
        if (-not $v) { continue }
        $u = @($v.urls) | Select-Object -First 1
        if ($u) { [void]$targets.Add([pscustomobject]@{ app=$a.id; kind='win'; arch=$v.arch; format=$v.format; file=$v.file; url=$u }) }
    }
    foreach ($m in @($a.mac)) {
        if (-not $m) { continue }
        $u = @($m.urls) | Select-Object -First 1
        if ($u) { [void]$targets.Add([pscustomobject]@{ app=$a.id; kind='mac'; arch=$m.arch; format=$m.format; file=$m.file; url=$u }) }
    }
    $hasBin = (@($a.variants).Count + @($a.mac).Count) -gt 0
    if (-not $hasBin -and $a.page) {
        [void]$targets.Add([pscustomobject]@{ app=$a.id; kind='page'; arch=''; format='page'; file=''; url=[string]$a.page })
    }
}

Write-Host ''
Write-Host ('==============================================================') -ForegroundColor Magenta
Write-Host ('  直链 + 落地页健康检查  共 ' + $targets.Count + ' 个目标  并发 ' + $Concurrency) -ForegroundColor Magenta
Write-Host ('==============================================================') -ForegroundColor Magenta
Write-Host ''

$isPS7 = $PSVersionTable.PSVersion.Major -ge 7
$resArr = New-Object System.Collections.ArrayList

if ($isPS7) {
    # PS7：用 -Parallel 真并发。并行 runspace 看不到脚本函数，故内联全部工具逻辑。
    $results = $targets | ForEach-Object -ThrottleLimit $Concurrency -Parallel {
        $T = $_
        $TO = $using:TimeoutSec
        $RT = $using:Retry
        $PX = $using:Proxy
        $PF = [bool]$using:ProxyFirst
        $UAA = $using:UA

        function New-PC { param([int]$Timeout, [string]$ProxyFor)
            Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
            $h = [System.Net.Http.HttpClientHandler]::new()
            $h.AllowAutoRedirect = $true
            $h.MaxAutomaticRedirections = 5
            $h.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
            if ($ProxyFor) { try { $h.Proxy = [System.Net.WebProxy]::new($ProxyFor); $h.UseProxy = $true } catch { $h.UseProxy = $false } }
            else { $h.UseProxy = $false }
            $c = [System.Net.Http.HttpClient]::new($h)
            $c.Timeout = [TimeSpan]::FromSeconds($Timeout)
            [void]$c.DefaultRequestHeaders.TryAddWithoutValidation('User-Agent', $UAA)
            [void]$c.DefaultRequestHeaders.TryAddWithoutValidation('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8')
            return $c
        }
        function Invoke-PB { param($Client, [string]$Url, [string]$Method = 'Head')
            try {
                $verb = [System.Net.Http.HttpMethod]::new($Method.ToUpperInvariant())
                $req = [System.Net.Http.HttpRequestMessage]::new($verb, $Url)
                $r = $Client.SendAsync($req, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
                $code = [int]$r.StatusCode; $r.Dispose()
                return @{ Code = $code; Error = $null }
            } catch { return @{ Code = 0; Error = $_.Exception.Message } }
        }
        function Get-RV { param([string]$Url, [int]$TO = 25)
            $c = $null
            try {
                $c = New-PC -Timeout $TO
                $r = Invoke-PB -Client $c -Url ('https://r.jina.ai/' + $Url) -Method 'Get'
                return ($r.Code -gt 0 -and $r.Code -lt 500)
            } catch { return $false }
            finally { if ($c) { $c.Dispose() } }
        }

        $primary = $null; $secondary = $null
        if ($PF -and $PX) { $primary = New-PC -Timeout $TO -ProxyFor $PX; $secondary = New-PC -Timeout $TO }
        else { $primary = New-PC -Timeout $TO; if ($PX) { $secondary = New-PC -Timeout $TO -ProxyFor $PX } }

        $status = 'UNREACHABLE'; $code = 0
        try {
            $res = $null
            $last = $null
            for ($i = 1; $i -le [Math]::Max(1, $RT); $i++) {
                $h = Invoke-PB -Client $primary -Url $T.url -Method 'Head'
                if ($h.Code -gt 0 -and @(400,405,501) -notcontains $h.Code) { $res = $h; break }
                $g = Invoke-PB -Client $primary -Url $T.url -Method 'Get'
                if ($g.Code -gt 0) { $res = $g; break }
                $last = $g
                if ($i -lt $RT) { Start-Sleep -Milliseconds 500 }
            }
            if (-not $res -and $secondary) {
                $sp = Invoke-PB -Client $secondary -Url $T.url -Method 'Head'
                if ($sp.Code -le 0) { $sp = Invoke-PB -Client $secondary -Url $T.url -Method 'Get' }
                if ($sp.Code -gt 0) { $res = $sp }
            }
            if (-not $res) { $res = $last }
            if ($res) { $code = $res.Code }
            if ($code -gt 0) {
                if ($code -ge 200 -and $code -lt 400) { $status = 'ALIVE' }
                elseif (@(404,410) -contains $code) { $status = 'DEAD' }
                else { $status = 'BLOCKED' }
            }
            if ($status -eq 'DEAD' -and @(404,410) -contains $code) {
                if (Get-RV -Url $T.url) { $status = 'UNREACHABLE' }
            }
        } catch { $status = 'UNREACHABLE' }
        finally { if ($primary) { $primary.Dispose() }; if ($secondary) { $secondary.Dispose() } }

        [pscustomobject]@{ app=$T.app; kind=$T.kind; arch=$T.arch; format=$T.format; status=$status; code=$code; url=$T.url }
    }
} else {
    # PS5.1：顺序
    foreach ($t in $targets) {
        $r = Test-UrlParallel -T $t -TO $TimeoutSec -RT $Retry -PX $Proxy -PF ([bool]$ProxyFirst) -UAA $UA
        [void]$resArr.Add($r)
    }
    $results = $resArr
}

$alive = @($results | Where-Object { $_.status -eq 'ALIVE' })
$dead  = @($results | Where-Object { $_.status -eq 'DEAD' })
$blocked = @($results | Where-Object { $_.status -eq 'BLOCKED' })
$unreach = @($results | Where-Object { $_.status -eq 'UNREACHABLE' })

foreach ($r in (@($alive) + @($dead) + @($blocked) + @($unreach))) {
    switch ($r.status) {
        'ALIVE' { Write-Host ('  200  ' + $r.app + ' / ' + $r.kind + ' / ' + $r.arch) -ForegroundColor Green }
        'DEAD'  { $upHint2 = ''; if ($r.upstream) { $upHint2 = '  [上游最新: ' + $r.upstream + ']' }; Write-Host (('  ' + $r.code + '  ' + $r.app + ' / ' + $r.kind + ' / ' + $r.arch + $upHint2)) -ForegroundColor Red }
        'BLOCKED' { Write-Host ('  ' + $r.code + '  ' + $r.app + ' / ' + $r.kind + ' / ' + $r.arch + '  （被拦截 / 限流，不是死链）') -ForegroundColor DarkYellow }
        default { Write-Host ('  ???  ' + $r.app + ' / ' + $r.kind + ' / ' + $r.arch + '  （网络不可达）') -ForegroundColor Yellow }
    }
}

# ---- 版本漂移提示：对 GitHub 直链死链，提示上游最新稳定版（主脚本顺序执行，可靠） ----
function Get-StableLatest { param([string]$Repo, [string]$ProxyUrl = '')
    try {
        Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
        $hh = [System.Net.Http.HttpClientHandler]::new()
        $hh.AllowAutoRedirect = $true
        $hh.MaxAutomaticRedirections = 5
        $hh.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip -bor [System.Net.DecompressionMethods]::Deflate
        if ($ProxyUrl) { try { $hh.Proxy = [System.Net.WebProxy]::new($ProxyUrl); $hh.UseProxy = $true } catch { $hh.UseProxy = $false } }
        else { $hh.UseProxy = $false }
        $hc = [System.Net.Http.HttpClient]::new($hh)
        $hc.Timeout = [TimeSpan]::FromSeconds(30)
        [void]$hc.DefaultRequestHeaders.TryAddWithoutValidation('User-Agent', $UA)
        $txt = $hc.GetStringAsync('https://github.com/' + $Repo + '/releases.atom').GetAwaiter().GetResult()
        $hc.Dispose()
        $titles = [regex]::Matches($txt, '<title>([^<]+)</title>')
        foreach ($mm in $titles) {
            $tv = $mm.Groups[1].Value.Trim()
            if ($tv -match 'Release notes from') { continue }
            if ($tv -match 'canary|beta|next|nightly|pr ?build|rc|alpha|rc\.') { continue }
            return $tv
        }
        return ''
    } catch { return '' }
}
$tagCache = @{}
$deadWithUpstream = New-Object System.Collections.ArrayList
foreach ($r2 in $dead) {
    $r2 | Add-Member -NotePropertyName upstream -NotePropertyValue '' -Force
    try {
        $du = [uri]$r2.url
        if ($du.Host -eq 'github.com') {
            $segs = @($du.Segments | Where-Object { $_ -ne '/' } | ForEach-Object { $_.TrimEnd('/') })
            if ($segs.Count -ge 2) {
                $rp = $segs[0] + '/' + $segs[1]
                if ($tagCache.ContainsKey($rp)) { $r2.upstream = $tagCache[$rp] }
                else { $r2.upstream = (Get-StableLatest -Repo $rp -ProxyUrl $Proxy); if ($r2.upstream) { $tagCache[$rp] = $r2.upstream } }
            }
        }
    } catch { }
    [void]$deadWithUpstream.Add($r2)
}
$dead = @($deadWithUpstream)

$lines = New-Object System.Collections.ArrayList
[void]$lines.Add('直链 + 落地页健康检查报告')
[void]$lines.Add('生成时间：' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
[void]$lines.Add(('总计：' + $targets.Count + '   存活：' + $alive.Count + '   失效：' + $dead.Count + '   被拦截：' + $blocked.Count + '   不可达：' + $unreach.Count))
[void]$lines.Add('')
if ($dead.Count -gt 0) {
    [void]$lines.Add('=== 确认失效（需更新）===')
    foreach ($r in $dead) { $upHint = ''; if ($r.upstream) { $upHint = '   [上游最新: ' + $r.upstream + ']' }; [void]$lines.Add(('  ' + $r.code + '  ' + $r.app + '  ' + $r.kind + '  ' + $r.arch + '  ' + $r.format + '  ' + $r.url + $upHint)) }
    [void]$lines.Add('')
}
if ($blocked.Count -gt 0) {
    [void]$lines.Add('=== 被拦截 / 限流（401/403/429/5xx，不是死链，通常无需处理）===')
    foreach ($r in $blocked) { [void]$lines.Add(('  ' + $r.code + '  ' + $r.app + '  ' + $r.kind + '  ' + $r.arch + '  ' + $r.format + '  ' + $r.url)) }
    [void]$lines.Add('')
}
if ($unreach.Count -gt 0) {
    [void]$lines.Add('=== 网络不可达 / 墙外可达（可能需代理，不一定是链接坏了）===')
    foreach ($r in $unreach) { [void]$lines.Add(('  ???  ' + $r.app + '  ' + $r.kind + '  ' + $r.arch + '  ' + $r.format + '  ' + $r.url)) }
    [void]$lines.Add('')
}
[System.IO.File]::WriteAllLines($ReportPath, $lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host ''
Write-Host ('  存活 ' + $alive.Count + '  /  失效 ' + $dead.Count + '  /  被拦截 ' + $blocked.Count + '  /  不可达 ' + $unreach.Count) -ForegroundColor Cyan
Write-Host ('  报告已写入 ' + $ReportPath) -ForegroundColor Gray
Write-Host ''

if ($dead.Count -gt 0) { exit 1 } else { exit 0 }
