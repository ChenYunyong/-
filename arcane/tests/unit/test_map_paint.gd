## test_map_paint.gd
## 职责：羊皮卷路线图**画法**的验收 —— 四状态两两分得开、纸面与墨色读得出、符号画得出来。
## 所属系统：tests
## 依赖：MapModel, MapLayout, MapView, MapNodePainter, MapParchment, MapSymbolPainter
## 禁止：本文件不得写入布局 / 颜色常量，只断言。
##
## 为什么四状态要「算」而不是「看」：06 §11 禁止只靠明度区分状态。这条规则如果只靠肉眼过一遍，
## 下一个改配色的人会把某一对又调回同一个亮度，而且没有任何东西会响。这里把每个状态拆成
## 六个可比的维度，逐对要求至少两维不同 —— 改坏了就是一条红的算术，不是一句审美意见。
##
## 版式（东西摆在哪、摆不摆得下）在 test_map_layout 里，本文件只管画上去长什么样。

extends RefCounted

## 本工程判「两个颜色已经读不出区别」的 RGB 欧氏距离（与 test_layout_p0 同一个口径）。
const COLLAPSE_DISTANCE: float = 96.0
## 06 §11 的正文对比度下限。
const MIN_CONTRAST: float = 4.5

const ROGUELIKE_DIR: String = "res://scripts/roguelike"
## 路线图这一摊的三支画笔。它们只许把几何交给 StrokePainter（见 _check_unified_pen）。
const PAINTERS: PackedStringArray = ["map_parchment.gd", "map_node_painter.gd",
	"map_symbol_painter.gd"]
## 维度里哪几个是颜色（其余是结构：空心 / 外扩 / 内环）。
const COLOR_DIMS: PackedStringArray = ["fill", "ring", "ink"]
const STATE_NAMES: PackedStringArray = ["不可达", "可选", "已访问", "当前"]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_map_paint")
	_check_states_separable(ctx)
	_check_states_on_paper(ctx)
	_check_ink_legible(ctx)
	_check_state_of(ctx)
	_check_edges(ctx)
	_check_symbols(ctx)
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
	# 它们靠哪几维分开的，也要点名钉住 —— 免得日后「简化」掉外圈或内环。
	ctx.not_equal(visited["ring"], current["ring"], "已访问与当前的外圈不是一个颜色")
	ctx.not_equal(visited["mark"], current["mark"], "当前节点多一圈内环")


## 每种状态在纸面上都要**至少有一条线读得出来**。不可达是靠外圈（它是空心的），
## 当前是靠填充（它那圈金色在纸上只有 64 的距离，单靠它读不出来）。
func _check_states_on_paper(ctx: RefCounted) -> void:
	var paper: Color = MapParchment.edge_color(0.0)
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


## 纸面上的字。金色**做不了**纸面文字：GOLD_500 对 WARM_300 实测 1.03:1，
## 远在 4.5 之下，金字的纸面等于没字 —— 所以纸上的字一律走墨色。
func _check_ink_legible(ctx: RefCounted) -> void:
	var paper: Color = MapParchment.edge_color(0.0)
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


