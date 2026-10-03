# -*- coding: utf-8 -*-
import sys
import shutil
from pathlib import Path

SRC_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\src")

TARGET_DIRS = [
    Path(r"D:\什么什么大冒险2.0\v2.1\luas\fight"),
    Path(r"D:\什么什么大冒险2.0\v2.1\luas"),
    Path(r"D:\什么什么大冒险2.0\v2.1\Win32\luas\fight"),
    Path(r"D:\什么什么大冒险2.0\v2.1\Win32\luas"),
    Path(r"D:\什么什么大冒险2.0\luas\fight"),
    Path(r"D:\什么什么大冒险2.0\luas"),
]

def deploy():
    files_to_deploy = ["auto_fight.lua", "ai_fight_strategy.lua", "fight_skill_list.lua", "map_patrol.lua"]
    
    for target_dir in TARGET_DIRS:
        target_dir.mkdir(parents=True, exist_ok=True)
        print(f"[*] Deploying to target directory: {target_dir}")
        for fname in files_to_deploy:
            src_file = SRC_DIR / fname
            if not src_file.exists():
                print(f"[!] Error: Source file {src_file} does not exist!")
                return False

            content = src_file.read_text(encoding='utf-8')
            dest_file = target_dir / fname
            try:
                gbk_bytes = content.encode('gbk')
                dest_file.write_bytes(gbk_bytes)
                print(f"  [+] {fname} -> {dest_file} (GBK, {len(gbk_bytes)} bytes)")
            except UnicodeEncodeError as e:
                print(f"  [!] Warning: GBK encoding failed ({e}), writing as UTF-8 fallback")
                dest_file.write_text(content, encoding='utf-8')

    print("[+] All combat AI scripts deployed successfully across all potential VFS search paths!")
    return True

if __name__ == "__main__":
    deploy()
