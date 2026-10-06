# 11 — 任务板（TASK BOARD）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 **v0.4.2**｜维护者 DSH
> （v0.4.2：`PET-76` 复核 `ACCEPTED` 并落 `main`（战斗可读反馈）+ 双击包**用修后代码重新导出**；新增待办 `R7`（唤醒投递不可靠）。v0.4.1：`PET-75` 复核 `ACCEPTED` 并落 `main`；`PET-76` 自 `BACKLOG` 提升为 `TODO`（单写手让位）；新增待办 `R6`。v0.4.0：`PET-74` 复核 `ACCEPTED` 并落 `main`；**用户试玩反馈已进板** —— 新增 `PET-75` / `PET-76` 两行。）
> 本文件是唯一的任务事实来源。执行的 Agent 不得自行改状态，状态由 DSH 更新。

## 1. 状态定义

| 状态 | 含义 |
|---|---|
| `BLOCKED` | 有未解决的阻塞（依赖/决策/环境） |
| `TODO` | 已定义，未开始 |
| `IN_PROGRESS` | 正在执行 |
| `REVIEW` | 执行完成，等待 DSH 审查 |
| `ACCEPTED` | 通过 DSH 审查（L2/L3） |
| `DONE` | 用户已验收（L4） |
| `REJECTED` | 打回，附原因 |

## 2. STAGE 0 — PROJECT FOUNDATION（当前）

| ID | 任务 | 负责人 | 状态 | 产出 |
|---|---|---|---|---|
| S0-01 | STORAGE GATE 环境检查 | DSH | `ACCEPTED` | `01_STORAGE_RULES.md` §3 |
| S0-02 | 建立项目目录树 `D:\GameDev\PixelFusion` | DSH | `ACCEPTED` | §19 结构 + `D:\Temp\PixelFusion` |
| S0-03 | `00_PROJECT_CHARTER.md` | DSH | `REVIEW` | docs/00 |
| S0-04 | `01_STORAGE_RULES.md` | DSH | `REVIEW` | docs/01 |
| S0-05 | `02_CODE_STANDARD.md` | DSH | `REVIEW` | docs/02 |
| S0-06 | `03_ARCHITECTURE.md` | DSH | `REVIEW` | docs/03 |
| S0-07 | `04_COLOR_SYSTEM.md` | DSH + Codex | `REVIEW` | docs/04 **v0.1.1**（已按参考图实测校准） |
| S0-08 | `05_ART_STYLE.md` | DSH + Codex | `REVIEW` | docs/05（含参考图性质实测） |
| S0-09 | `06_UI_UX_STANDARD.md` | DSH | `REVIEW` | docs/06 |
| S0-10 | `07_ASSET_PIPELINE.md` | DSH | `REVIEW` | docs/07 |
| S0-11 | `08_AGENT_RULES.md` | DSH | `REVIEW` | docs/08 |
| S0-12 | `09_TEST_STANDARD.md` | DSH | `REVIEW` | docs/09 |
| S0-13 | `10_ACCEPTANCE_STANDARD.md` | DSH | `REVIEW` | docs/10 |
| S0-14 | `11_TASK_BOARD.md` | DSH | `REVIEW` | docs/11 |
| S0-15 | `12_CHANGELOG.md` | DSH | `REVIEW` | docs/12 |
| S0-16 | `.gitignore` + Git 初始化 | DSH | `ACCEPTED` | 仓库根 |
| S0-17 | **用户批准全部 Stage 0 文档** | 用户 | **`DONE`** ✅ | 2026-10-03 用户明确「**批准 Stage 0**」（L4 通过）|
| S0-18 | Godot 4.7.1 portable 安装（D 盘自包含） | DSH | `ACCEPTED` | `tools/godot/`（已验证不写 C 盘） |
| S0-19 | 参考图 A/B/C 落盘 + 逐像素取色实测 | DSH | `ACCEPTED` | `04` §2（证据） |
| S0-20 | `04`/`05` 按参考图实测校准（v0.1.1） | DSH | `REVIEW` | docs/04, docs/05 |
| S0-21 | 导出模板安装到 portable 引擎（**落盘在 E:**，见 `01` §11） | DSH | `PARTIAL`（当前**接受现状＝用户裁定选 B**；完整重装列为 **GATE 9 强制项**，执行点在正式 Web Release / Windows 打包 / RC 之前 —— 见下方「GATE 9 强制项」与 12 的 Notes） | `tools/godot/editor_data/export_templates/` → E: |
| S0-27 | 存储分层：E 盘纳入 + build/editor_data 重定向 | DSH | `ACCEPTED` | `01_STORAGE_RULES` §11 |
| S0-22 | Codex 对 `04/05/06` 的独立视觉审查 | Codex | `ACCEPTED` | 4 项 blocking 全部核验并采纳 |
| S0-23 | 依 Codex 第一轮审查修正 `04`→v0.1.2 | DSH | `ACCEPTED` | 04/05/06 |
| S0-24 | Codex 第二轮**目视**审查（真读了 A/B/C） | Codex | `ACCEPTED` | 采纳 3 项、3 项过期已提前修完 |
| S0-25 | 依目视审查修正 `04`→v0.1.3（节点卡 24px / 材质边界 / FX 三层） | DSH | `REVIEW` | 04/05/06 |
| S0-26 | PREPARATION 外框层 UI 素材（Codex 出稿 → 用户批准） | Codex | `TODO`（Stage 1） | `assets/_review/pending/` |

### S0 退出条件
- [x] 全部文档获用户明确批准（2026-10-03，L4 通过）
- [x] Godot portable 安装完成并验证 `%APPDATA%\Godot` 未被写入（2026-10-03 实测通过）
- [x] 三张参考图已取色实测并回写 `04` / `05`

## 2.1 门禁（GATE）状态

> 规则见 `08_AGENT_RULES.md` §10。**未获用户裁定的门禁，会阻塞受其影响的工作。**

| GATE | 状态 | 说明 |
|---|---|---|
| **GATE 1** — Stage 0 首次完成 | ✅ **已批准** | 用户 2026-10-03：「**批准 Stage 0**」→ Stage 1 解锁 |
| **GATE 3** — 视觉方向变化 | 🟡 已知相关 | `04` v0.1.1 已按参考图取色校准（属**对齐**既定方向，非改变方向）。红/橙两组标记 `UNVERIFIED-AGAINST-REFS`，留 Stage 4 确认。 |
| **GATE 7** — 工具无法避免写 C 盘 | ✅ **已裁定** | 用户 2026-10-03：「**只要不是长期留存在 C 盘都可以**」→ 允许短暂中转，禁止长期留存。规则见 `01_STORAGE_RULES.md` §9，容量门禁见 §10 |
| GATE 2 / 4 / 5 / 6 / 8 / 9 / 10 | ⚪ 未触发 | — |

### 当前是否可推进（2026-10-03 更新）

- **Stage 1（项目骨架）：🟢 进行中** —— GATE 1 已批准。第一批 S1-01~S1-04 已于 2026-10-03 交付并通过 L2/L3
  （PET-38，提交 `2f6d4c7` + `f9656fe`）；第二批 **S1-05** 已于 2026-10-03 交付并通过 L2/L3
  （PET-39，提交 `ed6d868` + `fc89777`），**待用户 L4 验收**。
- Stage 0 收尾（导出模板安装 S0-21、Git 远端）：✅ 可推进（属 DSH 默认执行权）。
- **视觉相关工作一律交 Codex**（用户 2026-10-03 明确提醒）；DSH 只提供测量数据与约束，不代替 Codex 做视觉判断。

## 3. STAGE 1 — PROJECT SKELETON（进行中：S1-01~S1-05 已交付，待用户 L4）

只实现状态循环，允许全部占位图。**首先验证整个游戏状态循环。**

| ID | 任务 | 负责人 | 依赖 | 状态 |
|---|---|---|---|---|
| S1-01 | `project.godot` 初始化 + Autoload 骨架（EventBus / GameFlow / DataRegistry / RunState / Settings） | Claude | S0 批准 | `ACCEPTED`（PET-38） |
| S1-02 | `GameFlow` 六状态机 + 切换硬规则 R1-R5 + 单元测试 | Claude | S1-01 | `ACCEPTED`（PET-38） |
| S1-03 | `scripts/data/palette.gd` + `assets/palette.tres`（依 04 §5） | Claude | S0 批准 | `ACCEPTED`（PET-38） |
| S1-04 | 全局 Theme（依 06） | Claude | S1-03 | `ACCEPTED`（PET-38） |
| S1-05 | BOOT 场景（数据校验 + 失败提示）**＋ 接线 `PanelShadow` ＋ 合并像素探针入口** | Claude | S1-01 ✅ | `ACCEPTED`（PET-39 · L2/L3 通过，待用户 L4） |
| S1-06 | MAIN_MENU 场景（占位：Logo/开始/继续/设置/退出）**＋ 落地 `06 §2.2` 面板标题栏（见 §3 已登记待办）** | Claude | S1-04 | `ACCEPTED`（PET-40 · PET-41 裁定已写回 06） |
| S1-07 | PREPARATION 场景（五分区布局 + 唯一动作「开始战斗」） | Claude | S1-06 | `ACCEPTED`（PET-42 · PET-44 裁定已写回 06） |
| S1-08 | COMBAT 场景（占位战场 + 紧凑 HUD） | Claude | S1-07 | `ACCEPTED`（PET-43 · PET-47 修订 · PET-46 裁定已写回 06） |
| S1-09 | REWARD 场景（3 选项 + 跳过） | Claude | S1-08 | `ACCEPTED`（PET-45 · PET-49 裁定已写回 06） |
| S1-10 | RESULT 场景（结算 + 返回） | Claude | S1-09 | `ACCEPTED`（PET-48 · PET-51 裁定已写回 06） |
| S1-11 | 双端输入适配（键鼠 + 触摸，44px 命中） | Claude | S1-10 | `ACCEPTED`（PET-53 · 统一输入层 6 文件 + 7 场景改造；交付时未提交，DSH 代为提交 `114dc4f`） |
| S1-08R | 收尾修复：COMBAT 冒烟 exit-notice 用例已被证伪，替换为 REWARD/RESULT 真实路由断言 | Claude | S1-08 | `ACCEPTED`（PET-50 · COMBAT 冒烟 103/103 转绿） |
| S1-09R | 规范一致性修复：REWARD 选项卡补 `PanelShadow` 叠层（Codex 裁定选 A） | Claude | S1-09 | `ACCEPTED`（PET-52） |
| S1-08R2 | 窄屏取样轴序统一 + 期望值按 `06 §7.1` 重导 + 补「25% 上限真的咬住」的专用取样 | Claude | S1-08R | `ACCEPTED`（PET-54 发现 → PET-55 完成） |
| S1-12 | 状态循环集成测试（10 次循环、防重入、不自动推进） | Claude | S1-10 | `ACCEPTED`（PET-56 · integration 19→333，三条性质各带反向对照；`09 §3.1` 的「无节点泄漏」一条并入测试卫生卡） |
| S1-13 | Web Export 冒烟验证 | Claude | S1-12 | `ACCEPTED`（PET-57 · debug+Threads 导出跑通、「人看清单」齐备） |
| S1-13R | 测试卫生 + Web 打包排除：夹到 0 覆盖 · 失准文案 · 10 轮泄漏断言 · `exclude_filter` | Claude | S1-13 | `ACCEPTED`（PET-58 · unit 1338 · integration 356 · 产物冒烟 36/36 · 四件各带反向对照） |
| S1-14 | Stage 1 用户验收（**GATE 9**） | 用户 | S1-13 | `REVIEW`（PET-59 · 验收清单已交用户，等用户 L4 结论；DSH 不得代判） |
| S1-14C | **Crash Investigation：Godot 原生崩溃（`0xc0000005`，用户报告）** | Claude | S1-14 | `ACCEPTED`（PET-60 · **结论已更正**：**已复现（触发条件明确）＋官方已知＋4.7.2 已修复** —— 引擎打不开 `user://logs` → `RotatedFileLogger::rotate_file()` 空指针；fault offset `0x3e15854` 与用户 Event 1000 逐字段＋WER 桶哈希相同；上游 #122437（affected 4.7.1 / `a13da4f`），修复 PR #121926 / commit `2906aa0` 随 **4.7.2** 发布。**本项目仍停在 4.7.1，不得视为已解决**） |

