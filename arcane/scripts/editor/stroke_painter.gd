## stroke_painter.gd
## 职责：全工程唯一的一支笔 —— 卡面符号 / 顶栏图标 / 状态角标 / 辅助线端点都只能经这里落笔。
## 所属系统：editor（绘制辅助）
## 依赖：无（只吃坐标与颜色；颜色由调用方从 Palette 取好传进来）
## 禁止：本文件不得出现裸色值；不得引用 Palette / 模型 / 节点状态 —— 它只画线。
##
## 为什么值得单独一支：PET-87 §1 要求「统一笔画（线宽、圆角、端点一致）」。若每个图形各写各的
## draw_polyline，线宽会漂、圆角会丢，下一个加图形的人又得重新决定一次端点长什么样。
## 收成一处之后，「一致」不是靠自觉，而是**结构上只有一种可能**（test_glyphs 扫源码钉住这一点）。

class_name StrokePainter
extends RefCounted

## 唯一线宽（960×540 画布上的逻辑像素）。
const WIDTH: float = 3.0

## 虚线节拍：实线段长度与间隔。用来把「辅助线」与「丝线」在**线型**上分开（13 §10.1）。
const DASH_LENGTH: float = 9.0
const DASH_GAP: float = 6.0


## 沿折线落笔。**圆角 + 圆端点**：每段画线，并在每个顶点补一个直径等于线宽的圆点。
##
## Godot 的 draw_line / draw_polyline 只有平头端点，转角处还会因厚度留下缺口；
## 补圆点是唯一能同时拿到「圆角」与「圆端点」的办法。18 个符号、4 个图标、
## 选中轮廓与辅助线端点全部走这一条路径，因此它们的笔触天然一致。
static func stroke_path(target: CanvasItem, points: PackedVector2Array, color: Color,
		width: float = WIDTH, closed: bool = false) -> void:
	if points.size() < 2:
		return
	var path: PackedVector2Array = closed_path(points) if closed else points
	for index: int in path.size() - 1:
		target.draw_line(path[index], path[index + 1], color, width, true)
	# 闭合路径的顶点就是原顶点表（末点与首点重合，只补一次）；开放路径两端也要补，才是圆端点。
	var radius: float = width * 0.5
	for point: Vector2 in (points if closed else path):
		target.draw_circle(point, radius, color)


## 首尾相接的顶点表（末点已与首点重合时不重复追加）。
static func closed_path(points: PackedVector2Array) -> PackedVector2Array:
	if points.size() < 2:
		return points
	var path: PackedVector2Array = points.duplicate()
	if not path[0].is_equal_approx(path[path.size() - 1]):
		path.append(path[0])
	return path


## 把一个矩形拆成一条闭合路径 —— 选中轮廓与焦点角标用同一条笔，转角因此是圆的。
static func rect_path(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


## 折线的虚线分段。返回若干条**独立**的短折线，各自交给 stroke_path 落笔。
static func dashed(points: PackedVector2Array, dash: float = DASH_LENGTH,
		gap: float = DASH_GAP) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if points.size() < 2 or dash <= 0.0 or gap <= 0.0:
		return segments
	var period: float = dash + gap
	var travelled: float = 0.0
	var current: PackedVector2Array = PackedVector2Array()
	for index: int in points.size() - 1:
		var from: Vector2 = points[index]
		var to: Vector2 = points[index + 1]
		var span: float = from.distance_to(to)
		if span <= 0.0:
			continue
		var direction: Vector2 = (to - from) / span
		var walked: float = 0.0
		while walked < span:
			var phase: float = fmod(travelled + walked, period)
			var step: float = (dash - phase) if phase < dash else (period - phase)
			step = minf(step, span - walked)
			var head: Vector2 = from + direction * walked
			if phase < dash:
				if not current.is_empty() and not current[current.size() - 1].is_equal_approx(head):
					segments.append(current)
					current = PackedVector2Array()
				if current.is_empty():
					current.append(head)
				current.append(head + direction * step)
			elif not current.is_empty():
				segments.append(current)
				current = PackedVector2Array()
			walked += step
		travelled += span
	if not current.is_empty():
		segments.append(current)
	return segments
