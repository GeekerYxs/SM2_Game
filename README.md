# SM2_Game — 什么什么大冒险2 游戏自动化与辅助系统

本仓库整合了《什么什么大冒险2.0》的客户端逆向分析、AI 战斗策略引擎、纯净地图巡逻系统以及纯网络层自动答题机器人（quizbot）。供代码审计、功能维护与二次开发使用。

---

## 目录结构索引

### 1. 独立纯净地图巡逻系统 (`src/` & `tools/`) [★ 新增重点]
彻底解耦官方 F12 挂机脚本（消除了强制普攻对 AI 战术的劫持冲突），实现战外智能巡逻与战内 AI 决策 100% 隔离：
- **`src/map_patrol.lua`**: 纯 Lua 地图巡逻引擎（支持就地定点 `AutoAnchor`、自定义两点坐标 `Custom`、队长双策略自省 `Leader Introspection`、战外全员极速补血哨兵与战斗态 0ms 挂起）。
- **`tools/PatrolDashboard.ps1`**: 巡逻中控台（实时监控 5 客户端战况、地图编号、当前站位、坐标航线，提供一键启停/定点/自定义坐标/切队长等操作）。
- **`tools/SetPatrolPoints.ps1`**: 自定义巡逻坐标配置器（支持命令行直接传参或交互式分步录入 A 点与 B 点共 4 个坐标数字）。
- **`tools/TogglePatrol.ps1`**: 巡逻控制核心调度脚本（下发 START / STOP / ANCHOR / CUSTOM 指令）。
- **`打开巡逻中控台.bat` / `设置巡逻坐标.bat` / `开启巡逻.bat` / `关闭巡逻.bat` / `就地重新定点.bat`**: 根目录与工具目录一键批处理。
- **[`AUTO_PATROL_HANDOVER_GUIDE.md`](AUTO_PATROL_HANDOVER_GUIDE.md)**: **【必读】独立地图巡逻系统交接手册与架构审计指南**（包含深度排障踩坑经验、数据分析与开发规约）。

### 2. 战斗 AI 策略引擎 (`src/` & `tools/`) [★ 核心业务]
基于游戏内置 Lua 虚拟机的多智能体协同战斗状态机：
- **[`COMBAT_AI_STRATEGY_GUIDE.md`](COMBAT_AI_STRATEGY_GUIDE.md)**: **【必读】战斗 AI 策略与挂机协同系统交接指南**（详尽阐述 3带2 阵容画像、死人全员停火绝对复活协议、小号彻底存 SP 待命策略、黑板协议与调试排障）。
- **`src/ai_fight_strategy.lua`**: 核心战斗决策逻辑（动态能力自省、全员停火抢救、小号极致存SP待命、分布式黑板通信等）。
- **`src/auto_fight.lua`**: 自动遇敌与战斗托管调度主入口。
- **`sync.ps1`**: 核心热更新同步工具（一键全盘扫描并同步至所有游戏安装目录）。
- **`tools/`**: 战斗数据捕获、技能与数据表逆向提取工具。
- **`battle_history/`**: 历史实战战绩与结算样本库（`battle_records.jsonl`）。
- **`extracted_luas/` & `official_luas/`**: 从客户端解出的官方脚本源码与参考实现。
- **`GameLuaRegister_API_Manual.md`**: 客户端导出的 C++ 到 Lua 原生 API 手册。
- **`AI战斗策略引擎与实装报告.md`**: 战斗引擎实装与验证文档。

### 3. 自动答题子系统 (`quizbot/`)
针对游戏定期弹出的答题活动开发的进程内网络层静默答题机器人：
- **`quizbot/dll/quizbot_hook.cpp`**: 32 位 IAT Hook DLL（Hook `ws2_32.dll` 的 `recv`、`send`、`WSASend`、`connect`、`closesocket`，进行明文协议嗅探与答案封包注入；100% 原始透传，不拦截弹窗、不修改界面渲染、不抢焦点）。
- **`quizbot/dll/quiz_protocol.h`**: 传输层协议定义（S2C/C2S 置换表双向编解码、0x46F4 题目明文解构、0x1F04 答案数据包构造）。
- **`quizbot/injector/injector.cpp`**: 32 位 DLL 注入器，支持指定 PID 注入与多开检测。
- **`quizbot/controller/quizbot.py`**: 机器级 Python 控制中心（命名管道双向通信、多客户端动态监控与自动注入、题库检索与 LLM 调用、排除法兜底）。
- **`quizbot/controller/config.json`**: 控制器配置文件（LLM 配置、题库路径、答题延迟等）。
- **`quizbot/data/bank.json`**: 累积沉淀的答题题库（包含已确认正确答案、历史选项与错误排除项）。
- **`quizbot/logs/`**: 历史战斗结算账本（`settle_*.csv`）、运行日志（`controller.log`）及逆向封包解析报告。
- **`quizbot/tools/`**: 离线测试与协议验证工具（`protocol_test.cpp` 包含 38 项基准断言测试）。
- **`启动自动答题.bat`**: 外部一键总开关（双击运行，自动守护并注入所有现有及后续新开的游戏窗口）。

---

## 快速上手与运行

### 1. 自动巡逻与战斗 AI
1. **一键打开巡逻中控台**：双击根目录或 `tools/` 下的 `打开巡逻中控台.bat`。
2. **设置自定义两点坐标**：双击 `设置巡逻坐标.bat`（分步输入 A 点和 B 点共 4 个坐标数字），或直接传参：
   ```cmd
   设置巡逻坐标.bat 1200 800 1360 800
   ```
3. **极速启停**：双击 `开启巡逻.bat`、`关闭巡逻.bat` 或 `就地重新定点.bat`。
4. **一键代码同步发布**：在修改 `src/` 或工具代码后，执行 `sync.ps1` 即可将最新代码秒级同步至所有游戏安装目录：
   ```powershell
   powershell -ExecutionPolicy Bypass -File sync.ps1
   ```

### 2. 自动答题运行
- 双击根目录下的 `启动自动答题.bat` 即可作为外部总开关运行，自动检测并注入已开或新开的游戏窗口。
- 源码构建依赖 MinGW-w64 32位编译器（i686），执行 `quizbot/build.sh` 即可生成 32 位 DLL 与注入器。

---

## 核心文档索引
- **[`UNIVERSAL_COMBAT_AI_ARCHITECTURE_SPEC.md`](UNIVERSAL_COMBAT_AI_ARCHITECTURE_SPEC.md)**：【必读】全场景通用战斗 AI 架构规范与客户端逆向工程报告（涵盖全职业/单人/小队/5人遥测审计与隐匿死循环解决证据）
- **[`COMBAT_AI_STRATEGY_GUIDE.md`](COMBAT_AI_STRATEGY_GUIDE.md)**：战斗 AI 策略与挂机协同系统交接指南
- **[`AUTO_PATROL_HANDOVER_GUIDE.md`](AUTO_PATROL_HANDOVER_GUIDE.md)**：独立地图巡逻系统交接手册与架构审计指南（新 Agent 必读）
- **[`AI_AGENT_GUIDE.md`](AI_AGENT_GUIDE.md)**：AI 协同开发与代码审计权威指南
- **[`GameLuaRegister_API_Manual.md`](GameLuaRegister_API_Manual.md)**：客户端 C++ 导出原生 API 手册
