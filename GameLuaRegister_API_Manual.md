# 游戏方法（Lua 接口手册）

本文档是 C++ 客户端（`WAATClient`）通过 `LuaPlus` 暴露给 Lua 脚本的**全部**接口的权威参考。注册逻辑见 `Source/apps/WAATClient/GameLuaRegister.cpp`，回调入口见 `Source/apps/WAATClient/GameLua.cpp`（仅供溯源，日常开发不再需要打开它们）。

文件约定：
- **位置标记**：参数类型 `int/DWORD/LONGLONG` 在 Lua 侧统一为 `number`；`const char*` / `std::string` 统一为 `string`；`bool` 为 `boolean`；指针返回值（`XXX*`）在 Lua 侧表现为对应的 metatable 对象，无对应时为 `nil`。
- **类继承**：UI 控件类的方法可以继承自 `wsWndBase`（基础窗口）或 `wsDialogBase`（继承 `wsWndBase`），用 *(继承)* 标记。
- 调用方式：实例方法用冒号 `obj:Method(args)`，类静态方法（仅 `CSendPacket`）以模块方式注册到顶层，用点号 `CSendPacket.Method(args)`；属性用 `obj.Name`。

---

## 1. 启动与生命周期

### 1.1 加载顺序

`CGameLua::Initial(luaFilename)` 在客户端启动时被调用一次：
1. 创建 `LuaState`，注册所有 C++ 类/方法（`GameLuaRegister::RegisterAll`）。
2. 把 `GameForLua` 实例绑定到全局变量 `game`。
3. 优先加载 `<luaFilename>.out`（编译后字节码），失败则加载 `<luaFilename>.lua`。
4. 调用 Lua 全局函数 `GameStart()`（如有）。

`CGameLua::Reload()`：销毁并重建整个 `LuaState`，重新注册接口，重新加载文件，再调用 `GameStart()`，最后调用 `OnReload()` 通知脚本。

### 1.2 全局函数（C++ → Lua 回调）

C++ 通过 `LuaState::GetGlobal(funcName)` 找到这些**顶层全局函数**并调用。Lua 侧只要定义同名全局函数即可被回调；未定义时 C++ 会记一条 `level=50` 的日志后忽略。

| 函数名 | 触发时机 | 参数（Lua 侧签名） | 返回值 |
| --- | --- | --- | --- |
| `GameStart` | 脚本初次加载、Reload 完毕 | 无 | 无 |
| `OnGameLogin` | 玩家登录完成 | 无 | 无 |
| `OnGameLogout` | 玩家下线 | 无 | 无 |
| `OnReload` | `CGameLua::Reload()` 末尾 | 无 | 无 |
| `OnCheatConfigLoaded` | 内挂配置从服务器拉取并解码完成 | 无 | 无 |
| `OnGameUpdate` | 每帧（仅当 `m_pGameData->GetGamePlayer()->m_dwID != 0` 即已入场后） | 无 | 无 |
| `OnButtonClicked` | UI 按钮被点击 | `(wndname:string, btnId:number)` | 无 |
| `OnShowUIWindow` | UI 窗口显示/隐藏 | `(wndname:string, bShow:boolean)` | 无 |
| `OnNpcTradeSale` | 打开 NPC 摆摊售卖界面 | 无 | 无 |
| `OnRequestJoinTeam` | 收到组队申请 | `(playerID:number)` | 无 |
| `OnShowDialog` | 收到 NPC 对话框包 | `(content:string, opts:table<int,string>)`（`opts` 索引从 0 开始） | 无 |
| `OnEnterFight` | 进入战斗（场景切换完成前） | 无 | 无 |
| `OnBeginFight` | 战斗实际开始（可操作回合开始） | 无 | 无 |
| `OnLeaveFight` | 离开战斗 | 无 | 无 |
| `OnUpdateMapBuff` | 地图 buff 状态更新 | `(buffs:table)`，结构见下文 | 无 |
| `OnUpdateArtifact` | 奇物状态更新 | 无 | 无 |
| `OnCallScript` | 服务器主动推送 ScriptObj | `(eventId:number, obj:table)` | 无 |
| `OnOpenInputDlg` | 打开输入对话框（C++ 发起） | `(inputType:number, title:string)` | 无 |
| `OnCreateAllUI` | UI 系统初始化时创建所有 Lua 对话框 | `(dlgMgr:CUILuaDlgMgr)` | 无 |
| `OnFreeAllUI` | UI 系统释放所有 Lua 对话框 | `(dlgMgr:CUILuaDlgMgr)` | 无 |
| `OnLuaQuantDlgOK` | 量化输入对话框点击确定 | `(quant:number)` | 无 |
| `OnLuaQuantDlgCancel` | 量化输入对话框点击取消 | 无 | 无 |
| `OnUIPackage` | 通过 `dlgMgr:HandlePackage(pkgType)` 注册的数据包到达 | `(pkgType:number, stream:bsBufferedStream)` | 无 |
| `OnDlgShow` | 单个对话框显示状态变化 | `(dlg:CUILuaDlg, bShowed:boolean)` | 无 |
| `OnScreenResize` | 对话框因屏幕分辨率改变收到通知 | `(dlg:CUILuaDlg, w:number, h:number)` | 无 |
| `OnMove` | 对话框被拖动 | `(dlg:CUILuaDlg, offx:number, offy:number)` | 无 |
| `OnDlgEventProc` | 对话框内控件事件 | `(dlg, eventCode:number, ctrlId:number, ctrl:wsWndBase)` | 无 |
| `OnDlgEscape` | 对话框按下 ESC | `(dlg)` | `boolean`（true=已处理） |
| `OnDlgHandleMessage` | 对话框收到自定义消息 | `(dlg, eventCode:number, param1:number, lParam:number)` | `boolean` |
| `OnUpdateItemBar` | 物品栏整体刷新 | `(dlgMgr:CUILuaDlgMgr)` | 无 |
| `OnUpdateItemCount` | 物品数量变化 | `(dlgMgr:CUILuaDlgMgr)` | 无 |
| `OnUpdateMoney` | 金币变化 | `(dlgMgr:CUILuaDlgMgr)` | 无 |
| `OnUpdateGodhoodExp` | 神识（神格经验）变化 | `(dlgMgr:CUILuaDlgMgr)` | 无 |
| `GetScrollVMaxLen` | 计算垂直滚动条最大长度 | `(dlg, listener:IScrollVListener)` | `number` |
| `GetScrollVPageLen` | 计算页长 | `(dlg, listener)` | `number` |
| `SetScrollVStart` | 设置滚动起点 | `(dlg, listener, v:number)` | 无 |
| `GetScrollVCurrent` | 获取当前滚动位置 | `(dlg, listener)` | `number` |
| `OnRequestSpecialRecordPet` | 宠物图鉴特殊收录请求确认 | `(curIndex:number, index:number, petId:number)` | 无 |
| `EncodeCheatScriptGeneralConfig` | C++ 保存内挂通用配置时调用，要求脚本返回 JSON 字符串 | `(data:CUIDataCheatingScript)` | `string` |
| `DecodeCheatScriptGeneralConfig` | C++ 加载内挂通用配置时调用，把 JSON 还原到 `data` 上 | `(jsonStr:string, data:CUIDataCheatingScript)` | 无 |
| `EncodeCheatScriptFightConfig` | 同上，战斗配置 | `(data:CUIDataCheatingScript)` | `string` |
| `DecodeCheatScriptFightConfig` | 同上 | `(jsonStr:string, data:CUIDataCheatingScript)` | 无 |

#### `OnUpdateMapBuff` 的 `buffs` 结构

```lua
buffs = {
    [buffId] = {
        buffId   = number, -- DWORD
        time     = number, -- 剩余时间
        isOpen   = boolean,
        isEnable = number, -- byte 0/1
        props    = { [propId] = value, ... },
    },
    ...
}
```

### 1.3 `OnCallScript` 的协议数据格式

`game:SendCallScriptPacket(eventId, data)`（C2S）和服务器侧 `SendScriptObj`（S2C）使用**同一种二进制编码**对 Lua table 进行打包，相互可逆。`CGameLua::ConstructParamBuff` / `ParseParamBuff` 实现：

| 类型字节 | 类型 | 后续数据 |
| --- | --- | --- |
| `1` | number（lua_Number / double） | 8 字节 IEEE-754 double |
| `2` | integer（int32） | 4 字节有符号小端 |
| `3` | boolean | 1 字节 0/1 |
| `4` | string | `uint16` 长度（含 `\0`）+ 原始字节（按 GBK 走线） |
| `5` | table（开始） | 后续是若干 `{indexType, key, value}` 三元组，直到 `indexType=255`（结束标记） |

`indexType`（仅在 `type=5` 内出现）：
- `0` = 键为 string，结构同上面的 string
- `1` = 键为 int32（4 字节）
- `255` = 表结束

string 数据按 NUL 结尾的原始字节传输——脚本侧不要塞 UTF-8 中文，按 GBK 来。

---

## 2. 全局对象 `game`（`GameForLua` 类）

注册位置：`GameLuaRegister::registerGameForLua`。属性表中 R/W 表示读写权限（默认读写）。

### 2.1 属性

| 属性 | 类型 | R/W | 说明 |
| --- | --- | --- | --- |
| `DEBUG` | `number` | R | 编译时为 `DEBUG` 时为 `TRUE`，否则 `FALSE`。可用于打开调试日志/快捷调试代码。 |

### 2.2 日志与系统提示

| 方法 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `Reportv` | `level:number, msg:string` | 无 | 写入客户端日志窗口。常用等级：`1`=Debug，`10`=Info，`50`=Warn，`100`=Error（同时弹错）。 |
| `ShowMessage` | `msg:string` | 无 | 调用 `wsMessageBoxDlg::ShowMessage`，弹出系统消息框。 |
| `ShowChatMessage` | `msg:string` | 无 | 通过系统频道（`SYSTEM_CHANNEL`）追加到聊天框。 |
| `GetString` | `name:string` | `string` | 通过 `CGETSTRINGBYNAME` 查多语言/资源字符串。 |

