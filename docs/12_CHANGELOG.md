# 12 — 变更日志（CHANGELOG）

> 维护者：DSH（唯一有权修改本文件的人）
> 格式参考 Keep a Changelog。所有规范变更、阶段验收、素材批准均记于此。

## [Unreleased]

### ENGINE-4.7.2 通过：Godot 4.7.2 成为新基线（2026-10-04）

#### Changed
- **新基线 = Godot 4.7.2-stable**（PET-61 验收通过）：4.7.2 引擎与**完整 Export Templates** 已落 `tools/godot`（D:）与 `editor_data`（E:），旧 4.7.1 原样保留可回滚；`project.godot` 未改一个字节。GATE 9 的「模板强制项」就 4.7.2 而言已具备执行条件。
- `11_TASK_BOARD.md` → **v0.2.5**：§4.1 更新 PET-61 `ACCEPTED`、PET-63 开工、PET-62 预览待批。

#### Notes
- **DSH 独立复跑（4.7.2）**：`4.7.2.stable.official.ed1daf0bf` · unit **1402/1402** · integration **356/356** · 失败项无 · 退出码 0。
- **PET-60 处置**：崩溃已由引擎升级规避 ⇒ 转为「**已通过引擎升级规避 / 等待长期观察**」，保持 OPEN、原生崩溃记录一条未删，不再主动投入。
- **PET-62 Visual Batch 01**：三张 UI Kit 预览（MAIN MENU / PREPARATION / COMBAT）已入库 `assets/_review/pending/visual_batch_01/`，**等用户批准**后才进正式资源。

### PLAYABLE-FIRST 模式切换 + S2-02 验收 + ENGINE-4.7.2 / FIRST PLAYABLE 开工（2026-10-04）

#### Changed
- **项目模式转为 PLAYABLE-FIRST**（用户 2026-10-04 指令）：优先级 = 可玩性 > 核心玩法 > 界面与操作 > 稳定性 > 工程完美度。停止过度基础设施投入；每个 Gameplay Milestone 必须交**可运行试玩版本** + 试玩重点 + 已知问题。
- `09_TEST_STANDARD.md` → **v0.1.7**：新增 §1.1 **分级执行（L1/L2/L3）**（禁止每卡跑全量）；§5 新增「**退出期资源清点**」判定规则。
- `11_TASK_BOARD.md` → **v0.2.4**：新增 §4.1 **FIRST PLAYABLE VERTICAL SLICE**（PET-61~66）；S2-01 / S2-02 标 `ACCEPTED`。

#### Added
- **PET-61 ENGINE-4.7.2**：Godot 4.7.1 → 4.7.2 迁移 + 新基线（引擎侧规避 `0xc0000005`；上游 #122437 已由 PR #121926 / `2906aa0` 在 4.7.2 修复）。
- **PET-62 Visual Batch 01**（Codex 并行）：MAIN MENU / PREPARATION / COMBAT UI Kit，先给用户预览再进正式资源。
- **PET-63 / 64 / 65 / 66 FIRST PLAYABLE 1/4 ~ 4/4**：蓝图可编辑 → 机器运行 → COMBAT 真实 → 循环闭合。
- **S2-02（`73cc2cb`）已验收**：`BlueprintData` 落盘 / 重载往返（`CACHE_MODE_IGNORE`）。DSH 独立复跑 unit **1402/1402** · integration **356/356**，失败 0。退出期 +1 ERROR / +1 WARNING 经 `--verbose` 复核归因到 `palette.gd` / `palette.tres`（不在本卡 ALLOWED FILES 内），按 `09 §5` 不判本卡未达 DoD，登记为非阻塞缺陷。
- **PET-60 处置**：崩溃已复现 / 已定位 / 与项目代码无关 / 官方已在 4.7.2 修复 ⇒ 不再投入 4.7.1 引擎内部追因；改由 ENGINE-4.7.2 规避，PET-60 待升级通过后转「已规避 / 长期观察」。

### Stage 2 开工 · S2-01 蓝图数据模型交付并验收（2026-10-04）

#### Added
- `scripts/data/node_data.gd`、`scripts/data/connection_data.gd`（新建）：蓝图三类节点（`CORE` / `FUNCTION` / `WEAPON`）与有向边（`from_node_id` / `from_port` / `to_node_id` / `to_port`）的 Resource 数据模型，依 `03_ARCHITECTURE.md` §4.1 / §4.2；只做数据，不含 UI、玩法逻辑与图算法。
- `tests/unit/test_node_data.gd`（新建，32 条断言，含反向对照）；`tests/unit/run_tests.gd` 仅加一行登记。
- `11_TASK_BOARD.md` → **v0.2.3**：STAGE 2 由「未开始」转「进行中」，登记 S2-01 为 `ACCEPTED`。

#### Notes
- 提交 `c769120`（7 files / +132）。DSH 独立复跑：基线 `c9421c0` = unit 1338/1338 · integration 356/356；本提交 = unit **1370/1370** · integration **356/356**，失败 0，ERROR/WARNING 零增量；负向对照 4 条按名转红。

### EXTERNAL RESEARCH GATE 立规（2026-10-04）

#### Added
- `08_AGENT_RULES.md` → **v0.1.3**：新增 **§11「EXTERNAL RESEARCH GATE」**。
  凡遇 Godot 引擎错误 / 原生崩溃 / 导出失败 / 渲染器与驱动问题 / Windows 系统错误 /
  API 与 GDScript 异常行为 / 已知引擎 Bug / 工具链与第三方工具异常 / 无法解释的性能问题 /
  **测试结果与预期不符**，任何 Agent **动手前必须先联网核对公开资料**，
  并按 §11.7 的八项格式汇报；§11.8 / §11.9 为隐私与污染红线（不得下载来历不明二进制、
  上传日志前须去标识）。§11.5 明确「已有成熟方案不得重复造轮子」。
- **动因**：PET-60 的 `0xc0000005` 调查中，DSH 先行的外部检索直接改写了处置方向 ——
  该崩溃**上游已知且已修复**（随 Godot 4.7.2 / 2026-08-18 发布），
  据此**砍掉**了 HKLM LocalDumps 提权、自研 `MiniDumpWriteDump` launcher、日志目录预检查工具三项自研方案。

#### Changed
- `11_TASK_BOARD.md` → **v0.2.2**：S1-14C 结论由「未能复现」更正为「已复现（触发条件明确）＋官方已知＋4.7.2 已修复」。

#### Notes
- §11 与 §10.4 的 GATE 1–10 并行：GATE 决定「是否找用户」，本门禁决定「动手前是否已核对公开资料」。
- 本次仅**立规**，未改任何生产代码。

### Crash Investigation 结论：**未能复现** + DSH 三条结论被证伪（PET-60，2026-10-03）

#### Fixed
- `09_TEST_STANDARD.md` → **v0.1.6**：新增「在仓库上跑过 `--editor` 之后必须 `git diff project.godot` 确认」——
  编辑器**打开项目**会重写 `project.godot`，官方样板注释覆盖项目注释，并**静默丢掉 `window/stretch/aspect="keep"`**
  （实测发生在本仓库，由 DSH 的编辑器测试造成）。首选做法是编辑器测试跑在**项目副本**上。
- `11_TASK_BOARD.md` → **v0.2.1**：S1-14C 转 `ACCEPTED`（结论：未能复现），并登记待办 A/B/C。

#### Notes
- **PET-60 结论：未能复现。** 16 种配置（项目 / `--editor` / GUI / 项目管理器 × Compatibility 与 Vulkan）
  + 6000 次压力迭代（`change_scene_to_file()` 在 `_ready()` 里同步调用的误用，3 种渲染器各 3000 次）→ **零再现**。
- **最有价值的负面证据（DSH 没做、PET-60 做了）**：把 WER 的 `Faulting application start time`
  解成绝对时间 → 进程**存活 < 0.55 秒**；且那一刻**没有产生任何 Godot 日志**
  （PET-60 先用 60 次启动验证了"每次运行必然轮转 godot.log"）。→ **崩溃发生在引擎早期初始化，
  项目任何 GDScript 都还没执行 → 项目代码不可能参与。** 这一条把整类「项目代码导致」的假设一次性排除。
- **DSH 的三条结论被 PET-60 用实测证伪，全部采纳**：
  1. DSH 说 `remove_child` 那条 ERROR 是「Vulkan 路径稳定出现」——实测**与渲染器无关**，
     DSH 自己 `crash_inv/` 下 GL 与 Vulkan 四份 stderr **逐字相同**；是纯场景树时序问题。
  2. DSH 说「编辑器/项目管理器默认走 Vulkan」——实测**裸启动项目管理器走 OpenGL 3.3**，假设不成立。
  3. DSH 说 `@tool` 占位报错「热缓存为 0」——实测**冷热缓存都是 32 条**，每次都刷。
  另 PET-60 纠正一条环境事实：`tools/godot/_sc_` **并未**让引擎进入 self-contained 模式，
  `user://` 仍解析到 `%APPDATA%\Godot`（这解释了为什么必须重定向 `APPDATA`）。
- **DSH 的最强线索被证否（方法论上很干净）**：PET-60 用**12 行、零 PixelFusion 代码**的独立工程做出了
  `change_scene_to_file()` in `_ready()` 的最小复现（错误逐字一致），再用 6000 次压力迭代证明
  它在 4.7.1 上是**引擎自愈**的、不是内存破坏路径 → **不能解释 `0xc0000005`**。
  该误用仍作为代码卫生待办 A 保留。
- **`0xc0000005` 的根因仍未定位**。在拿到 dump 之前任何"根因"都只是猜测 —— PET-60 明确拒绝编造。
  唯一可执行的手段是待办 C（WER LocalDumps，`HKCU`、落 D 盘、可逆），**待用户批准**。


### ⛔ 用户报告 Godot 原生崩溃 → 开发暂停 + 建立 Crash Investigation（2026-10-03）

用户原文要点：

> 「**发现 Godot 原生崩溃，请暂停继续开发并建立 Crash Investigation。**」
> `Godot_v4.7.1-stable_win64.exe` 出现 Windows Application Error：
> `0x00007FF67E785854 指令引用了 0x0000000000000058 内存，该内存不能为 read。`
> 「这不是普通 GDScript runtime error，请不要把它当普通脚本错误处理。」
> 并给出 9 步排查顺序与 7 项汇报要求；末尾两条硬约束：
> 「**不允许通过『忽略崩溃继续开发』关闭问题**」「**未定位前不要把 Stage 1 / 后续 Stage 标为稳定**」。

#### Decisions
- **开发暂停**：根因定位前不派发 Stage 1 收尾/新功能开发；`S1-14`（GATE 9）保持 `REVIEW`，**不得置 `DONE`**；
  Stage 1 与后续 Stage 一律**不得标为稳定**。
