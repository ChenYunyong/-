## test_map_route.gd
## 职责：路线图**路线几何**的验收 —— 端点裁到圆边、不穿节点、不穿短名框、避让不超过 24px。
## 所属系统：tests
## 依赖：MapModel, MapLayout, MapNodePainter, Palette
## 禁止：本文件不得写入几何常量，只断言；不得调用画笔的私有裁剪函数 —— 判据必须独立于被测代码。
##
## §2.2 对路线有三句硬话：端点裁到圆边、不穿过节点文字、可作不超过 24px 的折线避让。
## 前两句在真机上「看不出错」—— 线压过一行字只是有点脏，不会报错；第三句没有上界就会越绕越远。
## 所以这里把每一条真实的边取出来**逐点采样**，一行行量那三句话。
##
## 为什么采样而不是调用画笔的裁剪函数：那正是被测代码。换一套独立判据（点在不在矩形里、
## 离圆心多远）才算真的验过 —— 裁剪函数写错时，同一份错误会在断言里再犯一次，两面都绿。
##
## 避让本身由 O(n) 的采样量，代价可控：先用折线的外接框把要检的框与圆筛掉大半。

extends RefCounted

## 采样步长（逻辑像素）。0.25 远小于任何一条被判违规的线段，不会从缝里漏过去。
const SAMPLE_STEP: float = 0.25
## §2.2：避让偏差不超过 24px。
const MAX_DETOUR: float = 24.0
## 采样点「陷进去」的判定容差。折线避让之后线**正好切在短名框的角上**，
## 那一刻的交集是零面积，不该算违规。
const TOUCH_EPSILON: float = 0.05
## 一条边真的需要避让的判定门槛：直线压进短名框超过这么多像素才算。
const CROSS_THRESHOLD: float = 1.0


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_map_route")
	var map: MapModel = MapModel.new()
	map.generate(20261008)
	_check_adjacent_tiers(ctx, map)
	_check_styles(ctx)
	_check_style_choices(ctx, map)
	_check_endpoints(ctx, map)
	_check_clear_of_labels(ctx, map)
	_check_clear_of_nodes(ctx, map)
	_check_detour_budget(ctx, map)
	_check_detector(ctx)


## §2.2：边仅连接**相邻层**。跨层连线会让「往哪走」这件事失去意义。
func _check_adjacent_tiers(ctx: RefCounted, map: MapModel) -> void:
	var edges: Array[Dictionary] = _edges(map)
	ctx.check(edges.size() > 0, "这张图有 %d 条边（否则下面几条是空断言）" % edges.size())
	var bad: int = 0
	for edge: Dictionary in edges:
		var from: MapModel.MapNode = map.find(edge["from_id"])
		var to: MapModel.MapNode = map.find(edge["to_id"])
		if to.tier != from.tier + 1:
			bad += 1
	ctx.equal(bad, 0, "每条边都连着相邻的两层（共 %d 条）" % edges.size())


## §3 的三支取色 + §2.2 的三档线型。三档必须**两两可分辨** ——
## 可选与走过是同一个颜色，能分开它们的只有线型，所以线型这一列不是装饰。
func _check_styles(ctx: RefCounted) -> void:
	ctx.equal(MapNodePainter.EDGE_TOKEN[MapNodePainter.EdgeStyle.DORMANT],
		Palette.Key.BROWN_300, "其余路线 = BROWN_300（§3）")
	ctx.equal(MapNodePainter.EDGE_TOKEN[MapNodePainter.EdgeStyle.OPEN],
		Palette.Key.BROWN_700, "可达路线 = BROWN_700（§3）")
	ctx.equal(MapNodePainter.EDGE_TOKEN[MapNodePainter.EdgeStyle.WALKED],
		Palette.Key.BROWN_700, "走过路线 = BROWN_700（§3）")
	ctx.equal(MapNodePainter.ARROW_LENGTH, 8.0, "箭头长 8（§2.2）")
	ctx.equal(MapNodePainter.ARROW_SPREAD, 0.5, "箭头两撇各偏 0.5 rad")
	var wanted: Array = [
		["其余虚线 1（4/4）", MapNodePainter.EdgeStyle.DORMANT, 1.0, 4.0, 4.0],
		["可达虚线 2（8/4）", MapNodePainter.EdgeStyle.OPEN, 2.0, 8.0, 4.0],
		["走过实线 2 + 箭头", MapNodePainter.EdgeStyle.WALKED, 2.0, 0.0, 0.0],
	]
	for row: Array in wanted:
		ctx.equal(MapNodePainter.EDGE_WIDTH[row[1]], row[2], "%s：线宽" % row[0])
		ctx.equal(MapNodePainter.EDGE_DASH[row[1]], row[3], "%s：虚线段" % row[0])
		ctx.equal(MapNodePainter.EDGE_GAP[row[1]], row[4], "%s：虚线空" % row[0])
	ctx.check(MapNodePainter.EDGE_WIDTH[MapNodePainter.EdgeStyle.OPEN]
			> MapNodePainter.EDGE_WIDTH[MapNodePainter.EdgeStyle.DORMANT],
		"可达的比其余的粗")
	ctx.check(MapNodePainter.EDGE_DASH[MapNodePainter.EdgeStyle.OPEN]
			> MapNodePainter.EDGE_DASH[MapNodePainter.EdgeStyle.DORMANT],
		"可达的虚线段比其余的长")
	ctx.check(MapNodePainter.EDGE_DASH[MapNodePainter.EdgeStyle.WALKED] == 0.0,
		"走过的是实线（虚线段为 0）")


