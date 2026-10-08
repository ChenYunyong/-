## detail_panel.gd
## 职责：卡片详情**浮层**（docs/14 §2.1 DETAIL_POPOVER）—— 名字 / 收起键 / 类型 / 参数 / 说明。
## 所属系统：ui
## 依赖：EditorLayout, UiKit, IconButton, IconPainter, ContractTheme, BoardModel, CardData, CardCatalog
## 禁止：本文件不得查书页（数据由 editor 传进来）、不得持有选中状态（真值在 BoardView 上）、
##       不得出现裸色值、不得自己换场景。
##
## PET-93 之前它是常驻右栏；契约 §2.1 改成**按需浮层**，性质跟着变了三处：
##   · 只在选中卡时出现（show_card 开 / show_none 关），不再长期占版面 —— E02 量的正是
##     「纸区扣掉 224×240 之后仍 ≥48%」，常驻侧栏量不出这个数；
##   · 浮层自己**截获本区域输入**（浮层那一层 STOP）：从它上面按下去不会穿透去拖背后的卡；
##   · 收起只是「取消选中」的一个视图。本控件不持有选中状态，只上报 close_requested，
##     由 editor 清掉选中 —— 浮层开关因此不改动任何模型坐标（E02 后半句）。
##
## 空书页的操作引导**不在这里**：§2.1 没给空态提示独立的 rect，故它落在头栏的计数行上
## （见 editor_screen._refresh_counts）。这是为了不凭空发明版面而做的取舍。

class_name DetailPanel
extends Control

## 收起键的文案 key（只进 tooltip 与无障碍名）。24×24 里放 16 直径的叉，四周各留 4。
const CLOSE_KEY: String = "关闭详情"
const CLOSE_ICON_RADIUS: float = 8.0

## 玩家按下收起键。本控件不自己清选中 —— 选中的唯一真值在画布上。
signal close_requested

var _name_label: Label = null
var _close_button: IconButton = null
var _type_label: Label = null
var _stats_label: Label = null
var _note_label: Label = null


## 建浮层。五块内容全用 EditorLayout 的**整屏坐标**摆放，本控件只是个容器：
## 自身 IGNORE（不挡画布），浮层那一层 STOP（只挡它自己那 224×240）。
func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop: Panel = UiKit.panel(ContractTheme.TYPE_POPOVER, EditorLayout.popover())
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	_name_label = UiKit.label("", EditorLayout.detail_name_rect(), ContractTheme.TYPE_LABEL_DETAIL_NAME)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_label = UiKit.label("", EditorLayout.detail_type_rect(), ContractTheme.TYPE_LABEL_BODY_MUTED)
	_type_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stats_label = UiKit.wrapped_label("", EditorLayout.detail_stats_rect(), ContractTheme.TYPE_LABEL_BODY)
	_note_label = UiKit.wrapped_label("", EditorLayout.detail_note_rect(),
		ContractTheme.TYPE_LABEL_CAPTION_DANGER)
	for node: Label in [_name_label, _type_label, _stats_label, _note_label]:
		add_child(node)

	# 收起键**最后加**：同层里后加的在上，这颗才压在浮层底之上收得到点击。
	var rect: Rect2 = EditorLayout.detail_close_rect()
	_close_button = IconButton.new()
	_close_button.theme_type_variation = ContractTheme.TYPE_BUTTON_PAGE_ICON
	_close_button.icon_radius = CLOSE_ICON_RADIUS
	_close_button.setup(IconPainter.Icon.CLOSE, CLOSE_KEY)
	_close_button.position = rect.position
	_close_button.size = rect.size
	_close_button.pressed.connect(_on_close_pressed)
	add_child(_close_button)


## 收起键。本控件只上报意图 —— 清选中是 editor 的事。
func _on_close_pressed() -> void:
	close_requested.emit()


## 没有选中任何卡：整个浮层收起（连内容一起，不只是藏起来）。
func show_none() -> void:
	visible = false


## 展示一张卡并打开浮层。connected = 这张卡顺着入边走得到核心卡（走不到就不会被施放）。
func show_card(data: CardData, connected: bool) -> void:
	if data == null:
		show_none()
		return
	visible = true
	_name_label.text = tr(data.name_key)
	_type_label.text = "%s · %s" % [tr(CardCatalog.kind_label_key(data)),
		tr(CardCatalog.type_label_key(data))]
	_stats_label.text = _stats_text(data)
	_note_label.text = "" if connected else tr("未连接核心，不会被施放")


## 参数组。只列这张卡真正有的字段，没有的不占位（避免「费用 0」这种噪音）。
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
## 详情浮层要明确告诉玩家，而不是让他自己拉线数。
static func reaches_core(model: BoardModel, uid: int) -> bool:
	var stack: Array[int] = [uid]
	var seen: Dictionary = {}
	while not stack.is_empty():
		var current: int = stack.pop_back()
		if seen.has(current):
			continue
		seen[current] = true
		var card: BoardModel.PlacedCard = model.find_card(current)
		if card == null:
			continue
		if card.data() != null and card.data().is_core():
			return true
		for link: BoardModel.Link in model.links():
			if link.to_uid == current:
				stack.append(link.from_uid)
	return false