### 2.3 玩家与宠物属性查询

宠物相关方法读取**当前出战宠物**（`UIData->GetPet()->GetFightPet()`）；没有出战宠物时返回 0。

| 方法 | 返回 | 说明 |
| --- | --- | --- |
| `GetHp()` | `number` | 主角当前 HP |
| `GetHpMax()` | `number` | 主角 HP 上限 |
| `GetMp()` | `number` | 主角当前 MP |
| `GetMpMax()` | `number` | 主角 MP 上限 |
| `GetPetHp()` | `number` | 出战宠物当前 HP |
| `GetPetHpMax()` | `number` | 出战宠物 HP 上限 |
| `GetPetMp()` | `number` | 出战宠物当前 MP |
| `GetPetMpMax()` | `number` | 出战宠物 MP 上限 |
| `GetPetRp()` | `number` | 出战宠物当前忠诚度（Loyalty） |
| `GetPetRpMax()` | `number` | 出战宠物忠诚度上限 |
| `GetGamePlayer()` | `TGamePlayer` | 主角完整数据对象，见 §10 |
| `GetUIDataItem()` / `UIDataItem()` | `CUIDataItem` | 玩家物品栏数据，见 §6 |

### 2.4 自动回复 / 自动使用辅助物品

下列方法等价于"自动检测背包中存在的对应类型辅助物品并发出使用请求"。**若玩家当前处于战斗/摆摊/交易/银行/修理/NPC 买卖中，会直接返回不发包**。

| 方法 | 内部辅助物品类型 |
| --- | --- |
| `FillHp()` | 1（玩家 HP） |
| `FillMp()` | 2（玩家 MP） |
| `FillPetHp()` | 3（宠物 HP） |
| `FillPetMp()` | 4（宠物 MP） |
| `FillPetRp()` | 5（宠物忠诚度） |

### 2.5 物品操作

| 方法 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `DropItem` | `slot:number, quant:number` | 无 | 发送丢弃物品包，固定带"确认丢弃"标志。 |
| `AddItemSlotToSale` | `slot:number` | 无 | 把背包指定槽加入到 NPC 摆摊售卖窗口的售卖栏。 |
| `ChangePetID` | `petSlot:number, petId:number, newPetId:number` | 无 | 把第 `petSlot` 栏宠物（仅当其当前 `PetID()==petId` 时）的宠物 ID 改为 `newPetId`（宠物幻化/换皮），并刷新宠物基础信息 UI 与场景展示宠。 |
| `GetItemBar()` | — | `table<int, XPlayerItem>` | 主背包内的物品；键是槽号（0 起始），仅包含 `iItemID≠0 且 iFlag==VALID_GAMEUI_DATA` 的槽。 |
| `GetPBankBar(bankIdx)` | `bankIdx:number` | `table<int, XPlayerItem>` 或 无 | 随身仓库第 `bankIdx` 页的物品；键为页内槽号（0 起始），仅含有效物品；`bankIdx` 越界返回无。 |
| `GetItemInfo` | `itemId:number` | `wsItemInfo` 或 `nil` | 通过 `CIDParseTool::ParseSpecifyItemInfo` 取物品静态信息。 |
| `GetEquipInfo` | `equipId:number` | `XEquip` 或 `nil` | 装备静态信息。 |
| `GetCSAutoItem` | `name:string` | `XCSAutoItem` 或 `nil` | 内挂"自动物品"配置项查询。 |
| `ParseSpecifySkill(skillId, level)` | `skillId:number, level:number` | `XSkill` 或 `nil` | 解析指定技能的静态配置（`game` 级快捷入口，等价于 `StaticRes()` 同源查询）；结构字段见 §9.4 `XSkill`。 |
| `ParseSpecifyMagic(magicId, level)` | `magicId:number, level:number` | `XMagic` 或 `nil` | 解析指定法术的静态配置（`game` 级快捷入口）；结构字段见 §9.4 `XMagic`。 |
| `GetItemProps` | `itemId:number` | `table<int, propEntry>` | 物品随机属性条目数组。每条 `propEntry` 结构：`{group, minrate, maxrate, id, value, maxvalue, probatility, type, level}`，含义见 `wsItemPropInfo`。 |
| `GetItemTip` | `itemId:number` | `string` | 通过 `CParseProp` 渲染好的物品 tip 文本（包含颜色码）。 |
| `GetItemTipEx` | `itemId:number, endurance:number, propsTable?:table` | `string` | 寄售订单提示：按调用方传入的"真实耐久 + 属性快照"渲染物品 tip（与 `GetSlotTip` 同走 `ParseCommonItem`）。`endurance` 为打包值＝耐久上限×65536＋当前耐久，≤0 时回退配置耐久；`propsTable` 元素字段为服务端 item_props 口径 `prop_type/prop_id/prop_value/prop_st/prop_times/prop_prob`，可省略。物品不存在时返回 `""`。 |

### 2.6 NPC 与地图

| 方法 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `GetAllNpcObjs()` | — | `(npcs:table<int,bsGameUnit>, names:table<int,string>)` | 返回 2 个表，键均为 npcId。 |
| `MainPlayerObj()` | — | `bsPlayerObj` 或 `nil` | 主玩家场景物体。 |
| `FindPlayerObj` | `playerId:number` | `bsPlayerObj` 或 `nil` | 按玩家 ID 找场景物体。 |
| `FindNpc` | `npcId:number` | `{id, name, x, y}` 或 `nil` | 找指定 NPC 的坐标和名称。 |
| `ClickNpc` | `npcId:number` | 无 | 直接发送 `MSLGP_C_TYPE_NPCHIT`，等价于点击 NPC。 |
| `GetMapID()` | — | `number` | 当前地图 ID。 |
| `GetNextMapConnectPoint` | `fromMap:number, toMap:number` | `(x:number, y:number)` | 用客户端地图导航求下一步路径点（`UIAreaMap::findNextPathPos`）。 |
| `GetPlayerPosition()` | — | `(x:number, y:number)` | 主角的**屏幕**像素坐标（`sx, sy`），不是地图坐标。 |
| `IsMoving()` | — | `boolean` | 主角寻路队列非空时为 true。 |
| `MoveTo` | `x:number, y:number` | `boolean` | 主角寻路到地图坐标 `(x,y)`；返回是否成功发起。 |
| `GetPlayerDir()` | — | `number` | 主角当前朝向 `0~7`（`0`=上，顺时针，与服务端 `PlayerDashRequest.dir` 协议一致）；主玩家对象缺失（未入场等）返回 `-1`。 |
| `IsMapPointBlocked` | `x:number, y:number` | `boolean` | 按坐标查询阻挡：地图像素点 `(x,y)` 为阻挡格或出界（`CPath::IsBarPos` / 地图边界）时返回 `true`。通用接口，方向/距离的组合由脚本自行计算。 |
| `IsLineBlocked` | `x1:number, y1:number, x2:number, y2:number` | `boolean` | 按直线查询阻挡：从 `(x1,y1)` 到 `(x2,y2)` 的直线段（`CPath::IsCellLineThrough`）穿过阻挡格或任一端点出界时返回 `true`。可组合 `IsMapPointBlocked` 实现"给定方向、前方一定距离内是否有阻挡"的预检（突进按钮即如此使用）；服务端仍为权威（errCode=3 兜底）。 |
| `IsPlayerBusy()` | — | `boolean` | 主角是否处于"忙"状态：NPC 对话中、收到玩家交易请求、玩家交易中、NPC 买卖中（引擎级窗口判定）。地图桌面突进按钮等 UI 用它拒绝忙时操作；战斗态由脚本侧 `game_state.isInFight` 一并判定（进/出战斗事件已驱动显隐）。 |

### 2.7 对话与任务

| 方法 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `SelectNpcDialogEntry` | `selectId:number` | `boolean` (始终 true) | 先关闭客户端的模态对话框，再发送 `MSLGP_C_TYPE_SELECTDIALOGENTRY`。 |
| `CloseDialog()` | — | 无 | 关闭客户端的 NPC 对话框（不发包）。 |
| `IsTaskFinished` | `taskId:number` | `boolean` | 查询任务（`UIData->GetTask2()`）是否已完成。 |
| `CheckInstanceLoaded()` | — | 无 | 若任务系统未初始化，触发查询副本任务并循环点位查询。 |
| `ParseInstanceLoopPos` | `taskId:number` | `(x:number, y:number)` 或无 | 从已加载副本任务的 `LoopInfo` 字段（格式 `"……（X，Y）……"`）中解析出坐标。注意使用的是**中文括号和顿号**。 |
| `SetAutoTaskButtonVisibleStatus` | `status:number` | 无 | 设置内挂 UI 自动任务总开关按钮的图像状态：`0`=未开始（开始图），`1`=进行中（暂停图），`2`=暂停（继续图）。 |
| `GetAutoTaskButtonVisibleStatus()` | — | `number` | 同上反向。 |
| `SetAutoTaskItemStatusImage` | `taskId:number, status:number` | 无 | 设置内挂 UI 中单条任务图标状态：`0`=不显示，`1`=进行中，`2`=暂停。 |

### 2.8 技能 / 法术 / 宠物能力查询

下面四组返回 `boolean`。"In CD"通过比较 `bsGetTicks()` 与冷却结束时间得出。

| 方法 | 参数 | 含义 |
| --- | --- | --- |
| `HasSkill(id, level)` | 玩家技能 ID + 等级 | 玩家学会且 `iCurMaxLevel+iLevelModify >= level` |
| `IsSkillInCD(id)` | 玩家技能 ID | 是否还在冷却 |
| `HasMagic(id, level)` | 玩家法术 ID + 等级 | 同上，法术 |
| `IsMagicInCD(id)` | 玩家法术 ID | 同上 |
| `HasFightPetHasAbility(id, level)` | 出战宠物能力 ID + 等级 | 出战宠物拥有该能力 |
| `IsFightPetAbilityInCD(id)` | 出战宠物能力 ID | 是否在冷却 |

