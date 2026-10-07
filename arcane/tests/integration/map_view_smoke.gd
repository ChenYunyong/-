## map_view_smoke.gd
## 职责：路线图交互的端到端验收 —— 只有可选节点点得动、走不了的点了一点状态都不动、
##       命中区够大、鼠标与触摸走同一条路、退出再进来走过的痕迹还在。
## 所属系统：tests
## 依赖：TreeProbe, MapView, MapModel, MapLayout, MapNodePainter, RunState（经 /root 取）
## 禁止：本文件不得按「继续」—— 那会真的换屏，把 GameFlow 留给后面的用例收拾。
##
## 为什么要入树：控件是不是**真的收得到输入**（尺寸、位置、mouse_filter）只有进了树才算数，
## 光调一遍处理函数只能证明逻辑对。两者都测：几何与事件解码走真事件，
## 「状态一个字节都不动」这类断言走逐条对照。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCREEN_PATH: String = "res://scenes/map.tscn"
## 按钮文案的 key。按钮上的字是 UiKit 用 TranslationServer 翻好的，故按译文找。
const KEY_CONTINUE: String = "继续"
## 触控下限 44 **设备像素**，窗口 / 画布 = 2 → 22 逻辑像素（docs/06 §1）。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0

var _tree: SceneTree = null
var _run: Node = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("map_view_smoke")
	_tree = tree
	_run = tree.root.get_node_or_null(^"RunState")
	if not ctx.check(_run != null, "RunState 单例在，可测「重进界面路径复原」"):
		return
	_check_event_decoding(ctx)

	var screen: Control = await _open(ctx)
	if screen == null:
		return
	var model: MapModel = _run.map()
	var view: MapView = _first_of(screen, "MapView") as MapView
	ctx.check(view != null, "地图屏里有一张 MapView")
	if view == null:
		return
	_check_wiring(ctx, screen, view)
	_check_hit_area(ctx, model)
	_check_selectable_advances(ctx, model, view)
	_check_real_input(ctx, screen, model)
	_check_walked_is_inert(ctx, screen, model, view)
	await _check_reentry(ctx, screen, model)

# ---------------------------------------------------------------- 事件解码

## 左键按下与触摸按下走同一条判定路径；别的输入一概不算「按了一下」。
func _check_event_decoding(ctx: RefCounted) -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(7.0, 8.0)
	ctx.check(MapView.is_press(click), "左键按下算一次按")
	ctx.equal(MapView.event_position(click), Vector2(7.0, 8.0), "鼠标的坐标取自 position")

	# 反向对照：抬起、右键、移动都不算 —— 否则一次点击会被当成两次操作。
	click.pressed = false
	ctx.check(not MapView.is_press(click), "左键抬起不算按")
	click.pressed = true
	click.button_index = MOUSE_BUTTON_RIGHT
	ctx.check(not MapView.is_press(click), "右键不算按")
	ctx.check(not MapView.is_press(InputEventMouseMotion.new()), "移动不算按")

	var touch: InputEventScreenTouch = InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = Vector2(5.0, 6.0)
	ctx.check(MapView.is_press(touch), "触摸按下算一次按（06 §10 规则 6：触摸也要能操作）")
	ctx.equal(MapView.event_position(touch), Vector2(5.0, 6.0), "触摸的坐标取自 position")
	touch.pressed = false
	ctx.check(not MapView.is_press(touch), "触摸抬起不算按")


# ---------------------------------------------------------------- 装配与几何

## 图与羊皮卷同尺寸同位置 —— 于是 _draw() 里的坐标就是 MapLayout 那套局部坐标，
## 测试断言的落点与真机画出来的落点是同一组数。
func _check_wiring(ctx: RefCounted, screen: Control, view: MapView) -> void:
	ctx.equal(view.position, MapLayout.parchment().position, "图和羊皮卷左上角对齐")
	ctx.equal(view.size, MapLayout.parchment().size, "图和羊皮卷同尺寸")
	ctx.check(view.mouse_filter == Control.MOUSE_FILTER_STOP, "图自己吃鼠标事件（不然点不到）")
	ctx.check(_status_text(screen) != "", "顶上那行写着当前位置")
	ctx.check(_continue_button(screen) != null, "底部有「继续」")
	ctx.equal(_continue_button(screen).disabled, true, "还没选好时「继续」是灰的")


## 命中区：正中、边缘之内、边缘之外各量一次。
## 命中的圆**就是**画出来那个圆（MapView.NODE_RADIUS），所以「看着没中却中了」不存在。
func _check_hit_area(ctx: RefCounted, model: MapModel) -> void:
	var first: MapModel.MapNode = model.selectable()[0]
	var at: Vector2 = MapLayout.node_position(first.tier, first.column)
	var radius: float = MapView.NODE_RADIUS
	ctx.equal(MapView.node_at(model, at), first.id, "节点正中命中它自己")
	ctx.equal(MapView.node_at(model, at + Vector2(-(radius - 1.0), 0.0)), first.id,
		"圆边之内还算命中")
	ctx.equal(MapView.node_at(model, at + Vector2(-(radius + 1.0), 0.0)), -1,
		"出了那个圆就不再算它")
	ctx.equal(MapView.node_at(model, Vector2(0.0, 0.0)), -1, "空白处不命中任何节点")
	ctx.check(radius * 2.0 * DEVICE_SCALE >= MIN_TOUCH_DEVICE_PX,
		"命中区直径 %.0f 设备像素 ≥ %.0f 下限" % [radius * 2.0 * DEVICE_SCALE, MIN_TOUCH_DEVICE_PX])


