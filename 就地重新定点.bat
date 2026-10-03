@echo off
chcp 65001 >nul
title 就地重新定点 [SM2_Game]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\TogglePatrol.ps1" -Action ANCHOR
pause
