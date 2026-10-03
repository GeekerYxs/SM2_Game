import re
from pathlib import Path

EXTRACT_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\extracted_luas")

def analyze():
    files = list(EXTRACT_DIR.glob("*.lua"))
    print(f"Total Lua files: {len(files)}")
    
    # We want to identify the key files:
    # auto_fight, fight_skill_list, auto_drop, game_define, TriggerItem, etc.
    keywords = ["fight", "auto_fight", "skill", "Skill", "CastSkill", "GetFighter", "myAction", "Round", "Drop"]
    
    for f in sorted(files, key=lambda x: int(re.search(r'rec_(\d+)', x.name).group(1))):
        try:
            content = f.read_text(encoding='gbk', errors='replace')
        except Exception:
            continue
        
        matches = []
        for kw in keywords:
            if kw in content:
                matches.append(kw)
        
        # print summary
        first_few = [line.strip() for line in content.splitlines() if line.strip() and not line.strip().startswith("--")][:3]
        rec_id = re.search(r'rec_(\d+)', f.name).group(1)
        if matches:
            print(f"[{f.name}] (Rec #{rec_id}, matches: {matches}) -> Head: {first_few[:2]}")

if __name__ == "__main__":
    analyze()
