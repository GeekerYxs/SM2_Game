# -*- coding: utf-8 -*-
"""防外挂题框关闭模块：模板匹配标题 -> 定位选项行 -> SendInput 真实点击。

背景:
    答题框(DX自绘)对合成鼠标消息(PostMessage/SendMessage)免疫，
    只有系统级真实输入(SendInput)能被 DirectInput 感知。
    机器人已通过封包提交答案且服务器确认后，真实点击"已答对的那个选项"
    会重复提交同一正确答案（服务器视为重复，无害），同时客户端本地关闭答题框。
"""
import ctypes
import ctypes.wintypes as wt
import os
import sys
import time

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
import numpy as np
import cv2

from screenshot import find_game_hwnd, capture

u32 = ctypes.WinDLL("user32")
g32 = ctypes.WinDLL("gdi32")

TEMPLATE_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "title_template.png")
_SCORE_THR = 0.50


class BMIH(ctypes.Structure):
    _fields_ = [("biSize", wt.DWORD), ("biWidth", ctypes.c_long), ("biHeight", ctypes.c_long),
                ("biPlanes", wt.WORD), ("biBitCount", wt.WORD), ("biCompression", wt.DWORD),
                ("biSizeImage", wt.DWORD), ("biXPelsPerMeter", ctypes.c_long),
                ("biYPelsPerMeter", ctypes.c_long), ("biClrUsed", wt.DWORD),
                ("biClrImportant", wt.DWORD)]


