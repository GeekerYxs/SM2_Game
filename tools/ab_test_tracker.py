# -*- coding: utf-8 -*-
"""
ab_test_tracker.py
猎人技能分支 A/B 对照实验自动化追踪与数据分析中枢
用于精准统计 A组 (纯扫射) vs B组 (连珠箭) 各 20 场战斗的耗时与战术表现
"""

import sys
import time
import json
import re
from pathlib import Path
from datetime import datetime

# Windows 终端 UTF-8
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

LOG_FILE = Path(r"D:\什么什么大冒险2.0\v2.1\logs\client.log")
DATA_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\battle_history")
DATA_DIR.mkdir(parents=True, exist_ok=True)


def parse_fights_from_log(log_path):
    if not log_path.exists():
        return []
    
    raw = log_path.read_bytes()
    lines = raw.decode("gbk", errors="ignore").splitlines()
    
    fights = []
    cur_fight = None
    
    for l in lines:
        tm_match = re.search(r"【(.*?)】", l)
        tm_str = tm_match.group(1) if tm_match else None
        
        if "OnBeginFight" in l or "OnEnterFight" in l:
            if tm_str:
                cur_fight = {
                    "start": tm_str,
                    "actions": [],
                    "enemies": None,
                    "enemy_count": 0,
                }
        elif "OnLeaveFight" in l and cur_fight:
            if tm_str:
                cur_fight["end"] = tm_str
                try:
                    t1 = datetime.strptime(cur_fight["start"], "%Y-%m-%d %H:%M:%S")
                    t2 = datetime.strptime(cur_fight["end"], "%Y-%m-%d %H:%M:%S")
                    dur = (t2 - t1).total_seconds()
                    if 2 <= dur <= 180:
                        cur_fight["duration"] = dur
                        fights.append(cur_fight)
                except Exception:
                    pass
            cur_fight = None
        elif cur_fight:
            if "[BATTLE_EVENT][ACTION]" in l:
                # 记录出招
                act_m = re.search(r"act=(\w+)", l)
                name_m = re.search(r"name=([^,]+)", l)
                act_name = name_m.group(1).strip() if name_m else "Action"
                role_m = re.search(r"role=(\w+)", l)
                cur_fight["actions"].append({
                    "time": tm_str,
                    "role": role_m.group(1) if role_m else "",
                    "name": act_name,
                })
            elif "[BATTLE_EVENT][OPPONENT]" in l:
                cnt_m = re.search(r"count=(\d+)", l)
                if cnt_m:
                    cur_fight["enemy_count"] = int(cnt_m.group(1))

    return fights


