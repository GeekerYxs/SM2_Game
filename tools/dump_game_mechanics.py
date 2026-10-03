# -*- coding: utf-8 -*-
import sys
from collections import defaultdict
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

def parse_skills():
    skills = {}
    with open('extracted_luas/rec_7662.csv', 'rb') as f:
        hdr = f.readline().decode('gbk', errors='ignore').strip().split(',')
        for line in f:
            p = line.decode('gbk', errors='ignore').strip().split(',')
            if p and p[0].isdigit():
                sid = int(p[0])
                slv = int(p[1]) if p[1].isdigit() else 1
                if sid not in skills or slv > skills[sid]['lv']:
                    skills[sid] = {
                        'id': sid, 'lv': slv,
                        'type': p[2] if len(p) > 2 else '',
                        'target': p[5] if len(p) > 5 else '',
                        'dmg': p[6] if len(p) > 6 else '',
                        'range': p[7] if len(p) > 7 else '',
                        'combo': p[8] if len(p) > 8 else '',
                        'sp': p[9] if len(p) > 9 else '',
                        'weapon': p[13] if len(p) > 13 else '',
                        'name': p[14] if len(p) > 14 else '',
                        'desc': p[16] if len(p) > 16 else '',
                        'jobreq': p[22] if len(p) > 22 else '',
                    }
    return skills

def parse_magics():
    magics = {}
    with open('extracted_luas/rec_3531.csv', 'rb') as f:
        hdr = f.readline().decode('gbk', errors='ignore').strip().split(',')
        for line in f:
            p = line.decode('gbk', errors='ignore').strip().split(',')
            if p and p[0].isdigit():
                mid = int(p[0])
                mlv = int(p[1]) if p[1].isdigit() else 1
                if mid not in magics or mlv > magics[mid]['lv']:
                    magics[mid] = {
                        'id': mid, 'lv': mlv,
                        'type': p[2] if len(p) > 2 else '',
                        'target': p[4] if len(p) > 4 else '',
                        'range': p[6] if len(p) > 6 else '',
                        'sp': p[8] if len(p) > 8 else '',
                        'mp': p[7] if len(p) > 7 else '',
                        'name': p[13] if len(p) > 13 else '',
                        'desc': p[15] if len(p) > 15 else '',
                        'jobreq': p[19] if len(p) > 19 else '',
                    }
    return magics

def parse_buffs():
    buffs = {}
    with open('extracted_luas/rec_7657.csv', 'rb') as f:
        hdr = f.readline().decode('gbk', errors='ignore').strip().split(',')
        for line in f:
            p = line.decode('gbk', errors='ignore').strip().split(',')
            if p and p[0].isdigit():
                bid = int(p[0])
                blv = int(p[1]) if p[1].isdigit() else 1
                if bid not in buffs or blv > buffs[bid]['lv']:
                    buffs[bid] = {
                        'id': bid, 'lv': blv,
                        'is_pos': p[3] if len(p) > 3 else '',
                        'name': p[5] if len(p) > 5 else '',
                        'desc': p[6] if len(p) > 6 else '',
                    }
    return buffs

def main():
    print("=================== 1. SKILLS (rec_7662.csv) ===================")
    skills = parse_skills()
    print(f"Total unique skills: {len(skills)}")
    job_skills = defaultdict(list)
    for sid, s in skills.items():
        job_skills[s['jobreq']].append(s)

    for j, sk_list in sorted(job_skills.items(), key=lambda x: str(x[0])):
        print(f"\n--- JobReq: {j} ({len(sk_list)} skills) ---")
        for s in sorted(sk_list, key=lambda x: x['id']):
            print(f"  ID:{s['id']:<5} MaxLv:{s['lv']:<2} Type:{s['type']:<2} SP:{s['sp']:<2} Range:{s['range']:<2} Name:{s['name']:<12} Weapon:{s['weapon']:<10} Desc:{s['desc']}")

    print("\n=================== 2. MAGICS (rec_3531.csv) ===================")
    magics = parse_magics()
    print(f"Total unique magics: {len(magics)}")
    job_magics = defaultdict(list)
    for mid, m in magics.items():
        job_magics[m['jobreq']].append(m)

    for j, mg_list in sorted(job_magics.items(), key=lambda x: str(x[0])):
        print(f"\n--- Magic JobReq: {j} ({len(mg_list)} magics) ---")
        for m in sorted(mg_list, key=lambda x: x['id']):
            print(f"  ID:{m['id']:<5} MaxLv:{m['lv']:<2} Type:{m['type']:<2} SP:{m['sp']:<2} MP:{m['mp']:<4} Range:{m['range']:<2} Name:{m['name']:<12} Desc:{m['desc']}")

    print("\n=================== 3. BUFFS (rec_7657.csv) ===================")
    buffs = parse_buffs()
    print(f"Total unique buffs: {len(buffs)}")
    for bid in [212, 1, 2, 3, 4, 5, 10, 11, 12, 20, 30, 40, 50, 100, 101, 102, 103, 104, 105, 306, 307, 308]:
        if bid in buffs:
            b = buffs[bid]
            print(f"  Buff ID:{b['id']} Name:{b['name']} Type:{b['is_pos']} Desc:{b['desc']}")
    # Also find any buff with '隐' or '隐匿'
    print("\n--- Buffs related to Invisibility / Stealth / Healing ---")
    for bid, b in buffs.items():
        if any(w in b['name'] or w in b['desc'] for w in ['隐', '复活', '封魔', '定身', '眩晕', '昏睡', '催眠', '中毒', '冰冻', '麻痹']):
            print(f"  Buff ID:{b['id']:<5} Name:{b['name']:<12} Type:{b['is_pos']} Desc:{b['desc']}")

if __name__ == '__main__':
    main()
