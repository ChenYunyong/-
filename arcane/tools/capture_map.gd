## capture_map.gd
## 职责：路线图屏的**像素证据**采集 —— 真机走到 MAP，用真鼠标事件沿路走两站，截图并打印实测数字。
## 所属系统：tools
## 依赖：tests/tree_probe.gd（只借它做子树查找）、MapLayout（节点落点）、MapNodePainter（状态判定）、
##       boot.tscn 与路线图场景
## 禁止：本文件不得改动任何产品代码；不得被游戏运行时引用（tools/* 已排除导出）。
##
## 为什么不是「摆好一个状态再截图」：那样截出来的是布置出来的画面，证明不了「点得动」。
## 这里走的是玩家那条路 —— push_input 真鼠标事件 → Viewport → MapView._gui_input → press()。
## 于是截图里那道走过的墨迹、那个金圈当前节点，是这条链真的跑出来的产物。
##
## 09 §8 要求证据附「窗口是否可见 + 验证方式 + 实测数字」，三者都在打印里给出。
##
## 运行方式（**不要**加 --headless，截图需要真实渲染窗口）：
##   godot --path . --script res://tools/capture_map.gd

extends SceneTree

const TreeProbe = preload("res://tests/tree_probe.gd")
const OUTPUT_DIR: String = "res://tests/output"
## 强制中文再截：这一屏的字全走 i18n，系统语言不是中文时截出来是英文，
## 而这张图要说明的正是「新文案进了表」（MapView.kind_text / state_text 全经 TranslationServer）。
const LOCALE: String = "zh_CN"

var _run: Node = null
var _flow: Node = null
var _view: Control = null
var _model: MapModel = null
var _lines: Array[String] = []


func _initialize() -> void:
	# 与 run_tests 同一个理由：--script 入口在 _initialize() 时 Autoload 还没 _ready()。
	await process_frame
	await process_frame
	_run = root.get_node_or_null(^"RunState")
	_flow = root.get_node_or_null(^"GameFlow")
	if _run == null or _flow == null:
		_say("致命：RunState / GameFlow 单例不在树里")
		quit(1)
		return
	var settings: Node = root.get_node_or_null(^"Settings")
	if settings != null:
		settings.set_locale(LOCALE, false)

	if not await _boot_to_editor():
		quit(1)
		return
	if not await _open_map():
		quit(1)
		return
	await _walk_two_stops()
	await _capture("map_route.png")
	await _show_rejection()
	await _capture("map_reject.png")
	_report()
	for line: String in _lines:
		print(line)
	quit(0)


# ------------------------------------------------------------------ 启动

## 走引擎那条路：落地 boot 主场景 → 自检 → 开一局 → 编辑器 → 路线图。
func _boot_to_editor() -> bool:
	var packed: PackedScene = load("res://scenes/boot.tscn")
	if packed == null:
		_say("致命：boot.tscn 加载不了")
		return false
	var boot: Node = packed.instantiate()
	root.add_child(boot)
	# 不补这一步的话 change_scene_to_file() 不会回收 boot（它只回收 current_scene）。
	current_scene = boot
	_say("窗口：%s，窗口尺寸 %s，视口 %s，倍率 %.2f" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(root.get_visible_rect().size), _window_scale()])
	for _frame: int in 20:
		await process_frame
		if current_scene != null and TreeProbe.count_of(current_scene, "BoardView") == 1:
			break
	if current_scene == null or TreeProbe.count_of(current_scene, "BoardView") != 1:
		_say("致命：没有从 boot 走到编辑器")
		return false
	return true


## EDITOR → MAP。GameState 只能从脚本常量表里取 —— 本文件是 --script 入口，
## 编译期还没有 Autoload 标识符 GameFlow，写不出来（见 run_tests.gd 的同一条禁止）。
func _open_map() -> bool:
	var states: Dictionary = _flow.get_script().get_script_constant_map()["GameState"]
	if not bool(_flow.change_state(states["MAP"])):
		_say("致命：EDITOR → MAP 被拒（当前 %s）" % _flow.state_name(_flow.get_state()))
		return false
	for _frame: int in 20:
		await process_frame
		if current_scene != null and TreeProbe.count_of(current_scene, "MapView") == 1:
			break
	var found: Array[Node] = TreeProbe.find_all(current_scene, "MapView")
	if found.is_empty():
		_say("致命：MAP 场景里没有 MapView")
		return false
	_view = found[0]
	_model = _run.map()
	_say("启动：boot 自检 → 开一局 → 编辑器 → MAP，羊皮卷 %s，图上 %d 个节点 / %d 条边" % [
		str(_view.size), _model.nodes().size(), _edge_count()])
	return true


# ------------------------------------------------------------------ 沿路走两站

## 真鼠标事件点两下「可选」节点 —— 每一站都留下痕迹（走过的边加粗、上一站退成已访问）。
func _walk_two_stops() -> void:
	for stop: int in 2:
		var next: MapModel.MapNode = _model.selectable()[0]
		await _click_node(next)
		_say("第 %d 站：点第 %d 层第 %d 列（%s）→ 当前节点 %d，走过的序列 %s" % [
			stop + 1, next.tier, next.column, MapView.kind_text(next.kind),
			_model.current_id(), str(_model.path())])


