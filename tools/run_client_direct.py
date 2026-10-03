# -*- coding: utf-8 -*-
import ctypes
import subprocess
import time
from pathlib import Path

k32 = ctypes.WinDLL("kernel32", use_last_error=True)

def run_test():
    print("[*] Creating mutex 'iuiuu_run_update'...")
    hMutex = k32.CreateMutexA(None, False, b"iuiuu_run_update")
    if not hMutex:
        print(f"[!] CreateMutex failed: {ctypes.get_last_error()}")
        return

    print("[*] Launching WAATClient.exe directly...")
    exe_path = r"D:\什么什么大冒险2.0\v2.1\win32\WaatClient.exe"
    cwd = r"D:\什么什么大冒险2.0\v2.1\win32"
    
    proc = subprocess.Popen([exe_path], cwd=cwd)
    print(f"[+] Launched WAATClient PID: {proc.pid}")
    
    # Wait 6 seconds to observe log
    time.sleep(6)
    
    log_file = Path(r"D:\什么什么大冒险2.0\v2.1\logs\client.log")
    if log_file.exists():
        lines = log_file.read_text(encoding='gbk', errors='replace').splitlines()
        print("\n--- client.log Tail ---")
        for line in lines[-35:]:
            print(line)
        print("-----------------------\n")
        
    print("[*] Terminating test client...")
    proc.terminate()
    try:
        proc.wait(timeout=3)
    except Exception:
        proc.kill()
    k32.CloseHandle(hMutex)
    print("[+] Test completed.")

if __name__ == "__main__":
    run_test()
