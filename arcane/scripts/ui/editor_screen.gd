## editor_screen.gd
## 职责：模块编辑器（奥术蓝图）—— 本作的招牌屏，装配顶栏 / 书页画布 / 卡片详情 / 卡牌仓库。
## 所属系统：ui
## 依赖：RunState, BoardModel, BoardView, CardCatalog, CardChip, DetailPanel, EditorLayout,
##       UiKit, IconButton, IconPainter, GameFlow, ArcaneTheme
## 禁止：本文件不得实现吸附几何（在 Snap 里）、不得实现绘制（在 BoardView / CardFace 里）；
##       不得出现裸色值；不得自己调 change_scene_to_file()（03 §1.1 R3：只有 GameFlow 能换场景）。
##
## 本屏要证明的两件事（PET-85 验收点）：
##   1. **无网格**：卡片位置就是自由浮点坐标，界面任何一处都不做坐标量化；
##   2. **自由吸附**：只在拖到别的卡片附近时吸，并当场画出辅助线 + 金色高亮。

extends Control

## 撤销栈深度。够用即可 —— 这不是编辑器，是搭配界面的防手滑。
const UNDO_LIMIT: int = 32

## 顶栏按钮的变体，顺序与 EditorLayout.TOP_BUTTONS 一致（最右是主动作）。
## PET-87 §3：只有「开始战斗」是金色强主动作，另外三个退成次级。
const TOP_BUTTON_VARIATIONS: Array[StringName] = [
	ArcaneTheme.TYPE_BUTTON_PRIMARY,
	ArcaneTheme.TYPE_BUTTON_SECONDARY,
	ArcaneTheme.TYPE_BUTTON_SECONDARY,
	ArcaneTheme.TYPE_BUTTON_SECONDARY,
]
## 顶栏按钮各自的图标，顺序与 EditorLayout.TOP_BUTTONS 一致。
## NONE = 这个键仍是文字按钮（顶栏唯一的强主动作）。
const TOP_BUTTON_ICONS: Array[IconPainter.Icon] = [
	IconPainter.Icon.NONE,
	IconPainter.Icon.MAP,
	IconPainter.Icon.DELETE,
	IconPainter.Icon.UNDO,
]
## 需要按状态置灰的那两个按钮在 TOP_BUTTONS 里的下标。
const TOP_BUTTON_DELETE: int = 2
const TOP_BUTTON_UNDO: int = 3
## 仓库两端滚动入口的图标与文案 key（左 / 右）。文案只进 tooltip 与无障碍名。
const TRAY_ARROW_ICONS: Array[IconPainter.Icon] = [
	IconPainter.Icon.ARROW_LEFT,
	IconPainter.Icon.ARROW_RIGHT,
]
const TRAY_ARROW_KEYS: PackedStringArray = ["仓库向左滚动", "仓库向右滚动"]
## 偏移小于这个数就算「到头了」，对应那一端的滚动入口自行隐藏。
## 浮点比较不能用 == 0（滚动偏移是一路累加出来的）。
const TRAY_EDGE_EPSILON: float = 0.01

## 书页就是**本局那一份**（RunState.board()），在 _ready() 里绑定。
## 不各持一份：编辑器改的和战斗读的必须是同一个对象，否则玩家连的线战斗根本看不到
## （loop_smoke 就是钉这一条的 —— 两份书页的话那条用例会红在「战斗队列是空的」）。
var _board: BoardModel = null
var _undo_stack: Array[Dictionary] = []

var _canvas: BoardView = null
var _tray_clip: Control = null
var _tray_row: HBoxContainer = null
var _tray_offset: float = 0.0
var _tray_count: int = 0
var _tray_arrows: Array[IconButton] = []

var _detail: DetailPanel = null
var _status_label: Label = null
var _undo_button: IconButton = null
var _delete_button: IconButton = null


func _ready() -> void:
	_board = RunState.board()
	_build_top_bar()
	_build_canvas()
	_build_detail()
	_build_tray()
	_canvas.setup(_board)
	_board.changed.connect(_refresh)
	_refresh()