func _click_node(node: MapModel.MapNode) -> void:
	var at: Vector2 = _to_window(MapLayout.node_position(node.tier, node.column))
	_mouse_move(at)
	_mouse_press(at)
	await process_frame
	_mouse_release(at)
	await process_frame


# ------------------------------------------------------------------ 走不了的那一下

## 点一个够不到的节点：给红圈 + 斜杠 + 一句话，并且**一个字节的状态都不动**。
func _show_rejection() -> void:
	var path_before: Array[int] = _model.path()
	var current_before: int = _model.current_id()
	var far: MapModel.MapNode = _model.nodes_in_tier(MapModel.TIERS - 1)[0]
	await _click_node(far)
	var hint: String = _hint_text()
	_say("走不了的那一下：点第 %d 层第 %d 列（%s，%s）→ 被拒的是 %d，提示「%s」" % [
		far.tier, far.column, MapView.kind_text(far.kind),
		MapView.state_text(MapNodePainter.state_of(_model, far.id)),
		int(_view.call(&"rejected_id")), hint])
	_say("状态没动：走过的序列 %s（点之前 %s），当前节点 %d（点之前 %d）" % [
		str(_model.path()), str(path_before), _model.current_id(), current_before])


# ------------------------------------------------------------------ 数字

func _report() -> void:
	# 四种状态在这一帧里各有几个 —— 少一种就说明图例上有一样东西画面上根本没出现过。
	var counts: Dictionary = {}
	for state: MapNodePainter.State in MapNodePainter.State.size():
		counts[state] = 0
	for node: MapModel.MapNode in _model.nodes():
		var state: MapNodePainter.State = MapNodePainter.state_of(_model, node.id)
		counts[state] = int(counts[state]) + 1
	var parts: PackedStringArray = PackedStringArray()
	for state: MapNodePainter.State in MapNodePainter.State.size():
		parts.append("%s %d" % [MapView.state_text(state), int(counts[state])])
	_say("四状态分布（画面上同时在场）：%s" % ", ".join(parts))
	_say("命中区：节点半径 %.0f 逻辑像素 → 直径 %.0f 设备像素（06 §1 下限 44）" % [
		MapView.NODE_RADIUS, MapView.NODE_RADIUS * 2.0 * _window_scale()])
	_say("当前位置那行：%s" % _status_text())


func _edge_count() -> int:
	var total: int = 0
	for node: MapModel.MapNode in _model.nodes():
		total += node.next.size()
	return total


## 顶上那行按**落点**找（MapLayout.status_rect() 是版式契约），不按文案前缀。
func _status_text() -> String:
	var want: Vector2 = MapLayout.status_rect().position
	for node: Node in TreeProbe.find_all(current_scene, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(want):
			return label.text
	return "（没找到）"


## 底部那句提示。同样按落点找（MapLayout.bottom_hint_rect()）—— 按文案找会先撞上标题。
func _hint_text() -> String:
	var want: Vector2 = MapLayout.bottom_hint_rect().position
	for node: Node in TreeProbe.find_all(current_scene, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(want):
			return label.text
	return "（没找到）"


# ------------------------------------------------------------------ 手势

## 合成输入必须自己先补一次移动：Viewport 只有收到过移动事件才认为指针在窗口内
## （gui.mouse_in_viewport），在那之前按下的那一下会被整条丢掉。
func _mouse_move(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = at
	root.push_input(event)


func _mouse_press(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)


func _mouse_release(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = at
	root.push_input(event)


## 图**局部**坐标 → **窗口**坐标。push_input 收到的是窗口坐标，引擎再按内容缩放把它换算进
## 960×540 的视口；给视口坐标的话会被再除一次倍率，落点跑到左上角去（与 capture_editor 同一条）。
func _to_window(local: Vector2) -> Vector2:
	return (_view.global_position + local) * _window_scale()


## 窗口 ÷ 视口的整数倍率（960×540 → 1920×1080 即 2）。
func _window_scale() -> float:
	return float(DisplayServer.window_get_size().x) / root.get_visible_rect().size.x


# ------------------------------------------------------------------ 截图

func _capture(file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# 等这一帧真的画完再取纹理，否则拿到的是上一帧（刚点的那一下还没画上去）。
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		_say("致命：拿不到窗口纹理，%s 未生成" % file_name)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, file_name]
	var error: Error = image.save_png(path)
	if error != OK:
		_say("致命：%s 写入失败（错误码 %d）" % [path, error])
		return
	# 截图取的是**逻辑渲染目标**（960×540），不是窗口帧缓冲：stretch/mode=viewport 下引擎先按
	# 960×540 画，再整块放大贴到窗口上。所以「2×」只能靠 窗口 ÷ 视口 + scale_mode=integer 证明。
	_say("截图：%s %d×%d（逻辑渲染目标；scale_mode=%s）" % [
		path, image.get_width(), image.get_height(),
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode"))])


func _say(line: String) -> void:
	_lines.append("[capture] " + line)
