# -*- coding: utf-8 -*-
"""大冒险2 自动答题控制器（机器级，单进程管理所有客户端）。

架构（对应交接包 README 第 5 节）：
  - 每个 WAATClient.exe 进程注入的 quizbot_hook.dll 通过命名管道
    \\\\.\\pipe\\quizbot_<pid> 上报事件（question/sys/sent/sendfail...）
  - 本控制器连接所有管道，运行答题引擎：
      本地题库 bank.json（题干→正确选项，答错自动记录排除项）
      → 未命中走 LLM（OpenAI 兼容接口，可选）
      → 全未命中按排除法兜底（答错无惩罚，实测可继续答下一题）
  - 结果回写：0x46FF "测试通过！" = 答对 → 题库确认存档；
    发出答案后又来新题 = 答错 → 记录错误选项
  - dry_run：只决策不发包

用法：
  python quizbot.py            # 按当前目录 config.json 运行
  python quizbot.py --dry      # 强制 dry_run（覆盖 config）
"""
import ctypes
import ctypes.wintypes as wt
import json
import random
import re
import sys
import threading
import time
import subprocess
import urllib.request
import urllib.error
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

# ---------------- Windows: 枚举进程（PROCESSENTRY32 正确定义，交接包原版有误） ----------------
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
TH32CS_SNAPPROCESS = 2

k32.CreateFileA.restype = wt.HANDLE
k32.CreateFileA.argtypes = [ctypes.c_char_p, wt.DWORD, wt.DWORD, ctypes.c_void_p, wt.DWORD, wt.DWORD, wt.HANDLE]
k32.ReadFile.restype = wt.BOOL
k32.ReadFile.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD), ctypes.c_void_p]
k32.WriteFile.restype = wt.BOOL
k32.WriteFile.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD), ctypes.c_void_p]
k32.PeekNamedPipe.restype = wt.BOOL
k32.PeekNamedPipe.argtypes = [wt.HANDLE, ctypes.c_void_p, wt.DWORD, ctypes.POINTER(wt.DWORD), ctypes.POINTER(wt.DWORD), ctypes.POINTER(wt.DWORD)]
k32.CloseHandle.restype = wt.BOOL
k32.CloseHandle.argtypes = [wt.HANDLE]


class PROCESSENTRY32(ctypes.Structure):
    _fields_ = [
        ("dwSize", wt.DWORD),
        ("cntUsage", wt.DWORD),
        ("th32ProcessID", wt.DWORD),
        ("th32DefaultHeapID", ctypes.POINTER(wt.ULONG)),
        ("th32ModuleID", wt.DWORD),
        ("cntThreads", wt.DWORD),
        ("th32ParentProcessID", wt.DWORD),
        ("pcPriClassBase", wt.LONG),
        ("dwFlags", wt.DWORD),
        ("szExeFile", ctypes.c_char * 260),
    ]


def find_pids(name="WAATClient.exe"):
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    e = PROCESSENTRY32()
    e.dwSize = ctypes.sizeof(e)
    pids = []
    ok = k32.Process32First(snap, ctypes.byref(e))
    while ok:
        if e.szExeFile.decode("mbcs", "ignore").lower() == name.lower():
            pids.append(e.th32ProcessID)
        ok = k32.Process32Next(snap, ctypes.byref(e))
    k32.CloseHandle(snap)
    return pids


# ---------------- 配置 ----------------
CONFIG_PATH = ROOT / "controller" / "config.json"
DEFAULT_CONFIG = {
    "dry_run": True,
    "answer_delay_ms": 500,
    "fallback": "eliminate",        # eliminate | first | random | llm_only
    "llm": {
        "enabled": False,
        "endpoint": "",             # 例: https://api.example.com/v1/chat/completions
        "api_key": "",
        "model": "",
        "timeout_s": 10,
    },
    "bank_path": "data/bank.json",
    "llm_cache_s": 3600,
}


def load_config():
    cfg = json.loads(json.dumps(DEFAULT_CONFIG))  # deep copy
    if CONFIG_PATH.exists():
        user = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
        for k, v in user.items():
            if k == "llm":
                cfg["llm"].update(v)
            else:
                cfg[k] = v
    else:
        CONFIG_PATH.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"[CONFIG] 已生成默认配置 {CONFIG_PATH}，请按需修改（LLM/开关）")
    return cfg


