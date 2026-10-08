## icon_painter.gd
## 职责：程序化绘制界面图标（顶栏的撤销 / 删除 / 路线图）—— 只出几何，落笔交给 StrokePainter。
## 所属系统：editor（绘制辅助）
## 依赖：StrokePainter（唯一的笔）
## 禁止：本文件不得出现任何裸颜色字面量 —— 颜色一律由调用方从 Palette 取好传进来。
##       不得自己 draw_line —— 笔触必须与卡面符号同一个定义（PET-87 §1「统一笔画」）。
##
## PET-87 §3：顶栏的撤销 / 删除 / 路线图要从「和开始战斗一样大的文字按钮」降为**紧凑图标控件**。
## 这三个图标不带任何美术资源，是画出来的；与卡面符号共用一支笔，因此圆角端点天然一致。

class_name IconPainter
extends RefCounted

## 可用图标。NONE 是「这个键不画图标」的占位（主动作按钮仍然是文字按钮）。
## ARROW_LEFT / ARROW_RIGHT 是仓库两端的滚动入口（PET-87 §3）—— 与顶栏图标同一支笔。
## CLOSE 是详情浮层的收起键（PET-93 §2.1 DETAIL_CLOSE）—— 契约给了 24×24 的 rect，没指定图形。
enum Icon { NONE, MAP, DELETE, UNDO, ARROW_LEFT, ARROW_RIGHT, CLOSE }


static func paint(target: CanvasItem, icon: Icon, center: Vector2, radius: float, color: Color) -> void:
	for path: Dictionary in paths(icon, center, radius):
		StrokePainter.stroke_path(target, path["points"], color, StrokePainter.WIDTH,
			bool(path["closed"]))


## 一枚图标的几何。与 GlyphPainter.paths() 同形，方便两处共用同一种画法思路。
static func paths(icon: Icon, center: Vector2, radius: float) -> Array[Dictionary]:
	match icon:
		Icon.UNDO:
			return _undo(center, radius)
		Icon.DELETE:
			return _delete(center, radius)
		Icon.MAP:
			return _map(center, radius)
		Icon.ARROW_LEFT, Icon.ARROW_RIGHT:
			return _arrow(icon, center, radius)
		Icon.CLOSE:
			return _close(center, radius)
	return []


## 逆时针回卷的弧 + 左端箭头 —— 「撤销」的通用画法。
static func _undo(center: Vector2, radius: float) -> Array[Dictionary]:
	var sweep: PackedVector2Array = _arc(center, radius * 0.7, 195.0, 345.0)
	var tip: Vector2 = sweep[0]
	var heading: Vector2 = (tip - sweep[1]).normalized()
	var arm: Vector2 = Vector2(-heading.y, heading.x) * radius * 0.34
	var head: PackedVector2Array = PackedVector2Array([
		tip - arm + heading * radius * 0.38, tip, tip + arm + heading * radius * 0.38])
	return [_open(sweep), _open(head)]


## 垃圾桶：桶盖 + 提手 + 上宽下窄的桶身（三面开口，底由桶身折线自带）。
static func _delete(center: Vector2, radius: float) -> Array[Dictionary]:
	return [
		_open(PackedVector2Array([
			center + Vector2(-radius * 0.82, -radius * 0.5),
			center + Vector2(radius * 0.82, -radius * 0.5)])),
		_open(PackedVector2Array([
			center + Vector2(-radius * 0.28, -radius * 0.5),
			center + Vector2(-radius * 0.28, -radius * 0.76),
			center + Vector2(radius * 0.28, -radius * 0.76),
			center + Vector2(radius * 0.28, -radius * 0.5)])),
		_open(PackedVector2Array([
			center + Vector2(-radius * 0.6, -radius * 0.5),
			center + Vector2(-radius * 0.44, radius * 0.78),
			center + Vector2(radius * 0.44, radius * 0.78),
			center + Vector2(radius * 0.6, -radius * 0.5)])),
	]


## 路线图：三个节点 + 两段路。比「折叠地图」好认，也和丝线的箭头形状不撞。
static func _map(center: Vector2, radius: float) -> Array[Dictionary]:
	var nodes: Array[Vector2] = [
		center + Vector2(-radius * 0.62, radius * 0.5),
		center + Vector2(0.0, -radius * 0.58),
		center + Vector2(radius * 0.62, radius * 0.34),
	]
	var paths_out: Array[Dictionary] = []
	for node: Vector2 in nodes:
		paths_out.append(_closed(_circle(node, radius * 0.2)))
	paths_out.append(_open(PackedVector2Array([nodes[0], nodes[1]])))
	paths_out.append(_open(PackedVector2Array([nodes[1], nodes[2]])))
	return paths_out


## 单尖角箭头，画满整个 radius —— 它是滚动入口，要在仓库的木框上看得见。
## 与卡面符号的**双层** chevron（CHEVRONS_UP/DOWN）刻意不同形状，避免读混。
static func _arrow(icon: Icon, center: Vector2, radius: float) -> Array[Dictionary]:
	var sign_x: float = -1.0 if icon == Icon.ARROW_LEFT else 1.0
	var base: float = -radius * 0.55 * sign_x
	return [_open(PackedVector2Array([
		center + Vector2(base, -radius * 0.72),
		center + Vector2(radius * 0.55 * sign_x, 0.0),
		center + Vector2(base, radius * 0.72),
	]))]


## 收起浮层的叉。两笔对角的**开放**折线，不闭合 —— 闭合会在交点附近多出一段回程。
static func _close(center: Vector2, radius: float) -> Array[Dictionary]:
	var arm: float = radius * 0.62
	return [
		_open(PackedVector2Array([
			center + Vector2(-arm, -arm), center + Vector2(arm, arm)])),
		_open(PackedVector2Array([
			center + Vector2(arm, -arm), center + Vector2(-arm, arm)])),
	]


# ---------------------------------------------------------------- 几何工具

static func _arc(center: Vector2, radius: float, from_deg: float, to_deg: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = maxi(2, int(round(20.0 * absf(to_deg - from_deg) / 360.0)))
	for index: int in segments + 1:
		var angle: float = deg_to_rad(lerpf(from_deg, to_deg, float(index) / float(segments)))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	return _arc(center, radius, 0.0, 360.0)


static func _open(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "closed": false}


static func _closed(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "closed": true}