# ---------------------------------------------------------------- 点得动 / 点不动

## 点亮的节点：模型真的走过去，并且发出 node_chosen（带着节点类型）。
func _check_selectable_advances(ctx: RefCounted, model: MapModel, view: MapView) -> void:
	var chosen: Array = []
	view.node_chosen.connect(func(kind: MapModel.Kind) -> void: chosen.append(kind))
	var first: MapModel.MapNode = model.selectable()[0]
	view.press(MapLayout.node_position(first.tier, first.column))
	ctx.equal(chosen.size(), 1, "可选节点点一下就发一次 node_chosen")
	if chosen.size() == 1:
		ctx.equal(chosen[0], first.kind, "带上的是这个节点的类型")
	ctx.equal(model.current_id(), first.id, "走过的那里成了当前节点")
	ctx.equal(view.rejected_id(), -1, "成功走一步之后没有「走不了」的痕迹")


## 真事件走一遍：这一条问的是「控件到底收不收得到输入」，不是逻辑。
## 左键与触摸各推一次真的 —— 06 §10 规则 6 要求两条路都能操作，而它们只共用 `press()`
## 之后的那半段，前面的事件解码各走各的。
func _check_real_input(ctx: RefCounted, screen: Control, model: MapModel) -> void:
	var before: int = model.current_id()
	var by_mouse: MapModel.MapNode = model.selectable()[0]
	_push(_mouse_at(_to_window(screen, by_mouse)))
	ctx.equal(model.current_id(), by_mouse.id,
		"从真实鼠标事件点过去也能走（前一站 %d → 现在 %d）" % [before, model.current_id()])

	var by_touch: MapModel.MapNode = model.selectable()[0]
	_push(_touch_at(_to_window(screen, by_touch)))
	ctx.equal(model.current_id(), by_touch.id, "从真实触摸事件点过去也能走")
	ctx.check(model.path().size() >= 3, "这段路已经走过 %d 站（痕迹够长，画得出走过的路线）"
		% model.path().size())


## 走不了的两个：当前节点（= 已访问）与更早走过的。点它们必须**一个字节都不动**。
func _check_walked_is_inert(ctx: RefCounted, screen: Control, model: MapModel,
		view: MapView) -> void:
	var rejected: Array = []
	view.node_rejected.connect(func(state: MapNodePainter.State) -> void: rejected.append(state))
	var chosen: Array = []
	view.node_chosen.connect(func(kind: MapModel.Kind) -> void: chosen.append(kind))

	var here: MapModel.MapNode = model.current()
	var path_before: Array[int] = model.path()
	view.press(MapLayout.node_position(here.tier, here.column))
	ctx.equal(rejected.size(), 1, "点当前节点给一次「走不了」的反馈")
	if rejected.size() == 1:
		ctx.equal(rejected[0], MapNodePainter.State.CURRENT, "反馈说的是「你就在这儿」")
	ctx.equal(view.rejected_id(), here.id, "被拒的是那个节点（界面据此画红圈）")
	ctx.equal(model.path(), path_before, "点当前节点：走过的序列没变")
	ctx.equal(model.current_id(), here.id, "点当前节点：当前位置没变")

	# 触摸那条路：同一个走不了的节点，结果必须一模一样（与上面鼠标那次同一个换算口径）。
	_push(_touch_at(_to_window(screen, here)))
	ctx.equal(rejected.size(), 2, "触摸点同一个节点同样给反馈（两条路一致）")
	ctx.equal(model.path(), path_before, "触摸点当前节点：走过的序列还是没变")

	# 再往前走一步，上一站退成「已访问」，点它同样点不动。
	var next_node: MapModel.MapNode = model.selectable()[0]
	view.press(MapLayout.node_position(next_node.tier, next_node.column))
	ctx.equal(model.current_id(), next_node.id, "再走一步到了下一站")
	ctx.equal(chosen.size(), 1, "这一步也发了一次 node_chosen")

	var walked: MapModel.MapNode = model.find(here.id)
	ctx.equal(MapNodePainter.state_of(model, walked.id), MapNodePainter.State.VISITED,
		"上一站现在是「已访问」")
	var frozen: Array[int] = model.path()
	view.press(MapLayout.node_position(walked.tier, walked.column))
	ctx.equal(rejected.size(), 3, "点已访问的节点也有反馈")
	if rejected.size() == 3:
		ctx.equal(rejected[2], MapNodePainter.State.VISITED, "反馈说的是「已经走过了」")
	ctx.equal(model.path(), frozen, "点已访问的节点：走过的序列没变")
	ctx.equal(model.current_id(), next_node.id, "点已访问的节点：当前位置没变")
	ctx.equal(chosen.size(), 1, "点走不了的节点一个 node_chosen 都不发")

	# 不可达（还没走到的远处）同理 —— 连反馈都给了，状态还是不动。
	var far: MapModel.MapNode = model.nodes_in_tier(MapModel.TIERS - 1)[0]
	view.press(MapLayout.node_position(far.tier, far.column))
	ctx.equal(rejected.size(), 4, "点不可达的节点也有反馈")
	if rejected.size() == 4:
		ctx.equal(rejected[3], MapNodePainter.State.UNREACHABLE, "反馈说的是「走不到」")
	ctx.equal(model.path(), frozen, "点不可达的节点：走过的序列没变")
	ctx.equal(model.current_id(), next_node.id, "点不可达的节点：当前位置没变")