> **已登记待办（S1-05 复核产生）**：`06 §2.2` 的**面板标题栏**（高度 16px / 底色 `NAVY_700` + 1px 底部 `GOLD_600` 分隔线）
> 在 Theme 与 `scenes/**` 均无落点。Codex 2026-10-03 独立复核裁定：S1-05 的 BOOT 占位面板不必补，**列为 S1-06 验收项**
> —— 做真实面板/菜单 UI 时落地，并按 `09 §4` 做像素取证。
> **已登记待办（DSH 2026-10-03 回填时新增）—— 已解决**：三个单元测试的 `SHORT_NARROW_VIEWPORT` 轴序写反
> （`Vector2(180.0, 120.0)` 宽高比 1.5 → `is_narrow` 判为**宽屏**）已统一为 `Vector2(120.0, 180.0)`
> （PET-54 发现 / PET-55 完成）。但它被**两层**掩盖：① 三个单元测试直接调 `layout.*_rects()`，
> **绕开了 `is_narrow` 这道闸**；② 纠正轴序后 `120×180` 与基准**同高**，`min(45,45)=45`，25% 上限**仍然咬不住** ——
> 即该案**从未测过它注释里自称要测的东西**。现由 `TIGHT_NARROW_VIEWPORT = Vector2(120.0, 160.0)` 补上。
>
> **已登记待办（DSH 2026-10-03 PET-55 复核新增）**：`scripts/ui/result_layout.gd:126` 的
> `maxf(bottom - readout_top(), 0.0)`「夹到 0」分支**没有任何取样触发**（`120×180` 下读数区仍剩 36px；
> 实测需 `120×140` 才会夹到 0），故 `readout_rect(...).size.y >= 0.0` 对现有三个取样**恒真** ——
> 与上一条同类。另有两处已失准字符串待清：`tests/integration/combat_smoke.gd:33-37`、`scripts/ui/result_layout.gd:122`。
>
> **已登记待办（DSH 2026-10-03 S1-12 复核新增）**：`09 §3.1` 明写「循环 10 次**无内存/节点泄漏**」，
> 而 `tests/integration/test_state_loop.gd` 里**没有任何泄漏断言**（全文无 `orphan` / `child_count`）。
> PET-56 声称 `§3.1` 的语义「被完全覆盖」，该说法**只对循环次数成立**。已并入「测试卫生」卡。
>
> **已登记待办（DSH 2026-10-03 S1-13 复核新增，本批真实缺陷）**：`export_presets.cfg` 走默认
> `export_filter="all_resources"`，而 `build/` / `.godot/` / `tools/` 都在 `res://` 之内 ——
> DSH 自己的导出日志**逐字打出**它在打包 `res://tools/godot/editor_data/editor_settings-4.7.tres.remap`、
> `res://.godot/global_script_class_cache.cfg`、`res://.godot/uid_cache.bin`，即**用户既有的编辑器设置与本地缓存
> 被塞进了 `index.pck`**；且上一轮导出产物会被打进下一轮（实测 pck +29,680）。修法是加 `exclude_filter` ——
> 原卡「不要发明额外开关」那句让它无法修，已在本轮明确授权，并入「测试卫生 + Web 打包排除」卡。
>
> **已登记待办（DSH 2026-10-03 S1-13 复核新增，非本批引入）**：冷缓存导出会刷 64 条 `SCRIPT ERROR`
> （`palette.gd:87 resolve`：`Attempt to call a method on a placeholder instance`）。PET-57 的受控对照显示
> 与 preset 无关（单跑 `--editor --quit` 同样刷 32 条），热缓存为 0，**运行时不受影响**（全套套件全绿）。
> 属 `@tool` 扫描期的占位实例问题，登记待办，本轮不派卡。
>
> **已登记待办据实结清（DSH 2026-10-03 PET-58 复核后）**：上面几条 —— ① `result_layout.gd:126`「夹到 0」
> 分支无取样、② 两处失准文案、③ `09 §3.1` 的「10 轮无节点泄漏」无断言、④ Web 打包排除缺陷（含用户既有编辑器设置
> 被打进 `index.pck`）—— 已由 **PET-58 一次提交全部落地**（`015efec`），**每条都带反向对照**
> （分别红 2 / 文案类无断言可红 / 恰 10 / 恰 3 条），且 DSH 在正式树里独立复跑确认：
> 修复后连导两次 pck **Δ0**，清空 `exclude_filter` 后 pck 由 95,712 涨到 **3,659,192**。
>
> # ⛔ 开发暂停（用户指令 2026-10-03）· 已由用户 2026-10-04 后续指令（PLAYABLE-FIRST）实际解除
>
> 用户报告 **Godot 原生崩溃**（WER：`Exception code 0xc0000005`，faulting module = **Godot 本体**，
> fault offset `0x3e15854`）并要求：**暂停继续开发并建立 Crash Investigation**。
> 调查卡：`S1-14C`（PET-60，`ACCEPTED`）。用户原始指令全文见 `12_CHANGELOG.md` 同日条目。
>
> **Crash Investigation 最终结论（结论已由「未能复现」更正为「已复现·触发条件明确」）：**
> 根因 = **引擎自身的日志打开路径**。`OS::ensure_user_data_dir()` 建不出 `user://logs`（或目标不可写）时，
> `RotatedFileLogger::rotate_file()` 里 `FileAccess::open()` 返回 null **未检查**即 `detach_from_objectdb()`，
> 空 this 读 `[rcx+0x58]` —— **精确命中用户弹窗的「引用了 `0x0000000000000058`」**，fault offset `0x3e15854`。
> **独立复现 3/3**，且**换空工程（无 autoload / 无主场景 / 无任何 GDScript）同帧同址崩溃**
> ⇒ **与本项目代码无关**（`0xc0000005` 的因果**至此已证**，不再是假设）。
> 上游 **#122437** 已知（affected `4.7.1.stable` / commit `a13da4f` = 我方构建），
> **修复 PR #121926 / commit `2906aa0` 随 Godot 4.7.2 发布**。
> **处置：引擎已升级至 4.7.2（PET-61 `ACCEPTED`，含完整导出模板），4.7.1 原样保留可回滚 —— 即「由引擎版本升级规避」。**
>
> **⚠ 仍然生效、与根因是否定位无关的两条用户红线**：
> `S1-14`（GATE 9）**不得置 `DONE`** —— L4 只属于用户；**Stage 1 与后续 Stage 一律不得标为「稳定」**。
>
> **待办 A（代码卫生）— 已落地 ✅**：`game_flow.gd` 现走 `_apply_scene_change.call_deferred(path)`
> （`game_flow.gd:159`，附「为何不让 `_route_to_scene()` 直接 `call_deferred`」的就地说明），
> 启动期不再刷 `remove_child() can't be called at this time`。
> 其与崩溃的因果关系此前已被证否（6000 次误用零崩溃，引擎自愈），**仅作代码卫生修正**。
>
> **待办 B（独立缺陷，等恢复开发再做）**：`palette_theme.gd` 是 `@tool`，`_init()` 里即 `apply_palette()`，
> 而 `Palette` 此时是**占位实例** → 每次编辑器扫描稳定刷 **32 条** `SCRIPT ERROR`（冷热缓存都一样，
> DSH 此前说"热缓存为 0"是**错的**）。属独立缺陷，与本次崩溃无关。
>
> **待办 C（曾拟装 WER LocalDumps）— 已作废，无需用户批准 ✅**：PET-60 实测 **`HKCU` 下的 LocalDumps 静默无效**
> （该功能只读 `HKLM`，启用需管理员；写好 `HKCU` 子键后连造 5 次真崩溃，`D:\Temp\PixelFusion\crash_dumps\`
> 始终 **0 个文件**），两个 `HKCU` 子键已按 DSH 裁定删除、`HKLM` 提权方案放弃。
> 且根因**并未依赖 dump 就已定位**（字节级反汇编 + 空工程对照 + `--log-file` 单变量 A/B：默认日志路径崩溃、
> 指定可写日志路径 exit 0），故**不再向用户申请任何提权 / LocalDumps**；自研 `MiniDumpWriteDump` launcher
> 亦按 `08 §11.5`（已有成熟方案不得重复造轮子）一并砍掉。
> **GATE 9 强制项（用户 2026-10-03 裁定）**：**重新安装完整的 Godot 4.7.1 Stable Export Templates**。
> 用户选定 **B：当前继续开发，不因导出模板中断项目推进** —— 同时明确要求把该条**登记为 GATE 9 前的必须完成项**，
> 并在**进入正式 Web Release、Windows 打包或 Release Candidate 阶段之前**执行**完整模板重装 + 导出验证**。
> **2026-10-04 现状更新（PET-61 验收后）**：基线已迁至 **Godot 4.7.2**，其**完整 Export Templates 已落
> `tools/godot`（D:）与 `editor_data`（E:）**，该条的**实质要求已在新基线上满足**（Web Debug 导出实测通过、
> 像素缩放 4× 整数）。**残留条件**：**4.7.1 回滚路径仍不具备 release / 桌面导出能力**（旧 `templates.tpz` 仍是截断的）
> —— 若将来必须回滚到 4.7.1，本强制项**立即复活**。
> **是否就此结清 `S0-21` 属用户的 GATE 9 裁定，DSH 不代判。**

**Stage 1 绝对禁止**：真实战斗、真实伤害、蓝图编辑逻辑、敌人 AI。

## 4. STAGE 2 — BLUEPRINT BASE（S2-01 / S2-02 已验收；后续按 PLAYABLE-FIRST 重排为 §4.1）

| ID | 任务 | 负责人 |
|---|---|---|
| S2-01 | `NodeData` / `ConnectionData` Resource 定义 | Claude |
| S2-02 | 蓝图数据模型 + 序列化（保存/重载一致） | Claude |
| S2-03 | 蓝图工作区 UI：节点仓库、拖放、网格吸附 | Claude |
| S2-04 | 连线交互（鼠标 + 触摸）与合法性校验 | Claude |
| S2-05 | 删除 / 撤销（Ctrl+Z / 触摸撤销） | Claude |
| S2-06 | 环路、悬空端口、类型不匹配的处理与提示 | Claude |
| S2-07 | 蓝图单元测试（空蓝图、删除引用、环路、重载） | Claude |
| S2-08 | Stage 2 用户验收 | 用户 |

> **进度（2026-10-04）**：**S2-01 `NodeData` / `ConnectionData` 已验收（`ACCEPTED`，L2/L3）** —— Claude 提交 `c769120`（7 files / +132，DSH 已推送）；DSH 独立复跑：基线 `c9421c0` = unit **1338/1338** · integration **356/356**，本提交 = unit **1370/1370**（+32） · integration **356/356**，失败项 0，ERROR 35→35 / WARNING 18→18 **零增量**；负向对照（`kind` 缺省改 `CORE`、`from_port` 缺省改 `"out"`）恰好 **4 条**按名转红（1366/1370）。
>
> **S2-02（`73cc2cb`）已验收（`ACCEPTED`）**：unit **1402/1402** · integration **356/356**，失败 0。退出期 +1 ERROR / +1 WARNING，经 DSH 用 `--verbose` 独立复核，泄漏对象是 `res://scripts/data/palette.gd` 与 `res://assets/palette.tres` —— **不在本卡 ALLOWED FILES 内**，按 `09 §5`（v0.1.7）「退出期资源清点」条**不判本卡未达 DoD**，登记为非阻塞缺陷（见 §4.1）。

