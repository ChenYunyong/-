## input_smoke.gd
## 职责：统一输入层的**真实场景**冒烟（09 §1 场景冒烟层）—— 在真场景、真路由、真 GUI 拾取下，
##       分别驱动「触摸」与「鼠标」两条路径，断言两者产出**同一个结果**。**单独进程**运行。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, 六个场景, scripts/core/game_flow.gd
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译；一律 load() + 经 /root 取节点。
##
## 为什么不能塞进 run_tests.gd：本用例会真的把 GameFlow 推过 MAIN_MENU / PREPARATION / COMBAT /
## REWARD / RESULT 五个状态并让路由换掉当前场景，留在同进程会污染 test_state_loop.gd 的断言。
##
## 输入怎么发：root.push_input(event) —— 走引擎真实的 GUI 拾取，不是直接调场景的私有方法。
## 这一点是本用例的立身之本：直接调 _on_back_requested() 只能证明那个函数写了什么，
## 证明不了玩家的一指头按下去真的会走到它。
##
## 判别力：每个实验组都配一个反向对照（环带外的点、只抬起的触摸），
## 一个「永远返回同一件事」的实现会在反向对照上翻车。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const LOG_PATH: String = "res://tests/output/input_smoke.log"
const TASK_LABEL: String = "S1-11（PET-53）双端输入适配：统一输入层 + 触摸/键鼠双路径"

## 场景语义尺寸。与工程视口一致，也让布局函数拿到真实档位（320×180 是横屏 → 宽屏布局）。
const VIEWPORT: Vector2 = Vector2(320.0, 180.0)
const STATE_NAMES: Array[String] = ["BOOT", "MAIN_MENU", "PREPARATION", "COMBAT", "REWARD", "RESULT"]
## 全部用例跑完应有的断言条数（实测值）。少一条就说明某个用例中途没跑完 —— 见 _finish()。
const MIN_ASSERTIONS: int = 40

var _ctx: RefCounted = null
var _flow_script: GDScript = null
var _lines: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_flow_script = load(GAME_FLOW_PATH)
	await process_frame

	await _case_routed_entry()
	await _case_hit_ring("MAIN_MENU", "ButtonStart", "PREPARATION")
	await _case_notice_equivalence()
	await _case_escape_at_menu()
	await _case_hit_ring("PREPARATION", "ButtonStartCombat", "COMBAT")
	await _case_escape_preparation()
	await _case_escape_combat()
	await _case_escape_result()
	await _case_reward_cards()
	_finish()


## 前置：本层的所有断言都发生在真实路由进来的场景里，先把 BOOT → MAIN_MENU 走通。
func _case_routed_entry() -> void:
	_ctx.begin_case("输入冒烟 · 经 GameFlow 路由进入 MAIN_MENU")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	flow.call(&"change_state", _state("MAIN_MENU"))
	await _settle()
	_ctx.check(current_scene != null, "路由后应有当前场景")
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "前置：状态应为 MAIN_MENU")


## 交付物 2 的**行为**证明：命中环带（视觉矩形之外、命中矩形之内）按下去要真的触发那个控件。
## 触摸与鼠标各走一遍，两次的状态迁移必须一模一样。
func _case_hit_ring(state_name: String, node_name: String, target_name: String) -> void:
	_ctx.begin_case("输入冒烟 · %s 的命中环带（触摸 vs 鼠标）" % node_name)
	await _goto(state_name)
	var control: Control = _find(current_scene, node_name)
	if not _ctx.check(control != null, "%s 里应有 %s" % [state_name, node_name]):
		return
	var rect: Rect2 = control.get_global_rect()
	var ring: Vector2 = Vector2(rect.get_center().x, rect.position.y - 1.0)
	var outside: Vector2 = Vector2(rect.get_center().x, rect.position.y - 5.0)
	# 环带内的判据用**控件自己的** hit_rect()（局部坐标），而不是在外面对着两个矩形比大小 ——
	# 后者即使 _has_point() 被改坏了也照样成立，是自证式的写法。
	var local: Vector2 = ring - rect.position
	_ctx.check((control.call(&"hit_rect") as Rect2).has_point(local),
		"取样点应落在命中矩形内（局部坐标 %s，命中矩形 %s）" % [local, control.call(&"hit_rect")])
	_ctx.check(not rect.has_point(ring), "取样点应在视觉矩形之外 —— 否则这一条测的不是环带")

	# 反向对照：环带之外，两条路径都不得有任何效果。
	await _tap_touch(outside)
	_ctx.equal(_state_of_flow(), _state(state_name), "环带外触摸不得改变状态")
	await _goto(state_name)
	await _tap_mouse(outside)
	_ctx.equal(_state_of_flow(), _state(state_name), "环带外鼠标不得改变状态")

	await _goto(state_name)
	await _tap_touch(ring)
	var by_touch: int = _state_of_flow()
	await _goto(state_name)
	await _tap_mouse(ring)
	var by_mouse: int = _state_of_flow()

	_ctx.equal(by_touch, _state(target_name), "环带内触摸应触发控件（→%s）" % target_name)
	_ctx.equal(by_mouse, _state(target_name), "环带内鼠标应触发控件（→%s）" % target_name)
	_ctx.equal(by_touch, by_mouse, "触摸与鼠标必须产出同一个结果")