- 建立 **Crash Investigation**（`S1-14C` / PET-60，assignee Claude），交付物是**报告**而非修复；
  若定位到根因，再另开最小修复卡。

#### DSH 先期取证（已并入 PET-60）
- 从 Windows 事件日志取到**权威签名**：`Exception code 0xc0000005`（访问违例）、
  fault offset `0x3e15854`、**faulting module = `Godot_v4.7.1-stable_win64.exe` 本体**
  （**不是**显卡驱动 DLL）；全日志中 Godot 的 Application-Error 事件**只有这 1 条**（一次性，非稳定必现）。
- **未能复现**：6 种配置（项目 / `--editor` / GUI 本体 / 项目管理器 × Compatibility 与 Vulkan `forward_plus`）
  限时后强制结束，**一个都没崩**。
- **但复现到一条真实、可重复的引擎级误用**（本卡最强线索）：Vulkan 路径 stderr 稳定出现
  `Parent node is busy adding/removing children, remove_child() can't be called at this time`，
  backtrace 落在 `game_flow.gd:159 change_scene_to_file()` ← `_commit_transition:138` ← `change_state:81`
  ← `boot_screen.gd:53 _hand_off_to_game_flow ← apply_check_result:41 ← _ready:34`
  —— 即**在 BOOT 的 `_ready()` 里同步换场景**，而 `change_scene_to_file()` 内部会立即 `remove_child`。
  这类误用正是能升级成 native 崩溃的典型。
- 步骤 4 结论：全项目**零** GDExtension / 第三方原生插件 / DLL。

#### Notes
- 另有一条需**分开定性**的事实：一个尝试处理该崩溃报告的 **DSH run 自身以 `exit status 0xc0000409`
  终止**（PET-59 15:44）。它可能与用户崩溃同源，也可能纯粹是 DSH 运行时问题 —— 不得混为一谈。


### 用户提问：S1-14 验收卡上先问「游戏文件在哪」（DSH）— 2026-10-03

用户回复（原文）：「游戏文件在哪」

#### Notes
- 用户**未给出 L4 裁决**（既非「通过」也非「打回」），按规则**只回答、不判断**：
  `11_TASK_BOARD.md` 的 S1-14 **状态不变**（仍 `REVIEW`，assignee = 用户本人）；DSH 未代判、未改看板、未派卡。
- DSH 已在 PET-59 原帖回复文件位置（源代码树 / portable 引擎 / Web 构建产物 / GitHub 远端，含打开与复跑方式）。
- 待办不变：**等用户 L4 结论**。通过 → 回填 `S1-14 = DONE` 并把「重新安装完整 Godot 4.7.1 Stable Export Templates」
  转到 Stage 2 看板持续跟踪；打回 → 逐项拆卡派发。已重新登记 `comment.created` 唤醒（只认用户本人）接住下一条回复。
- 环境备注（**与项目无关**）：DSH 本次在 agent 沙箱内无法启动引擎 —— 沙箱只允许写会话工作区，
  Godot 写不了 `%APPDATA%\Godot\app_userdata\...\logs`，启动即在 `core/io/dir_access.cpp:429` 段错误退出；
  `01_STORAGE_RULES.md` §5 的临时目录重定向在本沙箱同样被拒。**用户本机手动运行不受此限。**

### PET-58 交付复核：测试卫生 + Web 打包排除全部落地（DSH）— 2026-10-03

#### Fixed
- `11_TASK_BOARD.md` → **v0.1.9**：新增 `S1-13R` 行（`ACCEPTED`）；S1-14 置 `REVIEW`（已交用户，等 L4）；
  前面几条「已登记待办」据实结清。

#### Notes
- **PET-58 通过**（提交 `015efec`，6 文件）：① 补 `CLAMP_VIEWPORT = 120×140`，**独立推导**出余量 −4（实测 −4 对上），
  去掉夹取后恰 2 条红；② 两处失准文案改掉，`result_layout.gd` **只动注释**（3+/1−，全为 `##` 行）；
  ③ 补 `09 §3.1` 的「10 轮无节点泄漏」，用 `root.get_child_count()` + `OBJECT_ORPHAN_NODE_COUNT` 双口径、
  断言**不增长**（基线就地取，不用魔数），并内置「造孤儿 → 计数 +1 → free 回落」的**度量自证**；
  留孤儿后恰 **10 条红**；④ `exclude_filter="build/*, .godot/*, tools/*, tests/*, docs/*, assets/_review/*"`。
- **DSH 在正式树里独立复跑确认件 ④**：修复后导出两次 `index.pck` 均为 **95,712**（**Δ0**）；
  清空 `exclude_filter` 后 pck 变 **3,659,192**（38×）；按字节搜 pck，6 个禁止串**全部不存在**、
  4 个「必须仍在」串**全部存在**；产物冒烟 **36/36**。全套基线：unit **1338/1338** · integration **356/356** ·
  七套冒烟不变 · 探针 284/284。
- **PET-58 纠正了 DSH 的一条验收条件（应当采纳）**：原卡要求「断言 `res://.godot/` 不出现在 pck 里」——
  该条**在正确实现下也不成立**：Godot 4.7.1 正确导出的 pck **必然**含 `res://.godot/exported/<N>/export-*.scn|.res`
  （那是**导出器自己的**转换产物，不是本地缓存）。一刀切禁 `res://.godot/` 会让断言恒红。
  已把禁区重述为「`.godot/` 下**除 `exported/` 外**」，并把 `global_script_class_cache.cfg` / `uid_cache.bin`
  列为「必须仍在」（运行时靠它解析 `class_name`）。
- 另：PET-58 指出它新增的「必须仍在」半组断言**防的是排除过头**（比泄漏更糟）——这一方向此前没有覆盖，值得保留。


### 用户裁定：导出模板「选 B」+ 登记为 GATE 9 强制项（2026-10-03）

用户回复（原文要点）：「选 B。当前先继续开发，不因为导出模板中断项目推进。」
「将『重新安装完整 Godot 4.7.1 Stable Export Templates』记录为 GATE 9 前的必须完成项。」
「在进入正式 Web Release、Windows 打包或 Release Candidate 阶段前，再执行完整模板重装与导出验证。」
「当前不要因此阻塞 PET-58 或其他正常开发任务。」

#### Decisions
- **方针 = B**：不因导出模板中断 Stage 1 推进。
- **登记项**：**重新安装完整的 Godot 4.7.1 Stable Export Templates** —— 列为 **GATE 9 的必须完成项**；
  执行点在**进入正式 Web Release / Windows 打包 / Release Candidate 之前**，届时执行完整重装 + 导出验证。
- 已写入 `11_TASK_BOARD.md`（`S0-21` 状态与「GATE 9 强制项」说明），并同步进 S1-14 的建卡要求。

#### Notes
- 现状不变：只有 `web_debug.zip` 可用 → **debug + Threads 的 Web 导出可跑通**（PET-57 已验证）；
  **release Web 导出与桌面导出不可用**，直到模板重装。
- 本条**不阻塞** PET-58，也不阻塞 Stage 1 的后续开发。


### S1-13 交付复核 + 打包排除缺陷（DSH）— 2026-10-03

#### Fixed
- `.gitignore`：删掉 `export_presets.cfg` 那行忽略 —— 它现在是 **S1-13 的交付物**（只含相对路径与
  `variant/thread_support`，无机密、无机器相关项），**刻意入库**。PET-57 已用 `git add -f` 收编，
  DSH 复核后去掉那行会误导人的忽略规则。
- `11_TASK_BOARD.md` → **v0.1.7**：S1-13 转 `ACCEPTED`。

#### Notes
- **S1-13（PET-57）通过**：preset 落地、真跑一次 debug + Threads 导出（exit 0）、产物冒烟 **23/23**
  并带两条外部改坏的反向对照（移走 `index.wasm` → 19/21；`index.pck` 换 0 字节 → 21/23，md5 恢复后回到 23/23）；
  全套基线一条未退；「人要看什么」清单齐备（COOP/COEP 服务脚本 + 6 条肉眼项）。
- **DSH 独立确认了一个真实打包缺陷**：`export_presets.cfg` 走默认 `export_filter="all_resources"`，
  而 `build/` / `.godot/` / `tools/` 都在 `res://` 之内。**DSH 自己的导出日志逐字打出**它在打包
  `res://tools/godot/editor_data/editor_settings-4.7.tres.remap`、`res://.godot/global_script_class_cache.cfg`、
  `res://.godot/uid_cache.bin` —— 即**用户既有的编辑器设置与本地缓存被塞进了 `index.pck`**；
  且上一轮导出产物会被打进下一轮（实测 pck +29,680）。修法是加 `exclude_filter`，而
  **原卡「不要发明额外开关」那句让它无法修** —— 已在本轮明确授权，并入「测试卫生 + Web 打包排除」卡。
- **另一处如实登记（PET-57 发现，非本批引入）**：冷缓存导出会刷 64 条 `SCRIPT ERROR`
  （`palette.gd:87 resolve`：`Attempt to call a method on a placeholder instance`）。其受控对照显示
  与 preset 无关（单跑 `--editor --quit` 同样刷 32 条），热缓存为 0，**运行时不受影响**（全套套件全绿）。


### S1-12 交付复核 + 导出模板截断（DSH）— 2026-10-03

#### Fixed
- `09_TEST_STANDARD.md` → **v0.1.5**：`§5` 的「无 Godot 报错 / 无 warning 新增」补一条**例外** ——
  由**被断言的负路径用例**主动触发、且在报告里**逐条点名**的报错 / warning **不算新增**。
  不设例外则 `§4`（要求反向对照、故意走错误分支）与 `§5` **互相打架** —— S1-12 的 10 轮负向探针必然带来 warning 增量。
- `11_TASK_BOARD.md` → **v0.1.6**：S1-12 转 `ACCEPTED`；S1-13 转 `IN_PROGRESS`；S0-21 由 `TODO` 改 `PARTIAL`。

#### Notes
- **S1-12（PET-56）通过**：integration 由 **19 → 333/333**；unit 1331/1331；七套场景/输入冒烟全部等于基线；
  探针 284/284。三条性质**各带反向对照**（改坏后分别红 80 / 8 / 53 条），且 `game_flow.gd` 用 `--exit-code`
  核对过**逐字节还原**。既有断言一条未删（含 `end_run` 幂等那两条）。
- **一处如实记下的缺口**：`09 §3.1` 明写「循环 10 次**无内存/节点泄漏**」，交付里**没有任何泄漏断言**。
  PET-56 声称 `§3.1` 语义「被完全覆盖」，该说法**只对循环次数成立**。已并入「测试卫生」卡，落地后补记。
