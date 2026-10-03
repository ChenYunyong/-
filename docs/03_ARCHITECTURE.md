# 03 — 架构规范（ARCHITECTURE）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 **v0.1.1**｜维护者 DSH
> 本文件定义「系统长什么样」，不定义「具体怎么实现」。实现细节属 Claude Lead Developer，但不得违反本文件的边界。

## 1. 顶层状态机

系统只允许存在一个顶层游戏状态机 `GameFlow`（Autoload）。

```
enum GameState { BOOT, MAIN_MENU, PREPARATION, COMBAT, REWARD, RESULT }
```

```
BOOT
 ↓（加载数据/配置，校验失败则进入错误提示）
MAIN_MENU
 ↓（开始 / 继续）
PREPARATION  ──────────────┐
 ↓（仅玩家点击「开始战斗」）      │
COMBAT                     │
 ↓（本波敌人全部被击败）          │
REWARD                     │
 ↓（玩家选定奖励）               │
PREPARATION ───────────────┘
 ↓（局内进程终止：放弃本局 / 达到终局条件）
RESULT  ←── COMBAT（CORE 被摧毁 / 达到终局条件；见 §1.1 R2）
 ↓（返回主菜单 / 再来一局）
MAIN_MENU / PREPARATION
```

### 1.1 状态切换硬规则

| 规则 | 说明 |
|---|---|
| R1 | `PREPARATION → COMBAT` **只能**由玩家显式输入触发，禁止任何计时器/信号自动触发。 |
| R2 | `COMBAT → REWARD` **只能**由「本波清空」触发。CORE 被摧毁 / 达到终局条件 → `COMBAT → RESULT`（与 §1 状态图及 `09_TEST_STANDARD.md` §3.4 一致）。 |
| R3 | 状态切换必须经 `GameFlow` 的**单一提交点**落地并发信号，禁止任何模块自己 `change_scene_to_file()`。通用入口是 `GameFlow.change_state()`；玩家显式动作另有 `request_start_combat()` / `request_end_run()` 两个语义入口，是 `PREPARATION → COMBAT` 与 `→ RESULT` 的**唯一**合法通道。三者全部汇入同一提交点。 |
| R4 | 每次状态切换必须发出 `state_changed(from, to)` 信号。 |
| R5 | 切换过程中禁止重入（必须处理「切到一半又来一次」）。 |

## 2. 时间模型（本项目最容易写错的地方）

- **PREPARATION = 时间停止**：不推进战斗 tick，不生成敌人，不结算 Heat，不扣血。
- **COMBAT = 时间流动**：固定步长 tick 驱动 CORE、FUNCTION、WEAPON、Heat、敌人推进。
- 战斗仿真必须与渲染帧率解耦：使用固定 `TICK_RATE`（初值 **20 tick/s**，`0.05s`）累加器模式，禁止把逻辑写成「每渲染帧算一次」。
- 允许 1x / 2x / 4x 战斗倍速（后续阶段），但不得改变 tick 结果，只改变每帧执行的 tick 次数。
- 倍速不得影响随机数的可复现性（见 §6）。

## 3. Autoload（全局单例）清单

只允许下列 Autoload，新增必须经 DSH 批准。

| 名称 | 职责 | 禁止 |
|---|---|---|
| `EventBus` | 全局信号总线 | 不得存状态 |
| `GameFlow` | 顶层状态机与场景路由 | 不得存玩法数值 |
| `DataRegistry` | 加载并索引全部 `.tres` 数据 | 不得含玩法逻辑 |
| `RunState` | 当前这一局的进度（波次、奖励、随机种子） | 不得含表现逻辑 |
| `Settings` | 分辨率、音量、输入、语言 key | 不得含玩法逻辑 |
| `SaveService` | 本地存档读写 | 不得直接改 RunState 内部字段 |

## 4. 蓝图系统（核心系统）

### 4.1 三类节点

| 类型 | 作用 |
|---|---|
| `CORE` | 起点/驱动源：产生能量或信号脉冲，是玩家必须保护的对象 |
| `FUNCTION` | 中间处理：运算、分流、延时、放大、条件判断 |
| `WEAPON` | 终点执行：消耗能量/信号，产生伤害或效果 |

### 4.2 信号传播

