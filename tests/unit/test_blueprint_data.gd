## test_blueprint_data.gd
## 职责：BlueprintData 的字段 / 缺省值，以及「落盘 → 重新载入 → 逐字段相等」的真实往返
##       （09_TEST_STANDARD.md §3.2：保存后重载 → 结构完全一致）。
## 所属系统：tests
## 依赖：test_context, scripts/data/blueprint_data.gd, node_data.gd, connection_data.gd
## 禁止：本文件不得写入 res://data/ —— 正式数据目录只读；往返文件一律落 user://（09 §4）。
##       测试产物也不得落进 BlueprintData.DEFAULT_SAVE_DIR：那是玩家正式存档目录，
##       落进去会让将来「列目录取全部蓝图」的功能把测试文件当成真蓝图读出来。

extends RefCounted

## 测试专用的落盘目录，与正式存档目录刻意分开（见文件头「禁止」）。
const TEST_DIR: String = "user://test_blueprints"
## 往返用的两个文件：内容不同，用来证明载回的确实是文件内容而不是恒为空的新对象。
const PATH_A: String = TEST_DIR + "/_roundtrip_a.tres"
const PATH_B: String = TEST_DIR + "/_roundtrip_b.tres"
## 「类型不符」的反向对照：自造的、与正式存档同目录同扩展名、只差类型的 .tres。
## 不用仓库里的现成资产（如 assets/palette.tres）：那是别系统的资产，既引入跨系统依赖，
## 又会经 CACHE_MODE_IGNORE 载入一个本已被 ResourceCache 持有的资源。
const PATH_WRONG_TYPE: String = TEST_DIR + "/_wrong_type.tres"
const MISSING_PATH: String = TEST_DIR + "/_no_such_file.tres"
## 「旧存档」对照用的文件：同一份内容，但把 weapon_kind 那一行删掉 ——
## 那就是该字段存在之前写下的存档长什么样。
const PATH_OLD_SAVE: String = TEST_DIR + "/_old_save.tres"
const WEAPON_KIND_LINE: String = "weapon_kind = "


func run(ctx: RefCounted, tree: SceneTree) -> void:
	_run_default_checks(ctx)
	_run_roundtrip_checks(ctx)
	_run_negative_controls(ctx)
	_run_old_save_checks(ctx)


func _run_default_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintData · 类型与缺省值")
	var blueprint: BlueprintData = BlueprintData.new()
	ctx.check(blueprint is Resource, "BlueprintData 应是 Resource（02 §5：容器用 Resource）")
	ctx.equal(blueprint.nodes.size(), 0, "nodes 缺省应为空")
	ctx.equal(blueprint.connections.size(), 0, "connections 缺省应为空")
	# 01 §7：蓝图是玩家产物，只允许落 user://，不得写 res:// 或项目外的绝对路径。
	ctx.check(BlueprintData.DEFAULT_SAVE_DIR.begins_with("user://"),
		"DEFAULT_SAVE_DIR 应在 user:// 下（实际 '%s'）" % BlueprintData.DEFAULT_SAVE_DIR)

	ctx.begin_case("BlueprintData · 实例独立性")
	var other: BlueprintData = BlueprintData.new()
	blueprint.nodes.append(_make_node(&"solo", NodeData.Kind.CORE, "Solo"))
	ctx.equal(blueprint.nodes.size(), 1, "写入后 blueprint 自身应有 1 个节点")
	# 反向对照：两个实例不得共用同一个内部数组。
	ctx.equal(other.nodes.size(), 0, "改 blueprint 不应影响 other 的 nodes")
	ctx.equal(other.connections.size(), 0, "改 blueprint 不应影响 other 的 connections")


