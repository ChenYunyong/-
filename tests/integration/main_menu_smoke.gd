## main_menu_smoke.gd
## 职责：MAIN_MENU 场景的场景冒烟（09 §1）—— 走真实 GameFlow 路由进入、四个按钮的行为、
##       面板三层几何、重复进入不残留。**单独进程**运行。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, scenes/menu/main_menu.tscn, scripts/ui/main_menu.gd
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 run_tests.gd 的约束）；一律 load() + 经 /root 取节点。
##
## 为什么不挂进 run_tests.gd：本用例要真的把 GameFlow 推到 MAIN_MENU 并让路由换掉当前场景，
## 那会污染同进程里 test_state_loop.gd 的「BOOT → MAIN_MENU」与场景断言。
##
## 「开始」的验收点是**停在主菜单并给出可读提示**，所以本文件断言的是屏幕上看得见的东西
## （提示面板可见、文字是中文），而不是「脚本里有没有那个 if」。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const MENU_SCENE_PATH: String = "res://scenes/menu/main_menu.tscn"
## S1-07 起「开始」会真的路由到这里。刻意写死路径而不是问 GameFlow 要 ——
## 本用例要证的就是「路由表登记的就是这个文件」，问了被测实现就成了同义反复。
const PREP_SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const MENU_SCRIPT_PATH: String = "res://scripts/ui/main_menu.gd"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"
const LOG_PATH: String = "res://tests/output/main_menu_smoke.log"

## S1-05 复核记下的坑：MessagePanel 的最小尺寸是 25×61，容器矩形小于它就会被静默撑开。
const MESSAGE_PANEL_MIN: Vector2 = Vector2(25.0, 61.0)

var _ctx: RefCounted = null
var _scene: PackedScene = null
var _menu_script: GDScript = null
var _flow_script: GDScript = null
var _lines: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_scene = load(MENU_SCENE_PATH)
	_menu_script = load(MENU_SCRIPT_PATH)
	_flow_script = load(GAME_FLOW_PATH)

	await process_frame
	await _run_routed_entry_case()
	_run_structure_case()
	_run_continue_case()
	_run_placeholder_case()
	await _run_reentry_case()
	# 「开始」会把当前场景换成 PREPARATION，故必须排在最后 —— 否则后面每个用例的
	# `current_scene` 都已经不是主菜单，会连锁报一串与它们本身无关的失败。
	await _run_start_case()
	_finish()


## 验收第一条：MAIN_MENU 必须由 GameFlow 的路由进入，不得绕过状态机自己 add_child。
## 所以这里不手工挂场景，而是真的请求一次切换，再回头问「当前场景是哪个」。
func _run_routed_entry_case() -> void:
	_ctx.begin_case("MAIN_MENU 冒烟 · 经 GameFlow 路由进入")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.check(bool(flow.call(&"is_state", _state("BOOT"))), "前置：启动态应为 BOOT")

	var path: String = String(flow.call(&"get_scene_path_for", _state("MAIN_MENU")))
	_ctx.equal(path, MENU_SCENE_PATH, "GameFlow 登记的 MAIN_MENU 路由路径")
	_ctx.check(bool(flow.call(&"change_state", _state("MAIN_MENU"))), "BOOT → MAIN_MENU 应被接受")
	await process_frame
	await process_frame

	var menu: Node = current_scene
	if not _ctx.check(menu != null, "切换后应存在当前场景"):
		return
	_ctx.equal(menu.scene_file_path, MENU_SCENE_PATH, "当前场景应来自路由表登记的路径")
	_ctx.equal(menu.get_script(), _menu_script, "当前场景应挂着 main_menu.gd")
	_ctx.check(menu.get_parent() == root, "当前场景应挂在 root 下")
	_ctx.check(bool(flow.call(&"is_state", _state("MAIN_MENU"))), "状态应为 MAIN_MENU")