## 顶栏：标题 · 状态 · 撤销/删除（编辑动作）· 路线图/开始战斗（前进动作）。
## 不带木框 —— 72 高的条里若再扣 9px 描边，54 高的按钮就贴边了。
## 按钮的位置由 EditorLayout.top_button_rects() 统一算（布局测试断言的是同一组数）。
func _build_top_bar() -> void:
	var title: Label = UiKit.label(tr("模块编辑器"), EditorLayout.TOP_TITLE_RECT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	_status_label = UiKit.label("", EditorLayout.TOP_STATUS_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_status_label)

	var handlers: Array[Callable] = [_on_start_battle, _on_open_map, _on_delete, _on_undo]
	var rects: Array[Rect2] = EditorLayout.top_button_rects()
	for index: int in rects.size():
		var key: String = EditorLayout.TOP_BUTTONS[index]
		var rect: Rect2 = rects[index]
		var button: Button = _make_top_button(key, index, handlers[index])
		button.position = rect.position
		button.size = rect.size
		add_child(button)
		# 这两个按钮要按状态置灰，留个引用（下标与 EditorLayout.TOP_BUTTONS 对齐）。
		if index == TOP_BUTTON_DELETE:
			_delete_button = button
		elif index == TOP_BUTTON_UNDO:
			_undo_button = button


## 顶栏上的一个控件。图标为 NONE 的走文字按钮（顶栏唯一的强主动作），
## 其余一律是紧凑方形图标控件 —— 靠图标认、靠 tooltip 说全名（PET-87 §3）。
func _make_top_button(key: String, index: int, handler: Callable) -> Button:
	var icon: IconPainter.Icon = TOP_BUTTON_ICONS[index]
	if icon == IconPainter.Icon.NONE:
		return UiKit.button(key, TOP_BUTTON_VARIATIONS[index], handler)
	var node: IconButton = IconButton.new()
	node.theme_type_variation = TOP_BUTTON_VARIATIONS[index]
	# setup() 必须早于 add_child()：它要写 tooltip 与无障碍名，与 _ready() 无关。
	node.setup(icon, key)
	if handler.is_valid():
		node.pressed.connect(handler)
	return node


## 书页画布。外层是带 9px 厚边的 PanelCanvas，BoardView 铺在框内。
func _build_canvas() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_CANVAS, EditorLayout.canvas_frame()))
	_canvas = BoardView.new()
	_canvas.position = EditorLayout.CANVAS_VIEW_ORIGIN
	_canvas.size = EditorLayout.CANVAS_VIEW_SIZE
	# 卡片被拖到画布边缘时必须被裁掉，否则会画到详情面板上去。
	_canvas.clip_contents = true
	add_child(_canvas)
	_canvas.selection_changed.connect(_on_selection_changed)
	_canvas.edit_started.connect(_push_undo)
	_canvas.edit_finished.connect(_refresh)
	_canvas.link_requested.connect(_on_link_requested)


## 卡片详情。搭建与刷新都在 DetailPanel 里 —— 本屏只需要把它挂上、在选中变化时喊一声。
func _build_detail() -> void:
	_detail = DetailPanel.new()
	_detail.build()
	add_child(_detail)


## 卡牌仓库。横向一排 72px 卡位，超出部分靠滚轮横向滚 —— 自绘，不挂 ScrollContainer
## （内置滚动条要用默认主题的灰色样式，会破坏像素风，见 EditorLayout.TRAY_HEIGHT 的说明）。
func _build_tray() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_FRAME, EditorLayout.tray()))
	_tray_clip = Control.new()
	_tray_clip.position = EditorLayout.TRAY_VIEW_ORIGIN
	_tray_clip.size = EditorLayout.TRAY_VIEW_SIZE
	_tray_clip.clip_contents = true
	_tray_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	_tray_clip.gui_input.connect(_on_tray_input)
	add_child(_tray_clip)

	_tray_row = HBoxContainer.new()
	_tray_row.add_theme_constant_override("separation", int(EditorLayout.TRAY_CHIP_GAP))
	_tray_row.position = Vector2.ZERO
	_tray_clip.add_child(_tray_row)

	var catalog: Array[CardData] = CardCatalog.all()
	for card: CardData in catalog:
		var chip: CardChip = CardChip.new()
		_tray_row.add_child(chip)
		chip.setup(card)
		chip.chosen.connect(_on_chip_chosen)
	# 行宽自己算：容器的 get_combined_minimum_size() 依赖主题解析，headless 下不可靠。
	_tray_count = catalog.size()
	_tray_row.size = Vector2(EditorLayout.tray_content_width(_tray_count), EditorLayout.TRAY_CHIP_SIZE)
	_build_tray_arrows()
	_refresh_tray_arrows()


