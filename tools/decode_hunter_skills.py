import sys
sys.stdout.reconfigure(encoding='utf-8')

skill_names = {}
with open('extracted_luas/rec_7662.csv', 'rb') as f:
    for line in f:
        p = line.decode('gbk', errors='ignore').strip().split(',')
        if p and p[0].isdigit() and len(p) > 14:
            if p[1] == '1':
                skill_names[int(p[0])] = (p[14], p[2], p[7])

skill_ids = [101, 104, 307, 308, 309, 310, 803, 805, 806]
print("==================== CLIENT 0, 1, 2 (浪客/猎人) TRUE SKILLS ====================")
for sid in skill_ids:
    s_info = skill_names.get(sid)
    if s_info:
        print(f"ID {sid:<4} -> 【物理技能 Skill】名称: {s_info[0]:<10} Type:{s_info[1]} Range:{s_info[2]}")
