# -*- coding: utf-8 -*-
import ctypes
import ctypes.wintypes as wt

u32 = ctypes.WinDLL("user32")
pids = [1400, 14688, 22680, 24056, 31112]

def cb(hwnd, extra):
    pid = wt.DWORD()
    u32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    if pid.value in pids:
        length = u32.GetWindowTextLengthW(hwnd)
        buf = ctypes.create_unicode_buffer(length + 1)
        u32.GetWindowTextW(hwnd, buf, length + 1)
        cls = ctypes.create_unicode_buffer(256)
        u32.GetClassNameW(hwnd, cls, 256)
        if length > 0 or cls.value != '':
            print(f"[PID {pid.value}] HWND={hex(hwnd)} Cls={cls.value} Title='{buf.value}'")
    return True

WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)
u32.EnumWindows(WNDENUMPROC(cb), 0)