## 仓库两端的滚动入口（PET-87 §3）。**加在 _tray_clip 之后** —— 后加的是后画的兄弟，
## 落在这 24×48 上的点击先到入口、再到卡位。两端各一个，走到头就自己隐藏：
## 于是停在第 0 格时不会有箭头压着第一张卡，停在终点时也不会有箭头压着最后一张。
func _build_tray_arrows() -> void:
	var sides: Array[float] = [-1.0, 1.0]
	for index: int in sides.size():
		var rect: Rect2 = EditorLayout.tray_arrow_rect(sides[index])
		var arrow: IconButton = IconButton.new()
		arrow.theme_type_variation = TOP_BUTTON_VARIATIONS[1]
		arrow.setup(TRAY_ARROW_ICONS[index], TRAY_ARROW_KEYS[index])
		arrow.position = rect.position
		arrow.size = rect.size
		var delta: float = -EditorLayout.TRAY_SCROLL_STEP if sides[index] < 0.0 else EditorLayout.TRAY_SCROLL_STEP
		arrow.pressed.connect(_scroll_tray.bind(delta))
		add_child(arrow)
		_tray_arrows.append(arrow)


## 哪一端还有内容就把哪一端的入口露出来。
func _refresh_tray_arrows() -> void:
	if _tray_arrows.size() < 2:
		return
	var limit: float = EditorLayout.tray_max_offset(_tray_count)
	_tray_arrows[0].visible = _tray_offset > TRAY_EDGE_EPSILON
	_tray_arrows[1].visible = _tray_offset < limit - TRAY_EDGE_EPSILON


## 仓库的横向滚动。滚轮上下 = 左右滚，点两端的箭头也是同一套停靠算法。
func _on_tray_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var wheel: InputEventMouseButton = event
	if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_tray(EditorLayout.TRAY_SCROLL_STEP)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_tray(-EditorLayout.TRAY_SCROLL_STEP)


## 停在 EditorLayout.tray_stops() 给出的停靠点上，而不是「当前位置 + 一步」。
## 差别就在最后一张卡：按步长累加永远差最后几像素，停靠点里单列的那个终点不会。
func _scroll_tray(delta: float) -> void:
	_tray_offset = EditorLayout.tray_stop_offset(_tray_offset, delta, _tray_count)
	_tray_row.position.x = -_tray_offset
	_refresh_tray_arrows()


func _on_chip_chosen(card_id: StringName) -> void:
	_push_undo()
	var placed: BoardModel.PlacedCard = _board.add_card(card_id, _canvas.free_position())
	_canvas.select(placed.uid)


func _on_selection_changed(_uid: int) -> void:
	_refresh()


## 连线请求。连不成（重复 / 成环 / 自连）时把刚推的快照退回去 —— 没人改过任何东西，
## 不该在撤销栈里留一步空操作。
func _on_link_requested(from_uid: int, to_uid: int) -> void:
	_push_undo()
	if _board.connect_cards(from_uid, to_uid) < 0:
		_undo_stack.pop_back()
		_refresh()


func _on_delete() -> void:
	var uid: int = _canvas.selected_uid()
	if uid == 0:
		return
	_push_undo()
	_board.remove_card(uid)
	_canvas.clear_selection()


func _on_undo() -> void:
	if _undo_stack.is_empty():
		return
	_board.restore(_undo_stack.pop_back())
	if _board.find_card(_canvas.selected_uid()) == null:
		_canvas.clear_selection()
	_refresh()


func _on_start_battle() -> void:
	# 唯一入口是 GameFlow.request_start_combat()（硬规则 R1），本屏不自己换场景。
	if not GameFlow.request_start_combat():
		_refresh()


func _on_open_map() -> void:
	GameFlow.change_state(GameFlow.GameState.MAP)


## 把当前书页推入撤销栈。**必须在改动之前调用** —— 栈里存的是「改之前长什么样」。
func _push_undo() -> void:
	_undo_stack.append(_board.snapshot())
	if _undo_stack.size() > UNDO_LIMIT:
		_undo_stack.pop_front()


func _refresh() -> void:
	_status_label.text = tr("卡片 %d · 丝线 %d") % [_board.cards().size(), _board.links().size()]
	_undo_button.disabled = _undo_stack.is_empty()
	# disabled 没有变更信号，图标不会自己重画 —— 它的颜色要跟着置灰，所以显式刷一次。
	_undo_button.refresh()
	_refresh_detail()


func _refresh_detail() -> void:
	var card: BoardModel.PlacedCard = _board.find_card(_canvas.selected_uid())
	var has_card: bool = card != null and card.data() != null
	if has_card:
		_detail.show_card(card.data(), DetailPanel.reaches_core(_board, card.uid))
	else:
		_detail.show_none()
	_delete_button.disabled = not has_card
	_delete_button.refresh()
