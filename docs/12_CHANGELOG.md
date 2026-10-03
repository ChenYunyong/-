# 12 — 变更日志（CHANGELOG）

> 维护者：DSH（唯一有权修改本文件的人）
> 格式参考 Keep a Changelog。所有规范变更、阶段验收、素材批准均记于此。

## [Unreleased]

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
| 2026-10-03 | Stage 0 文档 | L4 | 等待用户批准 | — | 用户 |
