## map_symbol_painter.gd
## 职责：路线图节点上那 24×24 见方符号的几何与画法 —— 两种节点类型 + 四种状态标记。
## 所属系统：roguelike（绘制辅助）
## 依赖：MapModel（Kind）、StrokePainter（唯一的笔）
## 禁止：本文件不得出现裸色值、不得引用 Palette / 节点 —— 颜色与坐标全由调用方传进来。
##
## 沿用 PET-87 在 glyph_painter / icon_painter 立下的那套：paths() / mark_paths() 只吐几何，
## paint() / paint_mark() 只把几何交给 StrokePainter。于是「线宽 / 圆角 / 端点」依然只有一处定义，
## 这里没有第二支笔 —— test_map_paint 会扫源码钉住这一点。
##
## 形状为什么是这两个：§2.2 给的符号框是 24×24，笔画一多就糊成一团。
## 交叉双剑（两条对角线 + 两道护手）与铁锤（方头 + 柄）在缩略尺寸下形状拓扑不同 ——
## 一个全是斜线、一个全是正交线，加上旁边那行短名（战 / 工），两条路都不会读混。
##
## **状态标记是另一回事**（§2.2 四态那一行：不可达=锁 / 可选=类型符号 / 已走=勾 / 当前=定位三角）。
## §4 M02 要「各态同时有形状标记与填/边区别」—— 填与外圈在 MapNodePainter 那张表里，
## 形状标记在这里。两者都在同一个 24×24 框内画，于是「换个状态」同时改三样东西。

class_name MapSymbolPainter
extends RefCounted

## 一个状态用哪种形状标记。KIND 表示「画这个节点本来的类型符号」，不是一种新图形。
enum Mark { KIND, LOCK, CHECK, LOCATOR }

## 符号线宽。比笔的默认 3 细一档：24px 的框里再压 3px 的笔画，缝隙就没了。
## §2.2 的重复元素表也写死了这一档：符号 24×24、线宽 2。
const SYMBOL_WIDTH: float = 2.0

## 几何用「半径的倍数」表示，于是换半径不用重写坐标。
## **倍数的模长一律 ≤1**：这些是半径的比例，不是各自轴上的比例 —— 写成 (±0.98, ±0.42)
## 这种「轴上都不到 1」的点，实际长度是 1.07，会画到圆外面去（test_map_symbol 量这一点）。
static func paths(kind: MapModel.Kind, center: Vector2, radius: float) -> Array[Dictionary]:
	if kind == MapModel.Kind.BATTLE:
		return _sword(center, radius)
	return _hammer(center, radius)


static func paint(target: CanvasItem, kind: MapModel.Kind, center: Vector2, radius: float,
		color: Color) -> void:
	for path: Dictionary in paths(kind, center, radius):
		StrokePainter.stroke_path(target, path["points"], color, SYMBOL_WIDTH, bool(path["closed"]))


## 状态标记的几何。KIND 走 paths()（战斗 / 工坊各自的符号），其余三个是固定图形。
static func mark_paths(mark: Mark, kind: MapModel.Kind, center: Vector2, radius: float) -> Array[Dictionary]:
	match mark:
		Mark.LOCK:
			return _lock(center, radius)
		Mark.CHECK:
			return _check(center, radius)
		Mark.LOCATOR:
			return _locator(center, radius)
		_:
			return paths(kind, center, radius)


static func paint_mark(target: CanvasItem, mark: Mark, kind: MapModel.Kind, center: Vector2,
		radius: float, color: Color) -> void:
	for path: Dictionary in mark_paths(mark, kind, center, radius):
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


## 锁（不可达）：一个闭合锁体 + 一段上拱的锁梁。锁梁用折线逼近半圆 —— 这里只有折线笔。
## 全正交 + 一个上拱，与全斜线的剑、方头的锤都不一样。
static func _lock(center: Vector2, radius: float) -> Array[Dictionary]:
	return [
		_closed(center, radius, [Vector2(-0.52, 0.06), Vector2(0.52, 0.06),
			Vector2(0.52, 0.80), Vector2(-0.52, 0.80)]),
		_open(center, radius, [Vector2(-0.30, 0.06), Vector2(-0.30, -0.22),
			Vector2(-0.13, -0.36), Vector2(0.13, -0.36), Vector2(0.30, -0.22),
			Vector2(0.30, 0.06)]),
	]


## 勾（已走）：一撇一捺折成的对勾。笔画数最少的一个 —— 「走过了」不需要再说什么。
static func _check(center: Vector2, radius: float) -> Array[Dictionary]:
	return [_open(center, radius,
		[Vector2(-0.62, 0.06), Vector2(-0.18, 0.52), Vector2(0.66, -0.46)])]


## 定位三角（当前）：尖端朝下的等边三角，指住脚下那一格。当前节点专用，与其它三态都不同形。
static func _locator(center: Vector2, radius: float) -> Array[Dictionary]:
	return [_closed(center, radius,
		[Vector2(0.0, 0.72), Vector2(0.66, -0.38), Vector2(-0.66, -0.38)])]


static func _open(center: Vector2, radius: float, units: Array) -> Dictionary:
	var points: PackedVector2Array = PackedVector2Array()
	for unit: Vector2 in units:
		points.append(center + unit * radius)
	return {"points": points, "closed": false}


static func _closed(center: Vector2, radius: float, units: Array) -> Dictionary:
	var path: Dictionary = _open(center, radius, units)
	path["closed"] = true
	return path
