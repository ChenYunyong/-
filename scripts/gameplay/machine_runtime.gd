## machine_runtime.gd
## 职责：蓝图机器的固定节拍仿真（FIRST PLAYABLE 2/4 + 4/4 的 Heat）—— CORE 按固定节拍发脉冲、
##       脉冲沿有向边传播、FUNCTION 变换脉冲（分流 / 放大 / 延时）、WEAPON 收到脉冲即开火并把 Heat 加上去，
##       连续开火到阈值即 **Overheat**（停火 + 冷却，冷却完自动恢复）。
## 所属系统：gameplay
## 依赖：NodeData / ConnectionData / BlueprintData / SignalPulse
## 禁止：本文件不得触碰场景树 / 渲染 / 输入 / Palette / 存档 —— 它只推进数值，可见反馈由 ui 层读它的只读状态；
##       不得使用真实时间、Timer、_process 或自动运行 —— 推进的唯一入口是 tick()，由调用方按固定节拍喂
##       （03 §2：固定步长累加器；把时间来源放进仿真内部，仿真就无法在测试里被精确驱动）；
##       不得使用 randi() / randf()（03 §6）—— 同一份蓝图必须跑出同一串结果，否则确定性无从验证；
##       不得结算伤害 / 生成敌人 / 判定死亡（属 PET-65 的 combat_simulation.gd）。

class_name MachineRuntime
extends RefCounted

## 每秒的节拍数。取自 03 §2 的固定步长初值。**全项目唯一的节拍定义处**，
## 调用方一律由它派生（MachineDriver.TICK_SECONDS），不得另抄一个 20。
const TICK_RATE: int = 20

## CORE 每多少拍发一次脉冲（20 拍/秒 → 0.5 秒一次）。本卡不做调速，就是一个常数 ——
## 卡片明确「用常数，不要自己发明公式」。
const CORE_PERIOD_TICKS: int = 10

## 一枚脉冲穿过一条连线所需的拍数。连线长度不影响它：节拍是逻辑时间，不是几何距离。
const TRAVEL_TICKS: int = 4

## Delay 节点收下脉冲后滞留的拍数，之后才放行到下游。
const DELAY_TICKS: int = 12

## Amplify 的固定放大倍数。
const AMPLIFY_FACTOR: float = 2.0

## CORE 发出的脉冲初值。
const BASE_PULSE_VALUE: float = 1.0

## 每次开火累加的 Heat，以及 Heat 的上限（06 §8.1 的 `热量` 读数按百分比显示）。
const HEAT_PER_SHOT: float = 2.0
const MAX_HEAT: float = 100.0

## 过热后的冷却速度（每拍降多少 Heat）。**阈值就是 MAX_HEAT，不另设第二个常数** ——
## 两个数一旦各自可调，「读数到 100% 了却没停火」这类错就会没有任何断言能钉住。
## 100 / 2.5 = 40 拍 = 2 秒：短到不至于让玩家以为机器坏了，长到能真的改变战况。
const COOL_PER_TICK: float = 2.5

## 「刚被点亮」的判定窗口（拍）。定义在这里而不是 UI 里 —— 窗口若在 UI 侧另写一个数，
## 两边迟早对不上，而症状只是「闪烁看起来怪怪的」，没人会去查。
const FLASH_TICKS: int = 4

## 「刚开过火」的判定窗口（拍），也就是占位弹丸的存活时长。
const SHOT_TICKS: int = 8

## 某个节点本拍被点亮（CORE 自发、脉冲抵达、Delay 放行都算）。携带节点 id，UI 只读。
signal node_activated(node_id: StringName)

## 某个武器节点开火。本卡只到「打出一发占位弹」，不结算伤害（PET-65）。
signal weapon_fired(weapon_id: StringName)

## Heat 变化。携带的是**绝对值**不是增量 —— 增量语义在重连 / 补跑时会把读数加错。
signal heat_changed(heat: float)

## 进入 Overheat：Heat 到顶，武器停止开火并开始冷却。
signal overheat_started()

## 冷却完毕，机器恢复开火。
signal overheat_ended()

## 本拍推进完毕。UI 用它触发一次重绘，不去轮询。
signal ticked()

## 节点集合。**数组顺序即同拍内的执行顺序**（蓝图落盘顺序），确定性由此而来（03 §6）。
var _nodes: Array[NodeData] = []

## node_id -> NodeData。投递要按 id 取节点，逐次线性扫在节点多时会退化成 O(n²)。
var _by_id: Dictionary = {}

## node_id -> 该节点全部出边的目标 id，按蓝图连线顺序。
## **出边表就是「分流」的实现**：出边有几条就发几枚，不复制数据、也不限制条数（03 §4.2）。
var _outgoing: Dictionary = {}

## 在途脉冲，先进先出。
var _pulses: Array[SignalPulse] = []

