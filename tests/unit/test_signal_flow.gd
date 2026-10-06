## test_signal_flow.gd
## 职责：机器运行的**纯逻辑**（FIRST PLAYABLE 2/4）—— CORE 固定节拍、脉冲沿有向边传播、
##       功能卡三件（子弹数量 / 附魔 / 冷却）、能力卡施放与魔力扣减，
##       外加确定性、环路、悬空边、断开子图这些边界（03 §4 / §6、09 §3.3）。
## 所属系统：tests
## 依赖：test_context, scripts/gameplay/{machine_runtime,signal_pulse}.gd,
##       scripts/data/{node_data,connection_data,blueprint_data}.gd, scripts/ui/blueprint_workspace.gd
## 禁止：本文件不得入树、不得碰真实时间 —— 全部在内存里手摇 tick()（09 §4：仿真若依赖真实时间，
##       同一份蓝图在不同机器上会跑出不同结果，用例本身就不可复现）；
##       不得落进 BlueprintData.DEFAULT_SAVE_DIR（同 test_blueprint_data.gd —— 正式存档目录只归玩家的游戏写）。
##
## 真实渲染、真实节拍驱动（MachineDriver 的 _process）与截图取证归 tests/integration/signal_flow_smoke.gd
## **独立进程** —— 本文件证明「算得对」，那边证明「画出来了」。

extends RefCounted

const RUNTIME_PATH: String = "res://scripts/gameplay/machine_runtime.gd"
const DRIVER_PATH: String = "res://scripts/gameplay/machine_driver.gd"
const WORKSPACE_PATH: String = "res://scripts/ui/blueprint_workspace.gd"
const COMBAT_SCENE_PATH: String = "res://scenes/combat/combat.tscn"

## 测试专用落盘目录，与正式存档目录刻意分开。
const SAVE_DIR: String = "user://test_blueprints"
const SAVE_PATH: String = SAVE_DIR + "/_flow_01.tres"

## 03 §6：仿真里不得有随机源；03 §2：不得有自动时间源。
## MachineDriver 是**唯一**允许带 _process 的文件（它就是把帧时间换成节拍的那一层），故它不在扫描之列。
const DETERMINISM_BANNED: PackedStringArray = [
	"randi", "randf", "RandomNumberGenerator", "_process", "_physics_process", "Timer", "create_timer",
]

## 用户 2026-10-06 给功能卡列的八类。本文件独立复写，不从实现里取 ——
## 从实现里取的话，枚举被改窄了这条还是绿的。**前四个必须原地不动**（旧存档落的是整数）。
const EXPECTED_FUNCTIONS: PackedStringArray = ["NONE", "BULLET_COUNT", "ENCHANT", "COOLDOWN",
	"HASTE", "SLOW", "BURST", "LOOP", "ATTACK_SPEED"]

var _activations: Array[StringName] = []
var _fired: Array[StringName] = []
var _fire_ticks: Array[int] = []
var _mana_log: Array[float] = []
var _watched: MachineRuntime = null


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_cleanup()
	_run_enum_checks(ctx)
	_run_source_checks(ctx)
	_run_core_beat_checks(ctx)
	_run_travel_checks(ctx)
	_run_split_checks(ctx)
	_run_amplify_checks(ctx)
	_run_delay_checks(ctx)
	_run_ability_cast_checks(ctx)
	_run_degenerate_checks(ctx)
	_run_cycle_checks(ctx)
	_run_determinism_checks(ctx)
	_run_readonly_checks(ctx)
	_run_warehouse_checks(ctx)
	_run_persistence_checks(ctx)
	_run_assembly_checks(ctx)
	_cleanup()


## 03 §4.1 的「中间处理」四类。NONE 必须排第一并作缺省：缺省走直通，不猜一种运算。
func _run_enum_checks(ctx: RefCounted) -> void:
	ctx.begin_case("NodeData · Function 枚举与缺省行为")
	ctx.equal(NodeData.Function.size(), EXPECTED_FUNCTIONS.size(), "Function 成员数")
	for index: int in EXPECTED_FUNCTIONS.size():
		ctx.check(NodeData.Function.has(EXPECTED_FUNCTIONS[index]),
			"Function 应含成员 %s" % EXPECTED_FUNCTIONS[index])
	ctx.equal(int(NodeData.Function.NONE), 0, "NONE 的枚举值（缺省值必须排在第一位）")
	# 旧存档里有行为的只有前三件，它们的整数落盘值必须一动不动。
	ctx.equal(int(NodeData.Function.BULLET_COUNT), 1, "BULLET_COUNT 的枚举值（旧 SPLIT）")
	ctx.equal(int(NodeData.Function.ENCHANT), 2, "ENCHANT 的枚举值（旧 AMPLIFY）")
	ctx.equal(int(NodeData.Function.COOLDOWN), 3, "COOLDOWN 的枚举值（旧 DELAY）")
	# 反向对照：三个行为两两不同，否则「拖的是冷却、跑出来是附魔」这种错没有任何断言能发现。
	ctx.not_equal(NodeData.Function.BULLET_COUNT, NodeData.Function.ENCHANT, "前两件不得同值")
	ctx.not_equal(NodeData.Function.ENCHANT, NodeData.Function.COOLDOWN, "后两件不得同值")
	ctx.not_equal(NodeData.Function.BULLET_COUNT, NodeData.Function.COOLDOWN, "首尾两件不得同值")
	var node: NodeData = NodeData.new()
	ctx.equal(node.function_kind, NodeData.Function.NONE, "缺省行为应是直通")
	ctx.equal(node.kind, NodeData.Kind.FUNCTION, "只设 function_kind 不得顺带改 kind")


