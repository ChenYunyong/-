## test_map_paint.gd
## 职责：羊皮卷路线图**画法**的验收 —— 四状态两两分得开、取色与 §3 逐字对得上、纸面与墨色读得出。
## 所属系统：tests
## 依赖：MapModel, MapNodePainter, MapParchment, Palette
## 禁止：本文件不得写入布局 / 颜色常量，只断言。
##
## 为什么四状态要「算」而不是「看」：06 §11 禁止只靠明度区分状态。这条规则如果只靠肉眼过一遍，
## 下一个改配色的人会把某一对又调回同一个亮度，而且没有任何东西会响。这里把每个状态拆成
## 六个可比的维度，逐对要求至少两维不同 —— 改坏了就是一条红的算术，不是一句审美意见。
##
## 版式（东西摆在哪、摆不摆得下）在 test_map_layout，路线几何在 test_map_route，
## 符号与形状标记在 test_map_symbol —— 本文件只管画上去长什么样。

extends RefCounted

## 本工程判「两个颜色已经读不出区别」的 RGB 欧氏距离（与 test_layout_p0 同一个口径）。
const COLLAPSE_DISTANCE: float = 96.0
## 06 §11 的正文对比度下限。
const MIN_CONTRAST: float = 4.5

const ROGUELIKE_DIR: String = "res://scripts/roguelike"
## 路线图这一摊的三支画笔。它们只许把几何交给 StrokePainter（见 _check_unified_pen）。
const PAINTERS: PackedStringArray = ["map_parchment.gd", "map_node_painter.gd",
	"map_symbol_painter.gd"]
## 维度里哪几个是颜色（其余是结构：空心 / 外圈外扩 / 形状标记）。
const COLOR_DIMS: PackedStringArray = ["fill", "ring", "ink"]
const STATE_NAMES: PackedStringArray = ["不可达", "可选", "已访问", "当前"]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_map_paint")
	_check_states_separable(ctx)
	_check_state_tokens(ctx)
	_check_states_on_paper(ctx)
	_check_ink_legible(ctx)
	_check_state_of(ctx)
	_check_fibers(ctx)
	_check_unified_pen(ctx)


# ---------------------------------------------------------------- 四状态

## 四个状态两两至少差两个维度 —— 这是 §2「不靠明度」那条的可算版本。
func _check_states_separable(ctx: RefCounted) -> void:
	var dimensions: Array[Dictionary] = []
	for state: MapNodePainter.State in MapNodePainter.State.size():
		dimensions.append(MapNodePainter.dimensions(state))
	ctx.equal(dimensions.size(), 4, "四种状态各有自己的外观表")

	var thin: PackedStringArray = PackedStringArray()
	var worst: int = dimensions[0].size()
	for one: int in dimensions.size():
		for other: int in range(one + 1, dimensions.size()):
			var count: int = _differing_dims(dimensions[one], dimensions[other])
			worst = mini(worst, count)
			if count < 2:
				thin.append("%s↔%s 只差 %d 维" % [STATE_NAMES[one], STATE_NAMES[other], count])
	ctx.equal(thin.size(), 0,
		"四状态两两至少差两维（最少的一对差 %d 维）" % worst
			if thin.is_empty() else "太像：%s" % "; ".join(thin))

	# 反向对照：这一对上**填充**只差不到阈值 —— 证明「光靠颜色」真的不够，
	# 上面那条（≥2 维）不是凑出来的。这一对就是当初逼出外圈与内环的那一对。
	var visited: Dictionary = dimensions[MapNodePainter.State.VISITED]
	var current: Dictionary = dimensions[MapNodePainter.State.CURRENT]
	ctx.check(_rgb_distance(visited["fill"], current["fill"]) < COLLAPSE_DISTANCE,
		"反向对照：已访问与当前的填充只差 %.1f < %.0f，颜色本身分不开它们"
			% [_rgb_distance(visited["fill"], current["fill"]), COLLAPSE_DISTANCE])
	# 它们靠哪几维分开的，也要点名钉住 —— 免得日后「简化」掉外圈或形状标记。
	ctx.not_equal(visited["ring"], current["ring"], "已走与当前的边不同（已走的边与底同色 = 没有边）")
	ctx.not_equal(visited["mark"], current["mark"], "已访问与当前的形状标记也不同（勾 / 定位三角）")