## 被 Delay 节点收下、正在倒计时的脉冲。它们不在 _pulses 里，故不会被画成在途信号。
var _held: Array[SignalPulse] = []

## node_id -> 最近一次被点亮的拍号。缺键表示从未点亮。
var _activated: Dictionary = {}

## weapon_id -> 最近一次开火的拍号。缺键表示从未开火。
var _fired: Dictionary = {}

var _tick_index: int = 0
var _heat: float = 0.0
var _has_core: bool = false

## 是否正处于 Overheat。到阈值时置位、冷却到 0 时清除 —— 只有这一个字段决定「能不能开火」，
## 于是「读数说 100%」与「武器停了」不可能各说各话。
var _overheated: bool = false


func _init(blueprint: BlueprintData) -> void:
	if blueprint == null:
		return
	_nodes = blueprint.nodes
	for node: NodeData in _nodes:
		_by_id[node.id] = node
		var empty: Array[StringName] = []
		_outgoing[node.id] = empty
		if node.kind == NodeData.Kind.CORE:
			_has_core = true
	for link: ConnectionData in blueprint.connections:
		# 起点不存在的边直接丢：它永远不会被发出，留着只会让出边表和图对不上。
		if not _outgoing.has(link.from_node_id):
			continue
		var edges: Array[StringName] = _outgoing[link.from_node_id]
		edges.append(link.to_node_id)


## 推进一拍。**仿真时间的唯一入口** —— 调用它的节拍由 MachineDriver 按固定步长给出。
##
## 开头那一行快照定下了本拍的时间边界：**只有它之前就在途的脉冲会前进**。
## 少了这一行，本拍新发出的脉冲会在同一拍里被减一次倒计时，一条边就只走 TRAVEL_TICKS - 1 拍，
## 而且越靠近信号源的边越快 —— 症状是「后面的连线看起来更长」，几乎不可能靠看画面发现。
##
## Delay 的滞留用的是同一个边界：放行发生在前、收下发生在后，
## 故刚被收下的那一枚不会在自己被收下的这一拍里就被减掉一次（否则滞留期恒少一拍）。
func tick() -> void:
	_tick_index += 1
	var in_flight: int = _pulses.size()
	# 冷却排在发脉冲之前：冷却恰在本拍走完时，机器本拍就能重新开火 ——
	# 排到后面会平白多停一拍，而那一拍在画面上只表现为「恢复得慢一点」，查不出原因。
	_cool()
	_release_held()
	_emit_from_cores()
	_advance(in_flight)
	ticked.emit()


## 把快照内的在途脉冲各推一拍，走完的**当拍**抵达。快照之外（本拍新生的）一律不动，
## 故抵达时新发的下游脉冲要下一拍才走。
func _advance(in_flight: int) -> void:
	if in_flight == 0:
		return
	var arrived: Array[SignalPulse] = []
	for index: int in in_flight:
		var pulse: SignalPulse = _pulses[index]
		pulse.ticks_left -= 1
		if pulse.ticks_left <= 0:
			arrived.append(pulse)
	for pulse: SignalPulse in arrived:
		_pulses.erase(pulse)
		_deliver(pulse)


## CORE 按固定节拍自发脉冲（03 §2：CORE 由 tick 驱动，不等外部输入）。
## 有多个 CORE 时按节点顺序依次发 —— 顺序确定，不依赖字典遍历次序。
func _emit_from_cores() -> void:
	if not _has_core or _tick_index % CORE_PERIOD_TICKS != 0:
		return
	for node: NodeData in _nodes:
		if node.kind != NodeData.Kind.CORE:
			continue
		_light(node.id)
		_emit(node.id, BASE_PULSE_VALUE)


## Delay 的倒计时：到点才把滞留在它手里的脉冲放行到下游，放行当拍再点亮它一次。
func _release_held() -> void:
	if _held.is_empty():
		return
	var due: Array[SignalPulse] = []
	for pulse: SignalPulse in _held:
		pulse.ticks_left -= 1
		if pulse.ticks_left <= 0:
			due.append(pulse)
	for pulse: SignalPulse in due:
		_held.erase(pulse)
		_light(pulse.from_node_id)
		_emit(pulse.from_node_id, pulse.value)


## 脉冲抵达一个节点：先点亮它，再按它的类型决定下一步。
## 目标节点不存在（悬空边）时只点亮不转发 —— 空 id 不会在 _by_id 里，这里也就不会崩。
func _deliver(pulse: SignalPulse) -> void:
	_light(pulse.to_node_id)
	var node: NodeData = _by_id.get(pulse.to_node_id) as NodeData
	if node == null:
		return
	match node.kind:
		NodeData.Kind.WEAPON:
			_fire(node.id)
		NodeData.Kind.FUNCTION:
			_apply_function(node, pulse)
		_:
			# CORE 收到信号不做事：它的行为是「按节拍发」，不是「被推动」。
			pass


