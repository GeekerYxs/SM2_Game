import sys
sys.stdout.reconfigure(encoding='utf-8')
from pathlib import Path
import re

logs_dir = Path(r"D:\什么什么大冒险2.0\v2.1\logs")

for i in range(5):
    suffix = str(i) if i > 0 else ""
    fname = f"client{suffix}.log"
    p = logs_dir / fname
    if not p.exists(): continue
    content = p.read_bytes().decode('gbk', errors='ignore')
    
    print(f"=== {fname} ===")
    # 1. search for ALLY_SNAPSHOT
    snapshots = [l for l in content.splitlines() if '[BATTLE_EVENT][ALLY_SNAPSHOT]' in l]
    print(f"  ALLY_SNAPSHOT count: {len(snapshots)}")
    if snapshots:
        print(f"  Latest: {snapshots[-1]}")
    
    # 2. search for any name pattern
    name_lines = [l for l in content.splitlines() if 'myPos=' in l or '伏地魔' in l or 'Pos=' in l]
    print(f"  Name lines count: {len(name_lines)}")
    if name_lines:
        for l in name_lines[-3:]:
            print(f"    {l}")