## 06 §2.1 / §2.2：外框铺满面板，内芯与外框内沿对齐；Body 缩进 = 3px 外框 + 12px 边距。
## 这里量的是**入树后 layout 出来的真实矩形**，不是场景里写的 offset。
func _run_structure_case() -> void:
	_ctx.begin_case("MAIN_MENU 冒烟 · 面板三层几何")
	var menu: Node = _menu()
	if not _ctx.check(menu != null, "应已进入 MAIN_MENU 场景"):
		return
	var panel: Control = _find(menu, "MenuPanel") as Control
	if not _ctx.check(panel != null, "应有 MenuPanel 容器"):
		return

	var theme_script: GDScript = load(THEME_SCRIPT_PATH)
	var expected: Dictionary = {
		"Shadow": theme_script.TYPE_PANEL_SHADOW,
		"Frame": theme_script.TYPE_PANEL_FRAME,
		"Core": theme_script.TYPE_PANEL_CORE,
		"Highlight": theme_script.TYPE_PANEL_HIGHLIGHT,
	}
	for layer_name: String in expected:
		var layer: Control = _find(panel, layer_name) as Control
		if not _ctx.check(layer != null, "菜单面板应有 %s 层" % layer_name):
			continue
		_ctx.equal(layer.theme_type_variation, expected[layer_name], "%s 层的 Theme 变体" % layer_name)

	var frame: Control = _find(panel, "Frame") as Control
	var core: Control = _find(panel, "Core") as Control
	var body: Control = _find(panel, "Body") as Control
	if frame == null or core == null or body == null:
		return

	var border: float = float(theme_script.FRAME_BORDER_WIDTH)
	_ctx.equal(frame.size, panel.size, "外框应与面板同尺寸（铺满）")
	_ctx.equal(core.size, panel.size - Vector2(border, border) * 2.0, "内芯应比面板四周各小 3px")
	_ctx.equal(core.position, Vector2(border, border), "内芯左上角应落在面板内沿")
	_ctx.check(_contains(frame.get_global_rect(), core.get_global_rect()), "内芯应完全落在外框内")
	_ctx.check(_contains(core.get_global_rect(), body.get_global_rect()), "Body 应完全落在内芯内")

	var inset: float = float(_menu_script.PANEL_BODY_INSET)
	_ctx.equal(body.position, Vector2(inset, inset), "Body 应缩进 3px 外框 + 12px 内容边距")
	_ctx.equal(body.size, panel.size - Vector2(inset, inset) * 2.0, "Body 尺寸应与缩进相符")

	_check_notice_panel_fits(menu)


## S1-05 的坑：容器矩形小于 MessagePanel 的最小尺寸时会被静默撑开，越出预定区域。
## 故这里不只断言「不小于最小值」，还断言它的真实矩形**没有超出**场景给定的范围。
func _check_notice_panel_fits(menu: Node) -> void:
	var notice: Control = _find(menu, "NoticePanel") as Control
	if not _ctx.check(notice != null, "应有提示面板"):
		return
	var minimum: Vector2 = notice.get_combined_minimum_size()
	_ctx.check(notice.size.x >= minimum.x and notice.size.y >= minimum.y,
		"提示面板矩形不得小于其最小尺寸（%.0fx%.0f，实际 %.0fx%.0f）" % [
			minimum.x, minimum.y, notice.size.x, notice.size.y])
	_ctx.check(notice.size.x >= MESSAGE_PANEL_MIN.x and notice.size.y >= MESSAGE_PANEL_MIN.y,
		"提示面板矩形应 ≥ S1-05 记下的 25x61")
	var viewport: Rect2 = menu.get_viewport_rect()
	_ctx.check(_contains(viewport, notice.get_global_rect()),
		"提示面板不得被最小尺寸撑出屏幕（实际 %s，视口 %s）" % [notice.get_global_rect(), viewport])


## 「开始」：PREPARATION 已由 S1-07 落地，本用例改为断言**真的经 GameFlow 路由进入整备场景**。
##
## S1-06 交付时这里断言的是「停在主菜单 + 未实现提示」（因为当时 preparation.tscn 还不存在）。
## 那条行为随 S1-07 落地而合法失效 —— 它不是被改坏了，而是它守的那个前提没了。
## 「未实现 → 可读提示」这条路径本身没有失去覆盖：下面的设置 / 退出两条走的是同一套机制。
## main_menu.gd 里那个路由就绪判断也仍然在，它现在守的是「场景文件缺失」这类真正的路由故障。
func _run_start_case() -> void:
	_ctx.begin_case("MAIN_MENU 冒烟 · 开始（经路由进入 PREPARATION）")
	var menu: Node = _menu()
	if not _ctx.check(menu != null, "应已进入 MAIN_MENU 场景"):
		return
	var notice: Control = _find(menu, "NoticePanel") as Control
	if not _ctx.check(notice != null, "应有提示面板"):
		return
	_ctx.check(not notice.visible, "前置：提示面板初始不可见")
	var flow: Node = _autoload("GameFlow")
	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("PREPARATION"))), PREP_SCENE_PATH,
		"按钮将要走的正是路由表登记的那条路径")

	_press(_find(menu, "ButtonStart") as Button)
	_ctx.equal(_state_of_flow(), _state("PREPARATION"), "请求『开始』后状态应为 PREPARATION")
	_ctx.check(not notice.visible, "路由就绪时不得弹出『未实现』提示")

	# change_scene_to_file 是延迟落地的，等两帧再看当前场景。
	await process_frame
	await process_frame
	var preparation: Node = current_scene
	if not _ctx.check(preparation != null, "切换后应存在当前场景"):
		return
	_ctx.equal(preparation.scene_file_path, PREP_SCENE_PATH, "当前场景应是路由表登记的 PREPARATION 路径")
	_ctx.equal(preparation.get_parent(), root, "当前场景应挂在 root 下")
	_ctx.check(preparation.get_script() != null, "PREPARATION 场景应挂上自己的脚本")
	_ctx.check(not is_instance_valid(menu), "切换后旧场景应被释放（不得两份菜单同时挂着）")