## 提示面板的关闭：两条路径都必须关得掉，且**都不得消费**事件（落在按钮上的那一次点击
## 既要关提示、也要照常触发按钮 —— 这是 S1-06 起就有的行为）。
func _case_notice_equivalence() -> void:
	_ctx.begin_case("输入冒烟 · 关提示（触摸 vs 鼠标）")
	await _goto("MAIN_MENU")
	var menu: Node = current_scene
	var notice: Control = _find(menu, "NoticePanel")
	var settings: Button = _find(menu, "ButtonSettings")
	if not _ctx.check(notice != null and settings != null, "应有提示面板与『设置』按钮"):
		return
	var spot: Vector2 = Vector2(4.0, 4.0)

	settings.emit_signal(&"pressed")
	_ctx.check(notice.visible, "前置：按『设置』应弹出提示")
	await _tap_touch(spot)
	_ctx.equal(notice.visible, false, "触摸按下应关掉提示")
	# 反向对照：只抬起不得关提示（否则一次点击会算两下）。
	settings.emit_signal(&"pressed")
	await _touch(spot, false)
	await process_frame
	_ctx.equal(notice.visible, true, "只抬起不得关掉提示")

	await _tap_mouse(spot)
	_ctx.equal(notice.visible, false, "鼠标按下应关掉提示")
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "关提示不得改变状态")


## 交付物 3：MAIN_MENU 没有返回边（它是状态图入口），Escape 必须什么都不做；
## 提示在场时按下 Escape 只关提示、不越级触发返回。
func _case_escape_at_menu() -> void:
	_ctx.begin_case("输入冒烟 · MAIN_MENU 的 Escape（无返回边 + 提示优先）")
	await _goto("MAIN_MENU")
	var settings: Button = _find(current_scene, "ButtonSettings")
	settings.emit_signal(&"pressed")
	var notice: Control = _find(current_scene, "NoticePanel")
	await _key(KEY_ESCAPE)
	_ctx.equal(notice.visible, false, "Escape 应关掉提示")
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "关提示的那一次 Escape 不得同时触发返回（一次按键只走一步）")
	await _key(KEY_ESCAPE)
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "MAIN_MENU 没有返回边，Escape 不得改变状态")


func _case_escape_preparation() -> void:
	_ctx.begin_case("输入冒烟 · PREPARATION 的 Escape（未开打就退出本局）")
	await _goto("PREPARATION")
	await _key(KEY_ESCAPE)
	_ctx.equal(_state_of_flow(), _state("RESULT"), "PREPARATION 按 Escape 应结束本局 → RESULT")
	_ctx.equal(_scene_path(), _path_of("RESULT"), "状态与场景应一起落到 RESULT（不得脱钩）")


func _case_escape_combat() -> void:
	_ctx.begin_case("输入冒烟 · COMBAT 的 Escape（结束本局）")
	await _goto("COMBAT")
	await _key(KEY_ESCAPE)
	_ctx.equal(_state_of_flow(), _state("RESULT"), "COMBAT 按 Escape 应结束本局 → RESULT")
	_ctx.equal(_scene_path(), _path_of("RESULT"), "状态与场景应一起落到 RESULT（不得脱钩）")


func _case_escape_result() -> void:
	_ctx.begin_case("输入冒烟 · RESULT 的 Escape（返回主菜单，不是再来一局）")
	await _goto("RESULT")
	await _key(KEY_ESCAPE)
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"),
		"RESULT 按 Escape 应回 MAIN_MENU（Escape 是「返回」，不是「开始新的一局」）")
	_ctx.equal(_scene_path(), _path_of("MAIN_MENU"), "状态与场景应一起落到 MAIN_MENU")


## 奖励卡：触摸与鼠标点同一张卡，必须选中**同一项**。
func _case_reward_cards() -> void:
	_ctx.begin_case("输入冒烟 · REWARD 卡片（触摸 vs 鼠标）")
	var by_touch: Array[int] = await _pick_card(1, true)
	var by_mouse: Array[int] = await _pick_card(1, false)
	_ctx.equal(by_touch, [1], "触摸应选中被点的那一张卡")
	_ctx.equal(by_mouse, [1], "鼠标应选中被点的那一张卡")
	_ctx.equal(by_touch, by_mouse, "触摸与鼠标必须选中同一项")
	_ctx.equal(_state_of_flow(), _state("PREPARATION"), "选定后应回 PREPARATION")


