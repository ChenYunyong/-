## board_state_painter.gd
## 职责：画布上**状态层**的画法 —— 选中轮廓（金）/ 焦点角标（浅蓝）/ 吸附辅助线（短虚线 + 端点杠）。
## 所属系统：editor（绘制辅助）
## 依赖：StrokePainter（唯一的笔）
## 禁止：本文件不得出现裸色值、不得引用 Palette / 模型 / 节点 —— 颜色与坐标全由调用方传进来。
##
## 为什么单独一支：docs/13 §10.1 要求 Focus 与 Selected 在**语义与配色**上都分得开。
## 两者若各写各的画法，下一个人改其中一处就会让它们重新长回同一个样子 ——
## 收进一个文件之后，「两者不同源」这件事在代码里是看得见的。
##
## PET-87 §2 的三条口径：
##   1. **Focus = 浅蓝细角标**（不是整圈）。整圈会立刻变成第二个「选中」。
##   2. **Selected = 金色明确轮廓**，画在卡外一圈，不和卡自身的卡缘抢位置。
##   3. **不堆辉光** —— 本文件只有线和端点，没有任何发光/模糊/多层叠色。
##
## PET-93 §3 补上的两条：选中金圈与吸附辅助线在**亮纸**上都必须带 NAVY_600 暗底线。
## 金 GOLD_500/纸 GOLD_200 = 1.218:1、浅蓝 BLUE_400/纸 = 1.371:1 —— 单画都等于没画。
## 两条底线都由调用方把颜色传进来（本文件不认识 Palette），仍是同一条笔、同一种圆角端点。

class_name BoardStatePainter
extends RefCounted

## 选中轮廓：外扩量与线宽。外扩 5 + 半线宽 3 = 卡外 8px 就是最远处，
## 小于 BoardView.EDGE_PADDING（16），因此贴边摆放时选中轮廓也不会被画布裁掉。
##
## **底线（SELECT_UNDER_WIDTH）不是装饰**：亮纸上单画金圈实测 1.218:1（§3.2），等于没画。
## 契约因此要求「亮纸处另垫 NAVY_600 暗线」—— 金圈压在一圈更宽的暗线上，边界才立得住。
const SELECT_GROW: float = 5.0
const SELECT_WIDTH: float = 4.0
const SELECT_UNDER_WIDTH: float = 6.0
## 焦点角标：贴着卡缘内侧画，臂长与线宽。内缩 1 是为了不压住卡缘本身。
const FOCUS_ARM: float = 12.0
const FOCUS_WIDTH: float = 2.0
const FOCUS_INSET: float = 1.0
## 亮纸 / 金底上那圈 NAVY_600 暗底的线宽。比芯线宽 1px 两侧 —— 与 SELECT_UNDER_WIDTH 同一条手法。
const FOCUS_UNDER_WIDTH: float = 4.0
## 辅助线：底线 4 + 芯线 2（§3「吸附参考线 NAVY_600 底 / BLUE_300 芯」）。
## 端点杠总长 8，故半长 4。虚线节拍在 StrokePainter 里（8/4）。
##
## 芯线 BLUE_300 与焦点角标同色 —— 这是契约指定的映射，不是撞色：两者靠**线型**（虚/实）、
## **端点**（短杠/角标）与**范围**分开，§1.1 末段明写了这三条区分手段。
const GUIDE_WIDTH: float = 2.0
const GUIDE_UNDER_WIDTH: float = 4.0
const GUIDE_TICK: float = 4.0


## 选中：金色整圈轮廓 + 其下的暗底线（13 §10.1「Selected 保留金色主强调」）。
## 底线比金圈宽，两侧各漏出 1px，金圈于是**永远有一条深色的边衬着**，在亮纸上也读得出。
static func paint_selected(target: CanvasItem, rect: Rect2, color: Color, under: Color) -> void:
	var path: PackedVector2Array = StrokePainter.rect_path(rect.grow(SELECT_GROW))
	StrokePainter.stroke_path(target, path, under, SELECT_UNDER_WIDTH, true)
	StrokePainter.stroke_path(target, path, color, SELECT_WIDTH, true)


## 焦点：四角浅蓝细角标（13 §10.1「Focus 用浅蓝 / 亮色细框或角标」）。
## 画四个 L 形而**不画整圈** —— 整圈与选中轮廓在缩略图尺度上分不出来。
static func paint_focus(target: CanvasItem, rect: Rect2, color: Color) -> void:
	_paint_corners(target, rect, color, FOCUS_WIDTH)