## 03 §6 / §2 的静态纪律，顺带把「视图不推仿真」这条方向钉住。
func _run_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("机器运行 · 静态纪律（03 §6 确定性 / 视图只读）")
	var runtime_source: String = FileAccess.get_file_as_string(RUNTIME_PATH)
	if not ctx.check(not runtime_source.is_empty(), "%s 应能读取" % RUNTIME_PATH):
		return
	var runtime_code: String = _strip_comments(runtime_source)
	for token: String in DETERMINISM_BANNED:
		ctx.check(not runtime_code.contains(token),
			"MachineRuntime 的代码中不得出现 `%s`（仿真不得有随机源或自动时间源）" % token)
	# 节拍必须真的有人给：MachineDriver 是唯一允许带 _process 的文件，且它必须真的带。
	var driver_code: String = _strip_comments(FileAccess.get_file_as_string(DRIVER_PATH))
	ctx.check(driver_code.contains("_process"), "MachineDriver 应自己带 _process（帧时间 → 固定节拍那一层）")
	ctx.check(not driver_code.contains("create_timer"),
		"MachineDriver 不得用定时器代替固定步长累加器（03 §2）")
	# 反向对照：一旦有人把 tick() 挪进绘制路径，「画得对不对」就会反过来影响「跑得对不对」。
	var view_code: String = _strip_comments(FileAccess.get_file_as_string(WORKSPACE_PATH))
	ctx.check(not view_code.contains(".tick()"), "blueprint_workspace.gd 不得调用 tick()（视图不推仿真）")
	ctx.check(not view_code.contains("_process"), "blueprint_workspace.gd 不得有 _process（03 §2）")


## CORE 按固定节拍自发脉冲，且**节拍之前一拍都不发**。
func _run_core_beat_checks(ctx: RefCounted) -> void:
	ctx.begin_case("CORE · 固定节拍发脉冲（03 §2：CORE 由 tick 驱动）")
	var runtime: MachineRuntime = _machine(_chain([]))
	ctx.check(runtime.has_core(), "含 CORE 的机器应报告 has_core")
	ctx.equal(runtime.tick_index(), 0, "新建的机器应停在 0 拍")

	# 反向对照：CORE_PERIOD_TICKS 若被改成 1，第 1 拍就会看见脉冲，下面整段立刻转红。
	_tick(runtime, MachineRuntime.CORE_PERIOD_TICKS - 1)
	ctx.equal(runtime.pulses().size(), 0, "满一拍之前不得有在途脉冲")
	ctx.equal(_activations.size(), 0, "满一拍之前不得点亮任何节点")
	ctx.equal(runtime.mana(), MachineRuntime.MANA_MAX, "还没施放，魔力应为满（资源线见 test_mana.gd）")

	runtime.tick()
	var beat: int = MachineRuntime.CORE_PERIOD_TICKS
	ctx.equal(runtime.tick_index(), beat, "第 %d 拍" % beat)
	ctx.equal(runtime.pulses().size(), 1, "CORE 应在第 %d 拍发出第一枚脉冲" % beat)
	ctx.equal(_activations.size(), 1, "CORE 自己应被点亮一次（信号源也要有可见反馈）")
	ctx.equal(String(_activations[0]), "core", "最先被点亮的应是 CORE")

	var pulse: SignalPulse = runtime.pulses()[0]
	ctx.equal(String(pulse.from_node_id), "core", "脉冲的起点")
	ctx.equal(String(pulse.to_node_id), "needle", "脉冲的终点")
	ctx.equal(pulse.value, MachineRuntime.BASE_PULSE_VALUE, "CORE 发出的脉冲初值")
	# 反向对照：tick() 里那行快照若被删掉，新生脉冲会在同一拍被减一次，进度立刻不是 0。
	ctx.check(is_zero_approx(pulse.progress()), "刚发出的脉冲进度应为 0（本拍不得推进它）")


## 一条边恰走 TRAVEL_TICKS 拍 —— 不多不少。
func _run_travel_checks(ctx: RefCounted) -> void:
	ctx.begin_case("传播 · 一条边恰走 TRAVEL_TICKS 拍（03 §2 的固定步长）")
	var runtime: MachineRuntime = _machine(_chain([]))
	var travel: int = MachineRuntime.TRAVEL_TICKS
	_tick(runtime, MachineRuntime.CORE_PERIOD_TICKS + travel - 1)
	ctx.equal(runtime.pulses().size(), 1, "走满 %d 拍时脉冲应仍在途" % (travel - 1))
	ctx.equal(_count_fired("needle"), 0, "此时武器不该开火")

	runtime.tick()
	ctx.equal(runtime.pulses().size(), 0, "走满 %d 拍应抵达并从在途列表移除" % travel)
	ctx.equal(_count_fired("needle"), 1, "抵达的**当拍**武器就应开火")
	ctx.equal(_count_activated("needle"), 1, "终点节点应被点亮一次")