- **导出模板截断（环境问题，需用户关注）**：用户既有的
  `%APPDATA%\Godot\export_templates\templates.tpz` **本身是截断的**（995.4 MB；缺 `web_release` /
  `web_nothreads_release` / 全部 `windows_*` 条目）。DSH 从中抢救出唯一有效的 **`web_debug.zip`**，
  装入 portable 引擎的 `editor_data\export_templates\4.7.1.stable\`（落 E:，符合 `01 §11`）；
  `web_nothreads_debug.zip` 已损坏（`End of Central Directory record could not be found`）。
  → S1-13 只能做 **debug + Thread Support 开启**的 Web 导出；**release Web 导出与桌面导出当前不可用**。


### PET-55 窄屏取样收尾落地 + 新登记待办（DSH）— 2026-10-03

#### Fixed
- `tests/unit/test_combat.gd`：`SHORT_NARROW_VIEWPORT` 由 `Vector2(180.0, 120.0)` 统一为 `Vector2(120.0, 180.0)`；
  `EXPECTED_SHORT_NARROW` 按 `06 §7.1` 在 `120×180` 上**重导**为 `[(0,0,120,135), (0,135,120,45)]`；
  新增只给 COMBAT 的 `TIGHT_NARROW_VIEWPORT = Vector2(120.0, 160.0)`（窄屏 0.75、且比基准矮 → 状态带
  `min(45, 40) = 40 < 45`），并新增两条钉住「25% 上限真的生效」的断言。
- `tests/unit/test_reward.gd` / `tests/unit/test_result.gd`：同一常量统一为 `120×180`，并修掉随之失准的注释。

#### Notes
- **补齐了本文件此前登记的「窄屏取样轴序写反」待办**（PET-54 发现 / PET-55 完成）。该缺陷被**两层**掩盖：
  ① 三个单元测试直接调 `layout.*_rects()`，**绕开了 `is_narrow` 这道闸**；
  ② 纠正轴序之后 `120×180` 与基准**同高**，`min(45, 45) = 45`，25% 上限**仍然咬不住** ——
  亦即这一案**从来没有测过它注释里自称要测的那个东西**。现由 `TIGHT_NARROW_VIEWPORT` 补上。
- **新登记待办**：`scripts/ui/result_layout.gd:126` 的 `maxf(bottom - readout_top(), 0.0)`「夹到 0」分支
  **至今没有任何取样触发**（`120×180` 下读数区仍剩 36px；实测需 `120×140` 才会夹到 0），
  故 `readout_rect(...).size.y >= 0.0` 这条断言对现有三个取样**恒真**。与本轮修掉的是**同一类问题**。
- 另有若干**已失准但不在该卡允许清单内**的字符串，另行清理：`tests/integration/combat_smoke.gd:33-37`、
  `scripts/ui/result_layout.gd:122`。


### S1-11 交付复核 + 全局类缓存假红规则（DSH）— 2026-10-03

#### Fixed
- `09_TEST_STANDARD.md` → **v0.1.4**：新增验证纪律 —— **新增带 `class_name` 的文件后，必须先 `--headless --import`
  刷新 `.godot/global_script_class_cache.cfg`，再跑套件**。该缓存不受 `git checkout` / `cherry-pick` 影响，
  会让既有脚本 `extends` 新类时全线 `Parse Error: Could not find base class`，表现为**环境假红**。
  同时写明判别特征（失败面大得不合理、**总断言数骤降**）与「打回前必须有受控对照」的反向纪律，
  以及新脚本的 `.gd.uid` 必须随提交入库。
- `11_TASK_BOARD.md` → **v0.1.4**：S1-11 由 `IN_PROGRESS` 转 `ACCEPTED`。

#### Notes
- **本轮差点误打回。** DSH 在工作树里直接复跑，6/6 场景冒烟全红、探针 284 → 68，一度判为「严重回归」。
  根因是上述缓存未刷新（`.godot/` 早于新脚本）。刷新后**全绿**：unit 1327/1327 · integration 19/19 ·
  六场景冒烟 544 · input_smoke 41/41 · 探针 284/284，0 失败、0 `SCRIPT ERROR`。教训已写进 `09 §4`。
- **交付卫生（须避免的模式）**：PET-53 交付时报称「工作留在 `agent/claude-lead-developer/817a02e05277`」，
  但那个分支上**没有任何提交** —— 16 个文件全是 worktree 脏改动。因重新派发的 Agent 会拿到**另一个克隆**
  （看不到该工作），DSH 只能代为提交（`114dc4f`）。**交付必须包含一次真实提交**，否则「交付」只是工作树里的临时状态。


### 规范一致性修复：`03 §8` 触摸口径 + `11` 任务板状态回填（DSH）— 2026-10-03

#### Fixed
- `03_ARCHITECTURE.md` → **v0.1.2**：`§8` 原文「触摸目标最小命中尺寸 **44×44 px**（逻辑像素，按缩放换算）」是
  `06 §1` 已明确废弃的自相矛盾写法（`06 §1` 现为 **44×44 设备像素（物理）** = 2× 缩放下 22 逻辑像素、4× 下 11 逻辑像素）。
  `03` 当时漏改，现按 `06 §1` 对齐，并补上「触摸平台最小缩放 ≥ 2×」的推论；明确本节**不另立口径，数值以 `06 §1` 为准**。
- `11_TASK_BOARD.md` → **v0.1.3**：任务板状态长期未回填 —— S1-06~S1-10 七个场景（PET-40 / PET-42 / PET-43 / PET-45 / PET-48，
  以及 PET-47 的 COMBAT 状态带修订）**均已交付并进入 in_review**，板上却仍写 `TODO`。现按平台真实状态回填为 `ACCEPTED`；
  S1-01~S1-04 的 `DONE` 一并改为 `ACCEPTED`（`§1` 状态定义中 `DONE` 专属**用户 L4 验收**，尚未发生）。
  另补两行收尾修复 `S1-08R`（PET-50）/ `S1-09R`（PET-52），S1-11 置 `IN_PROGRESS`，依赖由 S1-07 改为 S1-10。
- `12_CHANGELOG.md`（本文件）：补记 Stage 1 的 L2/L3 验收行 —— 此前 `验收记录` 只有 Stage 0 一行，而 10 个 Stage 1 子任务早已进入 `in_review`。

#### Notes
- **新登记待办（窄屏取样轴序写反）**：`tests/unit/test_combat.gd:38`、`tests/unit/test_reward.gd:28`、
  `tests/unit/test_result.gd:27` 的 `SHORT_NARROW_VIEWPORT` 仍是 `Vector2(180.0, 120.0)`。
  `CombatLayout.is_narrow()` 的判据是 `viewport_size.x / viewport_size.y < NARROW_ASPECT_MAX`（`NARROW_ASPECT_MAX = 1.0`，
  见 `combat_layout.gd:31/39`），故 `180×120` 宽高比 1.5 → **判为宽屏**，与常量名及用例意图相反；
  `tests/integration/combat_smoke.gd:38` 已是正确的 `Vector2(120.0, 180.0)`。
  三个单元测试直接调 `layout.*_rects()`，**绕开了 `is_narrow` 这道闸**，所以该缺陷不会被自己发现。修法：三处统一为 `120×180`。
- **自记（本次写入事故）**：本条目首次写入时用 `String.Replace` 定位，而 `## [Unreleased]` 在正文中另有 3 处**行内引用**，
  `Replace` 是**全量替换** → 条目被插入 4 次，其中 2 次切断了两行正文。已 `git checkout` 还原后用**行首锚点**重写。
  教训：文档手术的锚点必须带边界（前后裹换行）或按行匹配，不得依赖「子串在全文中唯一」。
- **自记（二次更正）**：本条目初稿把场景冒烟合计写成「七场景 663」。场景冒烟实际只有 **6 个**
  （BOOT 31 / MAIN_MENU 67 / PREPARATION 86 / COMBAT 103 / REWARD 165 / RESULT 92），合计 **544**。已更正 —— 数字不能凭印象写。


### Codex 裁定写回：RESULT 版面 + 次级面板阴影方向（PET-51）— 2026-10-03

#### Fixed
- `06_UI_UX_STANDARD.md` → **v0.1.12**：
  ① 新增 **§9.2 RESULT 布局规格**（`06` 此前**没有** RESULT 版面规格，S1-10 由执行者提案，Codex 裁定接受现状并升为正式规格）：
  16px `PanelTitleBar` / 次级面板 **304×88** 读数区 / 两个 **148×44** 出口 / 间距与安全边距**一律 8** / 窄屏 180×320 竖排宽 164；编号用 §9.2 以免牵动既有 §10 引用。
  ② **§2.2 阴影行收紧**：次级面板的「同」明确为「**同，且由独立 `PanelShadow` 场景叠层实现**；**铺满视口的 shell 例外**」。
  ③ **§9.1 补一句**：REWARD 选项卡是浮动次级面板，**应带 `PanelShadow`**；§7.2 ⑤ 的「整屏外壳不补」**不得外推**到卡片。

#### Decisions
- **次级面板阴影方向裁定选 (A)**：浮动次级面板**都要**阴影、由独立 `PanelShadow` 叠层承载。
  依据不是偏好，而是规范自身：§2.2 已把次级面板阴影写成「同」，且同节已裁定实现方式为**场景组合**（面板自身不带阴影）。
  → **RESULT 读数区保留现状；`scenes/reward/reward_card.tscn` 需补 `PanelShadow`**（已派最小修复）。
- RESULT 版面**代码现状不变**（常量与场景 offset 一个字都不动）。

#### Notes
- Codex 再次逐字引用版本行（`版本 **v0.1.11**`，与磁盘一致）—— 版本行规则**连续第五轮**生效。
- **风险已知会带出**：给 REWARD 卡补阴影后，**像素探针期望必须同步更新**；
  且 `Shadow` 子节点**必须排在内容 `Layout` 之前**，否则会盖住文字（已写进 §9.1 与修复卡）。


### Codex 裁定写回：`06 §9` REWARD 选项卡观感（PET-49）— 2026-10-03

S1-09 上报三项 §9 未覆盖的观感判断，Codex **三项全部确认现状**。它再次逐字引用了版本行
（`版本 **v0.1.10**`，与磁盘一致）—— 版本行规则**连续第四轮**生效。

