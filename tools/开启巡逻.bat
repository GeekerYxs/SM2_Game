@echo off
chcp 65001 >nul
title 开启巡逻
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0TogglePatrol.ps1" -Action START
echo.
pause
