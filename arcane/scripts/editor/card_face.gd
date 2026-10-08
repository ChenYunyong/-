## card_face.gd
## 职责：一张卡面的画法（卡身 + 金/银普通框 + 上左高光 + 类型徽记 + 主符号 + 短名）。
## 所属系统：editor（绘制辅助）
## 依赖：CardData, GlyphPainter, CardCatalog, Palette, ContractTheme
## 禁止：本文件不得出现裸色值、不得自己决定类型色 —— 类型色只在 CardCatalog.accent_token() 里定义。
##
## 画布上的卡与仓库里的卡位**必须长得一模一样**（用户在仓库里认出的牌，落到画布上还得是同一张），
## 因此两边共用这一个画法，而不是各画各的。
##
## PET-93：几何改成 docs/14 §1.1 的「共用卡片」表 —— 每个部件的位置都是契约逐格给死的：
## 卡身 72×72 / 徽记 (4,4,12,12) / 主符号 (20,12,32,32) 笔宽 2 / 短名 (4,48,64,20) 字 12。
## 上一版的 3px BROWN 卡缘、钢笔宽 3、24 号短名三处都与这张表对不上。
## 仍然成立的两条老口径：
##   1. **符号**是主识别手段（18 张卡 18 个符号，见 GlyphPainter）。
##   2. 符号用**墨色 BLUE_100**（对 NAVY_800 = 11.754:1），不涂类型色：土 BROWN_400 只有 1.787:1、
##      毒 ORANGE_600 只有 2.958:1，涂上去这两系的符号直接读不出来。**可读性优先于配色对称**。

class_name CardFace
extends RefCounted

## 画布卡与仓库卡位共用的尺寸。**取自 BoardModel** —— 卡的占地大小是模型事实，
## 绘制只能照它画，另写一个数就迟早会和重叠判定 / 吸附参照对不上。
const SIZE: Vector2 = BoardModel.CARD_SIZE
## §1 的材质几何：圆角 4、普通轮廓 1。
const CORNER_RADIUS: int = 4
const FRAME_WIDTH: int = 1
## 主符号：框 (20,12,32,32) 的中心，符号自身留 2px 边（半径 14）。
const GLYPH_CENTER: Vector2 = Vector2(36.0, 28.0)
const GLYPH_RADIUS: float = 14.0
## 类型徽记 (4,4,12,12)：GREY_300 外圈 + 内缩 1 的 10×10 着色内区。
const BADGE_RECT: Rect2 = Rect2(4.0, 4.0, 12.0, 12.0)
const BADGE_RING: float = 1.0
## 短名行框 (4,48,64,20) 字 12/行 20。行框高是契约给的，基线按**字体实测度量**落在正中，
## 于是换字体也不会把行框撑开（§1「ascent+descent ≤ 表列行高」）。
const MARK_RECT: Rect2 = Rect2(4.0, 48.0, 64.0, 20.0)
const MARK_FONT_SIZE: int = 12
## 上左材质高光宽（§3：只画上/左，不画四边整圈）。
const HILIGHT_WIDTH: float = 1.0
## 战斗屏给「当前施法卡」用的粗描边宽。**本文件自己不用它** —— card_face 画的是常态牌面，
## 状态一律由 BoardStatePainter 在外圈画。留在这里是因为 combat_view 一直在读它，
## 而契约要求一次只改一屏（战斗屏是第③屏，本次不动）。
const BORDER_WIDTH_HOT: float = 5.0


## 画整张卡面。fill / ink 由调用方决定（选中是**状态**，不是牌面的一部分）；
## 普通框、徽记与高光取自 Token / CardCatalog，不由调用方传 —— 它们是牌面的一部分。
static func paint(target: CanvasItem, card: CardData, origin: Vector2, fill: Color, ink: Color) -> void:
	target.draw_style_box(_body_box(fill, frame_token(card)), Rect2(origin, SIZE))
	_paint_hilight(target, origin)
	_paint_badge(target, card, origin)
	GlyphPainter.paint(target, card.glyph, origin + GLYPH_CENTER, GLYPH_RADIUS, ink)
	paint_mark(target, card, origin, ink)


