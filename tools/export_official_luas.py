from pathlib import Path

EXTRACT_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\extracted_luas")
OUT_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\official_luas")
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Map known recs
mapping = {
    108: "dmx.lua",
    110: "auto_fight.lua",
    111: "auto_recover.lua",
    112: "auto_relive.lua",
    113: "catch_pet.lua",
    114: "fight_prepare.lua",
    115: "fight_skill_list.lua",
    101: "auto_drop.lua",
    121: "log.lua",
}

for rec_id, name in mapping.items():
    matched = list(EXTRACT_DIR.glob(f"rec_{rec_id}*"))
    if matched:
        content = matched[0].read_bytes()
        try:
            text = content.decode('gbk')
        except Exception:
            text = content.decode('utf-8', errors='replace')
        (OUT_DIR / name).write_text(text, encoding='utf-8')
        print(f"Exported {name} from {matched[0].name}")