## 走过的边加粗留痕，当前节点的出边是可走的，其余一律是淡的。
func _check_style_choices(ctx: RefCounted, map: MapModel) -> void:
	var first: MapModel.MapNode = map.selectable()[0]
	map.select(first.id)
	var second: MapModel.MapNode = map.selectable()[0]
	map.select(second.id)

	ctx.equal(map.path(), [first.id, second.id] as Array[int], "走过的顺序记得住")
	ctx.equal(MapNodePainter.edge_style(first.id, second.id, map.path(), map.current_id()),
		MapNodePainter.EdgeStyle.WALKED, "走过的那条边是 WALKED")
	var open: int = 0
	for id: int in second.next:
		open += 1
		ctx.equal(MapNodePainter.edge_style(second.id, id, map.path(), map.current_id()),
			MapNodePainter.EdgeStyle.OPEN, "当前节点的出边 %d 是可走的" % id)
	ctx.check(open > 0, "当前节点确实有出边（否则上一条是空断言）")
	# 反向对照：没走过的那些边一律是淡的 —— 痕迹只沿着走过的那条线，不会整片亮起来。
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
	ctx.check(dormant > 0, "那些节点确实有出边（否则上一条是空断言）")


## §2.2：端点**裁到圆边** —— 线不许画进节点里，也不许离节点还差一截。
func _check_endpoints(ctx: RefCounted, map: MapModel) -> void:
	var radius: float = MapLayout.NODE_RADIUS
	var worst: float = 0.0
	for edge: Dictionary in _edges(map):
		var points: PackedVector2Array = edge["points"]
		if not ctx.check(points.size() >= 2, "边 %d→%d 是一条线" % [edge["from_id"], edge["to_id"]]):
			continue
		worst = maxf(worst, absf(points[0].distance_to(edge["source"]) - radius))
		worst = maxf(worst, absf(points[points.size() - 1].distance_to(edge["target"]) - radius))
		ctx.check(points[0].distance_to(edge["source"]) > 0.0, "起点不在源节点圆心（线从圆边起）")
	ctx.near(worst, 0.0, "每条边的两端都正好落在圆边上（最大偏差 %.3f）" % worst)


## M03：短名框与线路的**交集面积 = 0**。独立判据：把折线采样，逐点问「陷进框里多深」。
func _check_clear_of_labels(ctx: RefCounted, map: MapModel) -> void:
	var worst: float = -1e9
	var where: String = ""
	for edge: Dictionary in _edges(map):
		var samples: PackedVector2Array = _samples(edge["points"])
		var scope: Rect2 = _bounds(edge["points"]).grow(1.0)
		for tier: int in MapModel.TIERS:
			for column: int in MapModel.COLUMNS:
				var label: Rect2 = MapLayout.node_label_rect(tier, column)
				if not scope.intersects(label):
					continue
				for at: Vector2 in samples:
					var depth: float = _depth_in_rect(at, label)
					if depth > worst:
						worst = depth
						where = "边 %d→%d × 第 %d 层第 %d 列的短名" % [edge["from_id"],
							edge["to_id"], tier, column]
	ctx.check(worst <= TOUCH_EPSILON,
		"M03：%d 条边与 18 个短名框的交集面积 = 0（最深处 %.3f px）%s"
			% [_edges(map).size(), worst, "" if worst <= TOUCH_EPSILON else "；%s" % where])


## 路线不许压过**别的**节点（两端那两个例外：端点本来就落在它们的圆边上）。
func _check_clear_of_nodes(ctx: RefCounted, map: MapModel) -> void:
	var radius: float = MapLayout.NODE_RADIUS
	var worst: float = -1e9
	var where: String = ""
	for edge: Dictionary in _edges(map):
		var samples: PackedVector2Array = _samples(edge["points"])
		var scope: Rect2 = _bounds(edge["points"]).grow(1.0)
		for node: MapModel.MapNode in map.nodes():
			if node.id == edge["from_id"] or node.id == edge["to_id"]:
				continue
			var center: Vector2 = MapLayout.node_position(node.tier, node.column)
			if not scope.grow(radius).has_point(center):
				continue
			for at: Vector2 in samples:
				var depth: float = radius - at.distance_to(center)
				if depth > worst:
					worst = depth
					where = "边 %d→%d × 节点 %d" % [edge["from_id"], edge["to_id"], node.id]
	ctx.check(worst <= TOUCH_EPSILON,
		"路线不压过别的节点（最深处 %.3f px）%s" % [worst,
			"" if worst <= TOUCH_EPSILON else "；%s" % where])


