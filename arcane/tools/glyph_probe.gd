## glyph_probe.gd
## 职责：一次性测量脚本 —— 把 18 个卡面符号两两比一遍，打印最小相似度，供测试定阈值。
## 所属系统：tools（不进 tests/、不被 test_source_rules 扫描）
## 运行：godot --headless --path . --script res://tools/glyph_probe.gd

extends SceneTree

const GRID: int = 24
const SAMPLES: int = 24


func _initialize() -> void:
	var names: Array[String] = []
	var sigs: Array[PackedFloat32Array] = []
	for value: int in CardData.Glyph.size():
		var glyph: CardData.Glyph = value
		names.append(CardData.Glyph.keys()[value])
		sigs.append(_signature(GlyphPainter.paths(glyph, Vector2.ZERO, 1.0)))
	var pairs: Array = []
	for i: int in sigs.size():
		for j: int in range(i + 1, sigs.size()):
			pairs.append({"name": "%s / %s" % [names[i], names[j]],
				"sim": _similarity(sigs[i], sigs[j])})
	pairs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["sim"] > b["sim"])
	print("字形数：%d" % sigs.size())
	print("自比（应为 1.0）：%f" % _similarity(sigs[0], sigs[0]))
	print("平移后自比（归一化是否生效）：%f" % _similarity(sigs[0],
		_signature(GlyphPainter.paths(CardData.Glyph.RING, Vector2(37.0, -12.0), 2.5))))
	for index: int in mini(6, pairs.size()):
		print("  第 %d 像：%s = %f" % [index + 1, pairs[index]["name"], pairs[index]["sim"]])
	# 卡面符号 vs 顶栏图标：两组不会同屏比较，但形状撞车照样会让人读混。
	for icon: int in [IconPainter.Icon.MAP, IconPainter.Icon.DELETE, IconPainter.Icon.UNDO,
			IconPainter.Icon.ARROW_LEFT]:
		var icon_sig: PackedFloat32Array = _signature(IconPainter.paths(icon, Vector2.ZERO, 1.0))
		var best: float = -1.0
		var best_name: String = ""
		for i: int in sigs.size():
			var sim: float = _similarity(sigs[i], icon_sig)
			if sim > best:
				best = sim
				best_name = names[i]
		print("图标 %s 最像的卡面符号：%s = %f" % [IconPainter.Icon.keys()[icon], best_name, best])
	quit(0)


## 把一组折线栅格化成 GRID×GRID 的占用位图，先按自身包围盒归一化。
func _signature(paths: Array[Dictionary]) -> PackedFloat32Array:
	var points: PackedVector2Array = PackedVector2Array()
	for path: Dictionary in paths:
		var poly: PackedVector2Array = path["points"]
		var closed: bool = bool(path["closed"])
		var last: int = poly.size() if closed else poly.size() - 1
		for index: int in last:
			var a: Vector2 = poly[index]
			var b: Vector2 = poly[(index + 1) % poly.size()]
			for step: int in SAMPLES + 1:
				points.append(a.lerp(b, float(step) / float(SAMPLES)))
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	var grid: PackedFloat32Array = PackedFloat32Array()
	grid.resize(GRID * GRID)
	var span: Vector2 = Vector2(maxf(box.size.x, 0.0001), maxf(box.size.y, 0.0001))
	for point: Vector2 in points:
		var u: Vector2 = (point - box.position) / span
		var cell: Vector2i = Vector2i(clampi(int(u.x * float(GRID - 1) + 0.5), 0, GRID - 1),
			clampi(int(u.y * float(GRID - 1) + 0.5), 0, GRID - 1))
		grid[cell.y * GRID + cell.x] = 1.0
	return grid


## Jaccard 相似度：交集 / 并集。1 = 完全同一张位图。
func _similarity(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var both: int = 0
	var either: int = 0
	for index: int in a.size():
		var hit: bool = a[index] > 0.0 or b[index] > 0.0
		if hit:
			either += 1
		if hit and a[index] > 0.0 and b[index] > 0.0:
			both += 1
	return float(both) / float(maxi(either, 1))
