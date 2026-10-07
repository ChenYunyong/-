## map_view.gd
## 职责：路线图的绘制与点击 —— 层、节点、连线的画法，以及「哪些节点现在能点」的高亮。
## 所属系统：roguelike（表现部分）
## 依赖：MapModel, Palette
## 禁止：本文件不得改图数据（选择走 MapModel.select()）；不得出现裸色值。
##
## 路线图是**格点布局**（层 × 列），这与「书页无网格」并不冲突：
## 无网格是模块编辑器那条招牌交互的规则，路线图本来就是一张排好版的图。

class_name MapView
extends Control

## 点了某个可选节点。
signal node_chosen(kind: MapModel.Kind)

const NODE_RADIUS: float = 24.0
const EDGE_WIDTH: float = 3.0
const SELECTABLE_BORDER: float = 3.0
const PADDING: float = 24.0

var _model: MapModel = null
var _font: Font = null
var _font_size: int = 24


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func setup(model: MapModel) -> void:
	_model = model
	_font = Fonts.ui_font()
	_font_size = ArcaneTheme.BODY_FONT_SIZE
	queue_redraw()


## 某层某列在画布上的坐标。层号从下往上（第 0 层在最下面），列从左往右。
static func node_position(size: Vector2, tier: int, column: int) -> Vector2:
	var rows: int = maxi(MapModel.TIERS - 1, 1)
	var step_y: float = (size.y - PADDING * 2.0) / float(rows)
	var step_x: float = (size.x - PADDING * 2.0) / float(MapModel.COLUMNS)
	return Vector2(
		PADDING + (float(column) + 0.5) * step_x,
		size.y - PADDING - float(tier) * step_y
	)


func _draw() -> void:
	if _model == null:
		return
	_draw_edges()
	for node: MapModel.MapNode in _model.nodes():
		_draw_node(node)


func _draw_edges() -> void:
	var dim: Color = Palette.get_color(Palette.Key.BLUE_500)
	var here: int = _model.current_id()
	for node: MapModel.MapNode in _model.nodes():
		var from: Vector2 = node_position(size, node.tier, node.column)
		for next_id: int in node.next:
			var target: MapModel.MapNode = _model.find(next_id)
			if target == null:
				continue
			# 已走过的那一段描亮，玩家一眼能看出自己是从哪来的。
			var color: Color = Palette.get_color(Palette.Key.GOLD_500) if node.id == here else dim
			draw_line(from, node_position(size, target.tier, target.column), color, EDGE_WIDTH)


func _draw_node(node: MapModel.MapNode) -> void:
	var center: Vector2 = node_position(size, node.tier, node.column)
	var selectable: bool = _model.can_select(node.id)
	var visited: bool = _model.is_visited(node.id)
	var fill: Color = _kind_color(node.kind)
	if visited:
		fill = Palette.get_color(Palette.Key.GREY_500)
	elif not selectable:
		# 够不着的节点压暗一档，而不是直接隐藏 —— 玩家要看得到「后面还有什么」。
		fill = fill.darkened(0.55)
	draw_circle(center, NODE_RADIUS, fill)
	if selectable:
		draw_arc(center, NODE_RADIUS, 0.0, TAU, 32, Palette.get_color(Palette.Key.GOLD_400), SELECTABLE_BORDER, true)
	_draw_kind_mark(center, node.kind, visited)


## 节点里的一个字：战 / 工。图形标记之外再给一个字，免得只靠颜色区分。
func _draw_kind_mark(center: Vector2, kind: MapModel.Kind, visited: bool) -> void:
	if _font == null:
		return
	var text: String = tr("战") if kind == MapModel.Kind.BATTLE else tr("工")
	var token: Palette.Key = Palette.Key.NAVY_700 if visited else Palette.Key.NAVY_900
	var color: Color = Palette.get_color(token)
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var baseline: float = center.y + float(_font_size) * 0.35
	draw_string(_font, Vector2(center.x - width * 0.5, baseline), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)


static func _kind_color(kind: MapModel.Kind) -> Color:
	if kind == MapModel.Kind.WORKSHOP:
		return Palette.get_color(Palette.Key.GOLD_400)
	return Palette.get_color(Palette.Key.ORANGE_500)


func _gui_input(event: InputEvent) -> void:
	if _model == null:
		return
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var click: InputEventMouseButton = event
	if click.button_index != MOUSE_BUTTON_LEFT:
		return
	for node: MapModel.MapNode in _model.selectable():
		if node_position(size, node.tier, node.column).distance_to(click.position) <= NODE_RADIUS:
			if _model.select(node.id):
				node_chosen.emit(node.kind)
			return
