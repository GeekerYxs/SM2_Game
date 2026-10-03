import struct
import zlib
from pathlib import Path

DATA_FILE = Path(r"D:\什么什么大冒险2.0\Update.Data")

def inspect():
    with open(DATA_FILE, "rb") as f:
        hdr = f.read(40)
        hdr_size, magic, ver1, ver2, file_size, off_idx, idx_size, num_entries, num_entries2, zero = struct.unpack('<IIIIIIIIII', hdr)
        print(f"Header: size={hdr_size}, magic={hex(magic)}, ver1={ver1}, ver2={ver2}, file_size={file_size}")
        print(f"Indices: off_idx={off_idx}, idx_size={idx_size}, n1={num_entries}, n2={num_entries2}")

        f.seek(40)
        for i in range(5):
            entry = f.read(16)
            print(f"entry {i}: {struct.unpack('<4I', entry)}")

        f.seek(off_idx)
        raw_idx = f.read(min(idx_size, 256))
        print("idx raw head:", raw_idx[:128])

if __name__ == "__main__":
    inspect()
