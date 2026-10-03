# -*- coding: utf-8 -*-
import sys
import time
import subprocess
from pathlib import Path

# Windows 终端 UTF-8
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

PYTHON_EXE = sys.executable

def main():
    target_count = 10  # 先快速跑到10场观察中短期表现，若足够快则跑满20场
    print(f"[*] 开始自动化监听 B 组连珠箭策略实战数据...")
    
    start_time = time.time()
    while True:
        res = subprocess.run([PYTHON_EXE, "tools/ab_test_tracker.py", "collect_b"], capture_output=True, text=True, encoding="utf-8", errors="ignore")
        output = res.stdout
        
        # 提取当前场次
        for line in output.splitlines():
            if "目前已完成战斗:" in line:
                print(f"[{time.strftime('%H:%M:%S')}] {line.strip()}")
            if "平均单场耗时:" in line or "1回合清屏率" in line:
                print(f"    {line.strip()}")
            if "A/B 对照实验最终效能PK报告" in line:
                print("\n" + output)
                return
        
        time.sleep(20)
        # 最多跑 400 秒 (约 6 分钟)
        if time.time() - start_time > 400:
            print("[*] 已达到本次采集时间窗口上限，输出阶段性对比成果...")
            print(output)
            break

if __name__ == "__main__":
    main()
