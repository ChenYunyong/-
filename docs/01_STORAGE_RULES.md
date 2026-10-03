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

## 9. C 盘短暂中转规则（2026-10-03 用户裁定，GATE 7 关闭）

用户裁定原文：

> 「**只要不是长期留存在 C 盘都可以**」

即：**允许短暂中转，禁止长期留存。**

### 9.1 允许

- 工具自身在**进程级**产生的临时文件。
- 平台（Multica）自身的任务工作区与运行时文件 —— 任务结束后由平台回收。
- 前提：**任务结束前清理**；且不得把 C 盘目录当作项目工作目录使用。

### 9.2 仍然禁止

- 项目源码 / 素材 / 存档 / 日志 / 构建产物在 C 盘**长期驻留**（跨任务一直躺着即为违规）。
- 判断标准是**留存时间**，不是**是否写过**：运行期临时产生、任务结束即清理 → 合规；跨任务遗留 → 违规。

### 9.3 STORAGE CHECK 追加两项

```
- 本次在 C 盘产生的临时文件（路径 + 清理方式）：
- 任务结束时是否已清理：是 / 否（说明）
```

## 10. 容量门禁（2026-10-03 新增）

用户要求：「**需要你去把握一下 C 盘目前的空间是否支持，不要撑爆了**」。

### 10.1 实测基线

| 卷 | 总量 | 可用 | 可用率 |
|---|---|---|---|
| C: | 148.9 GB | 36.0 GB | 24.2% |
| D: | 412.8 GB | 65.9 GB | **16.0%** |
| E: | 390.6 GB | 189.7 GB | 48.6% |

> 注意：**D 盘反而是可用率最低的卷**（项目盘）。C 盘虽被禁止长期留存，但空间并不紧张。

### 10.2 规则

1. 任何预计写入 **> 500 MB** 的操作（导出模板、素材批次、导出包、引擎副本）执行前**必须先查目标卷可用空间**。
2. 目标卷可用率 **< 10%** 或可用空间 **< 10 GB** → **停止该操作**，报 DSH 并由 DSH 提请用户（属 GATE 8 范畴）。
3. 检查结果记入任务的 `STORAGE CHECK`。

### 10.3 已识别的容量消耗项

| 项 | 位置 | 体积 | 性质 |
|---|---|---|---|
| `%APPDATA%\Godot` | C | 1.0 GB | **用户既有**，非本项目 |
| Codex 任务工作区 | C | **≈340 MB / 次运行** | 平台运行时（`codex.exe` 单文件 281.7 MB）；由平台 GC 管理 |
| 历史任务工作区 | C | 338.9 MB + 27.7 MB | 旧 run 遗留，**建议清理**（属 GATE 8，待用户点头） |
| `D:\GameDev\PixelFusion` | D | 171 MB | 项目本体（含 170.9 MB portable Godot） |
| `D:\Temp\PixelFusion` | D | 29.4 MB | 临时与参考图 |

**由此得出一条派发纪律**：每次 Codex 运行都有约 340 MB 的 C 盘成本（虽由平台回收，但会阶段性占用）。
**DSH 应控制 Codex 派发次数** —— 不做无意义的重跑、不要在未确认版本前就让 Codex 开审
（参见 `08_AGENT_RULES.md` §3.1 版本行规则：一次过期审查既浪费钱，也浪费 340 MB）。
## 11. 存储分层：E 盘正式纳入（2026-10-03 用户授权）

用户 2026-10-03：

> 「可以，不用清理，你自行判断，有些东西也可以放到 E 盘中，你觉得可行的话」

**据此裁定**：C 盘旧遗留**不清**（用户已决定，见 §10.3）；**E 盘正式纳入为「大块 · 可再生」层**。

### 11.1 三层分工

| 层 | 放什么 | 判据 |
|---|---|---|
| **D:** `D:\GameDev\PixelFusion` | 项目源码 · `docs/` · `.git` · `scripts/` · `scenes/` · `data/` · `tests/` | **必须进版本库 / 被 git 追踪**的东西 |
| **E:** `E:\GameDev\PixelFusion` | 导出产物 `build/` · 素材源文件 `assets_src/` · Godot editor data（含约 1 GB 导出模板） | **体积大 · 可再生 / 不进版本库** |
| **C:** | 仅短暂中转 | 见 §9：允许短暂，**禁止长期留存** |

### 11.2 为什么这样分

- 实测可用率（§10.1）：**D 盘 16.0% 是三个卷里最紧的**，E 盘 48.6% 最宽松。
- 导出模板（约 1 GB）、Web / Windows 导出包、素材源文件这三类会持续增长，且**全部可再生或本就不该进 git** → 放 E:。
- 项目源码**必须**留 D:：它是唯一的 git 工作区，源码分散会让仓库分裂（这正是 §0.3 当初要禁的东西的反面教训）。

### 11.3 已实施的重定向（目录联接：逻辑路径不变，字节落在 E 盘）

| 逻辑路径（对 Agent 不变） | 实际落盘位置 |
|---|---|
| `D:\GameDev\PixelFusion\build` | `E:\GameDev\PixelFusion\build` |
| `D:\GameDev\PixelFusion\tools\godot\editor_data` | `E:\GameDev\PixelFusion\godot_editor_data` |

这样**同时满足**两件事：原提示词里「构建输出 = `D:\GameDev\PixelFusion\build`」的路径约定继续成立，
而占用更大的字节落在空间更宽的盘上。

> ⚠ **禁止删除或覆盖这两个联接**。若某次操作发现它们已变成普通目录（例如整目录复制导致联接被展开），
> **立即上报 DSH** —— 那意味着重定向已失效，字节正在往 D 盘堆。

### 11.4 纪律

1. 新增「**大块 · 可再生 · 不进 git**」的产物 → 一律先考虑 **E:**。
2. 新增「**必须进 git**」的东西 → 一律留 **D:**。
3. 任何 **> 500 MB** 的操作仍须走 §10 容量门禁。
4. **只允许**在 `E:\GameDev\` 与 `E:\Temp\PixelFusion` 下写入。
   **不得触碰 `E:\godot\`（用户自己的引擎）**，也不得触碰 E 盘上用户的其它目录。