def _grab(pid, retries=14, sleep=0.35):
    """PrintWindow 截图，带全黑帧重试。返回灰度图或 None。"""
    hwnd = find_game_hwnd(pid)
    if not hwnd:
        return None, None
    for _ in range(retries):
        w, h, px = capture(hwnd)
        arr = np.frombuffer(px, dtype=np.uint8).reshape(h, ((w * 3 + 3) // 4) * 4)[:, :w * 3].reshape(h, w, 3)
        gray = cv2.cvtColor(arr, cv2.COLOR_BGR2GRAY)
        if float(arr.mean()) > 25 and int(arr.max()) > 200:
            return hwnd, gray
        time.sleep(sleep)
    return hwnd, None


def load_template():
    tpl = cv2.imread(TEMPLATE_PATH, cv2.IMREAD_GRAYSCALE)
    return tpl


def detect_frame(pid):
    """返回 dict(opts=[(x,y)x4], score=…) 或 None。坐标为窗口坐标。"""
    tpl = load_template()
    if tpl is None:
        raise FileNotFoundError(TEMPLATE_PATH)
    hwnd, gray = _grab(pid)
    if gray is None:
        return None
    res = cv2.matchTemplate(gray, tpl, cv2.TM_CCOEFF_NORMED)
    _, score, _, loc = cv2.minMaxLoc(res)
    if score < _SCORE_THR:
        return None
    tx, ty = loc
    th, tw = tpl.shape
    # 选项扫描窗：标题模板下方（题目1~3行都让位），x 限制在框内文字列
    y0, y1 = ty + th + 58, ty + th + 175
    x0, x1 = tx, tx + 100
    if y1 >= gray.shape[0]:
        return None
    win = gray[y0:y1, x0:x1]
    rows = (win > 165).sum(axis=1) >= 5
    segs = []
    i, m = 0, len(rows)
    while i < m:
        if rows[i]:
            j = i; gap = 0; end = i
            while j < m:
                if rows[j]:
                    end = j; gap = 0
                else:
                    gap += 1
                    if gap > 2:
                        break
                j += 1
            if 4 <= end - i <= 18:
                segs.append((i, end))
            i = j + 1
        else:
            i += 1
    if len(segs) < 4:
        return None
    # 取最后4段（题目可能占1-3行，选项是末尾4条等距行）
    four = segs[-4:]
    tops = [s[0] for s in four]
    diffs = [tops[k + 1] - tops[k] for k in range(3)]
    if not all(14 <= d <= 26 for d in diffs):
        return None
    opts = []
    for (a, b) in four:
        band = win[a:b + 1]
        cols = np.where((band > 165).any(axis=0))[0]
        left = int(cols[0]) + x0 if len(cols) else x0 + 15
        opts.append((left + 15, y0 + (a + b) // 2))
    return dict(opts=opts, score=float(score), title=(tx, ty))


def _set_foreground(hwnd):
    """ALT 技巧绕过前台锁，返回原前台窗口。"""
    prev = u32.GetForegroundWindow()
    try:
        u32.keybd_event(0x12, 0, 0, 0)      # ALT down
        u32.keybd_event(0x12, 0, 2, 0)      # ALT up
    except Exception:
        pass
    u32.SetForegroundWindow(hwnd)
    time.sleep(0.12)
    return prev


def click_option(pid, opt_no, restore_cursor=True):
    """真实点击第 opt_no(1-4) 个选项。成功返回 True。"""
    d = detect_frame(pid)
    if not d:
        return False, "frame-not-found"
    hwnd = find_game_hwnd(pid)
    if not hwnd or u32.IsIconic(hwnd):
        return False, "window-minimized"
    if not (1 <= opt_no <= 4):
        return False, "bad-opt"
    cx, cy = d["opts"][opt_no - 1]
    rc = wt.RECT()
    u32.GetWindowRect(hwnd, ctypes.byref(rc))
    sx, sy = rc.left + cx, rc.top + cy

    pt = wt.POINT()
    u32.GetCursorPos(ctypes.byref(pt))
    old_x, old_y = pt.x, pt.y
    prev = _set_foreground(hwnd)
    time.sleep(0.08)
    u32.SetCursorPos(sx, sy)
    time.sleep(0.05)
    u32.mouse_event(0x0002, 0, 0, 0, 0)   # LEFTDOWN
    time.sleep(0.04)
    u32.mouse_event(0x0004, 0, 0, 0, 0)   # LEFTUP
    time.sleep(0.15)
    if restore_cursor:
        u32.SetCursorPos(old_x, old_y)
    if prev and prev != hwnd:
        u32.SetForegroundWindow(prev)
    return True, f"clicked({sx},{sy}) score={d['score']:.2f}"


def _frame_present(pid):
    """True=框在, False=框不在, None=截图一直失败(未知)"""
    tpl = load_template()
    if tpl is None:
        raise FileNotFoundError(TEMPLATE_PATH)
    for _ in range(3):
        hwnd, gray = _grab(pid, retries=10)
        if gray is not None:
            res = cv2.matchTemplate(gray, tpl, cv2.TM_CCOEFF_NORMED)
            _, score, _, _ = cv2.minMaxLoc(res)
            return score >= _SCORE_THR
        time.sleep(0.5)
    return None


def close_answered_frame(pid, opt_no, verify=True):
    """关闭已作答的框：点击 -> 截图验证 -> 未消失再点一次。"""
    ok, info = click_option(pid, opt_no)
    if not ok:
        return False, info
    if not verify:
        return True, info
    time.sleep(1.0)
    present = _frame_present(pid)
    if present is False:
        return True, info + " verified-closed"
    if present is True:                   # 还在 → 再点一次
        ok2, info2 = click_option(pid, opt_no)
        if ok2:
            time.sleep(1.0)
            present = _frame_present(pid)
            info += " retry:" + info2
    if present is None:
        return True, info + " verify-unknown(capture-failed)"
    return True, info + (" still-open" if present else " verified-closed")


if __name__ == "__main__":
    pid = int(sys.argv[1])
    opt = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    if opt:
        print(close_answered_frame(pid, opt))
    else:
        d = detect_frame(pid)
        print("NOT FOUND" if not d else f"score={d['score']:.2f} title={d['title']} opts={d['opts']}")
