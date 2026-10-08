## port_hit_smoke.gd
## 职责：PET-97 #1 的端到端验收 —— 输出端口 Ø32 的**中心 / 外侧**都起得手（真鼠标事件走
##       Viewport → BoardView._gui_input），并把线落进目标卡**输入端口的外半圆**。
## 所属系统：tests
## 依赖：TreeProbe, RunState（经 /root 取）, BoardModel, BoardView, EditorLayout
## 禁止：本文件不得按「开始战斗」（那会真的换屏，把 GameFlow 留给后面的用例收拾）。
##
## 为什么必须入树 + 真事件：PET-95 量到的正是「起手失效」——它取决于两件只有真机才验得了的事：
##   ① 命中判定的**先后**（卡身 vs 端口）：端口中心正好落在卡身边缘上，先判卡身就判不到；
##   ② 画布控件真的收得到指针事件（尺寸 / 位置 / mouse_filter 三者都对才收得到）。
## 光调一遍纯函数（test_contract_closure 里那一组）证明不了这两件事。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")
const SCREEN_PATH: String = "res://scenes/editor.tscn"

var _tree: SceneTree = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("port_hit_smoke")
	_tree = tree
	var run_state: Node = tree.root.get_node_or_null(^"RunState")
	if not ctx.check(run_state != null, "RunState 单例在（书页归这一局）"):
		return
	var screen: Control = await _open(ctx)
	if screen == null:
		return
	var canvas: BoardView = _first(screen, "BoardView") as BoardView
	if not ctx.check(canvas != null, "编辑器里有一块书页画布"):
		return
	var board: BoardModel = run_state.board()
	# 书页是这一局的共享对象，本用例只在上面临时摆两张卡与一条线 —— 收尾按快照还原，
	# 不留痕迹给后面的用例（defeat_smoke 就钉着「书页上一条法术都没连」）。
	var before: Dictionary = board.snapshot()
	var cards_before: int = board.cards().size()
	var links_before: int = board.links().size()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(60.0, 60.0))
	var spell: BoardModel.PlacedCard = board.add_card(&"ab_metal", Vector2(300.0, 60.0))
	canvas.queue_redraw()
	await _tree.process_frame
	_check_center(canvas, core, ctx)
	await _check_outer(ctx, canvas, core)
	await _check_miss(ctx, canvas, core)
	await _check_drop(ctx, canvas, board, core, spell)
	await _check_body_press(ctx, canvas, core)
	board.restore(before)
	ctx.equal(board.cards().size(), cards_before, "收尾：书页按快照还原，本用例不留卡")
	ctx.equal(board.links().size(), links_before, "收尾：本用例不留线")
	screen.queue_free()
	await _tree.process_frame


## ① 端口**正中**：它在卡身右缘上（半开区间的 has_point 判它在外面），旧口径在这里判 miss。
func _check_center(canvas: BoardView, core: BoardModel.PlacedCard, ctx: RefCounted) -> void:
	var center: Vector2 = BoardView.output_port(core)
	ctx.check(not BoardView.card_rect(core).has_point(center),
		"端口正中确实落在卡身之外（这条不成立的话下面就是空断言）")
	_push(_mouse(canvas, center, true))
	ctx.equal(canvas.renderer().link_from, core.uid, "端口**正中**按下去进入连线态")
	_push(_mouse(canvas, center, false))
	ctx.equal(canvas.renderer().link_from, 0, "抬起后连线态结束")


## ② 端口**外侧**半圆（卡身之外 15px）。③ 圆外 1px 不算。
func _check_outer(ctx: RefCounted, canvas: BoardView, core: BoardModel.PlacedCard) -> void:
	var outer: Vector2 = BoardView.output_port(core) + Vector2(BoardView.PORT_HIT_RADIUS - 1.0, 0.0)
	ctx.check(not BoardView.card_rect(core).has_point(outer), "外侧那一点也在卡身之外")
	_push(_mouse(canvas, outer, true))
	ctx.equal(canvas.renderer().link_from, core.uid, "端口**外侧**按下去同样进入连线态")
	_push(_mouse(canvas, outer, false))
	ctx.equal(canvas.renderer().link_from, 0, "抬起后连线态结束")


