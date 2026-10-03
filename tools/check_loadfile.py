import struct
from pathlib import Path

EXE_PATH = Path(r"D:\什么什么大冒险2.0\v2.1\Win32\WAATClient.exe")

def check_loadfile():
    data = EXE_PATH.read_bytes()
    # Let's search for "cannot open " or "open file failed" or "loadfile"
    for s in [b"cannot open %s", b"cannot open", b"fread", b"fopen"]:
        idx = 0
        while True:
            idx = data.find(s, idx)
            if idx == -1:
                break
            print(f"Found '{s.decode()}' at file offset {hex(idx)}")
            idx += len(s)

if __name__ == "__main__":
    check_loadfile()
