## machine_runtime.gd
## 职责：法术书的固定节拍仿真 —— 核心卡按固定节拍放出魔力脉冲、脉冲沿有向边传播、
##       功能卡改造脉冲（子弹数量 / 附魔 / 冷却）、能力卡收到脉冲即施放并**扣魔力**，
##       魔力见底即 **Overload（过载）**（哑火 + 回魔，回满自动恢复）。
## 所属系统：gameplay
## 依赖：NodeData / ConnectionData / BlueprintData / SignalPulse
## 禁止：本文件不得触碰场景树 / 渲染 / 输入 / Palette / 存档 —— 它只推进数值，可见反馈由 ui 层读它的只读状态；
##       不得使用真实时间、Timer、_process 或自动运行 —— 推进的唯一入口是 tick()，由调用方按固定节拍喂
##       （03 §2：固定步长累加器；把时间来源放进仿真内部，仿真就无法在测试里被精确驱动）；
##       不得使用 randi() / randf()（03 §6）—— 同一份法术书必须跑出同一串结果，否则确定性无从验证；
##       不得结算伤害 / 生成敌人 / 判定死亡（属 combat_simulation.gd）。
##
## PET-82（MAGIC-01）把 Heat / Overheat 换成 Mana / Overload：**方向反过来**。
## 旧机制是「开火攒热，攒满被罚停」—— 玩家越猛越挨罚，读数是惩罚进度条；
## 新机制是「施法花魔力，魔力回不上来就哑火」—— 读数是**资源余量**，见底才是过载。
## 阈值因此从上限挪到了下限：旧代码比的是 `_heat >= MAX_HEAT`，现在比的是 `_mana <= 0`。
## 「过载」的判据也随之变成「魔力见底」，同一个字段同时决定读数与停火，两者不可能各说各话。

class_name MachineRuntime
extends RefCounted

## 每秒的节拍数。取自 03 §2 的固定步长初值。**全项目唯一的节拍定义处**，
## 调用方一律由它派生（MachineDriver.TICK_SECONDS），不得另抄一个 20。
const TICK_RATE: int = 20

## 核心卡每多少拍放一次脉冲（20 拍/秒 → 0.5 秒一次）。本卡不做调速，就是一个常数 ——
## 卡片明确「用常数，不要自己发明公式」。
const CORE_PERIOD_TICKS: int = 10

## 一枚脉冲穿过一条连线所需的拍数。连线长度不影响它：节拍是逻辑时间，不是几何距离。
const TRAVEL_TICKS: int = 4

## 冷却功能卡收下脉冲后滞留的拍数，之后才放行到下游。
const COOLDOWN_TICKS: int = 12

## 附魔功能卡的固定放大倍数。
const ENCHANT_FACTOR: float = 2.0

## 核心卡放出的脉冲初值。
const BASE_PULSE_VALUE: float = 1.0

## 一次施法消耗的魔力，以及魔力上限（06 §8.1 的 `魔力` 读数按百分比显示）。
##
## 12 这个数不是随手挑的：它由「一张核心卡能养活几张能力卡」反推 —— 一个脉冲周期（10 拍）
## 回 10 × 2.5 = 25 点魔力，正好够**两张**各施放一次（24），不够**三张**（36）。
## 于是「两张能力卡的书写得动、三张的书会过载」成为一条玩家自己能摸出来的规律，
## 而不是一条写在帮助里的规则 —— 见 MANA_REGEN_PER_TICK 的注释。
const MANA_PER_CAST: float = 12.0
const MANA_MAX: float = 100.0

## 每拍回复的魔力。与 MANA_PER_CAST 的关系就是这套机制的**全部平衡**：
## 25/周期 对 24（两发，净 +1，稳定）与 36（三发，净 -11，约 3 秒见底）。
## 三张的书见底后再回满要 100 / 2.5 = 40 拍 = 2 秒 —— 短到不至于让玩家以为法术书坏了，
## 长到足以让漏掉的敌人真的走过去。
const MANA_REGEN_PER_TICK: float = 2.5