## §3 的四行「地图…」逐字对照。配色是契约给的，不是这里挑的 ——
## 换一支 Token 就是改这一屏的样子，所以它值得一条点名到 Token 的断言。
##
## 顺带把 §2.2 重复元素表里的圈宽 / 外扩 / 暗底也钉在这里：它们和取色是同一张表上的事。
func _check_state_tokens(ctx: RefCounted) -> void:
	var rows: Array = [
		["地图未到达", MapNodePainter.State.UNREACHABLE, Palette.Key.GOLD_200,
			Palette.Key.BROWN_300, Palette.Key.BROWN_700],
		["地图可选", MapNodePainter.State.SELECTABLE, Palette.Key.GOLD_500,
			Palette.Key.BROWN_700, Palette.Key.BROWN_700],
		["地图当前", MapNodePainter.State.CURRENT, Palette.Key.NAVY_800,
			Palette.Key.GOLD_500, Palette.Key.BLUE_100],
		["地图已走", MapNodePainter.State.VISITED, Palette.Key.BROWN_700,
			Palette.Key.BROWN_700, Palette.Key.GOLD_200],
	]
	for row: Array in rows:
		ctx.equal(MapNodePainter.STATE_FILL[row[1]], row[2], "%s 填 = %s（§3）" % [row[0], row[2]])
		ctx.equal(MapNodePainter.STATE_RING[row[1]], row[3], "%s 环 = %s（§3）" % [row[0], row[3]])
		ctx.equal(MapNodePainter.STATE_INK[row[1]], row[4], "%s 墨 = %s（§3）" % [row[0], row[4]])
	ctx.equal(MapNodePainter.fill_color(MapNodePainter.State.UNREACHABLE),
		MapParchment.paper_color(), "羊皮纸面就是不可达的填充色（GOLD_200）")
	# §2.2：普通圈宽 1、当前圈宽 3 且外扩 4，其下暗底宽 5。
	var plain: int = 0
	for state: MapNodePainter.State in MapNodePainter.State.size():
		if MapNodePainter.STATE_RING_GROW[state] > 0.0:
			ctx.equal(state, MapNodePainter.State.CURRENT, "只有当前那个圈外扩")
			ctx.equal(MapNodePainter.STATE_RING_GROW[state], 4.0, "当前圈外扩 4")
			ctx.equal(MapNodePainter.STATE_RING_WIDTH[state], 3.0, "当前圈宽 3")
		else:
			plain += 1
			ctx.equal(MapNodePainter.STATE_RING_WIDTH[state], 1.0, "普通圈宽 1")
	ctx.equal(plain, 3, "四个状态里三个是普通圈（否则上面那条没量到东西）")
	ctx.equal(MapNodePainter.needs_dark_backing(MapNodePainter.State.CURRENT), true,
		"当前圈垫暗底")
	ctx.equal(MapNodePainter.UNDER_RING_WIDTH, 5.0, "暗底宽 5（比它上面那圈金边宽）")
	# 暗底存在的**理由**是 §3.2：金圈贴纸面只有 1.218:1，没有它就几乎没有边界。
	var paper: Color = MapParchment.paper_color()
	ctx.check(_contrast(Palette.get_color(MapNodePainter.UNDER_RING), paper) >= MIN_CONTRAST,
		"暗底对纸面 %.2f:1 ≥ %.1f（它替金圈把边界画出来）"
			% [_contrast(Palette.get_color(MapNodePainter.UNDER_RING), paper), MIN_CONTRAST])


## 每种状态在纸面上都要**至少有一条线读得出来**。不可达是靠外圈（它是空心的），
## 当前是靠暗底 + 填充（它那圈金色在纸上只有 69 的距离，单靠它读不出来）。
func _check_states_on_paper(ctx: RefCounted) -> void:
	var paper: Color = MapParchment.paper_color()
	for state: MapNodePainter.State in MapNodePainter.State.size():
		var dimensions: Dictionary = MapNodePainter.dimensions(state)
		var ring: float = _rgb_distance(dimensions["ring"], paper)
		var fill: float = 0.0 if bool(dimensions["hollow"]) else _rgb_distance(dimensions["fill"], paper)
		ctx.check(maxf(ring, fill) >= COLLAPSE_DISTANCE,
			"%s 在纸面上读得出来（外圈 %.1f / 填充 %.1f）" % [STATE_NAMES[state], ring, fill])
	# 空心是「不可达」唯一的结构特征，不能变成实心 —— 它和纸色只差 0，一填就没了。
	ctx.check(bool(MapNodePainter.dimensions(MapNodePainter.State.UNREACHABLE)["hollow"]),
		"不可达是空心的（填了纸色就等于没画）")
	ctx.near(_rgb_distance(MapNodePainter.dimensions(MapNodePainter.State.UNREACHABLE)["fill"],
		paper), 0.0, "不可达的填充色就是纸色 —— 它不靠填充说话")