## 「1 进 → 2 出」是**连线的形状**：出边有几条就发几枚，值既不复制也不切分。
func _run_split_checks(ctx: RefCounted) -> void:
	ctx.begin_case("FUNCTION · 子弹数量：出边几条就发几枚（03 §4.2）")
	var runtime: MachineRuntime = _machine(_graph([
		{"id": "core", "kind": NodeData.Kind.CORE},
		{"id": "split", "function": NodeData.Function.BULLET_COUNT},
		{"id": "needle_a", "kind": NodeData.Kind.ABILITY},
		{"id": "needle_b", "kind": NodeData.Kind.ABILITY},
	], [
		{"from": "core", "to": "split"},
		{"from": "split", "to": "needle_a"},
		{"from": "split", "to": "needle_b"},
	]))
	var arrival: int = MachineRuntime.CORE_PERIOD_TICKS + MachineRuntime.TRAVEL_TICKS
	_tick(runtime, arrival)
	ctx.equal(_count_activated("split"), 1, "子弹数量节点应被点亮一次")
	ctx.equal(runtime.pulses().size(), 2, "两条出边应各发一枚")
	ctx.equal(_count_fired("needle_a") + _count_fired("needle_b"), 0, "此时两把武器都还没收到")
	for pulse: SignalPulse in runtime.pulses():
		# 反向对照：子弹数量若被实现成「把值切成两半」，这里会读到 0.5。
		ctx.equal(pulse.value, MachineRuntime.BASE_PULSE_VALUE, "子弹数量不得改动信号值")

	_tick(runtime, MachineRuntime.TRAVEL_TICKS)
	ctx.equal(_count_fired("needle_a"), 1, "第一把武器应收到一枚")
	ctx.equal(_count_fired("needle_b"), 1, "第二把武器应收到一枚")

	# 反向对照：同一个子弹数量节点只接一条出边时**只有一枚** ——
	# 若「子弹数量」被实现成节点自带的复制，这一条会读到 2。
	var one: MachineRuntime = _machine(_graph([
		{"id": "core", "kind": NodeData.Kind.CORE},
		{"id": "split", "function": NodeData.Function.BULLET_COUNT},
		{"id": "needle", "kind": NodeData.Kind.ABILITY},
	], [
		{"from": "core", "to": "split"},
		{"from": "split", "to": "needle"},
	]))
	_tick(one, arrival + MachineRuntime.TRAVEL_TICKS)
	ctx.equal(_count_fired("needle"), 1, "只接一条出边的子弹数量只发一枚（它是连线的形状）")


## 附魔：固定倍数放大脉冲值。
func _run_amplify_checks(ctx: RefCounted) -> void:
	ctx.begin_case("FUNCTION · 放大：固定倍数（本卡用常数，不自造公式）")
	ctx.check(MachineRuntime.ENCHANT_FACTOR > 1.0,
		"放大倍数必须 > 1，否则「放大」是句空话（实际 %.2f）" % MachineRuntime.ENCHANT_FACTOR)
	var runtime: MachineRuntime = _machine(_chain([{"id": "amp", "function": NodeData.Function.ENCHANT}]))
	var arrival: int = MachineRuntime.CORE_PERIOD_TICKS + MachineRuntime.TRAVEL_TICKS
	_tick(runtime, arrival)
	ctx.equal(runtime.pulses().size(), 1, "放大节点应在抵达当拍转发一枚")
	var pulse: SignalPulse = runtime.pulses()[0]
	ctx.equal(String(pulse.from_node_id), "amp", "转发后的起点应是放大节点")
	ctx.equal(pulse.value, MachineRuntime.BASE_PULSE_VALUE * MachineRuntime.ENCHANT_FACTOR, "放大后的信号值")

	# 反向对照：同一个位置放一个「未指定行为」的 FUNCTION，值必须原样通过。
	var plain: MachineRuntime = _machine(_chain([]))
	_tick(plain, arrival)
	ctx.equal(plain.pulses()[0].value, MachineRuntime.BASE_PULSE_VALUE, "未指定行为的节点应原样转发")


## 冷却：滞留 COOLDOWN_TICKS 拍后才放行。反向对照是「没有冷却的链路早该施放了」。
func _run_delay_checks(ctx: RefCounted) -> void:
	ctx.begin_case("FUNCTION · 冷却：滞留 COOLDOWN_TICKS 拍（03 §2 的节拍计数）")
	var runtime: MachineRuntime = _machine(_chain([{"id": "delay", "function": NodeData.Function.COOLDOWN}]))
	var arrival: int = MachineRuntime.CORE_PERIOD_TICKS + MachineRuntime.TRAVEL_TICKS
	var release: int = arrival + MachineRuntime.COOLDOWN_TICKS
	_tick(runtime, arrival)
	ctx.equal(_count_activated("delay"), 1, "冷却节点应在抵达当拍被点亮")
	ctx.equal(runtime.pulses().size(), 0, "被冷却节点收下的脉冲不在途，故不该出现在画面上")

	# 反向对照：不带冷却的链路在第 10 + 4 × 2 = 18 拍就已经施放了，
	# 这条在 18 / 25 拍都要求「还没施放」—— 冷却若没生效，两次都会转红。
	_tick(runtime, MachineRuntime.TRAVEL_TICKS)
	ctx.equal(_count_fired("needle"), 0, "第 %d 拍时带冷却的链路还不该施放" % (arrival + MachineRuntime.TRAVEL_TICKS))
	_tick(runtime, release - 1 - runtime.tick_index())
	ctx.equal(runtime.tick_index(), release - 1, "推进到放行前一拍")
	ctx.equal(_count_fired("needle"), 0, "第 %d 拍（放行前一拍）仍不该开火" % (release - 1))

	# CORE 每 10 拍发一次，滞留 12 拍意味着冷却节点手里可能同时压着两枚 —— 故这里比的是**增量**
	# 而不是总数：总数取决于「这几拍里又到了几枚」，那与「放行是否点亮了自己」是两件事。
	var before: int = _count_activated("delay")
	runtime.tick()
	ctx.equal(runtime.tick_index(), release, "第 %d 拍" % release)
	ctx.equal(runtime.pulses().size(), 1, "第 %d 拍冷却节点应放行一枚" % release)
	ctx.equal(_count_activated("delay"), before + 1, "放行当拍冷却节点应再被点亮一次（放行也是可见事件）")

	_tick(runtime, MachineRuntime.TRAVEL_TICKS)
	ctx.equal(_count_fired("needle"), 1, "放行后再走满 %d 拍应抵达并开火" % MachineRuntime.TRAVEL_TICKS)