## 4.1 FIRST PLAYABLE VERTICAL SLICE（2026-10-04 起，最高优先级）

用户 2026-10-04 指令：项目进入 **PLAYABLE-FIRST / 可玩成果优先模式**。目标 = **尽快形成真实、可玩的纵向切片**；不再追求「先把所有基础设施做到非常完整」。

优先级：**可玩性 > 核心玩法 > 界面与操作 > 稳定性 > 工程完美度**。

| 卡 | 内容 | 负责人 | 状态 |
|---|---|---|---|
| PET-61 | **ENGINE-4.7.2**：Godot 4.7.1 → 4.7.2 + 新基线（前置） | Claude | `ACCEPTED` |
| PET-63 | **FP 1/4** 蓝图可编辑：节点拖放 + 连线（CORE→FUNCTION→WEAPON） | Claude | `ACCEPTED`（DSH 独立复核通过，提交 `e40629c`，已推送；证据见本节末注） |
| PET-64 | **FP 2/4** 机器运行：CORE 信号 + Split/Amplify/Delay + Needle/Bomb/Saw 开火 + 基础 Heat | Claude | `ACCEPTED`（DSH 独立复核通过，提交 `c6e085f`，已推送；证据见本节末注） |
| PET-65 | **FP 3/4** COMBAT 真实：Slime/Runner 生成推进 + 三武器伤害结算 + 死亡 | Claude | `ACCEPTED`（DSH 独立复核通过，提交 `d122d3d`，已推送；证据见本节末注） |
| PET-66 | **FP 4/4** 循环闭合：3 波 + REWARD 三选一 + 回 PREPARATION + Overheat | Claude | `ACCEPTED`（DSH 独立复核通过，提交 `84d18e9`，已推送；**FIRST PLAYABLE 完成**，证据见本节末注） |
| PET-62 | **Visual Batch 01**（并行）：MAIN MENU / PREPARATION / COMBAT UI Kit | Codex | `APPROVED`（有条件批准，见 `13`） |
| PET-67 | **I18N-MIN** UI 中英可切换：Godot CSV 翻译表（中文原文 = key → en）+ 最小语言开关 + 持久化 | Claude | `ACCEPTED`（DSH 独立复核通过，提交 `f26db75`，已推送；证据见本节末注 —— 含「PET-70 拆弹未被重新装上」的独立探针核验） |
| PET-68 | **VB-01b** 三张 UI Kit 补英文标签版 + 中英版式容纳结论 | Codex | `REVIEW`（复核：英文版与原图逐字节相同，容纳结论不成立） |
| PET-69 | **VB-02** UI Kit 组件化制作 + 批准附带小改（含 COMBAT 越框修正） | Codex | `DONE`（用户 2026-10-04 批准组件方向） |
| PET-71 | **VB-03** 正式组件切图 + `_approved/` 流程（基础组件语言 v1，含 `13 §10` 三修） | Codex | `ACCEPTED`（**资产侧**；2026-10-04 由 **PET-73 / VB-04** 收口 —— 24 张切片 + `.import` 已落 `assets/_approved/vb03_component_language/` 并由 DSH 逐张复核通过，见 §4.1 末注；**仅剩** HUD Block 运行时集成，即待办 **R3**；issue 卡仍 `in_review`，`done` 属用户） |
| PET-70 | **UI-KIT 接入**（MAIN_MENU + COMBAT 结构）：按批准 Kit 建场景结构，placeholder 资源 | Claude | `ACCEPTED`（DSH 独立复核通过，提交 `1af0c42`，已推送；证据见本节末注 —— 开卡前置 `weapon_kind` 同批落地） |
| PET-72 | **S4-07 最小版 · 奖励真的生效**：清空一波后的三选一，选中的那一项**真的落到玩家蓝图**（正确的 `function_kind` / `weapon_kind`、画布内第一个空闲格、立即落盘）；跨场景传递走既有载体，不新造全局单例。**不做**掉落池 / 稀有度 / 权重。**顺带结清** R1（`full_loop_smoke` 补 `weapon_kind`）与 R5（仓库槽位名走 `tr()`）—— 三者都落在同一批文件 | Claude | `TODO`（2026-10-04 DSH 自 `BACKLOG` 提升 —— 承接 `PET-37` 交用户亲测时登记的「三选一目前只是『选给你看』」；已挂条件唤醒 `status = in_review`） |
| PET-73 | **VB-04** VB-03 组件切片收口：Godot 导入设置（`.png.import` 九宫格落点 = `StyleBoxTexture`）+ `_approved/` 流程走完 + 可用清单 | Codex | `ACCEPTED`（2026-10-04 DSH **逐张**复核通过并已推送 `main`，见 §4.1 末注；**未新开 gameplay 方向** —— 下一个玩法里程碑等 `PET-37` 的用户试玩反馈定向） |
| PET-74 | **BUILD-WIN** 双击可玩的 Windows 调试包：`export_presets.cfg` **仅新增** `Windows Desktop` 段（debug）→ `build\windows\PixelFusion.exe`（产物不入库） | Claude | `ACCEPTED`（2026-10-04 DSH 复核通过并已推送 `main`，见 §4.1 末注；**窗口尺寸实测 1280×720 = 4× 整数放大**） |
| PET-75 | **PLAY-01 · 用户试玩反馈 #2** 蓝图节点删不掉：删除 / 撤销（`Ctrl+Z`）/ 清空（S2-05 补课） | Claude | `ACCEPTED`（2026-10-04 DSH 独立复核通过并已推送 `main`，见 §4.1 末注；**唯一红项 I18N 由 DSH 集成补齐**） |
| PET-76 | **PLAY-02 · 用户试玩反馈 #3** 战斗看不懂：武器 / 命中 / 结果 的可读反馈（依 `13 §18` 克制原则） | Claude | `ACCEPTED`（2026-10-06 DSH 独立复核通过并已推送 `main`，见 §4.1 末注；**复核因平台 run 卡死而延迟约 8 小时**，交付本身逐项复跑全绿） |

| — | 退出期资源清点：`palette.gd` / `palette.tres` 未释放（已复核、非阻塞；随下一张触碰该文件的卡一并修） | Claude | `BACKLOG` |
| R1 | `tests/integration/full_loop_smoke.gd` 仍按老写法建武器节点（无 `weapon_kind`）→ 每次跑出 5 条 `WeaponData.resolve` 降级 `push_error`，且该用例的武器全部落到 Needle。**一条参数即可消除**（`09 §5` 的 ERROR 零增量） | Claude | `BACKLOG` |
| R2 | COMBAT HUD 正式分层收口：`06 §8.1` 五格冻结 vs `13 §5` 的二级 `GOLD` / `NEXT`（**不在**五格内），以及与 Machine 面板「左下」（`13 §5`）的冲突 —— 需同时改 `06 §8.1`、`13 §5` 落点与 `signal_flow_smoke` 的整宽机器区断言 | Claude | `BACKLOG` |
| R3 | VB-03 HUD 分级切片（`ui_hud_block_primary_72x24` / `secondary_48x20`，`assets/ui/vb03_component_language/`）装不进 `06 §8.1` 五格横排（3×72 + 2×48 = 312 > 272 可用宽）→ 未接运行时； | Codex | `BACKLOG`（**半条已结**：`assets/ui/vb03_component_language/asset_manifest.json` 的 `status` 已由 `PET-73` 随批准流程改为 `user_approved`，不再是 `pending_dsh_review`；**尺寸半条仍开** —— 切片装不进五格、未接运行时，与 R2 同批） |
| R4 | 主按钮切片 64×20 与主菜单四按钮 90×20（`tests/unit/test_input.gd` 命中区表）不一致 —— 是否按切片尺寸重排待定 | Claude | `BACKLOG` |
| R5 | `blueprint_workspace._draw_warehouse()` 的 7 个仓库槽位名走 `draw_string(String(entry["name"]))`，**不经 `tr()`** ⇒ 英文态下这 7 个标签仍是中文（DSH 独立取帧逐像素实测：底部仓库墨迹带在 zh / en 两帧完全相同）。`06 §11` 的旧缺口、**不在 PET-67 的 ALLOWED FILES** 内，故不判 PET-67 未达 DoD；**不静默豁免**，并入 `PET-72`（同一文件，单一写手） | Claude | `BACKLOG` |
| R6 | `tests/integration/test_state_loop.gd` 的 `S1-12 · R1`「COMBAT 停 10 分钟不动」按**墙钟预算**推进模拟时间（`line 372-373`：`elapsed < 600s` **且** `Time.get_ticks_msec() < deadline`）—— 机器一忙就跑不满 600 秒，该用例稳定输出 **4 条按名转红**（状态 3→5、场景换到 `result.tscn`、切换数 +1、清空入口）。DSH 在**未改动的 `1a6f874`（HEAD）**上用同一命令复现出**逐字相同**的 4 条 ⇒ **非 PET-75 回归**，属测试自身的时序脆弱性。修法（下一张触碰该文件的卡一并做）：把 10 分钟压进模拟时钟（`--fixed-fps` 之外改由 `TestClock` 直接推进）或把 deadline 抬到模拟跑满为止 | Claude | `BACKLOG`（**非阻塞**：`09 §1.1` 的 L1 只要求本模块不退化，且 HEAD 同结果） |
| R7 | **流水线驱动不可靠（本次停摆 8 小时的直接原因，属平台/进程层，非代码缺陷）**：`PET-76` 的条件唤醒 `status = in_review` 于 `2026-10-06T03:16:35Z` **确实触发**并起了 DSH 复核 run `01a10f36`；该 run 只把 `PET-76` 置 `in_progress` 后即**卡死**，任务记录至今停在 `running`（另一条 `01a10f35` 同样停在 03:15）。此后：① 条件已不再满足（`in_progress`）⇒ 事件唤醒无望；② 03:33 的一次性 `at` 安全网 `fire_count = 0` **从未触发**；③ 30 分钟巡检已于 10-04 关闭 ⇒ **没有任何独立驱动**。处置：巡检**重新武装为按小时周期**（唯一不依赖单卡状态的驱动），并保留「每个交付卡各挂一条 `at` 安全网」。**未证实**：`at` 不触发究竟是平台调度缺陷还是被同 issue 的 `running` 僵尸 run 压制（无平台侧日志可查）——**不编根因**，只登记现象与规避手段 | DSH | `OPEN`（**观察中**：下次任一卡交付若仍出现「无 run、无唤醒」即为复发） |

