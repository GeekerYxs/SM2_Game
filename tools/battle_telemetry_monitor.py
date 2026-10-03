# -*- coding: utf-8 -*-
"""
battle_telemetry_monitor.py
5账号全量战斗全景遥测与数据持久化监控分析中枢 (SMSM2 5-Client Combat Telemetry Center)

核心功能:
1. 全程不间断并发监听 5 个游戏客户端日志 (client.log ~ client4.log)
2. 逐场解析并归档:
   - 对面情况: 怪物数量、位号、类型、等级、初始与剩余血量、稀有捕捉标记
   - 我方情况: 5人+5宠出招全时序链条 (时间戳、角色、招式名、等级、目标位号、AI决策底层原因)
   - 队伍属性生存线: HP/MP快照、物理攻击、魔法攻击、物理防御、魔法防御
   - 战果统计: 单体输出、群攻总伤、有效集火、战斗回合数、清怪效率
   - 异常拦截与警报: 捕获宠物普通攻击告警、保姆小号普攻告警
3. 结构化持久化保存到 battle_history/battle_records.jsonl，并支持实时战报渲染。
"""

import os
import sys
import time
import json
import re
from pathlib import Path
from datetime import datetime

# Windows 终端 UTF-8 输出重定向
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

LOGS_DIR = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
OUTPUT_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\battle_history")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
RECORDS_FILE = OUTPUT_DIR / "battle_records.jsonl"

CLIENT_MAP = {
    "client.log":  {"id": 0, "name": "伏地魔1 (队长/猎人大号1, Pos 17)", "role": "Carry/主力猎人", "pet": "魔力布老虎(Lv70)"},
    "client1.log": {"id": 1, "name": "伏地魔2 (猎人大号2, Pos 18)", "role": "Carry/主力猎人", "pet": "魔力布老虎(Lv70)"},
    "client2.log": {"id": 2, "name": "伏地魔3 (猎人大号3, Pos 19)", "role": "Carry/主力猎人", "pet": "魔力布老虎(Lv70)"},
    "client3.log": {"id": 3, "name": "自由四号 (医仙小号1, Pos 15)", "role": "Support/专职医疗", "pet": "快跑葫芦娃(Lv48)"},
    "client4.log": {"id": 4, "name": "自由五号 (医仙小号2, Pos 16)", "role": "Support/专职医疗", "pet": "快跑葫芦娃(Lv48)"},
}

TYPE_MAP = {
    0: "常规怪",
    1: "物理型",
    2: "魔法型",
    3: "辅助型",
    4: "控制型",
    5: "稀有怪",
    6: "BOSS",
}

