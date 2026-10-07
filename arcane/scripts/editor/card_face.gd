## card_face.gd
## 职责：一张卡面的画法（底板 + 类型色描边 + 图形标记 + 短标记）。
## 所属系统：editor（绘制辅助）
## 依赖：CardData, GlyphPainter, CardCatalog, Palette
## 禁止：本文件不得出现裸色值、不得自己决定类型色 —— 类型色只在 CardCatalog.accent_token() 里定义。
##
## 画布上的卡与仓库里的卡位**必须长得一模一样**（用户在仓库里认出的牌，落到画布上还得是同一张），
## 因此两边共用这一个画法，而不是各画各的。

class_name CardFace
extends RefCounted

## 画布卡与仓库卡位共用的尺寸。**取自 BoardModel** —— 卡的占地大小是模型事实，
## 绘制只能照它画，另写一个数就迟早会和重叠判定 / 吸附参照对不上。
const SIZE: Vector2 = BoardModel.CARD_SIZE
const GLYPH_CENTER_Y: float = 26.0
const GLYPH_RADIUS: float = 16.0
## 短标记的基线纵向偏移。
const MARK_BASELINE_Y: float = 64.0
const BORDER_WIDTH: float = 3.0
## 高亮（选中 / 吸附）时的描边宽度。
const BORDER_WIDTH_HOT: float = 5.0


## 画整张卡面。fill / border / text 由调用方决定（选中与吸附是**状态**，不是牌面的一部分）。
static func paint(target: CanvasItem, card: CardData, origin: Vector2, fill: Color, border: Color,
		border_width: float, text: Color) -> void:
	var rect: Rect2 = Rect2(origin, SIZE)
	target.draw_rect(rect, fill, true)
	target.draw_rect(rect, border, false, border_width)
	# 类型色只出现在描边与图形标记两处小面积上（13 §10.1），不做整卡铺色。
	GlyphPainter.paint(target, card.glyph, origin + Vector2(SIZE.x * 0.5, GLYPH_CENTER_Y),
		GLYPH_RADIUS, CardCatalog.accent_color(card))
	paint_mark(target, card, origin, text)


## 只画短标记。仓库卡位与画布卡共用同一段排版，避免两处字号/基线各写一份。
static func paint_mark(target: CanvasItem, card: CardData, origin: Vector2, text: Color) -> void:
	var font: Font = target.get_theme_default_font()
	var font_size: int = target.get_theme_default_font_size()
	if font == null or text.a <= 0.0:
		return
	target.draw_string(font, Vector2(origin.x, origin.y + MARK_BASELINE_Y),
		TranslationServer.translate(CardCatalog.mark_key(card)),
		HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, font_size, text)
