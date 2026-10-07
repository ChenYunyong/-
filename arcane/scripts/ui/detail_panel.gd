## detail_panel.gd
## 职责：右侧「卡片详情」面板 —— 木框 / 标题栏 / 三级排版的四段行，以及无选中时的引导文案。
## 所属系统：ui
## 依赖：EditorLayout, UiKit, ArcaneTheme, BoardModel, CardData, CardCatalog
## 禁止：本文件不得查书页（数据由 editor 传进来）、不得出现裸色值、不得自己换场景。
##
## PET-87 §3：名字 / 类型 / 参数原本字号与亮度都太接近，读不出主次。现在分三级，
## **行高在 EditorLayout 里按字号倒推**（每段 = 字号 × 1.25 × 最坏行数），四段之和
## 受 DETAIL_CONTENT_HEIGHT 约束 —— 以后想加一段，test_layout 会先拦下来。
##
## 面板是 Control 但自己不画也不占地方：三个 Panel 与五个 Label 都用 EditorLayout 给的
## **整屏坐标**摆放，本控件只是个把四段刷新技术收在一处的容器（mouse_filter 因此设成 IGNORE）。

class_name DetailPanel
extends Control

## 空书页时的引导文案。第二段讲连线，两句都只在「没选中任何卡」时出现。
const HINT_EMPTY_KEY: String = "点下方仓库的卡片放到书页上"
const HINT_LINK_KEY: String = "从卡片接口拖出奥术丝线连接另一张卡"

var _name_label: Label = null
var _type_label: Label = null
var _stats_label: Label = null
var _warn_label: Label = null
var _hint_label: Label = null


## 建面板。三层结构（06 §2.1）：木框 PanelFrame 包住 NAVY_800 的 PanelSecondary，
## 顶部一条 48 高的标题栏。
func build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_FRAME, EditorLayout.detail_panel()))
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, EditorLayout.detail_body()))
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_TITLE_BAR, EditorLayout.detail_title_bar()))

	var title_rect: Rect2 = EditorLayout.detail_title_bar()
	title_rect.position.x += EditorLayout.DETAIL_PADDING
	title_rect.size.x -= EditorLayout.DETAIL_PADDING * 2.0
	var title: Label = UiKit.label(tr("卡片详情"), title_rect)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	_name_label = UiKit.label("", EditorLayout.detail_name_rect(), ArcaneTheme.TYPE_LABEL_TITLE)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_label = UiKit.label("", EditorLayout.detail_type_rect(), ArcaneTheme.TYPE_LABEL_SECONDARY)
	_stats_label = UiKit.wrapped_label("", EditorLayout.detail_stats_rect(), ArcaneTheme.TYPE_LABEL_PARAM)
	_warn_label = UiKit.wrapped_label("", EditorLayout.detail_warn_rect(), ArcaneTheme.TYPE_LABEL_WARN)
	_hint_label = UiKit.wrapped_label("%s\n\n%s" % [tr(HINT_EMPTY_KEY), tr(HINT_LINK_KEY)],
		Rect2(EditorLayout.DETAIL_CONTENT_ORIGIN,
			Vector2(EditorLayout.DETAIL_CONTENT_WIDTH, EditorLayout.DETAIL_CONTENT_HEIGHT)),
		ArcaneTheme.TYPE_LABEL_SECONDARY)
	for node: Label in [_name_label, _type_label, _stats_label, _warn_label, _hint_label]:
		add_child(node)


## 没有选中任何卡：四段全隐，只留引导文案。
func show_none() -> void:
	_hint_label.visible = true
	for node: Label in _rows():
		node.visible = false


## 展示一张卡。connected = 这张卡顺着入边走得到核心卡（走不到就不会被施放）。
func show_card(data: CardData, connected: bool) -> void:
	_hint_label.visible = false
	for node: Label in _rows():
		node.visible = true
	if data == null:
		return
	_name_label.text = tr(data.name_key)
	_type_label.text = "%s · %s" % [tr(CardCatalog.kind_label_key(data)),
		tr(CardCatalog.type_label_key(data))]
	_stats_label.text = _stats_text(data)
	_warn_label.text = "" if connected else tr("未连接核心，不会被施放")


func _rows() -> Array[Label]:
	return [_name_label, _type_label, _stats_label, _warn_label]


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
## 详情面板要明确告诉玩家，而不是让他自己拉线数。
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
