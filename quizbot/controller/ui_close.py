"""答题框自动关闭：截图定位 + 合成鼠标消息点击（不移动真实光标）。

原理:
  - PrintWindow(PW_RENDERFULLCONTENT) 抓游戏 DX 画面（无需窗口在前台）
  - 向游戏主窗口 SendMessage(WM_LBUTTONDOWN/UP) 发合成点击消息，
    游戏内部 UI 引擎按坐标命中答题框选项并走正常关闭流程
  - 全程不改变真实鼠标光标位置，用户可正常使用电脑
"""
import ctypes
import ctypes.wintypes as wt
import os
import struct
import time
import zlib

u32 = ctypes.WinDLL("user32")
g32 = ctypes.WinDLL("gdi32")

WM_LBUTTONDOWN = 0x0201
WM_LBUTTONUP = 0x0202
MK_LBUTTON = 0x0001
PW_RENDERFULLCONTENT = 2

WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)


class BMIH(ctypes.Structure):
    _fields_ = [("biSize", wt.DWORD), ("biWidth", ctypes.c_long), ("biHeight", ctypes.c_long),
                ("biPlanes", wt.WORD), ("biBitCount", wt.WORD), ("biCompression", wt.DWORD),
                ("biSizeImage", wt.DWORD), ("biXPelsPerMeter", ctypes.c_long),
                ("biYPelsPerMeter", ctypes.c_long), ("biClrUsed", wt.DWORD),
                ("biClrImportant", wt.DWORD)]


def find_game_hwnd(pid):
    """找 pid 对应的游戏主窗口（标题含"大冒险"的可见顶层窗口）"""
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


def capture(pid):
    """截图。返回 (hwnd, w, h, rect, raw_rgb24) 或 None"""
    hwnd = find_game_hwnd(pid)
    if not hwnd:
        return None
    rc = wt.RECT()
    u32.GetWindowRect(hwnd, ctypes.byref(rc))
    w, h = rc.right - rc.left, rc.bottom - rc.top
    if w <= 0 or h <= 0:
        return None
    hdc = u32.GetWindowDC(hwnd)
    mem = g32.CreateCompatibleDC(hdc)
    bmp = g32.CreateCompatibleBitmap(hdc, w, h)
    g32.SelectObject(mem, bmp)
    ok = u32.PrintWindow(hwnd, mem, PW_RENDERFULLCONTENT) or u32.PrintWindow(hwnd, mem, 0)
    bmi = BMIH()
    bmi.biSize = ctypes.sizeof(BMIH)
    bmi.biWidth = w
    bmi.biHeight = -h
    bmi.biPlanes = 1
    bmi.biBitCount = 24
    bmi.biSizeImage = ((w * 3 + 3) // 4) * 4 * h
    buf = ctypes.create_string_buffer(bmi.biSizeImage)
    got = g32.GetDIBits(mem, bmp, 0, h, buf, ctypes.byref(bmi), 0)
    g32.DeleteObject(bmp)
    g32.DeleteDC(mem)
    u32.ReleaseDC(hwnd, hdc)
    if not got:
        return None
    return hwnd, w, h, (rc.left, rc.top, rc.right, rc.bottom), buf.raw


def is_black(raw, w, h):
    """最小化/未渲染的窗口截出来是全黑——跳过点击防止误操作"""
    step = max(1, len(raw) // 3000)
    sample = raw[2::step]
    return sum(sample) / max(1, len(sample)) < 12


def save_png(path, w, h, px):
    stride = ((w * 3 + 3) // 4) * 4

    def chunk(tag, payload):
        c = tag + payload
        return struct.pack(">I", len(payload)) + c + struct.pack(">I", zlib.crc32(c))

    raw = bytearray()
    for y in range(h):
        raw += b"\x00" + px[y * stride:(y + 1) * stride]
    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr)
                + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))


def click_window_coords(hwnd, wr, x, y):
    """向 hwnd 发合成点击。x,y 为窗口坐标（相对 GetWindowRect 左上角）。
    内部换算成客户区坐标。不移动真实鼠标。"""
    pt = wt.POINT(0, 0)
    u32.ClientToScreen(hwnd, ctypes.byref(pt))
    cx = x - (pt.x - wr[0])
    cy = y - (pt.y - wr[1])
    lp = (cy << 16) | (cx & 0xFFFF)
    u32.SendMessageA(hwnd, WM_LBUTTONDOWN, MK_LBUTTON, lp)
    time.sleep(0.05)
    u32.SendMessageA(hwnd, WM_LBUTTONUP, 0, lp)


def close_frame(pid, opt_coords, shot_dir):
    """答题后关框流程：截图 → 按标定坐标点击选项 → 再截图存证。
    返回日志字符串。坐标未标定/画面不可用时只截图（校准阶段）。"""
    cap = capture(pid)
    if not cap:
        return "UI关框: 找不到游戏窗口"
    hwnd, w, h, wr, px = cap
    ts = time.strftime("%H%M%S")
    pre = os.path.join(shot_dir, f"q_{pid}_{ts}_pre.png")
    save_png(pre, w, h, px)
    if is_black(px, w, h):
        return f"UI关框: 窗口未渲染(最小化?)，仅存截图 {os.path.basename(pre)}"
    if not opt_coords:
        return f"UI关框: 坐标未标定，仅存截图 {os.path.basename(pre)}"
    pt = opt_coords.get("opt")
    if not pt:
        return f"UI关框: 该选项无坐标，仅存截图 {os.path.basename(pre)}"
    click_window_coords(hwnd, wr, pt[0], pt[1])
    time.sleep(1.0)
    cap2 = capture(pid)
    post = "post失败"
    if cap2:
        _, w2, h2, _, px2 = cap2
        name = f"q_{pid}_{ts}_post.png"
        save_png(os.path.join(shot_dir, name), w2, h2, px2)
        post = name
    return f"UI关框: 已点击选项({pt[0]},{pt[1]}) 截图={os.path.basename(pre)}/{post}"