## FUNCTION 的三件（本卡范围）。
##
## 分流不是一次数值运算，而是**连线的形状**：出边有几条就发几枚，玩家想「1 进 2 出」就接两条边。
## 所以它与「未指定行为」的直通走同一条路 —— 把它写成一个会复制脉冲的分支才是错的，
## 那会让「接了两条边的分流」和「只接一条的分流」行为不一致。
func _apply_function(node: NodeData, pulse: SignalPulse) -> void:
	if node.function_kind == NodeData.Function.AMPLIFY:
		_emit(node.id, pulse.value * AMPLIFY_FACTOR)
	elif node.function_kind == NodeData.Function.DELAY:
		_held.append(_make_pulse(node.id, node.id, pulse.value, DELAY_TICKS))
	else:
		_emit(node.id, pulse.value)


## 从 from_id 的每条出边各发一枚脉冲。出边表在 _init 建好，这里不重算（02 §7）。
func _emit(from_id: StringName, value: float) -> void:
	if not _outgoing.has(from_id):
		return
	var edges: Array[StringName] = _outgoing[from_id]
	for index: int in edges.size():
		_pulses.append(_make_pulse(from_id, edges[index], value, TRAVEL_TICKS))


## 造一枚脉冲。倒计时初值与全程拍数**必须一起给** —— 分开设就会漏掉一个，
## 而 progress() 拿 0 当分母只会得到一个安静的 1.0，画面上表现为「脉冲一出生就在终点」。
func _make_pulse(from_id: StringName, to_id: StringName, value: float, travel: int) -> SignalPulse:
	var pulse := SignalPulse.new()
	pulse.from_node_id = from_id
	pulse.to_node_id = to_id
	pulse.value = value
	pulse.ticks_left = travel
	pulse.travel_ticks = travel
	return pulse


## 武器开火：打出一发（伤害结算在 combat_simulation.gd）+ 累积 Heat。
##
## Overheat 期间**根本不开火** —— 节点照旧被点亮（信号确实走到了那里），但没有弹丸、没有伤害。
## 这就是过热的代价：机器越猛，停火时漏掉的敌人越多。Heat 同时封顶在 MAX_HEAT，
## 读数格只有三位，不封顶会溢出成四位数。
func _fire(weapon_id: StringName) -> void:
	if _overheated:
		return
	_fired[weapon_id] = _tick_index
	_heat = minf(_heat + HEAT_PER_SHOT, MAX_HEAT)
	weapon_fired.emit(weapon_id)
	heat_changed.emit(_heat)
	if _heat >= MAX_HEAT:
		_overheated = true
		overheat_started.emit()


## 过热后的冷却。每拍降 COOL_PER_TICK，降到 0 即恢复开火。
## 冷却期间照旧广播绝对值 —— 读数格要能看着它掉下来，否则玩家只看到「100% 卡住不动」。
func _cool() -> void:
	if not _overheated:
		return
	_heat = maxf(_heat - COOL_PER_TICK, 0.0)
	heat_changed.emit(_heat)
	if _heat <= 0.0:
		_overheated = false
		overheat_ended.emit()


func _light(node_id: StringName) -> void:
	_activated[node_id] = _tick_index
	node_activated.emit(node_id)


## 已推进的拍数。UI 与测试用它算「最近 N 拍内发生过什么」，不必自己数帧。
func tick_index() -> int:
	return _tick_index


## 当前 Heat 绝对值（0..MAX_HEAT）。06 §8.1 的 `热量` 读数取它。
func heat() -> float:
	return _heat


## 是否正处于 Overheat（武器停火、正在冷却）。
func is_overheated() -> bool:
	return _overheated


## 机器里有没有信号源。没有 CORE 时这台机器一 tick 都不会动，
## 调用方据此给玩家一句可读提示，而不是让他对着不动的画面猜。
func has_core() -> bool:
	return _has_core


## 在途脉冲的**只读副本**。UI 每拍取一次画位置；直接交出内部数组，
## 调用方一次误改就能改到仿真状态，而那种错误在画面上只表现为「信号偶尔乱飞」。
func pulses() -> Array[SignalPulse]:
	var copy: Array[SignalPulse] = []
	copy.assign(_pulses)
	return copy


## node_id 是否在最近 FLASH_TICKS 拍内被点亮过。UI 据此画闪烁。
func is_lit(node_id: StringName) -> bool:
	if not _activated.has(node_id):
		return false
	return _tick_index - int(_activated[node_id]) < FLASH_TICKS


## 某武器最近一次开火的年龄（拍）。从未开火、或弹丸已过存活期时返回 -1 ——
## 把「开过火」和「弹丸还在飞」两件事收在一个返回值里，UI 就不必自己减拍数、也就不会减错。
func shot_age(weapon_id: StringName) -> int:
	if not _fired.has(weapon_id):
		return -1
	var age: int = _tick_index - int(_fired[weapon_id])
	return age if age < SHOT_TICKS else -1
