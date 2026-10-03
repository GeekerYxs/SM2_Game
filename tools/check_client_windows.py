import ctypes
import ctypes.wintypes as wt
import sys

sys.stdout.reconfigure(encoding='utf-8')

u32 = ctypes.windll.user32
pids = [4944, 9156, 16868, 29252, 35408]

def cb(hwnd, extra):
    pid = wt.DWORD()
    u32.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    if pid.value in pids:
        length = u32.GetWindowTextLengthW(hwnd)
        buf = ctypes.create_unicode_buffer(length + 1)
        u32.GetWindowTextW(hwnd, buf, length + 1)
        cls = ctypes.create_unicode_buffer(256)
        u32.GetClassNameW(hwnd, cls, 256)
        if buf.value or cls.value:
            print(f"PID {pid.value} HWND={hex(hwnd)} Class={cls.value} Title='{buf.value}'")
    return True

WNDENUMPROC = ctypes.WINFUNCTYPE(ctypes.c_bool, wt.HWND, wt.LPARAM)
u32.EnumWindows(WNDENUMPROC(cb), 0)
