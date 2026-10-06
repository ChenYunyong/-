## test_mana.gd
## 职责：Mana / Overload 的**纯逻辑**（PET-82 / todo R8）—— 施法扣魔力、停手回魔力、
##       魔力见底触发 Overload（哑火 + 回魔）、回满恢复施放、以及过载可重复发生。
## 所属系统：tests
## 依赖：test_context, scripts/gameplay/machine_runtime.gd,
##       scripts/data/{node_data,connection_data,blueprint_data}.gd
## 禁止：本文件不得入树、不得碰真实时间 —— 全部在内存里手摇 tick()（09 §4：仿真若依赖真实时间，
##       同一份法术书在不同机器上会跑出不同结果，用例本身就不可复现）；
##       不得落盘（本用例一张法术书都不存）。
##
## 与 test_signal_flow.gd 的分工：那边钉「魔力怎么走、脉冲怎么传」，本文件只钉**魔力这条资源线**
## —— 扣、回、见底、恢复、可重复 —— 外加广播值域。
##
## 与旧 test_heat.gd 的关系：PET-82 把 Heat / Overheat 换成 Mana / Overload，**方向反过来**。
## 旧机制「开火攒热、攒满被罚停」在单武器下就能自证（50 发攒到 100）；
## 新机制是**资源**：每周期回的量是固定的，施法越多抠得越狠。
## 故本文件反过来先钉「**一枚能力卡的书永不过载**」，过载那几条改用三枚能力卡的书 ——
## 这正是本卡要玩家自己摸出来的那条规律（一源养两发，第三发开始透支）。
##
## 反向对照有两条，缺一不可：
##   · 在树内 —— `_run_discriminating_control`：同样跑那么久，两发的书不过载、三发的书过载。
##     少了它，「过载会发生」可能只是「魔力机制压根没接上」的另一种说法。
##   · 卡面点名的那条（把 MANA_PER_CAST 改成 0，过载用例必须转红）要改常数、跑不了在树内，
##     取证见交付评论。

extends RefCounted

## 施法拍号、overload_started / overload_ended 的拍号，以及每一次 mana_changed 的值。
## 探针**只记录**，不干预仿真。
var _fired: Array[int] = []
var _started: Array[int] = []
var _ended: Array[int] = []
var _mana_log: Array[float] = []
var _watched: MachineRuntime = null


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_single_spell_checks(ctx)
	_run_regen_checks(ctx)
	_run_episode_checks(ctx)
	_run_broadcast_checks(ctx)
	_run_discriminating_control(ctx)
	_run_degenerate_checks(ctx)


## 一枚能力卡的书：魔力只在 100 与 100 - MANA_PER_CAST 之间来回，永远见不了底。
## 这一条同时是后面所有过载用例的**前置**：过载不是「只要施法就会发生」。
func _run_single_spell_checks(ctx: RefCounted) -> void:
	ctx.begin_case("Mana · 施法扣魔力，一枚能力卡的书永不过载")
	var runtime: MachineRuntime = _machine(_chain(1))
	ctx.equal(runtime.mana(), MachineRuntime.MANA_MAX,
		"初始魔力应是满的（旧存档 / 首次进战斗都从这里起）")
	ctx.equal(runtime.has_core(), true, "这台书里有核心卡")

	_tick_until(runtime, _shot_tick(1))
	ctx.equal(_fired.size(), 1, "第 %d 拍应有第一发" % _shot_tick(1))
	ctx.equal(runtime.mana(), MachineRuntime.MANA_MAX - MachineRuntime.MANA_PER_CAST,
		"施法当拍魔力应恰好扣掉一发（这一拍的回魔把魔力顶在上限，扣的是满值）")

	# 走满好几轮，看它有没有被攒着的能力卡拖垮。
	_tick(runtime, 20 * MachineRuntime.CORE_PERIOD_TICKS)
	ctx.check(runtime.mana() > 0.0, "一枚能力卡时魔力不得见底（实际 %.1f）" % runtime.mana())
	ctx.check(not runtime.is_overloaded(),
		"一枚能力卡的书不该过载 —— 过载是「能力卡太多」的代价，不是施法的代价")
	ctx.equal(_started.size(), 0, "不过载时不得广播 overload_started")


