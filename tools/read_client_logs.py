import glob
from pathlib import Path

logs_dir = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
for p in sorted(logs_dir.glob("client*.log")):
    try:
        content = p.read_bytes()
        lines = [line for line in content.decode('gbk', errors='ignore').splitlines() if line.strip()]
        print(f"\n==================== {p.name} (Lines: {len(lines)}) ====================")
        # Find AI log entries
        ai_lines = [l for l in lines if '[AI' in l or '[auto_fight' in l]
        print(f"Total AI lines: {len(ai_lines)}")
        if ai_lines:
            print("--- Last 10 AI lines ---")
            for l in ai_lines[-10:]:
                print(l)
    except Exception as e:
        print(f"Error reading {p.name}: {e}")