## 「继续」：无存档 → Disabled（06 §3），且不得挂任何处理器。
## 光断言 disabled 不够 —— 直接把 pressed 信号打出来，看状态会不会动。
func _run_continue_case() -> void:
	_ctx.begin_case("MAIN_MENU 冒烟 · 继续（Disabled，无存档）")
	var menu: Node = _menu()
	if not _ctx.check(menu != null, "应已进入 MAIN_MENU 场景"):
		return
	var resume: Button = _find(menu, "ButtonContinue") as Button
	if not _ctx.check(resume != null, "应有『继续』按钮"):
		return
	var notice: Control = _find(menu, "NoticePanel") as Control

	_ctx.check(resume.disabled, "『继续』必须为 Disabled（11 §8：存档格式尚未规划）")
	_ctx.check(resume.pressed.get_connections().is_empty(), "『继续』不得连接任何处理器")

	var before: int = _state_of_flow()
	resume.emit_signal(&"pressed")
	_ctx.equal(_state_of_flow(), before, "强制触发『继续』也不得改变状态")
	if notice != null:
		_ctx.check(not notice.visible, "强制触发『继续』不得弹出任何提示（它本就该点不动）")


## 设置 / 退出：本批不实现，但必须**明确标注**并给出可读提示，而不是静默无效。
func _run_placeholder_case() -> void:
	_ctx.begin_case("MAIN_MENU 冒烟 · 设置 / 退出（标注未实现）")
	var menu: Node = _menu()
	if not _ctx.check(menu != null, "应已进入 MAIN_MENU 场景"):
		return
	var notice: Control = _find(menu, "NoticePanel") as Control
	if not _ctx.check(notice != null, "应有提示面板"):
		return

	for pair: Array in [
		["ButtonSettings", String(_menu_script.NOTICE_SETTINGS), "『设置』"],
		["ButtonExit", String(_menu_script.NOTICE_EXIT), "『退出』"],
	]:
		var button: Button = _find(menu, pair[0]) as Button
		if not _ctx.check(button != null, "应有 %s 按钮" % pair[2]):
			continue
		_ctx.check(button.text.contains("未实现"), "%s 的文案应标注未实现（实际：%s）" % [pair[2], button.text])
		_press(button)
		_ctx.check(notice.visible, "%s 必须给出提示，不得静默无效" % pair[2])
		_check_notice_text(notice, String(pair[1]), "%s 的提示" % pair[2])
		_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "%s 不得改变状态" % pair[2])
		_dismiss(menu)


## 09 §2 第 7 类：重新进入场景。再实例化一份不得推状态、不得残留节点。
func _run_reentry_case() -> void:
	_ctx.begin_case("MAIN_MENU 冒烟 · 重复进入不残留")
	var base: int = root.get_child_count()
	var second: Node = _scene.instantiate()
	root.add_child(second)
	await process_frame
	await process_frame

	_ctx.equal(root.get_child_count(), base + 1, "第二次实例化应只多一个节点")
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "再次进入 MAIN_MENU 不得推进状态")

	root.remove_child(second)
	second.free()
	await process_frame
	_ctx.equal(root.get_child_count(), base, "释放后不应残留节点")
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "释放后状态不得变化")


func _check_notice_text(notice: Control, expected: String, label: String) -> void:
	var message: Label = _find(notice, "Message") as Label
	if not _ctx.check(message != null, "%s 应有正文" % label):
		return
	_ctx.check(message.text.contains(tr(expected)), "%s 应含 `%s`（实际：%s）" % [label, tr(expected), message.text])
	_ctx.check(_has_cjk(message.text), "%s 必须是中文（屏幕上要读得懂）" % label)


func _press(button: Button) -> void:
	if button != null:
		button.emit_signal(&"pressed")


func _dismiss(menu: Node) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.pressed = true
	menu.call(&"_input", event)


func _menu() -> Node:
	return current_scene


func _state_of_flow() -> int:
	var flow: Node = _autoload("GameFlow")
	if flow == null:
		return -1
	return int(flow.call(&"get_state"))


func _contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.encloses(inner)


func _has_cjk(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


## 按名字找节点。刻意不用 `%` 唯一名：子场景实例的唯一名作用域挂在各自 owner 上，
## 跨子场景边界时语义容易出意外；按名字搜是确定的。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


func _state(name: String) -> int:
	return int(_flow_script.GameState[name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：S1-06（PET-40）MAIN_MENU 场景 + 面板标题栏")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：MAIN_MENU 经路由进入 · 开始(→PREPARATION) · 继续(Disabled) · 设置 · 退出 · 重复进入")
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\main_menu_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("main_menu_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
