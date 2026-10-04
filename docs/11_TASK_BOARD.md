# 11 — 任务板（TASK BOARD）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 **v0.3.3**｜维护者 DSH
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
| PET-65 | **FP 3/4** COMBAT 真实：Slime/Runner 生成推进 + 三武器伤害结算 + 死亡 | Claude | `TODO`（2026-10-04 DSH 自 `BACKLOG` 提升） |
| PET-66 | **FP 4/4** 循环闭合：3 波 + REWARD 三选一 + 回 PREPARATION + Overheat | Claude | `BACKLOG` |
| PET-62 | **Visual Batch 01**（并行）：MAIN MENU / PREPARATION / COMBAT UI Kit | Codex | `APPROVED`（有条件批准，见 `13`） |
| PET-67 | **I18N-MIN** UI 中英可切换：Godot CSV 翻译表（中文原文 = key → en）+ 最小语言开关 + 持久化 | Claude | `BACKLOG`（排 PET-63 之后） |
| PET-68 | **VB-01b** 三张 UI Kit 补英文标签版 + 中英版式容纳结论 | Codex | `REVIEW`（复核：英文版与原图逐字节相同，容纳结论不成立） |
| PET-69 | **VB-02** UI Kit 组件化制作 + 批准附带小改（含 COMBAT 越框修正） | Codex | `DONE`（用户 2026-10-04 批准组件方向） |
| PET-71 | **VB-03** 正式组件切图 + `_approved/` 流程（基础组件语言 v1，含 `13 §10` 三修） | Codex | `TODO` |
| PET-70 | **UI-KIT 接入**（MAIN_MENU + COMBAT 结构）：按批准 Kit 建场景结构，placeholder 资源 | Claude | `BACKLOG` |

| — | 退出期资源清点：`palette.gd` / `palette.tres` 未释放（已复核、非阻塞；随下一张触碰该文件的卡一并修） | Claude | `BACKLOG` |

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
