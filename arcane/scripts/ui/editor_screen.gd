## editor_screen.gd
## 职责：模块编辑器（奥术蓝图）—— 本作的招牌屏，装配头栏 / 书页 / 详情浮层 / 书槽。
## 所属系统：ui
## 依赖：RunState, BoardModel, BoardView, CardCatalog, DetailPanel, EditorTray, EditorLayout,
##       UiKit, IconButton, IconPainter, GameFlow, ContractTheme
## 禁止：本文件不得实现吸附几何（在 Snap 里）、不得实现绘制（在 BoardView / CardFace 里）、
##       不得实现书槽滚动（在 EditorTray 里）；不得出现裸色值；
##       不得自己调 change_scene_to_file()（03 §1.1 R3：只有 GameFlow 能换场景）。
##
## docs/14 §2.1 落成之后的版面：头栏 40 高（只有三颗 40×32 图标控件）、书本撑到整宽 928×360、
## 详情从常驻侧栏改成**按需浮层**、唯一的金底主按钮搬到书槽右端。本屏要证明的两件事不变：
##   1. **无网格**：卡片位置就是自由浮点坐标，界面任何一处都不做坐标量化；
##   2. **自由吸附**：只在拖到别的卡片附近时吸，并当场画出辅助线 + 金色高亮。

extends Control

## 撤销栈深度。够用即可 —— 这不是编辑器，是搭配界面的防手滑。
const UNDO_LIMIT: int = 32

## 头栏三颗图标控件的图标，顺序与 EditorLayout.TOP_BUTTONS 一致（**从右往左**）。
const TOP_BUTTON_ICONS: Array[IconPainter.Icon] = [
	IconPainter.Icon.MAP,
	IconPainter.Icon.DELETE,
	IconPainter.Icon.UNDO,
]
## 需要按状态置灰的那两颗在 TOP_BUTTONS 里的下标。
const TOP_BUTTON_DELETE: int = 1
const TOP_BUTTON_UNDO: int = 2
## 空书页时的操作引导。**落在头栏的计数行上**：§2.1 没有给空态提示独立的 rect，
## 凭空加一块面板就是自己发明版面。计数行 400 宽、16/24，这一句 14 字占 ≈224，装得下。
const HINT_EMPTY_KEY: String = "点下方仓库的卡片放到书页上"

## 书页就是**本局那一份**（RunState.board()），在 _ready() 里绑定。
## 不各持一份：编辑器改的和战斗读的必须是同一个对象，否则玩家连的线战斗根本看不到
## （loop_smoke 就是钉这一条的 —— 两份书页的话那条用例会红在「战斗队列是空的」）。
var _board: BoardModel = null
var _undo_stack: Array[Dictionary] = []

var _canvas: BoardView = null
var _tray: EditorTray = null
var _detail: DetailPanel = null
var _counts_label: Label = null
var _undo_button: IconButton = null
var _delete_button: IconButton = null
## 正在拖卡。浮层靠在净纸右上角，正是最常摆卡的地方 —— 拖动期间它必须让开。
## 光在 edit_started 里藏一次不够：拖动中模型每动一下都发 changed，_refresh 会把浮层又打开。
var _dragging: bool = false


func _ready() -> void:
	_board = RunState.board()
	# 顺序即层级：暗底 → 头栏 → 书本 → 画布 → 详情浮层 → 书槽。改顺序前先看每一层的注释。
	_build_backdrop()
	_build_header()
	_build_book()
	_build_detail()
	_build_tray()
	_canvas.setup(_board)
	_board.changed.connect(_refresh)
	_canvas.edit_started.connect(_on_edit_started)
	_canvas.edit_finished.connect(_on_edit_finished)
	_refresh()


## 全屏暗背景。**G06 靠它**：不铺满这一层，书页之外露的就是引擎默认灰 RGB(76,76,76)。
func _build_backdrop() -> void:
	add_child(_decor(ContractTheme.TYPE_BACKDROP, Rect2(Vector2.ZERO, EditorLayout.SCREEN)))


## 头栏：标题 · 计数 · 路线图/删除/撤销。§2.1 的头栏 R0/S0 —— 不带面板，文字直接落在暗底上。
func _build_header() -> void:
	var title: Label = UiKit.label(tr("模块编辑器"), EditorLayout.TITLE_RECT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	_counts_label = UiKit.label("", EditorLayout.COUNTS_RECT, ContractTheme.TYPE_LABEL_BODY_MUTED)
	_counts_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_counts_label)

	var handlers: Array[Callable] = [_on_open_map, _on_delete, _on_undo]
	var rects: Array[Rect2] = EditorLayout.top_button_rects()
	for index: int in rects.size():
		var button: IconButton = UiKit.icon_button(ContractTheme.TYPE_BUTTON_PAGE_ICON,
			TOP_BUTTON_ICONS[index], EditorLayout.HEADER_ICON_SIZE * 0.5,
			EditorLayout.TOP_BUTTONS[index], handlers[index])
		button.position = rects[index].position
		button.size = rects[index].size
		add_child(button)
		# 这两颗要按状态置灰，留个引用（下标与 EditorLayout.TOP_BUTTONS 对齐）。
		if index == TOP_BUTTON_DELETE:
			_delete_button = button
		elif index == TOP_BUTTON_UNDO:
			_undo_button = button


