# -*- coding: utf-8 -*-
import time
import sys
from pathlib import Path
from datetime import datetime

LOGS_DIR = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
DURATION = 180 # 3 minutes

def monitor():
    print(f"[{datetime.now():%H:%M:%S}] Starting 3-minute combat monitoring across all active game clients...", flush=True)
    
    log_files = sorted(LOGS_DIR.glob("client*.log"))
    file_offsets = {p: p.stat().st_size for p in log_files}
    
    start_time = time.time()
    end_time = start_time + DURATION
    
    battle_count = 0
    ai_logs = []
    official_actions = []
    log_samples = []
    
    last_report = start_time

    while time.time() < end_time:
        time.sleep(2)
        now = time.time()
        
        for p in log_files:
            if not p.exists(): continue
            curr_size = p.stat().st_size
            if curr_size > file_offsets[p]:
                with open(p, "rb") as f:
                    f.seek(file_offsets[p])
                    new_bytes = f.read()
                    file_offsets[p] = curr_size
                    
                text = new_bytes.decode('gbk', errors='replace')
                for line in text.splitlines():
                    line = line.strip()
                    if not line: continue
                    
                    if "OnBeginFight" in line or "fight ai start" in line:
                        battle_count += 1
                        ts = f"[{p.name}] {line}"
                        print(f"[{datetime.now():%H:%M:%S}] {ts}", flush=True)
                        log_samples.append(ts)
                    elif "AI战斗" in line or "ai_fight_strategy" in line:
                        ai_logs.append(f"[{p.name}] {line}")
                        print(f"[{datetime.now():%H:%M:%S}] *** AI SCRIPT ACTION: [{p.name}] {line} ***", flush=True)
                    elif "fighter castskill" in line or "fighter use" in line or "normalattack" in line:
                        official_actions.append(f"[{p.name}] {line}")
                        print(f"[{datetime.now():%H:%M:%S}] OFFICIAL SCRIPT ACTION: [{p.name}] {line}", flush=True)
                    elif "drop slot" in line:
                        print(f"[{datetime.now():%H:%M:%S}] BATTLE END / DROP: [{p.name}] {line}", flush=True)
                    elif "AutoFight" in line and "FightConfigs" in line:
                        # Log config update
                        if "AutoFight=1" in line:
                            print(f"[{datetime.now():%H:%M:%S}] AutoFight enabled in [{p.name}]", flush=True)
                        elif "AutoFight=0" in line:
                            # keep track
                            pass

        if now - last_report >= 30:
            elapsed = int(now - start_time)
            remaining = int(end_time - now)
            print(f"[{datetime.now():%H:%M:%S}] Progress: {elapsed}s elapsed, {remaining}s remaining. Battles observed: {battle_count}, AI logs: {len(ai_logs)}, Official action logs: {len(official_actions)}", flush=True)
            last_report = now

    print(f"\n==================== 3-MINUTE MONITORING SUMMARY ====================")
    print(f"Total Battles Detected: {battle_count}")
    print(f"Custom AI Engine Actions: {len(ai_logs)}")
    print(f"Official Lua Script Actions: {len(official_actions)}")
    if ai_logs:
        print("\n--- AI Script Logs Captured ---")
        for l in ai_logs[:10]:
            print(l)
    if official_actions:
        print("\n--- Official Actions Captured ---")
        for l in official_actions[:10]:
            print(l)
    print("=====================================================================")

if __name__ == "__main__":
    monitor()
