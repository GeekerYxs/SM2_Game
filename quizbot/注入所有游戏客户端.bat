@echo off
chcp 65001 >nul
title 注入所有游戏客户端
cd /d "%~dp0"

echo [*] 正在扫描并注入所有 WAATClient.exe 游戏客户端...
if exist "build\injector.exe" (
    "build\injector.exe"
) else (
    echo [!] 错误: build\injector.exe 不存在，请先编译。
)

echo.
pause
