## test_heat.gd
## 职责：Heat / Overheat 的**纯逻辑**（FIRST PLAYABLE 4/4）—— 连续开火累加 Heat、
##       到 MAX_HEAT 触发 Overheat（停火 + 冷却）、冷却到 0 恢复开火、以及过热可重复发生。
## 所属系统：tests
## 依赖：test_context, scripts/gameplay/machine_runtime.gd,
##       scripts/data/{node_data,connection_data,blueprint_data}.gd
## 禁止：本文件不得入树、不得碰真实时间 —— 全部在内存里手摇 tick()（09 §4：仿真若依赖真实时间，
##       同一份蓝图在不同机器上会跑出不同结果，用例本身就不可复现）；
##       不得落盘（本用例一张蓝图都不存）。
##
## 与 test_signal_flow.gd 的分工：那边钉「信号怎么走、Heat 怎么累加」，本文件只钉**阈值之后的四件事**
## —— 停火、冷却、恢复、可重复 —— 外加广播值域。故这里的机器取最短的一条链（CORE → 针）：
## 每一发的拍号都能由两个常数直接算出来，断言里因此不出现任何魔数。

extends RefCounted

## 开火拍号、overheat_started / overheat_ended 的拍号，以及每一次 heat_changed 的值。
## 探针**只记录**，不干预仿真。
var _fired: Array[int] = []
var _started: Array[int] = []
var _ended: Array[int] = []
var _heat_log: Array[float] = []
var _watched: MachineRuntime = null


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_episode_checks(ctx)
	_run_broadcast_checks(ctx)
	_run_degenerate_checks(ctx)


## 一段完整的过热：到阈值 → 停火 → 冷却 → 恢复 → 再来一次。
##
## 四段共用同一个运行时，因为它们是**同一段因果**：后一段的起点就是前一段的终点。
## 拆成四个独立机器反而要各自重跑几百拍，且「冷却从哪一拍算起」会变成抄一遍常数。
func _run_episode_checks(ctx: RefCounted) -> void:
	var runtime: MachineRuntime = _machine(_shortest())
	var trigger: int = _shot_tick(_shots_to_overheat())

	ctx.begin_case("Heat · 连续开火到阈值触发 Overheat")
	_tick_until(runtime, trigger - 1)
	ctx.equal(_fired.size(), _shots_to_overheat() - 1, "到阈值前一发应照常开火")
	ctx.check(not runtime.is_overheated(), "差一发到阈值时不得过热")
	ctx.check(runtime.heat() < MachineRuntime.MAX_HEAT, "差一发时 Heat 应低于上限")
	ctx.equal(_started.size(), 0, "还没到阈值不得广播 overheat_started")

	_tick_until(runtime, trigger)
	ctx.equal(runtime.heat(), MachineRuntime.MAX_HEAT, "触发的那一拍 Heat 应恰是 MAX_HEAT")
	ctx.check(runtime.is_overheated(), "累加到阈值应置位 Overheat")
	ctx.equal(_started.size(), 1, "overheat_started 应广播恰好一次")
	ctx.equal(_started[0], trigger, "overheat_started 的拍号")
	ctx.equal(_ended.size(), 0, "同一拍不得立刻结束过热")

	ctx.begin_case("Heat · 过热期间停火，但信号照旧抵达")
	var fired_before: int = _fired.size()
	_tick_until(runtime, _shot_tick(_shots_to_overheat() + 1))
	ctx.equal(_fired.size(), fired_before, "过热期间不得开火")
	ctx.check(runtime.is_lit(&"needle"),
		"信号仍应抵达武器（节点照旧被点亮）—— 停的是开火，不是传播")
	ctx.equal(_started.size(), 1,
		"过热期间不得反复广播 overheat_started（它是一次状态变化的通知，不是每拍的心跳）")

	var cooled: float = runtime.heat()
	_tick(runtime, 1)
	ctx.check(runtime.heat() < cooled, "过热期间 Heat 应逐拍下降（读数格要能看着它掉下来）")

	ctx.begin_case("Heat · 冷却到 0 恢复开火")
	var recover: int = trigger + _cool_ticks()
	_tick_until(runtime, recover)
	ctx.check(not runtime.is_overheated(), "冷却 %d 拍（%.1f 秒）后应恢复开火" % [
		_cool_ticks(), float(_cool_ticks()) / float(MachineRuntime.TICK_RATE)])
	ctx.equal(_ended.size(), 1, "overheat_ended 应广播恰好一次")
	ctx.equal(_ended[0], recover, "overheat_ended 的拍号（触发那一拍 + 冷却时长）")
	# 冷却走完的那一拍最多只可能多算一发（信号正好也在这一拍抵达时）——
	# 故这里断言的是「已经清零并重新起算」，而不是一个恰好等于 0 的数：
	# 那个 0 只在两个时长凑巧整除时才成立，把它写死会让这条断言在改冷却速度时莫名其妙转红。
	ctx.check(runtime.heat() <= MachineRuntime.HEAT_PER_SHOT,
		"冷却走完后 Heat 应已清零，最多只算上这一拍重新开火的那一发（实际 %.1f）" % runtime.heat())

	# 恢复之后的第一发不一定正好落在恢复那一拍上（取决于两个时长能不能整除），
	# 故这里推进到**恢复之后的第一发**，而不是把「恢复那一拍恰好有信号抵达」当成前提。
	var resume: int = _next_shot_tick(recover)
	_tick_until(runtime, resume)
	ctx.equal(_fired.size(), fired_before + 1, "冷却结束后信号再次抵达即恢复开火（第 %d 拍）" % resume)
	ctx.equal(runtime.heat(), MachineRuntime.HEAT_PER_SHOT, "恢复后的 Heat 应从重新开火那一发算起")
	ctx.equal(_ended.size(), 1, "恢复不得变成每拍都广播一次 overheat_ended")

	ctx.begin_case("Heat · 过热可重复发生（不是一次性的闩锁）")
	# 恢复时手里已有 HEAT_PER_SHOT，故再凑满上限只需要剩下的那几发。
	var remaining: int = int(ceilf((MachineRuntime.MAX_HEAT - MachineRuntime.HEAT_PER_SHOT)
		/ MachineRuntime.HEAT_PER_SHOT))
	var second_trigger: int = resume + remaining * MachineRuntime.CORE_PERIOD_TICKS
	_tick_until(runtime, second_trigger)
	ctx.equal(_started.size(), 2, "恢复之后应能再次过热")
	ctx.check(runtime.is_overheated(), "第二次到阈值应再次停火")
	ctx.equal(runtime.heat(), MachineRuntime.MAX_HEAT, "第二次触发时 Heat 应同样封顶在 MAX_HEAT")
	ctx.equal(_ended.size(), 1, "第二次过热才开始，还没到结束")