#### Fixed
- `06_UI_UX_STANDARD.md` → **v0.1.11**：新增 **§9.1**，把三条裁定写成正文：
  ① 选项卡**保持 `PanelSecondary`**（`NAVY_800` + 1px `BROWN_600`），**不另设奖励专用蓝底** ——
  改成 `NAVY_700` 会让所有选项默认像「已抬升/激活」，削弱 hover/selected 的辨识度；
  ② 「跳过」图标色**确认 `GREY_500`**（不是类型，不得借类型色；可读但退后，语义接近次要/禁用）；
  ③ 16×16 图标与「短名词 + 数值/单位」占位串形态确认。

#### Decisions
- **三项均无需改代码**，记录为「已符合」，未派发修复任务。
- 新增**给 Stage 4 的接口约束**：`RewardOption(kind, name_key, type_key, value_key, rule_key)` 形状保持，
  S4-07 负责把真实 `RewardData` 映射成**已格式化**的显示 key/string，
  **`reward_card.gd` 不得承担数值计算或单位拼装** —— 这条现在写进规范，避免 Stage 4 把格式化逻辑塞进 UI 层。
- 可选收紧（未强制、未派发）：把「跳过」的测试从「不与类型色混同」升级为直接钉 `GREY_500`。

#### Notes
- 本轮由 **30 分钟兜底巡检**发现 PET-49 已交付为 `in_review` 而其条件唤醒尚未触发，
  处理完后**主动停用了该条唤醒**，避免重复起一次运行（与 PET-46、PET-47 同样的处置）。


### 并发纪律收紧：宽通配 `ALLOWED FILES` 视为相交（2026-10-03）

#### Fixed
- `08_AGENT_RULES.md` → **v0.1.2**：新增 **§4.1**。起因是 DSH 在 S1-09（REWARD）运行期间又派发了 S1-08 的状态带修订，
  两者都声明了 `tests/**` —— 按 §4「两个并行任务的文件集不得相交」的字面规则，**这是一次违规派发**。

#### Decisions
- **宽通配（`tests/**` / `scripts/ui/**` / `scenes/**`）在并发布局中一律视为相交**；修复类任务的 `ALLOWED FILES`
  必须列到**具体文件**。
- 两个 Agent 同写一个工作树时，即使文件不重叠，`git add`/`git commit` 也会争用 **index 锁**，
  失败形态是可恢复的 `index.lock` 错误而**不是仓库损坏**；但 DSH **必须**在复审时核对两个并行批次的提交文件清单是否真零重叠。
- 列不出具体文件、或确实需要同一批文件 → **串行化**：后一批先建为 `backlog`，前一批交付后再提 `todo`。


### Codex 裁定写回：`06 §8` 状态带信息结构（PET-46）— 2026-10-03

S1-08 实现时由 Claude 拟定状态带占位内容并主动上报（它明确标示这是本批唯一由它拟定的观感内容）。
Codex 的裁定**与已实现冲突**，故本轮同时产生**文档修订 + 一个最小修复项**。Codex 再次逐字引用了
`06_UI_UX_STANDARD.md` 的版本行（`版本 **v0.1.9**`，与磁盘一致）—— 版本行规则连续第三轮生效。

#### Fixed
- `06_UI_UX_STANDARD.md` → **v0.1.10**：新增 **§8.1 状态带的信息结构与占位文案**，把裁定写成正文：
  **5 个只读读数块**（`波次` / `CORE` / `热量` / `能量` / `队列`），并立四条硬规则 ——
  ① `热量` 与 `能量` **禁止合并**（Heat 橙 / Energy 蓝语义不同，合并后告警读不出是哪个系统在报警）；
  ② CORE 用可比较的百分比而非自然语言状态词；③ 全部为只读 Label，禁止任何要求玩家在 COMBAT 期间即时反应的控件；
  ④ 宽度不足时缩短 caption，**不得删字段、不得把 Heat/Energy 压回一格**。

#### Changed（代码修复项，已派发）
- `scenes/combat/combat.tscn` 的读数区由 **4 格改为 5 格**：`热量 / 能量` 拆成两个相邻读数块，CORE 文案 `完好` → `100%`。
  **不动** `scripts/ui/combat_layout.gd` 的几何常量（几何已独立复跑验收通过）。

#### Notes
- 本轮由 **30 分钟兜底巡检**发现：PET-46 已交付为 `in_review`，但其条件唤醒尚未触发（`next_fire_at` 已过）。
  DSH 处理完后**主动停用了那条条件唤醒**，避免重复起一次运行。
- **变更日志结构修复**：本文件此前出现**两个 `## [Unreleased]` 标题** —— 原因是 DSH 的插入写法
  `replace("## [Unreleased]\n", entry + "## [Unreleased]\n")` 会在插入新条目的同时**把原标题一起留下**。
  已合并为单一标题，并把该写法改为「只插正文、不重复标题」。


### Codex 裁定写回：`06 §7` 五项读数与几何（PET-44）— 2026-10-03

S1-07 上报 5 项 `06 §7` / `§7.1` 的读数与几何问题。Codex 在裁定中**附了 CONSTRAINT CHECK 并逐字引用版本行**
（`版本 **v0.1.8**`，与磁盘一致）—— 版本行规则再次生效。

#### Fixed
- `06_UI_UX_STANDARD.md` → **v0.1.9**：新增 **§7.2 读数澄清**，把五条裁定写进规范正文：
  ① `64×14` 是**参考图亮色区块**读数、**不是 Button 最终矩形**；中文按钮实机为 `x 246–310 / y 142–162`（向上扩展到 20px），
  **禁止**为塞进 14px 而缩字号或换文案；② 三栏顶边 `y=8` 确认；③ 窄屏弹层 = 视口 1/3 确认；
  ④ CTA 比底条右边外溢 1px —— **两组都是实测事实，不得为对齐而改**，遮挡按实机画面处理；
  ⑤ 整屏外壳**不补** `PanelShadow`（它是浮动面板的方案，整屏外壳没有可用的右下偏移空间）。

#### Decisions
- **代码现状保留，未派发修复任务** —— 五项裁定全部确认现有实现，本次是**纯文档消歧**。
- 采纳 Codex 的风险提示：把「亮色区块 vs Button 控件」的区分**写进 §7.2 正文**，
  否则后续实现者会再次把按钮压回装不下中文的高度。裁定不能只活在评论里。

### Codex 裁定写回：`06 §2.2` 三项读数澄清（PET-41）— 2026-10-03

S1-06 实现时 `06 §2.2` 出现三处读数歧义。Claude **没有自行拍板**，按项目分工交 Codex 裁定；
Codex 在裁定中**逐字引用了它读到的版本行**（`版本 **v0.1.7**`），与磁盘一致 —— 未重演此前的过期快照问题。

#### Fixed
- `06_UI_UX_STANDARD.md` → **v0.1.8**：§2.2 新增「读数澄清」小节，把三条裁定写进**规范正文**（不留在评论里）：
  ① 标题栏 16px **包含**底部 1px 金线；② 内容缩进 12px 从**内芯外沿**量起（从面板矩形读作 15px）；
  ③ `.tscn` 字面量允许，但必须由测试对常量公式断言。

#### Decisions
- **三项裁定全部确认当前实现，无需改代码** —— 已记录为「已符合」，未派发修复任务。
- 新增**联动修改规则**：改 ① 或 ② 时，常量、`.tscn` 字面量、测试期望必须三处同改，任一单独改动都应让探针报红。

#### Notes（提交卫生事故，自记）
- 本次「`docs(06)` 裁定写回」的提交 `a38564d` 使用了 `git add -A`，结果**同时纳入了 Claude 当时正在进行的 S1-07 半成品**
  （`scenes/preparation/**`、`scripts/ui/preparation_*.gd`、`tests/unit/_measure_tmp.gd`），
  于是**提交信息与内容不符**。这是同类失误的第二次（第一次是 PET-39 交付被混进 `docs` 提交）。
- **已推送，因此不改写历史**（不对共享远端做 force-push）。后续 Claude 的正式提交会覆盖这些文件内容，功能上无影响。
- **纪律修正（立即生效）**：只要其它 Agent 的工作区**可能有未提交产出**，
  DSH 的文档类提交**一律逐路径 `git add <具体文件>`，禁止 `git add -A`**。

#### Notes
- Codex 报备：它在自己的 checkout 里**看不到** `tests/output/render_probes.log`，
  因为 `.gitignore` 排除了 `*.log`。日志是本地可再生产物，**不影响裁定成立**，
  但意味着外部审查者无法直接复核像素取证日志 —— 记下备查。

### 文档陈旧项修正（PET-39 报备，DSH 执行）— 2026-10-03

PET-39 交付时报备了两处**指向已删文件**的规范条目（`docs/**` 仅 DSH 可改，故它未擅动）。

#### Fixed
- `09_TEST_STANDARD.md` → **v0.1.3**：§4 的两条探针命令（`render_shadow_probe.gd` /
  `render_highlight_probe.gd`）本批已合并为单一聚合入口，命令改为
  `--script res://tests/unit/run_render_probes.gd`，并补修订说明。
- `06_UI_UX_STANDARD.md` → **v0.1.7**：§2.2 末尾的实测依据指针由已删的 `render_shadow_probe.gd`
  改为 `run_render_probes.gd`。

#### Decisions
- `12_CHANGELOG.md` 中提及旧文件名的**历史条目保持原样**：变更日志是只追加的历史记录，
  改历史会让「当时到底改了什么」失真。陈旧引用只在**规范性文档正文**里修正。

#### Open（已授权，交由 Claude 在 PET-39 内完成）
- `scripts/core/data_registry.gd` 的 `list_ids()` 契约违反（`Array[StringName].sort()` 比的是驻留指针而非字典序），
  一行修法已授权并入本批。
- `scripts/data/palette_theme.gd:127` 注释仍指向已删的 `render_shadow_probe.gd`。
- `tests/unit/run_tests.gd` 报告表头硬编码任务号，应改为运行期传入。

### S1-A 骨架交付的规范裁定与修正（2026-10-03 第十二轮）

PET-38（S1-A：`project.godot` + 五个 Autoload + 六状态机 + Palette/Theme）回报中列出 5 项偏离。
本节记录 **DSH 的逐条裁定**。改的**全部是规范文档**，未触碰任何代码，不改变任何玩法方向。
（依 `08_AGENT_RULES.md` §2 权限矩阵，`docs/00`~`10` 只有 DSH 可改；
执行 Agent 的 PET-38 任务卡把 `docs/**` 列为 FORBIDDEN —— 那是**约束执行 Agent**，与 DSH 行使文档权限不矛盾。）

#### Changed（规范修正，3 个文档）
1. `06_UI_UX_STANDARD.md` → **抬头补正为 v0.1.3**（正文一个字节未改）。
   抬头原写 `v0.1.0`，但正文 §2（三层 Panel）、§4（24×24 节点卡）、§12.2（自相关测量）早已是
   v0.1.3 的内容，任务卡也写 v0.1.3 → 判定为**只改正文忘了抬头**。