### 2.9 技能/法术消耗校验

返回 `boolean`，`false` 表示 HP/MP 不够（仅判断玩家或出战宠物自身的资源，按技能配置的 `ConsumeType` 走）。`ConsumeType` 四种：`MP` / `MPPCT` / `HP` / `HPPCT`。

| 方法 | 参数 |
| --- | --- |
| `IsSatisfySkillConsume(id, level)` | 玩家技能 |
| `IsSatisfyMagicConsume(id, level)` | 玩家法术 |
| `IsSatisfyFightPetSkillConsume(id, level)` | 出战宠物技能 |
| `IsSatisfyFightPetMagicConsume(id, level)` | 出战宠物法术 |

### 2.10 战斗操作

战斗位坐标系：**客户端位 `pos`** 是脚本/UI 用的位置编号；C++ 内部需要通过 `ClientPos2SerPos` 转成服务端位再发包。`MAX_FIGHT_POSITION` 是上限。`pos<0` 在所有出招接口里会被替换为"当前选中目标"（`CFightRecordHitedObj::GetCurHitedObjInfo()`），若也没有则用 `2`（缺省位）。

| 方法 | 参数 | 返回 | 说明 |
| --- | --- | --- | --- |
| `IsPKFight()` | — | `boolean` | 当前是否 PK 战斗 |
| `IsWatchFight()` | — | `boolean` | 当前是否旁观（主角真实位置 < 0） |
| `GetFighter(pos)` | 客户端位 | `TFightNpcData` 或 `nil` | 注意 C++ 内 `pos` 不做 `ClientPos2SerPos` 转换，直接索引 `m_Fighters[pos]`；`pos<0` 或 `pos>=MAX` 或 `type==0xFFFFFFFF` 返回 nil。 |
| `IsFighterCanBeCatch(pos)` | 客户端位 | `boolean` | 该位的战斗者是否可捕捉。 |
| `GetFighterName(pos)` | 客户端位 | `string` 或 `nil` | 战斗者显示名。 |
| `GetFighterLevel(pos)` | 客户端位 | `number` | 战斗者等级（`wGrade`），找不到时 0。 |
| `GetMyPos()` | — | `number` | 主角当前客户端位（`SerPos2ClientPos(LeadingActorRealPos)`）。 |
| `GetMyPetPos()` | — | `number` | 出战宠物当前客户端位。 |
| `IsEnableAutoFight()` | — | `boolean` | UI 上的"自动战斗"复选框是否勾选。 |
| `NormalAttack(target)` | 客户端位 | 无 | 主角普通攻击。`target<0` 取当前选中或缺省位。 |
| `PetNormalAttack(target)` | 客户端位 | 无 | 宠物普通攻击。 |
| `UseItemToFighter(target, slot)` | 目标客户端位, 物品槽 | 无 | 战斗中对目标使用背包指定槽位的物品。 |
| `CastSkillToFighter(target, skillId, level)` | 目标位, 技能 ID/等级 | 无 | 主角对目标施放技能。 |
| `CastMagicToFighter(target, magicId, level)` | 目标位, 法术 ID/等级 | 无 | 主角对目标施放法术。 |
| `CastPetSkillToFighter(target, skillId, level)` | 同上 | 无 | 出战宠物释放技能。 |
| `CastPetMagicToFighter(target, magicId, level)` | 同上 | 无 | 出战宠物释放法术。 |

### 2.11 网络包发送

| 方法 | 参数 | 说明 |
| --- | --- | --- |
| `SendCallScriptPacket` | `eventId:number, data:any` | 通用 ScriptObj 发包（C2S `MSLGP_C_TYPE_CALLSCRIPT`）；`data` 会按 §1.3 的格式编码。 |
| `SendPlayerUseItemPacket` | `slot:number` | 玩家使用背包物品 |
| `SendPlayerUseItemToPlayerPacket` | `slot:number, targetPlayerId:number` | 玩家对其他玩家使用物品 |
| `SendPetUseItemPacket` | `slot:number, petIndex:number` | 宠物使用物品 |
| `SendUseTriggerItemPacket` | `slot:number` | 使用任务触发道具 |
| `SendInputDlgResult` | `content:string` | 提交 C++ 弹出的输入对话框内容（C2S `MSLGP_C_TYPE_SUBMITINPUTDLGRESULT`，最大 1024 字节）。 |
| `SendPackage` | `packetId:number` | 把通过 `PrepareSendBuffer` 写入的缓冲作为该 `packetId` 的包发出。 |
| `PrepareSendBuffer()` | — | 返回内部 `bsBufferedStream*`，并把它 Seek 到 0；后续用 §11 的 Read/Write API 填内容，再用 `SendPackage` 发出。**`game` 内部只有一个发送缓冲（8000 字节，自动扩容），不要交错使用**。 |

### 2.12 组队

| 方法 | 参数 | 说明 |
| --- | --- | --- |
| `RequestTeamJoin` | `playerId, grade, profession, name` | 发送组队申请（`MSLGP_C_TYPE_REQUESTJOIN`），name 截断到 `MSLGC_MAXPLAYERNAME`。 |
| `AcceptJoinTeam()` | — | 接受当前队伍系统排队中的入队申请。 |

### 2.13 UI 与资源访问器

| 方法 | 返回 | 说明 |
| --- | --- | --- |
| `LuaUIMgr()` | `CUILuaDlgMgr` | Lua UI 对话框管理器（见 §7.2）。|
| `GetCheatScript()` | `CUIDataCheatingScript` | 内挂配置数据模型（见 §3）。 |
| `StaticRes()` / `GetIDParseTool()` | `CIDParseTool` | 见 §9.1 |
| `GetFormatTipDlg()` | `wsDialogBase` | 全局格式化提示框（赋给对话框作为自定义 tip 窗口） |
| `GetUIPetManualElementScrollSpecialRecordPetSelectDlg()` | `CUIModalThrowAwayItem` | 宠物图鉴特殊收录确认子对话框 |
| `GetUIStoreDlg()` | `CUIStore` | 商城对话框（见 §7.6） |
| `GetEquipDlg()` | `CUIEquipDlg` | 装备背包对话框（见 §7.6） |

### 2.14 光标操作命令

C++ 端的光标可以处于某种"待操作"状态（如拾取/装备），脚本可以查询并清除。

| 方法 | 返回 | 说明 |
| --- | --- | --- |
| `GetCursorOperationCmd()` | `number`（`EOperationCmd`） | 当前光标操作命令枚举值；无操作时返回 `EOperationCmd_None`（0）。 |
| `GetCursorOperationCmdParam()` | `number` | 命令参数（`opInfo->xInterface.iParam`）。 |
| `ClearCursorOperation()` | 无 | 清掉光标图像列表并重置操作类型。 |

### 2.15 杂项工具

| 方法 | 参数/返回 | 说明 |
| --- | --- | --- |
| `Color24To16(r, g, b)` | -> `number` | RGB888 → RGB565 颜色值（`true2hi565(RGB(b,g,r))`）。 |
| `MaskValue(value, mask)` | -> `number` | 等价于 `value & mask`，用于在不支持位运算的 Lua 5.1 中走原生路径。 |
| `BasePropID(propId)` | -> `number` | 通过 `PropIDOP::BaseID(propId)` 计算"基础属性 ID"——本质上是 `propId / 64`，用于把扩展属性 ID 折回标准属性 ID。 |
| `GetSkillTip(skillId, level)` | -> `string` | 渲染好的技能 tip 文本。 |
| `ReadFileData(filename)` | -> `string` 或无 | 二进制读取文件全部内容并返回；末尾会附加 `\0`。失败返回无（0 返回值）。常用于读 `ResLib/*.csv`。 |
| `GetResolution()` | -> `(w, h)` | 当前游戏窗口分辨率（`UIMgr::GetScreenRect`）。 |
| `GetScreenWidth()` | -> `number` | `m_nScreenWidht` |
| `GetScreenHeight()` | -> `number` | `m_nScreenHeight` |
| `UTF8toASCII(text)` | -> `string` | 通过 `EncodingUtil::UTF_82ASCII` 转码（实际是 UTF-8 → 当前 ANSI 编码，即 GBK）。 |
| `PlayMagic(magicId, x?, y?)` | -> `number` 或无 | 在地图上 `(x,y)` 处独立播放一次法术特效（不归属玩家）；返回特效在 `Magic` 容器里的索引。`x/y` 默认 0。 |
| `GetAllArtifacts()` | -> `table` | 玩家所有奇物列表，元素为 `{id, isEnable:boolean, shortcutNum}`。 |
| `GetArtifact(id)` | -> `{id, isEnable, shortcutNum}` 或无 | 单个奇物。 |

---

## 3. `CUIDataCheatingScript` 内挂数据

通过 `game:GetCheatScript()` 获取，是内挂面板的数据模型，**所有勾选/比例/战斗配置都在这里**。脚本通过 Encode/Decode 配合 §1.2 的两对回调实现持久化（JSON）。

### 3.1 嵌套类型

#### `XFriendPlayer`（好友项）
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `PlayerID` | `number` | 玩家 ID |
| `Level` | `number` | 等级 |
| `Profession` | `number` | 职业 |
| `Checked` | `number`（0/1） | 是否勾选 |
| `Name` | `string` | 玩家名 |
| `Head` | `string` | 头像图标资源名 |

#### `XTaskInfo`（任务项）
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `ID` | `number` | 任务 ID |
| `Checked` | `number` | 是否勾选 |

#### `XItemInfo`（物品项）
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `Name` | `string` | 物品名（按名匹配） |
| `Checked` | `number` | 是否勾选 |

#### `XSkillMagicInfo`（技能/法术项）
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `type` | `number` | `0`=技能，`1`=法术 |
| `id` | `number` | 技能/法术 ID |
| `level` | `number` | 等级 |

