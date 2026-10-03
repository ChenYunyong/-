## test_state_loop.gd
## 职责：在真实 Autoload 单例上跑一遍状态流转，验证跨系统接线（09 §1 集成层）。
## 所属系统：tests
## 依赖：test_context, GameFlow / EventBus / RunState / DataRegistry 四个 Autoload
## 禁止：本文件不得改动 Autoload 的业务状态 —— 用完必须还原到 BOOT。

extends RefCounted

const EXPECTED_AUTOLOADS: PackedStringArray = ["EventBus", "GameFlow", "DataRegistry", "RunState", "Settings"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("集成 · 五个 Autoload 就位")
	for singleton_name: String in EXPECTED_AUTOLOADS:
		ctx.check(tree.root.get_node_or_null(NodePath(singleton_name)) != null, "%s 应已作为 Autoload 加载" % singleton_name)

	var bus: Node = tree.root.get_node_or_null(NodePath("EventBus"))
	var flow: Node = tree.root.get_node_or_null(NodePath("GameFlow"))
	var run_state: Node = tree.root.get_node_or_null(NodePath("RunState"))
	if not ctx.check(bus != null and flow != null and run_state != null, "EventBus / GameFlow / RunState 应可用"):
		return
	var flow_script: GDScript = flow.get_script()

	ctx.begin_case("集成 · EventBus 收到真实 GameFlow 的状态切换")
	var seen: Array = []
	var handler: Callable = func(from, to) -> void: seen.append([from, to])
	bus.connect(&"state_changed", handler)

	ctx.check(flow.call(&"change_state", flow_script.GameState.MAIN_MENU), "BOOT → MAIN_MENU")
	ctx.check(flow.call(&"change_state", flow_script.GameState.PREPARATION), "MAIN_MENU → PREPARATION")
	ctx.check(flow.call(&"request_start_combat"), "PREPARATION → COMBAT（玩家动作入口）")
	ctx.check(flow.call(&"change_state", flow_script.GameState.REWARD), "COMBAT → REWARD")
	ctx.check(flow.call(&"change_state", flow_script.GameState.PREPARATION), "REWARD → PREPARATION")
	ctx.equal(seen.size(), 5, "EventBus 应收到 5 次切换")
	ctx.equal(int(flow.call(&"get_state")), flow_script.GameState.PREPARATION, "最终状态")

	ctx.begin_case("集成 · RunState 种子可复现（03 §6）")
	run_state.call(&"start_run", 20261003)
	ctx.equal(int(run_state.call(&"get_run_seed")), 20261003, "显式种子应被采纳")
	var rng: RandomNumberGenerator = run_state.call(&"get_rng")
	ctx.check(rng != null, "应能取到随机源")
	var first: int = rng.randi()
	rng.seed = 20261003
	ctx.equal(rng.randi(), first, "同一种子必须产生同一序列")

	ctx.begin_case("集成 · RunState 生命周期")
	run_state.call(&"end_run")
	ctx.check(not bool(run_state.call(&"is_active")), "结束本局后 is_active 应为 false")
	run_state.call(&"end_run")
	ctx.check(not bool(run_state.call(&"is_active")), "重复结束不得崩溃")

	# 还原全局状态，避免污染后续用例。
	bus.disconnect(&"state_changed", handler)
	flow.call(&"change_state", flow_script.GameState.RESULT)
	flow.call(&"change_state", flow_script.GameState.MAIN_MENU)
	ctx.equal(int(flow.call(&"get_state")), flow_script.GameState.MAIN_MENU, "已还原到 MAIN_MENU")
