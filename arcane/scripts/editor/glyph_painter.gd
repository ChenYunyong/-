## glyph_painter.gd
## 职责：程序化绘制卡面图形标记（CardData.Glyph 的 18 种）—— 只出几何，落笔交给 StrokePainter。
## 所属系统：editor（绘制辅助）
## 依赖：CardData（只读它的枚举）、StrokePainter（唯一的笔）
## 禁止：本文件不得出现任何裸颜色字面量 —— 颜色一律由调用方从 CardCatalog / Palette 取好传进来
##       （04 §7：颜色只有一个入口）。不得自己 draw_line / draw_circle —— 笔触必须只有一处定义。
##
## PET-87 §1：18 张卡要有 18 个**互相读得开**的符号。拆成 paths() + paint() 两步是为了
## 让「两个符号是否长得一样」变成可计算的事 —— tests/unit/test_glyphs.gd 直接取几何点集
## 两两比距离，而不是靠人盯着截图看。

class_name GlyphPainter
extends RefCounted

## 圆弧类图形的采样段数（整圈）。16 段在 20px 半径上已经看不出折线。
const ARC_SEGMENTS: int = 24


## 在 target 的 _draw() 里画一枚图形标记。
## center / radius 用的是 target 的局部坐标；color 由调用方决定（卡面用墨色，见 CardFace）。
static func paint(target: CanvasItem, glyph: CardData.Glyph, center: Vector2, radius: float,
		color: Color) -> void:
	for path: Dictionary in paths(glyph, center, radius):
		StrokePainter.stroke_path(target, path["points"], color, StrokePainter.WIDTH,
			bool(path["closed"]))


## 一枚符号的几何：若干条折线，每条自带「是否闭合」。
## 抽出来是为了可测 —— 判两个符号像不像，比较的就是这里的点集。
##
## 三组只是**篇幅**上的切分（一个 match 塞 18 个分支会顶破 50 行的函数上限），
## 分组不承载语义：每张卡认哪个符号，唯一的地方是 CardCatalog 的卡表。
static func paths(glyph: CardData.Glyph, center: Vector2, radius: float) -> Array[Dictionary]:
	match glyph:
		CardData.Glyph.RING, CardData.Glyph.BLADE, CardData.Glyph.LEAF, \
		CardData.Glyph.DROP, CardData.Glyph.FLAME:
			return _core_paths(glyph, center, radius)
		CardData.Glyph.MOUNTAIN, CardData.Glyph.BOLT, CardData.Glyph.GUST, \
		CardData.Glyph.BUBBLE, CardData.Glyph.SHARD:
			return _field_paths(glyph, center, radius)
	return _rune_paths(glyph, center, radius)


## 金木水火土五系。剑 / 叶 / 水滴 / 火焰都是**实心轮廓**，靠形状本身分辨。
static func _core_paths(glyph: CardData.Glyph, center: Vector2, radius: float) -> Array[Dictionary]:
	match glyph:
		CardData.Glyph.RING:
			# 厚环（甜甜圈），不是「圆 + 里面的小圆」：内外半径差 0.45 让环带本身有肉，
			# 中间仍是通心的。它和「冷却」的秒表盘是全表最像的一对，见 CLOCK 的说明。
			return [_closed(_circle(center, radius * 0.9)), _closed(_circle(center, radius * 0.45))]
		CardData.Glyph.BLADE:
			return [_closed(PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius * 0.3, -radius * 0.28),
				center + Vector2(0.3 * radius, radius * 0.42),
				center + Vector2(0.0, radius * 0.72),
				center + Vector2(-0.3 * radius, radius * 0.42),
				center + Vector2(-0.3 * radius, -radius * 0.28),
			])), _open(PackedVector2Array([
				center + Vector2(-radius * 0.62, radius * 0.34),
				center + Vector2(radius * 0.62, radius * 0.34),
			]))]
		CardData.Glyph.LEAF:
			var leaf_angle: float = rad_to_deg(acos(0.35 / 0.9))
			var leaf: PackedVector2Array = _arc(center + Vector2(-radius * 0.35, 0.0), radius * 0.9,
				-leaf_angle, leaf_angle)
			for point: Vector2 in _arc(center + Vector2(radius * 0.35, 0.0), radius * 0.9,
					180.0 - leaf_angle, 180.0 + leaf_angle):
				leaf.append(point)
			return [_closed(leaf), _open(PackedVector2Array([
				center + Vector2(0.0, -radius * 0.78), center + Vector2(0.0, radius * 0.62)]))]
		CardData.Glyph.DROP:
			return [_closed(_drop(center, radius))]
		CardData.Glyph.FLAME:
			var flame: PackedVector2Array = _arc(center + Vector2(0.0, radius * 0.32), radius * 0.62,
				-18.0, 198.0)
			flame.append(center + Vector2(radius * 0.24, -radius))
			return [_closed(flame), _open(_arc(center + Vector2(0.02 * radius, radius * 0.42),
				radius * 0.22, -30.0, 210.0))]
	return []