### 3.2 列表方法

| 方法 | 返回/参数 | 说明 |
| --- | --- | --- |
| **好友** | | |
| `GetFriendCount()` | `number` | 好友数 |
| `GetFriendByIdx(idx)` | `XFriendPlayer` | 取第 `idx` 个（0 起始） |
| `CreateFriend(playerId)` | `XFriendPlayer` | 创建并返回新好友项 |
| `ClearFriends()` | 无 | 清空 |
| **任务** | | |
| `GetTaskCount()` | `number` | |
| `GetTaskByIdx(idx)` | `XTaskInfo` | |
| `CreateTask(taskId)` | `XTaskInfo` | |
| `ClearTask()` | 无 | |
| **物品** | | |
| `GetItemCount()` | `number` | |
| `GetItemByIdx(idx)` | `XItemInfo` | |
| `CreateItem(name)` | `XItemInfo` | |
| `ClearItems()` | 无 | |

### 3.3 一般配置（标量）

| Get / Set 方法对 | 类型 | 说明 |
| --- | --- | --- |
| `GetGatherName1` / `SetGatherName1(name)` | `string` | 采集类别 1 物品名 |
| `GetGatherName2` / `SetGatherName2(name)` | `string` | 采集类别 2 物品名 |
| `GetHpRate` / `SetHpRate(rate)` | `number` | 玩家 HP 自动恢复阈值（百分比） |
| `GetMpRate` / `SetMpRate(rate)` | `number` | 玩家 MP 阈值 |
| `GetPetHpRate` / `SetPetHpRate(rate)` | `number` | 宠物 HP 阈值 |
| `GetPetMpRate` / `SetPetMpRate(rate)` | `number` | 宠物 MP 阈值 |
| `GetPetRpRate` / `SetPetRpRate(rate)` | `number` | 宠物忠诚度阈值 |

### 3.4 自动行为开关

下面所有 `IsXxxEnabled` 返回 `number`（0/1），`SetXxxEnabled` 接 `number`。

| Get / Set | 含义 |
| --- | --- |
| `IsAutoDiscardEnabled` / `SetAutoDiscardEnabled` | 自动丢弃 |
| `IsAutoSellEnabled` / `SetAutoSellEnabled` | 自动售卖 |
| `IsAutoGatherEnabled` / `SetAutoGatherEnabled` | 自动采集 |
| `IsAutoRecoverHpEnabled` / `SetAutoRecoverHpEnabled` | 自动恢复玩家 HP |
| `IsAutoRecoverMpEnabled` / `SetAutoRecoverMpEnabled` | 自动恢复玩家 MP |
| `IsAutoRecoverPetHpEnabled` / `SetAutoRecoverPetHpEnabled` | 自动恢复宠物 HP |
| `IsAutoRecoverPetMpEnabled` / `SetAutoRecoverPetMpEnabled` | 自动恢复宠物 MP |
| `IsAutoRecoverPetRpEnabled` / `SetAutoRecoverPetRpEnabled` | 自动恢复宠物 RP |
| `IsAutoTaskEnabled` / `SetAutoTaskEnabled(bool)` | 自动任务总开关 |
| `IsAutoTaskPaused` / `SetAutoTaskPaused(bool)` | 自动任务暂停标志 |
| `IsAutoFightEnabled` / `SetAutoFightEnabled(int)` | 自动战斗辅助总开关 |

### 3.5 战斗配置（3 套，索引 0..2）

`SetFightConfigIndex(idx)` / `GetFightConfigIndex()` 切换当前生效套号。其余方法第 1 个参数都是 `configIndex:number`（0..2）。

#### 单 / 多选项

| Get / Set | 第 2 参数 | 含义 |
| --- | --- | --- |
| `IsPlayerUseSkillEnabled(idx)` / `SetPlayerUseSkillEnabled(idx, enabled)` | enabled:int | 玩家用技能 |
| `IsPlayerUseNormalAttackEnabled` / `SetPlayerUseNormalAttackEnabled` | enabled:int | 玩家用普攻 |
| `IsPetUseSkillEnabled` / `SetPetUseSkillEnabled` | enabled:int | 宠物用技能 |
| `IsPetUseNormalAttackEnabled` / `SetPetUseNormalAttackEnabled` | enabled:int | 宠物用普攻 |
| `IsAutoCatchPetEnabled` / `SetAutoCatchPetEnabled` | enabled:int | 抓宠开关 |
| `GetCatchPetName(idx)` / `SetCatchPetName(idx, name:string)` | name | 想抓的宠物名称 |
| `IsSelectPlayerFirstTargetEnabled` / `SetSelectPlayerFirstTargetEnabled` | enabled:int | 玩家开局选择首目标 |
| `IsSelectPetFirstTargetEnabled` / `SetSelectPetFirstTargetEnabled` | enabled:int | 宠物开局选择首目标 |
| `IsPlayerDelayActionEnabled` / `SetPlayerDelayActionEnabled` | enabled:int | 玩家开局等待蓄力 |
| `IsPetDelayActionEnabled` / `SetPetDelayActionEnabled` | enabled:int | 宠物开局等待蓄力 |
| `GetPlayerFirstTargetIndex(idx)` / `SetPlayerFirstTargetIndex(idx, posIdx)` | 位置号 | 玩家首目标位置 |
| `GetPetFirstTargetIndex(idx)` / `SetPetFirstTargetIndex(idx, posIdx)` | 位置号 | 宠物首目标位置 |
| `GetPlayerDelayActionSP(idx)` / `SetPlayerDelayActionSP(idx, sp)` | SP 数 | 玩家蓄力到 SP 再出手 |
| `GetPetDelayActionSP(idx)` / `SetPetDelayActionSP(idx, sp)` | SP 数 | 宠物蓄力到 SP 再出手 |

#### 技能/法术槽（每套有 4 个槽位 0..3）

| 方法 | 完整签名 | 说明 |
| --- | --- | --- |
| `SetPlayerSkillMagicInfo` | `(configIdx, slotIdx, type, id, level)` | 写入第 `configIdx` 套的第 `slotIdx` 个玩家技能/法术槽 |
| `GetPlayerSkillMagicInfo` | `(configIdx, slotIdx)` -> `XSkillMagicInfo` | 读取 |
| `SetPetSkillMagicInfo` | `(configIdx, slotIdx, type, id, level)` | 同上，宠物 |
| `GetPetSkillMagicInfo` | `(configIdx, slotIdx)` -> `XSkillMagicInfo` | 同上 |

#### 救护配置

| Get / Set | 含义 |
| --- | --- |
| `IsRescueIgnorePetEnabled(idx)` / `SetRescueIgnorePetEnabled` | 救护时忽略宠物 |
| `IsRescueAutoReliveEnabled` / `SetRescueAutoReliveEnabled` | 自动复活 |
| `IsRescueAutoHpRecoverEnabled` / `SetRescueAutoHpRecoverEnabled` | 自动恢复 HP |
| `GetRescueAutoHpRecoverRate(idx)` / `SetRescueAutoHpRecoverRate(idx, rate)` | HP 触发阈值（百分比） |
| `GetRescueRelivePlayerSkillMagicInfo(idx)` / `SetRescueRelivePlayerSkillMagicInfo(idx, type, id, level)` | 玩家复活技能 |
| `GetRescueRelivePetSkillMagicInfo` / `SetRescueRelivePetSkillMagicInfo` | 宠物复活技能 |
| `GetRescueHpRecoverPlayerSkillMagicInfo` / `SetRescueHpRecoverPlayerSkillMagicInfo` | 玩家加血技能 |
| `GetRescueHpRecoverPetSkillMagicInfo` / `SetRescueHpRecoverPetSkillMagicInfo` | 宠物加血技能 |

---

## 4. 物品数据类

### 4.1 `XPlayerItem` —— 背包/仓库槽位

只读属性。可作为 `GetItemBar()`、`CUIDataItem:GetSlotData` 等返回值。

| 属性 / 方法 | 类型 | 说明 |
| --- | --- | --- |
| `ItemID` | `number` | 物品 ID |
| `Type` | `number` | 物品类型 |
| `Count` | `number` | 数量 |
| `Name` | `string` | 名称 |
| `IsQueryProp` | `boolean` | 是否已查询过属性 |
| `GetPropValue(propId)` | `number` | 取指定 `propId` 的当前值（精确匹配 ID，含子属性） |
| `GetPropValueByBaseID(baseId)` | `number` | 按基础属性 ID 取值 |
| `GetPropsByBaseID(baseId)` | 多返回值 | 按基础 ID 取所有相关条目 |
| `GetImagePath()` | `string` | 物品图像资源路径 |

### 4.2 `CUIDataItem` —— 物品栏聚合

| 方法 | 参数/返回 | 说明 |
| --- | --- | --- |
| `GetSlotData(slot)` | -> `XPlayerItem` | 单槽数据（包装 `GetSpecifyItemSlotData`） |
| `GetSlotTip(slot)` | -> `string` | 单槽 tip 文本 |
| `GetItemCount(itemId)` | -> `number` | 背包中指定物品的总数量 |
| `GetMoney()` | -> `number` | 金币 |
| `GetGoldStone()` | -> `number` | 金元宝 |
| `GetSilverStone()` | -> `number` | 银元宝 |

---

## 5. 场景物体类

`bsPlayerObj` 和 `bsGameUnit` 都只暴露坐标，且**`X/Y` 是浮点像素坐标**（C++ 端是 `float m_fCurX/m_fCurY`，被强转为 `number`）。脚本里做距离比较时按整数处理即可。

### 5.1 `bsPlayerObj`
| 属性 | 类型 | R/W |
| --- | --- | --- |
| `X` | `number` | R |
| `Y` | `number` | R |

### 5.2 `bsGameUnit`
| 属性 | 类型 | R/W |
| --- | --- | --- |
| `X` | `number` | R |
| `Y` | `number` | R |

---

## 6. 战斗数据类 `TFightNpcData`

