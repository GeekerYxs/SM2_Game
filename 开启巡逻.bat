@echo off
chcp 65001 >nul
title 开启巡逻 [SM2_Game]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\TogglePatrol.ps1" -Action START
pause