## 普通框的颜色：核心出金、能力与功能出银（§3「核心卡普通金框 GOLD_600」/
## 「卡副墨/银框 GREY_300：所有能力/功能普通框 1px」）。
## 它是**类型的第一眼线索**，不是稀有度；与选中那圈 4px 金轮廓在粗细上就分得开。
static func frame_token(card: CardData) -> Palette.Key:
	return Palette.Key.GOLD_600 if card.is_core() else Palette.Key.GREY_300


## 卡身样式盒：圆角 + 普通框 + 右下投影。三样都只能用 StyleBoxFlat 画 ——
## draw_rect 画不出圆角，也画不出带模糊的投影。
##
## 每次重画现建一个：_draw() 只在 queue_redraw 之后跑，画布上最多 18 张卡，
## 为此养一个跨帧缓存反而要额外处理「颜色变了要让它失效」这件事。
static func _body_box(fill: Color, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Palette.get_color(border)
	box.set_border_width_all(FRAME_WIDTH)
	box.set_corner_radius_all(CORNER_RADIUS)
	box.anti_aliasing = false
	box.set_content_margin_all(0.0)
	box.shadow_color = _shadow()
	box.shadow_size = ContractTheme.CARD_SHADOW_SIZE
	box.shadow_offset = ContractTheme.CARD_SHADOW_OFFSET
	return box


## 投影色：NAVY_900 加 §1 的 0.22 alpha。§3「投影 | NAVY_900」—— 不另造暗色常量。
static func _shadow() -> Color:
	var color: Color = Palette.get_color(Palette.Key.NAVY_900)
	color.a = ContractTheme.CARD_SHADOW_ALPHA
	return color


## 上/左 1px 高光，画在框**内侧**（盖住框就等于没框）。只画两条边：
## 四边整圈会被读成「这张卡被选中了」，而它只说明光从左上来（§3 + G08）。
static func _paint_hilight(target: CanvasItem, origin: Vector2) -> void:
	var inner: Rect2 = Rect2(origin, SIZE).grow(-float(FRAME_WIDTH))
	var lit: Color = Palette.get_color(Palette.Key.GOLD_200)
	target.draw_rect(Rect2(inner.position, Vector2(inner.size.x, HILIGHT_WIDTH)), lit, true)
	target.draw_rect(Rect2(inner.position, Vector2(HILIGHT_WIDTH, inner.size.y)), lit, true)


## 类型徽记。类型色在整张卡上**只出现在这一小块**（13 §10.1：小面积辅助识别）。
## 外面那圈 GREY_300 不是装饰：土 / 毒的徽记色对卡底只有 1.787 / 2.958（§3.1），
## 没有银圈它们就与卡底糊在一起。整块 12×12 占卡面 2.778%，正是 §1.1 的上限。
static func _paint_badge(target: CanvasItem, card: CardData, origin: Vector2) -> void:
	var ring: Rect2 = Rect2(origin + BADGE_RECT.position, BADGE_RECT.size)
	target.draw_rect(ring, Palette.get_color(Palette.Key.GREY_300), true)
	target.draw_rect(ring.grow(-BADGE_RING), CardCatalog.accent_color(card), true)


## 只画短名。仓库卡位与画布卡共用同一段排版，避免两处字号/基线各写一份。
static func paint_mark(target: CanvasItem, card: CardData, origin: Vector2, ink: Color) -> void:
	var font: Font = target.get_theme_default_font()
	if font == null or ink.a <= 0.0:
		return
	target.draw_string(font, Vector2(origin.x + MARK_RECT.position.x, mark_baseline(font, origin)),
		TranslationServer.translate(CardCatalog.mark_key(card)),
		HORIZONTAL_ALIGNMENT_CENTER, MARK_RECT.size.x, MARK_FONT_SIZE, ink)


## 短名基线：把 ascent+descent 的行高在 (4,48,64,20) 里居中。
## 契约要求实际行高 ≤ 表列行高，所以基线只能从**字体度量**算，
## 不能写死一个「在某个字号下刚好合适」的数 —— 那种数换个字体就悄悄溢出。
static func mark_baseline(font: Font, origin: Vector2) -> float:
	var line: float = font.get_ascent(MARK_FONT_SIZE) + font.get_descent(MARK_FONT_SIZE)
	return origin.y + MARK_RECT.position.y + (MARK_RECT.size.y - line) * 0.5 \
		+ font.get_ascent(MARK_FONT_SIZE)