## 雷风毒冰四系。山 / 闪电 / 风 / 气泡 / 冰晶 —— 这一组里有三张是「同色系」的（见 CardCatalog
## 头部记录：水雷风冰四色最近距离只有 35.8），形状必须比颜色先说话，所以刻意选了轮廓方向
## 差异最大的五种：锯齿（雷）、横纹（风）、圆（毒）、三角（冰）、折线（土）。
static func _field_paths(glyph: CardData.Glyph, center: Vector2, radius: float) -> Array[Dictionary]:
	match glyph:
		CardData.Glyph.MOUNTAIN:
			return [_open(PackedVector2Array([
				center + Vector2(-radius * 0.95, radius * 0.62),
				center + Vector2(-radius * 0.38, -radius * 0.34),
				center + Vector2(radius * 0.02, radius * 0.14),
				center + Vector2(radius * 0.42, -radius * 0.62),
				center + Vector2(radius * 0.95, radius * 0.62),
			]))]
		CardData.Glyph.BOLT:
			return [_open(PackedVector2Array([
				center + Vector2(radius * 0.3, -radius),
				center + Vector2(-radius * 0.42, radius * 0.06),
				center + Vector2(radius * 0.06, radius * 0.06),
				center + Vector2(-radius * 0.26, radius),
			]))]
		CardData.Glyph.GUST:
			var gust: Array[Dictionary] = []
			for row: Array in [[-0.52, -0.88, 0.46], [0.0, -0.78, 0.68], [0.52, -0.58, 0.3]]:
				gust.append(_open(_gust_line(center, radius, float(row[0]), float(row[1]), float(row[2]))))
			return gust
		CardData.Glyph.BUBBLE:
			return [
				_closed(_circle(center + Vector2(0.0, radius * 0.15), radius * 0.68)),
				_closed(_circle(center + Vector2(-radius * 0.78, -radius * 0.7), radius * 0.3)),
				_closed(_circle(center + Vector2(radius * 0.58, -radius * 0.86), radius * 0.18)),
			]
		CardData.Glyph.SHARD:
			return [
				_closed(_regular_polygon(center, radius * 0.95, 3, 90.0)),
				_open(PackedVector2Array([
					center + Vector2(0.0, -radius * 0.5), center + Vector2(0.0, radius * 0.6)])),
			]
	return []