## 「刚被点亮」的判定窗口（拍）。定义在这里而不是 UI 里 —— 窗口若在 UI 侧另写一个数，
## 两边迟早对不上，而症状只是「闪烁看起来怪怪的」，没人会去查。
const FLASH_TICKS: int = 4

## 「刚施放过」的判定窗口（拍），也就是施放特效的存活时长。
const SHOT_TICKS: int = 8

## 某个节点本拍被点亮（核心卡自发、脉冲抵达、冷却功能卡放行都算）。携带节点 id，UI 只读。
signal node_activated(node_id: StringName)

## 某个能力卡节点施放。本卡只到「打出一发」，不结算伤害。
signal ability_cast(ability_id: StringName)

## 魔力变化。携带的是**绝对值**不是增量 —— 增量语义在重连 / 补跑时会把读数加错。
signal mana_changed(mana: float)

## 进入 Overload：魔力见底，能力卡停止施放并开始回魔。
signal overload_started()

## 回魔完毕，法术书恢复施放。
signal overload_ended()

## 本拍推进完毕。UI 用它触发一次重绘，不去轮询。
signal ticked()

## 节点集合。**数组顺序即同拍内的执行顺序**（蓝图落盘顺序），确定性由此而来（03 §6）。
var _nodes: Array[NodeData] = []

## node_id -> NodeData。投递要按 id 取节点，逐次线性扫在节点多时会退化成 O(n²)。
var _by_id: Dictionary = {}

## node_id -> 该节点全部出边的目标 id，按蓝图连线顺序。
## **出边表就是「子弹数量」的实现**：出边有几条就发几枚，不复制数据、也不限制条数（03 §4.2）。
var _outgoing: Dictionary = {}

## 在途脉冲，先进先出。
var _pulses: Array[SignalPulse] = []

## 被冷却符文收下、正在倒计时的脉冲。它们不在 _pulses 里，故不会被画成在途信号。
var _held: Array[SignalPulse] = []

## node_id -> 最近一次被点亮的拍号。缺键表示从未点亮。
var _activated: Dictionary = {}

## ability_id -> 最近一次施放的拍号。缺键表示从未施放。
var _fired: Dictionary = {}

var _tick_index: int = 0
var _mana: float = MANA_MAX
var _has_core: bool = false

## 是否正处于 Overload。魔力见底时置位、回满时清除 —— 只有这一个字段决定「能不能施放」，
## 于是「读数说 0%」与「能力卡停了」不可能各说各话。
var _overloaded: bool = false


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
## 冷却符文滞留用的是同一个边界：放行发生在前、收下发生在后，
## 故刚被收下的那一枚不会在自己被收下的这一拍里就被减掉一次（否则滞留期恒少一拍）。
func tick() -> void:
	_tick_index += 1
	var in_flight: int = _pulses.size()
	# 回魔排在放脉冲之前：回魔恰在本拍走完时，法术书本拍就能重新施放 ——
	# 排到后面会平白多哑火一拍，而那一拍在画面上只表现为「恢复得慢一点」，查不出原因。
	_regen()
	_release_held()
	_emit_from_sources()
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


## 核心卡按固定节拍自发脉冲（03 §2：核心卡由 tick 驱动，不等外部输入）。
## 有多个核心卡时按节点顺序依次发 —— 顺序确定，不依赖字典遍历次序。
func _emit_from_sources() -> void:
	if not _has_core or _tick_index % CORE_PERIOD_TICKS != 0:
		return
	for node: NodeData in _nodes:
		if node.kind != NodeData.Kind.CORE:
			continue
		_light(node.id)
		_emit(node.id, BASE_PULSE_VALUE)


## 冷却符文的倒计时：到点才把滞留在它手里的脉冲放行到下游，放行当拍再点亮它一次。
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
		NodeData.Kind.ABILITY:
			_fire(node.id)
		NodeData.Kind.FUNCTION:
			_apply_rune(node, pulse)
		_:
			# 核心卡收到信号不做事：它的行为是「按节拍放」，不是「被推动」。
			pass


