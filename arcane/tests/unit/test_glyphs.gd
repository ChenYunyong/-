## test_glyphs.gd
## 职责：卡面符号的验收 —— 18 张卡 18 个符号、两两**量得出来**地不像、全工程只有一支笔。
## 所属系统：tests
## 依赖：CardData, CardCatalog, GlyphPainter, IconPainter, StrokePainter
## 禁止：本文件不得写入符号几何，只断言。
##
## PET-87 §1 报的是「风与加速读成同一个尖角」—— 那是**目视**结论，改完只能再目视一次，
## 下一个人照样能在不知情的情况下把两个符号画回同一个样子。所以这里把它变成算术：
## 把每枚符号的折线栅格化成 24×24 的占用位图（先按自身包围盒归一化，于是「大小不同
## 但形状相同」也会被抓到），两两算 Jaccard 相似度，取最大值卡一条线。
## 阈值不是拍的，是 tools/glyph_probe.gd 实测出来的（见 DISTINCT_LIMIT 的注释）。

extends RefCounted

## 栅格分辨率与每段的采样数。24 格在 28px 的卡面符号上已经细过一像素。
const GRID: int = 24
const SAMPLES: int = 24
## 任意两枚符号的 Jaccard 相似度上限。**实测最像的一对是 DROP / FLAME = 0.356**
## （tools/glyph_probe.gd），留 0.09 余量。改符号几何之后这个数要么仍然成立，要么
## 说明你真的把两张卡画近了 —— 那时该改符号，不是改这个常量。
const DISTINCT_LIMIT: float = 0.45
## 卡面符号与顶栏图标之间的上限。实测最像的一对是 UNDO / RING = 0.186。
const ICON_LIMIT: float = 0.3
## 编辑器里那个「笔」目录。
const EDITOR_DIR: String = "res://scripts/editor"


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_glyphs")
	_check_enum_matches_catalog(ctx)
	_check_every_glyph_draws(ctx)
	_check_signature_metric(ctx)
	_check_symbols_are_distinct(ctx)
	_check_icons_do_not_collide_with_glyphs(ctx)
	_check_unified_pen(ctx)


## 符号枚举的个数必须**正好**等于卡数。少一个就一定有某两张卡共用一个值，
## 而共用值正是 PET-87 §1 报的那个 bug 的形状。
func _check_enum_matches_catalog(ctx: RefCounted) -> void:
	var catalog: Array[CardData] = CardCatalog.all()
	ctx.equal(CardData.Glyph.size(), catalog.size(),
		"符号枚举 %d 个 = 卡表 %d 张（多一个少一个都会让某两张卡读成同一个图形）"
			% [CardData.Glyph.size(), catalog.size()])
	var used: Dictionary = {}
	var duplicated: PackedStringArray = PackedStringArray()
	for card: CardData in catalog:
		if used.has(card.glyph):
			duplicated.append("%s 与 %s 共用 %s" % [used[card.glyph], card.id,
				CardData.Glyph.keys()[card.glyph]])
		used[card.glyph] = card.id
	ctx.equal(duplicated.size(), 0,
		"18 张卡没有两张共用一个符号" if duplicated.is_empty() else "撞车：%s" % ", ".join(duplicated))
	ctx.equal(used.size(), catalog.size(), "每个符号值都被用上了（没有画了却没人用的死图形）")


## 每一枚符号都要真的画得出来：至少一条折线、每线至少两点、坐标有限、不飞出半径太多。
func _check_every_glyph_draws(ctx: RefCounted) -> void:
	var broken: PackedStringArray = PackedStringArray()
	for value: int in CardData.Glyph.size():
		var glyph: CardData.Glyph = value
		var paths: Array[Dictionary] = GlyphPainter.paths(glyph, Vector2.ZERO, 14.0)
		if paths.is_empty():
			broken.append("%s 没有几何" % CardData.Glyph.keys()[value])
			continue
		for path: Dictionary in paths:
			for point: Vector2 in path["points"]:
				if not (is_finite(point.x) and is_finite(point.y)) or point.length() > 28.0:
					broken.append("%s 有越界点 %s" % [CardData.Glyph.keys()[value], point])
	ctx.equal(broken.size(), 0,
		"18 枚符号都在半径内画得出来" if broken.is_empty() else "坏几何：%s" % ", ".join(broken))


