@echo off
chcp 65001 >nul
title 什么什么大冒险2 自动答题系统 [根目录快捷入口]
cd /d "%~dp0quizbot"

if exist "启动自动答题.bat" (
    call "启动自动答题.bat"
) else (
    echo [!] 错误: quizbot\启动自动答题.bat 不存在！
    pause
)