# ---------------- 题库 ----------------
class Bank:
    """bank.json 结构：{ stem: {"opt": int|None, "confirmed": bool, "wrong": [int...]} }"""

    def __init__(self, path: Path):
        self.path = path
        self.lock = threading.Lock()
        if path.exists():
            try:
                self.data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                self.data = {}
        else:
            self.data = {}
        self._seed()

    def _seed(self):
        # 交接包实测已知项
        m = '人们在动物园里看到的俗称"四不象"的动物是?'
        if m not in self.data:
            self.data[m] = {"opt": 2, "confirmed": True, "wrong": [], "note": "交接包实测：麋鹿"}
        g = "光学物理上，下列哪种自由发光的物体温度最高?"
        if g not in self.data:
            self.data[g] = {"opt": None, "confirmed": False, "wrong": [0],
                            "note": "交接包实测：选项1(正能量)是错的"}
        self.save()

    def get(self, stem):
        with self.lock:
            return self.data.get(stem)

    def lookup(self, stem, n_options):
        """返回 (选项索引, 理由) 或 (None, 理由)"""
        with self.lock:
            rec = self.data.get(stem)
        if rec:
            wrong = set(rec.get("wrong", []))
            if rec.get("confirmed") and rec.get("opt") is not None and rec["opt"] < n_options:
                return rec["opt"], "题库已确认"
            if rec.get("opt") is not None and rec["opt"] < n_options and rec["opt"] not in wrong:
                return rec["opt"], "题库历史答案(未最终确认)"
            # 排除法
            cands = [i for i in range(n_options) if i not in wrong]
            if cands:
                return cands[0], f"题库排除法(已排除{sorted(wrong)})"
            return None, "题库全部选项都被排除过"
        return None, "题库未命中"

    def record_wrong(self, stem, opt):
        with self.lock:
            rec = self.data.setdefault(stem, {"opt": None, "confirmed": False, "wrong": []})
            if opt not in rec["wrong"]:
                rec["wrong"].append(opt)
            if rec.get("opt") == opt:
                rec["opt"] = None
                rec["confirmed"] = False
            self.save()

    def record_right(self, stem, opt):
        with self.lock:
            rec = self.data.setdefault(stem, {"opt": None, "confirmed": False, "wrong": []})
            rec["opt"] = opt
            rec["confirmed"] = True
            rec["ts"] = int(time.time())
            self.save()

    def record_unconfirmed(self, stem, opt):
        """LLM/兜底给的答案，先记为候选（答对与否由结果回写决定）"""
        with self.lock:
            rec = self.data.setdefault(stem, {"opt": None, "confirmed": False, "wrong": []})
            if rec.get("opt") is None and opt not in rec.get("wrong", []):
                rec["opt"] = opt
            self.save()

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix(".tmp")
        tmp.write_text(json.dumps(self.data, ensure_ascii=False, indent=1), encoding="utf-8")
        tmp.replace(self.path)


# ---------------- LLM ----------------
class LLM:
    def __init__(self, cfg, cache_s=3600):
        self.cfg = cfg
        self.cache = {}
        self.cache_s = cache_s

    def ask(self, stem, options):
        """返回 (选项索引|None, 理由)"""
        if not self.cfg.get("enabled") or not self.cfg.get("endpoint"):
            return None, "LLM 未启用"
        key = stem
        now = time.time()
        if key in self.cache and now - self.cache[key][2] < self.cache_s:
            return self.cache[key][0], f"LLM缓存: {self.cache[key][1]}"
        prompt = (
            "你是一个游戏答题助手。请回答下面这道选择题，只输出正确选项的序号数字（不带顿号、不带解释）。\n"
            f"题目：{stem}\n选项：\n" +
            "\n".join(options) +
            "\n只输出 1 到 N 的一个数字。"
        )
        body = json.dumps({
            "model": self.cfg.get("model", ""),
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0,
            "max_tokens": 8,
        }).encode()
        req = urllib.request.Request(
            self.cfg["endpoint"], data=body,
            headers={"Content-Type": "application/json",
                     "Authorization": f"Bearer {self.cfg.get('api_key', '')}"})
        try:
            with urllib.request.urlopen(req, timeout=self.cfg.get("timeout_s", 10)) as r:
                resp = json.loads(r.read())
            text = resp["choices"][0]["message"]["content"].strip()
            m = re.search(r"[1-9]", text)
            if not m:
                return None, f"LLM回复无法解析: {text!r}"
            idx = int(m.group()) - 1
            self.cache[key] = (idx, text, now)
            return idx, f"LLM: {text!r}"
        except Exception as ex:
            return None, f"LLM调用失败: {ex}"


