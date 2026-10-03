import struct
import zlib
from pathlib import Path

DATA_FILE = Path(r"D:\什么什么大冒险2.0\Update.Data")
OUT_DIR = Path(r"d:\Codes\GG_Antigravity\smsm2-game\extracted_luas")

def extract_all():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with open(DATA_FILE, "rb") as f:
        hdr = f.read(40)
        hdr_size, magic, ver1, ver2, file_size, off_idx, idx_size, num_entries, num_entries2, zero = struct.unpack('<IIIIIIIIII', hdr)
        off_records = 40 + num_entries * 16
        
        extracted_count = 0
        for i in range(num_entries):
            f.seek(off_records + i * 48)
            rec = f.read(48)
            fields = struct.unpack('<12I', rec)
            # data_off is fields[3]
            data_off = fields[3]
            if data_off == 0 or data_off >= file_size:
                continue
            f.seek(data_off)
            bhdr = f.read(16)
            if len(bhdr) < 16:
                continue
            csize = struct.unpack('<I', bhdr[4:8])[0]
            if csize == 0 or csize > 10 * 1024 * 1024:
                continue
            try:
                raw = f.read(csize)
                decomp = zlib.decompress(raw)
            except Exception:
                continue
            
            # Check if this decompressed content looks like text/lua
            # Look for common lua patterns or text
            is_text = False
            try:
                text = decomp.decode('gbk')
                is_text = True
            except Exception:
                try:
                    text = decomp.decode('utf-8')
                    is_text = True
                except Exception:
                    pass
            
            if is_text:
                # Find if there is a filename or module name
                first_lines = text[:500]
                # save text files
                fname = f"rec_{i}.txt"
                if "function" in text or "require" in text or "local " in text:
                    fname = f"rec_{i}.lua"
                    # Try to detect real name from comments or require
                    # e.g. "fight_skill_list" or similar
                    for line in text.splitlines()[:10]:
                        if "module" in line or ".lua" in line or "--" in line:
                            clean = "".join(c for c in line if c.isalnum() or c in "._-")
                            if clean:
                                fname = f"rec_{i}_{clean[:30]}.lua"
                                break
                    (OUT_DIR / fname).write_bytes(decomp)
                    extracted_count += 1
                    print(f"Extracted #{i}: {fname} (size {len(decomp)})")
                elif "csv" in first_lines or "," in first_lines[:50]:
                    fname = f"rec_{i}.csv"
                    (OUT_DIR / fname).write_bytes(decomp)
                    extracted_count += 1
                    print(f"Extracted #{i}: {fname} (size {len(decomp)})")

    print(f"Total extracted: {extracted_count}")

if __name__ == "__main__":
    extract_all()