## 相似度指标本身必须先被证明有牙 —— 否则「两两都不像」可能只是它永远返回 0。
func _check_signature_metric(ctx: RefCounted) -> void:
	var full: Array[Dictionary] = GlyphPainter.paths(CardData.Glyph.RING, Vector2.ZERO, 1.0)
	var ring: PackedFloat32Array = _signature(full)
	ctx.near(_similarity(ring, ring), 1.0, "反向对照：自己跟自己相似度为 1")
	# 换个大小与位置 —— 按包围盒归一化之后应当仍然是 1，否则归一化根本没生效，
	# 「两枚符号大小不同」会被误判成「不像」。
	var moved: PackedFloat32Array = _signature(GlyphPainter.paths(CardData.Glyph.RING,
		Vector2(37.0, -12.0), 2.5))
	ctx.near(_similarity(ring, moved), 1.0, "反向对照：平移放大之后相似度仍是 1（归一化生效）")
	# 结构敏感度：把「环」的内圈砍掉，签名必须明显变化。这一条是整段的关键 ——
	# 少了它，「18 枚两两都不像」也可能只是因为指标对细节不敏感、什么都判成不像。
	var only_outer: Array[Dictionary] = [full[0]]
	var partial: float = _similarity(ring, _signature(only_outer))
	ctx.check(partial > DISTINCT_LIMIT,
		"反向对照：少画一笔（砍掉内圈）之后相似度 %f 已经越过阈值 %f，掉包跑不掉"
			% [partial, DISTINCT_LIMIT])


## 18 枚符号两两比一遍，取最像的一对。
func _check_symbols_are_distinct(ctx: RefCounted) -> void:
	var names: Array[String] = []
	var sigs: Array[PackedFloat32Array] = []
	for value: int in CardData.Glyph.size():
		var glyph: CardData.Glyph = value
		names.append(CardData.Glyph.keys()[value])
		sigs.append(_signature(GlyphPainter.paths(glyph, Vector2.ZERO, 1.0)))
	var worst: float = 0.0
	var worst_pair: String = ""
	for i: int in sigs.size():
		for j: int in range(i + 1, sigs.size()):
			var sim: float = _similarity(sigs[i], sigs[j])
			if sim > worst:
				worst = sim
				worst_pair = "%s / %s" % [names[i], names[j]]
	ctx.check(worst < DISTINCT_LIMIT,
		"最像的一对 %s = %f < %f" % [worst_pair, worst, DISTINCT_LIMIT])


## 顶栏图标与卡面符号不会同时并排比，但形状撞车照样读混（「风」与「加速」就是这么来的）。
func _check_icons_do_not_collide_with_glyphs(ctx: RefCounted) -> void:
	var glyph_sigs: Array[PackedFloat32Array] = []
	var names: Array[String] = []
	for value: int in CardData.Glyph.size():
		var glyph: CardData.Glyph = value
		glyph_sigs.append(_signature(GlyphPainter.paths(glyph, Vector2.ZERO, 1.0)))
		names.append(CardData.Glyph.keys()[value])
	var worst: float = 0.0
	var worst_pair: String = ""
	for value: int in [IconPainter.Icon.MAP, IconPainter.Icon.DELETE, IconPainter.Icon.UNDO,
			IconPainter.Icon.ARROW_LEFT, IconPainter.Icon.ARROW_RIGHT]:
		var icon: IconPainter.Icon = value
		var icon_sig: PackedFloat32Array = _signature(IconPainter.paths(icon, Vector2.ZERO, 1.0))
		for index: int in glyph_sigs.size():
			var sim: float = _similarity(glyph_sigs[index], icon_sig)
			if sim > worst:
				worst = sim
				worst_pair = "%s / %s" % [IconPainter.Icon.keys()[icon], names[index]]
	ctx.check(worst < ICON_LIMIT, "图标与符号最像的一对 %s = %f < %f" % [worst_pair, worst, ICON_LIMIT])