# ---------------- 日志 ----------------
_logmtx = threading.Lock()
LOG_PATH = ROOT / "logs" / "controller.log"


def log(msg):
    line = time.strftime("[%H:%M:%S] ") + msg
    with _logmtx:
        print(line, flush=True)
        LOG_PATH.parent.mkdir(exist_ok=True)
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(line + "\n")


# ---------------- 管道客户端线程 ----------------
class ClientThread(threading.Thread):
    def __init__(self, pid, cfg, bank, llm):
        super().__init__(daemon=True)
        self.pid = pid
        self.cfg = cfg
        self.bank = bank
        self.llm = llm
        self.pending = None      # {"stem","opt","n"}
        self.sock = None
        self.buf = b""
        self.alive = True

    def run(self):
        pipe_path = f"\\\\.\\pipe\\quizbot_{self.pid}".encode()
        GENERIC_READ = 0x80000000
        GENERIC_WRITE = 0x40000000
        OPEN_EXISTING = 3
        INVALID_HANDLE_VALUE = wt.HANDLE(-1).value

        h = k32.CreateFileA(pipe_path, GENERIC_READ | GENERIC_WRITE, 0, None, OPEN_EXISTING, 0, None)
        if h in (0, INVALID_HANDLE_VALUE, -1):
            log(f"[pid {self.pid}] 管道连接失败 err={ctypes.get_last_error()}")
            self.alive = False
            self.ended_ts = time.time()
            return
        self.h = h
        log(f"[pid {self.pid}] 已连接答题通道")
        last_beat = 0.0
        while self.alive:
            av = wt.DWORD(0)
            if not k32.PeekNamedPipe(h, None, 0, None, ctypes.byref(av), None):
                log(f"[pid {self.pid}] 管道断开 err={ctypes.get_last_error()}")
                break
            if av.value:
                b = ctypes.create_string_buffer(av.value)
                n = wt.DWORD(0)
                if not k32.ReadFile(h, b, av.value, ctypes.byref(n), None) or n.value == 0:
                    log(f"[pid {self.pid}] 管道断开(读失败)")
                    break
                self.buf += b.raw[:n.value]
                while b"\n" in self.buf:
                    line, self.buf = self.buf.split(b"\n", 1)
                    if not line.strip():
                        continue
                    try:
                        ev = json.loads(line.decode("utf-8", "replace"))
                    except Exception:
                        continue
                    try:
                        self.handle_event(ev)
                    except Exception as ex:
                        log(f"[pid {self.pid}] 事件处理异常: {ex}")
            elif time.time() - last_beat >= 0.8:
                self.send_cmd({"cmd": "ping"})
                last_beat = time.time()
            else:
                time.sleep(0.05)
        self.alive = False
        self.ended_ts = time.time()
        try:
            k32.CloseHandle(h)
        except Exception:
            pass

    def send_cmd(self, obj):
        data = (json.dumps(obj) + "\n").encode()
        n = wt.DWORD(0)
        ok = k32.WriteFile(self.h, data, len(data), ctypes.byref(n), None)
        return bool(ok)

    # ---- 事件处理 ----
    def handle_event(self, ev):
        t = ev.get("type")
        if t == "question":
            self.on_question(ev)
        elif t == "sys":
            self.on_sys(ev)
        elif t == "currency":
            log(f"[pid {self.pid}] 货币更新 a={ev.get('a')} b={ev.get('b')}")
        elif t == "settle":
            self.on_settle(ev)
        elif t in ("sent", "sendfail"):
            pass  # 已由 DLL 日志记录，决策日志在 on_question 里
        elif t == "pong":
            pass
        elif t == "question_bad":
            log(f"[pid {self.pid}] 题目解析异常: {ev}")
        else:
            log(f"[pid {self.pid}] 未知事件: {ev}")

    def on_settle(self, ev):
        """战斗结算落盘：logs/settle_YYYYMMDD.csv（time,pid,exp,gold）"""
        exp = ev.get("exp", 0)
        gold = ev.get("gold", 0)
        path = ROOT / "logs" / ("settle_" + time.strftime("%Y%m%d") + ".csv")
        with _logmtx:
            path.parent.mkdir(exist_ok=True)
            new = not path.exists()
            with open(path, "a", encoding="utf-8") as f:
                if new:
                    f.write("time,pid,exp,gold\n")
                f.write(f"{time.strftime('%H:%M:%S')},{self.pid},{exp},{gold}\n")
        log(f"[pid {self.pid}] 战斗结算 exp={exp} gold={gold}")

    def on_question(self, ev):
        stem = ev.get("stem", "")
        options = ev.get("options", [])
        qno = ev.get("qno")
        n = len(options)
        # 上一个 pending 未确认 → 说明上次答案错了（答错直接来下一题，无提示包）
        if self.pending and self.pending["stem"] != stem:
            self.bank.record_wrong(self.pending["stem"], self.pending["opt"])
            log(f"[pid {self.pid}] 上一题答错(来新题无确认): {self.pending['stem'][:20]}.. opt={self.pending['opt']} → 记入排除")
        elif self.pending and self.pending["stem"] == stem:
            log(f"[pid {self.pid}] 同题重发（可能服务端重推），忽略旧 pending")
        self.pending = None
        if n == 0:
            log(f"[pid {self.pid}] 题目无选项，跳过: qno={qno}")
            return
        log(f"[pid {self.pid}] 收到题目 qno={qno}: {stem} | 选项: {' / '.join(options)}")

        opt, why = self.bank.lookup(stem, n)
        if opt is None:
            opt, why = self.llm.ask(stem, options)
            if opt is not None and 0 <= opt < n:
                self.bank.record_unconfirmed(stem, opt)
        if opt is None or not (0 <= opt < n):
            mode = self.cfg.get("fallback", "eliminate")
            rec = self.bank.get(stem) or {}
            wrong = set(rec.get("wrong", []))
            if mode == "llm_only":
                log(f"[pid {self.pid}] 决策: 放弃（llm_only 且无答案）")
                return
            cands = [i for i in range(n) if i not in wrong] or list(range(n))
            if mode == "first":
                opt = cands[0]
            else:
                opt = random.choice(cands)
            why = f"兜底({mode})"
        log(f"[pid {self.pid}] 决策: opt={opt} ({options[opt]}) 理由={why} dry_run={self.cfg['dry_run']}")
        if self.cfg["dry_run"]:
            self.pending = {"stem": stem, "opt": opt, "n": n}
            return
        delay = self.cfg.get("answer_delay_ms", 500) / 1000.0
        if delay > 0:
            time.sleep(delay)
        self.send_cmd({"cmd": "answer", "qno": qno, "opt": opt})
        self.pending = {"stem": stem, "opt": opt, "n": n}
        log(f"[pid {self.pid}] 已发送答案 qno={qno} opt={opt}")

    def on_sys(self, ev):
        text = ev.get("text", "")
        log(f"[pid {self.pid}] 系统提示: {text}")
        if "测试通过" in text and self.pending:
            self.bank.record_right(self.pending["stem"], self.pending["opt"])
            log(f"[pid {self.pid}] ✅ 答对确认，题库存档: {self.pending['stem'][:20]}.. -> opt={self.pending['opt']}")
            self.pending = None


