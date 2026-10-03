@echo off
chcp 65001 >nul
title SetPatrolPoints
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0SetPatrolPoints.ps1" -Ax "%~1" -Ay "%~2" -Bx "%~3" -By "%~4"
pause