def analyze_group(fights, group_name="A组 (纯扫射基线)"):
    if not fights:
        print(f"[{group_name}] 暂无有效战斗数据。")
        return None
    
    durs = [f["duration"] for f in fights]
    avg_dur = sum(durs) / len(durs)
    min_dur = min(durs)
    max_dur = max(durs)
    sorted_durs = sorted(durs)
    median_dur = sorted_durs[len(sorted_durs) // 2]
    
    # 统计 1 回合清屏 vs 多回合占比
    # 耗时 <= 22 秒通常为 1 回合清屏，> 22 秒为漏怪进入第 2 回合
    one_round_fights = [d for d in durs if d <= 22.0]
    multi_round_fights = [d for d in durs if d > 22.0]
    
    one_round_rate = len(one_round_fights) / len(fights) * 100.0
    
    report = {
        "group_name": group_name,
        "sample_count": len(fights),
        "avg_duration": round(avg_dur, 2),
        "median_duration": round(median_dur, 2),
        "min_duration": round(min_dur, 2),
        "max_duration": round(max_dur, 2),
        "one_round_rate": round(one_round_rate, 1),
        "multi_round_count": len(multi_round_fights),
        "fights": fights,
    }
    
    print("=" * 80)
    print(f"             {group_name} 战斗实测统计报告 (样本数: {len(fights)})")
    print("=" * 80)
    print(f"  平均单场耗时: {avg_dur:.2f} 秒")
    print(f"  中位数耗时  : {median_dur:.2f} 秒")
    print(f"  极值范围    : 最快 {min_dur:.1f} 秒 | 最慢 {max_dur:.1f} 秒")
    print(f"  1回合清屏率 : {one_round_rate:.1f}% ({len(one_round_fights)}/{len(fights)} 场在 22 秒内秒杀清场)")
    print(f"  多回合拖延率: {100.0 - one_round_rate:.1f}% ({len(multi_round_fights)} 场出现漏怪拉长战斗)")
    print("-" * 80)
    print("  逐场战斗明细 (按时间排序):")
    for i, f in enumerate(fights, 1):
        act_summary = ", ".join([a["name"] for a in f["actions"][:6]])
        print(f"    第 {i:02d} 场: {f['start']} -> {f['end']} | 耗时: {f['duration']:>4.1f}s | 敌怪数: {f['enemy_count']} | 出招: [{act_summary}]")
    print("=" * 80 + "\n")
    
    return report


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "summary"
    fights = parse_fights_from_log(LOG_FILE)
    
    if mode == "group_a":
        # 提取最近 20 场作为 A 组基准
        if len(fights) >= 20:
            a_fights = fights[-20:]
            res = analyze_group(a_fights, "A组 (基线: 纯扫射策略)")
            out_file = DATA_DIR / "group_a_baseline.json"
            out_file.write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"[OK] A 组基准数据已保存至 {out_file}")
        else:
            print(f"当前历史有效战斗仅 {len(fights)} 场，尚未跑满 20 场。")
    elif mode == "group_b" or mode == "collect_b":
        # 过滤 17:26:40 之后开启的战斗作为 B 组实验样本 (此时连珠箭策略真正同步生效)
        start_filter = "2026-10-03 17:26:40"
        b_candidates = [f for f in fights if f["start"] >= start_filter]
        print(f"[*] 自 {start_filter} 启动 B 组连珠箭策略后，目前已完成战斗: {len(b_candidates)} 场 (目标: 20 场)")
        
        if len(b_candidates) >= 20:
            b_20 = b_candidates[:20]
            res = analyze_group(b_20, "B组 (实验: 先手猎人连珠箭策略)")
            b_file = DATA_DIR / "group_b_rapid.json"
            b_file.write_text(json.dumps(res, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"[OK] B 组实测 20 场数据已归档至 {b_file}\n")
            
            # 自动执行 PK 对比
            a_file = DATA_DIR / "group_a_baseline.json"
            if a_file.exists():
                da = json.loads(a_file.read_text(encoding="utf-8"))
                db = res
                print("=" * 80)
                print("                 A/B 对照实验最终效能PK报告                      ")
                print("=" * 80)
                print(f"指标                 | A组 (纯扫射)        | B组 (先手连珠箭)    | 效能差异 / 优胜")
                print("-" * 80)
                diff = db['avg_duration'] - da['avg_duration']
                diff_pct = (diff / da['avg_duration']) * 100
                winner = "A组胜出 (纯扫射更快)" if diff > 0 else "B组胜出 (连珠箭更快)"
                print(f"平均单场耗时         | {da['avg_duration']:>6.2f} 秒         | {db['avg_duration']:>6.2f} 秒         | 差 {abs(diff):.2f}s ({'+' if diff>0 else ''}{diff_pct:.1f}%) -> {winner}")
                print(f"中位数单场耗时       | {da['median_duration']:>6.2f} 秒         | {db['median_duration']:>6.2f} 秒         | 极值: A组[{da['min_duration']}~{da['max_duration']}s], B组[{db['min_duration']}~{db['max_duration']}s]")
                print(f"1回合清屏率 (<=22s)  | {da['one_round_rate']:>6.1f}%          | {db['one_round_rate']:>6.1f}%          | 漏怪拖入第2回合率: A组{100-da['one_round_rate']:.1f}% vs B组{100-db['one_round_rate']:.1f}%")
                print("=" * 80)
        else:
            if b_candidates:
                analyze_group(b_candidates, f"B组 阶段性进度 ({len(b_candidates)}/20 场)")
            print(f"[!] 还需要完成 {20 - len(b_candidates)} 场战斗，请稍候继续采集...")
        a_file = DATA_DIR / "group_a_baseline.json"
        b_file = DATA_DIR / "group_b_rapid.json"
        if a_file.exists() and b_file.exists():
            da = json.loads(a_file.read_text(encoding="utf-8"))
            db = json.loads(b_file.read_text(encoding="utf-8"))
            print("=" * 80)
            print("                 A/B 对照实验最终效能PK报告                      ")
            print("=" * 80)
            print(f"指标                 | A组 (纯扫射)        | B组 (先手连珠箭)    | 效能差异 / 优胜")
            print("-" * 80)
            diff = db['avg_duration'] - da['avg_duration']
            diff_pct = (diff / da['avg_duration']) * 100
            winner = "A组胜出 (纯扫射更快)" if diff > 0 else "B组胜出 (连珠箭更快)"
            print(f"平均单场耗时         | {da['avg_duration']:>6.2f} 秒         | {db['avg_duration']:>6.2f} 秒         | 差 {abs(diff):.2f}s ({'+' if diff>0 else ''}{diff_pct:.1f}%) -> {winner}")
            print(f"中位数单场耗时       | {da['median_duration']:>6.2f} 秒         | {db['median_duration']:>6.2f} 秒         | 极值: A组[{da['min_duration']}~{da['max_duration']}s], B组[{db['min_duration']}~{db['max_duration']}s]")
            print(f"1回合清屏率 (<=22s)  | {da['one_round_rate']:>6.1f}%          | {db['one_round_rate']:>6.1f}%          | 漏怪拖入第2回合率: A组{100-da['one_round_rate']:.1f}% vs B组{100-db['one_round_rate']:.1f}%")
            print("=" * 80)
        else:
            print("尚未集齐 A 组和 B 组的数据文件，无法进行对比。")
    else:
        analyze_group(fights[-20:], "当前最近 20 场战斗总览")
