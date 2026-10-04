## test_node_data.gd
## 职责：蓝图数据模型 NodeData / ConnectionData 的字段、缺省值与实例独立性（03 §4.1 / §4.2）。
## 所属系统：tests
## 依赖：test_context, scripts/data/node_data.gd, scripts/data/connection_data.gd
## 禁止：本文件不得写入 data/ —— 正式数据目录只读，本用例全程在内存中构造（09 §4）。

extends RefCounted

## 03 §4.1 的三类节点，顺序即枚举值顺序。
const EXPECTED_KINDS: PackedStringArray = ["CORE", "FUNCTION", "WEAPON"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	_run_node_checks(ctx)
	_run_connection_checks(ctx)


func _run_node_checks(ctx: RefCounted) -> void:
	ctx.begin_case("NodeData · 类型与缺省值")
	# 用全局类名而非 load() 取类：09 §4 要求新增 class_name 后先 --import，
	# 这里的类型标注本身就是对该缓存的检查（缓存过期会直接编译失败并在报告里点名）。
	var node: NodeData = NodeData.new()
	ctx.check(node is Resource, "NodeData 应是 Resource 子类（02 §5：跨系统数据用 Resource）")
	ctx.equal(String(node.id), "", "id 缺省应为空")
	ctx.equal(node.display_name, "", "display_name 缺省应为空")

	# 反向对照：缺省 kind 必须是语义中立的那一类，不得被误当成能量源或伤害出口。
	ctx.equal(node.kind, NodeData.Kind.FUNCTION, "kind 缺省应为 FUNCTION")
	ctx.not_equal(node.kind, NodeData.Kind.CORE, "kind 缺省不得是 CORE")
	ctx.not_equal(node.kind, NodeData.Kind.WEAPON, "kind 缺省不得是 WEAPON")

	ctx.begin_case("NodeData · Kind 枚举")
	ctx.equal(NodeData.Kind.size(), EXPECTED_KINDS.size(), "Kind 成员数应与 03 §4.1 的三类一致")
	for index: int in EXPECTED_KINDS.size():
		ctx.check(NodeData.Kind.has(EXPECTED_KINDS[index]), "Kind 应含成员 %s" % EXPECTED_KINDS[index])
	ctx.equal(int(NodeData.Kind.CORE), 0, "CORE 的枚举值")
	ctx.equal(int(NodeData.Kind.FUNCTION), 1, "FUNCTION 的枚举值")
	ctx.equal(int(NodeData.Kind.WEAPON), 2, "WEAPON 的枚举值")
	# 反向对照：三个值两两不同，否则 .tres 落盘后无法区分节点类型。
	ctx.not_equal(NodeData.Kind.CORE, NodeData.Kind.FUNCTION, "CORE 与 FUNCTION 不得同值")
	ctx.not_equal(NodeData.Kind.FUNCTION, NodeData.Kind.WEAPON, "FUNCTION 与 WEAPON 不得同值")
	ctx.not_equal(NodeData.Kind.CORE, NodeData.Kind.WEAPON, "CORE 与 WEAPON 不得同值")

	ctx.begin_case("NodeData · 实例独立性")
	var first: NodeData = NodeData.new()
	var second: NodeData = NodeData.new()
	first.id = &"alpha"
	first.kind = NodeData.Kind.CORE
	ctx.equal(String(first.id), "alpha", "first 的 id 应已写入")
	ctx.equal(String(second.id), "", "改 first 不应影响 second 的 id")
	ctx.equal(second.kind, NodeData.Kind.FUNCTION, "改 first 不应影响 second 的 kind")


func _run_connection_checks(ctx: RefCounted) -> void:
	ctx.begin_case("ConnectionData · 类型与缺省值")
	var link: ConnectionData = ConnectionData.new()
	ctx.check(link is Resource, "ConnectionData 应是 Resource 子类（02 §5）")
	ctx.equal(String(link.from_node_id), "", "from_node_id 缺省应为空")
	ctx.equal(String(link.from_port), "", "from_port 缺省应为空")
	ctx.equal(String(link.to_node_id), "", "to_node_id 缺省应为空")
	ctx.equal(String(link.to_port), "", "to_port 缺省应为空")

	ctx.begin_case("ConnectionData · 有向边字段")
	link.from_node_id = &"core_a"
	link.from_port = &"out"
	link.to_node_id = &"func_b"
	link.to_port = &"in"
	ctx.equal(String(link.from_node_id), "core_a", "from_node_id")
	ctx.equal(String(link.from_port), "out", "from_port")
	ctx.equal(String(link.to_node_id), "func_b", "to_node_id")
	ctx.equal(String(link.to_port), "in", "to_port")
	# 反向对照：from / to 必须是两组独立字段，写一侧不得顺带改另一侧 —— 否则
	# 「有向边」（03 §4.2）会退化成无向边。
	ctx.not_equal(String(link.from_node_id), String(link.to_node_id), "from_node_id 与 to_node_id 不得互为别名")
	ctx.not_equal(String(link.from_port), String(link.to_port), "from_port 与 to_port 不得互为别名")

	ctx.begin_case("ConnectionData · 实例独立性")
	var other: ConnectionData = ConnectionData.new()
	ctx.equal(String(other.from_node_id), "", "改 link 不应影响 other 的 from_node_id")
	ctx.equal(String(other.to_port), "", "改 link 不应影响 other 的 to_port")
