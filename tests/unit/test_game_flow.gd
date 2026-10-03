## test_game_flow.gd
## 职责：六状态机的枚举、唯一入口、信号、硬规则 R1–R5、防重入与不自动推进。
## 所属系统：tests
## 依赖：test_context, scripts/core/game_flow.gd, scripts/core/event_bus.gd
## 禁止：本文件不得引用 Autoload 标识符 —— --script 入口在工程注册 Autoload
##       之前就被编译，裸写 EventBus 会直接编译失败；统一经 /root 取节点。

extends RefCounted

const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const EVENT_BUS_PATH: String = "res://scripts/core/event_bus.gd"

## 03 §1 规定的六状态，顺序即状态图顺序。
const EXPECTED_STATES: PackedStringArray = ["BOOT", "MAIN_MENU", "PREPARATION", "COMBAT", "REWARD", "RESULT"]

## R1 要求 game_flow.gd 里不存在任何计时器 / 每帧推进构造。
const BANNED_TIMING_TOKENS: PackedStringArray = [
	"Timer", "create_timer", "_process", "_physics_process", "timeout", "wait_time", "autostart",
]

## R1 实测：在 PREPARATION 停留 600 秒（10 分钟）模拟时间不得自动推进。
const R1_SIMULATED_SECONDS: float = 600.0

## 场景路由（03 §1.1 R3）：其余五个状态各自的责任任务号，取自 11_TASK_BOARD.md §3。
const EXPECTED_ROUTE_TASKS: Dictionary = {
	"MAIN_MENU": "S1-06",
	"PREPARATION": "S1-07",
	"COMBAT": "S1-08",
	"REWARD": "S1-09",
	"RESULT": "S1-10",
}

## R3 结构侧扫描的文件后缀。.tscn / .tres 也要扫 —— 场景里可以内嵌脚本。
const SCANNED_SUFFIXES: PackedStringArray = [".gd", ".tscn", ".tres"]
const ROUTING_TOKEN: String = "change_scene_to_file"

var _script: GDScript = null
var _tree: SceneTree = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	_tree = tree
	_script = load(GAME_FLOW_PATH)
	if not ctx.check(_script != null, "game_flow.gd 应能加载"):
		return
	_run_enum_checks(ctx)
	_run_happy_path_checks(ctx)
	_run_guard_checks(ctx)
	_run_r1_static_checks(ctx)
	_run_event_bus_checks(ctx)
	_run_source_integrity_checks(ctx)
	_run_routing_table_checks(ctx)
	_run_r3_source_checks(ctx)
	await _run_r1_simulated_time_check(ctx)
	# 路由权判定依赖 get_tree()。--script 模式下 Autoload 节点虽然已在 /root 下，
	# 但要等第一帧才真正入树（实测：在此之前 node.get_tree() 返回 null），
	# 故必须排在上面那个已经让出过帧的用例之后 —— 否则测到的是「顺序还没到」而非被测逻辑。
	_run_routing_ownership_checks(ctx)
	_run_cycle_check(ctx)


func _run_enum_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · 六状态枚举")
	var keys: Array = _script.GameState.keys()
	ctx.equal(keys.size(), EXPECTED_STATES.size(), "状态数量")
	for index: int in EXPECTED_STATES.size():
		if index < keys.size():
			ctx.equal(String(keys[index]), EXPECTED_STATES[index], "第 %d 个状态名" % index)
	ctx.equal(_script.state_name(-1), &"UNKNOWN", "越界序号的名称应降级为 UNKNOWN")


func _run_happy_path_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · 正常路径与状态切换信号（R4）")
	var flow: Node = _spawn()
	ctx.equal(flow.get_state(), _script.GameState.BOOT, "初始状态应为 BOOT")

	var recorder: Array = []
	var handler: Callable = func(from, to) -> void: recorder.append([from, to])
	flow.state_changed.connect(handler)

	ctx.check(flow.change_state(_script.GameState.MAIN_MENU), "BOOT → MAIN_MENU 应成功")
	ctx.check(flow.change_state(_script.GameState.PREPARATION), "MAIN_MENU → PREPARATION 应成功")
	ctx.equal(recorder.size(), 2, "两次切换应各发一次 state_changed")
	if recorder.size() == 2:
		ctx.equal(recorder[1][0], _script.GameState.MAIN_MENU, "第二次切换的 from")
		ctx.equal(recorder[1][1], _script.GameState.PREPARATION, "第二次切换的 to")

	ctx.check(flow.request_start_combat(), "PREPARATION 下点击开始战斗应成功")
	ctx.equal(flow.get_state(), _script.GameState.COMBAT, "应进入 COMBAT")
	ctx.check(flow.change_state(_script.GameState.REWARD), "COMBAT → REWARD 应成功")
	ctx.check(flow.change_state(_script.GameState.PREPARATION), "REWARD → PREPARATION 应成功")
	flow.state_changed.disconnect(handler)
	_release(flow)