## 走一遍「进 REWARD → 点第 index 张卡」，返回被选中的卡片下标序列。
## 两条路径各调用一次，比较返回值即可判定二者是否一致。
func _pick_card(index: int, use_touch: bool) -> Array[int]:
	await _goto("REWARD")
	var picked: Array[int] = []
	var card: Control = _find(current_scene, "Card%d" % index)
	if not _ctx.check(card != null and card.has_signal(&"option_chosen"), "应有可点击的第 %d 张卡" % index):
		return picked
	for slot: int in 3:
		(_find(current_scene, "Card%d" % slot) as Control).option_chosen.connect(
			func(_option: Variant) -> void: picked.append(slot))
	var center: Vector2 = card.get_global_rect().get_center()
	if use_touch:
		await _tap_touch(center)
	else:
		await _tap_mouse(center)
	return picked


## 沿**合法边**走到目标状态。走不通就返回 false —— 本用例自己不得绕过 GameFlow 的迁移表。
func _goto(target_name: String) -> bool:
	var target: int = _state(target_name)
	var flow: Node = _autoload("GameFlow")
	for _step: int in STATE_NAMES.size():
		if int(flow.call(&"get_state")) == target:
			await _settle()
			return true
		var next: int = _next_hop(int(flow.call(&"get_state")), target)
		if next < 0:
			return false
		if int(flow.call(&"get_state")) == _state("PREPARATION") and next == _state("COMBAT"):
			flow.call(&"request_start_combat")
		else:
			flow.call(&"change_state", next)
		await _settle()
	return int(flow.call(&"get_state")) == target


## 从 from 到 to 的下一跳，在 ALLOWED_TRANSITIONS 上做广度优先。
## 额外补一条 PREPARATION → COMBAT：它在迁移表里刻意缺席，只能经 request_start_combat() 走
## （03 §1.1 R1），但玩家要到达 COMBAT 就只有这一条路，导航时必须认它。
func _next_hop(from: int, to: int) -> int:
	var adjacency: Dictionary = {}
	for key: int in _flow_script.ALLOWED_TRANSITIONS:
		adjacency[key] = (Array(_flow_script.ALLOWED_TRANSITIONS[key]) as Array).duplicate()
	adjacency[_state("PREPARATION")].append(_state("COMBAT"))
	var queue: Array[int] = [from]
	var came: Dictionary = {from: -1}
	while not queue.is_empty():
		var node: int = queue.pop_front()
		for neighbour: int in adjacency.get(node, []):
			if came.has(neighbour):
				continue
			came[neighbour] = node
			if neighbour == to:
				var hop: int = to
				while int(came[hop]) != from and int(came[hop]) != -1:
					hop = int(came[hop])
				return hop
			queue.append(neighbour)
	return -1


## 等两帧：change_scene_to_file 是延迟落地的，落完还要等布局跑一次。
func _settle() -> void:
	await process_frame
	await process_frame
	await process_frame
	if current_scene is Control:
		(current_scene as Control).size = VIEWPORT
	if current_scene != null and current_scene.has_method(&"apply_layout_for"):
		current_scene.call(&"apply_layout_for", VIEWPORT)
	await process_frame


func _tap_touch(at: Vector2) -> void:
	await _touch(at, true)
	await _touch(at, false)


func _touch(at: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	root.push_input(event)
	await process_frame


func _tap_mouse(at: Vector2) -> void:
	await _mouse(at, true)
	await _mouse(at, false)


func _mouse(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	root.push_input(event)
	await process_frame


func _key(code: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	root.push_input(event)
	await _settle()


func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false) if node != null else null


func _scene_path() -> String:
	return current_scene.scene_file_path if current_scene != null else ""


func _path_of(state_name: String) -> String:
	return String(_autoload("GameFlow").call(&"get_scene_path_for", _state(state_name)))


func _state_of_flow() -> int:
	var flow: Node = _autoload("GameFlow")
	return int(flow.call(&"get_state")) if flow != null else -1


func _state(state_name: String) -> int:
	return int(_flow_script.GameState[state_name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	# 断言条数下限：某个用例中途抛错会让后面的断言**一条都不跑**，而报告仍然是「失败项：无」——
	# 那不是通过，是没跑。这条下限把「静默跳过」变成一条红。
	_ctx.begin_case("输入冒烟 · 覆盖度下限")
	_ctx.check(_ctx.total() >= MIN_ASSERTIONS,
		"断言条数应 ≥ %d（实际 %d）—— 低于此数说明有用例中途没跑完" % [MIN_ASSERTIONS, _ctx.total()])

	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：%s" % TASK_LABEL)
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：命中环带（触摸/鼠标）· 关提示（触摸/鼠标）· 奖励卡（触摸/鼠标）· "
		+ "四个场景的 Escape 出口")
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\input_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("input_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
