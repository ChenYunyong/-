## board_renderer.gd
## 职责：把一层书页画出来 —— 丝线 / 卡面与两层状态 / 接口 / 辅助线 / 连线预览，并持有取色缓存。
## 所属系统：editor（绘制辅助）
## 依赖：BoardModel, CardFace, BoardStatePainter, ThreadPainter, Palette
## 禁止：本文件不得处理输入事件、不得改模型 —— 它只读状态、只落笔。
##
## 为什么从 BoardView 里分出来：BoardView 的职责是**手势**（谁被按下、拖到哪、连给谁），
## 绘制只是它的下游。两者混在一个文件里时，加一种状态就要动一次手势代码，
## 而这个文件已经顶到 test_source_rules 的 300 行上限了。
##
## 绘制状态（指点、连线起点、吸附回执）放在这里，手势状态（拖动、悬停）留在 BoardView ——
## 分界线是「这个东西除了画出来还有没有别的用处」：拖动位置要写回模型，所以它不算绘制状态。
##
## 层级顺序（13 §10.1）：丝线在卡**后**，辅助线在卡**前**。顺序即 _draw_* 的调用顺序。

class_name BoardRenderer
extends RefCounted

## 绘制状态。BoardView 在手势里写，这里在 _draw 里读。
var selected_uid: int = 0
var focus_uid: int = 0
var pointer: Vector2 = Vector2.ZERO
var link_from: int = 0
## 吸附回报的辅助线：坐标与**该画多长**一一对应同序（范围由 Snap 按相关两卡算出）。
var guides_v: Array[float] = []
var guides_h: Array[float] = []
var spans_v: Array[Vector2] = []
var spans_h: Array[Vector2] = []
var snapped: bool = false

## 取色缓存。**来源仍是 Palette.get_color()** —— 缓存只为不在每帧 _draw 里反复查表。
var card_fill: Color = Palette.MISSING_COLOR
var card_selected: Color = Palette.MISSING_COLOR
var text: Color = Palette.MISSING_COLOR
var link: Color = Palette.MISSING_COLOR
var link_active: Color = Palette.MISSING_COLOR
var guide: Color = Palette.MISSING_COLOR
var selected: Color = Palette.MISSING_COLOR
var focus: Color = Palette.MISSING_COLOR
var port_in: Color = Palette.MISSING_COLOR
var port_out: Color = Palette.MISSING_COLOR


func _init() -> void:
	card_fill = Palette.get_color(Palette.Key.NAVY_800)
	card_selected = Palette.get_color(Palette.Key.NAVY_700)
	text = Palette.get_color(Palette.Key.BLUE_100)
	# 丝线整体退到卡后：BLUE_400 常驻、激活时提亮到 BLUE_300。**金色不再参与连线**，
	# 否则「金线」既可能是丝线也可能是辅助线，13 §10.1 要求的那种区分就无从谈起。
	link = Palette.get_color(Palette.Key.BLUE_400)
	link_active = Palette.get_color(Palette.Key.BLUE_300)
	guide = Palette.get_color(Palette.Key.GOLD_400)
	# 选中用金色（唯一承担「选中」的色），焦点用浅蓝细角标。
	selected = Palette.get_color(Palette.Key.GOLD_500)
	focus = Palette.get_color(Palette.Key.BLUE_300)
	# 两个接口用同族深浅区分进出口：输入 BLUE_200、输出 BLUE_400。
	port_in = Palette.get_color(Palette.Key.BLUE_200)
	port_out = Palette.get_color(Palette.Key.BLUE_400)


## 一次画完整层。顺序即层级，别调换。view_size 是画布控件的尺寸（角标要贴它的右上角）。
func paint(target: CanvasItem, model: BoardModel, view_size: Vector2) -> void:
	_paint_links(target, model)
	for card: BoardModel.PlacedCard in model.cards():
		_paint_card(target, card)
	BoardStatePainter.paint_guides(target, guides_v, spans_v, guides_h, spans_h, guide)
	if snapped:
		paint_snap_badge(target, view_size, TranslationServer.translate("吸附"), guide)
	if link_from != 0:
		paint_link_preview(target, model, pointer)


func _paint_links(target: CanvasItem, model: BoardModel) -> void:
	for link_item: BoardModel.Link in model.links():
		var source: BoardModel.PlacedCard = model.find_card(link_item.from_uid)
		var target_card: BoardModel.PlacedCard = model.find_card(link_item.to_uid)
		if source == null or target_card == null:
			continue
		var hot: bool = link_item.from_uid == selected_uid or link_item.to_uid == selected_uid
		ThreadPainter.paint(target, BoardView.output_port(source), BoardView.input_port(target_card),
			link_active if hot else link)


## 画一张卡：牌面（不含状态）→ 选中轮廓 → 焦点角标 → 接口。
## 三者顺序固定，因此「既选中又有焦点」时两种状态叠得可预期。
func _paint_card(target: CanvasItem, card: BoardModel.PlacedCard) -> void:
	var is_selected: bool = card.uid == selected_uid
	var is_focused: bool = card.uid == focus_uid
	# 选中是**状态**，不改牌面：底板抬升一档，轮廓与角标画在卡外 / 卡缘内侧。
	CardFace.paint(target, card.data(), card.position,
		card_selected if is_selected else card_fill, text)
	if is_selected:
		BoardStatePainter.paint_selected(target, BoardView.card_rect(card), selected)
	if is_focused:
		BoardStatePainter.paint_focus(target, BoardView.card_rect(card), focus)
	if is_selected or is_focused:
		paint_ports(target, card)


## 两个接口圆点。它是**填充**而不是笔画，故直接 draw_circle —— 这笔不属于 StrokePainter 的线。
func paint_ports(target: CanvasItem, card: BoardModel.PlacedCard) -> void:
	target.draw_circle(BoardView.input_port(card), BoardView.PORT_RADIUS, port_in)
	target.draw_circle(BoardView.output_port(card), BoardView.PORT_RADIUS, port_out)


## 吸附瞬间的角标。位置固定在画布右上角，不跟着卡片乱跑（避免遮挡正在看的卡）。
static func paint_snap_badge(target: CanvasItem, view_size: Vector2, text_in: String,
		color: Color) -> void:
	var font: Font = target.get_theme_default_font()
	var font_size: int = target.get_theme_default_font_size()
	if font == null:
		return
	var width: float = font.get_string_size(text_in, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	target.draw_string(font, Vector2(view_size.x - width - 12.0, float(font_size) + 4.0), text_in,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## 拖拉中的丝线预览：从起点接口到指针（指针压在别的卡上时吸到那张卡的输入接口）。
func paint_link_preview(target: CanvasItem, model: BoardModel, at: Vector2) -> void:
	var source: BoardModel.PlacedCard = model.find_card(link_from)
	if source == null:
		return
	var end: Vector2 = at
	var hovered: BoardModel.PlacedCard = find_card_at(model, at)
	if hovered != null and hovered.uid != link_from:
		end = BoardView.input_port(hovered)
	ThreadPainter.paint(target, BoardView.output_port(source), end, link_active)


## 命中测试。倒序遍历 = 后画的在上，点谁选谁。
static func find_card_at(model: BoardModel, at: Vector2) -> BoardModel.PlacedCard:
	var cards: Array[BoardModel.PlacedCard] = model.cards()
	for index: int in range(cards.size() - 1, -1, -1):
		if BoardView.card_rect(cards[index]).has_point(at):
			return cards[index]
	return null
