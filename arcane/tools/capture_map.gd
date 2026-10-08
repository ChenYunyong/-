## capture_map.gd
## 职责：路线图屏的**像素证据**采集 —— 真机走到 MAP，用真鼠标事件沿路走两站，截图并打印实测数字。
## 所属系统：tools
## 依赖：tests/tree_probe.gd（只借它做子树查找）、MapLayout（版式契约）、MapNodePainter（状态判定与线的折法）、
##       MapParchment（纸色）、Palette（墨色）、ContractTheme（字号）、Fonts（真字体，G10 量文字宽）、
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
## 主菜单上那颗按钮的文案 key。PET-90 起 boot 落在主菜单，编辑器要玩家按一下才去。
const KEY_NEW_RUN: String = "开始新一局"

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
		_fatal("RunState / GameFlow 单例不在树里")
		return
	var settings: Node = root.get_node_or_null(^"Settings")
	if settings != null:
		settings.set_locale(LOCALE, false)

	# 两步各自把失败原因说全了（见 _boot_to_editor / _open_map 里的致命行），
	# 这里不再重复一句 —— 同一件事印两遍，读的人会以为是两次不同的失败。
	if not await _boot_to_editor():
		_finish(1)
		return
	if not await _open_map():
		_finish(1)
		return
	await _walk_two_stops()
	var shot: Image = await _capture("map_route.png")
	if shot != null:
		_pixel_proof(shot)
	await _show_rejection()
	await _capture("map_reject.png")
	_report()
	_finish(0)


## 致命路径也要把话说完再退 —— 只 quit(1) 的话屏幕上只剩引擎那三行启动信息，
## 跑的人不知道是缺单例、还是自检没过、还是切场景被拒。
func _fatal(why: String) -> void:
	_say("致命：%s" % why)
	_finish(1)


func _finish(code: int) -> void:
	for line: String in _lines:
		print(line)
	quit(code)


# ------------------------------------------------------------------ 启动

## 走引擎那条路：落地 boot 主场景 → 自检 → 主菜单 →（按「开始新一局」）→ 编辑器 → 路线图。
##
## PET-90 起 boot 落在**主菜单**（并且不再替玩家开局），编辑器要玩家自己按进去 ——
## 所以这里不能像旧版那样光等 BoardView 出现，得先在主菜单上按那颗键。
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
	if not await _press_new_run():
		return false
	for _frame: int in 20:
		await process_frame
		if current_scene != null and TreeProbe.count_of(current_scene, "BoardView") == 1:
			break
	if current_scene == null or TreeProbe.count_of(current_scene, "BoardView") != 1:
		_say("致命：按了「开始新一局」也没走到编辑器（当前场景 %s）" % str(current_scene))
		return false
	_say("启动：boot 自检 → 主菜单 → 按「开始新一局」→ 编辑器")
	return true


## 等主菜单落地，然后按那颗按钮。**必须走按钮**：启动时不再有别人替玩家开局，
## 直接调 RunState.start_run() 就绕开了「主菜单真的接对了线」这件事（同 loop_smoke）。
func _press_new_run() -> bool:
	for _frame: int in 20:
		await process_frame
		var start: Button = _new_run_button()
		if start != null:
			start.pressed.emit()
			return true
	_say("致命：没有从 boot 走到主菜单（当前场景 %s）" % str(current_scene))
	return false


