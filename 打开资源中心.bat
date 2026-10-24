@echo off
title AI 桌面下载中心
cd /d "%~dp0"

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
