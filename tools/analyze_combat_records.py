# -*- coding: utf-8 -*-
import sys
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path
import re
from collections import Counter

logs_dir = Path(r"D:\什么什么大冒险2.0\v2.1\logs")

stats = {
    'total_fights': 0,
    'hunter_skills': Counter(),
    'pet_actions': Counter(),
    'doctor_actions': Counter(),
    'anomalies': [],
    'low_mp_warnings': [],
}

for i in range(5):
    suffix = str(i) if i > 0 else ""
    fname = f"client{suffix}.log"
    p = logs_dir / fname
    if not p.exists(): continue
    content = p.read_bytes().decode('gbk', errors='ignore')
    lines = content.splitlines()
    
    # filter lines since 15:00
    recent = [l for l in lines if ('【2026-10-03 15:' in l or '【2026-10-03 16:' in l)]
    
    for l in recent:
        if '[BATTLE_EVENT][ACTION]' in l:
            m = re.search(r'role=(\w+).*?name=([^,]+).*?reason=(.*)', l)
            if m:
                role, name, reason = m.group(1), m.group(2).strip(), m.group(3).strip()
                if i in [0, 1, 2]: # Hunters
                    if role == 'Player':
                        stats['hunter_skills'][f"{fname}:{name}"] += 1
                        if name == '法术飞弹':
                            stats['anomalies'].append(f"猎人释放法术飞弹: {l}")
                    elif role == 'Pet':
                        stats['pet_actions'][f"{fname}:{name}"] += 1
                        if name == '普通攻击':
                            stats['anomalies'].append(f"大号宠物普攻: {l}")
                else: # Doctors
                    if role == 'Player':
                        stats['doctor_actions'][f"{fname}:{name}"] += 1
                        if name == '普通攻击':
                            stats['anomalies'].append(f"医仙小号普攻: {l}")
                    elif role == 'Pet':
                        stats['pet_actions'][f"{fname}:{name}"] += 1
                        if name == '普通攻击':
                            stats['anomalies'].append(f"小号宠物普攻: {l}")
        
        if '[BATTLE_EVENT][ALLY_SNAPSHOT]' in l:
            m_mp = re.search(r'name=([^,]+).*?mp=(\d+)/(\d+)', l)
            if m_mp:
                cname, cur_mp, max_mp = m_mp.group(1), int(m_mp.group(2)), int(m_mp.group(3))
                if cur_mp < 120 and cur_mp < max_mp * 0.4:
                    stats['low_mp_warnings'].append(f"{cname} 蓝量偏低: {cur_mp}/{max_mp}")

print("=== 猎人技能统计 (15:00 ~ 16:08) ===")
for k, v in stats['hunter_skills'].most_common():
    print(f"  {k}: {v} 次")

print("\n=== 宠物动作统计 (15:00 ~ 16:08) ===")
for k, v in stats['pet_actions'].most_common():
    print(f"  {k}: {v} 次")

print("\n=== 医仙动作统计 (15:00 ~ 16:08) ===")
for k, v in stats['doctor_actions'].most_common():
    print(f"  {k}: {v} 次")

print(f"\n=== 异常告警总数: {len(stats['anomalies'])} 条 ===")
for a in stats['anomalies'][:10]:
    print(f"  [!] {a}")

print(f"\n=== 蓝量预警统计 ===")
unique_low = Counter(stats['low_mp_warnings'])
for k, v in unique_low.most_common(10):
    print(f"  [?] {k} (出现 {v} 次)")
