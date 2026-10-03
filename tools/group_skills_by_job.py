import sys
from collections import defaultdict

sys.stdout.reconfigure(encoding='utf-8')

# 1. SkillLib grouping
skill_by_job = defaultdict(list)
with open('extracted_luas/rec_7662.csv', 'rb') as f:
    hdr = f.readline()
    for line in f:
        line_str = line.decode('gbk', errors='ignore').strip()
        parts = line_str.split(',')
        if parts and parts[0].isdigit() and len(parts) > 22:
            sid = int(parts[0])
            slv = int(parts[1]) if parts[1].isdigit() else 1
            if slv == 1:
                name = parts[14]
                stype = parts[2]
                srange = parts[7]
                job = parts[22]
                desc = parts[16] if len(parts) > 16 else ""
                skill_by_job[job].append((sid, name, stype, srange, desc))

print("======================= SKILLS GROUPED BY 职业需求 =======================")
for job, skills in sorted(skill_by_job.items()):
    print(f"\n【职业代码: {job}】(共 {len(skills)} 个技能):")
    for sid, name, stype, srange, desc in skills:
        print(f"   ID:{sid:<4} 名称:{name:<10} Type:{stype} Range:{srange} | 描述: {desc}")

# 2. MagicLib grouping
magic_by_job = defaultdict(list)
with open('extracted_luas/rec_3531.csv', 'rb') as f:
    hdr = f.readline()
    for line in f:
        line_str = line.decode('gbk', errors='ignore').strip()
        parts = line_str.split(',')
        if parts and parts[0].isdigit() and len(parts) > 19:
            mid = int(parts[0])
            mlv = int(parts[1]) if parts[1].isdigit() else 1
            if mlv == 1:
                name = parts[13]
                mtype = parts[2]
                mrange = parts[6]
                job = parts[19] # 职业要求值
                job_req = parts[18] # 职业要求
                desc = parts[15] if len(parts) > 15 else ""
                magic_by_job[(job_req, job)].append((mid, name, mtype, mrange, desc))

print("\n======================= MAGICS GROUPED BY 职业要求 =======================")
for (jreq, jval), magics in sorted(magic_by_job.items()):
    print(f"\n【法术职业要求: {jreq}, 值: {jval}】(共 {len(magics)} 个法术):")
    for mid, name, mtype, mrange, desc in magics:
        print(f"   ID:{mid:<4} 名称:{name:<10} Type:{mtype} Range:{mrange} | 描述: {desc}")
