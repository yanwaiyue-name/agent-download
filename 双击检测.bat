@echo off
chcp 65001 >nul 2>&1
title Check My PC - Which Version Should I Install
cd /d "%~dp0"

where powershell >nul 2>&1
if errorlevel 1 (
    echo.
    echo   [ERROR] PowerShell not found on this system.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0check-pc.ps1" -NoPause

echo.
pause