`GetFighter(pos)` 返回。只读。

| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `Type` | `number` | 战斗者类型；`0xFFFFFFFF` 表示空槽（`GetFighter` 会直接返回 nil） |
| `HP` | `number` | 当前 HP |
| `HPMax` | `number` | HP 上限 |
| `IsDead` | `number` | 是否死亡（byte 0/1） |
| `SP` | `number` | 当前 Store Point（蓄力点） |

---

## 7. UI 框架

UI 系统使用基于 metatable 的继承链：`wsWndBase` → `wsDialogBase` → `CUILuaDlg` / `CUIStore` / `CUIModalThrowAwayItem` / `CUIEquipDlg`；其它具体控件（`TWndImageCtrl/TWndLabelCtrl/...`）都继承自 `wsWndBase`。

### 7.1 `wsWndBase`（控件基类）

所有控件都可调用以下方法。

| 方法 / 属性 | 签名 | 说明 |
| --- | --- | --- |
| `BaseCtrl()` | -> `wsWndBase` | 取自身的底层控件（用于 prefab 嵌套等） |
| `GetEnable()` / `SetEnable(b:int)` | | 启用状态 |
| `GetVisible()` / `SetVisible(b:int)` | | 可见状态 |
| `SetTipInfo(text:string)` | | 鼠标 tip |
| `SetWndText(text:string)` / `GetWndName()` | | 窗口文字 / 窗口名 |
| `SetUserData(data)` / `GetUserData()` | | 用户数据指针（透传） |
| `SetPosition(x, y)` | | 设置左上角 |
| `Left/Top/Right/Bottom` | -> `number` | 绝对坐标 |
| `RelativeLeft()` / `RelativeTop()` | -> `number` | 相对父窗口坐标 |
| `SetSize(w, h)` / `Width()` / `Height()` | | 尺寸 |
| `SetTextSize(n)` / `GetTextSize()` | | 文字大小 |
| `IsCoverPoint(x, y)` | -> `boolean` | 点是否覆盖此控件 |
| `SetAlpha(a)` / `GetAlpha()` | | 透明度 |
| `GetControlCount()` / `GetControl(idx)` / `GetControlByName(name)` / `GetControlByIndex(idx)` | | 子控件遍历 |
| `IsChildControl(ctrl)` | -> `boolean` | |
| `GetControlAtPoint(x, y)` | -> `wsWndBase` | 命中测试 |
| **属性** `CtrlID` | `number` (R) | 控件 ID |
| **属性** `Anchor` | `number` (RW) | 布局锚点位掩码：1=顶，2=左，4=右，8=底，互相相加表示居中。 |

### 7.2 `wsDialogBase`（对话框基类）*(继承 wsWndBase)*

| 方法 | 说明 |
| --- | --- |
| `SetCaptionRect(left, top, w, h, flag)` | 标题栏矩形 |
| `SetBKImage(path:string, x, y)` | 背景图 |
| `SetupCustomTipWnd(tipDlg)` / `GetCustomTipWnd()` | 绑定自定义 tip 窗口（一般传 `game:GetFormatTipDlg()`） |
| `CenterDlg()` | 居中 |
| `RemoveChild(ctrl)` | 移除子控件 |
| `SendWndEvent(event, p1, p2)` | 发送窗口事件 |
| `RequestFocus()` | 请求焦点 |
| `IsTipWindow()` | -> `boolean` |
| `IsActivedWindow()` | -> `boolean` |
| `DestroyAllCtrl()` | 销毁所有子控件 |
| `IsHitWindow(x, y)` | -> `boolean` |
| `GetChildCount()` / `GetChild(idx)` | 子对话框遍历 |
| `TWindowFromPoint(x, y)` | -> `wsWndBase` |

### 7.3 `CUILuaDlg` *(继承 wsDialogBase)*

`OnCreateAllUI(dlgMgr)` 中通过 `dlgMgr:CreateDlg(...)` 得到的对话框。**所有创建子控件的方法都成对存在**：`CreateXxxCtrl(name, x, y, w, h, ctrlId)` 在对话框根节点上创建，`CreateXxxCtrlInParent(name, x, y, w, h, ctrlId, parentCtrl:wsWndBase)` 在指定父控件上创建；`ToXxxCtrl(ctrl)` 用于把通过 `GetControlByName` 拿到的 `wsWndBase` 转换为具体类型。

| 控件类型 | 创建方法 | 转换方法 | 控件类 |
| --- | --- | --- | --- |
| Lua 容器控件 | `CreateLuaCtrl` / `CreateLuaCtrlInParent` | `ToLuaCtrl` | `CUILuaCtrl`（仅作为容器）|
| 图像 | `CreateImageCtrl` / `CreateImageCtrlInParent` | `ToImageCtrl` | `TWndImageCtrl` |
| 文字 | `CreateLabelCtrl` / `CreateLabelCtrlInParent` | `ToLabelCtrl` | `TWndLabelCtrl` |
| 复选框 | `CreateCBCtrl` / `CreateCBCtrlInParent` | `ToCBCtrl` | `TWndCheckBoxCtrl` |
| 按钮 | `CreateBtnCtrl` / `CreateBtnCtrlInParent` | `ToBtnCtrl` | `TWndButtonCtrl` |
| 动画图像 | `CreateMovCtrl` / `CreateMovCtrlInParent` | `ToMovCtrl` | `wsPlayImageCtrl` |
| 页签 | `CreateTabCtrl` / `CreateTabCtrlInParent` | `ToTabCtrl` | `TWndTabCtrl` |
| 垂直滚动条 | `CreateScrollBarV` / `CreateScrollBarVInParent` | `ToScrollBarV` | `wsScrollBarV` |
| 富文本 | `CreateRichEdit` / `CreateRichEditInParent` | `ToRichEdit` | `wsRichEdit` |
| 编辑框 | `CreateEditCtrl` / `CreateEditCtrlInParent` | `ToEditCtrl` | `TWndEditCtrl` |
| 进度条 | `CreateProgressBarCtrl` / `CreateProgressBarCtrlInParent` | `ToProgressBarCtrl` | `TWndProgressBarCtrl` |

其它对话框级方法：

| 方法 | 说明 |
| --- | --- |
| `ShowDlg(bShow:boolean)` | 显示/隐藏对话框 |
| `CreateScrollVListener(name:string)` | -> `IScrollVListener`，用于绑定到滚动条；C++ 端会回调 `GetScrollVMaxLen` 等全局函数 |
| `GetName()` | -> `string`，对话框名 |
| `SetHandleMsg(eventCode:number)` | 注册接收某种消息事件 |
| `DestroyCtrl(ctrl)` | 销毁指定子控件 |
| `SetCloseWhenMove(b)` | 设为"角色移动时自动关闭" |

### 7.4 `CUILuaDlgMgr`

`game:LuaUIMgr()` 返回。

| 方法 | 说明 |
| --- | --- |
| `CreateDlg(name:string, x, y, w, h)` | -> `CUILuaDlg`，创建新对话框 |
| `Free(dlg)` | 释放对话框（实际调用 `FreeDlg`） |
| `FindDlg(name:string)` | -> `CUILuaDlg` 或 `nil` |
| `AddToWndCloser(dlg)` | 加入 ESC 关闭链 |
| `HandlePackage(pkgType:number)` | 注册"该数据包到达时回调脚本 `OnUIPackage`" |
| `OpenQuantDlg(...)` | 打开通用量化输入对话框 |
| `CloseQuantDlg()` | 关闭量化对话框 |

### 7.5 各控件方法

#### `TWndImageCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `SetImage(path:string)` | 设置图像（`.mgff`） |
| `SetMouseMoveEvent(b:int)` | 是否接收鼠标移动事件 |
| `IsImageValid()` | -> `boolean` |
| `GetTotalFrames()` / `GetNowFrame()` / `SetNowFrame(n)` / `RandomNowFrame()` | 多帧图操作 |
| `IsAutoSeekFrame()` / `SetAutoSeekFrame(b)` | 是否自动播放 |
| `IsImageScale()` / `SetImageScale(b)` | 是否缩放绘制 |
| `SetImageDrawOffset(x, y)` | 绘制偏移 |

#### `TWndLabelCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `ClearString()` / `AddString(s)` / `GetString()` | 文本操作。`AddString` 是追加。 |
| `SetAlign(n)` / `GetAlign()` | 水平对齐：`0`=左，`1`=右，`2`=居中 |
| `SetVAlign(n)` / `GetVertAlign()` | 垂直对齐：`0`=顶，`1`=底，`2`=居中 |
| `SetFontSize(n)` / `GetFontSize()` | 字体大小 |
| `SetColor(rgb565)` | 颜色（用 `game:Color24To16` 转换） |
| `SetWrap(b)` / `IsWrap()` | 自动换行 |
| `SetLineSpace(n)` / `GetLineSpace()` | 行间距 |
| `SetTextStartPos(x, y)` | 文本起点 |
| `SetMouseMoveEvent(b)` | 鼠标移动事件 |
| `EnableOutlineEffect(b)` / `IsEnableOutlineEffect()` | 描边效果 |
| `SetOutlineColor(rgb565)` / `GetOutlineColor()` | 描边颜色 |
| `SetFontWeight(n)` / `GetFontWeight()` | 字体粗细 |
| `SetFontName(name)` / `GetFontName()` | 字体名 |

#### `TWndButtonCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `SetImage(normal, active, pressed, disabled)` | 四态图像 |
| `SetEnableDblClickEvent(b)` | 是否允许双击事件 |
| `SetBtnOffset(x, y)` | 偏移 |
| `SetButtonForceState(state)` | 强制状态 |
| `SetCanHasFocus(b)` | 是否可获焦点 |
| `IsMouseOver()` | -> `boolean`（注：旧 readme 中误写为 `GetBottonMSIsOver`） |
| `ChangeToCheckButton(b)` / `IsCheckButton()` | 转为复选按钮 |
| `IsChecked()` / `SetCheck(b)` | 选中状态 |
| `ShowButtonName(b)` | 是否显示文字 |
| `Set/GetTextDisabledColor(rgb565)` | |
| `Set/GetTextPressedColor(rgb565)` | |
| `Set/GetTextActivedColor(rgb565)` | |