**执行纪律（用户 2026-10-04）**：

- 短批次（2–4 小时），**每批必须产出肉眼可见的玩法进展**；
- 测试按 `09 §1.1` **分级执行**：普通卡 L1，功能块 L2，只有里程碑 / 引擎升级 / 核心架构改动 / RC / 用户验收前才上 L3；
- 无依赖关系的任务**并行**（Claude 玩法 ‖ Codex 美术 ‖ 既有模块回归）；
- **不做**与当前玩法无关的工具建设、过度测试覆盖、非阻塞引擎调查、自研调试工具；
- FIRST PLAYABLE 完成前**暂缓**：Boss、大量武器/敌人、天赋树、Meta 成长、商店、剧情、存档、成就、多语言、音乐系统、正式发布包、大量特效、完整 Balance Lab；
- 允许占位美术（程序占位 / 像素块 / 临时图标），**正式美术不得阻塞玩法**。

**FIRST PLAYABLE 验收（用户亲测）**：开始 → 蓝图拖节点 → 连线 → 开始战斗 → 敌人推进 → 机器运行 → 武器攻击 → 杀敌 → 三选一 → 回蓝图 → 改机器 → 再打一波。任一步是假界面即不算完成。

> **2026-10-04 更新**：**PET-61 已验收 —— Godot 4.7.2 成为新基线**（4.7.2 引擎 + 完整导出模板已落 D:/E:，4.7.1 原样保留可回滚；L3 十项全绿、ERROR/WARNING 零增量、Web Debug 导出通过、像素缩放 4× 整数）。**PET-60 转为「已通过引擎升级规避 / 等待长期观察」**：保持 OPEN、崩溃记录不删、不再主动投入。**PET-63 已开工**。

> **2026-10-04 三张 UI Kit 正式裁定**：**有条件批准（APPROVED WITH MINOR REVISIONS）** —— 完整硬约束见 **`13_VISUAL_RULING.md`**（新建）。PREPARATION **通过**（优先；PET-63 已交付待复核）；MAIN_MENU **小改后接入**（PET-70）；COMBAT **先整理信息层级再接入**（PET-70）。Codex 转**组件化**（PET-69 → VB-02）。**硬约束：不得擅自增加 主角 / 吉祥物 / 陪伴系统 / 剧情角色**（`13 §2`）。优先级：`FIRST PLAYABLE > UI 细节打磨 > 大量正式美术`。

> **2026-10-04 PET-63 验收（`ACCEPTED`，提交 `e40629c`，DSH 已推送）** —— DSH **不采信自报**，在**干净树**上重跑 L1：工作区 `3c0a6fd` 全新 checkout，只把 ALLOWED FILES 里的改动放进去（未改动文件与 `main` 逐字节相同）。
>
> - **L1 结果（四处全部 `exit=0` / 失败项 0）**：unit + integration **1625/1625 · 356/356**；PREPARATION 场景冒烟 **86/86**；蓝图场景冒烟 **79/79**（**非 headless**，`--resolution 320x180`）。
> - **取证独立复现**：DSH 自己跑出的 `tests/output/blueprint_first_playable.png` 与交付方附件 **SHA256 完全相同**（`B2915662…4815E`），320×180、534 色、以 `NAVY` 为底 —— 是真实渲染帧，不是重画。
> - **负向对照**：把 `blueprint_workspace.gd` 的 `_connect()` 改成恒返回 `false` → 恰好 **12 条**按名转红（1628/1640，全部落在「连线 / 落节点 / 存读往返」），恢复后文件哈希复原、重跑回绿。测试不是恒真断言。
> - **改动面核对**：仅 `scripts/ui/blueprint_workspace.gd`（新）· `scripts/ui/preparation_screen.gd` · `scenes/preparation/preparation.tscn` · `tests/unit/test_blueprint_workspace.gd`（新）· `tests/integration/blueprint_smoke.gd`（新）· `tests/unit/run_tests.gd`（**+1 登记行**）＋ 3 个 `.gd.uid` 引擎旁挂文件。`scripts/data/**` 未改（S2-02 数据类直接复用）；`docs/**` · `project.godot` · 其它场景 · `assets/**` **未触碰**。卡上点名的 `tests/integration/run_integration.gd` 在仓库中不存在，未新建 —— 集成层本就并入 `run_tests.gd`，判断正确。
> - `13 §4` 核对：蓝图区（CENTER `128×124`）仍是**面积最大的分区**（仓库 `294×48`）；节点类型只用「图标 / 边框 / 小分类色」区分，颜色**全部经 `Palette`**，无裸色值、无彩虹配色；PREPARATION **未引入任何人物 / 吉祥物**。
> - **环境说明（非本卡缺陷）**：本卡在 DSH 沙箱内首次复跑时 `user://` 不可写（`%APPDATA%\Godot\app_userdata\PixelFusion` 被沙箱拒绝，`ERR_FILE_CANT_WRITE`），导致 7 条与本卡无关的假红（含 S2-02 的 4 条）；把 `APPDATA` 重定向到工作区内即复现交付方的 1625/1625。**`09 §4` 的「先 `--headless --import` 刷类缓存」同样是必需前置**，否则 `Palette` 等一系列假红。
> - **遗留（转 Codex，非阻塞）**：`assets/_review/pending/visual_batch_01/` 下 3 个 `*.png.import` 是 `--headless --import` 的**引擎产物**（DSH 已在自己的干净树复现其成因）；本仓库**不追踪任何 `.import` 文件**（已入库 `*.png` 亦无旁挂），故不入库、不删、随下次导入自然重建。
> - **视觉偏离登记（接受，理由成立）**：不使用引擎原生 drag-and-drop 之外的输入分支（`03 §8` 未被破坏，`scripts/input/**` 也不在授权范围）；`RegionCenter/Title` 占位标题隐藏、底条仓库由占位 Label 换成真实槽位 —— 均在 `preparation.tscn` 授权范围内。

> **2026-10-04 追加裁定**：三张 Kit 批准为 **FIRST PLAYABLE 正式结构基线**（结构 / 组件基线 + 开发期视觉资源，**不是最终美术**）。**不再因 UI Kit 阻塞 Gameplay**。优先级切换为 **`FIRST PLAYABLE Gameplay > UI Kit 继续打磨`**。**下一批主交付目标 = 一个实际可玩的 Godot Build**（PREPARATION → 拖放 → 连线 → 战斗 → 敌人推进 → 武器攻击 → 死亡 → REWARD 三选一 → 返回）。细则见 `13 §9`。

> **2026-10-04 VB-02 组件 Kit 批准**：定义为 PixelFusion **正式基础 UI Component Language v1**（**非最终视觉完成度**）。`Panel` / `Button` 五态 / `Inventory Slot` / `HUD 分级` / `Tooltip` / `Progress Bar` / `Frame` / `Disabled` **全部通过**；**正式产出前 3 个小修**（`Focus` 与 `Selected` 语义区分 · 类型色小面积辅助识别、深蓝卡身不变 · 不得为「更精致」堆 Panel 装饰）见 `13 §10`。可**批量产正式资源**并推进 `_approved/`（PET-71）。**PET-70 仍等 PET-64；UI 不得再打断 FIRST PLAYABLE。**

