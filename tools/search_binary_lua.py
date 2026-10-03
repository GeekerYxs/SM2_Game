import re
from pathlib import Path

EXE_PATH = Path(r"D:\什么什么大冒险2.0\v2.1\Win32\WAATClient.exe")

def search_strings():
    data = EXE_PATH.read_bytes()
    targets = [b"package.loaders", b"loadfile", b"GameStart", b"CGameLua", b"luaL_loadfile", b"plgGraphFile"]
    for t in targets:
        matches = [m.start() for m in re.finditer(re.escape(t), data)]
        print(f"Target '{t.decode()}': found {len(matches)} times at {[hex(m) for m in matches[:5]]}")

if __name__ == "__main__":
    search_strings()
