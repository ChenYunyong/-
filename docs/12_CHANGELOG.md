# 12 — 变更日志（CHANGELOG）

> 维护者：DSH（唯一有权修改本文件的人）
> 格式参考 Keep a Changelog。所有规范变更、阶段验收、素材批准均记于此。

## [Unreleased]

### Stage 0 — PROJECT FOUNDATION（2026-10-03，待用户批准）

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