## 八张功能卡。这一组最容易和别的读混（§1 报的就是「风」与「加速」共用同一个朝上尖角），
## 因此每一张都从**不同的构图层级**出发：双层尖角 / 小圆点阵 / 三连箭 / 星 /
## 双环 / 圆盘指针 / 齿环 —— 没有两张共用同一种骨架。
static func _rune_paths(glyph: CardData.Glyph, center: Vector2, radius: float) -> Array[Dictionary]:
	match glyph:
		CardData.Glyph.CHEVRONS_UP:
			return [_open(_chevron(center + Vector2(0.0, -radius * 0.18), radius * 0.82, -1.0)),
				_open(_chevron(center + Vector2(0.0, radius * 0.3), radius * 0.82, -1.0))]
		CardData.Glyph.CHEVRONS_DOWN:
			return [_open(_chevron(center + Vector2(0.0, radius * 0.18), radius * 0.82, 1.0)),
				_open(_chevron(center + Vector2(0.0, -radius * 0.3), radius * 0.82, 1.0))]
		CardData.Glyph.PELLETS:
			var pellets: Array[Dictionary] = []
			for offset: Vector2 in [Vector2(-0.6, -0.5), Vector2(0.2, -0.78), Vector2(0.72, -0.08),
					Vector2(-0.18, 0.34), Vector2(0.48, 0.76)]:
				pellets.append(_closed(_circle(center + offset * radius, radius * 0.22)))
			return pellets
		CardData.Glyph.BURST:
			var burst: Array[Dictionary] = []
			for index: int in 3:
				var tip: Vector2 = center + Vector2((float(index) - 1.0) * radius * 0.45, 0.0)
				burst.append(_open(PackedVector2Array([
					tip + Vector2(-radius * 0.3, -radius * 0.62), tip,
					tip + Vector2(-radius * 0.3, radius * 0.62)])))
			return burst
		CardData.Glyph.SPARKLE:
			return [_closed(_star(center, radius * 0.98, radius * 0.2, 4))]
		CardData.Glyph.LOOP:
			return [
				_open(_arc(center + Vector2(0.0, -radius * 0.35), radius * 0.6, 200.0, 340.0)),
				_open(_arc(center + Vector2(0.0, radius * 0.35), radius * 0.6, 20.0, 160.0)),
			]
		CardData.Glyph.CLOCK:
			# **秒表**而不是纯圆表盘：纯圆（圆 + 两根指针）与核心卡的「环」实测 Jaccard 相似度
			# 0.647，是全表最高的一对 —— 两个圆轮廓互相盖住，指针那点差别撑不起辨识。
			# 顶端加表冠之后轮廓不再是圆，那一对掉到 0.19（tools/glyph_probe.gd 实测）。
			return [
				_closed(_circle(center + Vector2(0.0, radius * 0.16), radius * 0.7)),
				_open(PackedVector2Array([
					center + Vector2(0.0, -radius * 0.54), center + Vector2(0.0, -radius * 0.88)])),
				_open(PackedVector2Array([
					center + Vector2(-radius * 0.26, -radius * 0.88),
					center + Vector2(radius * 0.26, -radius * 0.88)])),
				_open(PackedVector2Array([
					center + Vector2(0.0, radius * 0.16), center + Vector2(0.0, -radius * 0.28)])),
			]
		CardData.Glyph.GEAR:
			return [
				_closed(_circle(center, radius * 0.45)),
				_closed(_gear_teeth(center, radius * 0.8, radius * 0.95, 6)),
			]
	return []


## 路径条数（测试用来确认枚举长度与卡表一致）。
static func path_count(glyph: CardData.Glyph, center: Vector2, radius: float) -> int:
	return paths(glyph, center, radius).size()


# ---------------------------------------------------------------- 几何工具

## 圆弧采样成折线。角度用度，0° 指向 +X，顺时针为正（Godot 的 Y 轴向下）。
static func _arc(center: Vector2, radius: float, from_deg: float, to_deg: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var segments: int = maxi(2, int(round(ARC_SEGMENTS * absf(to_deg - from_deg) / 360.0)))
	for index: int in segments + 1:
		var angle: float = deg_to_rad(lerpf(from_deg, to_deg, float(index) / float(segments)))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	return _arc(center, radius, 0.0, 360.0)


## 正多边形顶点。sides 边形，rotation_deg 决定第一个顶点的朝向。
static func _regular_polygon(center: Vector2, radius: float, sides: int, rotation_deg: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in sides:
		var angle: float = deg_to_rad(rotation_deg + 360.0 * float(index) / float(sides))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 星形：外顶点与内顶点交替。4 个外顶点就是「闪光」。
static func _star(center: Vector2, outer: float, inner: float, spikes: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in spikes * 2:
		var radius: float = outer if index % 2 == 0 else inner
		var angle: float = deg_to_rad(-90.0 + 180.0 * float(index) / float(spikes))
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 上下尖角（V 形）。direction = -1 指上，+1 指下。
static func _chevron(center: Vector2, radius: float, direction: float) -> PackedVector2Array:
	return PackedVector2Array([
		center + Vector2(-radius * 0.75, direction * -radius * 0.35),
		center + Vector2(0.0, direction * radius * 0.35),
		center + Vector2(radius * 0.75, direction * -radius * 0.35),
	])


## 水滴：上尖下圆。
static func _drop(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([center + Vector2(0.0, -radius)])
	for point: Vector2 in _arc(center + Vector2(0.0, radius * 0.32), radius * 0.68, -58.0, 238.0):
		points.append(point)
	return points


## 一缕风：一段横线，末端向上卷一个小钩。三缕不同长度即为「风」。
static func _gust_line(center: Vector2, radius: float, row: float, start: float, end: float) -> PackedVector2Array:
	var hook: float = radius * 0.24
	var points: PackedVector2Array = PackedVector2Array([
		center + Vector2(start * radius, row * radius),
		center + Vector2(end * radius, row * radius),
	])
	for point: Vector2 in _arc(center + Vector2(end * radius, (row - 0.24) * radius), hook, 90.0, -80.0):
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


static func _open(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "closed": false}


static func _closed(points: PackedVector2Array) -> Dictionary:
	return {"points": points, "closed": true}
