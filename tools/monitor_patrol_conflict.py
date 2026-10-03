import time, sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

logs_dir = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
leader_log = logs_dir / "client.log"

print("================================================================================")
print("             STARTING 3-MINUTE DEEP COMBAT MONITOR (LEADER & TEAM)              ")
print(f"Start Time: {time.strftime('%Y-%m-%d %H:%M:%S')}")
print("================================================================================\n")

# Open files at current end
files = {}
for p in logs_dir.glob("client*.log"):
    f = open(p, 'rb')
    f.seek(0, 2) # seek to end
    files[p.name] = f

start_time = time.time()
duration = 180 # 3 minutes

event_stats = {
    "battles_entered": 0,
    "ai_skill_casts": 0,
    "ai_magic_casts": 0,
    "normal_attacks": 0,
    "auto_fight_diagnostics": 0,
    "unknown_packets": 0,
}

last_report = time.time()

while time.time() - start_time < duration:
    time.sleep(0.5)
    for fname, f in files.items():
        while True:
            line_bytes = f.readline()
            if not line_bytes:
                break
            line = line_bytes.decode('gbk', errors='ignore').strip()
            if not line:
                continue

            # Check relevant events
            if "OnEnterFight" in line or "OnBeginFight" in line:
                event_stats["battles_entered"] += 1
                print(f"[{time.strftime('%H:%M:%S')}] [{fname}] >>> BATTLE START: {line}")
            elif "NormalAttack" in line or "普通攻击" in line or "普攻" in line:
                event_stats["normal_attacks"] += 1
                print(f"[{time.strftime('%H:%M:%S')}] [{fname}] [!] NORMAL ATTACK: {line}")
            elif "[AI施法" in line or "[AI协同]" in line:
                if "释放技能" in line:
                    event_stats["ai_skill_casts"] += 1
                elif "释放法术" in line:
                    event_stats["ai_magic_casts"] += 1
                # Print leader action and sampled team actions
                if fname == "client.log" or "普攻" in line:
                    print(f"[{time.strftime('%H:%M:%S')}] [{fname}] AI-ACTION: {line}")
            elif "FightConfig" in line or "AutoFight" in line:
                print(f"[{time.strftime('%H:%M:%S')}] [{fname}] CONFIG-UPDATE: {line[:120]}...")
            elif "0x47c0" in line:
                event_stats["unknown_packets"] += 1

    if time.time() - last_report >= 30:
        elapsed = int(time.time() - start_time)
        print(f"\n--- Progress: {elapsed}/180s | Battles: {event_stats['battles_entered']}, AI Casts: {event_stats['ai_skill_casts']+event_stats['ai_magic_casts']}, Normal Attacks: {event_stats['normal_attacks']} ---")
        last_report = time.time()

print("\n================================================================================")
print("                        3-MINUTE MONITORING COMPLETED                           ")
print("================================================================================")
print(f"Final Stats: {event_stats}")

# Close files
for f in files.values():
    f.close()