# ---------------- 本机命令端口（8488）----------------
# 外部工具（如 battle_capture.py）连 127.0.0.1:8488 发一行 JSON：
#   {"cmd": {"cmd": "cap_on"}}                 -> 广播给全部客户端
#   {"cmd": {"cmd": "cap_off"}, "pids": [123]} -> 只发给指定 pid
# 控制器原样转发给对应 ClientThread 的管道，回 {"relayed": n}。
import socket

CMD_PORT = 8488


def start_cmd_server(threads_getter):
    def srv():
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind(("127.0.0.1", CMD_PORT))
        except OSError as ex:
            log(f"[CMD] 8488 端口绑定失败: {ex}")
            return
        s.listen(4)
        log(f"[CMD] 命令端口就绪 127.0.0.1:{CMD_PORT}")
        while True:
            try:
                conn, addr = s.accept()
            except OSError:
                break
            threading.Thread(target=cmd_conn, args=(conn, threads_getter),
                             daemon=True).start()

    def cmd_conn(conn, tg):
        conn.settimeout(5)
        buf = b""
        try:
            while True:
                d = conn.recv(4096)
                if not d:
                    break
                buf += d
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    if not line.strip():
                        continue
                    try:
                        req = json.loads(line.decode("utf-8", "replace"))
                    except Exception as ex:
                        conn.sendall((json.dumps({"error": f"bad json: {ex}"}) + "\n").encode())
                        continue
                    cmd = req.get("cmd")
                    pids = req.get("pids")
                    if not isinstance(cmd, dict):
                        conn.sendall(b'{"error":"missing cmd object"}\n')
                        continue
                    n = 0
                    for pid, t in list(tg().items()):
                        if pids and pid not in pids:
                            continue
                        try:
                            if t.is_alive() and t.send_cmd(cmd):
                                n += 1
                        except Exception:
                            pass
                    conn.sendall((json.dumps({"relayed": n, "cmd": cmd}) + "\n").encode())
        except Exception:
            pass
        finally:
            try:
                conn.close()
            except Exception:
                pass

    threading.Thread(target=srv, daemon=True).start()


