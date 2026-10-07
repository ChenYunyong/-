## card_face.gd
## 职责：一张卡面的画法（底板 + 中性卡缘 + 类型徽记 + 符号 + 短标记）。
## 所属系统：editor（绘制辅助）
## 依赖：CardData, GlyphPainter, CardCatalog, Palette
## 禁止：本文件不得出现裸色值、不得自己决定类型色 —— 类型色只在 CardCatalog.accent_token() 里定义。
##
## 画布上的卡与仓库里的卡位**必须长得一模一样**（用户在仓库里认出的牌，落到画布上还得是同一张），
## 因此两边共用这一个画法，而不是各画各的。
##
## PET-87 §1：卡面不再绕一圈类型彩边。三处改动，各自对应一条可量测的理由：
##   1. **符号**是主识别手段（18 张卡 18 个符号，见 GlyphPainter）—— 风与加速不再读成同一个尖角。
##   2. 符号用**墨色 BLUE_100**（对 NAVY_800 = 11.75:1），不涂类型色：土 BROWN_400 只有 1.79:1、
##      毒 ORANGE_600 只有 2.96:1，涂上去这两系的符号直接读不出来。**可读性优先于配色对称**。
##   3. 类型色收进左上角 12×12 的一小块**徽记**（06 §4「类型标识 4×4 色块（左上）」×3），
##      小面积、统一位置、可预期；「颜色即类型」降级为辅助线索，与 docs/13 §10.1 一致。

class_name CardFace
extends RefCounted

## 画布卡与仓库卡位共用的尺寸。**取自 BoardModel** —— 卡的占地大小是模型事实，
## 绘制只能照它画，另写一个数就迟早会和重叠判定 / 吸附参照对不上。
const SIZE: Vector2 = BoardModel.CARD_SIZE
## 符号的中心与半径。徽记占掉左上 6..18 的方块，符号横向从 36−14=22 起，两者留 4px 缝。
const GLYPH_CENTER: Vector2 = Vector2(36.0, 30.0)
const GLYPH_RADIUS: float = 14.0
## 短标记的基线纵向偏移。
const MARK_BASELINE_Y: float = 64.0

## 卡缘（中性）。**不是类型色**：底色与画布的对比只有 1.16:1，卡缘是卡片唯一的轮廓来源，
## 必须真的看得见。BROWN_200 对 NAVY_800 = 3.68:1，属木质外框同色系，读作「卡自己的边」。
const EDGE_TOKEN: Palette.Key = Palette.Key.BROWN_200
const BORDER_WIDTH: float = 3.0
## 高亮（选中轮廓）时的描边宽度 —— 由 BoardStatePainter 画在卡外，不在本文件。
const BORDER_WIDTH_HOT: float = 5.0

## 类型徽记：位置与边长（06 §4 的 4×4 色块（左上）×3 = 12×12）。
const BADGE_SIZE: float = 12.0
const BADGE_ORIGIN: Vector2 = Vector2(6.0, 6.0)


## 画整张卡面。fill / ink 由调用方决定（选中是**状态**，不是牌面的一部分）；
## 卡缘与徽记取自 Token / CardCatalog，不由调用方传 —— 它们是牌面的一部分。
static func paint(target: CanvasItem, card: CardData, origin: Vector2, fill: Color, ink: Color) -> void:
	var rect: Rect2 = Rect2(origin, SIZE)
	target.draw_rect(rect, fill, true)
	target.draw_rect(rect, Palette.get_color(EDGE_TOKEN), false, BORDER_WIDTH)
	_paint_badge(target, card, origin)
	GlyphPainter.paint(target, card.glyph, origin + GLYPH_CENTER, GLYPH_RADIUS, ink)
	paint_mark(target, card, origin, ink)


## 类型徽记。类型色在整张卡上**只出现在这一小块**（13 §10.1：小面积辅助识别）。
static func _paint_badge(target: CanvasItem, card: CardData, origin: Vector2) -> void:
	target.draw_rect(Rect2(origin + BADGE_ORIGIN, Vector2(BADGE_SIZE, BADGE_SIZE)),
		CardCatalog.accent_color(card), true)


## 只画短标记。仓库卡位与画布卡共用同一段排版，避免两处字号/基线各写一份。
static func paint_mark(target: CanvasItem, card: CardData, origin: Vector2, ink: Color) -> void:
	var font: Font = target.get_theme_default_font()
	var font_size: int = target.get_theme_default_font_size()
	if font == null or ink.a <= 0.0:
		return
	target.draw_string(font, Vector2(origin.x, origin.y + MARK_BASELINE_Y),
		TranslationServer.translate(CardCatalog.mark_key(card)),
		HORIZONTAL_ALIGNMENT_CENTER, SIZE.x, font_size, ink)
