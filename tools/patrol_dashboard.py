# -*- coding: utf-8 -*-
"""
SMSM2 独立巡逻与多智能体战术中控台 (SMSM2 Patrol & Combat Dashboard)
"""
import sys
import os
import time
from pathlib import Path

GAME_DIR = Path(r"D:\什么什么大冒险2.0\v2.1")
CONFIG_PATH = GAME_DIR / "patrol_config.ini"
STATUS_PATH = GAME_DIR / "patrol_status.ini"
LOG_DIR = GAME_DIR / "logs"

def parse_ini(p: Path) -> dict:
    data = {}
    if not p.exists():
        return data
    try:
        content = p.read_text(encoding='utf-8')
    except Exception:
        try:
            content = p.read_text(encoding='gbk')
        except Exception:
            return data
    for line in content.splitlines():
        line = line.strip()
        if not line or line.startswith('#') or line.startswith(';'):
            continue
        if '=' in line:
            k, v = line.split('=', 1)
            k = k.strip()
            v = v.strip()
            if v.lower() == 'true':
                data[k] = True
            elif v.lower() == 'false':
                data[k] = False
            elif v.isdigit():
                data[k] = int(v)
            else:
                data[k] = v
    return data

def write_ini(p: Path, data: dict):
    lines = []
    lines.append("# SMSM2 Patrol Configuration")
    for k, v in data.items():
        if isinstance(v, bool):
            val_str = "true" if v else "false"
        else:
            val_str = str(v)
        lines.append(f"{k} = {val_str}")
    p.write_text("\n".join(lines) + "\n", encoding='utf-8')

def get_client_summary():
    clients = []
    if not LOG_DIR.exists():
        return clients
    for idx in range(10):
        log_name = f"client{idx if idx > 0 else ''}.log"
        lp = LOG_DIR / log_name
        if not lp.exists() or lp.stat().st_size == 0:
            continue
        # Check if modified in last 10 mins
        if (time.time() - lp.stat().st_mtime) > 600:
            continue
        try:
            lines = lp.read_text(encoding='gbk', errors='ignore').splitlines()[-40:]
        except Exception:
            continue
        
        pos = "未知"
        role = "队员"
        action = "待命"
        for line in reversed(lines):
            if "myPos=" in line:
                import re
                m = re.search(r'myPos=(\d+)', line)
                if m: pos = m.group(1)
            if "AI自省-主角" in line:
                if "扫射" in line or "连珠箭" in line:
                    role = "【大号主力-猎人】"
                elif "群体治疗术" in line:
                    role = "【保姆小号-医仙】"
            if "AI施法-主角" in line or "AI协同" in line or "AI群疗护航" in line:
                if "群体治疗术" in line:
                    action = "释放 [群体治疗术]"
                elif "扫射" in line:
                    action = "释放 [扫射]"
                elif "连珠箭" in line:
                    action = "释放 [连珠箭]"
                elif "待机待命" in line:
                    action = "防御待命"
                elif "天之箭" in line:
                    action = "释放 [天之箭]"
                elif "法术飞弹" in line:
                    action = "释放 [法术飞弹]"
        clients.append({"log": log_name, "pos": pos, "role": role, "action": action})
    return clients

def print_dashboard():
    os.system('cls' if os.name == 'nt' else 'clear')
    cfg = parse_ini(CONFIG_PATH)
    st = parse_ini(STATUS_PATH)
    
    print("=" * 68)
    print("     什么什么大冒险 2.0 - 巡逻控制与多智能体中控台 (v2.0)     ")
    print("=" * 68)
    
    leader_name = cfg.get("LeaderName", "伏地魔")
    is_enabled = cfg.get("Enabled", False)
    status_str = st.get("State", "Stopped" if not is_enabled else "Running")
    map_id = st.get("MapID", 0)
    cur_x = st.get("PlayerX", 0)
    cur_y = st.get("PlayerY", 0)
    p_ax = st.get("PointAX", cfg.get("PointAX", 0))
    p_ay = st.get("PointAY", cfg.get("PointAY", 0))
    p_bx = st.get("PointBX", cfg.get("PointBX", 0))
    p_by = st.get("PointBY", cfg.get("PointBY", 0))
    in_fight = st.get("InFight", False)
    
    status_display = "⚔️ 战斗中 (巡逻自动冻结挂起)" if in_fight else ("🚶 巡逻中 (在A-B间往返踱步)" if is_enabled else "⏹ 已停止")
    
    print(f"  👑 当前带队队长: {leader_name}")
    print(f"  🗺️ 当前地图编号: MapID = {map_id if map_id > 0 else '实时探测中'}")
    print(f"  📍 队长当前坐标: X = {cur_x}, Y = {cur_y}")
    print(f"  🚦 巡逻运行状态: {status_display}")
    print(f"  🎯 巡逻目标区间: 点A({p_ax}, {p_ay}) <===> 点B({p_bx}, {p_by})")
    print("-" * 68)
    print("  👥 在线多客户端协同战况:")
    clients = get_client_summary()
    if clients:
        for c in clients:
            print(f"    - {c['log']:<12} 位号:{c['pos']:<3} 角色:{c['role']:<14} 近期动作:{c['action']}")
    else:
        print("    (暂无活跃客户端日志或尚未进入战斗)")
    print("=" * 68)
    print("  【控制按键】:")
    print("    [1] 🚀 开启巡逻 (以队长当前站位就地智能定点往返)")
    print("    [2] ⏹ 停止巡逻 (原地驻足)")
    print("    [3] 🎯 就地重新定点 (把当前站位设为新的巡逻原点)")
    print("    [4] 👑 更换队长角色名 (换号时一键指定)")
    print("    [5] 🔄 刷新面板")
    print("    [0] 退出控制台")
    print("=" * 68)

def main():
    while True:
        print_dashboard()
        choice = input("请输入指令编号 [0-5]: ").strip()
        cfg = parse_ini(CONFIG_PATH)
        if choice == '1':
            cfg["Enabled"] = True
            cfg["Command"] = "ANCHOR"
            write_ini(CONFIG_PATH, cfg)
            print("[+] 指令已发送: 开启巡逻并在当前位置智能定点！")
            time.sleep(1.5)
        elif choice == '2':
            cfg["Enabled"] = False
            cfg["Command"] = "STOP"
            write_ini(CONFIG_PATH, cfg)
            print("[+] 指令已发送: 停止巡逻！")
            time.sleep(1.5)
        elif choice == '3':
            cfg["Enabled"] = True
            cfg["Command"] = "ANCHOR"
            cfg["PointAX"] = 0
            cfg["PointBX"] = 0
            write_ini(CONFIG_PATH, cfg)
            print("[+] 指令已发送: 正在重新抓取脚下坐标定点...")
            time.sleep(1.5)
        elif choice == '4':
            new_name = input("请输入新的队长角色名 (如: 伏地魔 / 先驱01): ").strip()
            if new_name:
                cfg["LeaderName"] = new_name
                write_ini(CONFIG_PATH, cfg)
                print(f"[+] 队长已更新为: {new_name}")
                time.sleep(1.5)
        elif choice == '5':
            continue
        elif choice == '0':
            print("退出中控台。")
            break
        else:
            print("无效输入，请重试。")
            time.sleep(1)

if __name__ == "__main__":
    main()
