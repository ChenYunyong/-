## board_view.gd
## 职责：书页画布 —— 画卡牌 / 画奥术丝线 / 画吸附辅助线，并处理「拖动摆放」与「拉线连接」两种手势。
## 所属系统：editor
## 依赖：BoardModel, Snap, CardFace, CardCatalog, ThreadPainter, Palette
## 禁止：本文件不得写入坐标量化（**本工程没有网格**）；不得出现裸色值 —— 颜色一律经 Palette。
##
## 这是本作的招牌屏（用户 2026-10-06：「编辑器是招牌，最先做」）。三条不可退让的规则：
##   1. 卡片画在**自由坐标**上，画布上没有格子、没有吸附点阵；
##   2. 只有拖动到**别的卡片附近**时才发生磁性吸附，并当场画出辅助线 + 高亮边框（吸附瞬间的反馈）；
##   3. 颜色即类型 —— 边框与图形标记取 CardCatalog 的类型色。

class_name BoardView
extends Control

## 选中项变化（0 = 没有选中）。editor 用它刷新详情面板。
signal selection_changed(uid: int)
## 一次编辑即将开始 —— 监听方在此刻推入撤销快照（必须在改动**之前**）。
signal edit_started()
## 一次编辑结束（拖动松手 / 连线落定）。
signal edit_finished()
## 用户从输出接口拖到了另一张卡 —— 由 editor 决定是否真的连（要查重、查环）。
signal link_requested(from_uid: int, to_uid: int)

## 接口圆点半径与命中半径（逻辑像素）。命中半径 16 → 直径 32 逻辑 = 2× 下 64 设备像素，
## 高于 docs/06 §1 的触控下限 44 —— 连线手势在触屏上也点得中。
const PORT_RADIUS: float = 6.0
const PORT_HIT_RADIUS: float = 16.0
## 辅助线 / 高亮描边粗细。1 逻辑像素 = 2 设备像素，足够看清又不喧宾夺主。
const GUIDE_WIDTH: float = 1.0

var _model: BoardModel = null
var _selected_uid: int = 0

## 拖动状态。_drag_uid = 0 表示当前没在拖卡。
var _drag_uid: int = 0
var _drag_grab: Vector2 = Vector2.ZERO
## 连线状态。_link_from = 0 表示当前没在拉线。
var _link_from: int = 0
var _pointer: Vector2 = Vector2.ZERO
var _guides_v: Array[float] = []
var _guides_h: Array[float] = []
var _snapped: bool = false

## 取色缓存。**来源仍是 Palette.get_color()** —— 缓存只是为了不在每帧 _draw 里反复查表。
var _col_card_fill: Color = Palette.MISSING_COLOR
var _col_card_selected: Color = Palette.MISSING_COLOR
var _col_text: Color = Palette.MISSING_COLOR
var _col_link: Color = Palette.MISSING_COLOR
var _col_link_active: Color = Palette.MISSING_COLOR
var _col_guide: Color = Palette.MISSING_COLOR
var _col_port: Color = Palette.MISSING_COLOR


func _ready() -> void:
	_col_card_fill = Palette.get_color(Palette.Key.NAVY_800)
	_col_card_selected = Palette.get_color(Palette.Key.NAVY_700)
	_col_text = Palette.get_color(Palette.Key.BLUE_100)
	_col_link = Palette.get_color(Palette.Key.BLUE_400)
	_col_link_active = Palette.get_color(Palette.Key.GOLD_500)
	_col_guide = Palette.get_color(Palette.Key.GOLD_400)
	_col_port = Palette.get_color(Palette.Key.BLUE_200)
	mouse_filter = Control.MOUSE_FILTER_STOP


## 接上数据模型。editor 在 _ready() 里调用一次。
func setup(model: BoardModel) -> void:
	if _model != null and _model.changed.is_connected(queue_redraw):
		_model.changed.disconnect(queue_redraw)
	_model = model
	if _model != null:
		_model.changed.connect(queue_redraw)
	queue_redraw()


func selected_uid() -> int:
	return _selected_uid


func select(uid: int) -> void:
	if _selected_uid == uid:
		return
	_selected_uid = uid
	selection_changed.emit(uid)
	queue_redraw()


func clear_selection() -> void:
	select(0)


## 给新卡牌找一个**落点**：离画布中心最近的空位（规则在 BoardModel.free_position）。
## 这是「放置」而不是「吸附」—— 只求落点不重叠，用户随后可以拖到任何位置。
func free_position() -> Vector2:
	return (size - CardFace.SIZE) * 0.5 if _model == null else _model.free_position(size)


## 卡片在画布上的矩形。
static func card_rect(card: BoardModel.PlacedCard) -> Rect2:
	return Rect2(card.position, CardFace.SIZE)


## 输出接口（右侧中点）与输入接口（左侧中点）的画布坐标。
static func output_port(card: BoardModel.PlacedCard) -> Vector2:
	return card.position + Vector2(CardFace.SIZE.x, CardFace.SIZE.y * 0.5)


static func input_port(card: BoardModel.PlacedCard) -> Vector2:
	return card.position + Vector2(0.0, CardFace.SIZE.y * 0.5)


func _draw() -> void:
	if _model == null:
		return
	_draw_links()
	_draw_guides()
	for card: BoardModel.PlacedCard in _model.cards():
		_draw_card(card)
	if _link_from != 0:
		_draw_link_preview()