2. `03_ARCHITECTURE.md` → **v0.1.1**
   - **§1.1 R2 冲突**：原文称 `COMBAT → REWARD` 可由「本波清空」**或「CORE 摧毁」**触发；
     这既与同一文件 §1 状态图（CORE 被摧毁 = 局内进程终止 → `RESULT`）冲突，
     也与 `09_TEST_STANDARD.md` §3.4（「CORE 被摧毁 → `RESULT`」）冲突。
     按 `08 §7` 冲突优先级（项目约束文档 `docs/00~10` > 架构文档）裁定：
     **CORE 摧毁 / 终局条件 → `COMBAT → RESULT`**；`COMBAT → REWARD` 只由「本波清空」触发。
     §1 状态图同步补上 `COMBAT → RESULT` 这条终止边。
   - **§1.1 R3 措辞**：原文要求「必须通过 `change_state()` 单一入口」。照字面实现，
     就必须把 `COMBAT` 放进 `PREPARATION` 的合法迁移表 —— 那会让**任何模块**无需玩家动作即可推进到 `COMBAT`，
     直接违反 R1 与 `06 §10.2`（违反即打回）。改为「单一**提交点**」：通用入口 `change_state()`
     ＋两个玩家动作语义入口 `request_start_combat()` / `request_end_run()`，三者汇入同一提交点并发信号。
3. `01_STORAGE_RULES.md` → **v0.1.2**
   - **§4**：把 `APPDATA` / `LOCALAPPDATA` 从「风险提示」升级为**强制注入项**
     （原强制清单只有 `TEMP` / `TMP` / `TMPDIR`）。
   - **§5.2 事实错误修正**：原文称自包含模式「会把编辑器数据与工程 `user://` **两者都**重定向」。
     S1-A 实测推翻：`._sc_` 标记**只重定向编辑器数据**；工程 `user://` 仍由 `OS::get_data_path()`
     解析 `%APPDATA%` 决定，落到 C 盘。

#### GATE 7 复核（S1-A 期间发现的 C 盘写入）
- 现象：portable 引擎以 `--headless --script` 运行时，工程日志出现在
  `C:\Users\20703\AppData\Roaming\Godot\app_userdata\{PixelFusion,gtest}\logs\`（共 7 个日志文件）。
- 成因：即上述 §5.2 的规范错误 —— `_sc_` 不覆盖工程 `user://`，而 §4 的强制变量清单里没有 `APPDATA`。
- 处置：执行 Agent 按 `01 §6` 四步走完（停止 → 定位 → 重定向 → 清理）：两个目录已删，
  同级其余 12 个用户既有目录**未被触碰**；注入 `APPDATA` / `LOCALAPPDATA` 后复跑，
  C 盘 `app_userdata` 零新增，测试结果不变（369/369 + 19/19）。
- **DSH 判定**：这不属于「工具无法避免写 C 盘」，而属于「规范漏了一条强制变量」。
  已按上述 §4 / §5.2 补正，故**不构成 GATE 7 的持续阻塞，无需用户裁定**。

#### Accepted（判为实现约束下的必要偏离，规范不动）
- `04 §6` 的签名 `static func get_color(key: Key) -> Color` 与 Godot `@GlobalScope` 的键盘枚举 `Key` 撞名；
  跨脚本调用必须写全 `Palette.Key`。签名语义与 §6 完全一致，只是类型限定符必须写全 → **接受**。
- `scripts/data/palette_theme.gd` 落在 `scripts/data/` 而非 `scripts/ui/`：S1-A 的 ALLOWED FILES 未含
  `scripts/ui/**`，未越界建目录是对的；Theme 是「由 Palette 装配出的资源」，`data` 不依赖上层
  （`03 §10`）→ **保留**。

#### Pending（遗留，另批处理）
- **抬头「（待用户批准）」全量过期**：GATE 1 已于第七轮关闭、`docs/00`~`12` 已成为生效契约，
  但 01 / 02 / 03 / 04 / 06 / 08 / 09 / 10 的抬头仍写「（待用户批准）」。本批只改版本号，
  状态串留给一次专门的文档卫生批次统一处理，避免与本次裁定混在一起。
- **S1-A 的 L2 / L3 验收记录**：Codex 已给出视觉审查结论（见下），但结论带 **2 项需实现方处理**，
  验收**未结案**；待修复并复评后记入本文件。

#### Codex 视觉审查结论（2026-10-03，同日）

Codex Visual Reviewer 对 `scripts/data/palette_theme.gd` + `assets/ui/theme_main.tres` 做静态视觉合规审查（只读，未改代码）。

**通过项**
- Button 五态与 `06 §3` **逐值相符**（Normal `GOLD_500`/`GOLD_600`，Hover `GOLD_400`/`GOLD_500`，
  Pressed `GOLD_600`/`GOLD_600`，Disabled `NAVY_800`/`NAVY_600`，文字 `NAVY_900`；`Selected` 走 Theme 的 `focus` 路径）。
- 辅助按钮 `NAVY_700` / `NAVY_600` / `GREY_300` 与 §3 相符。
- Label 三档 `BLUE_100` / `GREY_300` / `RED_400` 与 `04 §5.1` 的正文首选 / 正文 / 小号危险文字相符。
- Panel 已有取值相符：外框 3px、内芯 `NAVY_800`+`NAVY_600`、次级 `NAVY_800`+`BROWN_600`。
- `theme_main.tres` 字面色值检索命中 **0**（`Color(` 与 `#RRGGBB` 均为 0）。
- **字体维持不设**：`06 §1` 明文「待 Codex 选定并经用户批准」，现在选型属新视觉方向，须走用户审批（`08 §10.5`），不得直接落资源。

**裁定：外框填充/描边分工（已写回 `06 §2.1`，`06` → v0.1.4）**
`BROWN_600` 作**填充**、`BROWN_500` 作**描边**。依据 `04 §3.5`：`BROWN_600` = 深木结构、`BROWN_500` = 工坊外框/木质结构；
暗色作体块、亮色作边线，更符合像素 UI 的「体块—边缘分离」。
> 此前 `06 §2.1` 只写「主体 `BROWN_600` / `BROWN_500`」，未指认分工 —— 这正是本轮多绕一圈的原因，故把裁定写回规范本体。

**需实现方处理的两项（已派 Claude）**
1. **`06 §2.1` 第三层「高光」在 Theme 中无落点**：`palette_theme.gd` 全文无 `GOLD_200` / `BLUE_300`。
   已定为必须补 —— 规范标「（强制）」的层不能只在文档里存在；具体 Theme 机制属实现细节，由 Claude 定。
2. **`06 §2.2` 右下 1px `NAVY_900` 硬阴影**：Codex 认为 `shadow_size = 0` 使阴影无实际厚度。
   **DSH 判定此项存疑，不得靠读代码定案**：Godot 至今**没有关闭阴影模糊的开关**
   （godotengine/godot issue #96667 / PR #98162），即 `shadow_size > 0` 才更可能引入模糊；
   若如此，`shadow_size = 0` + `shadow_offset = (1,1)` 恰恰就是规范要的「不模糊 1px」。
   已要求**能跑引擎的一方实测取证后二选一**，任一方向都必须附证据。

**遗留风险（带入 S1-05 / S1-06）**
Button `Selected` 目前借用 Theme 的 `focus` 路径表达。正式场景接入时必须确认「当前选中项」确实走该路径，
否则主题里的值虽正确却不会在场景中生效。

#### 硬阴影取证：Codex 的 finding 2 成立，DSH 的反假设被实测推翻（2026-10-03，同日）

DSH 曾把该 finding 判为「存疑」，理由是 Godot 没有关闭阴影模糊的开关，
故推断 `shadow_size = 0` + `offset` 可能正是「不模糊」的解。
**执行方用像素级实测推翻了这个推断**（`StyleBoxFlat` 画进 24×24 `SubViewport` 后逐像素读回，
判据色直接用生产色值本身，故无需主观判断）：

| 配置 | 右缘像素（y=8 横扫） | 结论 |
|---|---|---|
| `shadow_size = 0`，`offset = (1,1)` | 全为背景色 | **一个阴影像素都没有** |
| `shadow_size = 0`，`offset = (3,3)` | 全为背景色 | `offset` 在 `size = 0` 时**完全无效** |
| `shadow_size = 1`，`offset = (1,1)` | 1px 精确 `NAVY_900` + 1px 50% 羽化 | 有阴影但**必带模糊** |
| `shadow_size = 2`，`offset = (1,1)` | 1px 精确 + 2px 渐隐 | 羽化带宽 = `shadow_size` |
| `border` 右下 1px + `expand_margin` 右下 1px | **精确 1px `NAVY_900`，零羽化** | ✅ 唯一同时满足「1px」与「不模糊」 |

- 羽化像素值可复算：`0.5 × 0.0588 + 0.5 × 0.9686 = 0.5137`，恰为 50% alpha，不是阴影色本身。
- 三个渲染后端逐像素一致；`ClassDB` 属性表里与阴影相关的只有 `shadow_color` / `shadow_size` / `shadow_offset` 三项。
- **结论**：`shadow_size` 同时决定「有没有阴影」与「羽化带多宽」，引擎内**不可解耦** → `shadow_*` 整条路出局。
- **DSH 记录自己的错误**（同 `04 §5.1` 的做法）：上轮要求「先取证」的方向是对的，但**我的推断本身是错的**。

#### 裁定：硬阴影用场景组合（`06 §2.2` → v0.1.5）
`StyleBoxFlat.border_color` 为单值、四边共用，三个面板 stylebox 的描边色已占满，
故 `NAVY_900` 硬边只能作为**独立叠层**存在。裁定 **(甲) 场景组合**：`PanelShadow` 叠层
（右下 1px `NAVY_900` + `expand_margin` 外推），面板自身不带阴影，S1-05 接线。
**否决 (乙)**：让外框右下各多 1px `BROWN` —— 既改掉规范指定的 `NAVY_900`，
`BROWN` 深边压在 `BROWN` 外框上也读不出阴影。已写回 `06 §2.2`。

#### 高光层已落地（`06 §2.1` v0.1.4 要求）
新增 `PanelHighlight`（1px `GOLD_200`）与 `PanelSelected`（1px `BLUE_300`）两个类型变体，
均为 `draw_center = false` 的 1px 描边叠层；`BLUE_300` 按裁定**始终留在 Theme**。
测试新增「扫遍 Theme 全部条目、确认两个 Token 真被引用」的断言，而非只查常量。
`palette_theme.gd` 字面 `Color(` 构造数为 **0**。

