# -*- coding: utf-8 -*-
"""
tools/deep_battle_telemetry_analyzer.py
深度解析今晚 5 人队伍持续战斗日志 (17:05 ~ 至今) 全量遥测数据
基于动作类型 (Act) 与技能 ID (Skill/Magic ID) 进行 100% 精确统计，彻底规避日志字符集乱码。
"""

import sys
import os
import re
import json
from pathlib import Path
from datetime import datetime
from collections import defaultdict, Counter

sys.stdout.reconfigure(encoding='utf-8')

LOG_DIR = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
RECORDS_FILE = Path(r"d:\Codes\GG_Antigravity\smsm2-game\battle_history\battle_records.jsonl")

ID_NAME_MAP = {
    0: "普通攻击/待命",
    104: "强力攻击",
    206: "嘲讽",
    207: "群体嘲讽",
    208: "反戈一击",
    209: "突击",
    212: "隐匿",
    303: "治疗术",
    304: "强愈术",
    305: "群体治疗术",
    306: "复活术",
    307: "保护盾/痛击",
    308: "能量射击/神佑",
    309: "精准射击/回复术",
    310: "连珠箭/心灵震撼",
    313: "急救术",
    350: "法术震荡",
    354: "天之箭",
    355: "魔法盾",
    606: "怒气斩",
    702: "五雷穿心掌",
    707: "元气斩",
    710: "顺势劈",
    803: "扫射",
    903: "刺杀",
    1501: "火球术",
    1502: "烈火",
    1503: "烈焰",
    1504: "烈焰爆发",
    1506: "烈焰风暴",
}

def extract_ts(line):
    m = re.search(r"【(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})】", line)
    if m:
        try:
            return datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
        except:
            pass
    return None

