#Requires -Version 5.1
<#
    AI 桌面下载中心 · 本地服务
    ------------------------------------------------
    只在 127.0.0.1 上监听，不联网、不上传任何数据。
    用 TcpListener 手写极简 HTTP，原因是 HttpListener 绑定端口
    在非管理员账户下会抛 AccessDenied，而 TcpListener 不需要任何授权。

    路由：
      GET /                界面
      GET /api/apps        软件清单（含本地文件是否存在）
      GET /dl?id=&i=       流式下载安装包（支持 Range 断点续传）
      GET /doc?k=usage     使用说明
      GET /doc?k=links     官方下载地址
#>
param(
    [int]$Port = 0,
    [switch]$NoBrowser
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
try { $Host.UI.RawUI.WindowTitle = 'AI 桌面下载中心 - 关闭此窗口即停止服务' } catch { }

# 出错时不要把窗口一闪而过，让人能看到原因
trap {
    Write-Host ''
    Write-Host ('  [X] 出错了：' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('      位置：' + $_.InvocationInfo.ScriptName + ' 第 ' + $_.InvocationInfo.ScriptLineNumber + ' 行') -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '  按任意键关闭…' -ForegroundColor DarkGray
    try { $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown') } catch { Start-Sleep -Seconds 8 }
    exit 1
}

$Root    = Split-Path -Parent $MyInvocation.MyCommand.Path
$Html    = Join-Path $Root '资源中心.html'
$SrcPath = Join-Path $Root 'sources.json'
$PkgRoot = Join-Path $Root '安装包'

function Say($msg, $color = 'Gray') { Write-Host $msg -ForegroundColor $color }

if (-not (Test-Path $Html))    { throw ('缺少 资源中心.html：' + $Html) }
if (-not (Test-Path $SrcPath)) { throw ('缺少 sources.json：' + $SrcPath) }

# ---------- 端口 ----------
function Find-FreePort {
    param([int]$Start = 18080, [int]$Count = 60)
    for ($p = $Start; $p -lt ($Start + $Count); $p++) {
        $l = $null
        try {
            $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $p)
            $l.Start()
            $l.Stop()
            return $p
        } catch {
            if ($l) { try { $l.Stop() } catch { } }
        }
    }
    throw '18080-18139 端口全部被占用，请关闭其他程序后重试'
}

# 检测是否已有实例在跑，避免重复双击开出多个服务
function Find-Existing {
    param([int]$Start = 18080, [int]$End = 18090)
    for ($p = $Start; $p -le $End; $p++) {
        try {
            $req = [System.Net.WebRequest]::Create('http://127.0.0.1:' + $p + '/api/apps')
            $req.Timeout = 700
            $req.Proxy = $null   # 本地请求绝不能走系统代理
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
            $body = $sr.ReadToEnd()
            $sr.Close()
            $resp.Close()
            if ($body -match '"apps"') { return $p }
        } catch { }
    }
    return 0
}

if ($Port -le 0) {
    $existing = Find-Existing
    if ($existing -gt 0) {
        Say ''
        Say ('  已有实例在运行：http://127.0.0.1:' + $existing + '/') Green
        Say '  已为你打开浏览器，不用重复启动。' DarkGray
        Say ''
        if (-not $NoBrowser) {
            try { Start-Process ('http://127.0.0.1:' + $existing + '/') | Out-Null } catch { }
        }
        Start-Sleep -Seconds 2
        exit 0
    }
    $Port = Find-FreePort
}

# ---------- 文件索引（只扫一次） ----------
function Build-FileIndex {
    $idx = @{}
    if (-not (Test-Path $PkgRoot)) { return $idx }
    foreach ($f in @(Get-ChildItem -Path $PkgRoot -Recurse -File -ErrorAction SilentlyContinue)) {
        $k = $f.Name.ToLowerInvariant()
        if (-not $idx.ContainsKey($k)) {
            $idx[$k] = [pscustomobject]@{ Path = $f.FullName; Size = $f.Length }
        }
    }
    return $idx
}

# ---------- 组装前端数据 ----------
function Build-AppData {
    param($Index)

    $src = Get-Content -Path $SrcPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $apps = New-Object System.Collections.ArrayList
    $order = New-Object System.Collections.ArrayList

    foreach ($a in @($src.apps)) {
        if ($null -eq $a) { continue }
        if (-not $order.Contains([string]$a.group)) { [void]$order.Add([string]$a.group) }

        $vs = New-Object System.Collections.ArrayList
        $i = 0
        foreach ($v in @($a.variants)) {
            if ($null -eq $v) { continue }
            $fileName = [string]$v.file
            $local = $false
            $sz = 0
            $hit = $null
            if ($Index.ContainsKey($fileName.ToLowerInvariant())) {
                $hit = $Index[$fileName.ToLowerInvariant()]
                $local = $true
                $sz = $hit.Size
            }
            [void]$vs.Add([pscustomobject]@{
                idx       = $i
                arch      = [string]$v.arch
                format    = [string]$v.format
                file      = $fileName
                size      = [string]$v.size
                local     = $local
                localSize = $sz
            })
            $i++
        }

        $macs = New-Object System.Collections.ArrayList
        foreach ($m in @($a.mac)) {
            if ($null -eq $m) { continue }
            [void]$macs.Add([pscustomobject]@{
                arch = [string]$m.arch
                file = [string]$m.file
                size = [string]$m.size
            })
        }

        [void]$apps.Add([pscustomobject]@{
            id        = [string]$a.id
            name      = [string]$a.name
            vendor    = [string]$a.vendor
            group     = [string]$a.group
            desc      = [string]$a.desc
            reason    = [string]$a.reason
            audience  = [string]$a.audience
            recommend = [bool]$a.recommend
            page      = [string]$a.page
            tip       = [string]$a.tip
            needProxy = [bool]$a.needProxy
            variants  = @($vs)
            mac       = @($macs)
        })
    }

    return [pscustomobject]@{ groups = @($order); apps = @($apps) }
}

# ---------- 文档 ----------
function Read-Doc {
    param([string]$Kind)
    $map = @{ usage = '使用说明.txt'; links = '软件推荐与官方下载地址.txt' }
    if (-not $map.ContainsKey($Kind)) { return $null }
    $p = Join-Path $Root $map[$Kind]
    if (-not (Test-Path $p)) { return ('缺少文件：' + $map[$Kind]) }
    return (Get-Content -Path $p -Raw -Encoding UTF8)
}

# ---------- 准备上下文 ----------
Say ''
Say '  正在扫描安装包…' DarkGray
$fileIndex = Build-FileIndex
$appData   = Build-AppData -Index $fileIndex
$appsJson  = $appData | ConvertTo-Json -Depth 8 -Compress
$htmlBytes = [System.IO.File]::ReadAllBytes($Html)

$localCount = 0
foreach ($a in $appData.apps) { foreach ($v in $a.variants) { if ($v.local) { $localCount++ } } }

$Ctx = @{
    Root      = $Root
    AppsJson  = $appsJson
    HtmlBytes = $htmlBytes
    FileIndex = $fileIndex
    AppData   = $appData
}

# ---------- 请求处理（在独立 runspace 中执行） ----------
$Handler = {
    param($Client, $Ctx)

    $stream = $null
    try {
        $Client.ReceiveTimeout = 20000
        $Client.SendTimeout    = 600000
        $stream = $Client.GetStream()

        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII, $false, 8192, $true)
        $first = $reader.ReadLine()
        if ([string]::IsNullOrWhiteSpace($first)) { return }

        $seg = $first.Split(' ')
        if ($seg.Length -lt 2) { return }
        $method = $seg[0].ToUpperInvariant()
        $raw    = $seg[1]

        # 读完请求头
        $headers = @{}
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -eq $line -or $line -eq '') { break }
            $c = $line.IndexOf(':')
            if ($c -gt 0) { $headers[$line.Substring(0, $c).Trim()] = $line.Substring($c + 1).Trim() }
        }

        # 解析路径与查询串
        $path = $raw
        $qidx = $raw.IndexOf('?')
        $qs = @{}
        if ($qidx -ge 0) {
            $path = $raw.Substring(0, $qidx)
            foreach ($kv in $raw.Substring($qidx + 1).Split('&')) {
                if ([string]::IsNullOrEmpty($kv)) { continue }
                $p = $kv.Split('=')
                $k = [System.Uri]::UnescapeDataString($p[0])
                $v = ''
                if ($p.Length -gt 1) { $v = [System.Uri]::UnescapeDataString($p[1]) }
                $qs[$k] = $v
            }
        }
        $path = [System.Uri]::UnescapeDataString($path)

        function Send-Head {
            param($S, [int]$Code, [string]$Type, [long]$Len, $Extra)
            $status = 'OK'
            if ($Code -eq 206) { $status = 'Partial Content' }
            elseif ($Code -eq 404) { $status = 'Not Found' }
            elseif ($Code -eq 500) { $status = 'Internal Server Error' }
            elseif ($Code -eq 405) { $status = 'Method Not Allowed' }
            $sb = New-Object System.Text.StringBuilder
            [void]$sb.Append('HTTP/1.1 ' + $Code + ' ' + $status + "`r`n")
            [void]$sb.Append('Content-Type: ' + $Type + "`r`n")
            [void]$sb.Append('Content-Length: ' + $Len + "`r`n")
            [void]$sb.Append("Cache-Control: no-store`r`n")
            [void]$sb.Append("Connection: close`r`n")
            [void]$sb.Append("X-Content-Type-Options: nosniff`r`n")
            if ($Extra) {
                foreach ($k in $Extra.Keys) {
                    [void]$sb.Append($k + ': ' + $Extra[$k] + "`r`n")
                }
            }
            [void]$sb.Append("`r`n")
            $b = [System.Text.Encoding]::ASCII.GetBytes($sb.ToString())
            $S.Write($b, 0, $b.Length)
        }

        function Send-Text {
            param($S, [string]$Text, [string]$Type = 'text/plain; charset=utf-8', [int]$Code = 200)
            $b = [System.Text.Encoding]::UTF8.GetBytes($Text)
            Send-Head $S $Code $Type $b.Length $null
            $S.Write($b, 0, $b.Length)
        }

        if ($method -ne 'GET' -and $method -ne 'HEAD') {
            Send-Text $stream 'method not allowed' 'text/plain; charset=utf-8' 405
            return
        }

        # ---- 路由 ----
        if ($path -eq '/' -or $path -eq '/index.html') {
            # 实时读取，卖家改完界面刷新即可生效，不用重启服务
            $hb = [System.IO.File]::ReadAllBytes((Join-Path $Ctx.Root '资源中心.html'))
            Send-Head $stream 200 'text/html; charset=utf-8' $hb.Length @{ 'Cache-Control' = 'no-cache' }
            if ($method -ne 'HEAD') { $stream.Write($hb, 0, $hb.Length) }
            return
        }

        if ($path -eq '/api/apps') {
            Send-Text $stream $Ctx.AppsJson 'application/json; charset=utf-8'
            return
        }

        if ($path -eq '/doc') {
            $k = ''
            if ($qs.ContainsKey('k')) { $k = $qs['k'] }
            $map = @{ usage = '使用说明.txt'; links = '软件推荐与官方下载地址.txt' }
            if (-not $map.ContainsKey($k)) {
                Send-Text $stream 'unknown doc' 'text/plain; charset=utf-8' 404
                return
            }
            $fp = Join-Path $Ctx.Root $map[$k]
            if (-not (Test-Path $fp)) {
                Send-Text $stream ('缺少文件：' + $map[$k]) 'text/plain; charset=utf-8'
                return
            }
            Send-Text $stream (Get-Content -Path $fp -Raw -Encoding UTF8) 'text/plain; charset=utf-8'
            return
        }

        if ($path -eq '/dl') {
            $appId = ''
            if ($qs.ContainsKey('id')) { $appId = $qs['id'] }
            $vi = -1
            if ($qs.ContainsKey('i')) { [void][int]::TryParse($qs['i'], [ref]$vi) }

            $app = $null
            foreach ($a in $Ctx.AppData.apps) { if ($a.id -eq $appId) { $app = $a; break } }
            if ($null -eq $app) { Send-Text $stream '软件不存在' 'text/plain; charset=utf-8' 404; return }
            if ($vi -lt 0 -or $vi -ge $app.variants.Count) { Send-Text $stream '安装包序号无效' 'text/plain; charset=utf-8' 404; return }

            $variant = $app.variants[$vi]
            if (-not $variant.local) { Send-Text $stream '该安装包不在本地，请使用官方下载' 'text/plain; charset=utf-8' 404; return }

            $hit = $Ctx.FileIndex[$variant.file.ToLowerInvariant()]
            if ($null -eq $hit) { Send-Text $stream '文件已被移动或删除' 'text/plain; charset=utf-8' 404; return }

            $full = $hit.Path
            $total = (Get-Item $full).Length
            $name  = Split-Path -Leaf $full

            # 断点续传
            $start = [long]0
            $end   = [long]($total - 1)
            $code  = 200
            $range = $headers['Range']
            if ($range -and $range -match 'bytes=(\d*)-(\d*)') {
                $s = $Matches[1]
                $e = $Matches[2]
                if ($s -ne '') { $start = [long]$s }
                if ($e -ne '') { $end = [long]$e }
                if ($end -ge $total) { $end = $total - 1 }
                if ($start -gt $end) { $start = 0; $end = $total - 1 }
                $code = 206
            }
            $len = $end - $start + 1

            # 中文文件名：ASCII 兜底 + RFC 5987
            $asciiName = ''
            foreach ($ch in $name.ToCharArray()) {
                if ([int]$ch -lt 128) { $asciiName += $ch } else { $asciiName += '_' }
            }
            $utf8Name = [System.Uri]::EscapeDataString($name)
            # RFC 5987：filename*=charset''value（charset 后必须是两个单引号）
            $cdHead = "attachment; filename=`"$asciiName`"; filename*=UTF-8''$utf8Name"

            $extra = @{
                'Accept-Ranges'       = 'bytes'
                'Content-Disposition' = $cdHead
            }
            if ($code -eq 206) { $extra['Content-Range'] = 'bytes ' + $start + '-' + $end + '/' + $total }

            Send-Head $stream $code 'application/octet-stream' $len $extra
            if ($method -eq 'HEAD') { return }

            $fs = [System.IO.File]::Open($full, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
            try {
                $fs.Position = $start
                $buf = New-Object byte[] 262144
                $remain = $len
                while ($remain -gt 0) {
                    $want = [Math]::Min([long]$buf.Length, $remain)
                    $got = $fs.Read($buf, 0, [int]$want)
                    if ($got -le 0) { break }
                    $stream.Write($buf, 0, $got)
                    $remain -= $got
                }
                $stream.Flush()
            } finally {
                $fs.Close()
            }
            return
        }

        if ($path -eq '/favicon.ico') {
            Send-Head $stream 404 'image/x-icon' 0 $null
            return
        }

        Send-Text $stream 'not found' 'text/plain; charset=utf-8' 404
    }
    catch {
        # 客户端中途取消下载会走到这里，属于正常情况
    }
    finally {
        try { if ($stream) { $stream.Close() } } catch { }
        try { $Client.Close() } catch { }
    }
}

# ---------- 启动 ----------
$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()

$iss  = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$pool = [runspacefactory]::CreateRunspacePool(1, 8, $iss, $Host)
$pool.Open()

$running = New-Object System.Collections.ArrayList
$url = 'http://127.0.0.1:' + $Port + '/'

Say ''
Say '  ============================================================' Cyan
Say '    AI 桌面下载中心' White
Say '  ============================================================' Cyan
Say ('    地址：' + $url) Green
Say ('    软件：' + $appData.apps.Count + ' 款   本地安装包：' + $localCount + ' 个') Gray
Say ''
Say '    浏览器应该已经自动打开。' DarkGray
Say '    关闭这个窗口即可停止服务，不影响已下载的文件。' DarkGray
Say '  ------------------------------------------------------------' DarkGray
Say ''

if (-not $NoBrowser) {
    try { Start-Process $url | Out-Null } catch { Say ('  自动打开失败，请手动复制上面的地址到浏览器') Yellow }
}

$cleanup = {
    try { $listener.Stop() } catch { }
    try { $pool.Close() } catch { }
}
try {
    while ($true) {
        $client = $listener.AcceptTcpClient()

        $ps = [powershell]::Create()
        $ps.RunspacePool = $pool
        [void]$ps.AddScript($Handler).AddArgument($client).AddArgument($Ctx)
        $handle = $ps.BeginInvoke()

        [void]$running.Add([pscustomobject]@{ PS = $ps; H = $handle })

        # 清理已完成的任务，避免句柄堆积
        if ($running.Count -gt 32) {
            for ($i = $running.Count - 1; $i -ge 0; $i--) {
                if ($running[$i].H.IsCompleted) {
                    try { [void]$running[$i].PS.EndInvoke($running[$i].H) } catch { }
                    try { $running[$i].PS.Dispose() } catch { }
                    $running.RemoveAt($i)
                }
            }
        }
    }
}
finally {
    & $cleanup
}