## 停手就回魔：把能力卡去掉（只留核心卡），魔力维持满值；再花掉一发，看它自己涨回来。
func _run_regen_checks(ctx: RefCounted) -> void:
	ctx.begin_case("Mana · 停手回魔力（06 §8.1 的读数要能看着它涨回来）")
	var idle: MachineRuntime = _machine(_chain(0))
	_tick(idle, 5 * MachineRuntime.CORE_PERIOD_TICKS)
	ctx.equal(idle.mana(), MachineRuntime.MANA_MAX, "没有能力卡时魔力应恒为满")
	ctx.equal(_mana_log.size(), 0, "满魔时不必逐拍广播（每秒 20 次无意义的信号）")

	var runtime: MachineRuntime = _machine(_chain(1))
	_tick_until(runtime, _shot_tick(1))
	ctx.equal(runtime.mana(), MachineRuntime.MANA_MAX - MachineRuntime.MANA_PER_CAST, "前置：先扣掉一发")
	# 回满需要几拍由两个常数算出，不写死。
	var ticks_to_full: int = int(ceilf(MachineRuntime.MANA_PER_CAST / MachineRuntime.MANA_REGEN_PER_TICK))
	_tick(runtime, ticks_to_full - 1)
	ctx.check(runtime.mana() < MachineRuntime.MANA_MAX,
		"差一拍时还不该回满（实际 %.1f）" % runtime.mana())
	_tick(runtime, 1)
	ctx.equal(runtime.mana(), MachineRuntime.MANA_MAX, "%d 拍后应回满" % ticks_to_full)


## 一段完整的过载：见底 → 停火 → 回魔 → 恢复 → 再来一次。
##
## 四段共用同一个运行时，因为它们是**同一段因果**：后一段的起点就是前一段的终点。
## 拆成四个独立机器反而要各自重跑几百拍，且「回魔从哪一拍算起」会变成抄一遍常数。
func _run_episode_checks(ctx: RefCounted) -> void:
	var count: int = _abilities_to_overload()
	var runtime: MachineRuntime = _machine(_chain(count))
	var trigger: int = _overload_tick()

	ctx.begin_case("Mana · 施法花超了每周期回的量，魔力见底触发 Overload")
	_tick_until(runtime, trigger - 1)
	ctx.check(runtime.mana() > 0.0, "差一拍时魔力应还没见底（实际 %.1f）" % runtime.mana())
	ctx.check(not runtime.is_overloaded(), "差一拍时不得过载")
	ctx.equal(_started.size(), 0, "还没见底不得广播 overload_started")

	var before_trigger: int = _fired.size()
	_tick(runtime, 1)
	ctx.equal(runtime.mana(), 0.0, "触发的那一拍魔力应恰是 0（见底那一发照常打出去）")
	ctx.check(runtime.is_overloaded(), "魔力见底应置位 Overload")
	ctx.equal(_started.size(), 1, "overload_started 应广播恰好一次")
	ctx.equal(_started[0], trigger, "overload_started 的拍号")
	ctx.equal(_fired.size() - before_trigger, count, "见底那一拍的能力卡照旧全部打出去")
	ctx.equal(_ended.size(), 0, "同一拍不得立刻结束过载")

	ctx.begin_case("Mana · 过载期间停火，但魔力照旧抵达")
	var fired_before: int = _fired.size()
	var during: int = trigger + MachineRuntime.CORE_PERIOD_TICKS
	_tick_until(runtime, during)
	ctx.check(runtime.is_overloaded(), "回魔还没走完，这一拍应仍在过载中")
	ctx.equal(_fired.size(), fired_before, "过载期间不得施放（第 %d 拍也没有新能力卡）" % during)
	ctx.check(runtime.is_lit(&"spell0"),
		"魔力仍应抵达能力卡（节点照旧被点亮）—— 停的是施放，不是传播")
	ctx.equal(_started.size(), 1,
		"过载期间不得反复广播 overload_started（它是一次状态变化的通知，不是每拍的心跳）")
	var before_regen: float = runtime.mana()
	_tick(runtime, 1)
	ctx.check(runtime.mana() > before_regen, "过载期间魔力应逐拍回升（读数格要能看着它涨回来）")

	ctx.begin_case("Mana · 回满自动恢复施放")
	var recover: int = trigger + _regen_ticks()
	_tick_until(runtime, recover)
	ctx.check(not runtime.is_overloaded(), "回魔 %d 拍（%.1f 秒）后应恢复施放" % [
		_regen_ticks(), float(_regen_ticks()) / float(MachineRuntime.TICK_RATE)])
	ctx.equal(_ended.size(), 1, "overload_ended 应广播恰好一次")
	ctx.equal(_ended[0], recover, "overload_ended 的拍号（见底那一拍 + 回满所需拍数）")
	# 恢复那一拍魔力恰好回满 —— 但同一拍可能正好有一批能力卡抵达并立刻花掉，
	# 故这里断言的是「回满过」（广播里出现过 MANA_MAX），而不是「此刻手里还是满的」。
	ctx.check(_mana_log.has(MachineRuntime.MANA_MAX), "回满的那一下应广播过满值")

	ctx.begin_case("Mana · 过载可重复发生（不是一次性的闩锁）")
	# 恢复之后能撑多久取决于恢复当拍有没有立刻又花掉一批，故这里推到「第二次过载」
	# 而不是把两次过载的间隔写成一个手算的常数 —— 手算的那个数会随常数改动静默过期。
	var bound: int = recover + (_abilities_to_overload() + 2) * _cycles_to_overload() * MachineRuntime.CORE_PERIOD_TICKS
	while _started.size() < 2 and runtime.tick_index() < bound:
		runtime.tick()
	ctx.equal(_started.size(), 2, "恢复之后应能再次过载（上限 %d 拍内）" % bound)
	ctx.check(runtime.is_overloaded(), "第二次见底应再次停火")
	ctx.equal(runtime.mana(), 0.0, "第二次触发时魔力应同样见底")
	ctx.equal(_ended.size(), 1, "第二次过载才开始，还没到结束")


