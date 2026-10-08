## editor_tray.gd
## 职责：书槽 —— 槽面 + 672×72 滚动区（18 张卡位）+ 两端 24×48 滚动入口 + 唯一的金底主按钮。
## 所属系统：ui
## 依赖：CardCatalog, CardChip, EditorLayout, UiKit, IconButton, IconPainter, ContractTheme
## 禁止：本文件不得碰模型（放哪张卡由 chip_chosen 交给编辑器）、不得换场景、不得出现裸色值。
##
## 为什么从 editor_screen 里分出来：那一支顶破了 test_source_rules 的 300 行上限，而书槽是它里面
## 唯一**自成一体**的一块 —— 自带一份滚动态（偏移、停靠点），与头栏 / 书本 / 浮层之间只靠
## chip_chosen 与 battle_requested 两个信号说话，不共享任何状态。
##
## 两端入口在**滚动区之外**（§2.1：左 24 / 视区 52 / 右 736）：这样它们结构上就不可能盖住卡位。
## 之前把入口压在滚动区两端，只能靠「走到头就自隐」来回避遮挡，那是补丁不是几何。

class_name EditorTray
extends Control

## 放一张卡进书页。参数是卡表里的 id。
signal chip_chosen(card_id: StringName)
## 请求开始战斗。本控件不碰 GameFlow —— 换场景只有那一条路径（03 §1.1 R3）。
signal battle_requested

## 两端滚动入口的图标与文案 key（左 / 右）。文案只进 tooltip 与无障碍名。
const ARROW_ICONS: Array[IconPainter.Icon] = [
	IconPainter.Icon.ARROW_LEFT,
	IconPainter.Icon.ARROW_RIGHT,
]
const ARROW_KEYS: PackedStringArray = ["仓库向左滚动", "仓库向右滚动"]
## 箭头控件只有 24 宽，图标直径得跟着收（头栏那三颗是 40×32、图标直径 24）。
const ARROW_ICON_RADIUS: float = 8.0

var _clip: Control = null
var _row: HBoxContainer = null
var _offset: float = 0.0
var _count: int = 0
var _arrows: Array[IconButton] = []


## 装配整个书槽。调用方负责 add_child()。
func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_band()
	_build_scroll()
	_build_arrows()
	_build_primary()


## 槽面。和书本同一支边带材质（§3：暖色边带 WARM_500 包住 GOLD_200 面）。
func _build_band() -> void:
	var band: Panel = UiKit.panel(ContractTheme.TYPE_PAGE_BAND, EditorLayout.tray())
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)


## 滚动区：裁切 + 滚轮 + 一行卡位。行宽自己算 —— 容器的 get_combined_minimum_size()
## 依赖主题与字体在树里解析完成，headless 下拿不到系统字体就会返回 0，滚动几何随之失真。
func _build_scroll() -> void:
	_clip = Control.new()
	_clip.position = EditorLayout.TRAY_VIEW_RECT.position
	_clip.size = EditorLayout.TRAY_VIEW_SIZE
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_STOP
	_clip.gui_input.connect(_on_scroll_input)
	add_child(_clip)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", int(EditorLayout.TRAY_CHIP_GAP))
	_clip.add_child(_row)

	var catalog: Array[CardData] = CardCatalog.all()
	for card: CardData in catalog:
		var chip: CardChip = CardChip.new()
		_row.add_child(chip)
		chip.setup(card)
		chip.chosen.connect(_on_chip_chosen)
	_count = catalog.size()
	_row.size = Vector2(EditorLayout.tray_content_width(_count), EditorLayout.TRAY_CHIP_SIZE)


func _build_arrows() -> void:
	for side: float in [-1.0, 1.0]:
		var index: int = 0 if side < 0.0 else 1
		var arrow: IconButton = UiKit.icon_button(ContractTheme.TYPE_BUTTON_PAGE_ICON,
			ARROW_ICONS[index], ARROW_ICON_RADIUS, ARROW_KEYS[index], Callable())
		arrow.position = EditorLayout.tray_arrow_rect(side).position
		arrow.size = EditorLayout.tray_arrow_rect(side).size
		var step: float = -EditorLayout.TRAY_SCROLL_STEP if side < 0.0 else EditorLayout.TRAY_SCROLL_STEP
		arrow.pressed.connect(func() -> void: scroll(step))
		add_child(arrow)
		_arrows.append(arrow)
	_refresh_arrows()


## 全屏唯一的金底主按钮（§2.1 EDITOR_PRIMARY，也是全屏唯一带文字的按钮）。
func _build_primary() -> void:
	var primary: Button = UiKit.button(EditorLayout.PRIMARY_KEY,
		ContractTheme.TYPE_BUTTON_PAGE_PRIMARY, _on_primary_pressed)
	var rect: Rect2 = EditorLayout.primary_rect()
	primary.position = rect.position
	primary.size = rect.size
	add_child(primary)


func card_count() -> int:
	return _count


func offset() -> float:
	return _offset


## 当前偏移下露在最左的那张卡的下标 —— 截图脚本与测试用它确认「末卡整张可见」。
func first_visible_index() -> int:
	return int(floor(_offset / EditorLayout.tray_pitch()))


func arrow(side: float) -> IconButton:
	return _arrows[0] if side < 0.0 else _arrows[1]


## 滚到下一个 / 上一个停靠点。停靠点由 EditorLayout 给（含单列的终点），
## 这里只负责把行挪过去 —— 「能不能滚」与本控件无关。
func scroll(delta: float) -> void:
	_offset = EditorLayout.tray_stop_offset(_offset, delta, _count)
	_row.position.x = -_offset
	_refresh_arrows()


## 哪一端还有内容就把哪一端的入口露出来。
func _refresh_arrows() -> void:
	if _arrows.size() < 2:
		return
	var limit: float = EditorLayout.tray_max_offset(_count)
	_arrows[0].visible = _offset > EditorLayout.TRAY_EDGE_EPSILON
	_arrows[1].visible = _offset < limit - EditorLayout.TRAY_EDGE_EPSILON


## 滚轮上下 = 左右滚。触屏没有滚轮，所以两端另有两颗常驻入口（这就是它们的理由）。
func _on_scroll_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var wheel: InputEventMouseButton = event
	if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll(EditorLayout.TRAY_SCROLL_STEP)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll(-EditorLayout.TRAY_SCROLL_STEP)


func _on_chip_chosen(card_id: StringName) -> void:
	chip_chosen.emit(card_id)


func _on_primary_pressed() -> void:
	battle_requested.emit()
