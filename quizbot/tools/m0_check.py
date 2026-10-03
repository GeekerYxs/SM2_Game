# -*- coding: utf-8 -*-
"""M0 环境验证：从运行中的 WAATClient.exe 进程内存读取编解码表。

修正交接包原版脚本的两处问题：
1. PROCESSENTRY32 结构体定义错误（缺少 th32DefaultHeapID/cntThreads 等字段，
   导致 64 位 Python 下 Process32First 报错 24，原脚本从未跑通过）
2. 进程名默认改为实测的 WAATClient.exe

用法：python m0_check.py [进程名，默认 WAATClient.exe]
"""
import ctypes
import ctypes.wintypes as wt
import json
import struct
import sys
from pathlib import Path

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
RVA_ENCODE, RVA_DECODE = 0x515D6C, 0x515D94
PROCESS_VM_READ = 0x10
PROCESS_QUERY_INFORMATION = 0x400
TH32CS_SNAPPROCESS = 2
TH32CS_SNAPMODULE = 8
TH32CS_SNAPMODULE32 = 0x10
MAX_PATH = 260


class PROCESSENTRY32(ctypes.Structure):
    _fields_ = [
        ("dwSize", wt.DWORD),
        ("cntUsage", wt.DWORD),
        ("th32ProcessID", wt.DWORD),
        ("th32DefaultHeapID", ctypes.POINTER(wt.ULONG)),  # ULONG_PTR, 指针宽度
        ("th32ModuleID", wt.DWORD),
        ("cntThreads", wt.DWORD),
        ("th32ParentProcessID", wt.DWORD),
        ("pcPriClassBase", wt.LONG),
        ("dwFlags", wt.DWORD),
        ("szExeFile", ctypes.c_char * MAX_PATH),
    ]


class MODULEENTRY32(ctypes.Structure):
    _fields_ = [
        ("dwSize", wt.DWORD),
        ("th32ModuleID", wt.DWORD),
        ("th32ProcessID", wt.DWORD),
        ("GlblcntUsage", wt.DWORD),
        ("ProccntUsage", wt.DWORD),
        ("modBaseAddr", ctypes.c_void_p),
        ("modBaseSize", wt.DWORD),
        ("hModule", wt.HMODULE),
        ("szModule", ctypes.c_char * 256),
        ("szExePath", ctypes.c_char * MAX_PATH),
    ]


def iter_pids(name: str):
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    e = PROCESSENTRY32(); e.dwSize = ctypes.sizeof(e)
    ok = k32.Process32First(snap, ctypes.byref(e))
    while ok:
        if e.szExeFile.decode("mbcs", "ignore").lower() == name.lower():
            yield e.th32ProcessID
        ok = k32.Process32Next(snap, ctypes.byref(e))
    k32.CloseHandle(snap)


def module_base(pid: int, name: str):
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, pid)
    if snap in (0, -1):
        return None
    m = MODULEENTRY32(); m.dwSize = ctypes.sizeof(m)
    base = None
    ok = k32.Module32First(snap, ctypes.byref(m))
    while ok:
        if m.szModule.decode("mbcs", "ignore").lower() == name.lower():
            base = m.modBaseAddr
            break
        ok = k32.Module32Next(snap, ctypes.byref(m))
    k32.CloseHandle(snap)
    return base


def rpm(h, addr, size):
    buf = ctypes.create_string_buffer(size)
    got = ctypes.c_size_t()
    if not k32.ReadProcessMemory(h, ctypes.c_void_p(addr), buf, size, ctypes.byref(got)):
        return None
    return buf.raw[:got.value]


def read_tables(h, base, rva):
    ptrs_raw = rpm(h, base + rva, 40)
    if ptrs_raw is None or len(ptrs_raw) != 40:
        return None
    tables = []
    for i in range(10):
        p = struct.unpack_from("<I", ptrs_raw, i * 4)[0]
        t = rpm(h, p, 256)
        if t is None or len(t) != 256:
            return None
        tables.append(t)
    return tables


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "WAATClient.exe"
    pids = list(iter_pids(name))
    if not pids:
        print(f"未找到进程 {name}")
        return 1
    print(f"找到 {len(pids)} 个 {name} 进程: {pids}")
    ref = json.loads((Path(__file__).parent.parent / "codec" / "codec_tables.json").read_text(encoding="utf-8"))
    ref_enc = [bytes.fromhex(t) for t in ref["encode"]]
    ref_dec = [bytes.fromhex(t) for t in ref["decode"]]
    all_ok = True
    for pid in pids:
        base = module_base(pid, name)
        if base is None:
            print(f"[pid {pid}] 找不到模块基址，跳过")
            all_ok = False
            continue
        h = k32.OpenProcess(PROCESS_VM_READ | PROCESS_QUERY_INFORMATION, False, pid)
        if not h:
            print(f"[pid {pid}] OpenProcess 失败 err={ctypes.get_last_error()}")
            all_ok = False
            continue
        enc = read_tables(h, base, RVA_ENCODE)
        dec = read_tables(h, base, RVA_DECODE)
        k32.CloseHandle(h)
        if enc is None or dec is None:
            print(f"[pid {pid}] base=0x{base:X} 读表失败（客户端版本不同？RVA 变了？）")
            all_ok = False
            continue
        bij_enc = all(len(set(t)) == 256 for t in enc)
        bij_dec = all(len(set(t)) == 256 for t in dec)
        same = enc == ref_enc and dec == ref_dec
        print(f"[pid {pid}] base=0x{base:X} encode双射={bij_enc} decode双射={bij_dec} 与参考表一致={same}")
        if not same:
            out = Path(__file__).parent.parent / "codec" / f"dump_{pid}_codec.json"
            out.write_text(json.dumps({
                "pid": pid, "module_base": hex(base),
                "encode": [t.hex() for t in enc], "decode": [t.hex() for t in dec],
                "matches_reference": False,
            }, indent=2), encoding="utf-8")
            print(f"          表不同！已导出 {out}（离线分析需用本机表）")
        if not (bij_enc and bij_dec):
            all_ok = False
    print("\nM0 结果:", "PASS — 全部进程表读取成功且双射校验通过" if all_ok else "有进程异常，见上")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