func _draw_links() -> void:
	for link: BoardModel.Link in _model.links():
		var source: BoardModel.PlacedCard = _model.find_card(link.from_uid)
		var target: BoardModel.PlacedCard = _model.find_card(link.to_uid)
		if source == null or target == null:
			continue
		var hot: bool = link.from_uid == _selected_uid or link.to_uid == _selected_uid
		ThreadPainter.paint(self, output_port(source), input_port(target),
			_col_link_active if hot else _col_link)


func _draw_guides() -> void:
	for x: float in _guides_v:
		draw_line(Vector2(x, 0.0), Vector2(x, size.y), _col_guide, GUIDE_WIDTH)
	for y: float in _guides_h:
		draw_line(Vector2(0.0, y), Vector2(size.x, y), _col_guide, GUIDE_WIDTH)
	if _snapped:
		_draw_snap_badge()


## 吸附瞬间的角标。位置固定在画布右上角，不跟着卡片乱跑（避免遮挡正在看的卡）。
func _draw_snap_badge() -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = get_theme_default_font_size()
	if font == null:
		return
	var text: String = tr("吸附")
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(size.x - width - 12.0, float(font_size) + 4.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _col_guide)


func _draw_card(card: BoardModel.PlacedCard) -> void:
	var data: CardData = card.data()
	var selected: bool = card.uid == _selected_uid
	var hot: bool = selected or card.uid == _drag_uid
	# 选中 / 拖动是**状态**，不改牌面类型色本身：状态走底板的深一档 + 金色描边，
	# 类型色留在图形标记与未选中时的描边上。
	var fill: Color = _col_card_selected if selected else _col_card_fill
	var border: Color = _col_guide if hot else CardCatalog.accent_color(data)
	var width: float = CardFace.BORDER_WIDTH_HOT if (_snapped and card.uid == _drag_uid) else CardFace.BORDER_WIDTH
	CardFace.paint(self, data, card.position, fill, border, width, _col_text)
	if hot:
		_draw_ports(card)


func _draw_ports(card: BoardModel.PlacedCard) -> void:
	draw_circle(input_port(card), PORT_RADIUS, _col_port)
	draw_circle(output_port(card), PORT_RADIUS, _col_link_active)


func _draw_link_preview() -> void:
	var source: BoardModel.PlacedCard = _model.find_card(_link_from)
	if source == null:
		return
	var target: Vector2 = _pointer
	var hovered: BoardModel.PlacedCard = _find_card_at(_pointer)
	if hovered != null and hovered.uid != _link_from:
		target = input_port(hovered)
	ThreadPainter.paint(self, output_port(source), target, _col_link_active)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion:
		_on_motion(event.position)


func _on_press(position: Vector2) -> void:
	_pointer = position
	var card: BoardModel.PlacedCard = _find_card_at(position)
	if card == null:
		clear_selection()
		return
	select(card.uid)
	if position.distance_to(output_port(card)) <= PORT_HIT_RADIUS:
		_link_from = card.uid
		queue_redraw()
		return
	# 推入撤销快照必须发生在改动之前，因此这里先发信号，再开始改坐标。
	edit_started.emit()
	_drag_uid = card.uid
	_drag_grab = position - card.position


func _on_motion(position: Vector2) -> void:
	_pointer = position
	if _link_from != 0:
		queue_redraw()
		return
	if _drag_uid == 0:
		return
	var card: BoardModel.PlacedCard = _model.find_card(_drag_uid)
	if card == null:
		return
	# 拖动中**只做一次**决定：吸附到附近卡片，或原样跟随指针。没有第三种可能 ——
	# 没有任何一步把坐标对齐到固定步长。
	var wanted: Vector2 = position - _drag_grab
	var outcome: Snap.Result = Snap.resolve(Rect2(wanted, CardFace.SIZE), _obstacle_rects(_drag_uid))
	_guides_v = outcome.guides_v
	_guides_h = outcome.guides_h
	_snapped = outcome.snapped
	_model.move_card(_drag_uid, outcome.position)


func _on_release(position: Vector2) -> void:
	_pointer = position
	if _link_from != 0:
		var target: BoardModel.PlacedCard = _find_card_at(position)
		var source_uid: int = _link_from
		_link_from = 0
		_guides_v = []
		_guides_h = []
		_snapped = false
		if target != null and target.uid != source_uid:
			link_requested.emit(source_uid, target.uid)
		queue_redraw()
		return
	if _drag_uid == 0:
		return
	_drag_uid = 0
	_guides_v = []
	_guides_h = []
	_snapped = false
	edit_finished.emit()
	queue_redraw()


## 除 exclude_uid 之外所有卡片的矩形 —— 吸附的参照物。拖动中的卡不能吸自己。
func _obstacle_rects(exclude_uid: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for card: BoardModel.PlacedCard in _model.cards():
		if card.uid != exclude_uid:
			rects.append(card_rect(card))
	return rects


## 命中测试。倒序遍历 = 后画的在上，点谁选谁。
func _find_card_at(position: Vector2) -> BoardModel.PlacedCard:
	if _model == null:
		return null
	var cards: Array[BoardModel.PlacedCard] = _model.cards()
	for index: int in range(cards.size() - 1, -1, -1):
		if card_rect(cards[index]).has_point(position):
			return cards[index]
	return null
