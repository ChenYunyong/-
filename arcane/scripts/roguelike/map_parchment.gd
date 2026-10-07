## map_parchment.gd
## 职责：羊皮卷纸面的程序化绘制 —— 纸底、边缘加深、纸面颗粒、折痕与卷角，全部由 Token 现画。
## 所属系统：roguelike（绘制辅助）
## 依赖：Palette（唯一色值来源）、StrokePainter（唯一的笔）
## 禁止：本文件不得出现裸色值；不得引入任何贴图 / 字体资源 —— 美术到位前一律现画（06 §10 规则 7）。
##
## 只用 06 §1 给 arcane/ 的那几个 Token：纸色 WARM_300 / WARM_500、墨色 BROWN_500 / BROWN_700。
## 边缘加深不是贴一张暗角图，而是**由外向内叠一圈圈更浅的填充**：越靠边越旧越深。
## 这个渐变在代码里就是 edge_color(t) 一个函数，测试可以直接拿它量，不必看图。
##
## 关于「高亮与标题用 GOLD_500 / GOLD_200」：金色**做不了纸面上的文字**。
## GOLD_500 对 WARM_300 的对比度实测 1.03:1（06 §11 要求正文 ≥4.5:1、标题 ≥3:1），
## 金字的纸面等于没字。所以金色在这一屏只当**填充与描边**（节点的可选态），
## 纸面上的字一律用墨色 BROWN_700（9.23:1）—— 这也正是羊皮卷该有的样子：字是墨写的。

class_name MapParchment
extends RefCounted

## 边缘加深的层数与总宽度（逻辑像素）。22 ≈ 纸宽的 2.4%，读起来是一条柔和的暗边。
const VIGNETTE_STEPS: int = 14
const VIGNETTE_DEPTH: float = 22.0
## 最外一圈再朝墨色压多少（0 = 只到 WARM_500，1 = 全墨）。
## 0.35 是「被翻旧了」而不是「烧焦了」—— 实测最外缘与纸心相距 ~106（0-255 的 RGB 距离）。
const EDGE_INK_MAX: float = 0.35
## 纸面颗粒：每 GRAIN_STEP 像素错行点一个小点。位置由行列号算出来，**不用随机**（03 §6）。
const GRAIN_STEP: float = 26.0
const GRAIN_RADIUS: float = 1.0
const GRAIN_DEPTH: float = 0.5
## 折痕离纸缘的距离，以及右下卷角的边长。
const FOLD_INSET: float = 10.0
const CORNER_FOLD: float = 18.0
## 纸的外框线宽。
const FRAME_WIDTH: float = 3.0


## 画一整张羊皮卷。fold_y 是折痕的局部纵坐标（由调用方给，避免两处各写一个数）。
static func paint(target: CanvasItem, rect: Rect2, fold_y: float) -> void:
	_paint_paper(target, rect)
	_paint_grain(target, rect)
	_paint_crease(target, rect, fold_y)
	_paint_corner_fold(target, rect)
	StrokePainter.stroke_path(target, StrokePainter.rect_path(rect),
		Palette.get_color(Palette.Key.BROWN_700), FRAME_WIDTH, true)


## 距纸心 t（0 = 纸心，1 = 最外缘）处的纸色。
##
## 两级混色：先按 t 朝 WARM_500 走（越靠边越暖越深），再按 t³ 朝 BROWN_500 压一点点墨。
## 用立方而不是线性，是为了让暗边**收在边上**：线性的话整张纸会均匀发灰，纸心就不白了。
static func edge_color(t: float) -> Color:
	var clamped: float = clampf(t, 0.0, 1.0)
	var paper: Color = Palette.get_color(Palette.Key.WARM_300)
	var warm: Color = Palette.get_color(Palette.Key.WARM_500)
	var ink: Color = Palette.get_color(Palette.Key.BROWN_500)
	return paper.lerp(warm, clamped).lerp(ink, clamped * clamped * clamped * EDGE_INK_MAX)


## 纸底 + 边缘加深。由外向内叠：先铺最大的一圈（最深），再一圈圈铺更浅更小的，最后一层就是纸心。
static func _paint_paper(target: CanvasItem, rect: Rect2) -> void:
	for step: int in VIGNETTE_STEPS:
		var t: float = 1.0 - float(step) / float(VIGNETTE_STEPS)
		target.draw_rect(rect.grow(-(1.0 - t) * VIGNETTE_DEPTH), edge_color(t))
	target.draw_rect(rect.grow(-VIGNETTE_DEPTH), edge_color(0.0))


## 纸面颗粒。错行的稀疏小点 —— 数量级刚好够让平涂的纸看起来有纤维，又不至于变成噪点。
static func _paint_grain(target: CanvasItem, rect: Rect2) -> void:
	var color: Color = edge_color(GRAIN_DEPTH)
	var inner: Rect2 = rect.grow(-VIGNETTE_DEPTH)
	var columns: int = int(inner.size.x / GRAIN_STEP)
	for row: int in int(inner.size.y / GRAIN_STEP):
		var offset: float = GRAIN_STEP * 0.5 if row % 2 == 1 else 0.0
		for column: int in columns:
			var at: Vector2 = inner.position + Vector2(
				float(column) * GRAIN_STEP + offset, float(row) * GRAIN_STEP + GRAIN_STEP * 0.5)
			if inner.has_point(at):
				target.draw_circle(at, GRAIN_RADIUS, color)


## 折痕：横向两道细线。它同时是路线图区与图例的分界，所以位置由调用方给。
static func _paint_crease(target: CanvasItem, rect: Rect2, fold_y: float) -> void:
	var color: Color = edge_color(0.45)
	var left: float = rect.position.x + FOLD_INSET
	var right: float = rect.end.x - FOLD_INSET
	for offset: float in [-1.5, 1.5]:
		StrokePainter.stroke_path(target,
			PackedVector2Array([Vector2(left, fold_y + offset), Vector2(right, fold_y + offset)]),
			color, 1.0, false)


## 卷角：右下角折起的一小块纸。一块浅色三角 + 一道折边。
static func _paint_corner_fold(target: CanvasItem, rect: Rect2) -> void:
	var corner: Vector2 = Vector2(rect.end.x - FOLD_INSET, rect.end.y - FOLD_INSET)
	var along: Vector2 = corner - Vector2(CORNER_FOLD, 0.0)
	var up: Vector2 = corner - Vector2(0.0, CORNER_FOLD)
	target.draw_colored_polygon(PackedVector2Array([along, up, corner]), edge_color(0.85))
	StrokePainter.stroke_path(target, PackedVector2Array([along, up]), edge_color(0.5), 2.0, false)