## 能力卡施放 → 扣魔力；顺带钉住点亮 / 弹丸两个时间窗口，以及整条链路端到端的拍号。
##
## **热累积那半条已随 Heat→Mana 一起搬走**：旧机制「开火攒热、攒满被罚停」在单张能力卡下
## 就能自证（50 发攒到 100），新机制是**资源**，单张能力卡永远攒不到过载 ——
## 「施法扣魔力 / 停手回魔力 / 见底过载 / 回满恢复」这四条现在整条归 tests/unit/test_mana.gd
## （那里有反向对照：两张养得动、三张才透支）。本文件只留它自己那一份职责：
## 施放发生没发生、什么时候发生、广播的值域对不对。
##
## 之所以不把这几条也搬过去：它们量的是**这条链路的拍号**，而链路由本文件的三个功能卡用例定义。
func _run_ability_cast_checks(ctx: RefCounted) -> void:
	ctx.begin_case("ABILITY · 施放扣魔力与点亮 / 弹丸时间窗（06 §8.1 的 `魔力` 读数）")
	# core → 子弹数量 → 附魔 → needle。三条边各走 TRAVEL_TICKS 拍，
	# 故首发的绝对拍号是 10 + 3 × 4 = 22 —— 这条把整条链路钉在一起：
	# 节拍、传播、功能卡的转发、能力卡的施放，任何一环改了时长这里都会转红。
	var runtime: MachineRuntime = _machine(_chain([
		{"id": "split", "function": NodeData.Function.BULLET_COUNT},
		{"id": "amp", "function": NodeData.Function.ENCHANT},
	]))
	var first: int = MachineRuntime.CORE_PERIOD_TICKS + 3 * MachineRuntime.TRAVEL_TICKS
	_tick(runtime, first)
	ctx.equal(_fire_ticks.size(), 1, "第 %d 拍应恰好施放一次" % first)
	ctx.equal(_fire_ticks[0], first, "首发的拍号（CORE 节拍 + 三条边各 %d 拍）" % MachineRuntime.TRAVEL_TICKS)
	ctx.equal(runtime.mana(), MachineRuntime.MANA_MAX - MachineRuntime.MANA_PER_CAST, "一发之后的魔力")
	ctx.equal(_mana_log.size(), 1, "魔力变化应广播一次")
	ctx.equal(runtime.shot_age(&"needle"), 0, "刚施放时弹丸年龄应为 0")
	ctx.check(runtime.is_lit(&"needle"), "刚施放的节点应处于点亮窗口内")
	ctx.equal(runtime.shot_age(&"core"), -1, "CORE 不是能力卡，弹丸年龄应为 -1")
	ctx.equal(runtime.is_lit(&"ghost"), false, "不存在的节点不得被报告为点亮")

	# 点亮窗口 FLASH_TICKS 与弹丸存活期 SHOT_TICKS —— 边界各钉一次。
	_tick(runtime, MachineRuntime.FLASH_TICKS - 1)
	ctx.check(runtime.is_lit(&"needle"), "点亮窗口内的最后一拍仍应算点亮")
	ctx.equal(runtime.shot_age(&"needle"), MachineRuntime.FLASH_TICKS - 1, "弹丸年龄")
	runtime.tick()
	ctx.check(not runtime.is_lit(&"needle"), "越过点亮窗口的那一拍应不再点亮")
	_tick(runtime, MachineRuntime.SHOT_TICKS - MachineRuntime.FLASH_TICKS - 1)
	ctx.equal(runtime.shot_age(&"needle"), MachineRuntime.SHOT_TICKS - 1, "弹丸存活期的最后一拍")
	runtime.tick()
	ctx.equal(runtime.shot_age(&"needle"), -1, "越过存活期后弹丸应消失")

	# 第二发：魔力广播的是**绝对值**（扣完剩多少），不是每发一条增量。
	# 这张书只有一张能力卡，一个周期净 +1（回 25、扣 12 × 1），故第二发之前魔力已经回满 ——
	# 广播里出现的正是「满值」与「满值 - 一发」，这与 test_mana.gd 的收支结论是同一条。
	var second: int = first + MachineRuntime.CORE_PERIOD_TICKS
	_tick(runtime, second - runtime.tick_index())
	ctx.equal(_fire_ticks.size(), 2, "第二个 CORE 节拍应带来第二发")
	ctx.equal(_fire_ticks[1], second, "第二发的拍号")
	ctx.equal(runtime.mana(), MachineRuntime.MANA_MAX - MachineRuntime.MANA_PER_CAST, "第二发之后的魔力")

	# 值域：读数是百分比，任何一次广播越界都会印成四位数或负数。
	var peak: float = 0.0
	var lowest: float = MachineRuntime.MANA_MAX
	var overflow: bool = false
	for value: float in _mana_log:
		peak = maxf(peak, value)
		lowest = minf(lowest, value)
		if value < 0.0 or value > MachineRuntime.MANA_MAX:
			overflow = true
	ctx.check(not overflow,
		"魔力的每次广播都应落在 [0, MANA_MAX]（读数格只有三位，共 %d 次）" % _mana_log.size())
	ctx.equal(lowest, MachineRuntime.MANA_MAX - MachineRuntime.MANA_PER_CAST,
		"广播的最小值应是扣掉一发之后的量")
	# 单张能力卡永远不过载 —— 过载是「能力卡太多」的代价，不是施放的代价。
	ctx.check(not runtime.is_overloaded(), "一张能力卡的书不该过载")


