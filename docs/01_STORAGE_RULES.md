# 01 — 存储规则（STORAGE RULES）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 v0.1.0｜维护者 DSH
> 本文件优先级高于任何工具默认行为、任何 Agent 的方便做法。

## 1. 最高规则：C 盘绝对禁令

**PixelFusion 项目相关内容禁止写入 C 盘。** 无例外，无「临时一下」。

被禁止写入 C 盘的内容包括但不限于：

- 项目源代码、`.godot/`、imported resources、shader cache
- 临时文件、Agent 中间文件、Python 缓存
- 美术源文件、图片处理缓存、生成素材
- 导出文件、日志、测试结果、截图、自动生成文档
- Codex 中间素材、Claude Code 临时脚本

## 2. 唯一合法路径

| 用途 | 路径 |
|---|---|
| 正式项目 | `D:\GameDev\PixelFusion` |
| 临时/缓存 | `D:\Temp\PixelFusion` |
| 构建输出 | `D:\GameDev\PixelFusion\build` |
| 测试输出 | `D:\GameDev\PixelFusion\tests\output` |
| 文档 | `D:\GameDev\PixelFusion\docs` |

## 3. STORAGE GATE — 首次实测结果（2026-10-03）

> 由 DSH 在本机实测，命令与原始输出见 `12_CHANGELOG.md`。

| 检查项 | 实测值 | 结论 |
|---|---|---|
| `TEMP` | `C:\Users\20703\AppData\Local\Temp\multica-task-<id>\dsh-<id>` | ⚠ **风险**：C 盘 |
| `TMP` | 同上 | ⚠ **风险**：C 盘 |
| `TMPDIR` | `C:\Users\20703\AppData\Local\Temp\multica-task-<id>` | ⚠ **风险**：C 盘 |
| `APPDATA` / `LOCALAPPDATA` | `C:\Users\20703\AppData\...` | ⚠ 工具默认缓存会落 C 盘 |
| `USERPROFILE` | `C:\Users\20703` | ⚠ 工具默认工作目录会落 C 盘 |
| Godot 编辑器 | **未安装**（PATH 无、`D:\` 深度 3 无 `Godot*.exe`、Program Files 无） | ⛔ **阻塞 Stage 1** |
| Python | `D:\Python312\python.exe`（3.12.9） | ✅ 在 D 盘 |
| D 盘 | 存在且可写（经授权验证） | ✅ |
| C 盘项目内容 | 无 | ✅ |

### 3.1 已执行的缓解措施

1. 已创建 `D:\GameDev\PixelFusion` 全套目录树（见 `03_ARCHITECTURE.md` §9）。
2. 已创建 `D:\Temp\PixelFusion` 及子目录 `pycache / pip / godot / logs / screenshots / scratch`。
3. 本文件 §4 规定的环境变量，任何工具在启动前必须先注入。

### 3.2 尚未解决 / 需用户决定

- **Multica Agent 运行时的任务工作区仍在 C 盘**
  `C:\Users\20703\multica_workspaces_desktop-api.multica.ai\...`
  这是 Multica 平台自身的工作目录，本项目无法在进程内重定向。它是**平台基础设施**，不是 PixelFusion 项目内容；但 Agent 的中间文件确实会落在那里。
  **需要用户决定**：(A) 接受该平台目录为唯一例外，并在规则中显式登记；(B) 在 Multica 桌面端设置中把工作区根目录迁到 D 盘。
- **Godot 4.x Stable 未安装**：Stage 1 开始前必须安装 **portable / 自包含** 版本到 D 盘（见 §5）。

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

## 5. Godot 自包含（Portable）安装要求

Stage 1 之前，Godot 必须满足：

1. 可执行文件放在 D 盘，例如 `D:\GameDev\PixelFusion\tools\godot\Godot_v4.x-stable_win64.exe`（或 `D:\Tools\Godot`）。
2. 在与可执行文件**同级**目录放置一个名为 `._sc_` 或 `_sc_` 的空文件，启用 Godot 自包含模式，使 editor data 落在同级 `editor_data\`，而不是 `%APPDATA%\Godot`。
3. 首次启动后必须验证：`%APPDATA%\Godot` **没有**新增目录。
4. 若某版本 Godot 无法自包含 → **立即停止使用该版本**，上报用户，不得以「系统默认行为」为由继续。

## 6. 违规处理流程

一旦发现某个工具向 C 盘写入 PixelFusion 相关内容：

1. **立即停止该工具的任务**（不是「跑完再说」）。
2. 清理已产生的 C 盘文件。
3. 向用户报告：哪个工具 / 为什么写入 / 写了什么 / 能否重定向 / 替代方案。
4. 未经用户允许，不得继续该工具的任务。

## 7. 每次任务的 STORAGE CHECK（放在 CONSTRAINT CHECK 内）

```
STORAGE CHECK
- 本次任务写入的路径：
- 是否全部位于 D:\GameDev\PixelFusion 或 D:\Temp\PixelFusion：是/否
- 已注入的 TEMP/TMP/TMPDIR：
- 使用的外部工具及其缓存重定向方式：
- 发现的 C 盘写入：无 / 有（描述）
```

任何任务的 CONSTRAINT CHECK 中 `STORAGE CHECK` 不通过 → 任务不得开工。

## 8. 例外登记

| 例外 | 说明 | 登记状态 |
|---|---|---|
| Multica 运行时工作区 | 平台注入 `C:\Users\20703\multica_workspaces_desktop-api.multica.ai\...` | **待用户裁定** |
| Git 全局配置 | `C:\Users\20703\.gitconfig`（非项目内容） | 允许（用户已有配置，禁止改动身份） |
