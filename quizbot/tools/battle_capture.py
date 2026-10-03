# -*- coding: utf-8 -*-
"""battle_capture.py — 战斗封包抓取与分析程序（配合 v7 DLL 抓包模式）。

流程：
  1. 连控制器命令端口 127.0.0.1:8488，广播 {"cmd":"cap_on"}（10 客户端 DLL
     开始把全部入站帧的 密文+解码明文 落盘 logs/build/../cap_<pid>.log）
  2. 每 5 秒打印一次各客户端抓包进度
  3. 默认 10 分钟后广播 {"cmd":"cap_off"}
  4. 自动分析：
     - 按客户端 / 操作码(opcode) 统计帧数与字节量
     - 从 controller.log 提取含"经验/升级/战斗/击杀"的系统提示及数值，
       与各 op 帧做时间相关性匹配（±3 秒窗口）
     - 对相关 op 的明文做 i32 LE 槽位解码，标出与提示数值吻合的槽位；
       并提取 GBK 可读字符串（怪物名/技能名等）
  5. 产出分析报告 logs/battle_report_<时间戳>.md + 控制台摘要

用法：
  python battle_capture.py [--minutes 10] [--no-cap]   # --no-cap 只分析已有 cap 文件
"""
import json
import re
import socket
import sys
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CAP_DIR = ROOT / "build" / "logs"          # DLL 的日志目录
CTRL_LOG = ROOT / "logs" / "controller.log"
CMD_PORT = 8488

RE_CAP = re.compile(
    r"^(\d\d:\d\d:\d\d)\.\d{3} \[CAP\] ([0-9A-F]{4}) inv=([0-9A-F]{4}) "
    r"len=(\d+) #\d+ wire=([0-9a-f]*)(?:\|trunc)? plain=([0-9a-f]*)(?:\|trunc)?\s*$")


def log(msg):
    print(time.strftime("[%H:%M:%S] ") + msg, flush=True)


# ---------------- 命令端口通信 ----------------
def send_broadcast(cmd_obj, pids=None, timeout=5):
    """返回 (relayed, 响应json)"""
    s = socket.create_connection(("127.0.0.1", CMD_PORT), timeout=timeout)
    req = {"cmd": cmd_obj}
    if pids:
        req["pids"] = pids
    s.sendall((json.dumps(req) + "\n").encode())
    buf = b""
    resp = None
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            d = s.recv(4096)
        except socket.timeout:
            break
        if not d:
            break
        buf += d
        if b"\n" in buf:
            line, _ = buf.split(b"\n", 1)
            try:
                resp = json.loads(line.decode())
            except Exception:
                resp = None
            break
    s.close()
    return (resp or {}).get("relayed", 0), resp


# ---------------- 抓包进度 ----------------
def cap_files():
    return sorted(CAP_DIR.glob("cap_*.log"))


def file_size(p):
    try:
        return p.stat().st_size
    except OSError:
        return 0


def monitor(minutes):
    files = cap_files()
    sizes = {p: file_size(p) for p in files}
    t_end = time.time() + minutes * 60
    while time.time() < t_end:
        time.sleep(5)
        total_delta = 0
        parts = []
        for p in cap_files():
            sz = file_size(p)
            d = sz - sizes.get(p, 0)
            sizes[p] = sz
            if d:
                total_delta += d
                parts.append(f"{p.stem.split('_')[1]}:+{d//1024}KB")
        remain = int(t_end - time.time())
        log(f"剩余 {remain//60}:{remain%60:02d}  抓包增速 "
            f"{total_delta//1024}KB/5s  [{', '.join(parts) or '无新数据'}]")
    log("抓包时间到")


# ---------------- 解析 ----------------
def parse_cap_file(path):
    """返回 [(sec, op, inv, len, plain_bytes)]，只取最后一次 capture ON 之后的帧"""
    frames = []
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return frames
    marker = "---- capture ON ----"
    pos = text.rfind(marker)
    if pos >= 0:
        text = text[pos + len(marker):]
    for ln in text.splitlines():
        m = RE_CAP.match(ln)
        if not m:
            continue
        sec, op, inv, ln_, _wire, plain = m.groups()
        if "|" in plain:
            plain = plain.split("|")[0]
        try:
            pb = bytes.fromhex(plain) if plain else b""
        except ValueError:
            pb = b""
        frames.append((sec, int(op, 16), int(inv, 16), int(ln_), pb))
    return frames


RE_SYS = re.compile(r"\[(\d\d:\d\d:\d\d)\] \[pid (\d+)\] 系统提示: (.*)")
KEYWORDS = ("经验", "升级", "击杀", "战斗", "获得", "伤害", "死亡", "掉落")
RE_NUM = re.compile(r"(\d+)")



