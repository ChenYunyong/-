## enemy_state.gd
## 职责：**一只**敌人的可变状态（血量 / 推进进度 / 死亡拍号），以及它自己的规则
##       （还能不能推进、这一下打没打死、尸体该不该移除）。
## 所属系统：gameplay
## 依赖：EnemyData
## 禁止：本文件不得触碰场景树 / 渲染 / 输入 / Palette / 存档 —— 它只推进数值与判定，
##       画在哪、画成什么样由 ui 层读它的只读状态决定；
##       不得自己推进时间（没有 tick 就没有 advance 调用）—— 节拍来源只有一个（03 §2）；
##       不得引用 CombatSimulation —— 单只敌人不该知道全局战况，否则「谁清空了一波」这类
##       判定会散落到两处，而对不上的症状只是「偶尔不会进奖励」。
##
## 为什么推进用**归一化进度**而不是像素：像素是表现层的事。战场尺寸会变（06 §7.1 窄屏折叠），
## 用像素做推进单位，同一个敌人在窄屏上会更快抵达终点 —— 那是玩法规则的改变，不是布局的改变。

class_name EnemyState
extends RefCounted

## 数值来源。本类自己不写任何 40 / 15 / 0.008。
var data: EnemyData = null

## 当前血量。归零即死亡。
var hp: float = 0.0

## 归一化推进进度：0 = 起点（战场右侧），1 = 终点（战场左侧）。
var progress: float = 0.0

## 横向泳道序号。只决定画在哪一行，不参与推进与结算 ——
## 把它做成玩法参数会让「走哪条道」变成一件影响胜负的事，本卡不要那个。
var lane: int = 0

## 被击杀的拍号。未死为 -1：用拍号而不是另开一个计时器，尸体动画才与仿真同步，
## 暂停 / 补跑时也不会出现「尸体比仿真先消失」。
var died_at_tick: int = -1

## 是否抵达终点（漏怪）。与「被击杀」分开记 —— 漏掉的敌人**不算被清空**，
## 否则「全部漏光」也会被算成本波清空，而那时 CORE 分明已经掉血。
var escaped: bool = false


func _init(enemy_data: EnemyData, lane_index: int) -> void:
	data = enemy_data
	lane = lane_index
	hp = enemy_data.max_hp if enemy_data != null else 0.0


## 还在场上：没被打死、也没漏掉。画不画、能不能再挨打、会不会再推进，全看它。
func is_alive() -> bool:
	return died_at_tick < 0 and not escaped


## 血量比例（0..1）。HP 条按它画。max_hp 非正时返回 0 —— 别让画条的一方去除零。
func hp_ratio() -> float:
	if data == null or data.max_hp <= 0.0:
		return 0.0
	return clampf(hp / data.max_hp, 0.0, 1.0)


## 沿路径推进一拍。死掉或已漏掉的敌人不再推进（尸体不会继续走向 CORE）。
func advance() -> void:
	if not is_alive() or data == null:
		return
	progress = minf(progress + data.advance_per_tick, 1.0)


## 是否已走到终点。判定放在这里而不是让调用方比 progress，是为了让「到终点」只有一种说法。
func reached_end() -> bool:
	return progress >= 1.0


## 挨一次伤害。返回**这一下有没有把它打死** —— 调用方据此决定要不要播音效 / 计数，
## 而不是拿 hp 前后比一次（那样在同一拍内挨两下时会漏掉第一次击杀）。
func take_damage(amount: float, tick: int) -> bool:
	if not is_alive():
		return false
	hp = maxf(hp - amount, 0.0)
	if hp > 0.0:
		return false
	died_at_tick = tick
	return true


## 死亡后过了几拍。未死返回 -1 —— 与 MachineRuntime.shot_age() 同一套约定：
## 把「死没死」和「死了多久」收在一个返回值里，调用方就不必自己减拍数、也就不会减错。
func death_age(tick: int) -> int:
	if died_at_tick < 0:
		return -1
	return tick - died_at_tick


## 这一拍该不该把尸体从场上移除。漏掉的敌人立即移除（它是走掉的，不是死掉的），
## 被打死的敌人留 vanish_ticks 拍给占位消失动画。
func is_gone(tick: int, vanish_ticks: int) -> bool:
	if escaped:
		return true
	var age: int = death_age(tick)
	return age >= 0 and age >= vanish_ticks