# ---------------------------------------------------------------- 重进界面

## 退出这一屏再进来，走过的痕迹与当前位置都要还在 —— 路线属于这一局（RunState），
## 不属于这一屏。所以这里的断言是两次访问**画出来的东西一样**。
func _check_reentry(ctx: RefCounted, screen: Control, model: MapModel) -> void:
	var path_before: Array[int] = model.path()
	var status_before: String = _status_text(screen)
	var current_before: int = model.current_id()
	ctx.check(current_before >= 0, "离开之前确实走在路上（否则下面那条是空断言）")

	screen.queue_free()
	await _tree.process_frame

	var again: Control = await _open(ctx)
	if again == null:
		return
	var view: MapView = _first_of(again, "MapView") as MapView
	ctx.equal(_run.map().path(), path_before, "重进之后走过的序列原样还在")
	ctx.equal(_run.map().current_id(), current_before, "重进之后还站在原来那一站")
	ctx.equal(_status_text(again), status_before, "重进之后顶上那行写着同一个位置")
	ctx.equal(_continue_button(again).disabled, true, "重进之后「继续」重新变成灰的（还没在新的一次访问里选）")

	# 重进之后点那个「已访问」的老地方，照样点不动 —— 复原的是状态，不是「又能重走」。
	var walked: MapModel.MapNode = _run.map().find(current_before)
	var rejected: Array = []
	view.node_rejected.connect(func(state: MapNodePainter.State) -> void: rejected.append(state))
	view.press(MapLayout.node_position(walked.tier, walked.column))
	ctx.equal(rejected.size(), 1, "重进之后点当前位置仍然给反馈")
	ctx.equal(_run.map().path(), path_before, "重进之后点当前位置仍然什么都不动")

	again.queue_free()
	await _tree.process_frame


# ---------------------------------------------------------------- 工具

func _open(ctx: RefCounted) -> Control:
	var packed: PackedScene = load(SCREEN_PATH)
	if not ctx.check(packed != null, "%s 可加载" % SCREEN_PATH):
		return null
	var screen: Control = packed.instantiate()
	_tree.root.add_child(screen)
	# 等一帧：_ready() 建控件、MapView.setup() 都在这一帧里跑完。
	await _tree.process_frame
	return screen


func _first_of(root: Node, kind: String) -> Node:
	var found: Array[Node] = TreeProbe.find_all(root, kind)
	return found[0] if not found.is_empty() else null


## 顶上那行「当前位置」。按**落点**找（MapLayout.status_rect() 是版式契约），
## 不按文案前缀 —— 开局那行写的是「还没出发」，前缀根本对不上。
func _status_text(screen: Control) -> String:
	var want: Vector2 = MapLayout.status_rect().position
	for node: Node in TreeProbe.find_all(screen, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(want):
			return label.text
	return ""


func _continue_button(screen: Control) -> Button:
	var want: String = TranslationServer.translate(KEY_CONTINUE)
	for node: Node in TreeProbe.find_all(screen, "Button"):
		if (node as Button).text == want:
			return node as Button
	return null


static func _mouse_at(at: Vector2) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.global_position = at
	return event


static func _touch_at(at: Vector2) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.pressed = true
	event.position = at
	return event


## 一个节点在**窗口**坐标里的位置：屏幕铺满根视口，故先加上图在屏上的位置换成屏坐标，
## 再乘拉伸比（与 tools/capture_editor.gd 同一个口径）。
func _to_window(screen: Control, node: MapModel.MapNode) -> Vector2:
	var local: Vector2 = MapLayout.parchment().position \
		+ MapLayout.node_position(node.tier, node.column)
	return (screen.get_global_transform() * local) * _window_scale()


## 走真实的输入路径：过一个 Viewport，而不是直接叫控件的方法。
func _push(event: InputEvent) -> void:
	_tree.root.push_input(event)


func _window_scale() -> float:
	var canvas_width: float = _tree.root.get_visible_rect().size.x
	var window_width: float = float(DisplayServer.window_get_size().x)
	if canvas_width <= 0.0 or window_width <= 0.0:
		return 1.0
	return window_width / canvas_width
