## glyph_painter.gd
## 职责：程序化绘制卡面图形标记（CardData.Glyph 的 16 种）。
## 所属系统：editor（绘制辅助）
## 依赖：CardData（只读它的枚举）
## 禁止：本文件不得出现任何裸颜色字面量 —— 颜色一律由调用方从 CardCatalog / Palette 取好传进来
##       （04 §7：颜色只有一个入口）。新工程不带旧美术，因此图形必须是画出来的，不是贴图。

class_name GlyphPainter
extends RefCounted

## 描边粗细（960×540 画布上的逻辑像素）。
const STROKE_WIDTH: float = 3.0
## 圆弧类图形的采样段数。16 段在 20px 半径上已经看不出折线。
const ARC_SEGMENTS: int = 24


## 在 target 的 _draw() 里画一枚图形标记。
## center / radius 用的是 target 的局部坐标；color 由调用方决定（类型色）。
static func paint(target: CanvasItem, glyph: CardData.Glyph, center: Vector2, radius: float, color: Color) -> void:
	match glyph:
		CardData.Glyph.RING:
			_stroke(target, _arc(center, radius * 0.78, 0.0, 360.0), color, true)
		CardData.Glyph.TRIANGLE:
			_stroke(target, _regular_polygon(center, radius * 0.85, 3, -90.0), color, true)
		CardData.Glyph.SQUARE:
			_stroke(target, _regular_polygon(center, radius * 0.78, 4, 45.0), color, true)
		CardData.Glyph.DIAMOND:
			_stroke(target, _regular_polygon(center, radius * 0.95, 4, -90.0), color, true)
		CardData.Glyph.STAR:
			_stroke(target, _star(center, radius * 0.95, radius * 0.42, 5), color, true)
		CardData.Glyph.CROSS:
			_line(target, center + Vector2(-radius * 0.7, -radius * 0.7), center + Vector2(radius * 0.7, radius * 0.7), color)
			_line(target, center + Vector2(radius * 0.7, -radius * 0.7), center + Vector2(-radius * 0.7, radius * 0.7), color)
		CardData.Glyph.CHEVRON_UP:
			_stroke(target, _chevron(center, radius, -1.0), color, false)
		CardData.Glyph.CHEVRON_DOWN:
			_stroke(target, _chevron(center, radius, 1.0), color, false)
		CardData.Glyph.DROP:
			_stroke(target, _drop(center, radius), color, true)
		CardData.Glyph.BUBBLE:
			_stroke(target, _arc(center + Vector2(0.0, radius * 0.15), radius * 0.7, 0.0, 360.0), color, true)
			_stroke(target, _arc(center + Vector2(-radius * 0.75, -radius * 0.72), radius * 0.3, 0.0, 360.0), color, true)
			_stroke(target, _arc(center + Vector2(radius * 0.55, -radius * 0.88), radius * 0.18, 0.0, 360.0), color, true)
		CardData.Glyph.SHARD:
			_stroke(target, _regular_polygon(center, radius * 0.95, 3, 90.0), color, true)
			_line(target, center + Vector2(0.0, -radius * 0.5), center + Vector2(0.0, radius * 0.6), color)
		CardData.Glyph.GEAR:
			_stroke(target, _arc(center, radius * 0.45, 0.0, 360.0), color, true)
			_stroke(target, _gear_teeth(center, radius * 0.8, radius * 0.95, 6), color, true)
		CardData.Glyph.PELLETS:
			for offset: Vector2 in [Vector2(-0.6, -0.5), Vector2(0.2, -0.75), Vector2(0.7, -0.1), Vector2(-0.15, 0.3), Vector2(0.45, 0.75)]:
				target.draw_circle(center + offset * radius, radius * 0.16, color)
		CardData.Glyph.BURST:
			for index: int in 3:
				var offset_x: float = (float(index) - 1.0) * radius * 0.62
				_stroke(target, _regular_polygon(center + Vector2(offset_x, 0.0), radius * 0.34, 4, -90.0), color, true)
		CardData.Glyph.LOOP:
			_stroke(target, _arc(center + Vector2(0.0, -radius * 0.35), radius * 0.6, 200.0, 340.0), color, false)
			_stroke(target, _arc(center + Vector2(0.0, radius * 0.35), radius * 0.6, 20.0, 160.0), color, false)
		CardData.Glyph.CLOCK:
			_stroke(target, _arc(center, radius * 0.85, 0.0, 360.0), color, true)
			_line(target, center, center + Vector2(0.0, -radius * 0.55), color)
			_line(target, center, center + Vector2(radius * 0.45, 0.0), color)


## 画一条折线。closed = true 时首尾相接（用于多边形轮廓）。
static func _stroke(target: CanvasItem, points: PackedVector2Array, color: Color, closed: bool) -> void:
	if points.size() < 2:
		return
	var path: PackedVector2Array = points
	if closed:
		path = points.duplicate()
		path.append(points[0])
	target.draw_polyline(path, color, STROKE_WIDTH, true)


static func _line(target: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	target.draw_line(from, to, color, STROKE_WIDTH, true)


## 圆弧采样成折线。角度用度，0° 指向 +X，顺时针为正（Godot 的 Y 轴向下）。
static func _arc(center: Vector2, radius: float, from_deg: float, to_deg: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = maxi(2, int(round(ARC_SEGMENTS * absf(to_deg - from_deg) / 360.0)))
	for index: int in segments + 1:
		var angle: float = deg_to_rad(lerpf(from_deg, to_deg, float(index) / float(segments)))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 正多边形顶点。sides 边形，rotation_deg 决定第一个顶点的朝向。
static func _regular_polygon(center: Vector2, radius: float, sides: int, rotation_deg: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in sides:
		var angle: float = deg_to_rad(rotation_deg + 360.0 * float(index) / float(sides))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 五角星：外顶点与内顶点交替。
static func _star(center: Vector2, outer: float, inner: float, points_count: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in points_count * 2:
		var radius: float = outer if index % 2 == 0 else inner
		var angle: float = deg_to_rad(-90.0 + 180.0 * float(index) / float(points_count))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 上下箭头（V 形）。direction = -1 指上，+1 指下。
static func _chevron(center: Vector2, radius: float, direction: float) -> PackedVector2Array:
	var tip: Vector2 = center + Vector2(0.0, direction * radius * 0.7)
	return PackedVector2Array([
		center + Vector2(-radius * 0.75, direction * -radius * 0.35),
		tip,
		center + Vector2(radius * 0.75, direction * -radius * 0.35),
	])


## 水滴：上尖下圆。
static func _drop(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	points.append(center + Vector2(0.0, -radius))
	var bulb: Vector2 = center + Vector2(0.0, radius * 0.3)
	var bulb_radius: float = radius * 0.7
	for point: Vector2 in _arc(bulb, bulb_radius, -60.0, 240.0):
		points.append(point)
	return points


## 齿轮轮廓：外齿与内圆交替成锯齿环。
static func _gear_teeth(center: Vector2, inner: float, outer: float, teeth: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = teeth * 2
	for index: int in steps:
		var radius: float = outer if index % 2 == 0 else inner
		var angle: float = deg_to_rad(360.0 * float(index) / float(steps))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