## 纸面上的字。金色**做不了**纸面文字：GOLD_500 对纸面 GOLD_200 实测 1.218:1（§3.2），
## 远在 4.5 之下，金字的纸面等于没字 —— 所以纸上的字一律走墨色 BROWN_700（10.947:1）。
func _check_ink_legible(ctx: RefCounted) -> void:
	var paper: Color = MapParchment.paper_color()
	var ink: Color = Palette.get_color(MapNodePainter.INK_ON_PAPER)
	ctx.check(_contrast(ink, paper) >= MIN_CONTRAST,
		"节点短名 / 图例的墨色对纸面 %.2f:1 ≥ %.1f" % [_contrast(ink, paper), MIN_CONTRAST])
	ctx.check(_contrast(Palette.get_color(Palette.Key.GOLD_500), paper) < MIN_CONTRAST,
		"反向对照：金字的纸面对比度只有 %.2f:1，不够当文字用"
			% _contrast(Palette.get_color(Palette.Key.GOLD_500), paper))
	for state: MapNodePainter.State in MapNodePainter.State.size():
		var dimensions: Dictionary = MapNodePainter.dimensions(state)
		var ground: Color = paper if bool(dimensions["hollow"]) else dimensions["fill"]
		ctx.check(_contrast(dimensions["ink"], ground) >= MIN_CONTRAST,
			"%s 里的符号读得出（%.2f:1 ≥ %.1f）"
				% [STATE_NAMES[state], _contrast(dimensions["ink"], ground), MIN_CONTRAST])


## 状态判定：拿一张真图逐个走，每一步之后四种状态都得各就各位。
func _check_state_of(ctx: RefCounted) -> void:
	var map: MapModel = MapModel.new()
	map.generate(20261008)
	var first: MapModel.MapNode = map.selectable()[0]
	ctx.equal(MapNodePainter.state_of(map, first.id), MapNodePainter.State.SELECTABLE,
		"开局第 0 层是可选的")
	ctx.equal(MapNodePainter.state_of(map, map.nodes_in_tier(3)[0].id),
		MapNodePainter.State.UNREACHABLE, "第 3 层此刻不可达")

	ctx.check(map.select(first.id), "走到第 0 层的一个节点")
	ctx.equal(MapNodePainter.state_of(map, first.id), MapNodePainter.State.CURRENT,
		"走过的那个就是当前 —— 当前优先于已访问")
	for node: MapModel.MapNode in map.selectable():
		ctx.equal(MapNodePainter.state_of(map, node.id), MapNodePainter.State.SELECTABLE,
			"第 1 层节点 %d 可选" % node.id)
	var blockable: int = 0
	for node: MapModel.MapNode in map.nodes_in_tier(1):
		if not first.next.has(node.id):
			blockable += 1
			ctx.equal(MapNodePainter.state_of(map, node.id), MapNodePainter.State.UNREACHABLE,
				"第 1 层节点 %d 不在出边上 → 不可达" % node.id)
	ctx.check(blockable > 0, "这一层确实有不可达的节点（否则上面那条断言是空的）")

	var second: MapModel.MapNode = map.selectable()[0]
	ctx.check(map.select(second.id), "再走一步")
	ctx.equal(MapNodePainter.state_of(map, first.id), MapNodePainter.State.VISITED,
		"上一步走过的那里退成已访问")