## 退化输入一律不崩、不产生事件 —— 「没有机器」是玩家的正常状态，不是异常。
func _run_degenerate_checks(ctx: RefCounted) -> void:
	ctx.begin_case("边界 · 空 / 缺 CORE / 悬空边 / 断开子图（09 §3.3）")
	var nothing: MachineRuntime = _machine(null)
	ctx.equal(nothing.has_core(), false, "null 蓝图不得报告 has_core")
	_tick(nothing, 30)
	ctx.equal(nothing.tick_index(), 30, "null 蓝图应能空转")
	ctx.equal(nothing.pulses().size(), 0, "null 蓝图不得产生脉冲")
	ctx.equal(_activations.size(), 0, "null 蓝图不得点亮任何节点")

	var empty: MachineRuntime = _machine(BlueprintData.new())
	_tick(empty, 30)
	ctx.equal(empty.pulses().size(), 0, "空蓝图不得产生脉冲")
	ctx.equal(empty.has_core(), false, "空蓝图不得报告 has_core")

	# 有武器但没信号源：机器一步都不动。这正是玩家「忘了拖 CORE」时看到的样子。
	var no_core: BlueprintData = BlueprintData.new()
	_node(no_core, "needle", NodeData.Kind.ABILITY)
	var orphan: MachineRuntime = _machine(no_core)
	_tick(orphan, 30)
	ctx.equal(_count_activated("needle"), 0, "没有 CORE 时武器不该被点亮")

	# 悬空边：终点节点不存在。脉冲要能抵达（点亮那个 id）而不崩。
	var dangling: MachineRuntime = _machine(_graph(
		[{"id": "core", "kind": NodeData.Kind.CORE}],
		[{"from": "core", "to": "ghost"}]))
	_tick(dangling, MachineRuntime.CORE_PERIOD_TICKS + MachineRuntime.TRAVEL_TICKS)
	ctx.equal(_count_activated("ghost"), 1, "悬空边的终点应被点亮（信号确实走到了那里）")
	ctx.equal(dangling.pulses().size(), 0, "悬空边不得再往下转发")

	# 断开子图（09 §3.3）：没接上 CORE 的那一支不参与执行。
	var split_runtime: MachineRuntime = _machine(_graph([
		{"id": "core", "kind": NodeData.Kind.CORE},
		{"id": "split", "function": NodeData.Function.BULLET_COUNT},
		{"id": "needle_a", "kind": NodeData.Kind.ABILITY},
		{"id": "needle_b", "kind": NodeData.Kind.ABILITY},
	], [
		{"from": "core", "to": "split"},
		{"from": "split", "to": "needle_a"},
	]))
	var first: int = MachineRuntime.CORE_PERIOD_TICKS + 3 * MachineRuntime.TRAVEL_TICKS
	_tick(split_runtime, first)
	ctx.equal(_count_fired("needle_a"), 1, "接上的那一支应开火")
	ctx.equal(_count_fired("needle_b"), 0, "断开的子图不得参与执行")


## 环路：本卡不做环路检测（属 S2-06），但仿真**绝不能因此挂死**。
func _run_cycle_checks(ctx: RefCounted) -> void:
	ctx.begin_case("边界 · 环路不死循环（03 §4.2：环路检测属 S2-06，本卡只保证不挂）")
	var runtime: MachineRuntime = _machine(_graph([
		{"id": "core", "kind": NodeData.Kind.CORE},
		{"id": "a"},
		{"id": "b"},
	], [
		{"from": "core", "to": "a"},
		{"from": "a", "to": "b"},
		{"from": "b", "to": "a"},
	]))
	_tick(runtime, 100)
	ctx.equal(runtime.tick_index(), 100, "带环路的机器应能在有限时间内走完 100 拍")
	# 每拍发出的脉冲都在环上转：数量随节拍线性增长而不发散，上界就是已发出的脉冲总数。
	ctx.check(runtime.pulses().size() > 0, "环路上的脉冲应确实在转（否则下面那条有界断言无意义）")
	ctx.check(runtime.pulses().size() <= 10,
		"环路上的在途脉冲数应有界（实际 %d 枚）" % runtime.pulses().size())


