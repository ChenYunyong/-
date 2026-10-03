# 11 — 任务板（TASK BOARD）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 v0.1.0｜维护者 DSH
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
| S0-17 | **用户批准全部 Stage 0 文档** | 用户 | `TODO` | L4 验收 |
| S0-18 | Godot 4.7.1 portable 安装（D 盘自包含） | DSH | `ACCEPTED` | `tools/godot/`（已验证不写 C 盘） |
| S0-19 | 参考图 A/B/C 落盘 + 逐像素取色实测 | DSH | `ACCEPTED` | `04` §2（证据） |
| S0-20 | `04`/`05` 按参考图实测校准（v0.1.1） | DSH | `REVIEW` | docs/04, docs/05 |
| S0-21 | 导出模板安装到 D 盘 portable 引擎 | DSH | `TODO`（S1-13 前完成） | `tools/godot/editor_data/export_templates/` |
| S0-22 | Codex 对 `04/05/06` 的独立视觉审查 | Codex | `ACCEPTED` | 4 项 blocking 全部核验并采纳 |
| S0-23 | 依 Codex 第一轮审查修正 `04`→v0.1.2 | DSH | `ACCEPTED` | 04/05/06 |
| S0-24 | Codex 第二轮**目视**审查（真读了 A/B/C） | Codex | `ACCEPTED` | 采纳 3 项、3 项过期已提前修完 |
| S0-25 | 依目视审查修正 `04`→v0.1.3（节点卡 24px / 材质边界 / FX 三层） | DSH | `REVIEW` | 04/05/06 |
| S0-26 | PREPARATION 外框层 UI 素材（Codex 出稿 → 用户批准） | Codex | `TODO`（Stage 1） | `assets/_review/pending/` |

### S0 退出条件
- [ ] 全部文档获用户明确批准
- [x] Godot portable 安装完成并验证 `%APPDATA%\Godot` 未被写入（2026-10-03 实测通过）
- [x] 三张参考图已取色实测并回写 `04` / `05`

## 2.1 门禁（GATE）状态

> 规则见 `08_AGENT_RULES.md` §10。**未获用户裁定的门禁，会阻塞受其影响的工作。**

| GATE | 状态 | 说明 |
|---|---|---|
| **GATE 1** — Stage 0 首次完成 | 🔴 **等待用户批准** | 文档已产出并两轮汇报（2026-10-03）。**Stage 1 不得开工。** |
| **GATE 3** — 视觉方向变化 | 🟡 已知相关 | `04` v0.1.1 已按参考图取色校准（属**对齐**既定方向，非改变方向）。红/橙两组标记 `UNVERIFIED-AGAINST-REFS`，留 Stage 4 确认。 |
| **GATE 7** — 工具无法避免写 C 盘 | 🔴 **等待用户裁定** | Multica 运行时任务工作区位于 `C:\Users\20703\multica_workspaces_desktop-api.multica.ai\...`，进程内无法重定向。详见 `01_STORAGE_RULES.md` §3.2 / §8。 |
| GATE 2 / 4 / 5 / 6 / 8 / 9 / 10 | ⚪ 未触发 | — |

### 当前是否可推进

- **Stage 1（项目骨架）：⛔ 不可推进** —— 阻塞于 GATE 1。
- Stage 0 收尾（文档维护、Task Board、Git、导出模板安装 S0-21）：✅ 可推进（属 DSH 默认执行权）。

## 3. STAGE 1 — PROJECT SKELETON（未开始）

只实现状态循环，允许全部占位图。**首先验证整个游戏状态循环。**

| ID | 任务 | 负责人 | 依赖 | 状态 |
|---|---|---|---|---|
| S1-01 | `project.godot` 初始化 + Autoload 骨架（EventBus / GameFlow / DataRegistry / RunState / Settings） | Claude | S0 批准 | `TODO` |
| S1-02 | `GameFlow` 六状态机 + 切换硬规则 R1-R5 + 单元测试 | Claude | S1-01 | `TODO` |
| S1-03 | `scripts/data/palette.gd` + `assets/palette.tres`（依 04 §5） | Claude | S0 批准 | `TODO` |
| S1-04 | 全局 Theme（依 06） | Claude | S1-03 | `TODO` |
| S1-05 | BOOT 场景（数据校验 + 失败提示） | Claude | S1-01 | `TODO` |
| S1-06 | MAIN_MENU 场景（占位：Logo/开始/继续/设置/退出） | Claude | S1-04 | `TODO` |
| S1-07 | PREPARATION 场景（五分区布局 + 唯一动作「开始战斗」） | Claude | S1-06 | `TODO` |
| S1-08 | COMBAT 场景（占位战场 + 紧凑 HUD） | Claude | S1-07 | `TODO` |
| S1-09 | REWARD 场景（3 选项 + 跳过） | Claude | S1-08 | `TODO` |
| S1-10 | RESULT 场景（结算 + 返回） | Claude | S1-09 | `TODO` |
| S1-11 | 双端输入适配（键鼠 + 触摸，44px 命中） | Claude | S1-07 | `TODO` |
| S1-12 | 状态循环集成测试（10 次循环、防重入、不自动推进） | Claude | S1-10 | `TODO` |
| S1-13 | Web Export 冒烟验证 | Claude | S1-12 | `TODO` |
| S1-14 | Stage 1 用户验收 | 用户 | S1-13 | `TODO` |

**Stage 1 绝对禁止**：真实战斗、真实伤害、蓝图编辑逻辑、敌人 AI。

## 4. STAGE 2 — BLUEPRINT BASE（未开始）

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