## 06 §8.1 的 `热量` 读数直接印广播值，故每一次广播都必须在读数格放得下的范围内；
## 且冷却期间**必须**继续广播 —— 否则玩家看到的是「100% 卡住不动」，那与卡死分不开。
func _run_broadcast_checks(ctx: RefCounted) -> void:
	ctx.begin_case("Heat · 广播的值域与「掉下来也要广播」（06 §8.1）")
	var runtime: MachineRuntime = _machine(_shortest())
	_tick_until(runtime, _shot_tick(_shots_to_overheat()) + _cool_ticks())

	var peak: float = 0.0
	var lowest: float = MachineRuntime.MAX_HEAT
	var out_of_range: int = 0
	for value: float in _heat_log:
		peak = maxf(peak, value)
		lowest = minf(lowest, value)
		if value < 0.0 or value > MachineRuntime.MAX_HEAT:
			out_of_range += 1
	ctx.check(_heat_log.size() > 0, "这一段里应当确实广播过（否则下面三条是空话）")
	ctx.check(out_of_range == 0,
		"每一次广播都应落在 [0, MAX_HEAT]（越界会印成四位数或负数，共 %d 次广播）" % _heat_log.size())
	ctx.equal(peak, MachineRuntime.MAX_HEAT, "广播的最大值应恰是 MAX_HEAT（确实走到过阈值）")
	ctx.equal(lowest, 0.0, "冷却到 0 也要广播一次 —— 否则读数卡在 100% 不动")


## 「没有机器」是玩家的正常状态（一次都没进过整备），不是异常：heat 恒为 0，且永不判定过热。
func _run_degenerate_checks(ctx: RefCounted) -> void:
	ctx.begin_case("边界 · 没有武器 / 没有 CORE / 没有蓝图时永不过热")
	var bare: MachineRuntime = _machine(_graph([{"id": "core", "kind": NodeData.Kind.CORE}], []))
	_tick(bare, 4 * _shots_to_overheat() * MachineRuntime.CORE_PERIOD_TICKS)
	ctx.equal(bare.heat(), 0.0, "有 CORE 但没有武器时 Heat 应恒为 0")
	ctx.check(not bare.is_overheated(), "没有武器时不得过热")
	ctx.equal(_started.size(), 0, "没有武器时不得广播 overheat_started")

	var orphan: MachineRuntime = _machine(_graph([{"id": "needle", "kind": NodeData.Kind.WEAPON}], []))
	_tick(orphan, 200)
	ctx.equal(orphan.heat(), 0.0, "有武器但没有 CORE 时 Heat 应恒为 0")
	ctx.check(not orphan.is_overheated(), "没有 CORE 时不得过热")

	var nothing: MachineRuntime = _machine(null)
	_tick(nothing, 200)
	ctx.equal(nothing.heat(), 0.0, "null 蓝图不得产生 Heat")
	ctx.check(not nothing.is_overheated(), "null 蓝图空转不得过热")


