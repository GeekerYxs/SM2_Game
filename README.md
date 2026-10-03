# SM2_Game — 什么什么大冒险2 游戏自动化与辅助系统

本仓库整合了《什么什么大冒险2.0》的客户端逆向分析、AI 战斗策略引擎以及纯网络层自动答题机器人（quizbot）。供代码审计、功能维护与二次开发使用。

---

## 目录结构索引

### 1. 自动答题子系统 (`quizbot/`)
针对游戏定期弹出的答题活动开发的进程内网络层静默答题机器人：
- **`quizbot/dll/quizbot_hook.cpp`**: 32 位 IAT Hook DLL（Hook `ws2_32.dll` 的 `recv`、`send`、`WSASend`、`connect`、`closesocket`，进行明文协议嗅探与答案封包注入；100% 原始透传，不拦截弹窗、不修改界面渲染、不抢焦点）。
- **`quizbot/dll/quiz_protocol.h`**: 传输层协议定义（S2C/C2S 置换表双向编解码、0x46F4 题目明文解构、0x1F04 答案数据包构造）。
- **`quizbot/injector/injector.cpp`**: 32 位 DLL 注入器，支持指定 PID 注入与多开检测。
- **`quizbot/controller/quizbot.py`**: 机器级 Python 控制中心（命名管道双向通信、多客户端动态监控与自动注入、题库检索与 LLM 调用、排除法兜底）。
- **`quizbot/controller/config.json`**: 控制器配置文件（LLM 配置、题库路径、答题延迟等）。
- **`quizbot/data/bank.json`**: 累积沉淀的答题题库（包含已确认正确答案、历史选项与错误排除项）。
- **`quizbot/logs/`**: 历史战斗结算账本（`settle_*.csv`）、运行日志（`controller.log`）及逆向封包解析报告。
- **`quizbot/tools/`**: 离线测试与协议验证工具（`protocol_test.cpp` 包含 38 项基准断言测试）。
- **`quizbot/启动自动答题.bat`**: 外部一键总开关（GBK 编码，双击运行，自动守护并注入所有现有及后续新开的游戏窗口）。

### 2. 战斗 AI 策略引擎 (`src/` & `tools/`)
基于游戏内置 Lua 虚拟机的全自动战斗策略与状态机：
- **`src/ai_fight_strategy.lua`**: 核心战斗决策逻辑（技能优先释放、补血吃药、逃跑保护等）。
- **`src/auto_fight.lua`**: 自动遇敌与战斗托管入口。
- **`tools/`**: 战斗数据捕获、技能与数据表逆向提取工具。
- **`battle_history/`**: 历史实战战绩与结算样本库（`battle_records.jsonl`）。
- **`extracted_luas/` & `official_luas/`**: 从客户端解出的官方脚本源码与参考实现。
- **`GameLuaRegister_API_Manual.md`**: 客户端导出的 C++ 到 Lua 原生 API 手册。
- **`AI战斗策略引擎与实装报告.md`**: 战斗引擎实装与验证文档。

---

## 快速上手与运行

### 自动答题运行
进入 `quizbot/` 目录：
1. **直接启动**：双击 `启动自动答题.bat` 即可作为外部总开关运行，自动检测并注入已开或新开的游戏窗口。
2. **源码构建**：
   - 依赖 MinGW-w64 32位编译器（i686）。
   - 执行 `build.sh` 即可生成 `build/quizbot_hook.dll` 与 `build/injector.exe`。