## 03 §6：同一份蓝图必须跑出同一串结果。反向对照是**连线顺序不同**的同一张图 ——
## 若比较没有判别力（比如只比脉冲数），那一条不会转红。
func _run_determinism_checks(ctx: RefCounted) -> void:
	ctx.begin_case("确定性 · 同图同结果（03 §6：无随机、无真实时间）")
	var spec: Array[Dictionary] = [
		{"id": "core", "kind": NodeData.Kind.CORE},
		{"id": "split", "function": NodeData.Function.BULLET_COUNT},
		{"id": "amp", "function": NodeData.Function.ENCHANT},
		{"id": "needle_a", "kind": NodeData.Kind.ABILITY},
		{"id": "needle_b", "kind": NodeData.Kind.ABILITY},
	]
	var forward: Array[Dictionary] = [
		{"from": "core", "to": "split"},
		{"from": "split", "to": "amp"},
		{"from": "split", "to": "needle_b"},
		{"from": "amp", "to": "needle_a"},
	]
	var first: String = _trace(_machine(_graph(spec, forward)), 200)
	ctx.check(first.length() > 0, "轨迹不该是空的（否则下面的相等是句空话）")
	ctx.equal(_trace(_machine(_graph(spec, forward)), 200), first,
		"同一张图跑两遍应得到逐拍完全相同的轨迹")

	# 拓扑不变、只把两条出边的先后对调：同拍内两枚脉冲的次序随之不同。
	var swapped: Array[Dictionary] = [
		{"from": "core", "to": "split"},
		{"from": "split", "to": "needle_b"},
		{"from": "split", "to": "amp"},
		{"from": "amp", "to": "needle_a"},
	]
	ctx.not_equal(_trace(_machine(_graph(spec, swapped)), 200), first,
		"出边顺序不同的图应跑出不同的轨迹（证明上面的比较确实有判别力）")


## 视图拿到的是只读副本：改它不得改到仿真状态。
func _run_readonly_checks(ctx: RefCounted) -> void:
	ctx.begin_case("只读访问 · pulses() 交出的必须是副本")
	var runtime: MachineRuntime = _machine(_chain([]))
	_tick(runtime, MachineRuntime.CORE_PERIOD_TICKS)
	ctx.equal(runtime.pulses().size(), 1, "先确认确实有在途脉冲")
	var copy: Array[SignalPulse] = runtime.pulses()
	copy.clear()
	ctx.equal(runtime.pulses().size(), 1, "清空拿到的数组不得影响仿真（交出的必须是副本）")


## 仓库清单里三个功能卡槽位各带一种行为。没有这一列，玩家拖出来的「冷却」重进场景就退化成直通。
func _run_warehouse_checks(ctx: RefCounted) -> void:
	ctx.begin_case("仓库清单 · 功能卡三件各带行为（2/4 新增列）")
	var expected := {
		"子弹数量": NodeData.Function.BULLET_COUNT,
		"附魔": NodeData.Function.ENCHANT,
		"冷却": NodeData.Function.COOLDOWN,
	}
	var list: Array[Dictionary] = BlueprintWorkspace.WAREHOUSE
	var carriers: int = 0
	var seen: PackedStringArray = []
	for index: int in list.size():
		var entry: Dictionary = list[index]
		var entry_name: String = String(entry["name"])
		if not ctx.check(entry.has("function_kind"), "槽位「%s」应带 function_kind" % entry_name):
			continue
		var behavior: int = int(entry["function_kind"])
		if expected.has(entry_name):
			seen.append(entry_name)
			ctx.equal(behavior, int(expected[entry_name]), "「%s」应带的行为" % entry_name)
		else:
			ctx.equal(behavior, int(NodeData.Function.NONE),
				"「%s」不是本卡三件之一，行为应为 NONE" % entry_name)
		if behavior != int(NodeData.Function.NONE):
			carriers += 1
	for want: String in expected:
		ctx.check(seen.has(want), "仓库应有「%s」槽位" % want)
	# 反向对照：数量对不上就说明有槽位被悄悄改成了 NONE（或凭空多了一个带行为的）。
	ctx.equal(carriers, expected.size(), "恰好 %d 个槽位带行为" % expected.size())


## 09 §3.2：function_kind 必须真的落盘并原样载回。
## 反向对照：它若没标 @export，载回后一律是 NONE，下面几条会同时转红。
func _run_persistence_checks(ctx: RefCounted) -> void:
	ctx.begin_case("落盘往返 · function_kind 存活（09 §3.2）")
	var blueprint: BlueprintData = BlueprintData.new()
	_node(blueprint, "core", NodeData.Kind.CORE)
	_node(blueprint, "split", NodeData.Kind.FUNCTION, NodeData.Function.BULLET_COUNT)
	_node(blueprint, "amp", NodeData.Kind.FUNCTION, NodeData.Function.ENCHANT)
	_node(blueprint, "delay", NodeData.Kind.FUNCTION, NodeData.Function.COOLDOWN)
	_node(blueprint, "needle", NodeData.Kind.ABILITY)
	_link(blueprint, "core", "split")
	_link(blueprint, "split", "amp")
	_link(blueprint, "amp", "delay")
	_link(blueprint, "delay", "needle")
	if not ctx.check(blueprint.save_to(SAVE_PATH), "测试蓝图应能写入 %s" % SAVE_PATH):
		return

	var loaded: BlueprintData = BlueprintData.load_from(SAVE_PATH)
	if not ctx.check(loaded != null, "载回的蓝图不应为 null"):
		return
	ctx.equal(loaded.nodes.size(), 5, "载回的节点数")
	ctx.equal(loaded.connections.size(), 4, "载回的连线数")
	var kinds: Dictionary = {}
	for node: NodeData in loaded.nodes:
		kinds[String(node.id)] = int(node.function_kind)
	ctx.equal(int(kinds.get("split", -1)), int(NodeData.Function.BULLET_COUNT), "载回后「子弹数量」的行为")
	ctx.equal(int(kinds.get("amp", -1)), int(NodeData.Function.ENCHANT), "载回后「附魔」的行为")
	ctx.equal(int(kinds.get("delay", -1)), int(NodeData.Function.COOLDOWN), "载回后「冷却」的行为")
	ctx.equal(int(kinds.get("core", -1)), int(NodeData.Function.NONE), "载回后 CORE 的行为")
	# 载回的图要能直接跑起来 —— 存档的价值就在于此。
	# 路径是 core→split→amp→delay→needle：CORE 节拍 10 + 四条边各 TRAVEL_TICKS + 滞留 COOLDOWN_TICKS。
	var fire_tick: int = MachineRuntime.CORE_PERIOD_TICKS + 4 * MachineRuntime.TRAVEL_TICKS \
		+ MachineRuntime.COOLDOWN_TICKS
	var runtime: MachineRuntime = _machine(loaded)
	_tick(runtime, fire_tick)
	ctx.check(_count_fired("needle") > 0, "载回的图应能直接跑出开火（第 %d 拍）" % fire_tick)


