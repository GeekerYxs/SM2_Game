# -*- coding: utf-8 -*-
import ctypes
import ctypes.wintypes as wt

u32 = ctypes.WinDLL('user32')

hwnds = []
def enum_cb(hwnd, lparam):
    lp_pid = wt.DWORD()
    u32.GetWindowThreadProcessId(hwnd, ctypes.byref(lp_pid))
    length = u32.GetWindowTextLengthW(hwnd)
    buf = ctypes.create_unicode_buffer(length + 1)
    u32.GetWindowTextW(hwnd, buf, length + 1)
    class_buf = ctypes.create_unicode_buffer(256)
    u32.GetClassNameW(hwnd, class_buf, 256)
    hwnds.append((hwnd, lp_pid.value, buf.value, class_buf.value, bool(u32.IsWindowVisible(hwnd))))
    return True

WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)
u32.EnumWindows(WNDENUMPROC(enum_cb), 0)

# Check which WAATClient processes exist
import subprocess
out = subprocess.check_output(['tasklist', '/FI', 'IMAGENAME eq WAATClient.exe']).decode('gbk')
print("Tasklist:\n", out)

# Find windows for those PIDs
pids = [int(line.split()[1]) for line in out.splitlines() if 'WAATClient.exe' in line]
print("PIDs:", pids)
for h, p, title, cls, vis in hwnds:
    if p in pids:
        print(f"HWND: {hex(h)}, PID: {p}, Visible: {vis}, Class: '{cls}', Title: '{title}'")