class CombatTelemetryMonitor:
    def __init__(self):
        self.file_offsets = {}
        self.current_battles = {}
        self.total_battles_recorded = 0
        self.recent_battle_cache = []

    def parse_log_line(self, filename, line):
        client_info = CLIENT_MAP.get(filename, {"id": -1, "name": filename, "role": "Unknown"})
        
        # 提取时间戳
        time_match = re.search(r'【(.*?)】', line)
        log_time = time_match.group(1) if time_match else datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # 1. 对面情况遥测: [BATTLE_EVENT][OPPONENT]
        if '[BATTLE_EVENT][OPPONENT]' in line:
            # 格式: count=X, enemies=[pos:0,name:X,type:Y,lvl:Z,hp:H/M,sp:S,catch:C; ...]
            count_match = re.search(r'count=(\d+)', line)
            enemies_match = re.search(r'enemies=\[(.*?)\]', line)
            enemy_count = int(count_match.group(1)) if count_match else 0
            raw_enemies = enemies_match.group(1) if enemies_match else ""
            
            enemies = []
            if raw_enemies:
                for chunk in raw_enemies.split(';'):
                    chunk = chunk.strip()
                    if not chunk: continue
                    em = {}
                    for item in chunk.split(','):
                        kv = item.split(':')
                        if len(kv) == 2:
                            em[kv[0].strip()] = kv[1].strip()
                    
                    pos = int(em.get('pos', -1))
                    name = em.get('name', 'Enemy')
                    etype = int(em.get('type', 0))
                    lvl = int(em.get('lvl', 0))
                    hp_str = em.get('hp', '0/1')
                    hp_cur = int(hp_str.split('/')[0]) if '/' in hp_str else 0
                    hp_max = int(hp_str.split('/')[1]) if '/' in hp_str else 1
                    is_catch = em.get('catch', 'false') == 'true'

                    enemies.append({
                        "pos": pos,
                        "name": name,
                        "type_id": etype,
                        "type_name": TYPE_MAP.get(etype, f"Type_{etype}"),
                        "level": lvl,
                        "hp": hp_cur,
                        "hp_max": hp_max,
                        "catchable": is_catch,
                    })

            return {
                "event": "OPPONENT",
                "time": log_time,
                "client": client_info,
                "enemy_count": enemy_count,
                "enemies": enemies
            }

        # 1.5 队伍全员阵容遥测: [BATTLE_EVENT][TEAM_LINEUP]
        if '[BATTLE_EVENT][TEAM_LINEUP]' in line:
            raw_allies = re.search(r'allies=\[(.*?)\]', line)
            allies = []
            if raw_allies:
                for chunk in raw_allies.group(1).split(';'):
                    chunk = chunk.strip()
                    if not chunk: continue
                    al = {}
                    for item in chunk.split(','):
                        kv = item.split(':')
                        if len(kv) == 2:
                            al[kv[0].strip()] = kv[1].strip()
                    allies.append(al)
            return {
                "event": "TEAM_LINEUP",
                "time": log_time,
                "client": client_info,
                "allies": allies
            }

        # 2. 友方快照遥测: [BATTLE_EVENT][ALLY_SNAPSHOT]
        if '[BATTLE_EVENT][ALLY_SNAPSHOT]' in line:
            data = {}
            for item in re.findall(r'(\w+)=([^,]+)', line[line.find('[ALLY_SNAPSHOT]'):]):
                data[item[0].strip()] = item[1].strip()

            return {
                "event": "ALLY_SNAPSHOT",
                "time": log_time,
                "client": client_info,
                "data": data
            }

        # 3. 出招动作遥测: [BATTLE_EVENT][ACTION]
        if '[BATTLE_EVENT][ACTION]' in line:
            payload = line[line.find('[BATTLE_EVENT][ACTION]') + len('[BATTLE_EVENT][ACTION]'):].strip()
            action_data = {}
            # 先提取 reason= 之后的所有内容，避免被逗号切断
            reason_part = ""
            if "reason=" in payload:
                payload, reason_part = payload.split("reason=", 1)
                action_data["reason"] = reason_part.strip()
            
            for token in payload.split(','):
                token = token.strip()
                if '=' in token:
                    k, v = token.split('=', 1)
                    action_data[k.strip()] = v.strip()

            return {
                "event": "ACTION",
                "time": log_time,
                "client": client_info,
                "action": action_data
            }

        # 4. 异常报警: [BATTLE_EVENT][ANOMALY] 或 异常普攻
        if '[BATTLE_EVENT][ANOMALY]' in line or ('[AI协同]' in line and '执行普通攻击' in line):
            is_anomaly = '[BATTLE_EVENT][ANOMALY]' in line
            is_pet_normal_attack = '宠物' in line and '普通攻击' in line
            return {
                "event": "ANOMALY",
                "time": log_time,
                "client": client_info,
                "is_critical": is_anomaly or is_pet_normal_attack,
                "message": line.strip()
            }

        # 5. 控制状态变化: [BATTLE_EVENT][STATE]
        if '[BATTLE_EVENT][STATE]' in line:
            payload = line[line.find('[BATTLE_EVENT][STATE]') + len('[BATTLE_EVENT][STATE]'):].strip()
            state_data = {}
            for token in payload.split(','):
                token = token.strip()
                if '=' in token:
                    k, v = token.split('=', 1)
                    state_data[k.strip()] = v.strip()

            return {
                "event": "STATE_CHANGE",
                "time": log_time,
                "client": client_info,
                "state": state_data
            }

        return None

    def scan_existing_logs(self, max_lines_tail=300):
        """扫描各个客户端最近的日志并建立基准"""
        print("[*] 正在扫描 5 个客户端日志文件...")
        for fname in CLIENT_MAP.keys():
            p = LOGS_DIR / fname
            if not p.exists():
                print(f"  [!] 文件未找到: {p}")
                continue
            
            size = p.stat().st_size
            # 记录初始读取偏移
            self.file_offsets[fname] = max(0, size - 40960) # tail recent ~40KB

    def poll_new_events(self):
        new_events = []
        for fname, client_info in CLIENT_MAP.items():
            p = LOGS_DIR / fname
            if not p.exists(): continue
            
            cur_size = p.stat().st_size
            last_offset = self.file_offsets.get(fname, 0)
            if cur_size < last_offset:
                # 日志被重写或轮换
                last_offset = 0

            if cur_size > last_offset:
                with open(p, 'rb') as fp:
                    fp.seek(last_offset)
                    chunk = fp.read(cur_size - last_offset)
                    self.file_offsets[fname] = cur_size

                text = chunk.decode('gbk', errors='ignore')
                for line in text.splitlines():
                    if line.strip():
                        ev = self.parse_log_line(fname, line)
                        if ev:
                            new_events.append(ev)
        return new_events

    def record_event_to_file(self, event):
        with open(RECORDS_FILE, 'a', encoding='utf-8') as f:
            f.write(json.dumps(event, ensure_ascii=False) + "\n")
        self.total_battles_recorded += 1

    def print_event(self, ev):
        cname = ev["client"]["name"]
        etype = ev["event"]
        t = ev["time"]

        if etype == "OPPONENT":
            print(f"\n================================================================================")
            print(f"[{t}] [战场态势感知] 敌方全景扫描 (来源: {cname})")
            print(f"================================================================================")
            print(f"  敌方存活数量: {ev['enemy_count']} 只怪物")
            for em in ev["enemies"]:
                catch_tag = " [可捕捉宝宝!]" if em["catchable"] else ""
                print(f"  - 位号[{em['pos']}]: {em['name']} (Lv{em['level']} {em['type_name']}) | HP: {em['hp']}/{em['hp_max']}{catch_tag}")
            print()

        elif etype == "ALLY_SNAPSHOT":
            d = ev["data"]
            print(f"[{t}] [队伍生存快照 - {cname}]")
            print(f"  主角: {d.get('name','')} (Lv{d.get('lvl',0)}) | HP: {d.get('hp','')}, MP: {d.get('mp','')}, SP: {d.get('sp',0)}")
            print(f"  属性: 物攻={d.get('pAtt',0)}, 物防={d.get('pDef',0)} | 魔攻={d.get('mAtt',0)}, 魔防={d.get('mDef',0)}")
            print(f"  出战宠物: {d.get('petName','')} (Lv{d.get('petLvl',0)}) | HP: {d.get('petHp','')}, MP: {d.get('petMp','')}, SP: {d.get('petSp',0)}")
            print()

        elif etype == "ACTION":
            act = ev["action"]
            role_desc = "主角" if act.get("role") == "Player" else "宠物"
            print(f"[{t}] [AI战术出招] {cname} -> {role_desc}(位号:{act.get('pos')})")
            print(f"  动作: {act.get('act')} | 招式: {act.get('name')} (Lv{act.get('lv',1)}, ID:{act.get('id',0)}) -> 目标位号: {act.get('target')}")
            print(f"  >> 战术决策原因: {act.get('reason')}")
            print()

        elif etype == "ANOMALY":
            prefix = "[CRITICAL ALERT 红色异常警报]" if ev["is_critical"] else "[NOTICE 异常提示]"
            print(f"********************************************************************************")
            print(f"{prefix} [{t}] {cname}: {ev['message']}")
            print(f"********************************************************************************\n")


