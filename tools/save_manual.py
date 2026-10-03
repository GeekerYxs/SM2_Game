import sys
from pathlib import Path

EXTRACT_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\extracted_luas")
OUT_FILE = Path(r"d:\Codes\GG_Antigravity\smsm2-game\GameLuaRegister_API_Manual.md")

for f in EXTRACT_DIR.glob("rec_249*"):
    # It was saved as bytes, let's decode with utf-8
    raw = f.read_bytes()
    try:
        text = raw.decode('utf-8')
    except Exception:
        text = raw.decode('gbk', errors='replace')
    OUT_FILE.write_text(text, encoding='utf-8')
    print(f"Saved GameLuaRegister_API_Manual.md ({len(text)} chars)")
