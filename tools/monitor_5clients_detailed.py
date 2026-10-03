import glob, re
from pathlib import Path

logs_dir = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
clients = {
    "client.log": "Client 0 (Pos 17)",
    "client1.log": "Client 1 (Pos 19)",
    "client2.log": "Client 2 (Pos 18)",
    "client3.log": "Client 3 (Pos 15)",
    "client4.log": "Client 4 (Pos 16)",
}

print("================================================================================")
print("                   5-CLIENT REAL-TIME COMBAT MONITORING REPORT                  ")
print("================================================================================\n")

for fname, title in clients.items():
    p = logs_dir / fname
    if not p.exists():
        continue
    content = p.read_bytes().decode('gbk', errors='ignore')
    lines = content.splitlines()

    print(f"*** [{title} - {fname}] ***")
    
    # 1. Introspection of skills
    intro_lines = [l for l in lines if '[AI自省' in l or '可用技能' in l or '可用能力' in l]
    print(f"  > [技能自省发现]:")
    if intro_lines:
        # print last 3 unique
        seen = set()
        for l in reversed(intro_lines):
            clean = l[l.find('[lua]'):]
            if clean not in seen:
                seen.add(clean)
                print(f"    - {clean}")
            if len(seen) >= 3:
                break
    else:
        print("    - 暂未捕获自省日志")

    # 2. Combat Decisions / Actions
    decisions = [l for l in lines if '[AI协同]' in l or '[AI施法' in l]
    print(f"  > [近期AI战术决策] (最近 6 条):")
    if decisions:
        for d in decisions[-6:]:
            time_part = d[:d.find('Information')] if 'Information' in d else ""
            msg = d[d.find('[lua]'):]
            print(f"    - {time_part.strip()} | {msg}")
    else:
        print("    - 暂无协同出招记录")
    print()

# 3. Blackboard Analysis
bb_path = Path(r"D:\什么什么大冒险2.0\v2.1\team_blackboard.txt")
if bb_path.exists():
    bb_content = bb_path.read_text(encoding='gbk', errors='ignore')
    print("================================================================================")
    print("                    TEAM BLACKBOARD (IPC COORDINATION STATE)                    ")
    print("================================================================================")
    print(f"Total blackboard records currently active: {len(bb_content.splitlines())}")
    for l in bb_content.splitlines()[-15:]:
        print("  " + l)