## 当前场景里那颗「开始新一局」。按**译文**找 —— 按钮上的字是 UiKit 翻好的。
func _new_run_button() -> Button:
	if current_scene == null:
		return null
	var wanted: String = TranslationServer.translate(KEY_NEW_RUN)
	for node: Node in TreeProbe.find_all(current_scene, "Button"):
		var button: Button = node
		if button.text == wanted:
			return button
	return null


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
	_say("启动：boot 自检 → 主菜单 → 开始新一局 → 编辑器 → MAP，羊皮卷 %s，图上 %d 个节点 / %d 条边" % [
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
	_say("M01：羊皮卷 %s，安全区 %s → 占 %.5f（契约 ≥ 0.73）" % [
		str(MapLayout.PAPER.size), str(MapLayout.SAFE_AREA.size),
		MapLayout.PAPER.size.x * MapLayout.PAPER.size.y
			/ (MapLayout.SAFE_AREA.size.x * MapLayout.SAFE_AREA.size.y)])
	_say("命中区：节点半径 %.0f 逻辑像素 → 直径 %.0f 设备像素（06 §1 下限 44）" % [
		MapView.NODE_RADIUS, MapView.NODE_RADIUS * 2.0 * _window_scale()])
	_text_widths()
	_say("当前位置那行：%s" % _status_text())


## G10：按钮文字用**真字体量出来的**宽度，不是估的 —— 估的尺跟真字形不是同一把。
func _text_widths() -> void:
	var font: Font = Fonts.ui_font()
	for row: Array in [["返回编辑器", MapLayout.BACK_RECT, ContractTheme.FONT_BODY],
			["继续", MapLayout.PRIMARY_RECT, ContractTheme.FONT_BUTTON]]:
		var text: String = TranslationServer.translate(row[0])
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(row[2])).x
		var box: Rect2 = row[1]
		_say("G10：按钮「%s」实排宽 %.1f ≤ 按钮宽 %.0f（%s）" % [text, width, box.size.x,
			"放得下" if width <= box.size.x else "放不下"])


func _edge_count() -> int:
	var total: int = 0
	for node: MapModel.MapNode in _model.nodes():
		total += node.next.size()
	return total


## 顶上那行按**落点**找（MapLayout.STATUS_RECT 是版式契约），不按文案前缀。
func _status_text() -> String:
	var want: Vector2 = MapLayout.STATUS_RECT.position
	for node: Node in TreeProbe.find_all(current_scene, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(want):
			return label.text
	return "（没找到）"


## 底部那句提示。同样按落点找（MapLayout.HINT_RECT）—— 按文案找会先撞上标题。
func _hint_text() -> String:
	var want: Vector2 = MapLayout.HINT_RECT.position
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


# ------------------------------------------------------------------ 像素证据

## 版面对不对，headless 那几条用例已经量过了；这里量的是**画上去之后**的像素。
## §4 里有两条只有像素答得了：G06 的兜底色一个像素都不许有、纸面到底落在哪个 Token 上。
func _pixel_proof(image: Image) -> void:
	var scale: float = float(image.get_width()) / MapLayout.SCREEN.x
	_say("同相机：截图 %d×%d = 960×540 的 %.2f 倍，铺满整屏（与编辑器那一屏同一台相机）"
		% [image.get_width(), image.get_height(), scale])

	# G06：无素材兜底帧 RGB(76,76,76) 的像素数必须恰好是 0。
	var fallback: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			if _is_fallback(image.get_pixel(x, y)):
				fallback += 1
	_say("G06：无素材兜底帧 RGB(76,76,76) 像素数 = %d（契约 = 0）" % fallback)

	# 纸面与纸边：§3 给纸面的是 GOLD_200，暖色材质层只能长在外圈那 8px 边带里。
	var face: Color = _modal(image, MapLayout.PAPER.grow(-MapLayout.PAPER_BAND))
	var band: Color = _modal(image, Rect2(MapLayout.PAPER.position,
		Vector2(MapLayout.PAPER.size.x, MapLayout.PAPER_BAND)))
	_say("M04：纸面众数色 %s，§3 的 GOLD_200 = %s（%s）；纸边带 %s（与纸面不同：%s）" % [
		_hex(face), _hex(MapParchment.paper_color()),
		"一致" if face.is_equal_approx(MapParchment.paper_color()) else "不一致",
		_hex(band), str(not band.is_equal_approx(face))])

	# M03：可见圆直径。挑一个干净的点（不可达 / 已访问都没有外扩圈），沿中心行量外缘。
	for state: MapNodePainter.State in [MapNodePainter.State.UNREACHABLE,
			MapNodePainter.State.VISITED]:
		var node: MapModel.MapNode = _node_in_state(state)
		if node == null:
			continue
		var center: Vector2 = MapLayout.PAPER.position \
			+ MapLayout.node_position(node.tier, node.column)
		_say("M03：%s 节点的可见圆实测直径 %.1f 逻辑像素（契约 40）"
			% [MapView.state_text(state), _diameter(image, center, face)])

	# M02：当前节点圆心是它的填充色 —— 四态各有各的填法，这是「填」那一半的像素证据。
	var here: MapModel.MapNode = _model.current()
	if here != null:
		var at: Vector2 = MapLayout.PAPER.position + MapLayout.node_position(here.tier, here.column)
		var seen: Color = _modal(image, Rect2(at - Vector2.ONE * 2.0, Vector2.ONE * 4.0))
		var want: Color = MapNodePainter.fill_color(MapNodePainter.State.CURRENT)
		_say("M02：当前节点圆心实测 %s，§3 的 NAVY_800 = %s（%s）"
			% [_hex(seen), _hex(want), "一致" if seen.is_equal_approx(want) else "不一致"])

	_walked_line(image)


## 走过的路线那一段：§2.2 给「走过 = 实线 2 + 8 长箭头」，可达与其余是虚线。
## 沿画笔**真正要画的那条折线**采样，数命中墨色的点数：实线应当全中，虚线（8/4 或 4/4）
## 只有约一半。于是「走过的路真的画出来了」是个数，不是看图说话 —— 图上全是虚线时，
## 光看截图分不清哪一条是走过的那条。
##
## 没中的点要把**落在什么颜色上**一并报出来：线端点裁在圆边（半径 20），而当前节点的金圈
## 外扩 4，那圈正好压在线的尾巴上。落在金色上是「圈压线」，与「线没画出来」是两回事。
func _walked_line(image: Image) -> void:
	var path: Array[int] = _model.path()
	if path.size() < 2:
		_say("走过的那段：本局只走过 %d 站，没得量" % path.size())
		return
	var from_node: MapModel.MapNode = _model.find(path[path.size() - 2])
	var to_node: MapModel.MapNode = _model.find(path[path.size() - 1])
	var ink: Color = Palette.get_color(MapNodePainter.EDGE_TOKEN[MapNodePainter.EdgeStyle.WALKED])
	var points: PackedVector2Array = MapNodePainter.edge_points(
		MapLayout.node_position(from_node.tier, from_node.column),
		MapLayout.node_position(to_node.tier, to_node.column), MapLayout.NODE_RADIUS,
		MapLayout.node_label_rect(from_node.tier, from_node.column),
		MapLayout.node_label_rect(to_node.tier, to_node.column))
	var hits: int = 0
	var missed: PackedStringArray = PackedStringArray()
	for index: int in points.size() - 1:
		for step: int in range(1, 4):
			var at: Vector2 = MapLayout.PAPER.position \
				+ points[index].lerp(points[index + 1], float(step) / 4.0)
			if _ink_at(image, at, ink):
				hits += 1
			else:
				missed.append(_hex(_modal(image, Rect2(at - Vector2.ONE, Vector2.ONE * 3.0))))
	_say("走过的那段：节点 %d → %d 沿折线取 %d 点，墨色命中 %d（走过实线应全中；虚线约一半）%s"
		% [from_node.id, to_node.id, (points.size() - 1) * 3, hits,
			"" if missed.is_empty() else "；%d 点没中，落在 %s" % [missed.size(), ", ".join(missed)]])


## 落点那一格是不是走过那条线的墨色。线宽 2 但折线避让后可能不落在整像素上，
## 所以看它上下左右各 1px —— 那不是放宽标准，是抗锯齿本身会让线心那一格混色。
func _ink_at(image: Image, at: Vector2, ink: Color) -> bool:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var x: int = int(round(at.x)) + dx
			var y: int = int(round(at.y)) + dy
			if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() \
					and image.get_pixel(x, y).is_equal_approx(ink):
				return true
	return false


func _node_in_state(state: MapNodePainter.State) -> MapModel.MapNode:
	for node: MapModel.MapNode in _model.nodes():
		if MapNodePainter.state_of(_model, node.id) == state:
			return node
	return null


## 一个节点在**中心行**上的外缘直径（逻辑像素）。从圆心往左右各走，最远那个「还不是纸」的像素
## 就是它的外缘 —— 普通节点的外圈宽 1，量出来正好是 §2.2 的 40。
func _diameter(image: Image, center: Vector2, paper: Color) -> float:
	var scale: float = float(image.get_width()) / MapLayout.SCREEN.x
	var row: int = int(center.y * scale)
	var middle: int = int(center.x * scale)
	# 只扫到半径 + 6：再往外就该撞上右边那行短名了（它在 center.x + 28）。
	var reach: int = int((MapLayout.NODE_RADIUS + 6.0) * scale)
	var first: int = middle
	var last: int = middle
	for step: int in reach + 1:
		if _differs(image, middle - step, row, paper):
			first = middle - step
		if _differs(image, middle + step, row, paper):
			last = middle + step
	return float(last - first + 1) / scale


static func _differs(image: Image, x: int, y: int, paper: Color) -> bool:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return false
	var color: Color = image.get_pixel(x, y)
	return maxf(maxf(absf(color.r - paper.r), absf(color.g - paper.g)),
		absf(color.b - paper.b)) > 0.04


## 无素材兜底色。按 8 位通道比，抗锯齿的邻域不算 —— 契约说的是「像素数 = 0」。
static func _is_fallback(color: Color) -> bool:
	return absi(int(round(color.r * 255.0)) - 76) == 0 \
		and absi(int(round(color.g * 255.0)) - 76) == 0 \
		and absi(int(round(color.b * 255.0)) - 76) == 0


## 一块区域里出现次数最多的颜色。纸面那种大片同色的地方，众数就是它的本色（抗锯齿的边不参与）。
static func _modal(image: Image, rect: Rect2) -> Color:
	var scale: float = float(image.get_width()) / MapLayout.SCREEN.x
	var tally: Dictionary = {}
	var best: Color = Color.BLACK
	var best_count: int = 0
	for y: int in range(int(rect.position.y * scale), int(rect.end.y * scale)):
		for x: int in range(int(rect.position.x * scale), int(rect.end.x * scale)):
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var color: Color = image.get_pixel(x, y)
			var count: int = int(tally.get(color, 0)) + 1
			tally[color] = count
			if count > best_count:
				best_count = count
				best = color
	return best


static func _hex(color: Color) -> String:
	return "#" + color.to_html(false)


# ------------------------------------------------------------------ 截图

func _capture(file_name: String) -> Image:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# 等这一帧真的画完再取纹理，否则拿到的是上一帧（刚点的那一下还没画上去）。
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		_say("致命：拿不到窗口纹理，%s 未生成" % file_name)
		return null
	var path: String = "%s/%s" % [OUTPUT_DIR, file_name]
	var error: Error = image.save_png(path)
	if error != OK:
		_say("致命：%s 写入失败（错误码 %d）" % [path, error])
		return null
	# 截图取的是**逻辑渲染目标**（960×540），不是窗口帧缓冲：stretch/mode=viewport 下引擎先按
	# 960×540 画，再整块放大贴到窗口上。所以「2×」只能靠 窗口 ÷ 视口 + scale_mode=integer 证明。
	_say("截图：%s %d×%d（逻辑渲染目标；scale_mode=%s）" % [
		path, image.get_width(), image.get_height(),
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode"))])
	return image


func _say(line: String) -> void:
	_lines.append("[capture] " + line)