## 焦点 + 其下的 NAVY_600 暗底。**亮纸 / 金底上的控件走这一支**（§3「亮纸上的控件加
## NAVY_600 暗底」）：BLUE_300 直接压在 GOLD_500 上只有 **1.057:1**（§3.2 的算法，
## PET-95 实测值），等于没画；垫一圈更宽的暗线之后 BLUE_300 / NAVY_600 = 6.948，
## 角标才对得起「焦点看得见」这条。与 Selected 的「金圈 + 暗线」是同一手法。
static func paint_focus_backed(target: CanvasItem, rect: Rect2, color: Color, under: Color) -> void:
	_paint_corners(target, rect, under, FOCUS_UNDER_WIDTH)
	_paint_corners(target, rect, color, FOCUS_WIDTH)


## 四角 L 的**唯一**画法。两支入口只差一个线宽与画几遍，L 的形状因此不会分家。
static func _paint_corners(target: CanvasItem, rect: Rect2, color: Color, width: float) -> void:
	var frame: Rect2 = rect.grow(-FOCUS_INSET)
	for corner: int in 4:
		var x: float = frame.position.x if corner % 2 == 0 else frame.end.x
		var y: float = frame.position.y if corner < 2 else frame.end.y
		var dx: float = FOCUS_ARM if corner % 2 == 0 else -FOCUS_ARM
		var dy: float = FOCUS_ARM if corner < 2 else -FOCUS_ARM
		StrokePainter.stroke_path(target, PackedVector2Array([
			Vector2(x + dx, y), Vector2(x, y), Vector2(x, y + dy),
		]), color, width, false)


## 吸附辅助线：**只在相关两个对象之间**画一小段虚线，两端各加一个端点杠。
##
## 与丝线的三处区别（13 §10.1「即使同色也要靠线型、范围、端点分开」）：
##   线型 = 虚线（丝线是实线）；范围 = 只跨相关两卡（丝线跨任意距离）；
##   端点 = 垂直于线的短杠（丝线是箭头）。
static func paint_guide(target: CanvasItem, from: Vector2, to: Vector2, color: Color,
		under: Color) -> void:
	var dashes: Array[PackedVector2Array] = StrokePainter.dashed(PackedVector2Array([from, to]))
	# **整条底线走完再走芯线**，不是逐段两遍：逐段的话后一段的底线会压在前一段的芯线上，
	# 每个虚线接缝处都露出一粒深色的疙瘩。
	_guide_pass(target, from, to, dashes, under, GUIDE_UNDER_WIDTH)
	_guide_pass(target, from, to, dashes, color, GUIDE_WIDTH)


## 辅助线的一遍（底色或芯色）：全部虚线段 + 两端的端点杠。
static func _guide_pass(target: CanvasItem, from: Vector2, to: Vector2,
		dashes: Array[PackedVector2Array], color: Color, width: float) -> void:
	for dash: PackedVector2Array in dashes:
		StrokePainter.stroke_path(target, dash, color, width, false)
	paint_tick(target, from, to, color, width)
	paint_tick(target, to, from, color, width)


## 端点杠：过端点、垂直于辅助线的一小段（契约总长 8 = 半长 4）。
static func paint_tick(target: CanvasItem, at: Vector2, towards: Vector2, color: Color,
		width: float = GUIDE_WIDTH) -> void:
	var heading: Vector2 = at - towards
	if heading.is_zero_approx():
		return
	var normal: Vector2 = Vector2(-heading.y, heading.x).normalized() * GUIDE_TICK
	StrokePainter.stroke_path(target, PackedVector2Array([at - normal, at + normal]), color, width,
		false)


## 把一次吸附回报的全部辅助线画出来。spans 与 guides **同序等长**（由 Snap 保证）。
##
## 放在这里而不是 BoardView：辅助线的画法与它「必须是短的」这条口径是同一件事，
## 分两个文件放迟早会有人只改一边。
static func paint_guides(target: CanvasItem, guides_v: Array[float], spans_v: Array[Vector2],
		guides_h: Array[float], spans_h: Array[Vector2], color: Color, under: Color) -> void:
	for index: int in guides_v.size():
		var span: Vector2 = spans_v[index] if index < spans_v.size() else Vector2.ZERO
		paint_guide(target, Vector2(guides_v[index], span.x), Vector2(guides_v[index], span.y),
			color, under)
	for index: int in guides_h.size():
		var span: Vector2 = spans_h[index] if index < spans_h.size() else Vector2.ZERO
		paint_guide(target, Vector2(span.x, guides_h[index]), Vector2(span.y, guides_h[index]),
			color, under)
