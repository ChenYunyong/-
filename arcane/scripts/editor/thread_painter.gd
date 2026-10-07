## thread_painter.gd
## 职责：奥术丝线的绘制 —— 三次贝塞尔曲线 + 末端箭头。
## 所属系统：editor
## 依赖：无（只吃坐标与颜色）
## 禁止：本文件不得引用 Palette / 模型 / Snap —— 颜色与端点全由调用方传入。
##
## 与 GlyphPainter / CardFace 同一套路：几何与绘制独立成无状态静态函数，
## 这样 BoardView 只管状态与手势，线条的形状可以单独验证。

class_name ThreadPainter
extends RefCounted

## 贝塞尔采样段数。段数越多线越顺，代价是顶点数。
const SEGMENTS: int = 20
## 丝线粗细（逻辑像素）。
const WIDTH: float = 2.0
## 末端箭头的大小。
const ARROW_SIZE: float = 9.0
## 控制点的最短探出距离 —— 两卡贴得极近时线也要有个弯，不能塌成直线。
const MIN_REACH: float = 24.0


## 画一条从 from 到 to 的丝线。
static func paint(target: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	var path: PackedVector2Array = curve_points(from, to)
	if path.size() < 2:
		return
	target.draw_polyline(path, color, WIDTH, true)
	var approach: Vector2 = path[path.size() - 2]
	var heading: Vector2 = (to - approach).normalized()
	if heading == Vector2.ZERO:
		return
	var normal: Vector2 = Vector2(-heading.y, heading.x) * (ARROW_SIZE * 0.5)
	target.draw_colored_polygon(PackedVector2Array([
		to,
		to - heading * ARROW_SIZE + normal,
		to - heading * ARROW_SIZE - normal,
	]), color)


## 贝塞尔采样点。控制点向两侧水平探出，丝线才像一根被拉弯的线，而不是斜插的直棍。
static func curve_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var reach: float = maxf(MIN_REACH, absf(to.x - from.x) * 0.5)
	var control_a: Vector2 = from + Vector2(reach, 0.0)
	var control_b: Vector2 = to - Vector2(reach, 0.0)
	for index: int in SEGMENTS + 1:
		var t: float = float(index) / float(SEGMENTS)
		var u: float = 1.0 - t
		points.append(
			from * (u * u * u)
			+ control_a * (3.0 * u * u * t)
			+ control_b * (3.0 * u * t * t)
			+ to * (t * t * t)
		)
	return points
