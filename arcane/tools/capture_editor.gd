## capture_editor.gd
## 职责：模块编辑器的**像素证据**采集 —— 真机跑一遍启动路径，用真手势拖卡，截图并打印实测数字。
## 所属系统：tools
## 依赖：tests/tree_probe.gd（只借它做子树查找）、BoardRenderer（读吸附回执）、boot.tscn 与编辑器场景
## 禁止：本文件不得改动任何产品代码；不得写 user:// 之外的状态；不得被游戏运行时引用（tools/* 已排除导出）。
##
## 为什么不是「摆好一个状态再截图」：那样截出来的是布置出来的画面，证明不了吸附真的发生。
## 这里走的是玩家那条路 —— push_input 真鼠标事件进 GUI → BoardView._gui_input → Snap.resolve。
## 于是截图里出现的参考线与角标，是这条链真的跑出来的产物。
##
## 09 §8 要求证据附「窗口是否可见 + 验证方式 + 实测数字」，三者都在打印里给出。
##
## 运行方式（**不要**加 --headless，截图需要真实渲染窗口）：
##   godot --path . --script res://tools/capture_editor.gd

extends SceneTree

const TreeProbe = preload("res://tests/tree_probe.gd")
const OUTPUT_DIR: String = "res://tests/output"

## 自由落点相对**锚点卡**的偏移。两条要求同时成立才算有效对照：
##   1. 两个分量都远大于吸附半径 18（这里 197 / 71），否则会被合法地吸走，证明不了「没有网格」；
##   2. 落点与锚点坐标之和**不是 24 的倍数**，一旦哪里偷偷量化过，实测余数会变成 0，当场露馅。
const FREE_OFFSET: Vector2 = Vector2(197.0, 71.0)
## 吸附对照：故意只偏离对齐边 5px。半径是 18，所以必须被拉回去。
const SNAP_OFFSET_Y: float = 5.0
## 主菜单上那颗按钮的文案 key。PET-90 起 boot 落在主菜单，编辑器要玩家按一下才去。
const KEY_NEW_RUN: String = "开始新一局"

var _run: Node = null
var _editor: Node = null
var _board_view: Node = null
var _board: BoardModel = null
## 指针当前的**窗口**坐标。松手要用它，所以得记着。
var _pointer: Vector2 = Vector2.ZERO
var _lines: Array[String] = []


func _initialize() -> void:
	# 与 run_tests 同一个理由：--script 入口在 _initialize() 时 Autoload 还没 _ready()，
	# root 也还没进树。等两帧，世界才和「引擎正常启动一局」一致。
	await process_frame
	await process_frame
	_run = root.get_node_or_null(^"RunState")
	var flow: Node = root.get_node_or_null(^"GameFlow")
	if _run == null or flow == null:
		_say("致命：RunState / GameFlow 单例不在树里")
		quit(1)
		return

	if not await _boot_to_editor():
		quit(1)
		return
	_place_two_cards()
	_link_them()
	await _capture_free_placement()
	await _capture_snapping()
	_report()
	for line: String in _lines:
		print(line)
	quit(0)


# ------------------------------------------------------------------ 启动

## 走引擎那条路：落地 boot 主场景 → 自检 → 主菜单 →（按「开始新一局」）→ 编辑器。
func _boot_to_editor() -> bool:
	var packed: PackedScene = load("res://scenes/boot.tscn")
	if packed == null:
		_say("致命：boot.tscn 加载不了")
		return false
	var boot: Node = packed.instantiate()
	root.add_child(boot)
	# 不补这一步的话 change_scene_to_file() 不会回收 boot（它只回收 current_scene）。
	current_scene = boot
	_say("窗口：%s，窗口尺寸 %s，视口 %s" % [
		DisplayServer.get_name(),
		str(DisplayServer.window_get_size()),
		str(root.get_visible_rect().size),
	])
	if not await _press_new_run():
		return false
	for _frame: int in 20:
		await process_frame
		if current_scene != null and TreeProbe.count_of(current_scene, "BoardView") == 1:
			break
	_editor = current_scene
	if TreeProbe.count_of(_editor, "BoardView") != 1:
		_say("致命：按了「开始新一局」也没走到编辑器（当前场景 %s）" % _editor.name)
		return false
	_board_view = TreeProbe.find_all(_editor, "BoardView")[0]
	_board = _run.board()
	_say("启动：boot 自检 → 主菜单 → 按「开始新一局」→ 编辑器，画布 %s，书页上 %d 张卡" % [
		str(_board_view.size), _board.cards().size()])
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


# ------------------------------------------------------- 摆两张卡 + 连一条丝线

