@echo off
chcp 65001 >nul
title 5账号战斗全景遥测与数据分析中枢
echo ================================================================================
echo                     5账号全量战斗全景遥测监控分析中枢
echo ================================================================================
echo.
echo 正在启动全天候战斗监测...
echo.

set PYTHON_EXE=C:\Users\R\.venv-html-to-docx\Scripts\python.exe
if not exist "%PYTHON_EXE%" (
    set PYTHON_EXE=python
)

"%PYTHON_EXE%" "%~dp0battle_telemetry_monitor.py"

pause
