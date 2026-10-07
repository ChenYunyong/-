## map_view.gd
## 职责：羊皮卷路线图的绘制与命中 —— 纸面、边线、四态节点、图例，以及鼠标 / 触摸的选择。
## 所属系统：roguelike（表现部分）
## 依赖：MapModel, MapLayout, MapParchment, MapNodePainter, MapSymbolPainter, Fonts, ArcaneTheme
## 禁止：本文件不得改图数据（选择走 MapModel.select()）；不得自己算「能去哪」（走 MapModel.selectable()）；
##       不得出现裸色值；不得直接 draw_line —— 线一律经 StrokePainter（test_map_paint 扫源码钉住）。
##
## 本控件**不持有任何路线状态**：走过的序列、当前节点都问 MapModel（本局那一份在 RunState 手里）。
## 于是退出这个界面再进来，画出来的还是同一条路线、同一个当前位置 —— 这是 §4 的验收点之一。
##
## 路线图是**格点布局**（层 × 列），这与「书页无网格」并不冲突：
## 无网格是模块编辑器那条招牌交互的规则，路线图本来就是一张排好版的图。

class_name MapView
extends Control

## 点了某个可选节点，并且模型已经真的走过去了。
signal node_chosen(kind: MapModel.Kind)
## 点了走不了的节点（已访问 / 不可达）。界面据此给一句「走不了」的当场反馈。
signal node_rejected(state: MapNodePainter.State)

## 节点半径。画的圆与命中的圆是同一个 —— 看得见多大就点得中多大。
## 40 逻辑像素的直径 = 80 设备像素，是 06 §1 那条 44 下限的 1.8 倍（test_layout 也核对它）。
const NODE_RADIUS: float = MapLayout.NODE_RADIUS

## 图例里四个状态的出场顺序：先说能做什么，再说已经怎样。
const LEGEND_STATES: Array[MapNodePainter.State] = [MapNodePainter.State.SELECTABLE,
	MapNodePainter.State.CURRENT, MapNodePainter.State.VISITED, MapNodePainter.State.UNREACHABLE]

var _model: MapModel = null
var _font: Font = null
var _font_size: int = ArcaneTheme.PARAM_FONT_SIZE
## 最近一次点了走不了的节点的 id（-1 = 没有）。它一直留到下一次点击 ——
## 界面不用计时器，也不会自己往下走（R1）。
var _rejected_id: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(model: MapModel) -> void:
	_model = model
	_font = Fonts.ui_font()
	_font_size = ArcaneTheme.PARAM_FONT_SIZE
	_rejected_id = -1
	queue_redraw()


func rejected_id() -> int:
	return _rejected_id


# ------------------------------------------------------------------ 绘制

func _draw() -> void:
	if _model == null:
		return
	MapParchment.paint(self, Rect2(Vector2.ZERO, MapLayout.PARCHMENT_SIZE), MapLayout.LEGEND_SEAM_Y)
	_draw_edges()
	_draw_nodes()
	_draw_legend()
	_draw_rejection()


## 边线分三档：走过的（粗墨）、现在能走的（中墨）、还走不到的（淡墨）。
## 于是「一条走过的路线」在地图上是一道压得最重的墨迹，而不是换个颜色。
func _draw_edges() -> void:
	var path: Array[int] = _model.path()
	var current: int = _model.current_id()
	for node: MapModel.MapNode in _model.nodes():
		var from: Vector2 = MapLayout.node_position(node.tier, node.column)
		for next_id: int in node.next:
			var target: MapModel.MapNode = _model.find(next_id)
			if target == null:
				continue
			MapNodePainter.paint_edge(self, from,
				MapLayout.node_position(target.tier, target.column),
				MapNodePainter.edge_style(node.id, next_id, path, current))


func _draw_nodes() -> void:
	for node: MapModel.MapNode in _model.nodes():
		var state: MapNodePainter.State = MapNodePainter.state_of(_model, node.id)
		var center: Vector2 = MapLayout.node_position(node.tier, node.column)
		MapNodePainter.paint_node(self, center, NODE_RADIUS, state)
		MapSymbolPainter.paint(self, node.kind, center, MapLayout.SYMBOL_RADIUS,
			MapNodePainter.ink(state))
		_draw_label(MapLayout.node_label_baseline(node.tier, node.column), kind_text(node.kind))


