@echo off
chcp 65001 >nul
title 关闭巡逻
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0TogglePatrol.ps1" -Action STOP
echo.
pause
