import re
from pathlib import Path
import sys

sys.stdout.reconfigure(encoding='utf-8')

logs_dir = Path(r"D:\什么什么大冒险2.0\v2.1\logs")
for i in range(5):
    suffix = str(i) if i > 0 else ""
    fname = f"client{suffix}.log"
    p = logs_dir / fname
    if not p.exists():
        continue
    content = p.read_bytes().decode('gbk', errors='ignore')
    
    vold = set(re.findall(r'伏地魔\d*', content))
    print(f"=== {fname} ===")
    print(f"  伏地魔 matches: {vold}")
    
    # Check for login or enter game lines
    login_lines = [l for l in content.splitlines() if any(k in l for k in ['角色', '登入', '进入游戏', 'Login', 'player', 'Player'])]
    print(f"  Login/Player lines count: {len(login_lines)}")
    for l in login_lines[:5]:
        print(f"    (head) {l}")
    for l in login_lines[-5:]:
        print(f"    (tail) {l}")
