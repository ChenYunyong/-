# 01 — 存储规则（STORAGE RULES）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 **v0.1.1**｜维护者 DSH
> 本文件优先级高于任何工具默认行为、任何 Agent 的方便做法。

## 1. 最高规则：C 盘绝对禁令

**PixelFusion 项目相关内容禁止写入 C 盘。** 无例外，无「临时一下」。

被禁止写入 C 盘的内容包括但不限于：

- 项目源代码、`.godot/`、imported resources、shader cache
- 临时文件、Agent 中间文件、Python 缓存
- 美术源文件、图片处理缓存、生成素材
- 导出文件、日志、测试结果、截图、自动生成文档
- Codex 中间素材、Claude Code 临时脚本
- **游戏存档与 `user://` 数据**（见 §5.2，这是最容易漏掉的一条）

## 2. 唯一合法路径

| 用途 | 路径 |
|---|---|
| 正式项目 | `D:\GameDev\PixelFusion` |
| 临时/缓存 | `D:\Temp\PixelFusion` |
| 构建输出 | `D:\GameDev\PixelFusion\build` |
| 测试输出 | `D:\GameDev\PixelFusion\tests\output` |
| 文档 | `D:\GameDev\PixelFusion\docs` |
| **Godot portable 引擎** | `D:\GameDev\PixelFusion\tools\godot` |

## 3. STORAGE GATE — 实测结果（2026-10-03）