## 最短的一条链：CORE → 针（一条边）。首发 = CORE 节拍 + 一条边的传播时间，
## 之后每 CORE 节拍一发 —— 每一发的拍号都算得出来。
func _shortest() -> BlueprintData:
	return _graph(
		[{"id": "core", "kind": NodeData.Kind.CORE}, {"id": "needle", "kind": NodeData.Kind.WEAPON}],
		[{"from": "core", "to": "needle"}])


## 第 index 发（从 1 起）的绝对拍号。
func _shot_tick(index: int) -> int:
	return MachineRuntime.CORE_PERIOD_TICKS + MachineRuntime.TRAVEL_TICKS \
		+ (index - 1) * MachineRuntime.CORE_PERIOD_TICKS


## 拍号 at **当天或之后**的第一发。
func _next_shot_tick(at: int) -> int:
	var first: int = MachineRuntime.CORE_PERIOD_TICKS + MachineRuntime.TRAVEL_TICKS
	var steps: int = maxi(0,
		int(ceilf(float(at - first) / float(MachineRuntime.CORE_PERIOD_TICKS))))
	return first + steps * MachineRuntime.CORE_PERIOD_TICKS


## 到阈值需要几发。由两个常数算出，不写死。
func _shots_to_overheat() -> int:
	return int(ceilf(MachineRuntime.MAX_HEAT / MachineRuntime.HEAT_PER_SHOT))


## 过热之后要冷却几拍。
func _cool_ticks() -> int:
	return int(ceilf(MachineRuntime.MAX_HEAT / MachineRuntime.COOL_PER_TICK))


## 建运行时并挂上探针。
func _machine(blueprint: BlueprintData) -> MachineRuntime:
	_fired.clear()
	_started.clear()
	_ended.clear()
	_heat_log.clear()
	var runtime := MachineRuntime.new(blueprint)
	_watched = runtime
	runtime.weapon_fired.connect(_on_fired)
	runtime.overheat_started.connect(_on_overheat_started)
	runtime.overheat_ended.connect(_on_overheat_ended)
	runtime.heat_changed.connect(_on_heat)
	return runtime


func _on_fired(_weapon_id: StringName) -> void:
	_fired.append(_watched.tick_index())


func _on_overheat_started() -> void:
	_started.append(_watched.tick_index())


func _on_overheat_ended() -> void:
	_ended.append(_watched.tick_index())


func _on_heat(heat: float) -> void:
	_heat_log.append(heat)


## 从零搭一张图。与 test_signal_flow.gd 的同名助手一致：节点全部落图之后才连线，
## 于是「边连到不存在的节点」只会是悬空边，不会与「节点声明顺序写错」混成同一个症状。
func _graph(spec: Array[Dictionary], links: Array[Dictionary]) -> BlueprintData:
	var blueprint: BlueprintData = BlueprintData.new()
	for item: Dictionary in spec:
		var node := NodeData.new()
		node.id = StringName(String(item["id"]))
		node.display_name = String(item["id"])
		node.kind = int(item.get("kind", NodeData.Kind.FUNCTION))
		blueprint.nodes.append(node)
	for link: Dictionary in links:
		var edge := ConnectionData.new()
		edge.from_node_id = StringName(String(link["from"]))
		edge.from_port = &"out"
		edge.to_node_id = StringName(String(link["to"]))
		edge.to_port = &"in"
		blueprint.connections.append(edge)
	return blueprint


func _tick(runtime: MachineRuntime, times: int) -> void:
	for index: int in maxi(times, 0):
		runtime.tick()


## 推进到指定的绝对拍号。目标已过或正好在当下时一拍都不推 ——
## 「推进 N 拍」写多了会随上下文漂移，绝对拍号不会。
func _tick_until(runtime: MachineRuntime, target: int) -> void:
	while runtime.tick_index() < target:
		runtime.tick()
