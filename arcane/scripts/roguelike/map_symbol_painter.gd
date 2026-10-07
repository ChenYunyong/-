## map_symbol_painter.gd
## 职责：路线图两种节点类型（战斗 / 工坊）的符号几何与画法。
## 所属系统：roguelike（绘制辅助）
## 依赖：MapModel（Kind）、StrokePainter（唯一的笔）
## 禁止：本文件不得出现裸色值、不得引用 Palette / 节点 —— 颜色与坐标全由调用方传进来。
##
## 沿用 PET-87 在 glyph_painter / icon_painter 立下的那套：paths() 只吐几何，
## paint() 只把几何交给 StrokePainter。于是「线宽 / 圆角 / 端点」依然只有一处定义，
## 这里没有第二支笔 —— test_map_paint 会扫源码钉住这一点。
##
## 形状为什么是这两个：半径 11 的圆里只有 22px 可画，笔画一多就糊成一团。
## 交叉双剑（两条对角线 + 两道护手）与铁锤（方头 + 柄）在缩略尺寸下形状拓扑不同 ——
## 一个全是斜线、一个全是正交线，加上旁边那行短名（战 / 工），两条路都不会读混。

class_name MapSymbolPainter
extends RefCounted

## 符号线宽。比笔的默认 3 细一档：22px 的圆里再压 3px 的笔画，缝隙就没了。
const SYMBOL_WIDTH: float = 2.0

## 几何用「半径的倍数」表示，于是换半径不用重写坐标。
## **倍数的模长一律 ≤1**：这些是半径的比例，不是各自轴上的比例 —— 写成 (±0.98, ±0.42)
## 这种「轴上都不到 1」的点，实际长度是 1.07，会画到圆外面去（test_map_paint 量这一点）。
static func paths(kind: MapModel.Kind, center: Vector2, radius: float) -> Array[Dictionary]:
	if kind == MapModel.Kind.BATTLE:
		return _sword(center, radius)
	return _hammer(center, radius)


static func paint(target: CanvasItem, kind: MapModel.Kind, center: Vector2, radius: float,
		color: Color) -> void:
	for path: Dictionary in paths(kind, center, radius):
		StrokePainter.stroke_path(target, path["points"], color, SYMBOL_WIDTH, bool(path["closed"]))


## 交叉双剑：两条对角线相交，各在靠下的一端补一道**垂直于剑身**的护手。
## 护手的两端由「剑身方向 ±0.55 处的法线 ±0.30」算出来，长度 0.626 —— 同样在半径以内。
static func _sword(center: Vector2, radius: float) -> Array[Dictionary]:
	var blade: float = 0.66
	var shoulder: float = 0.55
	var guard: float = 0.30
	return [
		_open(center, radius, [Vector2(-blade, blade), Vector2(blade, -blade)]),
		_open(center, radius, [Vector2(-blade, -blade), Vector2(blade, blade)]),
		_open(center, radius, [Vector2(-shoulder - guard, shoulder - guard),
			Vector2(-shoulder + guard, shoulder + guard)]),
		_open(center, radius, [Vector2(-shoulder + guard, -shoulder - guard),
			Vector2(-shoulder - guard, -shoulder + guard)]),
	]


## 铁锤：一个闭合的方头 + 一根柄。全正交，与全斜线的剑在轮廓上就分得开。
static func _hammer(center: Vector2, radius: float) -> Array[Dictionary]:
	var head: float = 0.70
	return [
		_closed(center, radius, [Vector2(-head, -head), Vector2(head, -head),
			Vector2(head, -head * 0.4), Vector2(-head, -head * 0.4)]),
		_open(center, radius, [Vector2(0.0, -head * 0.4), Vector2(0.0, 0.95)]),
	]


static func _open(center: Vector2, radius: float, units: Array) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	for unit: Vector2 in units:
		points.append(center + unit * radius)
	return {"points": points, "closed": false}


static func _closed(center: Vector2, radius: float, units: Array) -> Dictionary:
	var path: Dictionary = _open(center, radius, units)
	path["closed"] = true
	return path
