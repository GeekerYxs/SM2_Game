import sys
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')
EXTRACT_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\extracted_luas")

def dump_file(pattern):
    for f in EXTRACT_DIR.glob(pattern):
        print(f"\n==================== {f.name} ====================")
        content = f.read_text(encoding='gbk', errors='replace')
        print(content)

if __name__ == "__main__":
    if len(sys.argv) > 1:
        dump_file(sys.argv[1])
    else:
        for p in ["rec_110*", "rec_111*", "rec_112*", "rec_114*", "rec_115*"]:
            dump_file(p)
