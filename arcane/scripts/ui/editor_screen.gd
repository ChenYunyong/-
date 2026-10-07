## editor_screen.gd
## 职责：模块编辑器（奥术蓝图）—— 本作的招牌屏，装配顶栏 / 书页画布 / 卡片详情 / 卡牌仓库。
## 所属系统：ui
## 依赖：RunState, BoardModel, BoardView, CardCatalog, EditorLayout, UiKit, GameFlow, ArcaneTheme
## 禁止：本文件不得实现吸附几何（在 Snap 里）、不得实现绘制（在 BoardView / CardFace 里）；
##       不得出现裸色值；不得自己调 change_scene_to_file()（03 §1.1 R3：只有 GameFlow 能换场景）。
##
## 本屏要证明的两件事（PET-85 验收点）：
##   1. **无网格**：卡片位置就是自由浮点坐标，界面任何一处都不做坐标量化；
##   2. **自由吸附**：只在拖到别的卡片附近时吸，并当场画出辅助线 + 金色高亮。

extends Control

## 空书页时的引导文案。第二段讲连线，两句都只在「没选中任何卡」时出现。
const HINT_EMPTY_KEY: String = "点下方仓库的卡片放到书页上"
const HINT_LINK_KEY: String = "从卡片接口拖出奥术丝线连接另一张卡"

## 撤销栈深度。够用即可 —— 这不是编辑器，是搭配界面的防手滑。
const UNDO_LIMIT: int = 32

## 顶栏按钮的变体，顺序与 EditorLayout.TOP_BUTTONS 一致（最右是主动作）。
const TOP_BUTTON_VARIATIONS: Array[StringName] = [
	ArcaneTheme.TYPE_BUTTON_PRIMARY,
	ArcaneTheme.TYPE_BUTTON_SECONDARY,
	ArcaneTheme.TYPE_BUTTON_SECONDARY,
	ArcaneTheme.TYPE_BUTTON_SECONDARY,
]
## 需要按状态置灰的那两个按钮在 TOP_BUTTONS 里的下标。
const TOP_BUTTON_DELETE: int = 2
const TOP_BUTTON_UNDO: int = 3

## 书页就是**本局那一份**（RunState.board()），在 _ready() 里绑定。
## 不各持一份：编辑器改的和战斗读的必须是同一个对象，否则玩家连的线战斗根本看不到
## （loop_smoke 就是钉这一条的 —— 两份书页的话那条用例会红在「战斗队列是空的」）。
var _board: BoardModel = null
var _undo_stack: Array[Dictionary] = []

var _canvas: BoardView = null
var _tray_clip: Control = null
var _tray_row: HBoxContainer = null
var _tray_offset: float = 0.0

var _status_label: Label = null
var _name_label: Label = null
var _type_label: Label = null
var _stats_label: Label = null
var _warn_label: Label = null
var _hint_label: Label = null
var _undo_button: Button = null
var _delete_button: Button = null


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
		var button: Button = UiKit.button(key, TOP_BUTTON_VARIATIONS[index], handlers[index])
		button.position = rects[index].position
		button.size = rects[index].size
		add_child(button)
		# 这两个按钮要按状态置灰，留个引用（下标与 EditorLayout.TOP_BUTTONS 对齐）。
		if index == TOP_BUTTON_DELETE:
			_delete_button = button
		elif index == TOP_BUTTON_UNDO:
			_undo_button = button


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