## 走过的边加粗留痕，当前节点的出边是可走的，其余一律是淡的。
func _check_edges(ctx: RefCounted) -> void:
	var map: MapModel = MapModel.new()
	map.generate(777)
	var first: MapModel.MapNode = map.selectable()[0]
	map.select(first.id)
	var second: MapModel.MapNode = map.selectable()[0]
	map.select(second.id)

	var expected: Array[int] = [first.id, second.id]
	ctx.equal(map.path(), expected, "走过的顺序记得住")
	ctx.equal(MapNodePainter.edge_style(first.id, second.id, map.path(), map.current_id()),
		MapNodePainter.EdgeStyle.WALKED, "走过的那条边是 WALKED")
	var open: int = 0
	for id: int in second.next:
		open += 1
		ctx.equal(MapNodePainter.edge_style(second.id, id, map.path(), map.current_id()),
			MapNodePainter.EdgeStyle.OPEN, "当前节点的出边 %d 是可走的" % id)
	ctx.check(open > 0, "当前节点确实有出边（否则上一条是空断言）")
	# 反向对照：没走的那些边一律是淡的 —— 痕迹只沿着走过的那条线，不会整片亮起来。
	# 挑第 0 层里**另外两个**节点（= 既不是走过的起点，也不是当前节点），量它们自己的出边。
	var others: Array[MapModel.MapNode] = []
	for node: MapModel.MapNode in map.nodes_in_tier(0):
		if node.id != first.id:
			others.append(node)
	ctx.equal(others.size(), MapModel.COLUMNS - 1, "第 0 层还有两个没走过的节点")
	var dormant: int = 0
	for node: MapModel.MapNode in others:
		for id: int in node.next:
			dormant += 1
			ctx.equal(MapNodePainter.edge_style(node.id, id, map.path(), map.current_id()),
				MapNodePainter.EdgeStyle.DORMANT, "没走过的节点 %d 的出边 %d 还是淡的" % [node.id, id])
	ctx.check(dormant > 0, "那些节点确实有出边（否则上两条是空断言）")
	ctx.check(MapNodePainter.EDGE_WIDTH[MapNodePainter.EdgeStyle.WALKED]
		> MapNodePainter.EDGE_WIDTH[MapNodePainter.EdgeStyle.OPEN],
		"走过的痕迹比可走的更粗 —— 痕迹不是只换个颜色")


## 两种节点的符号：都画得出来、都在半径内、而且彼此不是同一个图形。
func _check_symbols(ctx: RefCounted) -> void:
	var drawn: Dictionary = {}
	var kinds: Array[MapModel.Kind] = [MapModel.Kind.BATTLE, MapModel.Kind.WORKSHOP]
	for kind: MapModel.Kind in kinds:
		var paths: Array[Dictionary] = MapSymbolPainter.paths(kind, Vector2.ZERO,
			MapLayout.SYMBOL_RADIUS)
		if not ctx.check(not paths.is_empty(), "%s 有几何" % MapView.kind_text(kind)):
			continue
		var bad: int = 0
		for path: Dictionary in paths:
			if path["points"].size() < 2:
				bad += 1
			for point: Vector2 in path["points"]:
				if not (is_finite(point.x) and is_finite(point.y)) \
						or point.length() > MapLayout.SYMBOL_RADIUS:
					bad += 1
		ctx.equal(bad, 0, "%s 的每一笔都在符号半径内、至少两点" % MapView.kind_text(kind))
		drawn[kind] = _flatten(paths)
	ctx.not_equal(drawn[MapModel.Kind.BATTLE], drawn[MapModel.Kind.WORKSHOP],
		"战斗与工坊不是同一个图形（符号 + 短名两重区分）")
	# 反向对照：同一个 kind 画两次当然一样 —— 证明上面那条比的是几何本身。
	ctx.equal(_flatten(MapSymbolPainter.paths(MapModel.Kind.BATTLE, Vector2.ZERO,
		MapLayout.SYMBOL_RADIUS)), drawn[MapModel.Kind.BATTLE], "反向对照：同一种 kind 画两次一致")
	ctx.check(MapSymbolPainter.SYMBOL_WIDTH < StrokePainter.WIDTH,
		"符号比笔的默认线宽细一档（22px 的圆里再压 3px 就糊了）")
	# 两种 kind 的短名也得是两个词 —— 图形之外的第二重区分。
	ctx.not_equal(MapView.kind_text(MapModel.Kind.BATTLE), MapView.kind_text(MapModel.Kind.WORKSHOP),
		"两种节点的短名不同")
	# 四个状态的图例名两两不同 —— 图例上写着同一个词就等于没写。
	var names: Dictionary = {}
	for state: MapNodePainter.State in MapNodePainter.State.size():
		names[MapView.state_text(state)] = true
	ctx.equal(names.size(), 4, "四种状态的说明各是一个词")


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


## 二维几何展开成一串坐标，用来直接比较两组图形是不是同一个。
static func _flatten(paths: Array[Dictionary]) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for path: Dictionary in paths:
		points.append_array(path["points"] as PackedVector2Array)
	return points


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
