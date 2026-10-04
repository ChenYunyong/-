## enemy_data.gd
## 职责：敌人数值的 Resource 定义（FIRST PLAYABLE 3/4）—— Slime / Runner 两种占位敌人的
##       血量与推进速度。数值是**占位平衡**，不是设计过的平衡（任务卡「不做平衡」）。
## 所属系统：data
## 依赖：无
## 禁止：本文件不得触碰场景树 / 渲染 / 输入 / Palette / 存档 —— 它只描述数值；
##       不得包含任何推进或伤害逻辑（推进与结算在 gameplay/combat_simulation.gd）；
##       不得在别处再抄一份 40 / 15 —— 两种敌人的差异只由本文件的常量给出，
##       逻辑侧一律经 for_kind() 取（02 §5：数值不得写死在逻辑代码里）。
##
## 为什么是类里的常量而不是 data/enemies/*.tres：本卡的 ALLOWED FILES 是 scripts/**，
## 落 .tres 要往 res://data/enemies/ 写文件，越界了。这也是本仓库既有批次的同一做法
## （PET-63/64 的节点仓库同样是代码表）。等数据卡授权 data/** 后应迁到 .tres + DataRegistry。

class_name EnemyData
extends Resource

## 敌人种类。本卡只要两种（任务卡「敌人（只两种）」）。
enum Kind { SLIME, RUNNER }

## Slime：慢、血多。Runner：快、血少。
## 推进速度是**每拍推进的归一化进度**（0 → 1），不是像素：像素是表现层的事，
## 战场尺寸一变（06 §7.1 窄屏折叠）推进速度就会跟着变，那是错的行为。
const SLIME_HP: float = 40.0
const SLIME_ADVANCE_PER_TICK: float = 0.008
const RUNNER_HP: float = 15.0
const RUNNER_ADVANCE_PER_TICK: float = 0.02

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.SLIME
@export var max_hp: float = SLIME_HP
@export var advance_per_tick: float = SLIME_ADVANCE_PER_TICK


## 按种类造一份数值。调用方只认 Kind，不认本文件里的常数名 ——
## 换数值时不必去追所有引用点。
static func for_kind(wanted: Kind) -> EnemyData:
	var data := EnemyData.new()
	data.kind = wanted
	if wanted == Kind.RUNNER:
		data.id = &"runner"
		data.display_name = "Runner"
		data.max_hp = RUNNER_HP
		data.advance_per_tick = RUNNER_ADVANCE_PER_TICK
	else:
		data.id = &"slime"
		data.display_name = "Slime"
		data.max_hp = SLIME_HP
		data.advance_per_tick = SLIME_ADVANCE_PER_TICK
	return data


## 从起点走到终点需要多少拍。测试与读秒都用它，免得各处自己算 1.0 / advance 而算错。
## 速度为 0 时返回 0（永不抵达），而不是除零 —— 调用方据此把它当成「不会漏的敌人」。
func travel_ticks() -> int:
	if advance_per_tick <= 0.0:
		return 0
	return int(ceil(1.0 / advance_per_tick))
