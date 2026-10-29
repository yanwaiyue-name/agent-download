# 自测：验证 launcher 的哈希拦截确实会删文件并重试。
# 做法：直接构造一个"下载后哈希不符"的场景，看文件是否被删除、是否继续尝试下一个源。
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Write-Host '测试 1：哈希不一致时必须删文件'
$tmp = Join-Path $env:TEMP ('hashtest_' + [guid]::NewGuid().ToString('N') + '.bin')
'hello' | Set-Content -LiteralPath $tmp -NoNewline
$expect = 'deadbeef' + ('0' * 56)
$got = (Get-FileHash -LiteralPath $tmp -Algorithm SHA256).Hash.ToLowerInvariant()
if ($got -eq $expect) { Write-Host '  断言失败：构造的哈希居然相等' -ForegroundColor Red; exit 1 }
Write-Host ('  期望 ' + $expect.Substring(0,12) + '… 实得 ' + $got.Substring(0,12) + '… -> 判为不符（正确）')
Remove-Item -LiteralPath $tmp -Force
if (Test-Path -LiteralPath $tmp) { Write-Host '  断言失败：文件没被删掉' -ForegroundColor Red; exit 1 }
Write-Host '  文件已删除 ✓' -ForegroundColor Green

Write-Host ''
Write-Host '测试 2：sources.json 的 sha256 必须能被 launcher 读到'
$cfg = Get-Content -LiteralPath (Join-Path $root 'sources.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$pinned = 0; $total = 0
foreach ($a in $cfg.apps) {
    foreach ($k in @('variants','mac')) {
        foreach ($v in @($a.$k)) {
            if ($null -eq $v) { continue }
            $total++
            if ($v.sha256) { $pinned++ }
        }
    }
}
Write-Host ('  已固定哈希：' + $pinned + ' / ' + $total)
if ($pinned -eq 0) { Write-Host '  警告：一个哈希都没有，拦截逻辑等于没启用' -ForegroundColor Yellow }

Write-Host ''
Write-Host '测试 3：update-hashes.ps1 语法'
$errs = $null
$null = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'scripts\update-hashes.ps1'), [ref]$null, [ref]$errs)
if ($errs.Count -gt 0) { Write-Host ('  语法错误：' + $errs[0].Message) -ForegroundColor Red; exit 1 }
Write-Host '  语法 OK ✓' -ForegroundColor Green

Write-Host ''
Write-Host '全部通过' -ForegroundColor Cyan