## 09 §3.2 的核心：真的落盘、真的从盘上载回，再逐字段比。
func _run_roundtrip_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintData · 落盘 → 重新载入（09 §3.2）")
	var original: BlueprintData = _build_blueprint()
	if not ctx.check(original.save_to(PATH_A), "save_to 应成功"):
		return

	# 先证明字节真的到了磁盘上，而不是只改了内存对象。
	var raw: String = FileAccess.get_file_as_string(PATH_A)
	ctx.check(raw.length() > 0, "落盘文件不应为空")
	ctx.check(raw.contains("core_a"), "落盘文件应含节点 id core_a")

	var reloaded: BlueprintData = BlueprintData.load_from(PATH_A)
	if not ctx.check(reloaded != null, "load_from 应能取回 BlueprintData"):
		return

	ctx.equal(reloaded.nodes.size(), original.nodes.size(), "节点数应一致")
	ctx.equal(reloaded.connections.size(), original.connections.size(), "连线数应一致")

	var node_count: int = mini(reloaded.nodes.size(), original.nodes.size())
	for index: int in node_count:
		var got: NodeData = reloaded.nodes[index]
		var want: NodeData = original.nodes[index]
		ctx.equal(String(got.id), String(want.id), "节点 %d 的 id" % index)
		ctx.equal(got.display_name, want.display_name, "节点 %d 的 display_name" % index)
		ctx.equal(got.kind, want.kind, "节点 %d 的 kind" % index)
		# weapon_kind 必须真的落盘再载回 —— 它是「拖出去的是针还是锯」的唯一来源，
		# 丢了它，玩家的锯重进场景就会变成针（而这正是本卡要接上的那条路）。
		ctx.equal(got.weapon_kind, want.weapon_kind, "节点 %d 的 weapon_kind" % index)

	var link_count: int = mini(reloaded.connections.size(), original.connections.size())
	for index: int in link_count:
		var got: ConnectionData = reloaded.connections[index]
		var want: ConnectionData = original.connections[index]
		ctx.equal(String(got.from_node_id), String(want.from_node_id), "连线 %d 的 from_node_id" % index)
		ctx.equal(String(got.from_port), String(want.from_port), "连线 %d 的 from_port" % index)
		ctx.equal(String(got.to_node_id), String(want.to_node_id), "连线 %d 的 to_node_id" % index)
		ctx.equal(String(got.to_port), String(want.to_port), "连线 %d 的 to_port" % index)


func _run_negative_controls(ctx: RefCounted) -> void:
	# 反向对照 1：两份**内容不同**的蓝图各落一个文件，载回后必须彼此不同。
	# 若 load_from 实际返回的是「恒为空的新对象」，两者会相等，下面两条断言即转红 ——
	# 这是本用例防止「往返测试空转」的主保险。
	ctx.begin_case("BlueprintData · 反向对照：载回的确为文件内容")
	var solo: BlueprintData = BlueprintData.new()
	solo.nodes.append(_make_node(&"solo", NodeData.Kind.WEAPON, "Solo"))
	ctx.check(solo.save_to(PATH_B), "第二份蓝图应能落盘")

	var loaded_a: BlueprintData = BlueprintData.load_from(PATH_A)
	var loaded_b: BlueprintData = BlueprintData.load_from(PATH_B)
	if ctx.check(loaded_a != null and loaded_b != null, "两份蓝图都应能载回"):
		ctx.not_equal(loaded_a.nodes.size(), loaded_b.nodes.size(), "两份不同蓝图的节点数不应相同")
		# 先确认各自非空再取下标：否则 load_from 一旦坏成「恒返回空对象」，
		# 下一行是越界报错而不是断言转红，看报告的人只会看到崩溃。
		if ctx.check(loaded_a.nodes.size() > 0 and loaded_b.nodes.size() > 0, "两份蓝图都应至少含 1 个节点"):
			ctx.not_equal(String(loaded_a.nodes[0].id), String(loaded_b.nodes[0].id), "两份不同蓝图的首节点 id 不应相同")

	# 反向对照 2：非法输入必须降级为 null，不得崩溃、也不得返回半成品（02 §9）。
	# 下面两条断言会各触发一条 push_error，属 09 §5 明文豁免的「被断言的负路径用例」。
	ctx.begin_case("BlueprintData · 反向对照：非法输入降级")
	# user:// 可写是本组用例的前提（01 §7）。先钉住它，后面转红才可解释。
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(TEST_DIR)
	ctx.check(dir_err == OK or dir_err == ERR_ALREADY_EXISTS, "user:// 测试目录应可创建（错误 %d）" % dir_err)
	ctx.equal(BlueprintData.load_from(MISSING_PATH), null, "文件不存在应返回 null")
	# 「类型不符」：用 NodeData 冒充。必须绕开 BlueprintData.save_to —— 它存出来的一定是
	# BlueprintData，造不出错误类型，故这里直接用 ResourceSaver。
	var wrong: NodeData = NodeData.new()
	wrong.id = &"not_a_blueprint"
	ctx.check(ResourceSaver.save(wrong, PATH_WRONG_TYPE) == OK, "对照用的 NodeData 应能落盘")
	ctx.equal(BlueprintData.load_from(PATH_WRONG_TYPE), null, "类型不符应返回 null")