## M04：纸纹不许长进**节点外扩 8** 与**短名外扩 4** 的保护区，也不许压到 8px 材质边带上。
## 它是纸上的装饰，压到符号或字上就是脏 —— 而「有点脏」在 headless 下不会报错。
func _check_fibers(ctx: RefCounted) -> void:
	ctx.check(MapParchment.FIBER_ALPHA <= 0.08, "纸纹 alpha %.2f ≤ 0.08（§4 M04）"
		% MapParchment.FIBER_ALPHA)
	# 纤维只画在纸**面**上：整个 PAPER 扣掉 8px 边带，暖色材质层那圈不许被压。
	var face: Rect2 = Rect2(Vector2.ZERO, MapLayout.PAPER.size).grow(-MapLayout.PAPER_BAND)
	var zones: Array[Rect2] = MapLayout.protected_rects()
	ctx.equal(zones.size(), 36, "保护区 = 18 个节点的外扩框 + 18 个短名框的外扩框")
	var fibers: Array[Rect2] = MapParchment.fibers(face, zones)
	ctx.check(fibers.size() >= 100, "纸面铺了 %d 根纤维（太少就不像纸了）" % fibers.size())
	var outside: int = 0
	for fiber: Rect2 in fibers:
		if not face.encloses(fiber):
			outside += 1
	ctx.equal(outside, 0, "纤维都长在纸面里（不压 8px 材质边带）")
	# 「文字框下 ≤ 0.03」在这条实现里是更强的结论：纤维一根都不进那些框，那里是 0。
	ctx.check(not _overlaps_any(fibers, zones), "纤维一根都没进保护区（节点外扩 8 / 短名外扩 4）")
	# 反向对照：不让路的话确实有纤维会落进去 —— 否则上面那条是白来的。
	var none: Array[Rect2] = []
	ctx.check(_overlaps_any(MapParchment.fibers(face, none), zones),
		"反向对照：不让路的话有纤维会落进保护区")


## 有没有一根纤维落进保护区。
static func _overlaps_any(fibers: Array[Rect2], zones: Array[Rect2]) -> bool:
	for fiber: Rect2 in fibers:
		for zone: Rect2 in zones:
			if _overlaps(fiber, zone):
				return true
	return false


## 路线图这一摊不许另起一支笔 —— PET-87 那套（线宽 / 圆角 / 端点）只有一处定义。
func _check_unified_pen(ctx: RefCounted) -> void:
	var sources: Dictionary = {}
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _gd_files(ROGUELIKE_DIR):
		var code: String = _code_only(path)
		sources[path.get_file()] = code
		for call: String in ["draw_line(", "draw_polyline(", "draw_arc(", "draw_dashed_line("]:
			if code.contains(call):
				offenders.append("%s 直接调 %s" % [path.get_file(), call])
	ctx.equal(offenders.size(), 0,
		"线一律经 StrokePainter 落笔" if offenders.is_empty() else "绕过笔：%s" % "; ".join(offenders))
	for file: String in PAINTERS:
		ctx.check(String(sources.get(file, "")).contains("StrokePainter."),
			"%s 经 StrokePainter 落笔" % file)
	# 反向对照：扫描确实读到了文件（否则上面那些「没违规」是空扫描换来的）。
	ctx.check(sources.size() > PAINTERS.size(), "扫描读到了 %d 个文件" % sources.size())


# ---------------------------------------------------------------- 工具

## 两个状态在外观表上差几个维度：颜色按距离算（过阈值才算不同），结构直接比。
static func _differing_dims(one: Dictionary, other: Dictionary) -> int:
	var count: int = 0
	for key: String in one:
		if COLOR_DIMS.has(key):
			if _rgb_distance(one[key], other[key]) >= COLLAPSE_DISTANCE:
				count += 1
		elif bool(one[key]) != bool(other[key]) \
				or not is_equal_approx(float(one[key]), float(other[key])):
			count += 1
	return count


## 两个矩形是不是**真的**压在一起。Rect2.intersects() 默认把「仅相邻」也算相交，
## 而这里问的是「有没有一块共同面积」—— 擦边不算。
static func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x \
		and a.position.y < b.end.y and b.position.y < a.end.y


## 两个颜色在 0-255 的 RGB 空间里的欧氏距离 —— 本工程判「已塌成一家」的那把尺。
static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 255.0


## WCAG 对比度。06 §11 的 4.5:1 就是按它算的。
static func _contrast(a: Color, b: Color) -> float:
	var one: float = _luminance(a)
	var other: float = _luminance(b)
	return (maxf(one, other) + 0.05) / (minf(one, other) + 0.05)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


static func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _gd_files(root: String) -> PackedStringArray:
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


func _code_only(path: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			kept.append(line)
	return "\n".join(kept)
