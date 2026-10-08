## board_view.gd
## 职责：书页画布 —— 处理「拖动摆放」与「拉线连接」两种手势，并把状态交给 BoardRenderer 画。
## 所属系统：editor
## 依赖：BoardModel, Snap, BoardRenderer, CardFace, Palette
## 禁止：本文件不得写入坐标量化（**本工程没有网格**）；不得出现裸色值；
##       不得自己画任何一笔（全部在 BoardRenderer / CardFace / BoardStatePainter 里）。
##
## 这是本作的招牌屏（用户 2026-10-06：「编辑器是招牌，最先做」）。四条不可退让的规则：
##   1. 卡片画在**自由坐标**上，画布上没有格子、没有吸附点阵；
##   2. 只有拖动到**别的卡片附近**时才发生磁性吸附，并当场画出**只跨相关两卡**的辅助线；
##   3. **状态分两层**（docs/13 §10.1）：选中 = 金色轮廓，焦点 = 浅蓝细角标，两者不同源、可同时出现；
##   4. 卡片四周留出 EDGE_PADDING，接口圆点与选中轮廓都不会被画布的裁切边切掉。

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
## 卡片**卡身**到画布裁切边必须留出的余量（逻辑像素）。
##
## 取值来自 docs/14 §1.1「卡到可裁切边最小距离 16（按卡身计）」，而 §2.1 的净纸 —— 也就是画布
## 本身的矩形 —— 才是裁切边。16 这个数要同时容下：接口圆点（半径 6，画在卡身外）、
## 选中轮廓（外扩 5）与端口命中圈（半径 16 的那一圈是**命中**范围，会溢出画布但不会画出来）。
## 6 与 5 都在 16 以内，所以卡身保住 16 就等于它们都保住了。这是一条几何约束，不是审美选择。
const EDGE_PADDING: float = 16.0

var _model: BoardModel = null
## 绘制层。它持有绘制状态（指点 / 连线起点 / 吸附回执），本文件写、它读。
var _renderer: BoardRenderer = null
var _selected_uid: int = 0
## 指针下的卡片（0 = 没有）。**焦点 = 指针悬停 或 正在被拖动** ——
## 与「选中」是两件事：选中回答「我在编辑哪张」，焦点回答「我此刻指着哪张」。
## 13 §10.1 要求两者在配色上分得开，因此这里也必须分开跟踪。
var _hover_uid: int = 0
## 拖动状态。_drag_uid = 0 表示当前没在拖卡。
var _drag_uid: int = 0
var _drag_grab: Vector2 = Vector2.ZERO


func _ready() -> void:
	_renderer = BoardRenderer.new()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(_on_mouse_exited)


## 接上数据模型。editor 在 _ready() 里调用一次。
func setup(model: BoardModel) -> void:
	if _model != null and _model.changed.is_connected(queue_redraw):
		_model.changed.disconnect(queue_redraw)
	_model = model
	if _model != null:
		_model.changed.connect(queue_redraw)
	queue_redraw()


## 绘制层。工具（tools/capture_editor.gd）读它拿吸附回执，测试别用它做断言。
func renderer() -> BoardRenderer:
	return _renderer


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


## 卡片左上角的合法范围：原点。
func play_origin() -> Vector2:
	return Vector2(EDGE_PADDING, EDGE_PADDING)


## 卡片左上角的合法范围：相对原点的上限（= 可移动的距离）。
## 卡片整体 + 两侧余量必须仍然落在画布里：origin + limit + CARD_SIZE + padding == size。
func play_limit() -> Vector2:
	return (size - CardFace.SIZE - Vector2(EDGE_PADDING, EDGE_PADDING) * 2.0).max(Vector2.ZERO)


## 把坐标夹进合法范围。端口与选中轮廓因此永远画得下（PET-87 §3）。
func clamp_to_play(position: Vector2) -> Vector2:
	var origin: Vector2 = play_origin()
	return Vector2(clampf(position.x, origin.x, origin.x + play_limit().x),
		clampf(position.y, origin.y, origin.y + play_limit().y))