## 旧存档兼容：本字段存在之前写下的 .tres 里没有 weapon_kind 这一行，
## 载回来必须是 NONE（缺省值）而不是崩溃或半个对象 —— 否则所有老玩家的蓝图一次性报废。
##
## 造「旧存档」的办法是从真实落盘的文件里**删掉那一行**，而不是手写一份 .tres：
## 手写的格式一旦与 ResourceSaver 的实际输出漂开，这条用例证的就是手写文件能读，
## 与「旧存档能读」无关了。
func _run_old_save_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintData · 旧存档（无 weapon_kind 字段）仍能载入")
	var blueprint: BlueprintData = BlueprintData.new()
	blueprint.nodes.append(_make_node(&"weapon_old", NodeData.Kind.WEAPON, "锯", NodeData.WeaponKind.SAW))
	if not ctx.check(blueprint.save_to(PATH_OLD_SAVE), "对照用的蓝图应能落盘"):
		return

	var raw: String = FileAccess.get_file_as_string(PATH_OLD_SAVE)
	if not ctx.check(raw.contains(WEAPON_KIND_LINE),
			"落盘文件应真的含 %s 行（否则下面删的是一个不存在的字段，用例空转）" % WEAPON_KIND_LINE):
		return

	var kept: PackedStringArray = []
	for line: String in raw.split("\n"):
		if line.strip_edges().begins_with(WEAPON_KIND_LINE):
			continue
		kept.append(line)
	var stripped: String = "\n".join(kept)
	ctx.check(not stripped.contains(WEAPON_KIND_LINE), "删掉之后文件里不该再有该字段")
	var file: FileAccess = FileAccess.open(PATH_OLD_SAVE, FileAccess.WRITE)
	if not ctx.check(file != null, "应能重写对照文件"):
		return
	file.store_string(stripped)
	file.close()

	var loaded: BlueprintData = BlueprintData.load_from(PATH_OLD_SAVE)
	if not ctx.check(loaded != null, "缺 weapon_kind 的旧存档应仍能载入（不得崩、不得返回 null）"):
		return
	if not ctx.check(loaded.nodes.size() == 1, "旧存档的节点数应原样载回（实际 %d）" % loaded.nodes.size()):
		return
	var node: NodeData = loaded.nodes[0]
	ctx.equal(node.kind, NodeData.Kind.WEAPON, "旧存档里的武器节点仍是武器")
	ctx.equal(node.weapon_kind, NodeData.WeaponKind.NONE,
		"缺字段的旧存档载回后 weapon_kind 应为 NONE（02 §9 的降级入口）")


func _make_node(id: StringName, kind: NodeData.Kind, display_name: String,
		weapon_kind: NodeData.WeaponKind = NodeData.WeaponKind.NONE) -> NodeData:
	var node: NodeData = NodeData.new()
	node.id = id
	node.kind = kind
	node.display_name = display_name
	node.weapon_kind = weapon_kind
	return node


func _make_connection(
	from_id: StringName, from_port: StringName, to_id: StringName, to_port: StringName
) -> ConnectionData:
	var link: ConnectionData = ConnectionData.new()
	link.from_node_id = from_id
	link.from_port = from_port
	link.to_node_id = to_id
	link.to_port = to_port
	return link


## 两份节点 + 一条连线：覆盖面够，且与 PATH_B 的内容刻意不同。
func _build_blueprint() -> BlueprintData:
	var blueprint: BlueprintData = BlueprintData.new()
	blueprint.nodes.append(_make_node(&"core_a", NodeData.Kind.CORE, "Core A"))
	# 刻意取一个非 NONE 的武器种类：两边都是缺省值的话，往返断言恒真、等于没测。
	blueprint.nodes.append(_make_node(&"weapon_b", NodeData.Kind.WEAPON, "Weapon B", NodeData.WeaponKind.SAW))
	blueprint.connections.append(_make_connection(&"core_a", &"out", &"weapon_b", &"in"))
	return blueprint
