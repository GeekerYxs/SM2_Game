# -*- coding: utf-8 -*-
"""
[已彻底禁用 - DANGEROUS HOT-RELOAD DISABLED]
此脚本已被永久禁用并拦截！

原因分析：
1. WaatClient.exe 具有动态基址重定位特性（实测基址为 0x110000），硬编码任何 VA 均会指向不可执行的数据段（.data，0x58dc60），
   触发 Windows 数据执行保护 (DEP)，抛出 EXCEPTION_ACCESS_VIOLATION (0xC0000005) 导致进程崩溃！
2. CGameLua 状态机属于游戏单线程渲染主循环，任何通过 CreateRemoteThread 注入的远程线程重载，均会在游戏主线程执行
   帧回调/封包派发时产生致命线程竞争，彻底破坏 LuaState 堆栈并导致全体客户端秒退闪退！
3. 所有策略与脚本修改请通过 deploy_ai_strategy.py 落盘即可，待客户端下次启动或换线时天然安全加载，严禁进程内注入热重载！
"""

import sys

def main():
    print("=" * 70)
    print("【严重安全警告】禁止执行远程线程 Lua 热重载！")
    print("WaatClient.exe 启用动态基址且 LuaState 属于单线程主循环。")
    print("远程注入会直接导致全体游戏客户端崩溃闪退 (0xC0000005 越界执行)！")
    print("所有策略已通过 deploy_ai_strategy.py 安全落盘，下次启动/换线自动加载。")
    print("=" * 70)
    sys.exit(1)

if __name__ == "__main__":
    main()