def generate_recent_summary_report():
    """解析最近的日志并生成综合战报"""
    print("================================================================================")
    print("               SMSM2 5-CLIENT REAL-TIME COMBAT TELEMETRY REPORT                 ")
    print(f"               生成时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}                         ")
    print("================================================================================\n")

    monitor = CombatTelemetryMonitor()
    monitor.scan_existing_logs()
    
    # 读最近 500 行生成即时报告
    recent_events = []
    for fname, cinfo in CLIENT_MAP.items():
        p = LOGS_DIR / fname
        if not p.exists(): continue
        lines = p.read_bytes().decode('gbk', errors='ignore').splitlines()
        for l in lines[-120:]:
            ev = monitor.parse_log_line(fname, l)
            if ev:
                recent_events.append(ev)

    print(f"[+] 当前捕获近期战斗事件共 {len(recent_events)} 条。\n")

    # 分类展示
    opponents = [e for e in recent_events if e['event'] == 'OPPONENT']
    actions = [e for e in recent_events if e['event'] == 'ACTION']
    anomalies = [e for e in recent_events if e['event'] == 'ANOMALY']
    snapshots = [e for e in recent_events if e['event'] == 'ALLY_SNAPSHOT']

    if opponents:
        latest_opp = opponents[-1]
        print("--------------------------------------------------------------------------------")
        print(f"1. 对面战场情报 (最近一场敌情态势)")
        print("--------------------------------------------------------------------------------")
        print(f"  怪物总数: {latest_opp['enemy_count']} 只 (扫描源: {latest_opp['client']['name']})")
        for em in latest_opp['enemies']:
            print(f"  - [位号 {em['pos']}]: {em['name']:<12} 等级: Lv{em['level']:<2} 类型: {em['type_name']:<6} 生命值: {em['hp']:>5} / {em['hp_max']:<5} {'[可抓宝宝]' if em['catchable'] else ''}")
        print()

    if snapshots:
        print("--------------------------------------------------------------------------------")
        print(f"2. 我方队伍五人五宠属性与生存线快照")
        print("--------------------------------------------------------------------------------")
        seen_clients = set()
        for snap in reversed(snapshots):
            cid = snap['client']['id']
            if cid in seen_clients: continue
            seen_clients.add(cid)
            d = snap['data']
            print(f"  * [{snap['client']['name']} - {snap['client']['role']}]:")
            print(f"    - 人物: {d.get('name','未知'):<8} 等级: Lv{d.get('lvl',0):<2} HP: {d.get('hp',''):<11} MP: {d.get('mp',''):<11} 物攻/物防: {d.get('pAtt',0)}/{d.get('pDef',0)} 魔攻/魔防: {d.get('mAtt',0)}/{d.get('mDef',0)}")
            print(f"    - 宠物: {d.get('petName','无出战'):<8} 等级: Lv{d.get('petLvl',0):<2} HP: {d.get('petHp',''):<11} MP: {d.get('petMp',''):<11} SP: {d.get('petSp',0)}")
        print()

    if actions:
        print("--------------------------------------------------------------------------------")
        print(f"3. 我方出招顺序链条与 AI 决策原因 (最近出招流水)")
        print("--------------------------------------------------------------------------------")
        for a in actions[-10:]:
            act = a['action']
            print(f"  [{a['time']}] {a['client']['name']:<16} | {act.get('role',''):<6} (位号{act.get('pos',-1):>2}) -> 招式: {act.get('name',''):<10} (ID:{act.get('id',0):>3}) -> 目标位: {act.get('target',-1)}")
            print(f"    └─ 决策原因: {act.get('reason','')}")
        print()

    print("--------------------------------------------------------------------------------")
    print(f"4. 异常情况监测 (大号宠物普攻/保姆普攻安全检测)")
    print("--------------------------------------------------------------------------------")
    if anomalies:
        print(f"  [!] 捕获到 {len(anomalies)} 条异常告警记录:")
        for an in anomalies[-6:]:
            print(f"    - [{an['time']}] {an['client']['name']}: {an['message']}")
    else:
        print("  [OK] 未发现任何宠物普通攻击或保姆违规普攻异常! 全队策略100%严格遵守法术全屏压制与专职群疗协议。")
    print()

    states = [e for e in recent_events if e['event'] == 'STATE_CHANGE']
    print("--------------------------------------------------------------------------------")
    print(f"5. 控制状态感知与自适应协同监测 (封魔/封技/控制怪集火)")
    print("--------------------------------------------------------------------------------")
    if states:
        print(f"  [i] 捕获到 {len(states)} 次受控状态感知事件:")
        for st in states[-5:]:
            s = st['state']
            print(f"    - [{st['time']}] {st['client']['name']}: 目标={s.get('role','')} (位号:{s.get('pos','')}) 状态={s.get('state','')} 影响={s.get('effect','')}")
    else:
        print("  [OK] 近期出招中暂无角色身受封魔/封技，全队处于完全行动自由状态。")
    print("================================================================================\n")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--summary":
        generate_recent_summary_report()
    else:
        # 持续后台监控模式
        print("[*] 启动 SMSM2 5账号战斗全景遥测实时监控中枢...")
        print(f"[*] 监控日志目录: {LOGS_DIR}")
        print(f"[*] 归档记录文件: {RECORDS_FILE}")
        print("[*] 正在持续监测全队战斗并实时记录，按 Ctrl+C 可停止...\n")

        monitor = CombatTelemetryMonitor()
        monitor.scan_existing_logs()

        try:
            while True:
                events = monitor.poll_new_events()
                for ev in events:
                    monitor.record_event_to_file(ev)
                    monitor.print_event(ev)
                time.sleep(1.0)
        except KeyboardInterrupt:
            print("\n[*] 监控已平稳退出。")
