# 大冒险2 自动答题系统（quizbot）

基于交接包（`quizbot_handover/`，2026-10-01）的协议逆向定论实现的常驻被动自动答题系统。
支持 5~10 客户端多开，不模拟任何物理键鼠，全部进程内完成。

## 架构

```
WAATClient.exe × N（每个注入一份 32 位 DLL）
  quizbot_hook.dll
    ├─ IAT hook ws2_32: recv(#16) / send(#19) / WSASend / connect(#4) / closesocket(#3)
    ├─ 运行时读编解码表（模块基址+0x515D6C/0x515D94，自适应客户端版本）
    ├─ 流式分帧 → op==0x46F4 解码题目 → GBK→UTF-8
    ├─ connect 按端口 8484 识别主连接；收到题的 socket 即主连接（双保险）
    └─ 命名管道 \\.\pipe\quizbot_<pid>：
         事件(上行): question / sys / currency / sent / sendfail / init / pong / stats
         命令(下行): {"cmd":"answer","qno":16,"opt":2} / ping / stats

controller/quizbot.py（机器级，1 进程管全部客户端）
  ├─ 自动扫描进程并连接所有管道（新开客户端自动接入）
  ├─ 答题引擎：题库 bank.json → LLM（OpenAI 兼容接口，可选）→ 排除法兜底
  ├─ 结果回写：0x46FF"测试通过！" = 答对存档；来新题 = 答错记排除项
  └─ dry_run：只决策不发包
```

## 文件说明

| 路径 | 说明 |
|---|---|
| `dll/quiz_protocol.h` | 传输层协议纯函数（分帧/编解码/题目解析/构答案包），与测试共享 |
| `dll/quizbot_hook.cpp` | hook DLL 全量实现 |
| `injector/injector.cpp` | 注入器（枚举+补注入，`-w` 常驻监视） |
| `controller/quizbot.py` | 控制器+答题引擎 |
| `controller/config.json` | 运行配置（首次运行自动生成） |
| `data/bank.json` | 题库（自动积累；已预置交接包实测两题） |
| `tools/m0_check.py` | M0 环境验证：从游戏内存读表比对 |
| `tools/protocol_test.cpp` | 离线回放测试（7 条实抓封包基准） |
| `build.sh` | 一键构建（需先放好工具链，见下） |

## 使用步骤

```bash
# 0) 一次性：把 MinGW-w64 i686 工具链放到 toolchain/mingw.7z（build.sh 自动解压）
#    或自行安装 MSVC x86 / 任意 i686 g++，改 build.sh 里的编译器路径

# 1) 构建 + 协议回放测试（应输出 ALL TESTS PASSED）
bash build.sh

# 2) 环境验证（游戏需已登录）
python tools/m0_check.py        # 应 10 进程全部 PASS

# 3) 注入全部客户端（管理员权限更稳）
build/injector.exe              # 一次性；  build/injector.exe -w 常驻补注入
# 注入后看 logs/quizbot_<pid>.log 应有 "[INIT] codec loaded OK" + iat hooks 全 1

# 4) 启动控制器（先用 dry_run 观察！config.json 里 dry_run 默认 true）
python controller/quizbot.py    # 强制只读观察加 --dry

# 5) 确认决策正常后，把 config.json 的 dry_run 改 false，等答题活动弹出即全自动。
```

## 配置（controller/config.json）

```jsonc
{
  "dry_run": true,            // true=只决策不发包
  "answer_delay_ms": 500,     // 收到题到发包的延迟（0=秒答）
  "fallback": "eliminate",    // LLM 不可用时策略: eliminate|first|random|llm_only
  "llm": {                    // OpenAI 兼容接口；留空 disabled
    "enabled": false, "endpoint": "", "api_key": "", "model": ""
  }
}
```

## 已实现里程碑

- **M0 环境验证** ✅：protocol.py 自检 2 PASS；7 条实抓封包解出全文；10 进程内存读表全部双射、与参考表一致
- **M1 被动解码** ✅：DLL 注入 + recv hook + 流式分帧 + 题目实时解码落日志
- **M2 答题引擎** ✅：题库自动积累 + LLM 兜底 + 排除法 + dry_run + 结果回写
- **M3 主动发包** ✅：SendQuizAnswer 经 IAT 记录的主连接 socket 发 0x1F04（构包逻辑已逐字节对齐实抓）
- **M4 多开整合** ✅：每进程独立管道 + 控制器统一调度 + 题库共享

## 与交接包差异 / 修正

1. **交接包 `read_codec_from_memory.py` 的 PROCESSENTRY32 定义有 bug**（缺字段，64 位 Python 下
   Process32First 报错 24，从未跑通）——已在 `tools/m0_check.py` 修正。
2. 实测进程名为 `WAATClient.exe`（非 README 写的 WaatClient.exe，Windows 不区分大小写，无碍）。
3. 客户端为 WSAEventSelect 异步模型，静态导入 WS2_32.dll（recv 按序号 #16 导入）——
   IAT hook 按地址匹配定位，序号/名称导入通吃，无需 MinHook。
4. DLL 不用 std::mutex/std::thread（win32 线程模型 MinGW 无 gthreads），改 CRITICAL_SECTION+CreateThread。
5. 主连接识别三重保险：connect 端口 8484 / 非心跳发送流量 / 收到题目包的 socket 本身。

## 关键坑备忘（来自交接包，实现均已规避）

- recv 块 ≠ 消息：每 socket 流式缓冲，`length=~inv` 校验切帧，坏帧重置缓冲
- S→C 用 decode 表，C→S 用 encode 表，帧头 4B 明文不过表
- 每条消息表轮换独立从自己的 (op,inv) 算起始号，不跨消息累计
- 答案 0-based（"N、" 的 N-1），明文 `[5:i32][题号:i32][选项u8]`
- GBK 编码；答案必须走 8484 主连接；别碰物理键鼠