func _run_guard_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · 硬规则与防重入（R1 / R3 / R5）")
	var flow: Node = _spawn()
	flow.change_state(_script.GameState.MAIN_MENU)
	flow.change_state(_script.GameState.PREPARATION)

	# R1：通用入口不得把 PREPARATION 送进 COMBAT。
	ctx.check(not flow.change_state(_script.GameState.COMBAT), "change_state 不得把 PREPARATION 推进到 COMBAT（R1）")
	ctx.equal(flow.get_state(), _script.GameState.PREPARATION, "被拒后状态不应改变")

	# 非法迁移：BOOT 不能直达 COMBAT。
	var fresh: Node = _spawn()
	ctx.check(not fresh.change_state(_script.GameState.COMBAT), "BOOT → COMBAT 应被拒绝")
	ctx.equal(fresh.get_state(), _script.GameState.BOOT, "被拒后应仍为 BOOT")

	# 防重入：连续快速调用，只生效一次。
	ctx.check(flow.request_start_combat(), "第一次开始战斗应成功")
	ctx.check(not flow.request_start_combat(), "紧接着的第二次开始战斗应被拒绝")
	ctx.equal(flow.get_state(), _script.GameState.COMBAT, "状态应为 COMBAT")

	# R5：监听者在 state_changed 回调里再次请求切换，必须被拒绝。
	var nested: Node = _spawn()
	var nested_result: Array = []
	var reentrant: Callable = func(_from, _to) -> void:
		nested_result.append(nested.change_state(_script.GameState.PREPARATION))
	nested.state_changed.connect(reentrant)
	nested.change_state(_script.GameState.MAIN_MENU)
	ctx.equal(nested_result.size(), 1, "切换回调应被调用一次")
	if nested_result.size() == 1:
		ctx.check(not nested_result[0], "切换回调内的再次切换应被拒绝（R5）")
	ctx.equal(nested.get_state(), _script.GameState.MAIN_MENU, "重入被拒后应停在 MAIN_MENU")
	nested.state_changed.disconnect(reentrant)

	# 语义化入口的边界。
	ctx.check(not fresh.request_end_run(), "BOOT 下结束本局应被拒绝")
	ctx.check(not fresh.request_start_combat(), "BOOT 下开始战斗应被拒绝")

	for node: Node in [flow, fresh, nested]:
		_release(node)


func _run_r1_static_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · R1 结构侧：不得存在任何计时器")
	var source: String = FileAccess.get_file_as_string(GAME_FLOW_PATH)
	for token: String in BANNED_TIMING_TOKENS:
		ctx.check(not source.contains(token), "game_flow.gd 不得出现 `%s`" % token)
	var flow: Node = _spawn()
	ctx.check(not flow.has_method(&"_process"), "GameFlow 不应有 _process")
	ctx.check(not flow.has_method(&"_physics_process"), "GameFlow 不应有 _physics_process")
	ctx.equal(_count_timers(flow), 0, "GameFlow 子树内的 Timer 数")
	_release(flow)


func _run_event_bus_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · EventBus 转发")
	var bus: Node = _autoload("EventBus")
	if not ctx.check(bus != null, "EventBus 应为已注册的 Autoload"):
		return
	var seen: Array = []
	var handler: Callable = func(from, to) -> void: seen.append([from, to])
	bus.state_changed.connect(handler)
	var flow: Node = _spawn()
	flow.change_state(_script.GameState.MAIN_MENU)
	ctx.equal(seen.size(), 1, "EventBus.state_changed 应被转发一次")
	if seen.size() == 1:
		ctx.equal(seen[0][1], _script.GameState.MAIN_MENU, "转发过去的 to")
	bus.state_changed.disconnect(handler)
	_release(flow)