## 节点右边那行短名。符号与文字同时在场：颜色认不出时，文字还认得（06 §11）。
func _draw_label(baseline: Vector2, text: String) -> void:
	if _font == null:
		return
	draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size,
		Palette.get_color(MapNodePainter.INK_ON_PAPER))


## 图例：四个状态各画一个**真的**小节点（走同一支画笔），旁边写状态名。
## 用同一个画笔而不是另画四块色卡 —— 图例上看到的与地图上看到的必须是同一个东西。
func _draw_legend() -> void:
	for index: int in LEGEND_STATES.size():
		var state: MapNodePainter.State = LEGEND_STATES[index]
		MapNodePainter.paint_node(self, MapLayout.legend_node_position(index),
			MapLayout.LEGEND_NODE_RADIUS, state)
		_draw_label(MapLayout.legend_label_baseline(index), state_text(state))


func _draw_rejection() -> void:
	if _rejected_id < 0:
		return
	var node: MapModel.MapNode = _model.find(_rejected_id)
	if node == null:
		return
	MapNodePainter.paint_rejected(self,
		MapLayout.node_position(node.tier, node.column), NODE_RADIUS)


# ------------------------------------------------------------------ 文案

## 节点的短名。tr 的字面量留在这里（不在 painter 里）—— test_i18n 靠扫字面量
## 保证它们都在语言表里；写进 painter 的话静态函数里没有 tr()，只能绕道。
static func kind_text(kind: MapModel.Kind) -> String:
	if kind == MapModel.Kind.WORKSHOP:
		return TranslationServer.translate("工坊")
	return TranslationServer.translate("战斗")


static func state_text(state: MapNodePainter.State) -> String:
	match state:
		MapNodePainter.State.SELECTABLE:
			return TranslationServer.translate("可选")
		MapNodePainter.State.CURRENT:
			return TranslationServer.translate("当前")
		MapNodePainter.State.VISITED:
			return TranslationServer.translate("走过")
		_:
			return TranslationServer.translate("不可达")


# ------------------------------------------------------------------ 命中与选择

func _gui_input(event: InputEvent) -> void:
	if _model == null or not is_press(event):
		return
	press(event_position(event))


## 左键按下与触摸按下走**同一条**判定路径（06 §10 规则 6：鼠标与触摸都要能操作）。
static func is_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event
		return click.pressed and click.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false


static func event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	return (event as InputEventMouseButton).position


## 局部坐标上命中的节点 id；没命中返回 -1。命中半径就是画出来的那个圆（NODE_RADIUS）。
static func node_at(model: MapModel, at: Vector2) -> int:
	var best: int = -1
	var best_distance: float = NODE_RADIUS
	for node: MapModel.MapNode in model.nodes():
		var distance: float = MapLayout.node_position(node.tier, node.column).distance_to(at)
		if distance <= best_distance:
			best = node.id
			best_distance = distance
	return best


## 在这张图的一处**局部坐标**上按一下。鼠标与触摸最终都汇到这里（_gui_input 只做事件解码），
## 于是「点得动 / 点不动」的判定只有这一条路径，测试也可以直接按一个坐标进来。
##
## 只有**可选**的节点会走下去并发出 node_chosen。
## 已访问 / 不可达的节点：给一个当场看得见的反馈（红圈 + 斜杠 + 一句话），
## 并且**一个字节的状态都不动** —— 这也是 §3 的验收点。
func press(at: Vector2) -> void:
	var id: int = node_at(_model, at)
	if id < 0:
		return
	if not _model.can_select(id):
		_rejected_id = id
		node_rejected.emit(MapNodePainter.state_of(_model, id))
		queue_redraw()
		return
	_rejected_id = -1
	if _model.select(id):
		node_chosen.emit(_model.find(id).kind)
	queue_redraw()
