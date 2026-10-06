## test_node_data.gd
## 职责：蓝图数据模型 NodeData / ConnectionData 的字段、缺省值与实例独立性（03 §4.1 / §4.2）。
## 所属系统：tests
## 依赖：test_context, scripts/data/node_data.gd, scripts/data/connection_data.gd
## 禁止：本文件不得写入 data/ —— 正式数据目录只读，本用例全程在内存中构造（09 §4）。

extends RefCounted

## 03 §4.1 的三类节点，顺序即枚举值顺序。PET-82 起用用户 2026-10-06 直接给的名字
## （核心卡 / 功能卡 / 能力卡），**只改成员名，取值一个没动** —— 它们是 .tres 里落盘的整数。
const EXPECTED_KINDS: PackedStringArray = ["CORE", "FUNCTION", "ABILITY"]
## 功能卡的八类（用户 2026-10-06 给的），顺序即枚举值顺序。
## **前四个必须原地不动**：旧存档里 `SPLIT=1` / `AMPLIFY=2` / `DELAY=3` 落的就是这三个整数。
const EXPECTED_FUNCTIONS: PackedStringArray = ["NONE", "BULLET_COUNT", "ENCHANT", "COOLDOWN",
	"HASTE", "SLOW", "BURST", "LOOP", "ATTACK_SPEED"]
## 能力卡的九系元素（用户 2026-10-06 给的），顺序即枚举值顺序。
## NONE 是缺省值兼旧存档的落点，排第一。
const EXPECTED_ABILITIES: PackedStringArray = ["NONE", "METAL", "WOOD", "WATER", "FIRE",
	"EARTH", "THUNDER", "WIND", "POISON", "ICE"]


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

	# 反向对照：缺省 kind 必须是语义中立的那一类，不得被误当成核心卡或伤害出口。
	ctx.equal(node.kind, NodeData.Kind.FUNCTION, "kind 缺省应为 FUNCTION（功能卡）")
	ctx.not_equal(node.kind, NodeData.Kind.CORE, "kind 缺省不得是 CORE")
	ctx.not_equal(node.kind, NodeData.Kind.ABILITY, "kind 缺省不得是 ABILITY")

	ctx.begin_case("NodeData · Kind 枚举")
	ctx.equal(NodeData.Kind.size(), EXPECTED_KINDS.size(), "Kind 成员数应与 03 §4.1 的三类一致")
	for index: int in EXPECTED_KINDS.size():
		ctx.check(NodeData.Kind.has(EXPECTED_KINDS[index]), "Kind 应含成员 %s" % EXPECTED_KINDS[index])
	ctx.equal(int(NodeData.Kind.CORE), 0, "CORE 的枚举值")
	ctx.equal(int(NodeData.Kind.FUNCTION), 1, "FUNCTION 的枚举值")
	ctx.equal(int(NodeData.Kind.ABILITY), 2, "ABILITY 的枚举值")
	# 反向对照：三个值两两不同，否则 .tres 落盘后无法区分节点类型。
	ctx.not_equal(NodeData.Kind.CORE, NodeData.Kind.FUNCTION, "CORE 与 FUNCTION 不得同值")
	ctx.not_equal(NodeData.Kind.FUNCTION, NodeData.Kind.ABILITY, "FUNCTION 与 ABILITY 不得同值")
	ctx.not_equal(NodeData.Kind.CORE, NodeData.Kind.ABILITY, "CORE 与 ABILITY 不得同值")

	# function_kind 的缺省值是 NONE，且**前四个取值一个都不许动** ——
	# 旧存档（写在该字段改名之前）里 1/2/3 落的就是子弹数量 / 附魔 / 冷却。
	ctx.begin_case("NodeData · function_kind 与缺省值")
	ctx.equal(node.function_kind, NodeData.Function.NONE, "function_kind 缺省应为 NONE")
	ctx.equal(NodeData.Function.size(), EXPECTED_FUNCTIONS.size(),
		"Function 成员数应覆盖用户给的八类 + NONE")
	for index: int in EXPECTED_FUNCTIONS.size():
		ctx.check(NodeData.Function.has(EXPECTED_FUNCTIONS[index]),
			"Function 应含成员 %s" % EXPECTED_FUNCTIONS[index])
	# 顺序即整数落盘值：重排会让玩家存下来的功能卡静默变成另一种功能（同 Kind 的理由）。
	ctx.equal(int(NodeData.Function.NONE), 0, "NONE 的枚举值（缺省值兼旧存档落点，必须排第一）")
	ctx.equal(int(NodeData.Function.BULLET_COUNT), 1, "BULLET_COUNT 的枚举值（旧 SPLIT）")
	ctx.equal(int(NodeData.Function.ENCHANT), 2, "ENCHANT 的枚举值（旧 AMPLIFY）")
	ctx.equal(int(NodeData.Function.COOLDOWN), 3, "COOLDOWN 的枚举值（旧 DELAY）")

	# weapon_kind 的缺省值是 NONE，且**非能力卡节点不得带能力卡元素** ——
	# NONE 正是旧存档（写于该字段存在之前）载回后的取值，也是 AbilityData 的降级入口。
	ctx.begin_case("NodeData · weapon_kind 与缺省值")
	ctx.equal(node.weapon_kind, NodeData.Ability.NONE, "weapon_kind 缺省应为 NONE")
	ctx.equal(NodeData.Ability.size(), EXPECTED_ABILITIES.size(),
		"Ability 成员数应覆盖用户给的九系 + NONE")
	for index: int in EXPECTED_ABILITIES.size():
		ctx.check(NodeData.Ability.has(EXPECTED_ABILITIES[index]),
			"Ability 应含成员 %s" % EXPECTED_ABILITIES[index])
	# 顺序即整数落盘值：重排会静默改变既有存档的语义（同 Kind 的理由）。
	ctx.equal(int(NodeData.Ability.NONE), 0, "NONE 的枚举值（缺省值兼降级入口，必须排第一）")
	ctx.equal(int(NodeData.Ability.METAL), 1, "METAL 的枚举值")
	ctx.equal(int(NodeData.Ability.FIRE), 4, "FIRE 的枚举值")
	ctx.equal(int(NodeData.Ability.ICE), 9, "ICE 的枚举值")

	ctx.begin_case("NodeData · 实例独立性")
	var first: NodeData = NodeData.new()
	var second: NodeData = NodeData.new()
	first.id = &"alpha"
	first.kind = NodeData.Kind.CORE
	first.weapon_kind = NodeData.Ability.THUNDER
	ctx.equal(String(first.id), "alpha", "first 的 id 应已写入")
	ctx.equal(String(second.id), "", "改 first 不应影响 second 的 id")
	ctx.equal(second.kind, NodeData.Kind.FUNCTION, "改 first 不应影响 second 的 kind")
	ctx.equal(second.weapon_kind, NodeData.Ability.NONE, "改 first 不应影响 second 的 weapon_kind")


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
