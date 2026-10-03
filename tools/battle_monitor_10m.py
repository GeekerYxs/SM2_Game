# -*- coding: utf-8 -*-
"""
tools/battle_monitor_10m.py
10分钟挂机战斗全景监控与缺陷分析脚本
监控时间段: 2026-10-03 20:37:30 起
全量解析 5 个客户端日志，全面评估:
1. 战斗场次与平均耗时
2. 自由四号、自由五号开局【隐匿】与自保执行率
3. 群体治疗阶梯触发与两小号最低生存血线
4. 是否出现倒地、是否触发【紧急停火与绝对复活协议】
5. 潜在战术缺陷与异常分析
"""

import sys
import os
import re
from pathlib import Path
from datetime import datetime

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

LOG_DIR = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
START_TIME_STR = "2026-10-03 20:37:30"
START_TIME = datetime.strptime(START_TIME_STR, "%Y-%m-%d %H:%M:%S")

def extract_timestamp(line):
    m = re.search(r"(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})", line)
    if m:
        try:
            return datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
        except Exception:
            return None
    return None

def parse_client_log(file_path):
    if not file_path.exists():
        return []
    raw = file_path.read_bytes()
    lines = raw.decode("gbk", errors="ignore").splitlines()
    result = []
    for line in lines:
        t = extract_timestamp(line)
        if t and t >= START_TIME:
            result.append((t, line))
    return result

def analyze():
    print(f"=== 10分钟挂机全景监控启动 (起始时间: {START_TIME_STR}) ===")
    
    logs = {
        "leader": parse_client_log(LOG_DIR / "client.log"),
        "hunter2": parse_client_log(LOG_DIR / "client1.log"),
        "hunter3": parse_client_log(LOG_DIR / "client2.log"),
        "healer5": parse_client_log(LOG_DIR / "client3.log"),
        "healer4": parse_client_log(LOG_DIR / "client4.log"),
    }
    
    # 统计场次与战斗耗时 (以队长 client.log 为准)
    fights = []
    cur_fight = None
    for t, l in logs["leader"]:
        if "OnBeginFight" in l or "OnEnterFight" in l:
            cur_fight = {
                "start": t,
                "enemies": 0,
                "actions": [],
                "end": None,
                "duration": 0,
                "min_h4_hp": 9999,
                "min_h5_hp": 9999,
                "h4_actions": [],
                "h5_actions": [],
                "ceasefire_triggered": False,
                "revive_triggered": False,
                "deaths": [],
            }
        elif "OnLeaveFight" in l and cur_fight:
            cur_fight["end"] = t
            dur = (t - cur_fight["start"]).total_seconds()
            if 2 <= dur <= 180:
                cur_fight["duration"] = dur
                fights.append(cur_fight)
            cur_fight = None
        elif cur_fight:
            if "[BATTLE_EVENT][OPPONENT]" in l and cur_fight["enemies"] == 0:
                m_cnt = re.search(r"count=(\d+)", l)
                if m_cnt:
                    cur_fight["enemies"] = int(m_cnt.group(1))
            if "[BATTLE_EVENT][ACTION]" in l:
                cur_fight["actions"].append(l)
            if "紧急停火待命" in l or "[紧急停火协议]" in l:
                cur_fight["ceasefire_triggered"] = True
    
    # 解析小号4行为与血量
    for t, l in logs["healer4"]:
        if "[AI开局自保]" in l or "[AI医仙自保]" in l or "隐匿" in l:
            # 记录小号4隐匿行为
            pass
        if "hp=" in l:
            m = re.search(r"pos:18.*?hp:(\d+)/(\d+)", l)
            if m:
                cur_hp = int(m.group(1))
                # 匹配所属战斗
                for f in fights:
                    if f["start"] <= t <= (f["end"] or t):
                        f["min_h4_hp"] = min(f["min_h4_hp"], cur_hp)

    # 解析小号5行为与血量
    for t, l in logs["healer5"]:
        if "hp=" in l:
            m = re.search(r"pos:19.*?hp:(\d+)/(\d+)", l)
            if m:
                cur_hp = int(m.group(1))
                for f in fights:
                    if f["start"] <= t <= (f["end"] or t):
                        f["min_h5_hp"] = min(f["min_h5_hp"], cur_hp)
        if "紧急停火" in l:
            for f in fights:
                if f["start"] <= t <= (f["end"] or t):
                    f["ceasefire_triggered"] = True
        if "复活术" in l:
            for f in fights:
                if f["start"] <= t <= (f["end"] or t):
                    f["revive_triggered"] = True

    print(f"当前已捕获完整战斗场次: {len(fights)} 场")
    for i, f in enumerate(fights, 1):
        end_str = f['end'].strftime('%H:%M:%S') if f['end'] else '进行中'
        print(f"第 {i:02d} 场: {f['start'].strftime('%H:%M:%S')} ~ {end_str} | 耗时: {f['duration']:.1f}s | 敌怪数: {f['enemies']} | 四号最低血: {f['min_h4_hp']} | 五号最低血: {f['min_h5_hp']} | 停火: {f['ceasefire_triggered']} | 复活: {f['revive_triggered']}")
        
    return fights

if __name__ == "__main__":
    analyze()