## 静态核对「EventBus 不存状态」「GameFlow 不存玩法数值」（03 §3）。
func _run_source_integrity_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · 职责边界（不存状态 / 不存玩法数值）")
	ctx.equal(_declared_vars(EVENT_BUS_PATH).size(), 0, "event_bus.gd 不应声明任何成员变量")

	var flow_vars: Array[String] = _declared_vars(GAME_FLOW_PATH)
	var expected: PackedStringArray = ["_state", "_is_transitioning"]
	ctx.equal(flow_vars.size(), expected.size(), "game_flow.gd 的成员变量数（多一个就可能越界存了玩法数值）")
	for name: String in flow_vars:
		ctx.check(expected.has(name), "game_flow.gd 出现了预期外的成员变量 `%s`" % name)

	ctx.equal(_script.ALLOWED_TRANSITIONS.size(), EXPECTED_STATES.size(), "迁移表应覆盖全部六个状态")


## 路由表本身：覆盖除 BOOT 外的五个状态，路径落在约定的场景目录，责任任务号与任务板一致。
## BOOT 刻意不在表内 —— 它是 project.godot 的主场景，由引擎启动时落地，不经路由。
func _run_routing_table_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · 场景路由表（03 §1.1 R3）")
	ctx.equal(_script.SCENE_ROUTES.size(), EXPECTED_STATES.size() - 1, "路由表应覆盖除 BOOT 外的五个状态")

	var flow: Node = _spawn()
	for index: int in EXPECTED_STATES.size():
		var name: String = EXPECTED_STATES[index]
		var path: String = flow.get_scene_path_for(index)
		if name == "BOOT":
			ctx.equal(path, "", "BOOT 是主场景、不经路由，路径应为空串")
			continue
		ctx.check(path.begins_with("res://scenes/"), "%s 的场景应登记在 res://scenes/ 下（实际 `%s`）" % [name, path])
		var route: Dictionary = _script.SCENE_ROUTES[index]
		ctx.equal(String(route["task"]), EXPECTED_ROUTE_TASKS[name], "%s 的责任任务号" % name)
	_release(flow)


## 路由是全局单例的职责。单测与工具会临时 new 出额外实例跑状态机，
## 那些副本一旦也去切场景，整个游戏当前场景就会被测试换掉。
func _run_routing_ownership_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · 路由权归属（只有 Autoload 单例能切场景）")
	var autoload_flow: Node = _autoload("GameFlow")
	if ctx.check(autoload_flow != null, "GameFlow 应为已注册的 Autoload"):
		ctx.check(autoload_flow.owns_scene_routing(),
			"Autoload 实例应拥有路由权（其 get_tree() = %s）" % str(autoload_flow.get_tree()))

	var spawned: Node = _spawn()
	ctx.check(not spawned.owns_scene_routing(), "临时实例不得拥有路由权")
	# 无场景树的实例（刚 new 出来还没挂进去）同样不得声称拥有路由权。
	var orphan: Node = _script.new()
	ctx.check(not orphan.owns_scene_routing(), "未入树的实例不得拥有路由权")
	orphan.free()
	_release(spawned)


## R3 结构侧：把整个 scripts/ 与 scenes/ 扫一遍，切场景的调用只允许出现在 game_flow.gd。
## 光靠约定挡不住 —— 这条断言才是 R3 的真正落点。
func _run_r3_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · R3 结构侧：全局只有一处 change_scene_to_file")
	var offenders: PackedStringArray = []
	var sources: Dictionary = _collect_sources(["res://scripts", "res://scenes"])
	for path: String in sources:
		if path != GAME_FLOW_PATH and _strip_comments(String(sources[path])).contains(ROUTING_TOKEN):
			offenders.append(path)
	ctx.equal(offenders.size(), 0, "越界调用 change_scene_to_file 的文件：%s" % ", ".join(offenders))
	ctx.check(sources.size() > 0, "扫描应覆盖到实际文件（命中 %d 个）" % sources.size())

	var flow_source: String = FileAccess.get_file_as_string(GAME_FLOW_PATH)
	ctx.check(flow_source.contains(ROUTING_TOKEN), "game_flow.gd 应确实是路由的唯一落地点")


## 去掉注释再扫描：本仓库的文档注释里大量提到 change_scene_to_file（正是为了声明「不许调它」），
## 直接全文匹配会把「写明禁令」误判成「违反禁令」。字符串里不会跨行，逐行处理即可。
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


