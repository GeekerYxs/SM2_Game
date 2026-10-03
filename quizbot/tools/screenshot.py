"""用 PrintWindow 截取游戏客户端窗口，存为 PNG。

用法: python screenshot.py <pid|all> [outdir]
原理: 枚举顶层窗口找 pid 对应的游戏主窗口 -> PrintWindow(PW_RENDERFULLCONTENT) -> PNG
"""
import ctypes
import ctypes.wintypes as wt
import os
import struct
import sys
import zlib

u32 = ctypes.WinDLL("user32")
g32 = ctypes.WinDLL("gdi32")

WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)


class BMIH(ctypes.Structure):
    _fields_ = [("biSize", wt.DWORD), ("biWidth", ctypes.c_long), ("biHeight", ctypes.c_long),
                ("biPlanes", wt.WORD), ("biBitCount", wt.WORD), ("biCompression", wt.DWORD),
                ("biSizeImage", wt.DWORD), ("biXPelsPerMeter", ctypes.c_long),
                ("biYPelsPerMeter", ctypes.c_long), ("biClrUsed", wt.DWORD),
                ("biClrImportant", wt.DWORD)]


def find_game_hwnd(pid):
    result = []

    @WNDENUMPROC
    def cb(hwnd, _):
        p = wt.DWORD()
        u32.GetWindowThreadProcessId(hwnd, ctypes.byref(p))
        if p.value == pid and u32.IsWindowVisible(hwnd):
            n = u32.GetWindowTextLengthW(hwnd)
            if n > 0:
                buf = ctypes.create_unicode_buffer(n + 1)
                u32.GetWindowTextW(hwnd, buf, n + 1)
                if "大冒险" in buf.value:
                    result.append(hwnd)
        return True

    u32.EnumWindows(cb, 0)
    return result[0] if result else None


def capture(hwnd):
    rc = wt.RECT()
    u32.GetWindowRect(hwnd, ctypes.byref(rc))
    w, h = rc.right - rc.left, rc.bottom - rc.top
    hdc = u32.GetWindowDC(hwnd)
    mem = g32.CreateCompatibleDC(hdc)
    bmp = g32.CreateCompatibleBitmap(hdc, w, h)
    g32.SelectObject(mem, bmp)
    if not u32.PrintWindow(hwnd, mem, 2):  # PW_RENDERFULLCONTENT
        u32.PrintWindow(hwnd, mem, 0)
    bmi = BMIH()
    bmi.biSize = ctypes.sizeof(BMIH)
    bmi.biWidth = w
    bmi.biHeight = -h
    bmi.biPlanes = 1
    bmi.biBitCount = 24
    bmi.biSizeImage = ((w * 3 + 3) // 4) * 4 * h
    buf = ctypes.create_string_buffer(bmi.biSizeImage)
    g32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bmi), 0)
    g32.DeleteObject(bmp)
    g32.DeleteDC(mem)
    u32.ReleaseDC(hwnd, hdc)
    return w, h, buf.raw


def to_png(w, h, px):
    stride = ((w * 3 + 3) // 4) * 4

    def chunk(tag, payload):
        c = tag + payload
        return struct.pack(">I", len(payload)) + c + struct.pack(">I", zlib.crc32(c))

    raw = bytearray()
    for y in range(h):
        raw += b"\x00" + px[y * stride:(y + 1) * stride]
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))


def main():
    target = sys.argv[1]
    outdir = sys.argv[2] if len(sys.argv) > 2 else "build/shots"
    os.makedirs(outdir, exist_ok=True)
    if target == "all":
        pids = []
        import subprocess
        out = subprocess.check_output(
            ["tasklist", "/FI", "IMAGENAME eq WAATClient.exe", "/FO", "CSV"]).decode("mbcs", "ignore")
        for line in out.splitlines()[1:]:
            parts = line.split('","')
            if len(parts) > 1:
                pids.append(int(parts[1].strip('"')))
    else:
        pids = [int(target)]
    for pid in pids:
        hwnd = find_game_hwnd(pid)
        if not hwnd:
            print(f"[pid {pid}] game window not found")
            continue
        w, h, px = capture(hwnd)
        path = os.path.join(outdir, f"shot_{pid}.png")
        with open(path, "wb") as f:
            f.write(to_png(w, h, px))
        print(f"[pid {pid}] hwnd={hwnd:#x} {w}x{h} -> {path}")


if __name__ == "__main__":
    main()
