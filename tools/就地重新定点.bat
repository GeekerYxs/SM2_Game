@echo off
chcp 65001 >nul
title 就地重新定点
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0TogglePatrol.ps1" -Action ANCHOR
echo.
pause