## 书本三层（§2.1）：8px 暖色边带的外框 → 净纸 → 上左来光。书脊夹在纸与卡之间 ——
## 它是纯装饰，必须画在卡片**下面**，否则会压住摆在中间那列的卡。
func _build_book() -> void:
	add_child(_decor(ContractTheme.TYPE_PAGE_BAND, EditorLayout.book()))
	add_child(_decor(ContractTheme.TYPE_PAGE_LEAF, EditorLayout.paper()))
	add_child(_decor(ContractTheme.TYPE_PAGE_HILIGHT, EditorLayout.paper()))
	add_child(_decor(ContractTheme.TYPE_PAGE_SPINE, EditorLayout.spine()))

	_canvas = BoardView.new()
	_canvas.position = EditorLayout.CANVAS_VIEW_ORIGIN
	_canvas.size = EditorLayout.CANVAS_VIEW_SIZE
	# 卡片被拖到画布边缘时必须被裁掉，否则会画到书本的边带上。
	_canvas.clip_contents = true
	add_child(_canvas)
	_canvas.selection_changed.connect(_on_selection_changed)
	_canvas.link_requested.connect(_on_link_requested)


## 书槽（§2.1 EDITOR_TRAY）整个交给 EditorTray —— 它自带滚动态，本屏只管接它的两个信号。
func _build_tray() -> void:
	_tray = EditorTray.new()
	_tray.build()
	_tray.chip_chosen.connect(_on_chip_chosen)
	_tray.battle_requested.connect(_on_start_battle)
	add_child(_tray)


## 卡片详情（§2.1 的 DETAIL_POPOVER）：搭建与刷新都在 DetailPanel 里 ——
## 本屏只需要挂上它、在选中变化时喊一声、并把它接在**画布之后**（浮层要压在卡上面）。
func _build_detail() -> void:
	_detail = DetailPanel.new()
	_detail.build()
	_detail.close_requested.connect(_on_close_detail)
	add_child(_detail)


## 装饰层：契约的材质面板一律不吃鼠标 —— 手势必须留给画布，不能落在纸上那几层。
func _decor(variation: StringName, rect: Rect2) -> Panel:
	var panel: Panel = UiKit.panel(variation, rect)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _on_chip_chosen(card_id: StringName) -> void:
	_push_undo()
	var placed: BoardModel.PlacedCard = _board.add_card(card_id, _canvas.free_position())
	_canvas.select(placed.uid)


func _on_selection_changed(_uid: int) -> void:
	_refresh()


## 浮层上的关闭键：收起浮层 = 取消选中。选中是画布的事实，收起只是它的一个视图，
## 因此这里改的是选中本身，不另设一个「已关闭」标志 —— 两处状态迟早会对不上。
func _on_close_detail() -> void:
	_canvas.clear_selection()


## 一次编辑开始的全部动作：快照（必须在改动之前）+ 让开浮层。
func _on_edit_started() -> void:
	_dragging = true
	_push_undo()
	_refresh_detail()


func _on_edit_finished() -> void:
	_dragging = false
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
	_refresh_counts()
	_undo_button.disabled = _undo_stack.is_empty()
	# disabled 没有变更信号，图标不会自己重画 —— 它的颜色要跟着置灰，所以显式刷一次。
	_undo_button.refresh()
	_refresh_detail()


## 计数行。书页空着时改说一句怎么开始 —— 这一屏的操作引导只有这一处落点（见 HINT_EMPTY_KEY）。
func _refresh_counts() -> void:
	var cards: int = _board.cards().size()
	if cards == 0:
		_counts_label.text = tr(HINT_EMPTY_KEY)
		return
	_counts_label.text = tr("卡片 %d · 丝线 %d") % [cards, _board.links().size()]


## 浮层只在「选中了一张卡、且当前没在拖」时出现。拖动期间它保持收起：
## 它压在净纸右上角，而那正是最常落卡的地方，跟着拖动一起晃会挡住落点。
func _refresh_detail() -> void:
	var card: BoardModel.PlacedCard = _board.find_card(_canvas.selected_uid())
	var has_card: bool = card != null and card.data() != null
	_delete_button.disabled = not has_card
	_delete_button.refresh()
	if _dragging or not has_card:
		_detail.show_none()
		return
	_detail.show_card(card.data(), DetailPanel.reaches_core(_board, card.uid))