> **2026-10-04 PET-64 验收（`ACCEPTED`，提交 `c6e085f`，DSH 已推送）** —— DSH **不采信自报**，按卡上写明的 **L1**（`09 §1.1`，未擅自上 L3）在交付树的一份独立副本上逐项复跑，并**另写一份自己的探针**（不复用交付方用例）从零搭蓝图、逐拍驱动 `MachineRuntime`。
>
> - **L1 结果（全部 `exit=0` / 失败项 0）**：unit + integration **1773/1773 · 356/356**；COMBAT 场景冒烟 **103/103**；信号流冒烟 **38/38**（**非 headless**，`--resolution 320x180`，真实 GL 渲染）。
> - **像素取证独立复现**：第 0 拍示意区 `BLUE_050 = 0 px`、第 23 拍 `= 120 px`（信号火花 + 点亮描边），走廊内弹丸芯 `BLUE_050 = 4 px` / 弹丸体 `BLUE_FX_600 = 12 px` —— 与交付方自报**逐位一致**。
> - **负向对照**：注释掉弹丸那一行 `_draw_spark()` → 冒烟恰好 **36/38**、`EXIT=1`（两条走廊像素断言按名转红）；恢复后文件与交付方原文件 **SHA256 相同**、重跑回绿。像素断言不是恒真断言。
> - **独立探针（DSH 自写，14/14）**：`CORE→Split→Amplify→Needle` 首发拍号 **22**、此后每 **10** 拍一发；`Heat` 每发 **+2**（第 5 发 = 10.0）；Amplify 出边信号值恒 **2.0**；Split 两条出边**同拍**各送一枚（`w1`/`w2` 同拍开火）；Delay 链首发第 **30** 拍（= 10 + 4 + 12 + 4）；无 CORE 时 50 拍零开火；同蓝图两遍开火序列一致（确定性）；直通节点出边 = 1.0（反向对照）。
> - **改动面核对**：全部落在 ALLOWED FILES —— `scripts/gameplay/**`（新）· `scripts/data/node_data.gd` · `scripts/ui/blueprint_workspace.gd` · `scripts/ui/combat_screen.gd` · `scenes/combat/combat.tscn` · 两个新测试文件 · `tests/unit/run_tests.gd`（**+1 登记行**）＋引擎 `.gd.uid` 旁挂；`docs/**` · `assets/**` · `preparation.tscn` **未触碰**。
> - **交付方三点待复核的裁定**：① `scripts/gameplay/` **保留**（`02 §4` 的目录清单是拆分指引而非闭集；`nodes/` 是单节点行为、`combat/` 是伤害与 Heat 结算，本卡是「整机固定节拍仿真 + 时间模型」，新目录职责更清晰）—— DSH 随后把该目录补进 `02 §4`；② 两个新测试文件超 `02 §4` 的 300 行（净 `503` / `316`）**接受**（卡上只允许新建这两个文件，仓库既有测试已有同量级先例）；③ VIEWER 描边在示意区上沿外溢 1px —— **接受，不改**（不影响可读性与判据）。
> - **环境说明**：本复核 run 的沙箱为 `workspace-write`，`D:\` 与工作区 `.repos` 的写入、`git push` 首先被拒；经**授权的提权重试**后，把交付提交 `061869e` **cherry-pick** 到 `main` 得 **`c6e085f`** 并推送（内容与 `061869e` 逐字节一致），另把交付分支 `agent/claude-lead-developer/7dfe06153c7f` 推至 origin 留档。

> **2026-10-04 PET-65 验收（`ACCEPTED`，提交 `d122d3d`，DSH 已推送）** —— DSH **不采信自报**，按卡上写明的 **L1**（`09 §1.1`，未擅自上 L3）在交付树的一份独立副本上逐项复跑，并**另写一份自己的探针**（不复用交付方用例）从零搭「只有 CORE」与「CORE→分流→针×2」两台机器逐拍驱动 `CombatSimulation`。
>
> - **L1 结果（全部 `exit=0` / 失败项 0）**：unit + integration **1904/1904 · 356/356**（基线 `affe14d` = **1773/1773 · 356/356**，净 +131 全在新增单测）；COMBAT 闭环冒烟 **74/74**、既有 COMBAT 冒烟 **103/103**（**非 headless**，`--resolution 320x180`，真实 GL 渲染）。
> - **像素取证独立复现**：第 0 拍两泳道判据色 **0 px**（负对照）→ 第 20 拍道 0 `RED_600 = 68 px` → 第 74 拍道 0 归零、道 1 `RED_500 = 40 px` → 第 82 拍全清 **0 px** —— 与交付方自报逐位一致；**交付的 8 张截图与本机重跑产物 SHA256 全部相同**（真实渲染帧，不是重画）。
> - **独立探针（DSH 自写，39/39）**：出场拍号 **10 / 30 / 50 / 70**、种类 `Slime/Runner/Slime/Runner`、泳道 `0/1/0/1`；实测推进速率 **0.008 / 0.02**（Slime 慢而肉、Runner 快而脆）；无武器机器漏怪拍号 **80 / 120 / 135 / 175**、`CORE` 100→75→50→25→0、第 **175** 拍 `run_failed`；`CORE→分流→针×2` 击杀拍号 **28 / 38 / 68 / 78**（四只全部血量归零）、第 **82** 拍 `wave_cleared`、`CORE` 满血 —— 与交付方自报一致。
> - **负向对照（DSH 自选，非交付方那三条）**：把 `CombatSimulation._strike()` 改成不结算伤害 → 自写探针 **27/39 转红**、交付方 L1 **1887/1904 · 17 条按名转红**（针/炸弹/锯的命中与击杀、清空、终局空转）；恢复后文件 SHA256 复原、重跑回绿。断言不是恒真。
> - **改动面核对**：16 个文件全部落在 ALLOWED FILES —— `scripts/data/{enemy_data,weapon_data}.gd`（新）· `scripts/gameplay/{enemy_state,combat_simulation}.gd`（新）· `scripts/gameplay/machine_driver.gd` · `scripts/ui/combat_screen.gd` · `scenes/combat/combat.tscn`（新增 `EnemyLayer`）· 两个新测试文件 · `tests/unit/run_tests.gd`（**恰好 +1 登记行**）＋ 3 个 `.gd.uid`；`docs/**` · `assets/**` · 其它场景**未触碰**；`scripts/**` 里**零字面色值**（`13 §6`）、**零 `randi()`/`randf()`**（`03 §6`）。
> - **`13` 号裁定核对**：敌人在**战场**上（`EnemyLayer` 挂在 `Battlefield` 下），底栏仍只有状态读数（`13 §5` 未被破坏）；两种敌人共用「危险」红、靠 8px / 6px 尺寸与行为区分（不在同一语义里造伪危险等级）；`13 §9.5` 相关的开发期占位文案 `占位战场：…` **保留**（PET-63 的既有用例要求该节点存在），**随正式美术落地时一并清掉**。
> - **交付方两点待裁定的裁定**：① `NodeData` 缺武器种类字段、`WeaponData.resolve()` 按**显示名**反查 —— **接受**（`02 §9` 允许的降级路径；本卡 ALLOWED FILES 不含 `blueprint_workspace.gd`），但这是 **I18N 的定时炸弹**（PET-67 一改翻译名就会全量落到降级分支），**必须**在 `PET-70` / `PET-67` 开卡时先给 `NodeData` 补 `weapon_kind`、由仓库槽位直接写入；② `combat_loop_smoke.gd` 不登记进 `run_tests.gd` —— **接受**（`tests/integration/` 下 12 个冒烟无一登记，`run_tests.gd` 头注已写明「场景冒烟必须独立进程」）。
> - **已知非阻塞项**：退出期 `3 ObjectDB / 2 resources` 与基线（`affe14d`）**逐字相同**，非本卡增量。

> **2026-10-04 PET-71（VB-03）交付与复核**：24 张 token 驱动切片 + 4 张预览已入库（`assets/_review/pending/vb03_component_language/` 与 `assets/ui/vb03_component_language/`）。**DSH 只核过程与硬约束**：`asset_manifest.json` 的 `constraints` 逐条对上 `13 §10.1` 三修 —— `focus_semantics = BLUE_300 light corner/thin frame`、`selected_semantics = GOLD_500/GOLD_200 primary emphasis`、`type_color_rule = small marker only; unified NAVY card body remains unchanged`；九宫格边距 / 尺寸 / Token 名列齐；`status` 仍为 `pending_dsh_review`（**未**自行进 `_approved/`）。**视觉判断属 Codex / 用户**。`_approved/` + 场景集成随 **PET-70**（等 PET-66 让位，单写手）。

> **2026-10-04 PET-66 验收（`ACCEPTED`，提交 `84d18e9`，DSH 已推送）—— FIRST PLAYABLE 完成** —— DSH **不采信自报**，按卡上写明的 **L2**（`09 §1.1`，**未擅自上 L3**）在交付树的一份**独立副本**上逐项复跑。
>
> - **L2 结果（全部 `exit=0` / 失败项 0）**：unit + integration **1943/1943 · 426/426**（`--fixed-fps 600`，headless）；十套场景冒烟 **COMBAT 103/103 · REWARD 165/165 · RESULT 92/92 · PREPARATION 86/86 · input 41/41 · BOOT 31/31 · MAIN_MENU 67/67 · blueprint 79/79 · signal_flow 38/38 · combat_loop 75/75**（后三套**非 headless**，`--resolution 320x180`，真实 GL 渲染）。
> - **完整循环取证独立复现**：DSH 用自己的窗口重跑重出全部 10 张 `full_loop_*.png` 与联络表，**SHA256 与交付方附件逐张相同**（主菜单 → 整备 → 第 1/2/3 波 → 三选一 → 回整备 → 结算 → 再来一局）；另 8 张 `combat_loop_*` / 4 张 `signal_flow_*` / 蓝图取证图同样**逐张相同** —— 是真实渲染帧，不是重画。
> - **负向对照（DSH 自选，非交付方那三条）**：① `RunState.advance_wave()` 改成恒不推进 → 完整循环用例 **12 条按名转红**（波次读数 `2/3`·`3/3`、末波判定、末波清空 → RESULT、结算读数与落点）；② `MachineRuntime._fire()` 的过热置位改成永不可达 → **4 条按名转红**（`test_heat` 的触发/广播、`test_signal_flow` 的阈值）；两处恢复后文件 SHA256 与交付方一致、重跑回绿。**新断言不是恒真。**
> - **一致性核对**：`RunState.TOTAL_WAVES = 3` 与 `CombatSimulation.WAVES` 三张表（4 / 6 / 8 只）的条数由 `full_loop_smoke` 钉住；难度只靠**出怪条数**递增（不动 PET-65 已取证的伤害数值）；第 1 波仍是 PET-65 取证的那四只 `Slime/Runner/Slime/Runner`；`RESULT` 读 `RunState.current_wave()`（`end_run()` **刻意保留**结束时的波次）→「坚持到第 3 波」；「再来一局」`start_run()` 复位到第 1 波。
> - **卡外改动（4 处，交付方已逐条声明）→ 裁定：接受**：① `scripts/ui/combat_screen.gd` + `scenes/combat/combat.tscn`（`波次` 读数接 `RunState` 拼 `n/3`、本波清空分「非末波 → REWARD / 末波 → RESULT」两条路、开局落在**唯一**读 `RunState` 的玩法场景）；② `tests/unit/test_signal_flow.gd`（旧的「Heat 恒等于 MAX 且单调不减」在 Overheat 落地后**必红**，改为「到阈值确实触发」）；③ `tests/integration/combat_smoke.gd`（`波次` 期望 `1/1` → `1/3`，刻意写死以钉住总数）；④ `tests/integration/combat_loop_smoke.gd`（离屏那一幕先拨回第 1 波）。四处**全部在本卡语义范围内**、`docs/**` · `assets/**` **未触碰**、**未 push**。
> - **交付方两点待裁定 → 裁定**：① **过热不做独立视觉元素** —— **接受现状**：`06 §8.1` 把状态带冻结成恰好 5 个只读读数块，动它属 UI Kit 接入范畴；过热在画面上的表现 = `热量` 从 100% 掉回 0% + 武器数秒不开火。**把「过热需要可辨识的状态提示」登记为 `PET-70` 的输入项**（**不阻塞**本卡）。② `reward_screen` 只展示并交出 `get_chosen_option()`，**奖励效果**（掉落池 / 稀有度 / 生效）属 S4-07 —— **接受**（卡面写明「选项可以是固定池」）。
> - **PET-65 登记待办（开卡前置）**：`NodeData` 仍无 `weapon_kind`，`WeaponData.BY_DISPLAY_NAME` 这条**按显示名反查武器**的临时桥仍在（`resolve()` 一旦认不出就 `push_error` + 按 Needle 降级；`PET-67` 一改翻译名即**全量**落到降级分支）。**必须在开 `PET-70` / `PET-67` 时先做**，已写进两卡的开卡前置与本卡关记录。
> - **环境说明（非本卡缺陷）**：DSH 沙箱下 `user://` 需把 `APPDATA` / `LOCALAPPDATA` / `TEMP` 重定向进工作区（否则 8 条落盘假红），且**必须**先 `--headless --import` 刷类缓存（`09 §4` v0.1.4，否则 `Could not find type "Palette" / "NodeData"` 全线假红）。两者都排除后与交付方自报**逐位吻合**。
> - **下一步**：**FIRST PLAYABLE 完成 ⇒ 已在 `PET-37` 交用户亲测**（14 步完整循环 Build）；**`PET-70` 提升为 `TODO`**（单写手），`PET-67` 仍 `BACKLOG` 排其后。

> **2026-10-04 PET-70 验收（`ACCEPTED`，提交 `1af0c42`，DSH 已推送）** —— DSH **不采信自报**，按卡上写明的 **L1**（`09 §1.1`，**未擅自上 L3**）在交付树的一份独立副本上逐项复跑；追加了**基线对照**与**反向对照**（`09 §4` 的判别力要求）。
>
> - **L1 结果（全部 `exit=0` / 失败项 0）**：unit + integration **2043/2043 · 426/426**（`--fixed-fps 600`，headless）；场景冒烟 **MAIN_MENU 67/67 · COMBAT 106/106 · blueprint 82/82 · combat_loop 75/75 · signal_flow 38/38 · input 41/41**（**非 headless**，`--resolution 320x180`，真实 GL 渲染：NVIDIA RTX 4060 / OpenGL 3.3）；像素探针 **284 / 0 失败**（`09 §4` 要求：本批改了场景视觉权重并宣称「层级已落地」，故必须跑）。
> - **基线对照**：未改动的 `24a8685` 同一命令 **1943/1943 · 426/426**，`ERROR` **38** 行，退出期 **3 ObjectDB / 2 resources** —— 与本批复跑逐项对齐；本批 unit 净 **+100** 条全在新增用例。
> - **反向对照（DSH 自选）：把 PET-70 的 7 个源码文件换回基线、只留 PET-70 新增/改写的 9 个测试文件 → 恰好 17 条转红**（3 条用例脚本因缺 `WeaponKind` 无法编译 + 14 条按名转红：Logo 翻译入口、ArtSkyIsland / ArtGirl / ArtCat 未拆、LogoSlot / DecorationSlot / VersionLabel 缺失、三块一级读数字号仍为 8、三块一级标题仍取次级色、两级差一档）。**新断言不是恒真。**
> - **开卡前置（PET-65 登记待办）已落地**：`weapon_data.gd` 的 `BY_DISPLAY_NAME` 与显示名反查分支**已删**，`resolve()` 改读 `NodeData.weapon_kind`；`WeaponKind`（`NONE` 排第一兼缺省值与旧存档落点）由 `blueprint_workspace.WAREHOUSE` 第 5 列在落节点时写入；旧存档（`.tres` 里没有该字段）由 `test_blueprint_data.gd` **从真实落盘文件删掉那一行**后载回，得 `NONE` 且 `resolve()` 按 `02 §9` 降级到 Needle（**不是** `null`、「开火不掉血」那条最难查的路被挡住）；`NodeData.WeaponKind` 与 `WeaponData.Kind` 两份独立枚举的逐项对应由 `test_combat_damage.gd` 顶住。
> - **截图独立复现**：交付的两张附件**与本机重跑产物 SHA256 逐张相同** —— `combat_loop_spawn_4x.png` = `48DE7C65…`、`pet70_main_menu_4x.png` / `full_loop_01_menu.png` = `FE5E248E…`：真实渲染帧，不是重画。
> - **像素级核对（DSH 自量，320×180 原生帧）**：状态带五格中**一级读数墨迹 8px（波次 / CORE / 热量）· 二级 6–7px（能量 / 队列）**；标题色一级 `BLUE_100`（对 `NAVY_800` **11.75:1**）vs 二级 `GREY_300`（**9.37:1**）；主菜单 Logo 墨迹 `x81..239`（中心 160 = 画面中心，占宽 50%）、左侧装饰位是 `x8..92 / y44..172` 的既有面板变体、右下版本行 `x249..311 / y163..168` 右对齐且为次级色、**旧 `ArtCat` 框内 0 个墨迹像素、8px 安全区内 0 个墨迹像素**（`13 §2` / `§3.1` / `§3.2` / `§3.3` 全部落到像素）。**过热提示的取色方向复核通过**：`ORANGE_600` 在本带底上实测 **2.96:1**（低于 `04 §3.7` 门槛），`ORANGE_500` 5.90:1 / `ORANGE_300` 9.42:1 —— 「更亮」而非「更深」成立。
> - **改动面核对**：**16 个文件全部落在 ALLOWED FILES**（含卡上追加的 `scripts/data/**` 前置三件）；`docs/**` · `assets/_review/**` · 其它场景**未触碰**；`.tscn` 无字面 `Color(`；COMBAT 仍零 Button、MAIN_MENU 仍 4 个；**未 push**（按卡）。卡面把主菜单场景写成 `scenes/main_menu/main_menu.tscn`，实际路径是 `scenes/menu/main_menu.tscn`（**卡面笔误**，交付方用的是真实文件）。
> - **`ERROR` 增量（`09 §5`）**：**44 行 vs 基线 38 = +6**，逐条归因 —— **5 条**来自 `tests/integration/full_loop_smoke.gd`（**不在本卡 ALLOWED FILES**，仍按老写法建武器节点 → 走 `02 §9` 降级），**1 条**是 `test_combat_damage.gd` 里**故意断言的旧存档负路径**（`09 §5` 明文豁免）。前者登记为待办 **R1**（不得静默豁免）。
> - **三处待裁定的裁定**：① **`06 §8.1` 五格冻结 vs `13 §5` 二级 `GOLD` / `NEXT`** —— **不动 §8.1**：按 `13 §9.1`「COMBAT 当前 HUD / 战场 / Machine 区 / 底栏结构允许直接接入」与 `§9.7`「本阶段不再要求完整 UI 大稿重新审批」，本批的**交集口径**（一级 = 波次 / CORE / 热量；二级 = 能量 / 队列）**接受为过渡**；正式收口登记为 **R2**（与 R3 同批）。② **VB-03 HUD 分级切片装不进五格** —— **不接入**（`3×72 + 2×48 = 312 > 272` 可用宽；其 manifest 仍 `pending_dsh_review`，用户批准也未走），登记 **R3**。③ **Machine 面板「左下」vs 已被 `signal_flow_smoke` 钉住的整宽机器区** —— **保持现状**（改用例属卡外），登记 **R2**。附带问题（主按钮切片 64×20 vs 90×20 命中区表）登记 **R4**。依据 `13 §9` 的优先级 `FIRST PLAYABLE Gameplay > UI Kit 继续打磨`：**一律不为这几处再阻塞玩法**。
> - **视觉「够不够分明」的主观判断仍属 Codex / 用户**（DSH 给出的是可量测证据：字号 10 vs 8、墨迹 8px vs 6–7px、对比度 11.75:1 vs 9.37:1）。`13 §5` 的原文口径是「二级**视觉可稍弱**」，本批落在这一档。
> - **报告口径待补（非阻塞）**：交付方 `TEST REPORT` 未按 `09 §5` v0.1.7 单列「退出期资源清点」—— 实测与基线一致（3 / 2），已在册缺陷（`palette.gd` / `palette.tres`），仅记口径。
> - **环境说明（非本卡缺陷）**：本复核 run 把 `APPDATA` 重定向进工作区并先 `--headless --import` 刷类缓存（`09 §4` v0.1.4）；未做这两步时会看到 9 条 `user://` 落盘假红与 `Could not find type "Palette"` 全线假红。**本复核 run 的沙箱禁止写工作区外的 `.repos`**（`git` 索引锁被拒），交付提交由**授权的提权重试**完成。

> **2026-10-04 PET-67 验收（`ACCEPTED`，提交 `f26db75`，DSH 已推送）** —— DSH **不采信自报**，按卡上写明的 **L1**（`09 §1.1`，**未擅自上 L3**）在交付树的**独立副本**上复跑，并**另写两份自己的探针**（不复用交付方用例）。
>
> - **L1 结果**：unit + integration **2385/2386 · 426/426**（`--fixed-fps 600`，headless）；MAIN_MENU 场景冒烟 **67/67**、`exit=0`（非 headless，`--resolution 320x180`，真实 GL：RTX 4060 / OpenGL 3.3）。
> - **基线对照（本批最重要的一条结论）**：未改动的 `913d57f` 同一命令、同一环境 **2037/2038 · 426/426**，失败项**逐字相同**（`BlueprintWorkspace · 落节点写入 weapon_kind :: 应落出 5 个节点（期望 5，实际 8）`）⇒ **该失败在 PET-67 之前就存在、与环境相关（`user://` 重定向下 `_cleanup()` 未生效），不是 PET-67 的回归**；本批 unit **净 +348 条全绿**。交付方自报的 `2391/2391` 在本环境不可复现，差异全部落在这条既有失败上。
> - **重点核验「PET-70 拆掉的定时炸弹没被重新装上」—— 结论：没装上，证据三条**：① 静态：`BY_DISPLAY_NAME` **零命中**，`resolve()` 只读 `NodeData.weapon_kind`，拖放载荷**直接带 `weapon_kind`**，全仓无一处把显示名回流到解析；② **DSH 自写探针（24 项 / 0 失败）**：在翻译表生效、`locale=en` 下，把武器节点 `display_name` 换成**英文译文**（`tr("锯")="Saw"`）乃至**完全不相干**的名字，解析结果仍由 `weapon_kind` 决定（`NEEDLE/BOMB/SAW` 各归各位）；③ 把真实落盘 `.tres` **删掉 `weapon_kind = ` 那一行**再载回 → **仍能载入**、节点数不变、解析按 `02 §9` 降级到 **Needle（不是 `null`）**，`CORE` / `null` 仍返回 `null`。
> - **`tr()` key 覆盖（DSH 自写扫描器）**：`scripts/**/*.gd` 含 CJK 字面量 —— **玩家可见 51 条 / 缺表 0 条**，另 **34 条**是 `push_error` / `push_warning` / `print` / `printerr` 的开发者日志（不译）；`scenes/**` 20 条中 17 条在表内，未进表的 3 条全是**有意占位**（`result.tscn` 的两条在 `_ready()` 必被 `tr(格式串) % n` 覆盖；`中 / EN` 是开关自身）。**一个不漏。**
> - **独立取帧核对「界面文案整体变英文」**：DSH 自写取帧脚本把 **PREPARATION** 在 `zh_CN` / `en` 下各渲一帧后**逐像素比对** —— 只有两处文字带变化（面板标题 `关卡信息→LEVEL INFO` y66–74、CTA `开始战斗→START BATTLE` y148–156）；**底部仓库 7 个槽位名的墨迹带两帧完全相同** ⇒ 英文态下这 7 个名字仍是中文。成因是 `_draw_warehouse()` 把 `entry["name"]` 原文直喂 `draw_string`、**不经 `tr()`**。**裁定：不阻塞本卡**（该缺口在 `blueprint_workspace.gd`，**不在本卡 ALLOWED FILES**；卡面覆盖率口径写明是「全部现有 `tr()` key」，此文案根本不经 `tr()`），但**登记 R5 并并入 PET-72**，不静默豁免。
> - **卡外改动（3 处，交付方逐条主动声明）→ 裁定：接受**：① `scenes/menu/main_menu.tscn`（+10 行，只加 `ButtonLang` 一个节点）—— 卡面建议的 `中 / EN` 按钮**必须**落成场景节点，而卡面 ALLOWED FILES 漏了它（**卡面自身缺陷**，先例同 PET-70 的路径笔误）；② `tests/unit/test_input.gd`（+1 行实测命中表）—— 该表自带「不得有漏网或多余」断言，多一个按钮必然多一行；③ `tests/unit/run_tests.gd`（+2 行排序说明注释，与同文件既有写法一致）。`docs/**` · `assets/_review/**` · 其它场景**未触碰**；**未 push**（按卡）。
> - **未上 L3**：全量 unit + 全部场景冒烟 + Web Export + 像素探针未跑，本卡不产生 L3 结论。
> - **环境说明（非本卡缺陷）**：本 run 沙箱 `workspace-write`，写工作区外 `.repos`（git 索引锁）与工作区外 Godot `editor_data` 被拒；复核在工作区内独立副本上完成，`APPDATA` / `LOCALAPPDATA` 重定向进工作区，并先 `--headless --import`（`09 §4` v0.1.4）。
> - **下一步**：`PET-72`（S4-07 最小版：奖励真的生效）已 `BACKLOG` → `TODO` 并挂同款条件唤醒（`status = in_review`），**R1 / R5 并入其中**；`R2 / R3 / R4` 仍 `BACKLOG`（UI Kit 口径，按 `13 §9` 不为它们阻塞玩法）。

> **2026-10-04 PET-73（VB-04）验收（`ACCEPTED`，DSH 已推送 `main`）** —— VB-03 组件切片的**收口卡**（`13 §10.1` 三修之后的正式产出 + Godot 导入设置 + `_approved/` 流程）。DSH 按卡面验收口径**逐张**复核（不是抽样），不采信自报。
>
> - **`_approved/` 内容与批准面**：`assets/_approved/vb03_component_language/` 下只有 `asset_manifest.json` + `slices/` 的 **24 PNG + 24 `.png.import`**；`_approved/` 全树**零**预览图、零 `visual_batch_01` 旧批次、零 `placeholder_`。`assets/ui/vb03_component_language/` 同样只有 24 PNG + 24 `.import` + `styleboxes/` 15 个 + manifest（**预览图不在正式接入路径上**）。
> - **导入参数与九宫格逐张对齐（24/24）**：全部切片 `importer=texture` / `type=CompressedTexture2D` / `compress/mode=0`（无损）/ `mipmaps/generate=false`；像素过滤由 `project.godot` 的 `textures/canvas_textures/default_texture_filter=0`（Nearest）保证（`07 §4`）。**15 张**带 `nine_patch` 的切片各配一个 `StyleBoxTexture`，其 `texture_margin_left/top/right/bottom` 与 manifest 的 `nine_patch` **逐张相同**（含 `panel_frame_main 3,16,3,3` 与 `overlay_focus 8,8,8,8` 两处非对称/宽边距）；**9 张**固定尺寸切片（节点卡 / 槽位）manifest 无 `nine_patch`，正确地**没有** StyleBox 旁挂。尺寸与文件名声明、manifest `size` 三者一致（`24x24` / `64x20` / `72x24` / `48x20` / `96x12` / `96x64` / `120x64` / `32x32` / `64x40`）。
> - **`.import` 是真引擎产物，不是手写**：24 个 `dest_files` 指向的 `.godot/imported/*.ctex` **全部实际存在**（三个副本各 24 个，四个目录共 **107 个 ctex**，时间戳同一批），说明确实跑过一次编辑器导入。`source_file` 逐张指回各自副本的真实 `res://` 路径（4 个副本的 `uid` / ctex 哈希各自独立、**零碰撞**）。
> - **`13 §10.1` 三修逐条对上（DSH 自量像素，非读注释）**：① **`Focus` / `Selected` 不混** —— `Focus` 一律 `BLUE_300` 细框或角标（按钮：1px 蓝框 + 四角角标 190px；槽位：整圈细蓝框 84px；节点卡：四角蓝角标 27px + 类型标记；overlay：100% `BLUE_300`），`Selected` 一律 `GOLD_500`/`GOLD_200` 主强调且**不含任何蓝**（槽位金框 84 + 金角 16；节点卡金双框 92+84；overlay 纯粹金），键盘焦点与实际选择**在切片上就是两种颜色**；② **类型色只做小面积** —— `CORE`/`FUNCTION`/`WEAPON` 卡身**同为 `NAVY_700` 407px（70.7%）**，类型标记恒为 `(2,2)` 的 4×4 = 16px（`GOLD_400` / `BLUE_400` / `ORANGE_500`），**无整圈高饱和边框**（武器最"热"也只用 16px `ORANGE_500`）；③ **未堆 Panel 装饰** —— 本批像素与已入库的 VB-03 切片**逐字节相同**（DSH 对 24 张跨 4 个副本做 SHA256 比对，全等），即**没有为了"更精致"重画/加装饰**，panel / tooltip / frame 仍是单层边框 + 一道 `GOLD_200` 高光。
> - **改动面**：只在 `assets/**`；`project.godot` **零 diff**（`09 §4` v0.1.6 的编辑器改写风险已排除）；`scripts/**` · `scenes/**` · `docs/**`（除本板与 `12`）未触碰。**未 push**（按卡），由 DSH 提交 `main`。
> - **口径变更（需记住）**：本卡是**第一次把 `.import` 入库**。此前 `PET-63` 关记录里的「本仓库不追踪任何 `.import` 文件」**自本卡起作废**（卡面明确要求 `09 §4` 的 `*.import` 入库，`.gitignore` 只忽略 `.import/` 目录、不忽略 `*.import` 文件）。后续新素材一律随切片提交 `.import`，保证不含 `.godot/` 的干净检出也能直接拿到正确的导入参数。
> - **清单（唯一要读的表）**：24 行「组件名 → 切片文件 → 尺寸 → 九宫格 margin → 用到的 Token → 建议控件」已贴在 `PET-73` 卡评论里。可缩放控件读 `assets/ui/vb03_component_language/styleboxes/*.stylebox.tres`；固定 24×24 的节点卡与槽位按 `Texture2D` 直接贴图。
> - **未做（刻意的）**：**没有**新开 gameplay 方向。按 `13 §9` 的 `FIRST PLAYABLE Gameplay > UI Kit 继续打磨`，下一个玩法里程碑等 **`PET-37`** 的用户试玩反馈定向；在那之前只清**登记在册**的项（本次清掉的仅是 R3 的 `status` 半条）。
> - **环境说明（非本卡缺陷）**：交付 run 的编辑器导入日志里有两条**与本批无关**的环境噪声（根证书库读取失败、便携版 `editor_data` 不可写）；`--import` 退出码 0、VB-03 的 `.ctex` 全部落盘，判定为环境噪声而非导入失败。本复核 run 的沙箱无本地 Godot（`tools/godot/` 被 gitignore），故 DSH 用**结构 + 产物 + 像素**三方取证代替重跑编辑器。


> **2026-10-04 PET-74 验收（`ACCEPTED`，提交 `3b9f4b1`，DSH 已推送 `main`）+ 用户试玩反馈进板** —— DSH **不采信自报**，直接在这台机器上**等价双击**冷启动交付产物（`D:\GameDev\PixelFusion\build\windows\PixelFusion.exe`），用 Win32 API 量窗口、用自写取帧脚本量像素。
>
> - **窗口尺寸（本卡验收重点；用户反馈「分辨率太低」）—— 实测 `1280×720`，不是 320×180 的小窗**：`GetClientRect` = **1280×720 物理像素**（两次独立冷启动一致），`GetWindowRect` 外层 = 1302×776，`GetDpiForWindow` = **144**（窗口为 per-monitor DPI aware）⇒ `display/window/size/window_width_override = 1280` / `window_height_override = 720` **在导出包里确实生效**，**不需要**启动时 `DisplayServer.window_set_size()` 兜底。内容分辨率仍是 `320×180`（本卡未改 `project.godot`），**4× 整数放大**。
> - **不糊（最近邻）**：DSH 自己在前台抓下运行中的客户区帧，按 4×4 同色块统计 **57590 / 57600 = 99.983%** 完全同色；与交付附件 `PET74-1.png` 逐像素比对差值 **0.01%**（只剩 1280×720 圆角 / 光标的合成痕迹）⇒ 交付截图是**真实渲染帧**，不是重画或事后放大。附件 `PET74-1` vs `PET74-2` 差 **75.43%**，与交付方自报**逐位一致**。
> - **`export_presets.cfg` 改动面**：交付提交 `3e00c77` = **恰好 1 个文件 / +50 行**，只新增 `[preset.1] Windows Desktop`；Web 预设（`[preset.0]`）**一字未动**。DSH 落 `main` 的提交 `3b9f4b1` 与其 blob **逐字节相同**（`e1068bd5…`）。
> - **未上 L3 / 不改玩法**：本卡 L1 只要求「双击 → 主菜单 → 开始整备 → PREPARATION」；`scripts/**` · `scenes/**` · `assets/**` · `project.godot` **零改动**（项目里那份窗口设置是上一版既有内容，本卡没碰）。产物 `build/**` 按卡不入库。
> - **「分辨率太低」的裁定**：**窗口放大没有丢**（见上）。若用户指的是**画面本身颗粒粗**（基础画布 `320×180`），那是**换规格**（抬到 640×360 之类，布局常量要整体重导），属**用户的 GATE 方向决定**，DSH 不代判 —— 已在 `PET-37` 向用户点明这一分支。
> - **用户试玩反馈已进板**：`PET-75`（PLAY-01 · 删除 / 撤销 / 清空）自 `BACKLOG` 提升为 **`TODO`**，并挂**同款条件唤醒**（`status = in_review`）；`PET-76`（PLAY-02 · 战斗可读性）**保持 `BACKLOG`**，等 `PET-75` 完成后由 DSH 再提 —— **单写手，不并行开第二张 Claude 卡**（用户规则）。依据 `13 §18`（战斗可读性）与 `13 §9`（`FIRST PLAYABLE Gameplay > UI Kit 继续打磨`）。

> **2026-10-04 PET-75 验收（`ACCEPTED`，DSH 已推送 `main`）—— 用户反馈「模块装上就摘不下来」已修好** —— DSH **不采信自报**，按卡面写明的 **L1**（`09 §1.1`，**未擅自上 L3**）在交付树的**独立副本**上复跑；交付的 8 个文件**与本机副本 SHA256 逐字节相同**（DSH 先比对再跑）。
>
> - **L1 结果（本模块全绿；`--fixed-fps 600`，headless）**：unit + integration **2742/2742 · 426/426**、**失败项 0**（前提：DSH 把该卡新增 4 条文案的翻译表行补齐，见下）。**基线对照**：未改动的 `1a6f874`（HEAD）同一命令 **2534/2534 · 426/426**、失败项 0 ⇒ 本卡 unit **净 +208 条全绿**。场景冒烟：**蓝图 132/132**（非 headless，`--resolution 320x180`，真实 GL；HEAD 为 82/82，净 +50 条）、**PREPARATION 86/86**（`--fixed-fps 60`，失败项 0）。
> - **五个必交付点逐条独立核实的证据（不引用交付方断言）**：① **删节点连带连线** —— 代码路径 `delete_node()` **两端都查**（`from_node_id` / `to_node_id`）后重建两个数组再 `_boxes.erase()`；单测「删中间节点 → 节点 2 / 连线 **2→0**」与冒烟「触摸点删除 → 3 节点 / **0 连线**」两处独立咬住；② **`Ctrl+Z`** —— 撤销为**有界快照栈**（`HISTORY_MAX = 20`，压栈点在全部回绝之后），冒烟发的是**真实 `InputEventKey`（ctrl + KEY_Z）**而非直接调函数，撤「删除」必须把**被连带删掉的两条线一起还原**（4 节点 / 2 连线）；单测另覆盖撤「放置 / 连线 / 删除 / 清空」并一路撤到空图；③ **清空二次确认 + 权重** —— 界面侧第一下只改文案、第二下才清（`preparation_screen._on_clear_pressed`），且清空本身也进撤销栈；**视觉权重按像素判据**：DSH 自量 320×180 原生帧，三个动作按钮区域 **gold 像素 = 0**，`开始战斗` 区域 **gold = 1158 px**，全帧 gold 总数在**修前 / 修后两帧完全相等（1741 = 1741）** ⇒ 本卡**没有新增任何金色主强调块**（`13 §4` / `06 §3`）；三个按钮均挂 `ButtonSecondary`（`test_preparation` 另加「辅助按钮必须挂变体」的反向断言）；④ **触摸可达 + 命中区** —— DSH 自写探针量活体控件：宽屏 `删除 / 撤销 / 清空` 均 **69×24 逻辑像素**（命中区 = 自身矩形）⇒ 2× 下 **138×48 设备像素 ≥ 44×44**（`06 §1`）；窄屏收起时三者 `visible=false`（`test_input` 的窄屏实测表据此不含它们，且该表自带「不得有漏网或多余」断言），点既有 §7.1 信息条展开后**三者回来且仍是 69×24 / 在 73×124 覆盖层内**；键盘入口落在 `.tscn` 的 `Button.shortcut`（`Delete` / `Backspace` / `Ctrl+Z`），**脚本里零键码**（`03 §8` 未被破坏），「清空」**刻意不挂快捷键**以免绕过二次确认；⑤ **即时落盘** —— 全部写盘点收敛到 `_after_change()`（落盘 + 重画 + 广播），DSH 逐行核对 6 处数组/字段改动**无一漏配**；冒烟真的**重实例化一份 PREPARATION**（`_ready()` 全跑）后 4 节点 / 2 连线 / 4 个落格一致，并另有 `load_from()` 直读存档复核。
> - **截图取证独立复现（修前 / 修后都在）**：DSH 在**自己的 HEAD 副本**上重跑蓝图冒烟，产出的 `blueprint_first_playable.png`（**修前**：4 节点 + 2 连线、左栏**没有任何删除入口**）与交付附件的 `blueprint_before_fix.png` **SHA256 完全相同**（`B2915662…`）；在**修后独立副本**上重跑，4 张截图（`blueprint_edit_selected` / `_deleted` / `_clear_armed` / `first_playable`）与交付附件**逐张 SHA256 完全相同**；交付的 4 张 4× 放大图经 DSH 纯 Python 解码后与**本机重跑帧的最近邻 4× 放大逐像素一致**（57600 像素中 **0 处不同**）⇒ 是真实渲染帧，不是重画或事后美化。
> - **唯一红项（本卡引入）→ 由 DSH 集成补齐，补前/补后都留档**：交付树 unit 为 **2721/2722**，唯一红项是 `I18N · 翻译表覆盖全部 UI 文案`：本卡新增 4 条玩家可见文案（`删除` / `撤销` / `清空蓝图` / `确认清空？`）的表行在 `assets/i18n/ui.csv`，而该文件**不在本卡 ALLOWED FILES**（卡面把 `assets/**` 划给 Codex）—— **属卡面自身缺陷 + 排期缺口，不是实现缺陷**（交付方已如实报告并给出 4 行原文）。`i18n` 表是**数据表非美术资源**，且由 `PET-67` 的 Claude 卡建立，故 DSH **随本次集成直接补齐 4 行并另起一个提交**（不与交付混在一起）。补后：unit **2721/2722 → 2742/2742**（+20 条来自该表「逐行 5 条格式断言」× 4 行），`TranslationServer.translate` 在 `en` 下实测得 `Delete` / `Undo` / `Clear blueprint` / `Confirm clear?`。
> - **`S1-12 · R1` 4 条集成红项：非本卡引入** —— DSH 在**未改动的 HEAD** 上用同一命令复现出**逐字相同**的 4 条（状态 3→5、场景换到 `result.tscn`、切换数 81→82、清空入口），成因是该用例按**墙钟预算**推进模拟时间（`test_state_loop.gd:372-373`）；同一命令在改后树上**也出现过一回全绿 426/426** ⇒ 时序脆弱，**登记为 `R6`**，不静默豁免。
> - **改动面核对**：交付的 8 个文件全部落在卡面 ALLOWED FILES 内（含交付方主动声明的 3 处 `tests/**` 断言收窄 —— `HIT_TABLE` 是实测表、`CTA 唯一性` 判据收窄到「无主题变体的 Button」，并补了「辅助按钮必须挂 `ButtonSecondary`」的反向断言，判别力未降）；`docs/**` 由 DSH 改，`project.godot` **零 diff**（`--import` 后已核）。DSH 额外动的**只有** `assets/i18n/ui.csv` +4 行（见上）。
> - **未上 L3**（按卡面 L1）：全量基线 / 全部场景冒烟 / Web 导出 / 像素探针未跑，本卡不产生 L3 结论。**未跑渲染探针**：本卡未改 Theme / StyleBox / 视觉 Token（三个按钮复用既有 `ButtonSecondary`），按 `09 §4` v0.1.2 的触发条件不适用；视觉权重改以**像素直方图**取证（见上）。
> - **环境说明（非本卡缺陷）**：复核在**工作区内的独立副本**上完成（`APPDATA` / `LOCALAPPDATA` / `TEMP` 重定向进工作区，先 `--headless --import` 刷类缓存）；期间观察到 **1 次**退出期 `0xC0000005`（报告已完整写出、失败项 0，同一命令随后 4 次运行不复现），与 `PET-60` 已结案的引擎级退出缺陷同类、**不可确定性复现**，不归因本卡。
> - **下一步**：`PET-76`（PLAY-02 · 战斗可读性）自 `BACKLOG` **提升为 `TODO`** 并挂**同款条件唤醒**（`status = in_review`）—— **单写手**：`PET-76` 完成前**不开第二张 Claude 卡**。依据 `13 §18` 与 `13 §9`（`FIRST PLAYABLE Gameplay > UI Kit 继续打磨`）。

> **2026-10-06 PET-76 验收（`ACCEPTED`，DSH 已推送 `main`）—— 用户反馈「战斗看不懂」已修好** —— DSH **不采信自报**，按卡面写明的 **L1**（`09 §1.1`，**未擅自上 L3**）在交付树的**独立副本**上复跑。
> - **复核方式**：把交付树（`HEAD = cdcc23f` + 4 个**未提交**改动文件）整树复制进 DSH 工作区，先 `--headless --import` 刷类缓存，再 `run_tests.gd --fixed-fps 600`（headless）→ **unit 2743/2743 · integration 426/426 · 失败项 无**；三个冒烟**非 headless**、`--resolution 320x180`、真实 GL（RTX 4060 / OpenGL 3.3）→ **`combat_smoke` 106/106 · `combat_loop_smoke` 113/113 · `blueprint_smoke` 132/132**，三者 `exit=0`。
> - **交付方自报与实跑不符，已如实记录**：交付说明写「integration 419/423，4 条失败」，DSH **在同一棵树上用同一条命令**复跑得 **426/426 全绿**。差异与 `R6` 同族（`test_state_loop` 按**墙钟预算**推进模拟时间，机器一忙跑不满 600 秒）。**不按自报判红，也不判交付方说谎** —— 结论以本机复跑为准：无回归。
> - **`13 §18` 六点逐条取证（不是「应该看得见」）**：① **三把武器形态可区分**，由 `combat_loop_smoke` 自量的**反馈包围盒**钉住 —— **针 1×6 / 炸弹 5×5 / 锯 9×2**（三种尺寸互不相同）；② **弹道可见**（1px）＋**命中点短促闪光**（2×2）；③ 敌人**受击闪白 + 抖动 1px**、**血条随逐拍 `enemy.hp` 差值真的动**、**击杀有一次性描边**；④ **因果同拍** —— 命中判定改为**逐拍 `enemy.hp` 差分**，与 `weapon_fired` **落在同一帧**，故「热量上涨 / 能量下降」与画面同拍，不是只有数字在跳；⑤ **未引入**粒子雨 / 全屏闪光 / 伤害数字洪水 / 屏幕震动（包围盒最大 9×2，全屏级特效在尺寸上即不可能）；⑥ 色值全走 `Palette`，无字面色值。
> - **交付方式合规**：交付方**按卡不 push**，4 个文件（`scripts/ui/blueprint_workspace.gd` · `scripts/ui/combat_screen.gd` · `tests/integration/combat_loop_smoke.gd` · `tests/unit/test_combat.gd`）全部落在卡面 ALLOWED FILES 内；未跟踪的 `.import` / `tests/output/**` 产物**未入库**。
> - **未上 L3**（按卡面 L1）：全量基线 / Web 导出 / 像素探针未跑，本卡不产生 L3 结论。
> - **环境说明（非本卡缺陷）**：复核期间退出期固定出现 **3 个 ObjectDB 实例 / 2 个资源未释放**的 `WARNING` / `ERROR`，按 `09 §1.1` **v0.1.7**「可复现且不属本批引入 ⇒ 不判 DoD 失败、须留档」处理；另有沙箱自身的 `Failed to read the root certificate store`（无证书存储），与本批无关。
> - **停摆 8 小时的如实归因**：交付本身无问题，**卡死的是平台侧驱动** —— 见新增待办 **`R7`**。DSH 未在停摆期间收到任何触发（事件唤醒的 run `01a10f36` 停在 `running`、`at` 安全网 `fire_count = 0`、巡检已关）。
> - **已同步的产物**：`build\windows\PixelFusion.exe`（+ `.pck` / `.console.exe`）**已用修后代码重新导出**，用户双击路径不变。
> - **下一步**：`PET-76` 完成即**让位**（单写手解除）—— 下一张 Claude 卡由 DSH 依**用户试玩反馈**定向；`PET-72`（奖励真的生效）与 `R1` / `R5` 仍在 `BACKLOG` 等待排期。


## 5. STAGE 3 — CORE / FUNCTION / WEAPON（未开始）

| ID | 任务 | 负责人 |
|---|---|---|
| S3-01 | `CORE` 节点：能量/信号脉冲产生 | Claude |
| S3-02 | `FUNCTION` 节点：运算/分流/延时/条件 | Claude |
| S3-03 | `WEAPON` 节点：消耗与执行接口 | Claude |
| S3-04 | 固定 tick 传播引擎（拓扑序 + 稳定 tie-break） | Claude |
| S3-05 | 确定性测试（同蓝图同输入同结果） | Claude |
| S3-06 | PREPARATION 中的传播预览（可选，若影响范围需 DSH 批准） | Claude |
| S3-07 | Stage 3 用户验收 | 用户 |

## 6. STAGE 4 — COMBAT LAYER（未开始）

| ID | 任务 | 负责人 |
|---|---|---|
| S4-01 | `EnemyData` + 敌人推进 | Claude |
| S4-02 | 波次系统 `WaveData` | Claude |
| S4-03 | 伤害结算与 HP/死亡 | Claude |
| S4-04 | Heat / Overheat 机制 | Claude |
| S4-05 | Energy 生成与消耗 | Claude |
| S4-06 | 战斗倍速（1x/2x/4x，不改变结算） | Claude |
| S4-07 | 奖励系统 + REWARD 逻辑 | Claude |
| S4-08 | RESULT 结算（含随机种子展示） | Claude |
| S4-09 | 一局完整集成测试 | Claude |
| S4-10 | Stage 4 用户验收 | 用户 |

## 7. STAGE 5 — ART REPLACEMENT（未开始）

| ID | 任务 | 负责人 |
|---|---|---|
| S5-01 | Codex 依据参考图校准 `04` 调色板 → v0.2.0 | Codex |
| S5-02 | UI 框架素材批次 A → 用户审批 | Codex |
| S5-03 | 角色/敌人批次 B → 用户审批 | Codex |
| S5-04 | 节点/武器 Icon 批次 C → 用户审批 | Codex |
| S5-05 | FX 批次 D → 用户审批 | Codex |
| S5-06 | 背景批次 E → 用户审批 | Codex |
| S5-07 | 逐批集成（仅 `_approved/`） | Claude |
| S5-08 | 最终验收 | 用户 |

## 8. 尚未规划（需用户决定后才可进入任务板）

- 存档格式与槽位数量
- 局外成长（Roguelike meta progression）是否存在
- 难度曲线与波次总数
- 音频（无规范文档，暂不派发任何音频任务）
