import time, os

log_dir = r"D:\什么什么大冒险2.0\v2.1\logs"
clients = ['client.log', 'client1.log', 'client2.log', 'client3.log', 'client4.log']
files = {c: os.path.join(log_dir, c) for c in clients}
handles = {c: open(p, 'rb') for c, p in files.items()}

# Seek to end
for c, h in handles.items():
    h.seek(0, os.SEEK_END)

print("=== STARTING 60-SECOND POST-FIX VERIFICATION MONITOR ===")
start_time = time.time()
while time.time() - start_time < 60:
    time.sleep(0.5)
    for c, h in handles.items():
        while True:
            line_bytes = h.readline()
            if not line_bytes:
                break
            line = line_bytes.decode('gbk', errors='ignore').strip()
            if not line:
                continue
            
            t = time.strftime("%H:%M:%S")
            if "OnBeginFight" in line:
                print(f"[{t}] [{c}] >>> BATTLE START")
            elif "[AI群疗护航]" in line:
                print(f"[{t}] [{c}] [HEAL OK] {line}")
            elif "[AI施法" in line:
                print(f"[{t}] [{c}] [CAST OK] {line}")
            elif "普通攻击" in line and "FightConfig" not in line:
                print(f"[{t}] [{c}] [!] NORMAL ATTACK: {line}")

print("=== MONITOR FINISHED ===")
