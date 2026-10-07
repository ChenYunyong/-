## test_map_model.gd
## 职责：杀戮尖塔式路线图的验收 —— 分层连通、只能沿边前进、同种子同地图、终点可达。
## 所属系统：tests
## 依赖：MapModel
## 禁止：本文件不得引用任何节点 —— 地图模型必须能脱离场景单独验证。

extends RefCounted

## 多抽几张图来验性质：只验一张等于只验了那条路径。
const SAMPLE_SEEDS: PackedInt32Array = [1, 2, 3, 7, 42, 99, 1234, 65535, 20261006, -5]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_map_model")
	_check_shape(ctx)
	_check_connectivity(ctx)
	_check_walk(ctx)
	_check_determinism(ctx)
	_check_kinds(ctx)


func _check_shape(ctx: RefCounted) -> void:
	var map: MapModel = MapModel.new()
	map.generate(12345)
	ctx.equal(map.nodes().size(), MapModel.TIERS * MapModel.COLUMNS, "节点数 = 层数 × 列数")
	for tier: int in MapModel.TIERS:
		ctx.equal(map.nodes_in_tier(tier).size(), MapModel.COLUMNS,
			"第 %d 层有 %d 个节点" % [tier, MapModel.COLUMNS])
	# 起点在「还没出发」的状态，第一层整层可选。
	ctx.equal(map.current_id(), -1, "还没出发时没有当前节点")
	ctx.check(map.current() == null, "还没出发时 current() 是 null")
	ctx.equal(map.selectable().size(), MapModel.COLUMNS, "第 0 层整层可选")
	ctx.check(not map.is_finished(), "还没出发不算走完")


## 每一层都要能走到下一层 —— 否则玩家会卡在一层无路可走，这是最恶性的死局。
func _check_connectivity(ctx: RefCounted) -> void:
	var broken: PackedStringArray = PackedStringArray()
	for seed_value: int in SAMPLE_SEEDS:
		var map: MapModel = MapModel.new()
		map.generate(seed_value)
		for tier: int in MapModel.TIERS - 1:
			for node: MapModel.MapNode in map.nodes_in_tier(tier):
				if node.next.is_empty():
					broken.append("seed %d 第 %d 层节点 %d 无出路" % [seed_value, tier, node.id])
				for next_id: int in node.next:
					var target: MapModel.MapNode = map.find(next_id)
					if target == null or target.tier != tier + 1:
						broken.append("seed %d 的边 %d→%d 没连到下一层" % [seed_value, node.id, next_id])
		# 终点层没有出边 —— 走到那里就该结算了。
		for node: MapModel.MapNode in map.nodes_in_tier(MapModel.TIERS - 1):
			if not node.next.is_empty():
				broken.append("seed %d 的终点节点 %d 还有出边" % [seed_value, node.id])
	ctx.equal(broken.size(), 0,
		"每一层都连得通下一层" if broken.is_empty() else "断路：%s" % "; ".join(broken))


## 只能沿边一步步往前走：跳到不相邻的节点必须被拒绝，且**不得改变任何状态**。
func _check_walk(ctx: RefCounted) -> void:
	var map: MapModel = MapModel.new()
	map.generate(4242)
	var first: MapModel.MapNode = map.selectable()[0]

	# 反向对照：不是第 0 层的节点一律选不了。
	var far: MapModel.MapNode = map.nodes_in_tier(3)[0]
	ctx.check(not map.can_select(far.id), "开局不能直接跳到第 3 层")
	ctx.check(not map.select(far.id), "非法选择返回 false")
	ctx.equal(map.current_id(), -1, "非法选择之后状态没变")
	ctx.check(not map.is_visited(far.id), "非法选择之后没有留下访问记录")

	ctx.check(map.select(first.id), "走到第 0 层的一个节点")
	ctx.equal(map.current_id(), first.id, "当前节点就是走到的那个")
	ctx.check(map.is_visited(first.id), "走过的节点被记住")
	ctx.check(not map.is_finished(), "第 0 层不是终点")
	ctx.equal(map.selectable().size(), first.next.size(), "可选集合 = 当前节点的出边")

	# 在不在出边上的节点都选不了。
	var blocked: int = 0
	for node: MapModel.MapNode in map.nodes_in_tier(1):
		if not first.next.has(node.id):
			blocked += 1
			ctx.check(not map.can_select(node.id), "不在出边上的第 1 层节点 %d 不可选" % node.id)
	ctx.check(blocked > 0, "这一层确实存在不可选的节点（否则上面那条断言是空的）")

	# 一路走到终点。
	var steps: int = 0
	while not map.is_finished() and steps < MapModel.TIERS * 2:
		steps += 1
		var options: Array[MapModel.MapNode] = map.selectable()
		if not ctx.check(not options.is_empty(), "第 %d 步还有路可走" % steps):
			return
		ctx.check(map.select(options[0].id), "第 %d 步走得通" % steps)
	ctx.check(map.is_finished(), "沿出边走一定能到终点（%d 步）" % steps)


## 同一 seed 必须得到同一张图 —— 否则「记住下一步去哪」这件事没有意义。
func _check_determinism(ctx: RefCounted) -> void:
	for seed_value: int in SAMPLE_SEEDS:
		var first: MapModel = MapModel.new()
		first.generate(seed_value)
		var second: MapModel = MapModel.new()
		second.generate(seed_value)
		ctx.equal(_fingerprint(first), _fingerprint(second), "seed %d 两次生成完全一致" % seed_value)
	# 反向对照：换一个 seed 必须换一张图，否则上面「一致」可能只是因为图是固定的。
	var one: MapModel = MapModel.new()
	one.generate(4242)
	var other: MapModel = MapModel.new()
	other.generate(987654)
	ctx.check(_fingerprint(one) != _fingerprint(other), "反向对照：不同 seed 生成不同的图")


func _check_kinds(ctx: RefCounted) -> void:
	var map: MapModel = MapModel.new()
	map.generate(31337)
	for node: MapModel.MapNode in map.nodes_in_tier(0):
		ctx.equal(node.kind, MapModel.Kind.BATTLE, "起点层一定是战斗（第一场不能是工坊）")
	for node: MapModel.MapNode in map.nodes_in_tier(MapModel.TIERS - 1):
		ctx.equal(node.kind, MapModel.Kind.BATTLE, "终点层一定是战斗（收尾不能是工坊）")
	var workshops: int = 0
	for node: MapModel.MapNode in map.nodes():
		if node.kind == MapModel.Kind.WORKSHOP:
			workshops += 1
	ctx.check(workshops > 0, "中间层确实会掷出工坊（否则工坊类型是死代码）")
	ctx.check(workshops < map.nodes().size(), "工坊不是全部（否则战斗类型是死代码）")


## 一张图的指纹：节点类型 + 出边。用来比较两张图是不是同一张。
func _fingerprint(map: MapModel) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node: MapModel.MapNode in map.nodes():
		var edges: Array = Array(node.next)
		edges.sort()
		parts.append("%d:%d:%s" % [node.id, node.kind, str(edges)])
	return "|".join(parts)
