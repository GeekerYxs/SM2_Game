@echo off
chcp 65001 >nul
title 巡逻中控台
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0PatrolDashboard.ps1"
pause
