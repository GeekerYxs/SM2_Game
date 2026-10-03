# -*- coding: utf-8 -*-
from pathlib import Path

p = Path(r"D:\Codes\GG_Antigravity\smsm2-game\extracted_luas")
for f in p.glob("*.csv"):
    try:
        content = f.read_bytes()
        first_line = content.split(b"\n")[0].decode('gbk', errors='ignore')
        if any(keyword in first_line for keyword in ["Skill", "Magic", "技能", "法术"]):
            print(f"{f.name}: {first_line[:80]}")
    except Exception as e:
        pass
