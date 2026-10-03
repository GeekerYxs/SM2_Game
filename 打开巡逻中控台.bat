@echo off
chcp 65001 >nul
title 巡逻中控台 [SM2_Game]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\PatrolDashboard.ps1"
pause
