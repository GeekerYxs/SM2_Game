# -*- coding: utf-8 -*-
"""防外挂题框检测 v3 —— 双帧差分找静止文字。

用法:
    python frame_detect.py <pid>
原理:
    隔0.4s截两帧 -> 完全相同且较亮的像素 = 静止UI文字(题目/选项)
    再找 4 条等间距(~21px)选项行
"""
import sys, os, time
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from screenshot import find_game_hwnd, capture


def grab_raw(pid, retries=6):
    hwnd = find_game_hwnd(pid)
    if not hwnd:
        return None, None
    for _ in range(retries):
        w, h, px = capture(hwnd)
        stride = ((w * 3 + 3) // 4) * 4
        arr = np.frombuffer(px, dtype=np.uint8, count=stride * h).reshape(h, stride)
        rgb = arr[:, :w * 3].reshape(h, w, 3).astype(np.int16)
        if int(rgb.max()) > 200 and float(rgb.mean()) > 25:
            return hwnd, rgb          # 有效帧（PrintWindow 偶发全黑，重试）
        time.sleep(0.3)
    return hwnd, None


def detect_frame(pid, interval=0.4):
    hwnd, a = grab_raw(pid)
    if hwnd is None or a is None:
        return None
    time.sleep(interval)
    _, b = grab_raw(pid)
    if b is None or a.shape != b.shape:
        return None
    mx_a = a.max(axis=2)
    static = (a == b).all(axis=2) & (mx_a > 150)

    # 每行静止亮像素数（只看中央区域）
    cnt = static[:, 400:950].sum(axis=1)
    rows = cnt >= 8
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
            if 5 <= end - i <= 18:
                segs.append((i, end, int(cnt[i:end+1].max())))
            i = j + 1
        else:
            i += 1
    # 找 4 条连续、间距 18~26px 的段
    for i in range(len(segs) - 3):
        tops = [s[0] for s in segs[i:i+4]]
        diffs = [tops[k+1] - tops[k] for k in range(3)]
        if all(17 <= d <= 26 for d in diffs):
            opts = []
            for (a0, b0, _) in segs[i:i+4]:
                band = static[a0:b0+1, 400:950]
                cols = np.where(band.any(axis=0))[0]
                left = int(cols[0]) + 400 if len(cols) else 500
                opts.append((left + 12, (a0 + b0) // 2))
            return dict(opts=opts, segs=segs[i:i+4])
    return None


def main():
    pid = int(sys.argv[1])
    d = detect_frame(pid)
    if not d:
        print(f"[pid {pid}] frame NOT found")
        return
    print(f"[pid {pid}] FRAME FOUND")
    for k, ((a0, b0, pk), opt) in enumerate(zip(d["segs"], d["opts"]), 1):
        print(f"  opt{k}: y={a0}-{b0} peak={pk} click=({opt[0]},{opt[1]})")


if __name__ == "__main__":
    main()