## 真实路径：点仓库里的卡位。不直接写 model。
func _place_two_cards() -> void:
	var chips: Array[Node] = TreeProbe.find_all(_editor, "CardChip")
	var picked: int = 0
	for chip: Node in chips:
		if picked >= 2:
			break
		chip.chosen.emit(chip.card_id)
		picked += 1
	_say("点卡位 %d 次 → 书页上 %d 张卡" % [picked, _board.cards().size()])


## 真实路径：从一张卡的输出接口拖到另一张的输入接口。
func _link_them() -> void:
	if _board.cards().size() < 2:
		return
	var source: BoardModel.PlacedCard = _board.cards()[0]
	var target: BoardModel.PlacedCard = _board.cards()[1]
	# 接口画在卡片边缘上，而 Rect2.has_point() **不含右/下边界**：正对边缘按下去会找不到卡。
	# 真人是从圆点里侧按的（接口命中半径 16，圆点半径 6），这里往里让 6px。
	var from: Vector2 = _to_window(BoardView.output_port(source) - Vector2(6.0, 0.0))
	var to: Vector2 = _to_window(BoardView.input_port(target) + Vector2(6.0, 0.0))
	_mouse_press(from)
	_mouse_move(from.lerp(to, 0.5), true)
	_mouse_move(to, true)
	var aiming: bool = _renderer().link_from == source.uid
	_mouse_release(to)
	_say("从卡 %d 的输出接口拖到卡 %d 的输入接口 → 起手命中接口=%s、丝线 %d 条" % [
		source.uid, target.uid, str(aiming), _board.links().size()])


# ------------------------------------------------------------ 证据一：没有网格

## 把第二张卡拖到一个刻意「不正」的坐标。它必须**原样停在那里**。
##
## 这一张同时是 PET-87 §2 的证据：松手之后卡 [1] 是**选中**（金色轮廓 + 抬起一档的底板），
## 指针再移到卡 [0] 上，卡 [0] 变成**焦点**（四角浅蓝细角标）。一帧里两种状态同时在场 ——
## 这正是「语义与配色可分」要证明的事；分不开的话这两个标记会长成一个样子。
func _capture_free_placement() -> void:
	if _board.cards().size() < 2:
		return
	var card: BoardModel.PlacedCard = _board.cards()[1]
	var origin: Vector2 = _board_view.play_origin()
	var reach: Vector2 = origin + _board_view.play_limit()
	var wanted: Vector2 = _free_target(card, reach)
	_say("自由落点对照：画布可放范围 %s … %s，目标 %s（带 .5 亚像素）" % [
		str(origin), str(reach), str(wanted)])
	if not await _drag_card_to(card, wanted, false):
		await _capture("editor_free.png")
		return
	var landed: Vector2 = _board.find_card(card.uid).position
	# 这一行必须在**松手之前**读：_on_release() 会把参考线与 snapped 一起清掉，
	# 松手后再读永远得到 false —— 那正是上一版把「被吸走了」误报成「没吸附」的原因。
	_say("自由落点：请求 %s → 实际 %s（差 %s），按住时的 snapped=%s" % [
		str(wanted), str(landed), str(landed - wanted), str(_snapped())])
	_say("自由落点余数：x %% 24 = %.3f，y %% 24 = %.3f（非 0 = 没有被量化到网格上）" % [
		fmod(landed.x, 24.0), fmod(landed.y, 24.0)])
	await _release()
	await _show_focus_beside_selection(card)
	await _capture("editor_free.png")


## 松手之后指针移到**另一张**卡上：选中留在刚放好的那张，焦点走到这张。
## 走的是真实手势（移动事件，不按下），因此截图里出现的角标是这条链跑出来的。
func _show_focus_beside_selection(placed: BoardModel.PlacedCard) -> void:
	var other: BoardModel.PlacedCard = _board.cards()[0]
	var centre: Vector2 = other.position + CardFace.SIZE * 0.5
	_mouse_move(_to_window(centre), false)
	await process_frame
	await process_frame
	_say("状态分层对照：选中 uid=%d（金色轮廓）、焦点 uid=%d（浅蓝角标），两者同帧在场=%s" % [
		_renderer().selected_uid, _renderer().focus_uid,
		str(_renderer().selected_uid == placed.uid and _renderer().focus_uid == other.uid)])


