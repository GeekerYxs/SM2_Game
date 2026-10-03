import csv, sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

# 1. Read MagicLib (rec_3531.csv)
magic_lib = {}
with open('extracted_luas/rec_3531.csv', 'rb') as f:
    for line in f:
        line_str = line.decode('gbk', errors='ignore').strip()
        if not line_str or line_str.startswith('//'):
            continue
        parts = line_str.split(',')
        if parts and parts[0].isdigit():
            mid = int(parts[0])
            mlv = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 1
            mname = parts[13] if len(parts) > 13 else ""
            mdesc = parts[15] if len(parts) > 15 else ""
            if mid not in magic_lib:
                magic_lib[mid] = {}
            magic_lib[mid][mlv] = (mname, mdesc)

# 2. Read SkillLib (rec_7662.csv)
skill_lib = {}
with open('extracted_luas/rec_7662.csv', 'rb') as f:
    for line in f:
        line_str = line.decode('gbk', errors='ignore').strip()
        if not line_str or line_str.startswith('//'):
            continue
        parts = line_str.split(',')
        if parts and parts[0].isdigit():
            sid = int(parts[0])
            slv = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else 1
            stype = int(parts[2]) if len(parts) > 2 and parts[2].isdigit() else 0
            # Let's inspect where the skill name is in SkillLib
            # Let's print first row of skill_lib
            skill_lib[(sid, slv)] = parts

print(f"Total Magic entries: {len(magic_lib)} unique IDs")
print("Sample MagicLib IDs and Names:")
for mid in sorted(magic_lib.keys())[:30]:
    name = magic_lib[mid].get(1, ("", ""))[0]
    print(f"  Magic {mid}: {name}")
