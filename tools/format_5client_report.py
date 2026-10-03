import sys
from pathlib import Path

# Force stdout to UTF-8
sys.stdout.reconfigure(encoding='utf-8')

logs_dir = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
clients = [
    ("client.log", "客户端 0 (主角位:17)"),
    ("client1.log", "客户端 1 (主角位:19)"),
    ("client2.log", "客户端 2 (主角位:18)"),
    ("client3.log", "客户端 3 (主角位:15)"),
    ("client4.log", "客户端 4 (主角位:16)"),
]

print("==========================================================================================")
print("                       【5账号AI协同战斗实况监测诊断报告】                               ")
print("==========================================================================================\n")

for fname, title in clients:
    p = logs_dir / fname
    if not p.exists():
        continue
    content = p.read_bytes().decode('gbk', errors='ignore')
    lines = content.splitlines()

    print(f"【{title} - 日志文件: {fname}】")
    
    # 1. 技能自省日志
    intro_lines = [l for l in lines if '[AI自省' in l]
    print(f"  ★ [动态技能自省结果]:")
    if intro_lines:
        seen = set()
        for l in reversed(intro_lines):
            clean = l[l.find('[lua]'):]
            if clean not in seen:
                seen.add(clean)
                print(f"    • {clean}")
            if len(seen) >= 2:
                break
    else:
        print("    • (暂无)")

    # 2. 战术出招与协同记录
    decisions = [l for l in lines if '[AI协同]' in l or '[AI施法' in l]
    print(f"  ★ [近期实操技能释放与协同记录 (最近 6 条)]:")
    if decisions:
        for d in decisions[-6:]:
            time_str = d[:d.find('】') + 1] if '【' in d else ""
            msg = d[d.find('[lua]'):]
            print(f"    • {time_str} {msg}")
    else:
        print("    • (暂无)")
    print("-" * 90)

# 看板分析
bb_path = Path(r"D:\什么什么大冒险2.0\v2.1\team_blackboard.txt")
if bb_path.exists():
    bb_content = bb_path.read_text(encoding='gbk', errors='ignore')
    print("\n==========================================================================================")
    print("                    【团队战术黑板 (Distributed Blackboard IPC) 状态】                  ")
    print("==========================================================================================")
    lines = [l for l in bb_content.splitlines() if l.strip()]
    print(f"当前场上跨进程登记的预定伤害/治疗记录条数: {len(lines)}")
    for l in lines[-15:]:
        parts = l.split(',')
        if len(parts) >= 5:
            ts, rtype, target, val, src = parts[:5]
            print(f"  - [来源位号 {src}] 对 [目标位号 {target}] 预定 {rtype} 伤害量: {val} (防伤害溢出/过量击杀)")
        else:
            print(f"  - {l}")