- 蓝图是一张**有向图**：`Port` 为出/入口，`Connection` 为有向边。
- 传播必须是**确定性**的：同一蓝图 + 同一输入必须产生同一结果。
- 必须处理：环路（循环连接）、悬空端口、类型不匹配的连接、断开的子图。
- 环路必须被显式检测并给出玩家可读的提示，禁止死循环。
- 每个 tick 的执行顺序必须明确定义（拓扑序 + 稳定排序 tie-break），并在 `PREPARATION` 的 UI 中可被玩家理解。

### 4.3 蓝图与战斗的边界

- 蓝图**编辑**只发生在 PREPARATION。
- COMBAT 期间蓝图是**只读**的。
- 战斗系统不得回写蓝图结构；战斗只读蓝图并产生伤害/Heat 结果。

## 5. 资源与热量

| 概念 | 含义 | 表现色 |
|---|---|---|
| `Energy` | 蓝图运行的基础资源，按 tick 生成/消耗 | Sky / Energy Blue |
| `Heat` | 武器与高负载节点产生，过高进入 `Overheat` | Heat Orange |
| `HP` | CORE 与敌人的生命 | Combat Red |

- 数值公式必须在 `data/` 与 `docs` 中有单一来源，禁止散落在 UI 层。
- 警告阈值必须是命名常量，不得是魔法数字。

## 6. 随机性与可复现

- 所有随机必须来自 `RunState.rng`（`RandomNumberGenerator`，带显式 seed）。
- **禁止**直接使用全局 `randi()` / `randf()`。
- 每局必须记录种子，便于复现 bug 与回放。
- 随机种子在 RESULT 界面可选择展示。

## 7. 表现层边界

- `scripts/ui/` 只负责渲染与输入，**不得**直接修改战斗内部状态。
- UI → 逻辑：通过命令/信号。
- 逻辑 → UI：通过信号。
- 禁止 UI 层 `get_node("../../combat_manager").heat = 0`。

## 8. 双端输入

- 从 Stage 1 起，所有交互必须同时支持：鼠标/键盘 与 触摸。
- 触摸目标最小命中尺寸 **44×44 px**（逻辑像素，按缩放换算）。
- 蓝图连线必须同时支持鼠标拖拽与触摸拖拽，并有触摸专用的取消手势。
- 禁止「先 PC，手机以后再说」。

## 9. 目录结构（唯一合法结构）

```
D:\GameDev\PixelFusion\
├─ project.godot
├─ assets\
│  ├─ _review\pending\      # Codex 产出，未审批
│  ├─ _review\final\        # 已提交待用户批准
│  ├─ _approved\            # 用户已批准，可被集成
│  ├─ characters\ enemies\ nodes\ weapons\ effects\ ui\ backgrounds\ fonts\
│  └─ palette.tres          # 调色板（Stage 1 由 palette.gd 实现）
├─ scenes\
│  ├─ boot\ menu\ preparation\ combat\ reward\ result\ components\
├─ scripts\
│  ├─ core\ blueprint\ combat\ enemies\ nodes\ roguelike\ ui\ data\ utils\
├─ data\
│  ├─ nodes\ weapons\ enemies\ waves\
├─ docs\
├─ tests\
│  ├─ unit\ integration\ output\
├─ tools\                   # Godot portable 等本地工具（不进版本库的除外）
└─ build\
```

禁止擅自创造杂乱目录。新增顶级目录必须经 DSH 批准并记入 `12_CHANGELOG.md`。

## 10. 依赖方向规则

```
ui  ──→  roguelike / blueprint / combat   （只读 + 命令）
roguelike ──→ blueprint / combat
blueprint ──→ data / utils
combat ──→ nodes / enemies / data / utils
enemies ──→ data / utils
nodes ──→ data / utils
core  ──→ 全部（仅限 Autoload 服务）
data / utils ──→ 不依赖任何上层
```

**禁止反向依赖**：`utils` 不得引用 `ui`；`data` 不得引用 `combat`；任何层不得直接引用 `ui`。

## 11. 扩展点（预留但 Stage 1-5 不实现）

- 新节点类型 → 新增 `NodeData` 子类 + `.tres`，不改战斗主循环。
- 新敌人行为 → 新增 `EnemyData` + 行为脚本，不改生成器。
- 新奖励类型 → 新增 `RewardData`，不改奖励界面结构。

扩展点的存在是为了证明架构可扩展，**不是**允许提前实现。