## 「统一笔画」不能只是一句注释：编辑器里除了那支笔，谁都不许直接 draw_line。
## 判定分两层 —— 真正落笔的四个文件必须引 StrokePainter；只画卡面的 CardFace 则必须把
## 符号交给 GlyphPainter。于是「这一段线是谁画的」全工程只有一个答案。
func _check_unified_pen(ctx: RefCounted) -> void:
	var offenders: PackedStringArray = PackedStringArray()
	var sources: Dictionary = {}
	for path: String in _gd_files(EDITOR_DIR):
		var code: String = _code_only(path)
		var file: String = path.get_file()
		sources[file] = code
		if code.contains("draw_line(") and file != "stroke_painter.gd":
			offenders.append(file)
	ctx.equal(offenders.size(), 0,
		"编辑器里只有 StrokePainter 直接 draw_line" if offenders.is_empty()
		else "绕过笔的文件：%s" % ", ".join(offenders))
	# 符号 / 图标 / 状态角标与辅助线 —— 这四类直线笔画全经那支笔，于是
	# 「线宽 · 圆角 · 端点」只有一处定义，改粗细不会漏掉其中某一类。
	for file: String in ["glyph_painter.gd", "icon_painter.gd", "board_state_painter.gd"]:
		ctx.check(String(sources.get(file, "")).contains("StrokePainter."),
			"%s 经 StrokePainter 落笔" % file)
	# 丝线是**故意**不走那支笔的：它是采样过的贝塞尔曲线（draw_polyline），
	# 与辅助线的直线段在线型上就分得开 —— 这正是 13 §10.1 要的「即使同色也不同线型」。
	ctx.check(String(sources.get("thread_painter.gd", "")).contains("draw_polyline("),
		"丝线仍走 draw_polyline 曲线，没有退化成和辅助线一样的直线段")


# ---------------------------------------------------------------- 工具

## 把一组折线栅格化成 GRID×GRID 的占用位图，先按自身包围盒归一化。
## 归一化是关键：不归一化的话「两枚符号大小不同」会被当成不像，而我们要抓的恰恰是
## 「换个尺寸就是同一个图形」。
static func _signature(paths: Array[Dictionary]) -> PackedFloat32Array:
	var points: PackedVector2Array = PackedVector2Array()
	for path: Dictionary in paths:
		var poly: PackedVector2Array = path["points"]
		var last: int = poly.size() if bool(path["closed"]) else poly.size() - 1
		for index: int in last:
			var a: Vector2 = poly[index]
			var b: Vector2 = poly[(index + 1) % poly.size()]
			for step: int in SAMPLES + 1:
				points.append(a.lerp(b, float(step) / float(SAMPLES)))
	var grid: PackedFloat32Array = PackedFloat32Array()
	grid.resize(GRID * GRID)
	if points.is_empty():
		return grid
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	var span: Vector2 = Vector2(maxf(box.size.x, 0.0001), maxf(box.size.y, 0.0001))
	for point: Vector2 in points:
		var u: Vector2 = (point - box.position) / span
		var cell: Vector2i = Vector2i(clampi(int(u.x * float(GRID - 1) + 0.5), 0, GRID - 1),
			clampi(int(u.y * float(GRID - 1) + 0.5), 0, GRID - 1))
		grid[cell.y * GRID + cell.x] = 1.0
	return grid


## Jaccard 相似度：交集 / 并集。1 = 完全同一张位图。
static func _similarity(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var both: int = 0
	var either: int = 0
	for index: int in a.size():
		var hit: bool = a[index] > 0.0 or b[index] > 0.0
		if hit:
			either += 1
		if hit and a[index] > 0.0 and b[index] > 0.0:
			both += 1
	return float(both) / float(maxi(either, 1))


static func _gd_files(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = "%s/%s" % [root, entry]
		if dir.current_is_dir():
			found.append_array(_gd_files(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


## 去掉注释行 —— 否则「本文件不得自己 draw_line」这句说明本身会把扫描判红。
static func _code_only(path: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			kept.append(line)
	return "\n".join(kept)