## 在画布内找一个「吸附不会碰它」的落点 —— 不靠手算边距，直接问 Snap 本人。
##
## 为什么是「挑四角」而不是「按步长扫整块画布」：72px 的卡三条边彼此相隔 36，
## 而吸附半径是 18，两者一叠加就把画布封掉了大半，真正空着的只剩贴着画布边缘的一条窄带。
## 按固定步长扫很容易整条跨过去（上一版就整整扫空了一圈，误报「整块画布都在吸附半径内」）。
## 四角（内缩 0.5）必然落在窄带里；带 .5 的亚像素偏移也是刻意的 —— 网格会把坐标吃掉，吸附不会。
##
## 四角取**合法范围**（play_origin … play_origin + play_limit）而不是控件矩形的角：
## 落在合法范围之外会被 clamp_to_play 夹回来，于是「请求 → 实际」的差值变成夹取造成的，
## 那一栏本用来证明「没被吸走」，混进夹取就什么也证明不了。
func _free_target(card: BoardModel.PlacedCard, reach: Vector2) -> Vector2:
	var obstacles: Array[Rect2] = []
	for other: BoardModel.PlacedCard in _board.cards():
		if other.uid != card.uid:
			obstacles.append(Rect2(other.position, CardFace.SIZE))
	var origin: Vector2 = _board_view.play_origin()
	# 顺序即优先级：两个**靠右**的角排在前面。§3 报的是「右上角那张卡的输出接口被裁切边
	# 切掉半个圆」，而输出接口长在卡的右缘 —— 落点取靠右的角，这条缺陷才在同一侧被截进画面。
	# 剩下的问题只是「这几个角里哪个吸附不会碰」：取第一个不被吸走的，不另设排序依据。
	var corners: Array[Vector2] = [
		Vector2(reach.x - 0.5, origin.y + 0.5), reach - Vector2(0.5, 0.5),
		origin + Vector2(0.5, 0.5), Vector2(origin.x + 0.5, reach.y - 0.5),
	]
	for corner: Vector2 in corners:
		if not Snap.resolve(Rect2(corner, CardFace.SIZE), obstacles).snapped:
			return corner
	_say("警告：画布四角全在吸附半径内，退回右上角")
	return corners[0]


# ------------------------------------------------------------ 证据二：真的吸附

## 把卡片拖到离对齐边 5px 的地方 —— 必须被拉正，并且画出参考线。
func _capture_snapping() -> void:
	if _board.cards().size() < 2:
		return
	var anchor: BoardModel.PlacedCard = _board.cards()[0]
	var card: BoardModel.PlacedCard = _board.cards()[1]
	var wanted: Vector2 = Vector2(anchor.position.x + 190.0, anchor.position.y + SNAP_OFFSET_Y)
	if not await _drag_card_to(card, wanted, false):
		await _capture("editor_snap.png")
		return
	var landed: Vector2 = _board.find_card(card.uid).position
	_say("吸附对照：请求 y=%.1f（= 锚点 y %.1f + %.1f）→ 实际 y=%.1f" % [
		wanted.y, anchor.position.y, SNAP_OFFSET_Y, landed.y])
	_say("吸附结果：snapped=%s，竖向参考线 %d 条、横向 %d 条" % [
		str(_snapped()), _guides_v().size(), _guides_h().size()])
	_say("吸附把偏差 %.1fpx 收成了 %.1fpx" % [
		absf(wanted.y - anchor.position.y), absf(landed.y - anchor.position.y)])
	# §2 的「范围」：每条参考线该画多长由 Snap 按**相关的那两张卡**算出，不是画布通高。
	# 卡高 72、并集最多两张卡的跨度，因此这里的数必须远小于画布高 —— 打印出来给人对照。
	var renderer: BoardRenderer = _renderer()
	for index: int in renderer.spans_v.size():
		_say("竖向参考线 x=%.1f 只跨 y %.1f…%.1f（长 %.1f，画布高 %.1f）" % [
			renderer.guides_v[index], renderer.spans_v[index].x, renderer.spans_v[index].y,
			renderer.spans_v[index].y - renderer.spans_v[index].x, _board_view.size.y])
	for index: int in renderer.spans_h.size():
		_say("横向参考线 y=%.1f 只跨 x %.1f…%.1f（长 %.1f）" % [
			renderer.guides_h[index], renderer.spans_h[index].x, renderer.spans_h[index].y,
			renderer.spans_h[index].y - renderer.spans_h[index].x])
	await _capture("editor_snap.png")
	await _release()


# ------------------------------------------------------------------ 手势

## 用**真鼠标事件**把一张卡拖到目标坐标。release = false 时保持按住，
## 这样参考线与角标留在画面上等着被截进去。
func _drag_card_to(card: BoardModel.PlacedCard, wanted: Vector2, release: bool = true) -> bool:
	var grab: Vector2 = card.position + CardFace.SIZE * 0.5
	var start: Vector2 = _to_window(grab)
	var finish: Vector2 = _to_window(wanted + CardFace.SIZE * 0.5)
	# 命中测试用**视口**坐标（控件矩形在视口空间），推送事件用**窗口**坐标 —— 两者差一个倍数。
	_say("按下前：抓取点（视口）%s，该点最上层控件 = %s" % [
		str(grab + _board_view.global_position), _hit_test(grab + _board_view.global_position)])
	_mouse_press(start)
	var grabbed: bool = int(_board_view.get(&"_drag_uid")) == card.uid
	_say("按下后：drag_uid=%s、selected_uid=%s" % [
		str(_board_view.get(&"_drag_uid")), str(_board_view.selected_uid())])
	if not grabbed:
		# 手势没抓住卡片就是没抓住 —— 绝不能让下面的「实测数字」看起来像一次成功的拖动。
		_say("手势未生效：按下没有抓住卡 %d，本次拖动作废" % card.uid)
		_mouse_release(start)
		await process_frame
		return false
	# 分两步动：GUI 的拖拽判定要先收到一次「按住后的移动」。
	_mouse_move(start.lerp(finish, 0.5), true)
	_mouse_move(finish, true)
	if release:
		_mouse_release(finish)
	_pointer = finish
	await process_frame
	await process_frame
	return true