#### 测试规范新增一条反「空实现断言」规则（`09 §4` → v0.1.1）
本轮暴露一个**新的失效模式**：`test_theme.gd` 曾断言「阴影不得模糊」，
而 `shadow_size = 0` 让该阴影**从不显形** —— 结构性断言全绿，像素层从未验证。
`09 §4` 据此新增：规范要求**可见结果**时，至少要有像素级 / 渲染产物证据，只断言配置字段值不算。

#### 验收记录（10 §7）
| 日期 | 阶段/任务 | 等级 | 结论 | 打回原因 | 验收人 |
|---|---|---|---|---|---|
| 2026-10-03 | S1-A（PET-38）骨架：`project.godot` + 五个 Autoload + 六状态机 + Palette / Theme | L1 自测 + L2 规范审查 + L3 测试审查 | **通过** | 无 | DSH |

- L1：单元 369 → **408**（+39），集成 19/19；新增 `tests/unit/render_shadow_probe.gd`（需真实渲染路径，**不进**常规回归）。
- L2：`04 §3` 35 Token 名称与顺序逐字一致；`scripts/**` 字面 `Color(` 构造数 0；`theme_main.tres` 零色值；`docs/**` 由执行方零改动。
- L3：以执行方实际跑出的计数为准，DSH 不重跑（`08 §2`）。
- `01 §4` v0.1.2 新增的 `APPDATA` / `LOCALAPPDATA` 强制项**实测有效**：本轮 5 次真实渲染运行，C 盘 `app_userdata` 零新增。

**非阻塞后续项（全部转 S1-05；S1-A 本身无遗留）**
1. `PanelShadow` 接线（需 `scenes/**`，不在 S1-A 的 ALLOWED FILES 内）。
2. 把两个像素探针合并为单一入口 `tests/unit/run_render_probes.gd`（`09 §4` v0.1.2 已登记为待办）。

#### S1-A 收尾交付（2026-10-03，同日）

- `06 §2.1` v0.1.6 的边数裁定已落实：`PanelHighlight`（`GOLD_200`）**仅上/左**，`PanelSelected`（`BLUE_300`）**四边整圈**；
  两者是**各自独立的 `StyleBoxFlat` 实例**，改一处不会连带另一处（Codex 点名的风险已规避）。
- 测试断言按变体拆分为 `_check_highlight_warm` / `_check_highlight_ring` / `_check_highlight_common`
  （公共部分**刻意不含边数** —— 边数正是两者唯一差异）。
  **反向对照已验证判别力**：把暖高光改回四边整圈 → 单元 388/390，失败 2 条精确指名右/下描边宽。
- `_panel_box()` 的阴影死配置已清，`HARD_SHADOW_OFFSET` 常量随之删除。
- 新增 `tests/unit/render_highlight_probe.gd`：按 `09 §4` 以**像素级证据**验证边数；
  探针不设 stylebox override，经 `theme_type_variation` 走 Theme 解析，故同时验证「变体落点可用」。
  **该探针首版自身坐标写错，字段层 390 条断言全绿，只有像素图暴露了问题** —— 再次印证 §4 的必要性。
- 回归：单元 **390/390**、集成 **19/19**、失败项无。

**DSH 对执行方三项待裁定项的答复**

1. **探针不进常规回归 → 成立，但规则不能只写在纸上。** `09 §4` 已升级 **v0.1.2**，
   补上编排契约：触发条件（改 Theme / StyleBox / 视觉 Token 的批次，或要宣称视觉结果已实现的批次）、
   「探针必须自证判别力」、执行者（改动方自测必跑 + DSH 在 L2 核对）与逐条命令。
   合并入口 `run_render_probes.gd` 已登记为 **S1-05 批次待办** —— 不为它单独跑一轮。
2. **两处 `shadow_size = 0`：保留，不重开。** 它们是无行为影响的显式默认值声明，
   与测试中保留的 `shadow_size == 0` 护栏一致；为零行为变化再跑一轮引擎回归不符 `01 §10.2 / §10.3` 的纪律。
   本项目**不把「显式写默认值」当缺陷**，只有当它与注释/断言矛盾、或产生行为差异时才处理。
3. **高光叠放观感未验证 → 确认属 S1-05**（需 `scenes/**` 才能看），不是本批缺口。

#### 高光层边数裁定：静态受光有方向、交互状态包围（`06 §2.1` → v0.1.6）

Codex Visual Reviewer 依 **Reference A/B/C 目视 + `05_ART_STYLE.md` §3** 裁定：
两个高光变体**不得共用同一套边数**。

| 变体 | 语义 | 边数 | 依据 |
|---|---|---|---|
| `PanelHighlight`（`GOLD_200`） | 材质**暖高光** | **仅上边 + 左边** | 参考图按钮 / 木质外框 / 节点卡的亮边呈方向性（亮面在上/左，暗边与阴影在下/右）；与 `05 §3`「**光源方向统一为左上**」一致。四边整圈会退化成「无方向的金色描边框」，违反该条。 |
| `PanelSelected`（`BLUE_300`） | 交互**激活 / 选中** | **四边整圈** | Reference B 的选中节点与发光连接是**状态提示**而非材质受光，需要包围式轮廓才能在密集蓝图网格上稳定读成「当前对象」；只亮上/左会削弱可发现性。 |

- `06 §2.1` 原文把 `GOLD_200` 写作「暖高光」、`BLUE_300` 写作「激活」——
  这两个词本身就是**两种视觉语义**，本轮裁定只是把语义落实为几何。
- **同时修掉一处内部矛盾**：此前四边整圈的金色高光与 `05 §3` 的左上光源规则冲突。
- Codex 明示的风险：实现方若图省事只改 `_highlight_box()` 一处，会把 `PanelSelected` 一起改成上/左 —— **不得如此**，必须拆成两种几何。
- 裁定已写回 `06 §2.1`；实现与回归由 DSH 派 Claude 执行。

### 追加二：OpenCode Go 端点修复 —— 凭据变量用错（2026-10-03 第十一轮）

用户提供密钥并要求「**修 opencode 端点**」。DSH 定位到根因是**密钥放错了变量**并修复。

**根因**：OpenCode Go 的 Anthropic 兼容端点只认 `x-api-key` 请求头；而 Claude Code 只有在密钥放在
`ANTHROPIC_API_KEY` 时才会发这个头。用户把密钥放在 `ANTHROPIC_AUTH_TOKEN`，Claude Code 于是发
`Authorization: Bearer …`，端点回 **`401 Missing API key.`** —— 正是 PET-38 的失败原因。

**证据（两条独立来源互相印证）**：

1. 官方 cc-switch 预设 PR #6196（*connect OpenCode Go directly in Claude Code*）写明
   `ANTHROPIC_BASE_URL: "https://opencode.ai/zen/go"`、`apiKeyField: "ANTHROPIC_API_KEY"`，
   且其单元测试明确断言 `expect(env).not.toHaveProperty("ANTHROPIC_AUTH_TOKEN")`。
2. DSH 直连同一 URL 实测：

   | 请求头 | 结果 |
   |---|---|
   | `x-api-key: <key>` | 通过鉴权（返回与鉴权无关的业务错误） |
   | `Authorization: Bearer <key>` | `401 {"type":"AuthError","message":"Missing API key."}` |

**处置**：把 `~/.claude/settings.json` 的 `env` 中密钥由 `ANTHROPIC_AUTH_TOKEN` 移至 `ANTHROPIC_API_KEY`
（其余配置一律不动），并在同目录留下备份 `settings.json.dsh-backup-<时间戳>`。

**验证**：CLI 端到端复跑，错误**从 401 变成完全不同的 400** —— 说明鉴权这一环已经通了：

```
API Error: 400 Upstream request failed: This Go model requires Global regions.
           Select Global in your workspace's Privacy settings to use it.
```

**新的剩余阻塞（只有用户能解）**：需在 OpenCode 工作区的 **Privacy settings** 中选择 **Global** 区域。
这属于**数据驻留 / 隐私设置**，是用户的决定而非技术细节，**DSH 不代为更改**。

**排查提示**：对 Go 端点做裸 HTTP 探测会被 `MissingSessionID` 挡住（需要 `x-opencode-session` 头，
由真实客户端补上），因此**只有用真实 CLI 才能可靠验证**模型权限 —— 本轮结论均以 CLI 实测为准。

### 追加：PET-38 首次派发失败 = Claude Code 凭据问题（2026-10-03 第十轮）

运行时恢复后（用户重启桌面端），PET-38 于 17:05:53 成功派发，但 3m07s 后失败、工具调用数为 0：

```
INF task did not complete, reporting failure
    failure_reason=agent_error.provider_auth_or_access
agent_error="Failed to authenticate. API Error: 401 Missing API key."
```

**根因（DSH 实测，与本项目无关）**：Claude Code 自身的凭据/端点失效。

- 直接执行 `claude -p "..."` **60 秒无响应**（停在认证阶段）—— 说明 CLI 在 Multica **之外**同样无法认证，
  不是 daemon 的调用上下文问题。
- `~/.claude/settings.json` 的 `env` **当前**配置：
  `ANTHROPIC_BASE_URL = https://opencode.ai/zen/go`，`ANTHROPIC_AUTH_TOKEN = oc_sk_…`（51 字符）。
- 而 6–8 月的三个 `settings.json.clawd-cleanup-*.bak` 备份里是：
  `ANTHROPIC_BASE_URL = https://api.deepseek.com/anthropic`，token 为 `sk-611…`（35 字符）。
  → 用户近期把 Claude Code 的端点从 DeepSeek 换成了 opencode.ai；**新端点返回 401**。
  （这也解释了为什么 9 月的 Claude 任务能成功、现在不行。）
- 所有模型都被映射到 `deepseek-v4-flash`，因此报错里那句
  `[claude-code:unrecognized_model] {"model":"deepseek-v4-flash"}` 是**既有噪声**（9 月成功运行时也有），不是失败原因。

**结论**：这是**外部商业服务 / 凭据**问题，对应 **GATE 6**，只有用户能修。
**DSH 不自行更换用户的 API 端点或密钥。**

**行动**：不重试（同端点必然同样失败，而每次失败都是真实成本）；PET-38 置为 `blocked`；
两个可选修复方案交用户决定（修 opencode 端点 / 回退 DeepSeek 端点）。

### 运行环境事故：Claude runtime 离线导致 PET-38 积压（2026-10-03 第九轮）

**现象**：子任务 PET-38 的 Claude 运行长时间停留在 `queued`，用户询问原因。

**根因**（以 daemon 日志为证）：Claude Code 自动更新后，把启动器从 `D:\OpenClaw\npm-global`
（Multica daemon **钉住**的路径，且在 PATH 中排在真正的 npm 目录之前）搬到了
`C:\Users\20703\AppData\Roaming\npm`。daemon 每 5–10 分钟重试版本探测，每次都失败：