# ---------------- 自动注入守护 ----------------
INJECTOR_EXE = ROOT / "build" / "injector.exe"


def ensure_injected(pid):
    """自动调用 injector.exe 对目标客户端注入 quizbot_hook.dll（已注入自动跳过）"""
    if not INJECTOR_EXE.exists():
        log(f"[INJECT] 注入器文件不存在: {INJECTOR_EXE}")
        return False
    try:
        res = subprocess.run([str(INJECTOR_EXE), "--pid", str(pid)],
                             capture_output=True, text=True, timeout=10)
        out = (res.stdout or "") + (res.stderr or "")
        if "already injected" in out:
            return True
        elif "INJECTED" in out:
            log(f"[+] [pid {pid}] 自动注入 quizbot_hook.dll 成功！")
            return True
        else:
            log(f"[!] [pid {pid}] 注入器反馈: {out.strip()}")
            return False
    except Exception as e:
        log(f"[!] [pid {pid}] 注入异常: {e}")
        return False


# ---------------- 主循环 ----------------
def main():
    force_dry = "--dry" in sys.argv
    cfg = load_config()
    if force_dry:
        cfg["dry_run"] = True
    bank_path = ROOT / cfg.get("bank_path", "data/bank.json")
    bank = Bank(bank_path)
    llm = LLM(cfg.get("llm", {}), cfg.get("llm_cache_s", 3600))
    log(f"============================================================")
    log(f"大冒险2 自动答题机器人 (纯网络层·多开自动检测注入守护版)")
    log(f"工作模式: 纯网络层收发协议 (零弹窗拦截、零UI点击、纯静默秒答)")
    log(f"配置状态: dry_run={cfg['dry_run']} | 题库题数={len(bank.data)} | LLM启用={cfg.get('llm', {}).get('enabled', False)}")
    log(f"============================================================")
    threads = {}

    def scan():
        injected_pids = set()
        last_count = -1
        while True:
            now = time.time()
            all_pids = set(find_pids())

            # 1. 监控客户端增减变化
            if len(all_pids) != last_count:
                log(f"[*] 守护状态: 当前在线客户端 = {len(all_pids)} 个: {sorted(list(all_pids))}")
                last_count = len(all_pids)

            # 2. 清理已关闭的客户端
            for p in list(injected_pids):
                if p not in all_pids:
                    injected_pids.remove(p)
                    if p in threads:
                        threads.pop(p, None)
                    log(f"[-] 客户端 [pid {p}] 已关闭，清理会话")

            # 3. 遍历检测并自动注入、建立答题管道
            for pid in all_pids:
                if pid not in injected_pids:
                    log(f"[*] 检测到客户端 [pid {pid}]，准备自动注入...")
                    if ensure_injected(pid):
                        injected_pids.add(pid)
                        time.sleep(0.3)  # 给 DLL 初始化管道留出缓冲

                t = threads.get(pid)
                if t is None:
                    t = ClientThread(pid, cfg, bank, llm)
                    t.start()
                    threads[pid] = t
                elif not t.is_alive() and not t.alive:
                    # 线程若意外断开，冷却 4 秒后重试连接
                    if now - getattr(t, "ended_ts", 0) < 4:
                        continue
                    t = ClientThread(pid, cfg, bank, llm)
                    t.start()
                    threads[pid] = t

            time.sleep(2)

    start_cmd_server(lambda: threads)
    try:
        scan()
    except KeyboardInterrupt:
        log("控制器退出")


if __name__ == "__main__":
    main()