#### `TWndCheckBoxCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `Init(statusCount:int)` | 多态复选框，传状态总数 |
| `SetImage(statusIdx:int, normalPath:string, activePath:string)` | 单态图像 |
| `SetCurStatus(idx)` / `GetCurStatus()` | 当前状态 |
| `GetIsMSOver()` | -> `boolean` |
| `IsShowName()` / `SetShowName(b)` | 是否显示文字 |

#### `wsPlayImageCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `Play()` / `Rewind()` | 播放 / 倒回首帧 |
| `SetImage(path:string)` | 设置动画图源 |
| `SetSpeed(speed:int)` | 播放速度（值越大越慢；典型值 33） |

#### `TWndTabCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `Init(pageCount:int)` | 初始化页数 |
| `SetTabPageImage(pageIdx, normal, hover, pressed, active)` | 四态图像 |
| `ActiveTabPage(pageIdx)` | 切到指定页 |
| `ActiveTabCtrl(ctrl)` | 把指定子控件激活为当前页 |
| `GetActiveTab()` | -> 当前页索引 |
| `SetEachPagePos(x, y, w, h)` | 每个 tab 标签的尺寸 |
| `SetPageAlign(n)` | 标签对齐 |
| `SetPageInterval(n)` | 标签间距 |

#### `wsScrollBarV` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `SetListener(listener:IScrollVListener)` | 绑定监听器（用 `CUILuaDlg:CreateScrollVListener` 创建） |
| `SetImage(...)` | 滚动条图像 |

#### `wsRichEdit` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `AddString(s)` / `AddStringIndent(s, indent)` / `GetString()` / `ClearText()` | 富文本操作 |
| `SetLineSpace(n)` / `GetLineSpace()` | |
| `ToScrollVListener()` | -> 内置的滚动监听器（用于直接驱动滚动） |
| `SetAutoMove(b)` | 自动滚到底部 |

#### `TWndEditCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `GetInputText()` | -> `string`，当前输入内容 |
| `AddString(s)` | 追加文本 |
| `SetAlign(n)` / `GetAlign()` | |
| `SetTextSize(n)` | |
| `SetTextColor(rgb565)` | |
| `SetMultiline(b)` | 多行模式 |
| `Clear()` | 清空 |

#### `TWndProgressBarCtrl` *(继承 wsWndBase)*
| 方法 | 说明 |
| --- | --- |
| `SetProcessBarImage(path)` | |
| `Set/GetProcessBarDataMaxValue(v)` | 数据上限 |
| `SetProcessBarDataCurValue(v)` | 当前值 |
| `SetProcessChangeValue(v)` / `GetProcessCurChangeValue()` / `ResetProcessCurChangeValue()` | "变化中"显示 |
| `SetBarChangeDir(dir)` | 变化方向（见 `EProgressBarChangeDir`） |
| `SetBarArangeDir(dir)` | 排列方向（见 `EProgressBarArrange`） |

### 7.6 特殊对话框

#### `CUIModalThrowAwayItem` *(继承 wsDialogBase)*
"丢弃确认"或类似确认弹窗。

| 方法 / 属性 | 类型 | 说明 |
| --- | --- | --- |
| `GetDlg()` | `wsDialogBase` | 底层对话框 |
| `GetOKButton()` | `TWndButtonCtrl` | 确定按钮 |
| `GetCancelButton()` | `TWndButtonCtrl` | 取消按钮 |
| `ShowDlg(b)` | | 显示/隐藏 |
| `SetCueInfo(text)` | | 提示文本 |
| `SetCueInfoRect(x, y, w, h)` | | 提示矩形 |
| `SetDefaultSizeAndImages()` | | 还原默认外观 |
| **属性** `TagIdx` | `number` (RW) | 关联索引 |
| **属性** `TagType` | `number` (RW) | 关联类型 |
| **属性** `EventHandle` | `string` (RW) | Lua 端的事件处理函数名（C++ 会用 `CallLuaFunc<void>(name, dwEvent, dwCtrlID, pCtrl)` 调用） |

#### `CUIStore` *(继承 wsDialogBase)*
商城对话框。`game:GetUIStoreDlg()` 获取。

| 方法 | 说明 |
| --- | --- |
| `SetOnSellTip(text:string)` | 设置当前售卖提示（支持颜色码 `#RRGGBB#`） |

#### `CUIEquipDlg` *(继承 wsDialogBase)*
装备背包对话框。`game:GetEquipDlg()` 获取（全局单例，即地图 UI 的装备/背包面板）。在 `wsDialogBase` 之上扩展了 `ShowDlg`。

| 方法 | 说明 |
| --- | --- |
| `ShowDlg(bShow:number)` | 显示/隐藏对话框：`1`=显示，`0`=隐藏。显示时执行完整开启逻辑（置顶、刷新坐骑/锁定状态、隐藏其内部子对话框）。**注意**：参数是 `number`（0/1），不同于 `CUILuaDlg:ShowDlg(boolean)` 的布尔参数——传 Lua 布尔值会被当作 0 处理。 |

---

## 8. 玩家数据 `TGamePlayer` / `TPlayerSecondProperty`

### 8.1 `TGamePlayer`

通过 `game:GetGamePlayer()` 获取。

| 属性/方法 | 类型 | 说明 |
| --- | --- | --- |
| `Grade` | `number` (R) | 等级 |
| `GodhoodLevel` | `number` (R) | 神格等级 |
| `GodhoodExp` | `number` (R) | 神格经验 |
| `GetSecondProperty()` | `TPlayerSecondProperty` | 二级属性 |

### 8.2 `TPlayerSecondProperty`（全部只读）

| 属性 | 含义 |
| --- | --- |
| `RoundTime` | 战斗回合时间 |
| `PhysicsDef` / `MagicDef` | 物 / 魔防 |
| `PhysicsAtt` / `MagicAtt` | 物 / 魔攻 |
| `Duck` / `Accuracy` | 闪避 / 命中 |
| `Deadly` | 致命一击 |
| `CounterAtt` | 反击 |
| `HarmShield` | 伤害护盾 |
| `Block` | 格挡 |
| `MagicDeadlyHarmScale` / `PhysicsDeadlyHarmScale` | 致命伤害倍率 |
| `HarmScaleInRange` | 范围内伤害倍率 |
| `SkillHarmScale` | 技能伤害倍率 |
| `PhyHarmAddition` / `MagicHarmAddition` / `HarmAddition` | 三类伤害加成 |
| `ShieldCollapse` | 护盾瓦解 |
| `BreakArmor` | 破甲 |
| `NormalAttackHarmAddition` | 普攻伤害加成 |
| `PhysicTenacity` / `MagicTenacity` | 韧性 |
| `RDeadlyHarmScale` | 抗致命倍率 |
| `PhyHarmRemission` / `MagicHarmRemission` / `HarmRemission` | 减伤 |
| `NormalAttackHarmRemission` | 普攻减伤 |
| `BlockEnhance` | 格挡强化 |
| `VigorMax` | 精力上限 |
| `TiredDuration` | 疲劳持续时间 |
| `ExpAmplification` / `GodExpAmplification` | 经验/神识加成 |
| `MoveSpeed` | 移速 |
| `EnmityScale` | 仇恨倍率 |
| `IgnoreResist` | 忽视抗性 |
| `MPCostReduceScale` | MP 消耗降低 |
| `StealHP` | 吸血 |
| `CureEffect` / `BeCureEffect` | 治疗 / 被治疗效果 |
| `SkillCDSpeed` | 技能 CD 速度 |
| `NearHarmAddition` / `FarHarmAddition` | 近 / 远程伤害加成 |
| `NearHarmRemission` / `FarHarmRemission` | 近 / 远程减伤 |
| `SkillHarmRemission` | 技能减伤 |
| `IntonateBoost` | 吟唱加速 |
| `MPLose` | MP 流失 |

---

## 9. 静态资源解析 `CIDParseTool`

通过 `game:StaticRes()` 或 `game:GetIDParseTool()` 获取。下列方法都是从客户端的静态配置表里查信息。**找不到时返回 `nil`**。

### 9.1 通用查询方法

| 方法 | 参数 | 返回 |
| --- | --- | --- |
| `GetItemInfo(itemId)` | -> `wsItemInfo` | 物品基础信息 |
| `GetEquipInfo(equipId)` | -> `XEquip` | 装备信息 |
| `FindEquipBlessLevel(...)` | -> `XEquipBlessLevelInfo` | 装备祝福等级条目 |
| `FindEquipBlessRank(...)` | -> `XEquipBlessRankInfo` | 装备祝福阶位条目 |
| `FindEquipBlessAbility(...)` | -> `XEquipBlessAbilityLibInfo` | 装备祝福能力库条目 |

### 9.2 宠物图鉴（5 类各自独立）

每类的查询接口模式一致：

- `ParseXxxByPetID(petId)` -> 数组
- `ParseXxx(pageId)` -> 单条
- `GetXxxPageCount()` -> 页数
- `GetXxxByPageIndex(idx)` -> 第 idx 页
- `GetXxxGroupID(...)` / `GetXxxListByGroupID(...)` -> 组查询
- `GetXxxClass(...)` -> 类别

类型名前缀：
- `PetManualElementScroll` —— 灵元珠
- `PetManualElfBook` —— 精灵书（与 ElementScroll/ElfTreasure 相同，方法族含组查询 `GetPetManualElfBookGroupID` / `GetPetManualElfBookListByGroupID` 及 `GetPetManualElfBookClass`；原注"无 `GroupID` 系列"与注册表不符，已更正）
- `PetManualElfTreasure` —— 精灵宝物
- `PetManualCost` —— 收录消耗（仅 `ParsePetManualCost`）
- `PetManualRuneBoxLevelup` —— 魔盒升级（`ParsePetManualRuneBoxLevelup`, `GetPetManualRuneBoxLevelupLevelCount`）

