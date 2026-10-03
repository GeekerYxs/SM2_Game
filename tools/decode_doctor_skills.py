import sys

sys.stdout.reconfigure(encoding='utf-8')

# Build comprehensive dictionaries from CSV
skill_names = {}
with open('extracted_luas/rec_7662.csv', 'rb') as f:
    for line in f:
        p = line.decode('gbk', errors='ignore').strip().split(',')
        if p and p[0].isdigit() and len(p) > 14:
            if p[1] == '1':
                skill_names[int(p[0])] = (p[14], p[2], p[7]) # name, type, range

magic_names = {}
with open('extracted_luas/rec_3531.csv', 'rb') as f:
    for line in f:
        p = line.decode('gbk', errors='ignore').strip().split(',')
        if p and p[0].isdigit() and len(p) > 13:
            if p[1] == '1':
                magic_names[int(p[0])] = (p[13], p[2], p[6]) # name, type, range

# Add pet magics
for mid, mname in [(1501, "火球术"), (1502, "烈火"), (1503, "烈焰"), (1504, "烈焰爆发"), (1506, "狂暴")]:
    magic_names[mid] = (mname, '1', '0')

# Client 3 & 4 skill list from log:
# 强力攻击[Lv7], Skill_101[Lv1], 隐匿[Lv7], 治疗术[Lv7], Skill_304[Lv6], 群体治疗术[Lv3], Skill_306[Lv1], Skill_307[Lv1], 能量射击/神佑[Lv7], Skill_309[Lv3], 连珠箭/心灵震撼[Lv7], Skill_311..319, Skill_330, Skill_350, Skill_354, Skill_355

client3_ids = [101, 104, 212, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 318, 319, 330, 350, 354, 355]

print("==================== CLIENT 3 & 4 (学者/医仙) TRUE SKILLS ====================")
for cid in client3_ids:
    m_info = magic_names.get(cid)
    s_info = skill_names.get(cid)
    if m_info and cid >= 300: # Clearly magic
        print(f"ID {cid:<4} -> 【法术 Magic】名称: {m_info[0]:<10} Type:{m_info[1]} Range:{m_info[2]}")
    elif s_info:
        print(f"ID {cid:<4} -> 【技能 Skill】名称: {s_info[0]:<10} Type:{s_info[1]} Range:{s_info[2]}")
    elif m_info:
        print(f"ID {cid:<4} -> 【法术 Magic】名称: {m_info[0]:<10} Type:{m_info[1]} Range:{m_info[2]}")