## 给新卡牌找一个**落点**：离画布中心最近的空位（规则在 BoardModel.free_position）。
## 这是「放置」而不是「吸附」—— 只求落点不重叠，用户随后可以拖到任何位置。
func free_position() -> Vector2:
	if _model == null:
		return clamp_to_play((size - CardFace.SIZE) * 0.5)
	# 把「合法范围」当成模型眼里的整块画布：模型照旧从 0 开始找空位，再整体平移进来。
	return clamp_to_play(_model.free_position(play_limit() + CardFace.SIZE) + play_origin())


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
	_renderer.selected_uid = _selected_uid
	# 焦点每帧现算：悬停与拖动都会变，而它们各自只发一次 queue_redraw，收在这最省心。
	_renderer.focus_uid = _focus_uid()
	_renderer.paint(self, _model, size)


## 当前焦点卡：正在拖的那张优先（拖动时指针可能已经不在卡上了）。
func _focus_uid() -> int:
	return _drag_uid if _drag_uid != 0 else _hover_uid


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion:
		_on_motion(event.position)


func _on_press(position: Vector2) -> void:
	_renderer.pointer = position
	var card: BoardModel.PlacedCard = _find_card_at(position)
	if card == null:
		clear_selection()
		return
	select(card.uid)
	if position.distance_to(output_port(card)) <= PORT_HIT_RADIUS:
		_renderer.link_from = card.uid
		queue_redraw()
		return
	# 推入撤销快照必须发生在改动之前，因此这里先发信号，再开始改坐标。
	edit_started.emit()
	_drag_uid = card.uid
	_drag_grab = position - card.position


func _on_motion(position: Vector2) -> void:
	_renderer.pointer = position
	_track_hover(position)
	if _renderer.link_from != 0:
		queue_redraw()
		return
	if _drag_uid == 0:
		return
	var card: BoardModel.PlacedCard = _model.find_card(_drag_uid)
	if card == null:
		return
	# 拖动中**只做一次**决定：吸附到附近卡片，或原样跟随指针。没有第三种可能 ——
	# 没有任何一步把坐标对齐到固定步长。
	var wanted: Vector2 = clamp_to_play(position - _drag_grab)
	var outcome: Snap.Result = Snap.resolve(Rect2(wanted, CardFace.SIZE), _obstacle_rects(_drag_uid))
	var settled: Vector2 = clamp_to_play(outcome.position)
	# 夹回来会破坏刚算出的对齐，此时那条回执已经不作数 —— 撤掉，不画一条和卡片对不上的线。
	var kept: bool = settled.is_equal_approx(outcome.position)
	_renderer.guides_v = outcome.guides_v if kept else []
	_renderer.guides_h = outcome.guides_h if kept else []
	_renderer.spans_v = outcome.spans_v if kept else []
	_renderer.spans_h = outcome.spans_h if kept else []
	_renderer.snapped = outcome.snapped and kept
	_model.move_card(_drag_uid, settled)


func _on_release(position: Vector2) -> void:
	_renderer.pointer = position
	if _renderer.link_from != 0:
		var target: BoardModel.PlacedCard = _find_card_at(position)
		var source_uid: int = _renderer.link_from
		_renderer.link_from = 0
		_clear_guides()
		if target != null and target.uid != source_uid:
			link_requested.emit(source_uid, target.uid)
		queue_redraw()
		return
	if _drag_uid == 0:
		return
	_drag_uid = 0
	_clear_guides()
	_track_hover(position)
	edit_finished.emit()
	queue_redraw()


## 跟踪指针下的卡片。焦点角标靠它 —— 没有这一段，Focus 就只能在拖动时才出现，
## 而「指针指着一张卡」恰恰是最需要焦点反馈的时刻。
func _track_hover(position: Vector2) -> void:
	var card: BoardModel.PlacedCard = _find_card_at(position)
	var uid: int = card.uid if card != null else 0
	if uid == _hover_uid:
		return
	_hover_uid = uid
	queue_redraw()


func _on_mouse_exited() -> void:
	_track_hover(Vector2(-1.0, -1.0))


func _clear_guides() -> void:
	_renderer.guides_v = []
	_renderer.guides_h = []
	_renderer.spans_v = []
	_renderer.spans_h = []
	_renderer.snapped = false


## 除 exclude_uid 之外所有卡片的矩形 —— 吸附的参照物。拖动中的卡不能吸自己。
func _obstacle_rects(exclude_uid: int) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for card: BoardModel.PlacedCard in _model.cards():
		if card.uid != exclude_uid:
			rects.append(card_rect(card))
	return rects


func _find_card_at(position: Vector2) -> BoardModel.PlacedCard:
	if _model == null:
		return null
	return BoardRenderer.find_card_at(_model, position)