### 9.3 符文系统

| 方法 | 说明 |
| --- | --- |
| `ParsePetManualRuneLib(...)` | 解析符文库条目 |
| `ParsePetManualRuneIDList(...)` | 解析符文 ID 列表 |
| `ParsePetManualRunePropList(...)` | 解析符文属性列表 |
| `GetPetManualRunePropDescCount()` | 属性描述条目数 |
| `ParsePetManualRunePropDesc(...)` | 解析单条属性描述 |
| `GetPetManualRuneBoxSlotCount(...)` | 符文槽位数 |
| `ParsePetManualRuneSlot(...)` | 槽位信息 |
| `ParsePetManualRuneRefineCost(...)` | 淬炼消耗 |
| `ParsePetManualRuneRefinePropCustomType(...)` | 淬炼定制类型 |

### 9.4 数据结构清单（所有属性均只读）

#### `wsItemInfo`（物品基础配置）
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `ItemID` | `number` | 物品 ID |
| `Name` | `string` | 名称（按 GBK） |
| `Type` | `number` | 类型枚举 |
| `Quality` | `number` | 文字颜色（用作品质区分） |
| `Endurance` | `number` | 耐久 |
| `Price` | `number` | 价格 |
| `Overlap` | `number` | 叠加数 |
| `ActObj` | `number` | 作用对象 |
| `LevelReq` | `number` | 等级要求 |
| `UsePlace` | `number` | 使用地点（0=只地图，1=只战斗，2=不限制） |
| `ActID` | `number` | 作用动作 ID |
| `NewActID` | `number` | 新作用动作 ID |
| `UseEffect` | `number` | 使用特效 |
| `Useable` | `number` | 是否允许使用（位掩码：可用 / 可丢 / 可摆摊） |
| `IsImportant` | `number` | 是否重要物品 |
| `WaitType` | `number` | 等待条；`0` 不显示，其它见 `UIGame/Bar` 目录 |
| `WaitTimeSec` | `number` | 等待时长（秒） |
| `GetImageName()` | `string` | 大图资源名 |
| `GetSmallImageName()` | `string` | 小图资源名 |
| `GetItemName()` | `string` | 名称（同 `Name`，方法形式） |

#### `XEquip`（装备静态配置）
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `ItemID` | `number` | |
| `Type` | `number` | |
| `Rank` | `number` | |
| `SexReq` | `number` | 性别要求 |
| `ProfReq` | `number` | 职业要求位掩码 |
| `StrengthReq` / `SenseReq` / `ResistanceReq` / `AgilityReq` / `LuckReq` | `number` | 力 / 感 / 抗 / 敏 / 运要求 |
| `RepairPrice` / `RepairDiamond` | `number` | 修理金币 / 钻石消耗 |
| `QualityLevel` | `number` | 品质等级 |
| `RefineMaterialType` / `RefineMaterialLevel` / `RefineMaterialAncient` | `number` | 精炼材料 |
| `GodhoodReq` | `number` | 神格要求 |
| `EnhanceType` | `number` | 强化类型 |
| `BlessPoolID` | `number` | 祝福池 ID |
| `BlessPropID1` / `BlessPropValue1` | `number` | 祝福属性 1 ID / 值 |
| `BlessPropID2` / `BlessPropValue2` | `number` | 祝福属性 2 ID / 值 |
| `AwakeEffectPool` | `number` | 觉醒特效池 |

#### `XCSAutoItem`（内挂自动物品配置）
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `Name` | `string` | 名称 |
| `ItemTypes` | `table<number>` | 物品类型数组（用于匹配多个类型） |
| `Quality` | `number` | 品质过滤 |

#### `XSkill` / `XMagic`
| 属性 | 类型 | 说明 |
| --- | --- | --- |
| `Type` | `number` | 技能 / 法术类型 |
| `TargetType` | `number` | 目标类型（`iActObj`） |
| `SP` | `number` | 蓄力消耗 |
| **仅 XSkill** `Name` / `Desc` | `string` | 名称 / 描述 |

#### `XEquipBlessLevelInfo` / `XEquipBlessRankInfo` / `XEquipBlessAbilityLibInfo`

详细字段列表见原配置表；典型字段如 `ConsumeItemID1..3`、`ConsumeItemCount1..3`、`ConsumeGodhoodExp`、`ConsumeMoney`，`XEquipBlessAbilityLibInfo` 额外有 `AbilityID`、`Type`、`SkillID`、`Rarity`、`Extract`，以及方法 `GetName()` -> `string`。

#### 宠物图鉴系列结构

`XPetManualElementScroll` / `XPetManualElfBook` / `XPetManualElfTreasure` 三类共同字段：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `ItemID` / `PageID` | `number` | 页面 ID（部分类型只有 `PageID`） |
| `GroupName` / `ClassName` | `string` | 分组 / 类别 |
| `PetID1..PetID6` | `number` | 收录所需 6 个宠物槽 |
| `NeedMinTotalScore` | `number` | 总积分要求 |
| `NeedClassName` | `string` | 类别要求 |
| `NeedPetManualNum` | `number` | 类别已收录数要求 |
| `NeedDesc` | `string` | 文本描述 |
| `RewardMagicMatrixPoints` | `number` | 法阵秘能点 |
| `RewardItemID1..3` / `RewardItemCount1..3` | `number` | 奖励物品 |
| **仅 ElementScroll** `RewardRuneID1` / `RewardRuneID2` | `number` | 奖励符文 ID |

`XPetManualCost`（收录消耗）—— 字段较多，覆盖：
- 目标宠物：`PetID`
- 消耗宠物：`CostPetID` / `CostBindedPetID`（两选一）
- 宠物前置要求：`NeedGrowing/Level/Soulshift/LearnLevel/XiulianLevel/StarLevel/PetEquipCount/PetEquipLevel/PetEquipQuality/PetEquipEnhanceLevel`
- 金币消耗：`CostMoney`
- 物品消耗：`CostItemID1..3` / `CostBindedItemID1..3` / `CostItemCount1..3`
- 特殊消耗 1：`SpecialCostItemID` / `SpecialCostBindedItemID` / `SpecialCostItemCount`
- 特殊消耗 2：`SpecialCost2ItemID` / `SpecialCost2BindedItemID` / `SpecialCost2ItemCount`
- 奖励：`RecordedRewardScore`、`RecordedRewardMagicMatrixPoints`

`XPetManualRuneBoxLevelup`（魔盒升级）：
- `m_dwLevel` —— 等级（注意：这个属性按 C++ 字段名 `m_dwLevel` 直接暴露，不是 `Level`）
- `CostItemID1/2` / `CostItemCount1/2` —— 升级消耗物品
- `RefinementRuneNeedItemID` / `RefinementRuneNeedBindedItemID` / `RefinementRuneNeedItemCount` / `RefinementRuneNeedMoney`
- `RefinementRuneCountWeight1..4` —— 淬炼时一次出几条符文的权重
- `RefinementRuneLevel1Weight..5Weight` —— 各等级符文权重
- `CanCustomProp:boolean`、`LockPropCount:number`

`XPetManualRunePropLib`：`ID/Value/Weight`。
`XPetManualRuneLib`：`ID/Name/Class/Level/Icon/Desc`。
`XPetManualRunePropDescItem`：`ID/Class/Level/PropID`。
`XPetManualRuneSlot`：`Index/ReqRuneBoxLevel/UnlockNeedItemID/UnlockNeedItemCount/UnlockNeedMoney`。
`XPetManualRuneRefineCost`：`BoxLevel/CustomType/NeedMoney/NeedItemID1/NeedBindedItemID1/NeedItemCount1/NeedItemID2/NeedBindedItemID2/NeedItemCount2`。
`XPetManualRuneRefinePropCustomType`：`PropID/CustomType1/CustomType2`。

---

## 10. 二进制流 `bsBufferedStream`

由 `game:PrepareSendBuffer()` 返回，用于手工拼装一个数据包，然后通过 `game:SendPackage(packetId)` 发出。在 §1.2 的 `OnUIPackage(pkgType, stream)` 中也以此类型传入。

| 方法 | 说明 |
| --- | --- |
| `ReadInt8` / `ReadInt16` / `ReadInt32` / `ReadInt64` | 有符号读 |
| `ReadUInt8` / `ReadUInt16` / `ReadUInt32` | 无符号读 |
| `ReadFloat` / `ReadDouble` | 浮点读 |
| `WriteInt8` / `WriteInt16` / `WriteInt32` / `WriteInt64` | 有符号写 |
| `WriteUInt8` / `WriteUInt16` / `WriteUInt32` | 无符号写 |
| `WriteFloat` / `WriteDouble` | 浮点写 |

> 注：所有数据按**小端字节序**。读字符串需自己读长度+字节并截止 `\0`（参考 §1.3 的格式）。

---

## 11. `CSendPacket` 顶层发包函数

注册到 Lua **全局模块**（不是 `game` 的方法）。调用形式：直接 `CSendPacket.SendXxx(args)`，**Lua 中没有自动暴露 `CSendPacket` 名字**——这些函数是用 `LuaModule lua(pState); lua.def("SendXxx", ...)` 注册的，所以实际上是**全局函数** `SendXxx(args)`。

> 命名上仍然以 `Send` 开头便于辨识。这部分以发包为主，调用后无返回值。

### 11.1 任务相关
- `SendCancelTaskPacket(taskId)` —— 取消任务
- `SendQuickFinishTaskPacket(taskId)` —— 快速完成任务
- `SendRecreateTaskPacket(taskId)` —— 重新接取任务