func _check_miss(ctx: RefCounted, canvas: BoardView, core: BoardModel.PlacedCard) -> void:
	var outside: Vector2 = BoardView.output_port(core) \
		+ Vector2(BoardView.PORT_HIT_RADIUS + 1.0, 0.0)
	_push(_mouse(canvas, outside, true))
	ctx.equal(canvas.renderer().link_from, 0, "反向对照：圆周外 1px 不起手")
	_push(_mouse(canvas, outside, false))


## ④ 落线：从核心卡的输出口拖到法术卡**输入口的外半圆**（同样在卡身之外）。
func _check_drop(ctx: RefCounted, canvas: BoardView, board: BoardModel,
		core: BoardModel.PlacedCard, spell: BoardModel.PlacedCard) -> void:
	var links: Array = []
	canvas.link_requested.connect(func(from_uid: int, to_uid: int) -> void:
		links.append([from_uid, to_uid]))
	var drop: Vector2 = BoardView.input_port(spell) - Vector2(BoardView.PORT_HIT_RADIUS - 1.0, 0.0)
	ctx.check(not BoardView.card_rect(spell).has_point(drop), "落点也在卡身之外（输入口外半圆）")
	_push(_mouse(canvas, BoardView.output_port(core), true))
	_push(_mouse(canvas, drop, false))
	ctx.equal(links.size(), 1, "落到输入口外半圆上，发出一次 link_requested")
	if links.size() == 1:
		ctx.equal(links[0][0], core.uid, "起点是核心卡")
		ctx.equal(links[0][1], spell.uid, "落点是那张法术卡")
	ctx.equal(board.links().size(), 1, "编辑器把这条丝线真的连上了（走的仍是它自己的校验）")
	ctx.equal(canvas.renderer().link_from, 0, "落线后连线态结束")


## ⑤ 反向对照：离端口远的**卡身正中**按下去是拖卡，不是连线。
func _check_body_press(ctx: RefCounted, canvas: BoardView, core: BoardModel.PlacedCard) -> void:
	var middle: Vector2 = BoardView.card_rect(core).get_center()
	_push(_mouse(canvas, middle, true))
	ctx.equal(canvas.renderer().link_from, 0, "反向对照：卡身正中起手是拖动而不是连线")
	_push(_mouse(canvas, middle, false))


# ---------------------------------------------------------------- 工具

func _open(ctx: RefCounted) -> Control:
	var scene: PackedScene = load(SCREEN_PATH)
	if not ctx.check(scene != null, "%s 可加载" % SCREEN_PATH):
		return null
	var screen: Control = scene.instantiate()
	_tree.root.add_child(screen)
	await _tree.process_frame
	return screen


func _first(root: Node, kind: String) -> Node:
	var found: Array[Node] = TreeProbe.find_all(root, kind)
	return found[0] if not found.is_empty() else null


## 走真实的输入路径：过一个 Viewport，而不是直接叫控件的方法。
func _push(event: InputEvent) -> void:
	_tree.root.push_input(event)


## 画布**局部坐标** → 窗口坐标。屏幕铺满根视口，故先过全局变换换成屏坐标，
## 再乘拉伸比（与 tests/integration/map_view_smoke.gd 同一口径）。
func _window_at(canvas: BoardView, local: Vector2) -> Vector2:
	return (canvas.get_global_transform() * local) * _window_scale()


func _mouse(canvas: BoardView, local: Vector2, pressed: bool) -> InputEventMouseButton:
	var at: Vector2 = _window_at(canvas, local)
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


func _window_scale() -> float:
	var canvas_width: float = _tree.root.get_visible_rect().size.x
	var window_width: float = float(DisplayServer.window_get_size().x)
	if canvas_width <= 0.0 or window_width <= 0.0:
		return 1.0
	return window_width / canvas_width
