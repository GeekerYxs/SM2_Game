@echo off
title 大冒险2 自动答题机器人 [外部总开关]
cd /d "%~dp0"

echo ===================================================================
echo             大冒险2 自动答题系统 [纯网络层·多开守护总开关]
echo ===================================================================
echo  [*] 工作模式: 纯网络层协议收发 [不拦截弹窗、不模拟点击、零封号风险]
echo  [*] 多开监控: 实时自动守护所有游戏窗口 [现有的+新开的，全自动注入]
echo  [*] 开关说明: 本窗口保持运行 = 开启答题；关闭本窗口 = 关闭答题
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