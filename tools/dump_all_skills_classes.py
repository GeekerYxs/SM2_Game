import csv, sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

# SkillLib
print("=================== SKILL LIB (rec_7662.csv) ===================")
with open('extracted_luas/rec_7662.csv', 'rb') as f:
    for line in f:
        line_str = line.decode('gbk', errors='ignore').strip()
        parts = line_str.split(',')
        if parts and parts[0].isdigit() and len(parts) > 14:
            sid = int(parts[0])
            slv = int(parts[1]) if parts[1].isdigit() else 1
            if slv == 1:
                stype = parts[2]
                sname = parts[14]
                srange = parts[7]
                print(f"Skill {sid}: {sname} (Type={stype}, Range={srange})")

# Let's inspect profession / class mapping table
print("\n=================== SEARCHING PROFESSION/CLASS TABLES ===================")
for p in Path('extracted_luas').glob('*.csv'):
    with open(p, 'rb') as f:
        first = f.readline().decode('gbk', errors='ignore')
        if '职业' in first or 'Class' in first or 'Job' in first or 'ְҵ' in first:
            print(f"Found table: {p.name} -> {first.strip()[:80]}")
