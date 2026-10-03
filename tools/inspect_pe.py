from pathlib import Path

EXE_PATH = Path(r"D:\什么什么大冒险2.0\v2.1\Win32\WAATClient.exe")

def inspect_around():
    data = EXE_PATH.read_bytes()
    # ImageBase is 0x400000 in 32-bit PE typically
    # Let's check PE header
    import struct
    pe_off = struct.unpack('<I', data[0x3C:0x40])[0]
    magic = struct.unpack('<H', data[pe_off+24:pe_off+26])[0]
    image_base = struct.unpack('<I', data[pe_off+52:pe_off+56])[0]
    print(f"PE ImageBase: {hex(image_base)}")
    
    # Check section headers
    num_sections = struct.unpack('<H', data[pe_off+6:pe_off+8])[0]
    opt_hdr_size = struct.unpack('<H', data[pe_off+20:pe_off+22])[0]
    sec_hdr_start = pe_off + 24 + opt_hdr_size
    
    sections = []
    for i in range(num_sections):
        sec = data[sec_hdr_start + i*40 : sec_hdr_start + (i+1)*40]
        sname = sec[:8].decode('ascii', errors='ignore').strip('\x00')
        vsize, va, rsize, roff = struct.unpack('<IIII', sec[8:24])
        sections.append((sname, va, vsize, roff, rsize))
        print(f"Sec {sname}: VA={hex(va)}, VSZ={hex(vsize)}, ROFF={hex(roff)}, RSZ={hex(rsize)}")
        
    def file_to_va(foff):
        for sname, va, vsize, roff, rsize in sections:
            if roff <= foff < roff + rsize:
                return image_base + va + (foff - roff)
        return image_base + foff

    print(f"File off 0x4ca775 -> VA: {hex(file_to_va(0x4ca775))}")
    print(f"File off 0x4ca034 -> VA: {hex(file_to_va(0x4ca034))}")

if __name__ == "__main__":
    inspect_around()