## 装配：COMBAT 的机器视图 + 节拍器；外加只读视图**不接拖放**这条新纪律。
func _run_assembly_checks(ctx: RefCounted) -> void:
	ctx.begin_case("COMBAT · 机器视图与节拍器的装配（06 §8）")
	var packed: PackedScene = load(COMBAT_SCENE_PATH)
	if not ctx.check(packed is PackedScene, "combat.tscn 应能加载为 PackedScene"):
		return
	var scene: Node = packed.instantiate()
	if not ctx.check(scene != null, "combat.tscn 应能实例化"):
		return
	var view: Control = _find(scene, "MachineView") as Control
	var battlefield: Control = _find(scene, "Battlefield") as Control
	if ctx.check(view != null, "场景应有 MachineView 节点"):
		ctx.equal(view.get_script(), load(WORKSPACE_PATH), "机器视图应挂 blueprint_workspace.gd")
		ctx.equal(int(view.get(&"area")), int(BlueprintWorkspace.Area.VIEWER), "机器视图应取 VIEWER 角色")
		ctx.equal(view.get_parent(), battlefield, "机器视图应挂在战场里")
		ctx.equal(view.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"视图不得接输入（COMBAT 期间蓝图不可编辑，03 §4.3）")
		ctx.equal(view.get(&"runtime"), null, "视图默认没有运行时（机器由 combat_screen 交进来）")
		# 06 §8：机器贴战场**下沿**，上方留给弹丸上升与（PET-65 的）敌人生成区。
		ctx.check(view.size.x > 0.0 and view.size.y > 0.0, "机器视图应有尺寸（未落布局则下面的范围断言无意义）")
		ctx.check(view.position.y >= 0.0 and view.position.y + view.size.y <= battlefield.size.y + 0.01,
			"机器视图应贴战场下沿且不越出战场（%s）" % Rect2(view.position, view.size))

	var placeholder: Node = _find(scene, "Placeholder")
	var notice: Node = _find(scene, "NoticeLabel")
	if ctx.check(placeholder != null and notice != null and view != null, "战场应有占位文字与提示文字"):
		ctx.check(placeholder.get_index() < view.get_index(), "机器应画在占位文字之上")
		ctx.check(view.get_index() < notice.get_index(), "提示文字应画在机器之上（提示不能被机器盖住）")

	var driver: Node = _find(scene, "MachineDriver")
	if ctx.check(driver != null, "场景应有 MachineDriver 节点"):
		ctx.equal(driver.get_script(), load(DRIVER_PATH), "节拍器应挂 machine_driver.gd")
		ctx.equal(driver.get_parent(), scene, "节拍器应挂在场景根下")
		ctx.equal(driver.get(&"runtime"), null, "未开战前节拍器不得持有机器")
	scene.free()

	ctx.begin_case("COMBAT · 只读视图不接拖放（03 §4.3）")
	var canvas: Control = _workspace(BlueprintWorkspace.Area.CANVAS)
	var viewer: Control = _workspace(BlueprintWorkspace.Area.VIEWER)
	var boxes: Dictionary = viewer.get(&"_boxes")
	if not ctx.check(boxes.size() > 0, "只读视图也应把载入的节点落格（否则下面两条只是因为点空了才通过）"):
		canvas.free()
		viewer.free()
		return
	var first_box: Rect2 = boxes.values()[0]
	var at: Vector2 = first_box.get_center()
	ctx.check(not String(viewer.call(&"_card_at", at)).is_empty(),
		"取样的点确实落在一张卡片上（这是下面两条断言有意义的前提）")
	var payload: Dictionary = {"type": &"node", "kind": NodeData.Kind.ABILITY, "name": "冰"}
	ctx.equal(canvas.call(&"_can_drop_data", at, payload), true, "画布应接受拖入的节点")
	ctx.equal(viewer.call(&"_can_drop_data", at, payload), false, "只读视图不得接受拖入的节点")
	ctx.equal(viewer.call(&"_get_drag_data", at), null, "只读视图不得拖出节点")
	canvas.free()
	viewer.free()