```
WRN re-resolved agent executable failed version detection; keeping pinned path
    new_path=D:\OpenClaw\npm-global\claude.cmd
    error="detect version for D:\\OpenClaw\\npm-global\\claude.cmd: exit status 1"
WRN skip registering runtime name=claude attempts=2
```

于是 daemon **跳过注册 claude runtime** → 所有绑定该 runtime 的任务（含 PET-38）永久排队。

**处置（DSH 执行）**：在该钉住路径补一个转发 shim `D:\OpenClaw\npm-global\claude.cmd`，
指向真实的 `C:\Users\20703\AppData\Roaming\npm\node_modules\@anthropic-ai\claude-code\bin\claude.exe`。
daemon 立即接受：

```
INF adopted resolved agent executable provider=claude
    new_path=D:\OpenClaw\npm-global\claude.cmd  version="2.1.288 (Claude Code)"
```

**遗留（需用户操作）**：claude **runtime 本身仍未注册/心跳** —— `4a169b9b` 状态 `offline`、
`last_seen=2026-10-02`。注册只在 daemon 启动时发生，因此**需要重启 Multica 桌面端**才能恢复派发。
DSH **不得**自行终止或重启 multica 进程（会打断其它正在运行的任务，且 AGENTS 明令禁止）。

**给未来 Agent 的排查顺序**（下次再遇到 Claude 任务长期 `queued`）：

1. `multica daemon status --output json` → 看 `skipped_agents`
2. `daemon.log` → 搜 `skip registering runtime name=claude`
3. `multica runtime list` → 看 claude runtime 的 `status` 与 `last_seen`
4. `multica agent tasks <claude-agent-id> --limit 3` → 确认 run 是否卡在 `queued`

> ⚠ **`daemon.log` 不带日期**，只按 `HH:MM:SS` 过滤会把历史条目混进来（本次排查中差点据此得出
> 「daemon 正在跑 Claude 任务」的错误结论）。判断新近性请用 `Get-Content -Tail`，或结合
> 其它带日期的字段。

### 存储分层：E 盘纳入（2026-10-03 第八轮）

用户 2026-10-03：「可以，不用清理，你自行判断，有些东西也可以放到 E 盘中，你觉得可行的话」。

#### Decisions
- **C 盘旧遗留不清**（用户决定），GATE 8 删除议题关闭。
- **E 盘纳入为「大块 · 可再生」层**，`01_STORAGE_RULES.md` 新增 **§11 存储分层**：
  - **D:** 必须进 git 的东西（源码 / docs / .git / scripts / scenes / data / tests）
  - **E:** 体积大且可再生 / 不进 git 的东西（`build/` 导出产物、素材源文件、Godot editor data 含约 1 GB 导出模板）
  - **C:** 仅短暂中转（§9 不变）
- 依据：D 盘可用率 16.0% 是三个卷里最紧的，E 盘 48.6% 最宽松。

#### Changed
- `D:\GameDev\PixelFusion\build` 与 `D:\GameDev\PixelFusion\tools\godot\editor_data` 改为**目录联接**，
  实际落盘到 `E:\GameDev\PixelFusion\`。**逻辑路径不变**，因此原提示词的路径约定与已派发给 Claude 的任务卡都不受影响。
- 明确纪律：只允许写 `E:\GameDev\` 与 `E:\Temp\PixelFusion`；**不得触碰 `E:\godot\`（用户自己的引擎）**及 E 盘其它用户目录。
- `11_TASK_BOARD` S0-21 注明模板落盘位置改为 E:；新增 S0-27 记录本次分层。

### GATE 1 通过 + GATE 7 裁定（2026-10-03 第七轮）

用户 2026-10-03 明确指令：

> 「视觉上的不是说好交给 codex 来吗，然后只要不是长期留存在 C 盘都可以，我批准了，
> 当然也需要你去把握一下 C 盘目前的空间是否支持，不要撑爆了，然后**批准 Stage 0**」

#### 验收
- **Stage 0 通过 L4 用户验收**（`11_TASK_BOARD` S0-17 → `DONE`）。`docs/00`~`12` 就此成为**已生效的开发契约**，
  不再标注「待用户批准」的悬置状态。
- **GATE 1 关闭** → Stage 1 解锁。

#### GATE 7 裁定
- C 盘**允许短暂中转，不允许长期留存**。已写入 `01_STORAGE_RULES.md` §9，
  并在 §7 的 STORAGE CHECK 中追加「C 盘临时文件清单 + 清理结果」两项。
- 新增 `01_STORAGE_RULES.md` §10 **容量门禁**（>500MB 操作前置检查；可用率 <10% 或 <10GB 即停止）。

#### 容量实测（2026-10-03）
| 卷 | 总量 | 可用 | 可用率 |
|---|---|---|---|
| C: | 148.9 GB | 36.0 GB | 24.2% |
| D: | 412.8 GB | 65.9 GB | 16.0% |
| E: | 390.6 GB | 189.7 GB | 48.6% |

- **C 盘无任何 PixelFusion 项目内容**：`C:\GameDev` 不存在，`C:\Users\20703` 深度 3 内无 `PixelFusion*` 命名项。
- C 盘的 367 MB 占用经查明**全部是 Agent 运行时**，不是项目文件：
  `pet-37-bf947acd4893\codex-home`（338.9 MB，其中 `codex.exe` 单文件 281.7 MB）+ 另一个历史任务 27.7 MB。
  这是 Codex 运行时的沙箱二进制与会话日志，由平台 GC 管理。
- **新增结论：每次 Codex 运行在 C 盘约产生 340 MB 成本** → DSH 应控制 Codex 派发次数，不做无意义重跑。

#### 流程
- 用户提醒「视觉交给 Codex」：DSH 后续只提供测量与约束，**视觉判断权归 Codex**，已写入 `11_TASK_BOARD` §2.1。

#### Git
- `D:\GameDev\PixelFusion` 接入远端 `ChenYunyong/-`，以**合并**方式纳入远端既有 `README.md`（不 force、不覆盖）。

### Codex 第二轮「目视」审查处置（2026-10-03 第六轮）

Codex 下载并**目视**了 Reference A/B/C（DSH 的模型无法看图，这部分只能由它提供）。5 项 blocking 中：

- **1 项经 DSH 独立测量确认** —— 节点卡尺寸
- **3 项为过期发现**（针对 v0.1.1，本轮已在 v0.1.2 修完）
- **1 项材质边界**成立，采纳但改用**实测值**而非其建议的猜测值

#### Fixed（采纳）
1. **节点卡几何（最重要）**：Codex 目视指出 320×180 基准下 48×48 卡片放不下参考图的节点密度。
   DSH 用**自相关周期测量**独立验证：Reference B 的节点/槽位间距为 **22.6 / 26.0 逻辑像素**（两个独立区域），
   48px 大了一倍以上。`06` §4 重设为 **24×24**，名称移出卡片（改由 Tooltip + 详情面板承载）；§12.2 记录方法。
   仓库槽位同取 24×24、间距 28px，仓库条由 64px 回调至 **48px**（64px 的理由随卡片缩小而失效）。
2. **触摸尺寸定义错误**：v0.1.2 写「44×44 px（逻辑像素，按缩放换算）」自相矛盾。
   已改为 **44×44 设备像素**，并规定触摸平台最小 2× 缩放 —— 24 逻辑像素在 2× 下为 48 设备像素，达标。
3. **材质边界**：`WARM_500` 与 `BROWN_200` 不得共用（Codex：否则「脸像木头」）。
   已拆分：`BROWN_200 #977777` 恢复为木质最亮；肤色改用 **实测**中间调 `#ECB48C`（Reference A 肤色族第二大色桶）。
   **未采用** Codex 的猜测值 `#C99784`。确立「暖色组 = 角色 / 木质组 = 场景与 UI 外框」。
4. **UI 层次规格缺失**：`06` §2 Panel 升为**三层结构**（暖木/黄铜外框 → 深蓝内芯 → 亮金高光），
   新增主面板框 3px / 次级 1px、铆钉与转角用 `GOLD_*`；明确禁止「没有外框的裸深蓝面板」。
   该判断由 Codex 目视得出，并与 DSH 实测的暖色边缘带（左 x 0–5%、底 y 97–100%）互相印证。
5. **FX 三层结构**：新增 `BLUE_FX_600 #3EA6FF`（**仅 FX**，禁止用于 UI）与 `04` §3.10 强制三层规则
   （亮芯 + 主体 + `NAVY_900` 描边），解决粉彩蓝弹体在天空背景上丢读性。
6. **伤害数字配色**：依 Codex 目视（Reference C 中伤害数字为橙金而非红色），改为优先
   `GOLD_500`/`ORANGE_300` + `NAVY_900` 描边；`RED_400` 保留给真正的危险/警告文字。
7. `06` §8 明确 COMBAT 底部带是**状态/预览**性质的命令带，**不得**做成实时动作栏（违反宪章 §5 交互硬规则 3）。

#### Rejected / Already fixed（过期发现，附证据）
- 「`同一色相 10° 内不得出现两个 Token` 仍然冲突」→ **已于 v0.1.2 废止**，现仅作为废止说明出现一次。
- 「`WARM_500` 与 `BROWN_200` 完全重复」→ **v0.1.2 已合并**；本轮按新的材质论据重新拆分，但拆分方式与 Codex 建议不同（用实测值）。
- 「Disabled 对比度仍建议修」→ **v0.1.2 已改**：Disabled 底色已为 `NAVY_800`（4.80:1）。
- 三项过期发现表明该轮审查读取的是 v0.1.1 快照（其引用的行号 04:136/148/191 与当前内容不符）。

### Codex 视觉审查处置（2026-10-03 第五轮）

Codex Visual Reviewer 对 `04/05/06` 提交了 4 项 blocking + 3 项建议。**其全部对比度计算已由 DSH 独立复算，四个数字完全一致**
（`GREY_500`/`NAVY_700`=3.84、`RED_500`/`NAVY_800`=3.21、`BLUE_500`/`NAVY_800`=6.98、`BLUE_100`/`NAVY_800`=11.75），故按可信结论处置。

#### Fixed（采纳 4 项 blocking）
1. `04` §4：**废止**「同一色相 10° 内不得出现两个 Token」—— 该条无法执行且与本表自相矛盾（色阶本身就是同色相）；
   改为「同一用途不得出现近似色 + 同色组允许 3–6 档明度阶梯，每档必须有明确用途」。
