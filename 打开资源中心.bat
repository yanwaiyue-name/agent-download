@echo off
chcp 65001 >nul 2>&1
rem 本文件必须保存为 UTF-8（无 BOM）。chcp 之后 cmd 才按 UTF-8 解析下面的中文；
rem 此前版本存的是 GBK，系统开了「Beta: UTF-8」时会误报「文件不完整」。
title AI 桌面下载中心
cd /d "%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
    echo.
    echo   [ERROR] PowerShell not found on this system.
    echo.
    pause
    exit /b 1
)

if not exist "资源中心.html" goto :nofile
if not exist "资源中心服务.ps1" goto :nofile
if not exist "sources.json" goto :nofile

start "AI桌面下载中心" powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0资源中心服务.ps1"
exit /b 0

:nofile
echo.
echo   [X] 文件不完整，找不到以下之一：
echo       资源中心.html / 资源中心服务.ps1 / sources.json
echo.
echo   请确认整个文件夹已完整解压，不要只复制单个文件。
echo.
pause
exit /b 1