## 串联的机器骨架：core 打头，spec 里的节点依次接上，最后接 needle。
## 要分叉 / 环路 / 悬空边的用例请用 _graph（这里一定会补一张冰，也会补一条链）。
func _chain(spec: Array[Dictionary]) -> BlueprintData:
	var nodes: Array[Dictionary] = [{"id": "core", "kind": NodeData.Kind.CORE}]
	var links: Array[Dictionary] = []
	var previous: String = "core"
	for item: Dictionary in spec:
		var id: String = String(item["id"])
		nodes.append(item)
		links.append({"from": previous, "to": id})
		previous = id
	nodes.append({"id": "needle", "kind": NodeData.Kind.ABILITY})
	links.append({"from": previous, "to": "needle"})
	return _graph(nodes, links)


## 从零搭一张图：spec 与 links 都得给全，不自动补节点、也不自动补边。
## 每一项 {"id": …, "kind": …（缺省 FUNCTION）, "function": …（缺省 NONE）}。
func _graph(spec: Array[Dictionary], links: Array[Dictionary]) -> BlueprintData:
	var blueprint: BlueprintData = BlueprintData.new()
	for item: Dictionary in spec:
		_node(blueprint, String(item["id"]),
			int(item.get("kind", NodeData.Kind.FUNCTION)),
			int(item.get("function", NodeData.Function.NONE)))
	# 节点**全部**落图之后才连线：这样「边连到不存在的节点」只会是悬空边，
	# 不会与「节点声明顺序写错」混成同一个症状。
	for link: Dictionary in links:
		_link(blueprint, String(link["from"]), String(link["to"]))
	return blueprint


func _node(blueprint: BlueprintData, id: String, kind: int,
		behavior: int = NodeData.Function.NONE) -> void:
	var node := NodeData.new()
	node.id = StringName(id)
	node.display_name = id
	node.kind = kind
	node.function_kind = behavior
	blueprint.nodes.append(node)


func _link(blueprint: BlueprintData, from_id: String, to_id: String) -> void:
	var link := ConnectionData.new()
	link.from_node_id = StringName(from_id)
	link.from_port = &"out"
	link.to_node_id = StringName(to_id)
	link.to_port = &"in"
	blueprint.connections.append(link)


## 建运行时并挂上探针。探针**只记录**，不干预仿真。
func _machine(blueprint: BlueprintData) -> MachineRuntime:
	_activations.clear()
	_fired.clear()
	_fire_ticks.clear()
	_mana_log.clear()
	var runtime := MachineRuntime.new(blueprint)
	_watched = runtime
	runtime.node_activated.connect(_on_activated)
	runtime.ability_cast.connect(_on_fired)
	runtime.mana_changed.connect(_on_mana)
	return runtime


func _on_activated(node_id: StringName) -> void:
	_activations.append(node_id)


func _on_fired(ability_id: StringName) -> void:
	_fired.append(ability_id)
	_fire_ticks.append(_watched.tick_index())


func _on_mana(mana: float) -> void:
	_mana_log.append(mana)


func _tick(runtime: MachineRuntime, times: int) -> void:
	for index: int in maxi(times, 0):
		runtime.tick()


## 逐拍把在途脉冲与魔力记成一串文本，供两张图逐字比较（03 §6 的确定性）。
func _trace(runtime: MachineRuntime, ticks: int) -> String:
	var lines: PackedStringArray = []
	for index: int in ticks:
		runtime.tick()
		var parts: PackedStringArray = []
		for pulse: SignalPulse in runtime.pulses():
			parts.append("%s>%s:%d:%.3f" % [pulse.from_node_id, pulse.to_node_id,
				pulse.ticks_left, pulse.value])
		lines.append("%d[%s]m=%.3f" % [runtime.tick_index(), ",".join(parts), runtime.mana()])
	return "\n".join(lines)


func _count_activated(node_id: String) -> int:
	return _count_of(_activations, node_id)


func _count_fired(node_id: String) -> int:
	return _count_of(_fired, node_id)


func _count_of(ids: Array[StringName], node_id: String) -> int:
	var total: int = 0
	for item: StringName in ids:
		if String(item) == node_id:
			total += 1
	return total


## 建一个不入树的工作区实例，路径指向测试蓝图（同 test_blueprint_workspace 的做法）。
func _workspace(area: int) -> Control:
	var workspace: Control = BlueprintWorkspace.new()
	workspace.set(&"area", area)
	workspace.size = Vector2(320.0, 96.0)
	workspace.set(&"blueprint_path", SAVE_PATH)
	workspace.call(&"reload")
	return workspace


## 清掉测试产物。正式存档目录一概不碰。
func _cleanup() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir != null:
		dir.remove(SAVE_PATH.get_file())


## 去掉注释再扫描：本仓库的文档注释里大量提到被禁的构造（正是为了声明「不许用」），
## 直接全文匹配会把「写明禁令」误判成「违反禁令」。同 test_blueprint_workspace.gd 的 _strip_comments。
func _strip_comments(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		var quote: String = ""
		var cut: int = line.length()
		for index: int in line.length():
			var character: String = line[index]
			if not quote.is_empty():
				if character == quote:
					quote = ""
			elif character == "\"" or character == "'":
				quote = character
			elif character == "#":
				cut = index
				break
		kept.append(line.substr(0, cut))
	return "\n".join(kept)


func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)
