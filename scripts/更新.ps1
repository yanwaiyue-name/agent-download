#Requires -Version 5.1
<#
    One-command update: verify -> commit -> push
    Usage:
      powershell -ExecutionPolicy Bypass -File .\scripts\更新.ps1 -Message "update Claude to v2.x"
      powershell -ExecutionPolicy Bypass -File .\scripts\更新.ps1 -Message "..." -Regen
      powershell -ExecutionPolicy Bypass -File .\scripts\更新.ps1 -Message "..." -Push:$false
    Options:
      -Message   commit message (required)
      -Regen     run gen-dirs.ps1 -Force first (after editing sources.json)
      -Push      push after commit (default true)
      -SkipVerify skip verify.ps1 (not recommended)
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Message,
    [switch]$Regen,
    [switch]$SkipVerify,
    [bool]$Push = $true
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $Root

function Say($m, $c) { if ($c) { Write-Host $m -ForegroundColor $c } else { Write-Host $m } }
function Step($n, $m) { Write-Host ''; Write-Host ('[' + $n + '] ' + $m) -ForegroundColor Cyan }

Say ''
Say '==============================================================' Magenta
Say '  update pipeline' Magenta
Say '==============================================================' Magenta

# ---------- 0. proxy for github ----------
$proxy = 'http://127.0.0.1:7897'
$env:HTTPS_PROXY = $proxy
$env:HTTP_PROXY  = $proxy

# ---------- 1. regenerate dirs (optional) ----------
if ($Regen) {
    Step '1/4' 'regenerate install dirs from sources.json'
    $gen = Join-Path $Root 'scripts\gen-dirs.ps1'
    if (-not (Test-Path $gen)) { throw 'scripts\gen-dirs.ps1 not found' }
    & powershell -NoProfile -ExecutionPolicy Bypass -File $gen -Force
    if ($LASTEXITCODE -ne 0) { throw 'gen-dirs.ps1 failed' }
} else {
    Step '1/4' 'skip dir regeneration (use -Regen after editing sources.json)'
}

# ---------- 2. verify ----------
if ($SkipVerify) {
    Step '2/4' 'verify SKIPPED (explicit -SkipVerify)'
} else {
    Step '2/4' 'validate sources.json and scripts'
    $vf = Join-Path $Root 'scripts\verify.ps1'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $vf
    if ($LASTEXITCODE -ne 0) {
        Say ''
        Say '  ABORTED: verify.ps1 reported errors. Fix them, then run again.' Red
        Say '  Nothing was committed.' Red
        Say ''
        exit 1
    }
}

# ---------- 3. commit ----------
Step '3/4' 'stage and commit'
$changes = git status --porcelain
if (-not $changes) {
    Say '  nothing to commit, working tree clean' Yellow
    Say ''
    exit 0
}

git add -A
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }

$msgFile = Join-Path $env:TEMP ('commit_msg_' + [guid]::NewGuid().ToString('N') + '.txt')
[System.IO.File]::WriteAllText($msgFile, $Message, (New-Object System.Text.UTF8Encoding($false)))
try {
    git commit -F $msgFile
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
} finally {
    Remove-Item -LiteralPath $msgFile -Force -ErrorAction SilentlyContinue
}

$head = git log -1 --pretty=format:'%h %s'
Say ('  committed: ' + $head) Green

# ---------- 4. push ----------
if (-not $Push) {
    Step '4/4' 'push SKIPPED (-Push:$false)'
    Say ''
    exit 0
}

Step '4/4' 'push to GitHub'
# remote 必须用 :443 形式，否则全局 insteadOf 会把地址改写成 ghfast.top 镜像（只能读）
$remoteUrl = git remote get-url origin 2>$null
if ($remoteUrl -notmatch ':443/') {
    Say ('  WARNING: origin is ' + $remoteUrl) Yellow
    Say '  It does not use :443, so a global insteadOf rule may rewrite it to a mirror (read-only).' Yellow
    Say '  Fix with: git remote set-url origin https://github.com:443/yanwaiyue-name/agent-download.git' Yellow
}

git push origin master
if ($LASTEXITCODE -ne 0) {
    Say ''
    Say '  PUSH FAILED' Red
    Say '  Common causes:' Red
    Say '    1. proxy not running (expected at 127.0.0.1:7897)' Red
    Say '    2. credential expired: run  gh auth status' Red
    Say '    3. remote rewritten to a mirror: check  git remote -v' Red
    Say ''
    Say '  The commit is safe locally. Retry the push once fixed.' Yellow
    Say ''
    exit 1
}

Say ''
Say '==============================================================' Magenta
Say '  DONE: verified, committed, pushed' Green
Say '==============================================================' Magenta
Say ''