## 功能卡的三件（本卡范围）。
##
## 子弹数量不是一次数值运算，而是**连线的形状**：出边有几条就发几枚，玩家想「1 进 2 出」就接两条边。
## 所以它与「未指定修饰」的直通走同一条路 —— 把它写成一个会复制脉冲的分支才是错的，
## 那会让「接了两条边的子弹数量」和「只接一条的子弹数量」行为不一致。
func _apply_rune(node: NodeData, pulse: SignalPulse) -> void:
	if node.function_kind == NodeData.Function.ENCHANT:
		_emit(node.id, pulse.value * ENCHANT_FACTOR)
	elif node.function_kind == NodeData.Function.COOLDOWN:
		_held.append(_make_pulse(node.id, node.id, pulse.value, COOLDOWN_TICKS))
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


## 能力卡施放：打出一发（伤害结算在 combat_simulation.gd）+ 扣魔力。
##
## Overload 期间**根本不施放** —— 节点照旧被点亮（魔力确实走到了那里），但没有能力卡、没有伤害。
## 这就是过载的代价：法术书越猛，哑火时漏掉的敌人越多。
##
## 见底那一发照常打出去、再把魔力压到 0：先把这一发吞掉再判定过载，
## 玩家看到的是「最后一发打出去了，然后哑火」，而不是「明明还有一点点魔力却打不出来」。
## 同一拍内后续的能力卡因为 _overloaded 已置位而不再施放 —— 一拍的哑火，从这里开始。
func _fire(ability_id: StringName) -> void:
	if _overloaded:
		return
	_fired[ability_id] = _tick_index
	_spend(MANA_PER_CAST)
	ability_cast.emit(ability_id)
	if _mana <= 0.0 and not _overloaded:
		_overloaded = true
		overload_started.emit()


## 回魔。每拍回 MANA_REGEN_PER_TICK，回满即恢复施放。
## 回魔期间照旧广播绝对值 —— 读数格要能看着它涨回来，否则玩家只看到「0% 卡住不动」。
##
## 只在数值真的变了才广播：满魔时本来就不动，逐拍发一次只会让每秒钟多 20 次无意义的信号。
func _regen() -> void:
	if _mana >= MANA_MAX:
		return
	_mana = minf(_mana + MANA_REGEN_PER_TICK, MANA_MAX)
	mana_changed.emit(_mana)
	if _mana >= MANA_MAX and _overloaded:
		_overloaded = false
		overload_ended.emit()


## 扣魔力并广播。封底在 0：读数格按百分比显示，负值会印成一个带减号的怪东西。
## 只在数值真的变了才广播，理由同 _regen()。
func _spend(amount: float) -> void:
	var before: float = _mana
	_mana = maxf(_mana - amount, 0.0)
	if _mana != before:
		mana_changed.emit(_mana)


func _light(node_id: StringName) -> void:
	_activated[node_id] = _tick_index
	node_activated.emit(node_id)


## 已推进的拍数。UI 与测试用它算「最近 N 拍内发生过什么」，不必自己数帧。
func tick_index() -> int:
	return _tick_index


## 当前魔力绝对值（0..MANA_MAX）。06 §8.1 的 `魔力` 读数取它。
func mana() -> float:
	return _mana


## 是否正处于 Overload（能力卡停发、正在回魔）。
func is_overloaded() -> bool:
	return _overloaded


## 法术书里有没有核心卡。没有核心卡时这本一 tick 都不会动，
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


## 某能力卡最近一次施放的年龄（拍）。从未施放、或能力卡已过存活期时返回 -1 ——
## 把「施放过」和「能力卡还在飞」两件事收在一个返回值里，UI 就不必自己减拍数、也就不会减错。
func shot_age(ability_id: StringName) -> int:
	if not _fired.has(ability_id):
		return -1
	var age: int = _tick_index - int(_fired[ability_id])
	return age if age < SHOT_TICKS else -1