def analyze_all_logs():
    print("[*] 开始全量深度解析 5 客户端日志 (精确ID映射模式)...")
    
    leader_path = LOG_DIR / "client.log"
    if not leader_path.exists():
        print(f"[!] 找不到 {leader_path}")
        return

    battles = []
    current_battle = None
    
    with open(leader_path, "r", encoding="gb18030", errors="replace") as f:
        for line in f:
            t = extract_ts(line)
            if not t:
                continue

            if "OnBeginFight" in line or "OnEnterFight" in line:
                if current_battle and not current_battle["end"]:
                    current_battle["end"] = t
                    dur = (current_battle["end"] - current_battle["start"]).total_seconds()
                    current_battle["duration"] = dur
                    if 1 <= dur <= 300:
                        battles.append(current_battle)

                current_battle = {
                    "id": len(battles) + 1,
                    "start": t,
                    "end": None,
                    "duration": 0,
                    "enemies": [],
                    "enemy_count": 0,
                    "actions": [],
                    "ceasefire": False,
                    "revive": False,
                }
            elif "OnLeaveFight" in line or "OnFightLeave" in line:
                if current_battle and not current_battle["end"]:
                    current_battle["end"] = t
                    dur = (t - current_battle["start"]).total_seconds()
                    current_battle["duration"] = dur
                    if 1 <= dur <= 300:
                        battles.append(current_battle)
                    current_battle = None
            elif current_battle:
                if "[BATTLE_EVENT][OPPONENT]" in line and current_battle["enemy_count"] == 0:
                    m_cnt = re.search(r"count=(\d+)", line)
                    if m_cnt:
                        current_battle["enemy_count"] = int(m_cnt.group(1))
                if "[BATTLE_EVENT][ACTION]" in line:
                    current_battle["actions"].append((t, line.strip()))
                if "绝对复活" in line or "紧急复活" in line or "复活术" in line:
                    current_battle["revive"] = True
                if "全员绝对停火" in line or "紧急停火" in line:
                    current_battle["ceasefire"] = True

    if current_battle and not current_battle["end"]:
        current_battle["end"] = datetime.now()
        current_battle["duration"] = (current_battle["end"] - current_battle["start"]).total_seconds()
        battles.append(current_battle)

    # 扫描各个客户端真实的位号与角色名映射
    pos_meta = {
        10: "魔力布老虎 (Pet, 主力火宠)",
        11: "魔力布老虎 (Pet, 主力火宠)",
        12: "魔力布老虎 (Pet, 主力火宠)",
        13: "快跑葫芦娃 (Pet, 辅助随宠)",
        14: "快跑葫芦娃 (Pet, 辅助随宠)",
        15: "伏地魔2 (Player, Lv70 猎人大号)",
        16: "自由五号 (Player, Lv48 医仙小号)",
        17: "伏地魔1 (Player, Lv70 队长猎人)",
        18: "伏地魔3 (Player, Lv70 猎人大号)",
        19: "自由四号 (Player, Lv48 医仙小号)",
    }

    action_stats = defaultdict(lambda: Counter())
    total_actions_count = 0
    total_revives = 0
    total_ceasefires = 0
    anomalies = []

    client_logs = [f"client{i}.log" if i > 0 else "client.log" for i in range(5)]
    for cf in client_logs:
        p = LOG_DIR / cf
        if not p.exists(): continue
        with open(p, "r", encoding="gb18030", errors="replace") as f:
            for line in f:
                t = extract_ts(line)
                if "[BATTLE_EVENT][ACTION]" in line:
                    total_actions_count += 1
                    m_role = re.search(r"role=([^,]+)", line)
                    m_act = re.search(r"act=([^,]+)", line)
                    m_id = re.search(r"id=(\d+)", line)
                    m_pos = re.search(r"pos=(\d+)", line)

                    role = m_role.group(1).strip() if m_role else "Unknown"
                    act = m_act.group(1).strip() if m_act else "Unknown"
                    sid = int(m_id.group(1)) if m_id else 0
                    pos = int(m_pos.group(1)) if m_pos else -1

                    # 规范化动作名称
                    act_name = ID_NAME_MAP.get(sid, f"ID_{sid}")
                    if act == "NormalAttack":
                        act_key = "普通攻击 (NormalAttack)"
                    elif act == "Standby":
                        act_key = "战术待命 (Standby)"
                    else:
                        act_key = f"{act}:{act_name} (ID:{sid})"

                    role_desc = pos_meta.get(pos, f"{role} Pos {pos}")
                    action_stats[role_desc][act_key] += 1

                if "宠物执行普通攻击" in line or ("role=Pet" in line and "act=NormalAttack" in line):
                    anomalies.append((t, cf, "宠物异常普攻", line.strip()))
                if ("pos=16" in line and "act=NormalAttack" in line and "role=Player" in line) or ("pos=19" in line and "act=NormalAttack" in line and "role=Player" in line):
                    anomalies.append((t, cf, "医仙小号异常普攻", line.strip()))
                if "紧急复活" in line or "施放【复活术" in line:
                    total_revives += 1
                if "全员绝对停火" in line or "[紧急停火协议]" in line:
                    total_ceasefires += 1

    valid_battles = [b for b in battles if b["duration"] >= 3]
    durations = [b["duration"] for b in valid_battles]
    enemy_counts = [b["enemy_count"] for b in valid_battles if b["enemy_count"] > 0]

    avg_dur = sum(durations) / len(durations) if durations else 0
    max_dur = max(durations) if durations else 0
    min_dur = min(durations) if durations else 0
    avg_enemies = sum(enemy_counts) / len(enemy_counts) if enemy_counts else 0

    dur_lt_10s = sum(1 for d in durations if d < 10)
    dur_10_20s = sum(1 for d in durations if 10 <= d < 20)
    dur_20_30s = sum(1 for d in durations if 20 <= d < 30)
    dur_gt_30s = sum(1 for d in durations if d >= 30)

    print("\n==================== 1. 宏观战斗性能基准 (今晚连续实战) ====================")
    print(f"总战斗场次: {len(valid_battles)} 场")
    if valid_battles:
        print(f"统计时间段: {valid_battles[0]['start']} ~ {valid_battles[-1]['start']}")
    print(f"平均每场耗时: {avg_dur:.2f} 秒 (极值: 最快 {min_dur:.1f}s / 最慢 {max_dur:.1f}s)")
    print(f"平均每场怪数: {avg_enemies:.2f} 只")
    print(f"战斗时长分布:")
    print(f"  极速清场 (<10s) : {dur_lt_10s:>4} 场 ({dur_lt_10s/len(durations)*100:>5.1f}%)")
    print(f"  标准速胜 (10~20s): {dur_10_20s:>4} 场 ({dur_10_20s/len(durations)*100:>5.1f}%)")
    print(f"  拉锯中盘 (20~30s): {dur_20_30s:>4} 场 ({dur_20_30s/len(durations)*100:>5.1f}%)")
    print(f"  异常拖沓 (>30s)  : {dur_gt_30s:>4} 场 ({dur_gt_30s/len(durations)*100:>5.1f}%)")

    print("\n==================== 2. 真实阵容与位号映射表 (消除历史错位) ====================")
    for p, desc in sorted(pos_meta.items()):
        print(f"  Pos {p:<2} : {desc}")

    print("\n==================== 3. 全员精确技能出招画像 (精准ID解析) ====================")
    summary_data = {}
    for role_name, actions in sorted(action_stats.items()):
        total_act = sum(actions.values())
        print(f"\n【{role_name}】 (总决策: {total_act} 次):")
        summary_data[role_name] = {}
        for act_desc, count in actions.most_common(10):
            ratio = count / total_act * 100
            print(f"   * {act_desc:<35} : {count:>5} 次 ({ratio:>5.1f}%)")
            summary_data[role_name][act_desc] = count

    # 持久化输出
    clean_summary = {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_battles": len(valid_battles),
        "avg_duration": round(avg_dur, 2),
        "max_duration": max_dur,
        "min_duration": min_dur,
        "avg_enemies": round(avg_enemies, 2),
        "duration_distribution": {
            "<10s": dur_lt_10s,
            "10-20s": dur_10_20s,
            "20-30s": dur_20_30s,
            ">30s": dur_gt_30s
        },
        "total_ceasefires": total_ceasefires,
        "total_revives": total_revives,
        "real_anomalies_count": len(anomalies),
        "actions_by_fighter": summary_data
    }
    
    out_file = Path(r"d:\Codes\GG_Antigravity\smsm2-game\battle_history\deep_combat_telemetry_clean.json")
    out_file.write_text(json.dumps(clean_summary, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n[+] 精确遥测报告已生成: {out_file}")

if __name__ == '__main__':
    analyze_all_logs()
