# -*- coding: utf-8 -*-
import ctypes
import ctypes.wintypes as wt
from pathlib import Path

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
psapi = ctypes.WinDLL("psapi", use_last_error=True)

def get_process_base(pid):
    h = k32.OpenProcess(0x0400 | 0x0010, False, pid) # QUERY_INFORMATION | VM_READ
    if not h:
        return None
    
    hmods = (wt.HMODULE * 1024)()
    cb_needed = wt.DWORD()
    if psapi.EnumProcessModules(h, hmods, ctypes.sizeof(hmods), ctypes.byref(cb_needed)):
        main_mod = hmods[0]
        mod_name = ctypes.create_string_buffer(260)
        psapi.GetModuleBaseNameA(h, main_mod, mod_name, 260)
        k32.CloseHandle(h)
        return main_mod, mod_name.value.decode()
    k32.CloseHandle(h)
    return None

if __name__ == "__main__":
    # Let's find all WAATClient processes
    import subprocess
    out = subprocess.check_output(["powershell", "-Command", "Get-Process -Name '*WAAT*' | Select-Object -ExpandProperty Id"]).decode()
    for line in out.splitlines():
        line = line.strip()
        if line.isdigit():
            pid = int(line)
            res = get_process_base(pid)
            if res:
                base, name = res
                reload_va = base + (0x0069dc60 - 0x00400000)
                print(f"[PID {pid}] {name} Base: {hex(base)} -> Reload func VA: {hex(reload_va)}")
