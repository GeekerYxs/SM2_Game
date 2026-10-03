@echo off
chcp 65001 >nul
title 设置巡逻坐标 [SM2_Game]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\SetPatrolPoints.ps1" -Ax "%~1" -Ay "%~2" -Bx "%~3" -By "%~4"
pause
