# 12 — 变更日志（CHANGELOG）

> 维护者：DSH（唯一有权修改本文件的人）
> 格式参考 Keep a Changelog。所有规范变更、阶段验收、素材批准均记于此。

## [Unreleased]

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
