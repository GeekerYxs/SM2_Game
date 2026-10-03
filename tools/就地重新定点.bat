@echo off
title 就地重新定点
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0TogglePatrol.ps1" -Action ANCHOR