2. `04` §3：**合并** `WARM_500` 与 `BROWN_200` —— 二者都是 `#977777`（同一实测桶 `#907070`），是同一颜色的两个名字。
3. `04` §3.7：新增 **`RED_400 #F06A6A`**（推导值）用于小号危险文字/伤害数字；把「`RED_500` 只 3.21:1、`RED_600` 只 1.68:1，
   不得承载小号文字」写成硬约束。
4. `06` §3：Disabled 按钮底色由 `NAVY_700`（3.84:1，不达标）改为 **`NAVY_800`**（4.80:1，达标）。
5. `06` §4/§7：解决 Node Card 58px 占位与 48px 仓库条的**硬冲突** —— 底部仓库条定为 **64px（y 116–180）**；
   该值与实测 CTA 位置（y 148–162）自洽（CTA 实为仓库条右端）；补充 44×44 隐形 hitbox 规定。

#### Fixed（采纳 3 项建议）
6. `04` §5：**修正 DSH 自己的错误** —— v0.1.1 称 `BLUE_500` 在 `NAVY_800` 上「亮度接近度不足」是**错的**（实测 6.98:1）。
   仍禁止其作正文，但理由改为「能量/激活语义色，作正文会抢焦点」。新增 §5.1 十组对比度实测表。
7. `05` §4：补充「单个交互对象 ≤12 色」与「背景/大场景允许分区调色板」，消除「整屏只能 12 色」的误读。
8. `06` §7.1：新增**移动端折叠规则**（左栏收起、右栏改底部弹层、仓库横向滚动、CTA 常驻）。

#### Rejected（1 项，附理由）
- Codex 建议把肤色中间调改为推导值 `#A8877A` 以避开与木质高光撞色 —— **不采纳**：
  参考图中两者本就是同一个值，凭空拆一个未实测颜色会破坏「每个色值可溯源」原则。
  记为 Stage 5 候选：若真实素材下确实撞色，再按 `04` §4.6 流程提请拆分。

### 布局实测：参考图结构反推（2026-10-03 第四轮）

#### Added
- `06_UI_UX_STANDARD.md` 新增 **§12「参考图实测布局证据」**，说明布局数值的来源、方法与可信度分级。
- `tools/ref_layout_probe.py`：边界检测 + 构成图（ASCII）工具，纯标准库，可复跑。

#### Changed
- `06_UI_UX_STANDARD.md` §7（PREPARATION）：左/中/右三栏宽度从**凭感觉的 64/72px** 改为实测 **73/128/83px**；
  明确「开始战斗」CTA 实测位于右下角 x 246–310 / y 148–162；标注底部「节点仓库」条高度**未能分离，仍为暂定值**。
- `06_UI_UX_STANDARD.md` §8（COMBAT）：新增实测结论 —— **底部全宽 HUD 条 y ≈ 135–180（高 ≈45px，占画面 25%）**，
  并把该值定为实现依据；同时注明「若要更紧凑属 GATE 3，需用户确认」。

#### Notes
- 本轮修正的是**数值**，不是**结构**：五区结构由用户指令固定，实测只用于校准比例。用户指令优先级高于实测。
- 上一版 06 中的 64px / 72px / 48px 为无依据的估值，现已由实测值替代并标注来源。

### 约束体系：纳入用户《DSH 连续自主执行规则》（2026-10-03 第三轮）

#### Added
- `08_AGENT_RULES.md` 新增 **§10「自主执行模型与关键门禁」**（v0.1.1）：工作模式、DSH 默认继续执行权、自动协作闭环、
  **GATE 1–10 完整门禁表**、美术批量审批特殊规则、禁止「假完成」、以及与「DSH 不抢开发」原则的边界。
- `11_TASK_BOARD.md` 新增 **§2.1 门禁状态**：当前 GATE 1 与 GATE 7 为 🔴 等待用户，Stage 1 明确标记为不可推进。

#### Decisions
- GATE 1 未获批准前，**Stage 1 一律不开工** —— 依据用户总控提示词 §32「获得用户明确批准后：才能派发第一项正式开发任务」，
  以及《连续自主执行规则》§六「在用户批准 Stage 0 后：DSH 应自行组织…」。自主执行权不覆盖 GATE 1。
- 自主执行扩大的是 DSH 的**决策与推进权**，不是**开发权**：DSH 仍不写正式游戏代码。

#### Rejected / Rolled back
- 无。

### Stage 0 — 参考图校准与环境落地（2026-10-03 第二轮，待用户批准）

#### Added
- 参考图 A / B / C 落盘至 `D:\Temp\PixelFusion\scratch\refs\`（从 issue 附件下载，未经过 C 盘）。
- 对三张参考图执行逐像素取色实测（纯标准库 PNG 解码 → 3px 采样 → 16 级量化），证据写入 `04_COLOR_SYSTEM.md` §2。
- `05_ART_STYLE.md` 新增 §2「参考图的真实性质」。

#### Changed
- `docs/04_COLOR_SYSTEM.md` → **v0.1.1**：蓝色组重写为粉彩天空蓝（`#77B7F7`~`#D7E7F7`），棕色组修正为低饱和偏红（`#372727`~`#977777`），新增 `WARM_*` 组，解除「少用纯白」限制。红/橙组保留 v0.1.0 值并标记 `UNVERIFIED-AGAINST-REFS`。
- `docs/01_STORAGE_RULES.md` → **v0.1.1**：回写真实 STORAGE GATE 结果；新增 §5 Godot 运行规则（含 `user://` 默认落 C 盘的泄漏说明）。
- `docs/11_TASK_BOARD.md`：S0-18 完成；新增 S0-19 / S0-20 / S0-21。
- `.gitignore`：排除 `tools/godot/`（引擎二进制不进版本库）。

#### STORAGE GATE — 第二轮实测（2026-10-03）
- 发现用户既有 Godot：**`E:\godot\Godot_v4.7.1-stable_win64.exe`（4.7.1.stable.official）**，`--headless --version` 正常。
- 发现用户既有 `%APPDATA%\Godot`：**约 1.0 GB**，创建于 2026-07-06，含 `editor_settings-4.7.tres`、`export_templates\templates.tpz`（995.4 MB）、`app_userdata\`。**为本项目之前就存在的用户数据，非本项目产物**，已登记为只读例外。
- 建立本项目 portable 引擎 `D:\GameDev\PixelFusion\tools\godot\`（复制自 E 盘既有安装 + `._sc_`/`_sc_` 标记）。
- **验证通过**：以该 portable 引擎运行 `--headless --version` 后，`%APPDATA%\Godot` 的 `LastWriteTime` 保持 `2026-09-20 22:10:46` 不变 → **未向 C 盘写入**。
- 未下载任何新引擎：复用用户既有的 4.7.1，避免版本与既有导出模板（4.7.1.stable）错配。
- 引擎版本锁定为 **Godot 4.7.1-stable**。

#### Known Issues / Pending
- 导出模板 `4.7.1.stable` 目录为空，仅有 `templates.tpz`；导出前必须安装到 D 盘 portable 引擎（S0-21）。
- Multica Agent 运行时任务工作区仍位于 C 盘，**待用户裁定**。
- 红/橙两组颜色为 `UNVERIFIED-AGAINST-REFS`，需在 Stage 4 实际战斗画面中由用户确认。

### Stage 0 — PROJECT FOUNDATION（2026-10-03 第一轮，待用户批准）

#### Added
- 建立正式项目目录树 `D:\GameDev\PixelFusion`（依 03_ARCHITECTURE §9）。
- 建立临时目录 `D:\Temp\PixelFusion`，含 `pycache / pip / godot / logs / screenshots / scratch`。
- 写入 Stage 0 全部约束文档：`00_PROJECT_CHARTER` ~ `12_CHANGELOG`。
- 写入 `.gitignore`（排除 `.godot/`、`.import/`、`build/`、`*.tmp`、`*.log`）。

#### Decisions
- 冻结技术基线：Godot 4.x Stable + GDScript；禁止 C#/GDExtension/Electron/Unity/Unreal。
- 冻结交互硬规则：PREPARATION 永不自动推进；`PREPARATION → COMBAT` 仅由玩家点击触发。
- 冻结颜色系统 v0.1.0（14 组 Token，依三张参考图）。
- 冻结美术方向：日式 Q 版精致像素风，基准 320×180。
- 冻结素材审批流程：`pending → final → 用户批准 → approved → 集成`。
- 冻结 Agent 权限矩阵与冲突优先级（08_AGENT_RULES §7）。

#### STORAGE GATE — 实测记录（2026-10-03）
- 实测 `TEMP` / `TMP` / `TMPDIR` 均指向 `C:\Users\20703\AppData\Local\Temp\multica-task-<id>\...` → 记为**风险**，已在 01 §4 规定强制注入 D 盘路径。
- 实测 `APPDATA` / `LOCALAPPDATA` / `USERPROFILE` 在 C 盘 → 工具默认缓存风险，已在 01 §5 规定 Godot 必须自包含。
- 实测 D 盘存在且可写 → ✅。
- 实测 Godot **未安装**（PATH 无、`D:\` 深度 3 无、Program Files 无）→ 记为**阻塞 Stage 1**，见 11_TASK_BOARD S0-18。
- 实测 Python 3.12.9 位于 `D:\Python312\python.exe` → ✅ 在 D 盘。
- 实测 Git 身份：`ChenYunyong <2070348240@qq.com>` → 保留，未做任何修改。

#### Known Issues / Pending
- Multica Agent 运行时任务工作区位于 C 盘（平台基础设施），是否豁免**待用户裁定**。
- `assets/palette.tres` 未创建：Stage 0 仅冻结 schema，避免提交损坏的 `.tres`；由 S1-03 实现。

#### Rejected / Rolled back
- 无。

## 变更记录规则

任何人对 `docs/` 的修改必须：

1. 由 DSH 执行（或经 DSH 批准后由执行 Agent 提交）。
2. 在本文件顶部 `[Unreleased]` 追加条目。
3. 说明：改了什么 / 为什么 / 影响哪些文档。
4. 涉及整体视觉、玩法循环、技术基线的修改 → 必须重新提交用户确认。

## 验收记录

| 日期 | 阶段/任务 | 等级 | 结论 | 打回原因 | 验收人 |
|---|---|---|---|---|---|
| 2026-10-03 | Stage 0 文档 | L2/L3 | 已审查，提交用户 | — | DSH |
| 2026-10-03 | Stage 1 S1-05~S1-10（七场景 + PET-41/44/46/49/51 裁定写回 + PET-50 冒烟修复） | L2/L3 | 逐项审查通过，全量套件绿（unit 1116 · integration 19 · 六场景冒烟 544 · 探针 241） | — | DSH |
| 2026-10-03 | Stage 0 文档 | L4 | 等待用户批准 | — | 用户 |