## 递归收集若干根目录下指定后缀的文件内容，返回 {路径: 源码}。
func _collect_sources(roots: PackedStringArray) -> Dictionary:
	var sources: Dictionary = {}
	var pending: PackedStringArray = roots.duplicate()
	while not pending.is_empty():
		var directory_path: String = pending[pending.size() - 1]
		pending.remove_at(pending.size() - 1)
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory == null:
			continue
		for file_name: String in directory.get_files():
			if SCANNED_SUFFIXES.has("." + file_name.get_extension()):
				var path: String = "%s/%s" % [directory_path, file_name]
				sources[path] = FileAccess.get_file_as_string(path)
		for sub: String in directory.get_directories():
			pending.append("%s/%s" % [directory_path, sub])
	return sources


## R1 实测：把实例挂进场景树跑满 600 秒模拟时间，状态不得自行变化。
## 依赖 --fixed-fps 提供固定步长；漏加该参数时会因跑不满而明确失败，而不是假装通过。
func _run_r1_simulated_time_check(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · R1 实测：停留 10 分钟不自动推进")
	var clock: Node = _tree.get(&"clock")
	if not ctx.check(clock != null, "测试时钟应已挂载"):
		return
	clock.set(&"elapsed", 0.0)

	var flow: Node = _spawn()
	flow.change_state(_script.GameState.MAIN_MENU)
	flow.change_state(_script.GameState.PREPARATION)
	var transitions: Array = []
	var handler: Callable = func(from, to) -> void: transitions.append([from, to])
	flow.state_changed.connect(handler)

	var deadline: int = Time.get_ticks_msec() + int(_tree.call(&"wall_clock_budget_ms"))
	while float(clock.get(&"elapsed")) < R1_SIMULATED_SECONDS and Time.get_ticks_msec() < deadline:
		await _tree.process_frame

	var reached: float = float(clock.get(&"elapsed"))
	ctx.check(reached >= R1_SIMULATED_SECONDS, "模拟时间应跑满 %.0f 秒，实际 %.1f 秒（是否漏了 --fixed-fps？）" % [R1_SIMULATED_SECONDS, reached])
	ctx.equal(flow.get_state(), _script.GameState.PREPARATION, "10 分钟后应仍停留在 PREPARATION")
	ctx.equal(transitions.size(), 0, "停留期间不应发生任何状态切换")

	# 反向核对：不是「入口整个坏掉」才没推进 —— 显式请求必须仍然有效。
	var explicit_ok: bool = flow.request_start_combat()
	ctx.check(explicit_ok, "同一实例上显式请求仍应能进入 COMBAT")
	ctx.equal(transitions.size(), 1, "显式请求应恰好产生一次切换")
	flow.state_changed.disconnect(handler)
	_release(flow)


## 09 §3.1：COMBAT → REWARD → PREPARATION 循环 10 次。
func _run_cycle_check(ctx: RefCounted) -> void:
	ctx.begin_case("GameFlow · 状态循环 10 次")
	var flow: Node = _spawn()
	flow.change_state(_script.GameState.MAIN_MENU)
	flow.change_state(_script.GameState.PREPARATION)
	var cycles: int = 0
	for _index: int in 10:
		if not flow.request_start_combat():
			break
		if not flow.change_state(_script.GameState.REWARD):
			break
		if not flow.change_state(_script.GameState.PREPARATION):
			break
		cycles += 1
	ctx.equal(cycles, 10, "完成的循环次数")
	ctx.equal(flow.get_state(), _script.GameState.PREPARATION, "循环后应回到 PREPARATION")
	_release(flow)


func _spawn() -> Node:
	var node: Node = _script.new()
	node.name = "GameFlowUnderTest"
	_tree.root.add_child(node)
	return node


func _release(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _autoload(singleton_name: String) -> Node:
	return _tree.root.get_node_or_null(NodePath(singleton_name))


func _count_timers(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is Timer:
			count += 1
		count += _count_timers(child)
	return count


## 解析脚本顶层的成员变量声明名（局部 var 有缩进，因此不会被误收）。
func _declared_vars(path: String) -> Array[String]:
	var names: Array[String] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return names
	while not file.eof_reached():
		var line: String = file.get_line()
		if not line.begins_with("var "):
			continue
		var declaration: String = line.trim_prefix("var ")
		var colon: int = declaration.find(":")
		var equals: int = declaration.find("=")
		var cut: int = colon
		if cut < 0 or (equals >= 0 and equals < cut):
			cut = equals
		names.append((declaration if cut < 0 else declaration.substr(0, cut)).strip_edges())
	file.close()
	return names
