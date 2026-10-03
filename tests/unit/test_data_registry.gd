## test_data_registry.gd
## 职责：DataRegistry 的索引、按 id 取数、空数据与非法输入降级。
## 所属系统：tests
## 依赖：test_context, scripts/core/data_registry.gd, tests/unit/fixtures/data
## 禁止：本文件不得写入 data/ —— 正式数据目录只读；测试数据一律用 fixtures（09 §4）。

extends RefCounted

const REGISTRY_PATH: String = "res://scripts/core/data_registry.gd"
const FIXTURE_ROOT: String = "res://tests/unit/fixtures/data"

## 03 §9 规定的四个数据类别。
const EXPECTED_CATEGORIES: PackedStringArray = ["nodes", "weapons", "enemies", "waves"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	var script: GDScript = load(REGISTRY_PATH)
	if not ctx.check(script != null, "data_registry.gd 应能加载"):
		return
	_run_category_checks(ctx, script)
	_run_empty_data_checks(ctx, tree, script)
	_run_fixture_checks(ctx, tree, script)


func _run_category_checks(ctx: RefCounted, script: GDScript) -> void:
	ctx.begin_case("DataRegistry · 类别定义")
	ctx.equal(script.CATEGORIES.size(), EXPECTED_CATEGORIES.size(), "类别数量")
	for index: int in EXPECTED_CATEGORIES.size():
		ctx.equal(String(script.CATEGORIES[index]), EXPECTED_CATEGORIES[index], "第 %d 个类别名" % index)


## 09 §2「空数据」：正式 data/ 下只有 .gitkeep，必须稳定返回 0 条而不是报错崩溃。
func _run_empty_data_checks(ctx: RefCounted, tree: SceneTree, script: GDScript) -> void:
	ctx.begin_case("DataRegistry · 空数据")
	var registry: Node = _spawn(tree, script)
	registry.call(&"load_all", script.DATA_ROOT)
	ctx.check(bool(registry.call(&"is_loaded")), "加载后 is_loaded 应为 true")
	for category: String in EXPECTED_CATEGORIES:
		ctx.equal(int(registry.call(&"count", StringName(category))), 0, "%s 类别应为空" % category)
		var ids: Array = registry.call(&"list_ids", StringName(category))
		ctx.equal(ids.size(), 0, "%s 类别的 id 列表应为空" % category)

	ctx.begin_case("DataRegistry · 非法输入")
	ctx.equal(registry.call(&"get_data", &"nodes", &"missing"), null, "不存在的 id 应返回 null")
	ctx.equal(registry.call(&"get_data", &"unknown_category", &"x"), null, "未知类别应返回 null")
	ctx.equal(int(registry.call(&"count", &"unknown_category")), 0, "未知类别计数应为 0")
	_release(registry)


## 用 fixtures 覆盖真实的索引路径：正常、重复 id、缺 id、空类别。
func _run_fixture_checks(ctx: RefCounted, tree: SceneTree, script: GDScript) -> void:
	ctx.begin_case("DataRegistry · 索引（fixtures）")
	var registry: Node = _spawn(tree, script)
	registry.call(&"load_all", FIXTURE_ROOT)

	ctx.equal(int(registry.call(&"count", &"nodes")), 2, "nodes 应索引到 2 条（重复 id 与缺 id 各被剔除一条）")
	var ids: Array = registry.call(&"list_ids", &"nodes")
	ctx.equal(ids.size(), 2, "id 数量")
	if ids.size() == 2:
		ctx.equal(String(ids[0]), "alpha", "id 应已排序")
		ctx.equal(String(ids[1]), "beta", "id 应已排序")

	var alpha: Resource = registry.call(&"get_data", &"nodes", &"alpha")
	ctx.check(alpha != null, "应能按 id 取到 alpha")
	if alpha != null:
		ctx.equal(String(alpha.get(&"id")), "alpha", "取回资源的 id")
		ctx.equal(String(alpha.get(&"display_name")), "Fixture Alpha", "取回资源的字段")
	ctx.equal(registry.call(&"get_data", &"nodes", &"beta") != null, true, "应能按 id 取到 beta")

	ctx.equal(int(registry.call(&"count", &"weapons")), 0, "空类别应为 0")
	ctx.equal(int(registry.call(&"count", &"waves")), 0, "不存在的类别目录应为 0")

	# 重复调用必须可重入且结果一致。
	registry.call(&"load_all", FIXTURE_ROOT)
	ctx.equal(int(registry.call(&"count", &"nodes")), 2, "重复加载后计数应一致")
	_release(registry)


func _spawn(tree: SceneTree, script: GDScript) -> Node:
	var node: Node = script.new()
	node.name = "DataRegistryUnderTest"
	tree.root.add_child(node)
	return node


func _release(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
