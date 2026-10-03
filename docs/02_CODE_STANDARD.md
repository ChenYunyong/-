# 02 — 代码规范（CODE STANDARD）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 v0.1.0｜维护者 DSH｜约束对象 Claude Lead Developer
> 本文件在 Stage 0 之后被冻结；新增规则必须走 `12_CHANGELOG.md` 记录。

## 1. 语言与引擎

- **Godot 4.x Stable + GDScript**。
- 禁止：C#、GDExtension、任何非必要第三方框架、付费插件。
- 缩进使用 **Tab**（Godot 社区默认），行宽 ≤ 120 字符。
- 文件编码 UTF-8（无 BOM），换行 LF。

## 2. 静态类型优先

所有变量、参数、返回值尽量显式标注类型。

```gdscript
# 正确
var heat: float = 0.0
var current_wave: int = 1
var is_running: bool = false

func add_heat(amount: float) -> void:
	heat = clampf(heat + amount, 0.0, MAX_HEAT)

func get_node_by_id(id: StringName) -> NodeData:
	return _registry.get(id) as NodeData
```

```gdscript
# 禁止
var heat = 0.0            # 可推断但需显式
var data = get_thing()    # 无类型 Variant 泛滥
```

- 禁止无意义的大量 `Variant` / 无类型 `Array` / 无类型 `Dictionary` 作为跨系统接口。
- 跨系统传递结构化数据必须使用 `Resource` 子类或 `class_name` 定义的类。
- 类型不确定时用 `Variant` 必须在该行上方写明原因注释。

## 3. 命名约定

| 对象 | 规则 | 示例 |
|---|---|---|
| 文件/脚本 | `snake_case.gd` | `blueprint_board.gd`、`combat_manager.gd`、`node_data.gd` |
| 场景 | `snake_case.tscn` | `preparation_view.tscn` |
| 资源 | `snake_case.tres` | `weapon_arc_coil.tres` |
| 变量 / 函数 | `snake_case` | `current_wave`、`apply_damage()` |
| 类 / `class_name` | `PascalCase` | `class_name NodeData` |
| 常量 | `UPPER_SNAKE_CASE` | `MAX_HEAT`、`TICK_RATE` |
| 私有成员 | 前缀 `_` | `_registry`、`_on_wave_cleared()` |
| Signal | 描述事件的 `snake_case` 过去式 | `combat_started`、`node_connected`、`heat_changed` |
| 枚举 | `PascalCase` 类型 + `UPPER_SNAKE_CASE` 值 | `enum Phase { IDLE, RUNNING }` |

Signal 命名规则：`<主语>_<已发生的事>`。禁止 `signal onClick`、`signal Callback1`。

## 4. 单一职责

**禁止出现 `game.gd`** —— 一个脚本管理整个游戏。系统必须按目录拆分：

```
scripts/
├─ core/        # 状态机、路由、EventBus、全局服务
├─ blueprint/   # 蓝图数据与编辑逻辑
├─ combat/      # 战斗推进、伤害结算、Heat/Energy
├─ enemies/     # 敌人行为与生成
├─ nodes/       # CORE / FUNCTION / WEAPON 节点逻辑
├─ roguelike/   # 波次、奖励、局内进度
├─ ui/          # 纯表现层
├─ data/        # Resource 定义
└─ utils/       # 无状态工具函数
```

单文件硬上限：**300 行**（不含注释与空行）。超过必须先拆分，并说明拆分理由。

## 5. 数据与逻辑分离

- 武器、节点、敌人、波次数值**禁止写死在逻辑代码中**。
- 一律使用 Godot `Resource` 子类：`NodeData`、`WeaponData`、`EnemyData`、`WaveData`。
- 正式配置存 `.tres`，放在 `data/nodes|weapons|enemies|waves/`。
- 逻辑代码只允许通过 `DataRegistry` 按 id 取数据，禁止 `preload("res://data/...")` 散落各处。

```gdscript
class_name WeaponData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var base_damage: float = 0.0
@export var heat_per_shot: float = 0.0
@export var cooldown: float = 1.0
@export var icon: Texture2D
```

## 6. 信号通信

- 跨系统通信优先 `Signal` / `EventBus`（Autoload）。
- 禁止模块之间形成大量互相 `get_node("../../..")` 硬引用。
- 禁止用 `get_tree().get_nodes_in_group()` 做每帧扫描来替代信号。
- Signal 必须在声明处写注释说明「何时触发、携带什么」。

```gdscript
## 一波敌人全部被清除时触发。
signal wave_cleared(wave_index: int)
```

## 7. 禁止项（Hard NO）

- 巨型脚本 / 巨型函数（函数 ≤ 50 行）
- 魔法数字：`if heat > 87.3:` → 必须命名常量
- 重复代码：第三处重复必须抽函数
- 随机硬编码资源路径：`load("res://assets/ui/foo_bar_v3.png")`
- UI 直接修改战斗内部状态（必须走命令/信号）
- 每帧重复扫描整个场景树
- `_process()` 中大量重计算（用 `_physics_process`、Timer、或事件驱动）
- 无注释的复杂算法
- 没有测试就宣布完成（见 `09_TEST_STANDARD.md`）
- 直接写 `Color("#xxxxxx")`（见 `04_COLOR_SYSTEM.md`）

## 8. 文件头模板

每个 `.gd` 文件必须以下列注释块开头：

```gdscript
## blueprint_board.gd
## 职责：渲染与编辑单张蓝图（节点放置、连线、删除）。
## 所属系统：blueprint
## 依赖：EventBus, BlueprintModel, NodeData
## 禁止：本文件不得直接结算伤害或读取战斗内部状态。
```

## 9. 错误处理

- 对外部输入（存档、配置、资源 id）必须校验：类型、范围、存在性、空值。
- 禁止用 `assert()` 处理玩家侧可触发的错误（导出后 assert 行为不可靠）。
- 资源缺失必须 `push_error()` 并降级到安全默认值，不得静默崩溃。
- 禁止空的 `catch`/忽略错误分支。

## 10. 注释

- 注释解释**为什么**，不解释**是什么**。
- 公共函数必须写 `##` 文档注释，含参数与返回值说明。
- 复杂算法必须有步骤注释或指向 `docs/` 的说明。

## 11. 提交规范（Git）

每个任务尽量独立提交。Commit message 四段式：

```
<类型>(<模块>): <一句话改动>

- 改动点 1
- 改动点 2

测试：<跑了什么测试，结果>
状态：<通过 / 部分通过 / 未测试原因>
```

类型：`feat` / `fix` / `refactor` / `test` / `docs` / `chore` / `art` / `build`。

**禁止提交**：`.godot/`、`.import/`、`build/`、`*.tmp`、`*.log`（已由 `.gitignore` 覆盖）。

## 12. 代码审查清单（DSH 每次审查必查）

```
[ ] 静态类型标注完整
[ ] 命名符合 §3
[ ] 单文件 ≤300 行，单函数 ≤50 行
[ ] 无魔法数字 / 无硬编码路径
[ ] 数值走 Resource，无写死
[ ] 跨系统走 Signal/EventBus
[ ] UI 未直接改战斗状态
[ ] 无 _process 中的重计算或场景树全扫描
[ ] 颜色来自 Palette
[ ] 有对应测试且测试通过
[ ] 未越界修改（对照 ALLOWED FILES）
```
