@echo off
chcp 65001 >nul
title 什么什么大冒险2 自动答题系统 [外部总开关]
cd /d "%~dp0"

echo ===================================================================
echo             什么什么大冒险2 自动答题系统 [纯网络层·多开守护总开关]
echo ===================================================================
echo  [*] 工作模式: 纯网络层协议收发 (零拦截弹窗、零模拟鼠标、零风险闪退)
echo  [*] 多开守护: 实时自动守护所有游戏进程 (已有进程 + 新启动窗口，全自动热注入)
echo  [*] 使用说明: 保持本窗口常驻运行 = 自动答题；关闭本窗口 = 关闭答题
echo ===================================================================
echo.

set "PY_EXE="
if exist "C:\Users\R\.workbuddy\binaries\python\versions\3.13.12\python.exe" (
    set "PY_EXE=C:\Users\R\.workbuddy\binaries\python\versions\3.13.12\python.exe"
)
if not defined PY_EXE (
    if exist "C:\Users\R\.workbuddy\binaries\python\envs\default\Scripts\python.exe" (
        set "PY_EXE=C:\Users\R\.workbuddy\binaries\python\envs\default\Scripts\python.exe"
    )
)
if not defined PY_EXE (
    set "PY_EXE=python"
)

"%PY_EXE%" controller\quizbot.py

echo.
echo [*] 答题服务已停止。
pause