## 卡片详情。三层结构（06 §2.1）：木框 PanelFrame 包住 NAVY_800 的 PanelSecondary，
## 顶部一条 48 高的标题栏。
func _build_detail() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_FRAME, EditorLayout.detail_panel()))
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, EditorLayout.detail_body()))
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_TITLE_BAR, EditorLayout.detail_title_bar()))

	var title_rect: Rect2 = EditorLayout.detail_title_bar()
	title_rect.position.x += EditorLayout.DETAIL_PADDING
	title_rect.size.x -= EditorLayout.DETAIL_PADDING * 2.0
	var title: Label = UiKit.label(tr("卡片详情"), title_rect)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	var origin: Vector2 = EditorLayout.DETAIL_CONTENT_ORIGIN
	var width: float = EditorLayout.DETAIL_CONTENT_WIDTH
	var line: float = EditorLayout.LINE_HEIGHT
	_name_label = UiKit.label("", Rect2(origin, Vector2(width, line)))
	_type_label = UiKit.label("", Rect2(origin + Vector2(0.0, line), Vector2(width, line)),
		ArcaneTheme.TYPE_LABEL_SECONDARY)
	_stats_label = UiKit.wrapped_label("", Rect2(origin + Vector2(0.0, line * 2.0), Vector2(width, line * 2.0)))
	_warn_label = UiKit.wrapped_label("", Rect2(origin + Vector2(0.0, line * 4.0), Vector2(width, line * 1.6)),
		ArcaneTheme.TYPE_LABEL_DANGER)
	_hint_label = UiKit.wrapped_label("%s\n\n%s" % [tr(HINT_EMPTY_KEY), tr(HINT_LINK_KEY)],
		Rect2(origin, Vector2(width, line * 4.0)), ArcaneTheme.TYPE_LABEL_SECONDARY)
	for node: Label in [_name_label, _type_label, _stats_label, _warn_label, _hint_label]:
		add_child(node)


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
	var count: int = catalog.size()
	var content_width: float = float(count) * EditorLayout.TRAY_CHIP_SIZE
	if count > 1:
		content_width += float(count - 1) * EditorLayout.TRAY_CHIP_GAP
	_tray_row.size = Vector2(content_width, EditorLayout.TRAY_CHIP_SIZE)


## 仓库的横向滚动。滚轮上下 = 左右滚。
func _on_tray_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var wheel: InputEventMouseButton = event
	if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_tray(EditorLayout.TRAY_SCROLL_STEP)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_tray(-EditorLayout.TRAY_SCROLL_STEP)


func _scroll_tray(delta: float) -> void:
	var limit: float = maxf(0.0, _tray_row.size.x - _tray_clip.size.x)
	_tray_offset = clampf(_tray_offset + delta, 0.0, limit)
	_tray_row.position.x = -_tray_offset


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
	_refresh_detail()


func _refresh_detail() -> void:
	var card: BoardModel.PlacedCard = _board.find_card(_canvas.selected_uid())
	var has_card: bool = card != null
	_hint_label.visible = not has_card
	for node: Label in [_name_label, _type_label, _stats_label, _warn_label]:
		node.visible = has_card
	_delete_button.disabled = not has_card
	if not has_card:
		return
	var data: CardData = card.data()
	if data == null:
		return
	_name_label.text = tr(data.name_key)
	_type_label.text = "%s · %s" % [tr(CardCatalog.kind_label_key(data)), tr(CardCatalog.type_label_key(data))]
	_stats_label.text = _stats_text(data)
	_warn_label.text = "" if _reaches_core(card.uid) else tr("未连接核心，不会被施放")


## 详情里的数值行。只列这张卡真正有的字段，没有的不占位（避免「费用 0」这种噪音）。
func _stats_text(data: CardData) -> String:
	var lines: PackedStringArray = PackedStringArray()
	if data.mana_output > 0:
		lines.append("%s %d" % [tr("魔力产出"), data.mana_output])
	if data.mana_cost > 0:
		lines.append("%s %d" % [tr("费用"), data.mana_cost])
	if data.damage > 0:
		lines.append("%s %d" % [tr("伤害"), data.damage])
	return "\n".join(lines)


## 顺着入边一路往回找，能不能走到一张核心卡。找不到 = 这张卡在战斗里不会被施放，
## 详情面板要明确告诉玩家，而不是让他自己拉线数。
func _reaches_core(uid: int) -> bool:
	var stack: Array[int] = [uid]
	var seen: Dictionary = {}
	while not stack.is_empty():
		var current: int = stack.pop_back()
		if seen.has(current):
			continue
		seen[current] = true
		var card: BoardModel.PlacedCard = _board.find_card(current)
		if card == null:
			continue
		if card.data() != null and card.data().is_core():
			return true
		for link: BoardModel.Link in _board.links():
			if link.to_uid == current:
				stack.append(link.from_uid)
	return false