| 检查项 | 实测 | 结论 |
|---|---|---|
| `TEMP` / `TMP` | `C:\Users\20703\AppData\Local\Temp\multica-task-<id>\dsh-<id>` | ⚠ 风险（平台注入），已强制重定向 |
| `TMPDIR` | `C:\Users\20703\AppData\Local\Temp\multica-task-<id>` | ⚠ 风险，同上 |
| `APPDATA` / `LOCALAPPDATA` / `USERPROFILE` | 均在 C 盘 | ⚠ 工具默认缓存风险 |
| **Godot 引擎（已存在）** | `E:\godot\Godot_v4.7.1-stable_win64.exe`（4.7.1.stable.official） | ✅ 在 E 盘，不违反禁令 |
| **Godot portable（本项目）** | `D:\GameDev\PixelFusion\tools\godot`（含 `._sc_` / `_sc_`） | ✅ 已建成并验证 |
| **`%APPDATA%\Godot`（既有）** | 存在，**约 1.0 GB**，含 `editor_settings-4.7.tres`、`export_templates\templates.tpz`（995.4 MB）、`app_userdata\` | ⚠ 用户既有编辑器数据，**不是本项目产物**；本项目禁止向其写入 |
| Python | `D:\Python312\python.exe`（3.12.9） | ✅ 在 D 盘 |
| D 盘可写 | 已验证 | ✅ |
| C 盘项目内容 | `C:\GameDev` 不存在；C 盘无任何 PixelFusion 产物 | ✅ |
| Git 身份 | `ChenYunyong <2070348240@qq.com>` | ✅ 原样保留 |

### 3.1 已执行的缓解措施

1. 建立完整项目目录树 `D:\GameDev\PixelFusion`（见 `03_ARCHITECTURE.md` §9）。
2. 建立 `D:\Temp\PixelFusion`：`pycache / pip / godot / logs / screenshots / scratch`。
3. **建立本项目专用的 portable Godot**：
   从既有的 `E:\godot\Godot_v4.7.1-stable_win64.exe` 复制到 `D:\GameDev\PixelFusion\tools\godot\`，
   并在同级写入 `._sc_` 与 `_sc_` 标记文件，启用自包含模式。
   **实测验证**：用该 portable 引擎 `--headless --version` 运行后，`%APPDATA%\Godot` 的 `LastWriteTime` **未发生变化**，确认未向 C 盘写入。
4. `§4` 规定每次任务必须注入的环境变量。

### 3.2 尚未解决 / 需用户决定

- **Multica Agent 运行时的任务工作区仍在 C 盘**
  `C:\Users\20703\multica_workspaces_desktop-api.multica.ai\...`
  这是 Multica 平台自身的工作目录，本项目无法在进程内重定向。它是**平台基础设施**，不是 PixelFusion 项目内容；但 Agent 的运行时中间文件（含本评论的正文文件）确实会落在那里。
  **需要用户裁定**：(A) 接受它为唯一登记例外；或 (B) 在 Multica 桌面端把工作区根目录迁到 D 盘。
- **导出模板尚未就位**：现有 `%APPDATA%\Godot\export_templates\4.7.1.stable` 目录为空，只有 `templates.tpz`（995.4 MB）。
  在需要导出（S1-13 Web 导出 / Stage 5 发布）之前，必须把模板安装到 **D 盘** 的 `tools\godot\editor_data\export_templates\4.7.1.stable`，
  否则导出会失败或回落到 C 盘。可在需要时从既有 `templates.tpz` 就地安装（只读 C 盘，不写入）。

## 4. 强制环境变量（每次任务启动前注入）

```powershell
$env:TEMP        = 'D:\Temp\PixelFusion'
$env:TMP         = 'D:\Temp\PixelFusion'
$env:TMPDIR      = 'D:\Temp\PixelFusion'
$env:PYTHONPYCACHEPREFIX = 'D:\Temp\PixelFusion\pycache'
$env:PIP_CACHE_DIR       = 'D:\Temp\PixelFusion\pip'
```

- 上述变量**必须**在调用 Godot / Python / 图片工具之前设置。
- 只允许在**当前进程**内设置；**禁止**用 `setx` 修改用户级/系统级变量（那会影响用户其它软件）。如需永久化，必须单独提请用户批准。
- 任何新引入的工具，必须先在 `D:\Temp\PixelFusion` 下验证其缓存可以重定向。

## 5. Godot 运行规则

### 5.1 只用本项目的 portable 引擎

- 本项目**一律**使用 `D:\GameDev\PixelFusion\tools\godot\Godot_v4.7.1-stable_win64_console.exe`（或非 console 版）。
- **禁止**使用 `E:\godot\...` 下的用户既有引擎来开 PixelFusion —— 那个引擎的 editor data 在 `%APPDATA%\Godot`（C 盘）。
- **禁止**修改 `E:\godot\` 或 `%APPDATA%\Godot\` 下的任何内容（那是用户既有资产）。
- 版本锁定：**Godot 4.7.1-stable**。升级版本属于 GATE 6（新版本 = 需要重新验证），必须先报 DSH 并由用户确认。

### 5.2 为什么必须自包含（这是最容易被忽略的 C 盘泄漏）

Godot 在 Windows 上的默认布局是：

| 内容 | 默认位置 | 是否项目内容 |
|---|---|---|
| 项目源码、`.godot/`、导入缓存 | `res://`（项目目录，即 D 盘） | ✅ 是（已在 D 盘） |
| **存档、`user://` 数据、运行日志** | `%APPDATA%\Godot\app_userdata\<项目名>\` | ⛔ **是**，默认会落在 C 盘 |
| 编辑器设置、导出模板 | `%APPDATA%\Godot\` | 引擎数据 |

**如果不用自包含模式，PixelFusion 的存档与日志会写进 C 盘**，直接违反 §1。

自包含模式（可执行文件同级存在 `._sc_` 或 `_sc_`）会把上述两者都重定向到 `<exe目录>\editor_data\`，即 D 盘。

因此：
1. `tools\godot\` 下的 `._sc_` / `_sc_` 标记文件**不得删除**。
2. 任何 Agent 若发现标记文件缺失，**必须先报告并恢复，再启动编辑器**。
3. Stage 1 的 S1-01 必须实测：运行一次编辑器后确认 `tools\godot\editor_data\` 被创建，且 `%APPDATA%\Godot` 未被修改。

## 6. 违规处理流程

一旦发现某个工具向 C 盘写入 PixelFusion 相关内容：

1. **立即停止该工具的任务**（不是「跑完再说」）。
2. 清理已产生的 C 盘文件。
3. 向用户报告：哪个工具 / 为什么写入 / 写了什么 / 能否重定向 / 替代方案。
4. 未经用户允许，不得继续该工具的任务。

本条对应总控规则的 **GATE 7**，属必须暂停并向用户汇报的事项。

## 7. 每次任务的 STORAGE CHECK（放在 CONSTRAINT CHECK 内）

```
STORAGE CHECK
- 本次任务写入的路径：
- 是否全部位于 D:\GameDev\PixelFusion 或 D:\Temp\PixelFusion：是/否
- 已注入的 TEMP/TMP/TMPDIR：
- 使用的 Godot 可执行文件全路径（必须为 D:\GameDev\PixelFusion\tools\godot\...）：
- 使用的外部工具及其缓存重定向方式：
- 发现的 C 盘写入：无 / 有（描述）
```

任何任务的 CONSTRAINT CHECK 中 `STORAGE CHECK` 不通过 → 任务不得开工。

## 8. 例外登记

| 例外 | 说明 | 登记状态 |
|---|---|---|
| Multica 运行时工作区 | 平台注入 `C:\Users\20703\multica_workspaces_desktop-api.multica.ai\...` | **待用户裁定** |
| 用户既有的 `%APPDATA%\Godot`（约 1.0 GB） | 用户在 2026-07-06 之前就存在的 Godot 编辑器数据，**非本项目产物** | 登记为**只读**：本项目不得读改写入；仅允许在安装导出模板时从其中的 `templates.tpz` 只读读取 |
| 用户既有的 `E:\godot\` | 用户自己的 Godot 4.7.1 安装，非本项目产物 | 登记为**只读**：本项目只从中复制了一次引擎文件，此后不得再改动 |
| Git 全局配置 | `C:\Users\20703\.gitconfig`（非项目内容） | 允许（用户已有配置，禁止改动身份） |