func _mouse_press(at: Vector2) -> void:
	# 先把指针「移」过去，再按下。合成输入必须自己补这一步：Viewport 只有收到过一次移动事件
	# 才认为指针在窗口内（gui.mouse_in_viewport），在那之前按下的那一下会被整条丢掉 ——
	# 表现就是命中测试明明选中了画布，_gui_input 却一次都没被调用。
	_mouse_move(at, false)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event)


func _mouse_move(to: Vector2, held: bool) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = to
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event)


func _mouse_release(at: Vector2) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = at
	root.push_input(event)


## 松开当前按住的那一下（在 _pointer 处）。截图要在按住状态下取，所以松手得由调用方显式做。
func _release() -> void:
	_mouse_release(_pointer)
	await process_frame
	await process_frame


## 画布局部坐标 → **窗口**坐标。
##
## 注意这里必须乘放大倍数，不能直接给视口坐标：_root.push_input()_ 收到的是**窗口**坐标，
## 引擎随后按内容缩放变换把它换算进 960×540 的视口。给视口坐标的话，事件会被再除一次 2，
## 落点跑到画布左上角去 —— 表现是命中测试明明选中了画布，_gui_input 却在错误的位置上找卡。
func _to_window(at: Vector2) -> Vector2:
	return (_board_view.global_position + at) * _window_scale()


## 窗口 ÷ 视口的整数倍率（960×540 → 1920×1080 即 2）。宽高比一致，没有黑边偏移。
func _window_scale() -> float:
	return float(DisplayServer.window_get_size().x) / root.get_visible_rect().size.x


## 这个视口坐标上最上层的、会吃鼠标的控件是谁 —— 事件没落到画布上时，靠它定位是谁挡着。
## 绘制顺序 = 树顺序，后加的盖在上面，所以倒着找第一个命中的。
func _hit_test(at: Vector2) -> String:
	var nodes: Array[Node] = TreeProbe.descendants(_editor)
	for index: int in range(nodes.size() - 1, -1, -1):
		var control: Control = nodes[index] as Control
		if control == null or control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if not control.is_visible_in_tree():
			continue
		if control.get_global_rect().has_point(at):
			return "%s(%s) rect=%s filter=%d" % [control.name,
				TreeProbe.script_class(control), str(control.get_global_rect()),
				control.mouse_filter]
	return "（没有控件接住）"


# ------------------------------------------------------------------ 截图

func _capture(file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# 等这一帧真的画完再取纹理，否则拿到的是上一帧（参考线还没画上去）。
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
	# 截图取的是**逻辑渲染目标**（960×540），不是窗口帧缓冲：stretch/mode=viewport 下
	# 引擎先按 960×540 画，再整块放大贴到 1920×1080 的窗口上。所以「2×」这件事不能靠
	# 数像素证明，只能靠窗口尺寸 ÷ 视口尺寸 + scale_mode=integer 这两条配置事实。
	var window: Vector2i = DisplayServer.window_get_size()
	_say("截图：%s %d×%d（逻辑渲染目标；窗口 %d×%d ÷ 视口 %d×%d = %.2f，scale_mode=%s）" % [
		path, image.get_width(), image.get_height(),
		window.x, window.y,
		int(root.get_visible_rect().size.x), int(root.get_visible_rect().size.y),
		float(window.x) / root.get_visible_rect().size.x,
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode"))])


# ------------------------------------------------------------------ 小工具

## 绘制状态（吸附回执、指点、选中 / 焦点 uid）由 BoardRenderer 持有 —— 这是采集脚本，
## 读它比在界面上「看」更准。拖动中的 uid 仍留在 BoardView（它要写回模型，不算绘制状态）。
func _renderer() -> BoardRenderer:
	return _board_view.renderer()


func _snapped() -> bool:
	return _renderer().snapped


func _guides_v() -> Array:
	return _renderer().guides_v


func _guides_h() -> Array:
	return _renderer().guides_h


func _say(line: String) -> void:
	_lines.append("[capture] " + line)


func _report() -> void:
	_say("书页终态：%d 张卡、%d 条丝线" % [_board.cards().size(), _board.links().size()])
