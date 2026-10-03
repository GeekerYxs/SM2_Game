"""向指定客户端的 DLL 管道发送命令。

用法:
    python send_cmd.py <pid> <cmd-json>        # 例: send_cmd.py 10496 {"cmd":"windump"}
    python send_cmd.py <pid> <cmd-json> <wait> # wait=读响应秒数, 0 不读
"""
import ctypes
import json
import sys
import time

k32 = ctypes.WinDLL("kernel32", use_last_error=True)


def main():
    pid = int(sys.argv[1])
    payload = sys.argv[2].encode("utf-8") + b"\n"
    wait = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0
    name = ("\\\\.\\pipe\\quizbot_%d" % pid).encode()
    h = k32.CreateFileA(name, 0xC0000000, 0, None, 3, 0, None)
    if h in (0, -1) or h is None:
        print(f"[pid {pid}] pipe unavailable err={ctypes.get_last_error()}")
        sys.exit(2)
    n = ctypes.c_uint32(0)
    ok = k32.WriteFile(h, payload, len(payload), ctypes.byref(n), None)
    print(f"[pid {pid}] sent {n.value}B ok={ok}: {sys.argv[2]}")
    # 读响应
    t0 = time.time()
    while time.time() - t0 < wait:
        avail = ctypes.c_uint32(0)
        if k32.PeekNamedPipe(h, None, 0, None, ctypes.byref(avail), None) and avail.value:
            buf = ctypes.create_string_buffer(8192)
            got = ctypes.c_uint32(0)
            k32.ReadFile(h, buf, min(avail.value, 8192), ctypes.byref(got), None)
            for line in buf.raw[: got.value].split(b"\n"):
                if line.strip():
                    try:
                        print(f"[pid {pid}] <<", json.dumps(
                            json.loads(line.decode("utf-8", "replace")), ensure_ascii=False))
                    except Exception:
                        print(f"[pid {pid}] <<", line)
        time.sleep(0.1)
    k32.CloseHandle(h)


if __name__ == "__main__":
    main()