### 11.2 物品 / 摆摊 / 仓库 / 银行
- `SendUseAssistPacket(type)` —— 使用辅助物品（注：内部已检查"背包中存在该类型"）
- `SendUseItemOnItemPacket(slotSrc, slotDst)` —— 物品对物品使用
- `SendDropItemPacket(slot, quant, confirm:bool)` —— 丢弃物品
- `SendPlayerUseItemPacket(slot)` —— 玩家使用物品
- `SendPlayerUseItemToPlayerPacket(slot, targetPlayerId)`
- `SendPetUseItemPacket(slot, petIndex)` —— 宠物使用物品
- `SendUseTriggerItemPacket(slot)` —— 使用任务触发道具
- `SendTidyItemBarPacket()` —— 整理背包
- `SendChangeEquipAppearVisible(b)` —— 切换装备外观可见性
- `SendQueryEquipPropPacket(slot)` —— 查询装备属性
- `SendRepairItemPacket(slot)` —— 修理物品
- `SendRepairItemEndPacket()` —— 结束修理
- `SendPutOnSlotPacket(srcType, srcSlot, dstType, dstSlot)` —— 换装（srcType: 0=物品栏, 1=装备栏, 2=宠物装备栏, 3=随身仓库）
- `SendCancelSpecialStatusPacket()` —— 取消特殊状态
- `SendChangeToBabyPacket()` / `SendChangeToAdultPacket()` —— 变身宝宝 / 成人

### 11.3 商城
- `SendQueryStoreBarPacket()` —— 查询商城物品栏
- `SendBuyStoreItemPacket(...)` —— 购买商城物品

### 11.4 账号物品栏 / 交通工具
- `SendQueryAccountItemBarPacket()`
- `SendQueryAccountItemPropPacket(slot)`
- `SendTakeAccountItemPacket(slot)` —— 取出 1 件
- `SendQueryVehicleCarriagePacket()` —— 查询交通工具物品栏
- `SendQueryVehicleItemPropPacket(slot)`
- `SendTakeOutFromVehicleCarriagePacket(slot)`
- `SendStoreIntoVehicleCarriagePacket(slot)`
- `SendTurnOnVehiclePacket()` / `SendTurnOffVehiclePacket()` —— 激活 / 关闭交通工具
- `SendEnhanceVehiclePacket(...)` —— 镶嵌功能模块

### 11.5 战斗
- `SendFightUseItemPacket(targetSerPos, slot)` —— 战斗中对位置 `targetSerPos` 使用物品
- `SendFightCastSkillPacket(targetSerPos, dwParam, 0)` —— `dwParam = MAKELONG(skillLevel, skillIndex)`
- `SendFightCastMagicPacket(targetSerPos, dwParam, 0)` —— 同上，法术
- `SendFightPetCastSkillPacket(targetSerPos, dwParam)`
- `SendFightPetCastMagicPacket(targetSerPos, dwParam)`
- `SendFightCmdPacket(isPet:bool, targetClientPos, action, param)` —— 战斗通用指令
- `SendAreaPKPacket(...)` —— 竞技包
- `SendFreePKPacket(targetPlayerId)` —— 自由 PK
- `SendRobDartPacket(targetPlayerId)` —— 劫镖

> **位号说明**：传给 `SendFightXxx` 的目标位是**服务端位**。脚本中常用 `game:GetXxxToFighter(...)`（§2.10），它会内部 `ClientPos2SerPos`；如果直接调用这些底层包，需要自己转换。

### 11.6 组队
- `SendRequestToJoinTeamPacket(...)` —— 申请入队
- `SendAcceptToJoinTeamPacket(playerId)` —— 同意入队
- `SendRefuseToJoinTeamPacket(playerId)` —— 拒绝入队

### 11.7 宠物
- `SendPetLearnSkillPacket(...)` —— 宠物学习技能
- `SendPetBankOperatorPacket(...)` —— 宠物银行通用操作
- `SendQueryBankPetProperty(...)` —— 查宠物银行中某宠物详细属性
- `SendQueryPetBankPacket()` —— 查宠物银行
- `SendPetBankEndPacket()` —— 结束银行操作
- `SendPetBankBuySlotPacket()` —— 购买银行栏位
- `SendSendQueryPetEquipPacket(...)` —— 查询宠物装备

### 11.8 宠物图鉴 / 魔盒符文
- `SendRequestSetPetIllusionID(petId, illusionId)` —— 宠物幻化 / 还原（`illusionId=0` 即还原）
- `SendRequestRecordPet(pageId, dwCostType)` —— 收录宠物。`dwCostType`：0=一般收录, 1=特殊收录, 2=第二种特殊收录（额外消耗物品）
- `SendRequestActivateRuneBox()` —— 激活魔盒
- `SendRequestLevelUpRuneBox()` —— 魔盒升级
- `SendRequestUnlockRuneSlot(slotIdx)` —— 解封符文槽
- `SendRequestRefinementRuneSlot(slotIdx, customType)` —— 淬炼符文
- `SendRequestRebuildRuneSlot(slotIdx)` —— 重筑符文
- `SendRequestUseRuneSlot(slotIdx, useType)` —— 使用符文
- `SendQueryPetManualRecordedPetList()` —— 查图鉴已收录列表
- `SendQueryUnlockedRuneIDList()` —— 查已解锁符文 ID 列表
- `SendQueryRuneBoxInfo()` —— 查魔盒信息

### 11.9 爬塔
- `SendSetChallengeTowerFightPartner(...)` —— 设置爬塔出战伙伴
- `SendQueryChallengeTowerFloorInfo(floor)` —— 查询指定层已通关数
- `SendDoChallengeTowerFight(floor)` —— 发起挑战
- `SendDoChallengeTowerRecall(floor, bRecall:int)` —— 回溯 / 解锁。`bRecall=1` 回溯到 1-5 层；`bRecall=0` 解锁 5 层

### 11.10 内挂配置
- `SendLoadCheatScriptConfig()` —— 拉取（拉到后客户端调用 `DecodeCheatScriptGeneralConfig`/`DecodeCheatScriptFightConfig` + `OnCheatConfigLoaded`）
- `SendSaveCheatScriptConfig()` —— 推送当前 Encode 结果到服务器

### 11.11 杂项
- `SendTansferPacket(targetPlayerId, amount)` —— 转账
- `SendRequestIncreasePortableBankSlotCount()` —— 随身仓库扩容（每次 +100）
- `SendPackage(streamOrId, ...)` —— 直接发送已构造好的数据包

---

## 12. 常用模式速查

### 12.1 监听并处理服务器自定义协议

```lua
function OnCallScriptID101(eventId, data)
    -- 在你的 OnCallScript 分发逻辑里把 101 路由到这里
end
```

`uimgr.lua` 中的 `OnCallScript` 已有约定：自动查找全局函数 `OnCallScriptID<eventId>` 并调用。新增协议只需定义同名全局函数。

### 12.2 手工拼一个发包

```lua
local s = game:PrepareSendBuffer()
s:WriteUInt32(playerId)
s:WriteUInt16(itemId)
s:WriteUInt8(count)
game:SendPackage(MSLGP_C_TYPE_XXX)
```

### 12.3 创建一个 Lua 对话框

```lua
function OnCreate(dlgmgr)
    local dlg = dlgmgr:CreateDlg("MyDlg", 100, 100, 400, 300)
    dlg:SetupCustomTipWnd(game:GetFormatTipDlg())
    dlg:SetBKImage("UIGame/Path/bg.mgff", 0, 0)

    local btn = dlg:CreateBtnCtrl("ok", 10, 10, 80, 30, 1001)
    btn:SetImage("..normal.mgff", "..active.mgff", "..pressed.mgff", "..gray.mgff")
    btn:ShowButtonName(1)
    btn:SetWndText("确定")

    -- 在 OnDlgEventProc 里通过 ctrlId==1001 + eventCode==UIEventDef.TBN_CLICKED 处理点击
    return { Raw = dlg, OK = btn }
end
```

### 12.4 监听 UI 包

```lua
local mgr = game:LuaUIMgr()
mgr:HandlePackage(0xC576)  -- 注册关心某个协议

function OnUIPackage(pkgType, stream)
    if pkgType == 0xC576 then
        local code = stream:ReadInt32()
        -- ...
    end
end
```

### 12.5 给宠物释放技能

```lua
-- 直接命令，由 GameForLua 内部做位号转换并查当前选中目标
game:CastPetSkillToFighter(-1, skillId, skillLevel)

-- 或者，手动指定目标客户端位
game:CastPetSkillToFighter(targetClientPos, skillId, skillLevel)
```

---

## 附录 A. C++ → Lua 调用方式备注

C++ 通过 `LuaPlus` 的 `LuaState::GetGlobal(name)` 找函数，再通过 `LuaFunction<RetType>` 调用。调用模板支持最多 9 个参数（多余的传 `NULL`）。所有调用都包裹在 `LuaAutoBlock` 中——异常或失败时不会破坏 Lua 栈，但会记日志。这意味着：

- **未定义的全局回调函数**会安静地走 `Reportv(50, "No lua script interface: ...")`，**不会报错**。
- 全局回调函数**不要 require 一个模块然后只在模块内监听**——如果该模块没被 `require` 入口加载，C++ 找不到它的全局函数。所有 `OnXxx` 回调都要在 `dmx.lua` 引导后的某条 `require` 路径上被定义为**真正的全局函数**（`function OnXxx(...)` 顶层声明）。

## 附录 B. 接口完整性核对

本文档基于以下源文件，覆盖了截至同步时的全部 Lua 绑定：

- `Source/apps/WAATClient/GameLuaRegister.cpp` —— 类/方法/属性注册
- `Source/apps/WAATClient/GameLua.cpp` / `GameLua.h` —— C++ → Lua 回调
- `Source/apps/WAATClient/UILuaDlg.cpp` —— UI 框架的回调
- `Source/apps/WAATClient/UIPetManualElementScroll.cpp` —— 宠物图鉴特殊收录回调

如客户端后续新增/修改了 Lua 接口，请同步更新本文档对应章节后**再合入主干**——本仓库的 lua 脚本不再阅读 C++ 源码。
