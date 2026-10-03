# 12 — 变更日志（CHANGELOG）

> 维护者：DSH（唯一有权修改本文件的人）
> 格式参考 Keep a Changelog。所有规范变更、阶段验收、素材批准均记于此。

## [Unreleased]

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
| 2026-10-03 | S1-A（PET-38）骨架：`project.godot` + 五个 Autoload + 六状态机 + Palette / Theme | L1 自测 + L2 规范审查 + L3 测试审查 | **通过**（附 2 项非阻塞后续项） | 无 | DSH |

- L1：单元 369 → **408**（+39），集成 19/19；新增 `tests/unit/render_shadow_probe.gd`（需真实渲染路径，**不进**常规回归）。
- L2：`04 §3` 35 Token 名称与顺序逐字一致；`scripts/**` 字面 `Color(` 构造数 0；`theme_main.tres` 零色值；`docs/**` 由执行方零改动。
- L3：以执行方实际跑出的计数为准，DSH 不重跑（`08 §2`）。
- `01 §4` v0.1.2 新增的 `APPDATA` / `LOCALAPPDATA` 强制项**实测有效**：本轮 5 次真实渲染运行，C 盘 `app_userdata` 零新增。

**非阻塞后续项（不影响本批验收结论）**
1. `06 §2.1` 只写「1px 内高光」，未写覆盖哪几条边。执行方取**四边整圈**（中性读法，未引入照明模型）。
   该项属视觉判断，按用户「视觉交给 Codex」的指令交 Codex 裁定；若改为仅上/左两遍，是两行改动。
2. `PanelShadow` 已实现、已测，**尚未接线**（`scenes/**` 不在 S1-A 的 ALLOWED FILES 内），属 S1-05。

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
| 2026-10-03 | Stage 0 文档 | L4 | 等待用户批准 | — | 用户 |