## 06 §8.1 的 `魔力` 读数直接印广播值，故每一次广播都必须在读数格放得下的范围内；
## 且回魔期间**必须**继续广播 —— 否则玩家看到的是「0% 卡住不动」，那与卡死分不开。
func _run_broadcast_checks(ctx: RefCounted) -> void:
	ctx.begin_case("Mana · 广播的值域与「涨回来也要广播」（06 §8.1）")
	var runtime: MachineRuntime = _machine(_chain(_abilities_to_overload()))
	var bound: int = _overload_tick() + _regen_ticks() + 2
	_tick_until(runtime, bound)

	var peak: float = 0.0
	var lowest: float = MachineRuntime.MANA_MAX
	var out_of_range: int = 0
	for value: float in _mana_log:
		peak = maxf(peak, value)
		lowest = minf(lowest, value)
		if value < 0.0 or value > MachineRuntime.MANA_MAX:
			out_of_range += 1
	ctx.check(_mana_log.size() > 0, "这一段里应当确实广播过（否则下面三条是空话）")
	ctx.check(out_of_range == 0,
		"每一次广播都应落在 [0, MANA_MAX]（越界会印成四位数或负数，共 %d 次广播）" % _mana_log.size())
	ctx.equal(peak, MachineRuntime.MANA_MAX, "广播的最大值应恰是 MANA_MAX（回满时确实广播过）")
	ctx.equal(lowest, 0.0, "见底到 0 也要广播一次 —— 否则读数卡在 100% 不动")


## 反向对照：同一台机器的形状，只差能力卡数量 —— 两发养得动、三发透支。
## 一个恒不过载的实现会让上面几条全红，而一个恒过载的实现在这里立刻露馅。
func _run_discriminating_control(ctx: RefCounted) -> void:
	ctx.begin_case("Mana · 反向对照：两发养得动、三发才透支")
	var span: int = _cycles_to_overload() * MachineRuntime.CORE_PERIOD_TICKS

	var affordable: int = _abilities_to_overload() - 1
	var lean: MachineRuntime = _machine(_chain(affordable))
	_tick(lean, _shot_tick(1) + span)
	ctx.equal(_started.size(), 0, "%d 发能力卡不该过载（每周期扣 %d、回 %d）" % [affordable,
		affordable * int(MachineRuntime.MANA_PER_CAST),
		MachineRuntime.CORE_PERIOD_TICKS * int(MachineRuntime.MANA_REGEN_PER_TICK)])
	ctx.check(lean.mana() > 0.0, "养得动的书魔力应始终有余额（实际 %.1f）" % lean.mana())

	var strained: MachineRuntime = _machine(_chain(_abilities_to_overload()))
	_tick(strained, _shot_tick(1) + span)
	ctx.check(strained.is_overloaded(),
		"同样跑 %d 拍，多发一封就该透支" % (_shot_tick(1) + span))