def parse_controller_sys():
    """返回 [(sec, pid, text, numbers_in_text)] 只保留含关键字的行"""
    out = []
    if not CTRL_LOG.exists():
        return out
    # 只读抓包窗口附近的尾部（整个文件读也可承受）
    for ln in CTRL_LOG.read_text(encoding="utf-8", errors="replace").splitlines():
        m = RE_SYS.match(ln)
        if not m:
            continue
        sec, pid, text = m.groups()
        clean = re.sub(r"#[0-9A-Fa-f]{6}#", "", text)
        if any(k in clean for k in KEYWORDS):
            nums = [int(x) for x in RE_NUM.findall(clean)]
            out.append((sec, int(pid), clean, nums))
    return out


def sec2ts(sec):
    h, m, s = sec.split(":")
    return int(h) * 3600 + int(m) * 60 + int(s)


def gbk_strings(b, minlen=3):
    """提取明文中的 GBK 可读串（混中文/ASCII）"""
    out, cur = [], b""
    for c in b:
        if 0x20 <= c < 0x7F or c >= 0x81:
            cur += bytes([c])
        else:
            if len(cur) >= minlen:
                try:
                    s = cur.decode("gbk", "strict")
                    if all(ch.isprintable() for ch in s):
                        out.append(s)
                except Exception:
                    pass
            cur = b""
    if len(cur) >= minlen:
        try:
            out.append(cur.decode("gbk", "strict"))
        except Exception:
            pass
    return out


def i32_slots(b):
    """按 4 字节槽位解读 i32 LE（截齐）"""
    n = len(b) // 4
    vals = []
    for i in range(n):
        v = int.from_bytes(b[i*4:(i+1)*4], "little", signed=True)
        vals.append(v)
    return vals


def analyze():
    sys_events = parse_controller_sys()
    log(f"系统提示(含战斗/经验关键词)共 {len(sys_events)} 条")
    per_pid = {}
    for p in cap_files():
        pid = int(p.stem.split("_")[1])
        fr = parse_cap_file(p)
        if fr:
            per_pid[pid] = fr

    report = ["# 战斗封包抓取分析报告", "",
              f"- 时间: {time.strftime('%Y-%m-%d %H:%M:%S')}",
              f"- 参与客户端: {len(per_pid)} 个",
              f"- 系统提示样本: {len(sys_events)} 条", ""]

    op_stats = defaultdict(lambda: [0, 0])          # op -> [count, bytes]
    op_samples = {}                                  # op -> 最新明文
    for pid, fr in per_pid.items():
        for sec, op, inv, ln, pb in fr:
            op_stats[op][0] += 1
            op_stats[op][1] += ln
            if pb:
                op_samples[op] = (pid, sec, pb)

    report.append("## 操作码统计（全部客户端合计）\n")
    report.append("| op | 帧数 | 字节 | 明文样例(前64B) |")
    report.append("|---|---|---|---|")
    for op, (cnt, byt) in sorted(op_stats.items(), key=lambda kv: -kv[1][1]):
        sample = ""
        if op in op_samples:
            sample = op_samples[op][2][:64].hex()
        report.append(f"| 0x{op:04X} | {cnt} | {byt} | `{sample}` |")

    # ---- 时间相关性：经验/战斗提示 ±3s 内出现的 op ----
    report.append("\n## 时间相关性（系统提示 ±3s 内出现的帧）\n")
    hits = defaultdict(lambda: defaultdict(int))     # (kw) -> op -> n
    sys_ts = [(sec2ts(sec), pid, text, nums) for sec, pid, text, nums in sys_events]
    for pid, fr in per_pid.items():
        fr_ts = [(sec2ts(sec), op, ln, pb) for sec, op, inv, ln, pb in fr]
        for t0, tpid, text, nums in sys_ts:
            kw = next((k for k in KEYWORDS if k in text), "?")
            for t, op, ln, pb in fr_ts:
                if abs(t - t0) <= 3:
                    hits[kw][op] += 1
    report.append("| 关键词 | op | 命中帧数 |")
    report.append("|---|---|---|")
    for kw in sorted(hits):
        for op, n in sorted(hits[kw].items(), key=lambda kv: -kv[1])[:8]:
            report.append(f"| {kw} | 0x{op:04X} | {n} |")

    # ---- 数值匹配：提示中的数字 与 明文 i32 槽位吻合 ----
    report.append("\n## 数值匹配（明文 i32 槽位 == 系统提示中的数字）\n")
    matched = defaultdict(set)                       # op -> {value}
    for pid, fr in per_pid.items():
        fr_ts = [(sec2ts(sec), op, pb) for sec, op, inv, ln, pb in fr]
        for t0, tpid, text, nums in sys_ts:
            nums = {n for n in nums if 0 < n < 100000000}
            if not nums:
                continue
            for t, op, pb in fr_ts:
                if abs(t - t0) <= 3:
                    for v in i32_slots(pb):
                        if v in nums:
                            matched[op].add(v)
    report.append("| op | 吻合数值 |")
    report.append("|---|---|")
    for op in sorted(matched, key=lambda o: -len(matched[o])):
        vals = sorted(matched[op])[:10]
        report.append(f"| 0x{op:04X} | {', '.join(map(str, vals))} |")

    # ---- 重点 op 明文明细（经验相关 op 的槽位解码样例）----
    report.append("\n## 重点 op 明文槽位样例\n")
    focus_ops = set(matched) | set(hits.get("经验", {})) | set(hits.get("击杀", {})) \
        | set(hits.get("战斗", {}))
    for op in sorted(focus_ops):
        if op not in op_samples:
            continue
        pid, sec, pb = op_samples[op]
        report.append(f"\n### op 0x{op:04X}（样例 pid={pid} {sec} len={len(pb)}）")
        slots = i32_slots(pb[:64])
        report.append(f"- i32槽位: {slots}")
        strs = gbk_strings(pb)
        if strs:
            report.append(f"- GBK字符串: {strs[:8]}")
        report.append(f"- hex: `{pb[:128].hex()}`")

    out = ROOT / "logs" / f"battle_report_{time.strftime('%H%M%S')}.md"
    out.write_text("\n".join(report), encoding="utf-8")
    log(f"分析完成 -> {out}")
    return out, op_stats, matched