## §2.2：可以绕，但**不超过 24px**。绕多远 = 折线上离「两个圆心连成的直线」最远的那一点。
func _check_detour_budget(ctx: RefCounted, map: MapModel) -> void:
	var worst: float = 0.0
	var detoured: int = 0
	var needed: int = 0
	for edge: Dictionary in _edges(map):
		var reach: float = 0.0
		for at: Vector2 in _samples(edge["points"]):
			reach = maxf(reach, _line_distance(at, edge["source"], edge["target"]))
		worst = maxf(worst, reach)
		if reach > CROSS_THRESHOLD:
			detoured += 1
		if _straight_presses(edge, map):
			needed += 1
	ctx.check(worst <= MAX_DETOUR,
		"折线避让不超过 24px（最远的一条绕了 %.3f px）" % worst)
	# 反向对照两连：既有真的绕了的边，也有「不绕就会压到字」的边 ——
	# 少了后一条，避让逻辑整段可以是死代码而上面那条照样绿。
	ctx.check(detoured > 0, "确实有 %d 条边绕了（避让逻辑被走到过）" % detoured)
	ctx.check(needed > 0, "确实有 %d 条边不绕就会压到短名框（避让不是多余的）" % needed)


## 判据本身的反向对照：取样点落在框心要判「陷得深」，落在框外要判「没陷」。
func _check_detector(ctx: RefCounted) -> void:
	var box: Rect2 = Rect2(100.0, 100.0, 96.0, 24.0)
	ctx.check(_depth_in_rect(box.get_center(), box) > 10.0, "反向对照：框心判为深深陷入")
	ctx.check(_depth_in_rect(Vector2(99.0, 112.0), box) < 0.0, "反向对照：框外一点判为没陷进去")
	ctx.check(absf(_depth_in_rect(Vector2(100.0, 112.0), box)) <= TOUCH_EPSILON,
		"反向对照：正好贴在框边上算「擦着过」，不算违规")
	# 采样本身也要有分辨力：一条明显穿过框心的直线必须被采到。
	var through: PackedVector2Array = PackedVector2Array(
		[Vector2(80.0, 112.0), Vector2(220.0, 112.0)])
	var worst: float = -1e9
	for at: Vector2 in _samples(through):
		worst = maxf(worst, _depth_in_rect(at, box))
	ctx.near(worst, 12.0, "反向对照：横穿框心的直线被采到（最深处）. ", 0.3)


# ---------------------------------------------------------------- 工具

## 这张图上每一条真实的边：两端节点、折线、两个圆心（纸内局部坐标）。
func _edges(map: MapModel) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: MapModel.MapNode in map.nodes():
		var source: Vector2 = MapLayout.node_position(node.tier, node.column)
		for next_id: int in node.next:
			var target: MapModel.MapNode = map.find(next_id)
			if target == null:
				continue
			var to: Vector2 = MapLayout.node_position(target.tier, target.column)
			result.append({
				"from_id": node.id, "to_id": next_id,
				"source": source, "target": to,
				"points": MapNodePainter.edge_points(source, to, MapLayout.NODE_RADIUS,
					MapLayout.node_label_rect(node.tier, node.column),
					MapLayout.node_label_rect(target.tier, target.column)),
			})
	return result


## 不做避让（直接把两个圆心连起来）时，会不会压到短名框 —— 用来证明避让不是白绕的。
func _straight_presses(edge: Dictionary, map: MapModel) -> bool:
	var straight: PackedVector2Array = PackedVector2Array([edge["source"], edge["target"]])
	for tier: int in MapModel.TIERS:
		for column: int in MapModel.COLUMNS:
			var label: Rect2 = MapLayout.node_label_rect(tier, column)
			for at: Vector2 in _samples(straight):
				if _depth_in_rect(at, label) > CROSS_THRESHOLD:
					return true
	return false


## 折线按固定步长采样（含两端点）。步长足够小，任何一条被判违规的线段都不会从缝里漏过去。
static func _samples(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for index: int in maxi(points.size() - 1, 0):
		var from: Vector2 = points[index]
		var to: Vector2 = points[index + 1]
		var steps: int = maxi(int(ceilf(from.distance_to(to) / SAMPLE_STEP)), 1)
		for step: int in steps + 1:
			result.append(from.lerp(to, float(step) / float(steps)))
	return result


static func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var box: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		box = box.expand(point)
	return box


## 点在矩形里陷进去多深。≤0 表示在外面或正好贴边。
static func _depth_in_rect(at: Vector2, rect: Rect2) -> float:
	return minf(minf(at.x - rect.position.x, rect.end.x - at.x),
		minf(at.y - rect.position.y, rect.end.y - at.y))


## 点到「两个圆心连成的直线」的距离。用向量积手算，不依赖 Vector2.cross 的版本差异。
static func _line_distance(at: Vector2, from: Vector2, to: Vector2) -> float:
	var direction: Vector2 = to - from
	var length: float = direction.length()
	if length <= 0.0:
		return at.distance_to(from)
	var span: Vector2 = at - from
	return absf(span.x * direction.y - span.y * direction.x) / length