## 「没有能力卡 / 没有核心卡 / 没有法术书」是玩家的正常状态（一次都没进过整备），不是异常：
## 魔力恒满，且永不判定过载。
func _run_degenerate_checks(ctx: RefCounted) -> void:
	ctx.begin_case("边界 · 没有能力卡 / 没有核心卡 / 没有法术书时永不过载")
	var bare: MachineRuntime = _machine(_graph([{"id": "core", "kind": NodeData.Kind.CORE}], []))
	_tick(bare, 4 * _abilities_to_overload() * MachineRuntime.CORE_PERIOD_TICKS)
	ctx.equal(bare.mana(), MachineRuntime.MANA_MAX, "有核心卡但没有能力卡时魔力应恒为满")
	ctx.check(not bare.is_overloaded(), "没有能力卡时不得过载")
	ctx.equal(_started.size(), 0, "没有能力卡时不得广播 overload_started")

	var orphan: MachineRuntime = _machine(_graph([{"id": "spell0", "kind": NodeData.Kind.ABILITY}], []))
	_tick(orphan, 200)
	ctx.equal(orphan.mana(), MachineRuntime.MANA_MAX, "有能力卡但没有核心卡时魔力应恒为满")
	ctx.check(not orphan.is_overloaded(), "没有核心卡时不得过载")
	ctx.equal(orphan.has_core(), false, "这台书里没有核心卡")

	var nothing: MachineRuntime = _machine(null)
	_tick(nothing, 200)
	ctx.equal(nothing.mana(), MachineRuntime.MANA_MAX, "null 法术书不得消耗魔力")
	ctx.check(not nothing.is_overloaded(), "null 法术书空转不得过载")
	ctx.equal(nothing.has_core(), false, "null 法术书里没有核心卡")


## 一台「核心卡 → n 张能力卡」的书（能力卡直接挂在源上，每条一条边）：
## 每 CORE 周期发 n 次，净收支由 n 定。n = 0 时退化成只有核心卡（用来钉「停手就回魔」）。
func _chain(count: int) -> BlueprintData:
	var spec: Array[Dictionary] = [{"id": "core", "kind": NodeData.Kind.CORE}]
	var links: Array[Dictionary] = []
	for index: int in count:
		var ability_id: String = "spell%d" % index
		spec.append({"id": ability_id, "kind": NodeData.Kind.ABILITY})
		links.append({"from": "core", "to": ability_id})
	return _graph(spec, links)


## 第 index 发（从 1 起）的绝对拍号。所有能力卡都直接挂在核心卡上（一条边），故与发数无关。
func _shot_tick(index: int) -> int:
	return MachineRuntime.CORE_PERIOD_TICKS + MachineRuntime.TRAVEL_TICKS \
		+ (index - 1) * MachineRuntime.CORE_PERIOD_TICKS


## 一个 CORE 周期里，多发一张能力卡的净透支。
## **必须按浮点算**：回魔是每拍 2.5，先 int() 再乘周期数会把它截成 2，
## 净透支于是从 11 变成 16 —— 用例跟着一起错，而错法是「还是绿的」。
func _deficit_per_cycle() -> float:
	return _abilities_to_overload() * MachineRuntime.MANA_PER_CAST \
		- MachineRuntime.CORE_PERIOD_TICKS * MachineRuntime.MANA_REGEN_PER_TICK


## 第一轮能力卡打完之后，还要几个 CORE 周期才见底。
func _cycles_to_overload() -> int:
	return int(ceilf((MachineRuntime.MANA_MAX - _abilities_to_overload() * MachineRuntime.MANA_PER_CAST)
		/ _deficit_per_cycle()))


## 从满魔起，第几拍见底。由两个常数算出，不写死 ——
## 手写的拍号会随 MANA_PER_CAST / MANA_REGEN_PER_TICK 的改动静默过期，
## 而过期的方式是「用例还是绿的」，正是最坏的一种。
func _overload_tick() -> int:
	return _shot_tick(1) + _cycles_to_overload() * MachineRuntime.CORE_PERIOD_TICKS


## 要让魔力见底，一台核心卡最多养得起几发能力卡。同样由常数算出 ——
## 「一源养两发」是 MANA_PER_CAST / MANA_REGEN_PER_TICK 的函数，不是一条独立设定。
func _abilities_to_overload() -> int:
	return int(MachineRuntime.CORE_PERIOD_TICKS * MachineRuntime.MANA_REGEN_PER_TICK \
		/ MachineRuntime.MANA_PER_CAST) + 1


## 见底之后要回几拍才满。
func _regen_ticks() -> int:
	return int(ceilf(MachineRuntime.MANA_MAX / MachineRuntime.MANA_REGEN_PER_TICK))


## 建运行时并挂上探针。
func _machine(blueprint: BlueprintData) -> MachineRuntime:
	_fired.clear()
	_started.clear()
	_ended.clear()
	_mana_log.clear()
	var runtime := MachineRuntime.new(blueprint)
	_watched = runtime
	runtime.ability_cast.connect(_on_fired)
	runtime.overload_started.connect(_on_overload_started)
	runtime.overload_ended.connect(_on_overload_ended)
	runtime.mana_changed.connect(_on_mana)
	return runtime


func _on_fired(_ability_id: StringName) -> void:
	_fired.append(_watched.tick_index())


func _on_overload_started() -> void:
	_started.append(_watched.tick_index())


func _on_overload_ended() -> void:
	_ended.append(_watched.tick_index())


func _on_mana(mana: float) -> void:
	_mana_log.append(mana)


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