def find_value(value, window_s=None):
    """在全部 cap 文件的明文里搜索指定数值（i32 LE 与 u16），打印命中帧上下文"""
    le32 = (value & 0xFFFFFFFF).to_bytes(4, "little")
    le16 = (value & 0xFFFF).to_bytes(2, "little")
    hits = defaultdict(list)                     # op -> [(pid, sec, off, pb)]
    for p in cap_files():
        pid = int(p.stem.split("_")[1])
        for sec, op, inv, ln, pb in parse_cap_file(p):
            for label, needle in (("i32", le32), ("u16", le16)):
                off = 0
                while True:
                    off = pb.find(needle, off)
                    if off < 0:
                        break
                    hits[op].append((pid, sec, label, off, pb))
                    off += 1
    log(f"数值 {value} 命中 {sum(len(v) for v in hits.values())} 处，"
        f"涉及 op: {['0x%04X' % o for o in hits]}")
    for op, lst in sorted(hits.items(), key=lambda kv: -len(kv[1])):
        print(f"\n=== op 0x{op:04X}：{len(lst)} 处命中 ===")
        for pid, sec, label, off, pb in lst[:5]:
            ctx = pb[max(0, off - 16):off + 20]
            print(f"[{sec}] pid={pid} {label}偏移={off} len={len(pb)}")
            print(f"   上下文: {ctx.hex()}")
            s = max(0, off - 16)
            lead = off - s
            print(f"   槽位: 命中值在 i32 槽 {off//4}，帧内前 16 槽 = "
                  f"{[int.from_bytes(pb[i*4:(i+1)*4],'little',signed=True) for i in range(min(16,len(pb)//4))]}")
        if len(lst) > 5:
            print(f"   ... 其余 {len(lst)-5} 条略")


def main():
    minutes = 10
    do_cap = "--no-cap" not in sys.argv
    if "--minutes" in sys.argv:
        minutes = int(sys.argv[sys.argv.index("--minutes") + 1])
    if "--find" in sys.argv:
        find_value(int(sys.argv[sys.argv.index("--find") + 1]))
        return

    if do_cap:
        n, resp = send_broadcast({"cmd": "cap_on"})
        log(f"cap_on 广播 -> {n} 个客户端已开启抓包 ({resp})")
        if n == 0:
            log("!! 没有任何客户端响应，请检查控制器/注入状态")
            sys.exit(2)
        log(f"抓包窗口 {minutes} 分钟开始 —— 现在去打战斗！")
        monitor(minutes)
        n, resp = send_broadcast({"cmd": "cap_off"})
        log(f"cap_off 广播 -> {n} 个客户端已停止 ({resp})")

    report, op_stats, matched = analyze()
    print("\n===== 摘要 =====")
    top = sorted(op_stats.items(), key=lambda kv: -kv[1][1])[:8]
    print("帧量最大的 op:", ", ".join(f"0x{o:04X}({c}帧)" for o, (c, b) in top))
    if matched:
        print("数值吻合的 op（疑似经验/结算包）:")
        for op, vals in sorted(matched.items(), key=lambda kv: -len(kv[1])):
            print(f"  0x{op:04X}: {sorted(vals)[:8]}")
    else:
        print("未发现与系统提示数值吻合的 op —— 窗口内可能没有战斗发生，"
              "或结算包不含提示中的数字（看报告的'时间相关性'部分）")
    print(f"完整报告: {report}")


if __name__ == "__main__":
    main()
