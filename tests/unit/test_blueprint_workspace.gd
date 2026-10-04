## test_blueprint_workspace.gd
## 职责：blueprint_workspace.gd 的**纯逻辑**与静态装配 —— 仓库清单、槽位退让、网格吸附、
##       连线的数据完整性、落盘往返，以及「拖放不碰原始输入事件」这条纪律。
## 所属系统：tests
## 依赖：test_context, scripts/ui/blueprint_workspace.gd, scripts/data/{node_data,blueprint_data}.gd, palette.gd
## 禁止：本文件不得写入 res://data/，也不得落进 BlueprintData.DEFAULT_SAVE_DIR
##       （同 test_blueprint_data.gd：正式存档目录只归玩家的游戏写，测试产物一律 user://test_blueprints）；
##       不得入树 —— 入树会跑 _ready()，而本文件要证的恰恰是「不入树也算得对」。
##       真实拖放、真实渲染与截图归 tests/integration/blueprint_smoke.gd**独立进程**。
##
## 为什么能不入树：工作区把图模型建在声明处之外的可重入入口 reload() 上，
## 且槽位 / 吸附 / 落格全部**按 size 现算不缓存**，因此给一个 size 就能验全部几何。

extends RefCounted

const WORKSPACE_SCRIPT_PATH: String = "res://scripts/ui/blueprint_workspace.gd"
const PREP_SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const NODE_DATA_PATH: String = "res://scripts/data/node_data.gd"
const BLUEPRINT_DATA_PATH: String = "res://scripts/data/blueprint_data.gd"

## 测试专用落盘目录，与正式存档目录刻意分开（同 test_blueprint_data.gd 的理由）。
const SAVE_DIR: String = "user://test_blueprints"
const SAVE_PATH: String = SAVE_DIR + "/_workspace_01.tres"

## 06 §4 的节点卡记法，在本文件**独立复写一遍**。刻意不从 blueprint_workspace.gd 取：
## 测试若与被测实现同源，实现里把 28 写成 26 时两边一起错，断言就永远是绿的。
const GRID: float = 24.0
const CARD: float = 24.0
const MARKER: float = 4.0
const PORT: float = 3.0
const SLOT_PITCH: float = 28.0
const DRAG_ALPHA: float = 0.7
const LABEL_FONT_SIZE: int = 8

## 06 §7 分区内缩 2px 后的真实可用区（RegionCenter 128×124、RegionBottom 294×48 减掉 CTA）。
const CANVAS_SIZE: Vector2 = Vector2(124.0, 120.0)
const WAREHOUSE_SIZE: Vector2 = Vector2(227.0, 44.0)
## 窄屏（06 §7.1）底条减掉 44px 的 CTA 后只剩这一段。
const WAREHOUSE_NARROW_SIZE: Vector2 = Vector2(124.0, 44.0)

## 03 §2 / 06 §10.1 R1：不得存在任何会自动推进的构造。
const BANNED_TIMING_TOKENS: PackedStringArray = [
	"Timer", "create_timer", "_process", "_physics_process", "timeout", "wait_time", "autostart",
]

## 03 §8：原始输入事件类型只在 input_normalizer.gd 里翻译。拖放走原生虚拟方法
## （_get_drag_data / _can_drop_data / _drop_data 都不接 InputEvent），故本文件一个都不该出现；
## 一旦有人改成自己读事件，下面这条会立刻转红。
const BANNED_EVENT_TOKENS: PackedStringArray = [
	"InputEventMouseButton", "InputEventMouseMotion", "InputEventScreenTouch",
	"InputEventScreenDrag", "InputEventKey", "func _input(", "func _gui_input(",
]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_cleanup()
	_run_source_checks(ctx)
	_run_constant_checks(ctx)
	_run_warehouse_checks(ctx)
	_run_slot_layout_checks(ctx)
	_run_snapping_checks(ctx)
	_run_graph_checks(ctx)
	_run_persistence_checks(ctx)
	_run_scene_assembly_checks(ctx)
	# 必须排在 _run_persistence_checks 之后：它会清掉 SAVE_PATH，而那个文件是上一条用例的物证。
	_run_weapon_kind_checks(ctx)


## 04 §6 / 06 §10.7 / 03 §2 / 03 §8 的静态纪律。顺带钉一条编译检查：
## 脚本编译失败时 .tscn 仍能实例化出节点，结构断言会一片全绿而游戏里跑的是空脚本。
func _run_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 静态纪律（06 §10.7 / 03 §2 / 03 §8）")
	var source: String = FileAccess.get_file_as_string(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(not source.is_empty(), "%s 应能读取" % WORKSPACE_SCRIPT_PATH):
		return
	ctx.check(not source.contains("Color("), "不得出现 Color(...) 字面量（色值只能来自 Palette）")
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return
	# 编译失败时 can_instantiate() 为假且上面已 return，故下面的扫描跑的一定是能编译的代码。
	var code: String = _strip_comments(source)
	for token: String in BANNED_TIMING_TOKENS:
		ctx.check(not code.contains(token), "代码中不得出现 `%s`（不得有自动推进的构造）" % token)
	for token: String in BANNED_EVENT_TOKENS:
		ctx.check(not code.contains(token), "代码中不得出现 `%s`（原始输入事件只在 InputNormalizer 翻译）" % token)
	# 反向核对：拖放必须靠原生虚拟方法，而不是别的机制。
	for method: StringName in [&"_get_drag_data", &"_can_drop_data", &"_drop_data"]:
		ctx.check(_script_has_method(script, method),
			"应有 %s（原生 drag-and-drop 的三个虚拟方法）" % method)


## GDScript 上的 has_method 要实例才准（脚本对象本身不算），这里建一个临时实例问它。
func _script_has_method(script: GDScript, method: StringName) -> bool:
	var probe: Control = script.new()
	if probe == null:
		return false
	var found: bool = probe.has_method(method)
	probe.free()
	return found


## 06 §4 的常量与类型标识配色。配色对齐 06 §4 的三条：CORE=GOLD_400 / FUNCTION=BLUE_400 / WEAPON=ORANGE_500。
func _run_constant_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 06 §4 的卡片记法")
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return
	ctx.equal(script.GRID, GRID, "网格步长")
	ctx.equal(script.CARD, CARD, "卡片边长")
	ctx.equal(script.MARKER, MARKER, "类型标识边长")
	ctx.equal(script.PORT, PORT, "端口标记边长")
	ctx.equal(script.SLOT_PITCH_MAX, SLOT_PITCH, "仓库槽位间距上限")
	ctx.equal(script.DRAG_ALPHA, DRAG_ALPHA, "拖动预览的不透明度")
	ctx.equal(script.LABEL_FONT_SIZE, LABEL_FONT_SIZE, "仓库名称字号（06 §1 的正文字号下限）")

	# 01 §7：蓝图只允许落 user://。默认路径必须从 BlueprintData 登记的用户目录派生，
	# 不在这里另抄一份 —— 抄一份就会在目录改名时静默分叉。
	# 这一问要用**没被动过**的实例：_workspace() 会把路径改到测试目录，拿它问等于问自己。
	var probe: Control = script.new()
	if ctx.check(probe != null, "blueprint_workspace.gd 应能实例化"):
		var path: String = String(probe.get(&"blueprint_path"))
		ctx.check(path.begins_with(BlueprintData.DEFAULT_SAVE_DIR + "/"),
			"默认存档路径应在 BlueprintData.DEFAULT_SAVE_DIR 下（实际 '%s'）" % path)
		probe.free()

	var ws: Control = _workspace(ctx, script.Area.CANVAS, CANVAS_SIZE)
	if ws == null:
		return
	var kinds: GDScript = load(NODE_DATA_PATH)
	var expected := {
		kinds.Kind.CORE: Palette.Key.GOLD_400,
		kinds.Kind.FUNCTION: Palette.Key.BLUE_400,
		kinds.Kind.WEAPON: Palette.Key.ORANGE_500,
	}
	for kind: int in expected:
		ctx.equal(ws.call(&"_kind_color", kind), Palette.get_color(expected[kind]),
			"%s 的类型标识色（06 §4）" % kinds.Kind.find_key(kind))
	ws.free()


## 本卡范围：1×CORE + 3×FUNCTION + 3×WEAPON，且按管线顺序排（玩家从左往右读）。
func _run_warehouse_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 节点仓库清单（本卡范围 1+3+3）")
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return
	var kinds: GDScript = load(NODE_DATA_PATH)
	var list: Array = script.WAREHOUSE
	ctx.equal(list.size(), 7, "仓库槽位数")

	var counts: Dictionary = {}
	var names: Dictionary = {}
	for index: int in list.size():
		var entry: Dictionary = list[index]
		var kind: int = int(entry["kind"])
		var name: String = String(entry["name"])
		counts[kind] = int(counts.get(kind, 0)) + 1
		ctx.check(not name.is_empty(), "槽位 %d 应有名称" % index)
		ctx.check(not names.has(name), "槽位名称不得重复（重复则玩家分不清两件同名节点）：'%s'" % name)
		names[name] = true
		ctx.check(kind in [kinds.Kind.CORE, kinds.Kind.FUNCTION, kinds.Kind.WEAPON],
			"槽位 %d 的类型应是三种之一" % index)

	ctx.equal(int(counts.get(kinds.Kind.CORE, 0)), 1, "CORE 数量")
	ctx.equal(int(counts.get(kinds.Kind.FUNCTION, 0)), 3, "FUNCTION 数量")
	ctx.equal(int(counts.get(kinds.Kind.WEAPON, 0)), 3, "WEAPON 数量")
	# 顺序即槽位顺序，也即玩家拖出的顺序：核心在最左，武器在最右。
	ctx.equal(int(list[0]["kind"]), kinds.Kind.CORE, "槽位 0 应是 CORE")
	ctx.equal(int(list[list.size() - 1]["kind"]), kinds.Kind.WEAPON, "最后一个槽位应是 WEAPON")

	# weapon_kind 列：三张武器槽在卡片上长得一模一样（类型标识只按 Kind 分三色），
	# 「拖出去的是针还是锯」全靠这一列。它是这条信息的**唯一来源** ——
	# 从前那条「拿中文显示名反查武器」的桥已删，这里空了就等于玩家的武器全部落到降级分支。
	_check_warehouse_weapon_column(ctx, kinds, list, counts)


## 武器槽位必须给出三把**互不相同**的武器种类，非武器槽位必须一律 NONE。
## 反向对照齐备：种类写成同一个 → 三把武器退化成同一把；给非武器槽位也写上种类 →
## 「这是不是武器」有两个互相矛盾的答案。
func _check_warehouse_weapon_column(ctx: RefCounted, kinds: GDScript, list: Array,
		counts: Dictionary) -> void:
	var seen: Dictionary = {}
	for index: int in list.size():
		var entry: Dictionary = list[index]
		var kind: int = int(entry["kind"])
		var weapon_kind: int = int(entry["weapon_kind"])
		if kind == kinds.Kind.WEAPON:
			ctx.check(weapon_kind != kinds.WeaponKind.NONE,
				"武器槽位 %d（%s）必须写明武器种类，不得留 NONE" % [index, entry["name"]])
			ctx.check(int(weapon_kind) in [kinds.WeaponKind.NEEDLE, kinds.WeaponKind.BOMB,
					kinds.WeaponKind.SAW],
				"武器槽位 %d 的种类应是三把武器之一（实际 %d）" % [index, weapon_kind])
			ctx.check(not seen.has(weapon_kind),
				"两个武器槽位不得是同一把武器（重复的种类 %d）" % weapon_kind)
			seen[weapon_kind] = String(entry["name"])
		else:
			ctx.equal(weapon_kind, kinds.WeaponKind.NONE,
				"槽位 %d（%s）不是武器，weapon_kind 必须留 NONE" % [index, entry["name"]])
	ctx.equal(seen.size(), int(counts.get(kinds.Kind.WEAPON, 0)),
		"三张武器槽应恰好覆盖三把各不相同的武器")


## 06 §4 的 28px 间距优先；装不下时退到「不重叠的最小间距 + 少放几个」。
## 底条在窄屏（06 §7.1）被 CTA 占去 44px，7 个槽位几何上放不下 —— 退让规则是这里的主断言。
func _run_slot_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 槽位布局（06 §4 间距 / 窄屏退让）")
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return

	var wide: Control = _workspace(ctx, script.Area.WAREHOUSE, WAREHOUSE_SIZE)
	if wide == null:
		return
	var layout: Dictionary = wide.call(&"_slot_layout")
	ctx.equal(int(layout["shown"]), 7, "宽屏底条应放得下全部 7 个槽位")
	ctx.equal(float(layout["pitch"]), SLOT_PITCH, "间距应取 06 §4 的 28px")
	_check_slots(ctx, wide, 7, float(layout["pitch"]), WAREHOUSE_SIZE.x, "宽屏")
	wide.free()

	var narrow: Control = _workspace(ctx, script.Area.WAREHOUSE, WAREHOUSE_NARROW_SIZE)
	if narrow == null:
		return
	var tight: Dictionary = narrow.call(&"_slot_layout")
	var shown: int = int(tight["shown"])
	var pitch: float = float(tight["pitch"])
	ctx.check(shown < 7, "窄屏放不下 7 个槽位时应少放（实际放 %d 个）" % shown)
	ctx.check(shown >= 1, "至少要放得下 1 个槽位（实际 %d 个）" % shown)
	ctx.check(pitch >= CARD + 1.0, "退让后的间距不得小于 %.0f，否则卡片会叠在一起（实际 %.1f）" % [CARD + 1.0, pitch])
	# 这两个合起来才是「放得下几个就放几个」：最后一个还塞得进，再添一个就塞不进。
	ctx.check(float(shown - 1) * pitch + CARD <= WAREHOUSE_NARROW_SIZE.x + 0.01,
		"放下的最后一个槽位应仍在可用宽度内")
	ctx.check(float(shown) * pitch + CARD > WAREHOUSE_NARROW_SIZE.x,
		"再添一个槽位就该超出可用宽度（否则是放少了，不是放不下）")
	_check_slots(ctx, narrow, shown, pitch, WAREHOUSE_NARROW_SIZE.x, "窄屏")
	narrow.free()


## 06 §4 / 06 §1：每个槽位都得是完整的 24×24（24 逻辑像素 = 2× 下 48 设备像素），不得越界、不得重叠。
func _check_slots(ctx: RefCounted, ws: Control, shown: int, pitch: float, width: float, label: String) -> void:
	var previous: Rect2 = Rect2()
	for index: int in shown:
		var rect: Rect2 = ws.call(&"_slot_rect", index)
		ctx.equal(rect.size, Vector2(CARD, CARD), "%s：槽位 %d 应是完整的 24×24 命中区" % [label, index])
		ctx.check(rect.position.x >= 0.0 and rect.end.x <= width + 0.01,
			"%s：槽位 %d 不得越出可用宽度（%s）" % [label, index, rect])
		ctx.check(rect.position.y >= 0.0 and rect.end.y <= WAREHOUSE_SIZE.y,
			"%s：槽位 %d 不得越出底条高度（%s）" % [label, index, rect])
		if index > 0:
			ctx.check(rect.position.x >= previous.end.x, "%s：槽位 %d 不得与上一个重叠" % [label, index])
		previous = rect


## 06 §4：落点吸附到 24px 网格，且卡片不得被拖出画布可视区。
func _run_snapping_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 网格吸附（06 §4）")
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return
	var ws: Control = _workspace(ctx, script.Area.CANVAS, CANVAS_SIZE)
	if ws == null:
		return

	# 画布内、画布外、负坐标、远超出 —— 四种落点都要收敛到同一个合法域。
	var drops: Array[Vector2] = [
		Vector2(12.0, 24.0), Vector2(50.0, 50.0), Vector2(60.0, 60.0),
		Vector2(123.0, 119.0), Vector2(-40.0, -40.0), Vector2(999.0, 999.0),
	]
	for at: Vector2 in drops:
		var rect: Rect2 = ws.call(&"_snapped", at)
		ctx.equal(rect.size, Vector2(CARD, CARD), "落点 %s 的卡片尺寸" % at)
		ctx.check(_is_on_grid(rect.position), "落点 %s 的卡片左上角应吸附到 24px 网格（实际 %s）" % [at, rect.position])
		ctx.check(rect.position.x >= 0.0 and rect.position.y >= 0.0,
			"落点 %s 不得越出画布左 / 上缘（实际 %s）" % [at, rect.position])
		ctx.check(rect.end.x <= CANVAS_SIZE.x + 0.01 and rect.end.y <= CANVAS_SIZE.y + 0.01,
			"落点 %s 不得越出画布右 / 下缘（实际 %s）" % [at, rect])
	# 画布内的落点即卡片中心（06 §4）：卡片必须盖住落点本身。
	var centered: Rect2 = ws.call(&"_snapped", Vector2(60.0, 60.0))
	ctx.check(centered.has_point(Vector2(60.0, 60.0)), "画布内的落点应落在卡片内（卡片以落点为中心）")
	# 两个具体值把吸附规则钉死：落点正好在格子中心时卡片与它**精确**同心；
	# 落点在格子边界（24 的奇数倍半格）时按四舍五入（Godot 的 snapped 是 half-away-from-zero）
	# 落到相邻格，故卡片可能与落点最多偏半格 —— 这是网格吸附的固有代价，不是 bug。
	ctx.equal(centered, Rect2(Vector2(48.0, 48.0), Vector2(CARD, CARD)), "落点 (60,60) 的卡片应精确以它为中心")
	ctx.equal(ws.call(&"_snapped", Vector2(48.0, 48.0)), Rect2(Vector2(48.0, 48.0), Vector2(CARD, CARD)),
		"落点 (48,48) 的卡片应吸附到最近的格子（36 → 48）")
	ws.free()


## 06 §4.2：连线是「输出端口 → 输入端口」的有向边。
## 本卡不做类型校验与环路检测（S2-06），但自环与重复边要挡掉 —— 那是数据完整性，不是校验。
func _run_graph_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 落节点（id / 类型 / 落格）")
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return
	var kinds: GDScript = load(NODE_DATA_PATH)
	var ws: Control = _workspace(ctx, script.Area.CANVAS, CANVAS_SIZE)
	if ws == null:
		return

	ws.call(&"_add_node", kinds.Kind.CORE, "核心", Vector2(48.0, 48.0))
	ws.call(&"_add_node", kinds.Kind.FUNCTION, "分流", Vector2(72.0, 72.0))
	var blueprint: BlueprintData = ws.call(&"blueprint")
	ctx.equal(blueprint.nodes.size(), 2, "落两个节点后蓝图应有 2 个节点")

	var core: NodeData = blueprint.nodes[0]
	var split: NodeData = blueprint.nodes[1]
	ctx.equal(core.kind, kinds.Kind.CORE, "第一个节点的类型")
	ctx.equal(core.display_name, "核心", "第一个节点的显示名")
	ctx.equal(split.kind, kinds.Kind.FUNCTION, "第二个节点的类型")
	ctx.check(not String(core.id).is_empty() and not String(split.id).is_empty(), "节点都应有 id")
	ctx.not_equal(String(core.id), String(split.id), "两个节点的 id 不得相同")
	ctx.check(String(core.id).begins_with("core"), "id 前缀应体现类型（实际 '%s'）" % core.id)
	ctx.check(String(split.id).begins_with("function"), "id 前缀应体现类型（实际 '%s'）" % split.id)

	var boxes: Dictionary = ws.get(&"_boxes")
	ctx.equal(boxes.size(), 2, "每个节点都应有一个落位矩形")
	for node: NodeData in blueprint.nodes:
		if not ctx.check(boxes.has(node.id), "节点 %s 应有落位矩形" % node.id):
			continue
		var rect: Rect2 = boxes[node.id]
		ctx.equal(rect.size, Vector2(CARD, CARD), "节点 %s 的卡片尺寸" % node.id)
		ctx.check(_is_on_grid(rect.position), "节点 %s 应落在网格上（实际 %s）" % [node.id, rect.position])
		ctx.equal(String(ws.call(&"_card_at", rect.get_center())), String(node.id),
			"卡片中心应命中该节点自己")

	ctx.begin_case("BlueprintWorkspace · 连线（06 §4.2：输出 → 输入）")
	ctx.check(bool(ws.call(&"_connect", core.id, split.id)), "两个不同节点之间应能连一条边")
	ctx.equal(blueprint.connections.size(), 1, "连线数")
	var link: ConnectionData = blueprint.connections[0]
	ctx.equal(String(link.from_node_id), String(core.id), "起点应是 CORE")
	ctx.equal(String(link.from_port), "out", "起点端口应是输出")
	ctx.equal(String(link.to_node_id), String(split.id), "终点应是 FUNCTION")
	ctx.equal(String(link.to_port), "in", "终点端口应是输入")

	# 数据完整性：重复边与自环都不得进图（两条都不是「校验」，见 _connect 的说明）。
	ctx.check(not bool(ws.call(&"_connect", core.id, split.id)), "同向重复边应被挡掉")
	ctx.equal(blueprint.connections.size(), 1, "挡掉重复边后连线数不应变化")
	ctx.check(not bool(ws.call(&"_connect", core.id, core.id)), "自环应被挡掉")
	ctx.equal(blueprint.connections.size(), 1, "挡掉自环后连线数不应变化")
	ctx.check(not bool(ws.call(&"_connect", &"", split.id)), "空起点应被挡掉")
	ctx.check(not bool(ws.call(&"_connect", core.id, &"")), "空终点应被挡掉")
	ctx.equal(blueprint.connections.size(), 1, "非法输入不得改动连线数")

	# 反向边本卡必须放行 —— 环路检测属 S2-06，这里挡掉就等于提前实现了校验。
	ctx.check(bool(ws.call(&"_connect", split.id, core.id)), "反向边本卡应放行（环路检测属 S2-06）")
	ctx.equal(blueprint.connections.size(), 2, "反向边应被记下")
	ws.free()


## 09 §3.2：改动即落盘，另起一个实例能载回同一份图；载回后继续加节点不得撞 id。
func _run_persistence_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 存 / 读往返（09 §3.2）")
	ctx.check(FileAccess.file_exists(SAVE_PATH), "每次改动后都应已落盘（%s）" % SAVE_PATH)
	var raw: String = FileAccess.get_file_as_string(SAVE_PATH)
	ctx.check(raw.length() > 0, "落盘文件不应为空")

	var blueprint_script: GDScript = load(BLUEPRINT_DATA_PATH)
	var loaded: BlueprintData = blueprint_script.load_from(SAVE_PATH)
	if not ctx.check(loaded != null, "load_from 应能取回蓝图"):
		return
	ctx.equal(loaded.nodes.size(), 2, "载回的节点数应与落盘前一致")
	ctx.equal(loaded.connections.size(), 2, "载回的连线数应与落盘前一致")

	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return
	var kinds: GDScript = load(NODE_DATA_PATH)
	# 另起一个实例：它的 reload() 会自己读同一个路径 —— 证明工作区读的确实是这份文件。
	var ws: Control = _workspace(ctx, script.Area.CANVAS, CANVAS_SIZE)
	if ws == null:
		return
	var blueprint: BlueprintData = ws.call(&"blueprint")
	ctx.equal(blueprint.nodes.size(), 2, "新工作区应载回同一份蓝图")
	ctx.equal(blueprint.connections.size(), 2, "新工作区应载回同两条连线")
	var boxes: Dictionary = ws.get(&"_boxes")
	ctx.equal(boxes.size(), 2, "载回的节点应重新落格（位置不进 NodeData，载回后按序落格）")

	# 载回后自增序号必须从既有节点数续起，否则新节点会与存档里的旧 id 撞车 ——
	# 撞车的后果是 _boxes 这个以 id 为键的字典把旧节点顶掉，图与画面对不上。
	ws.call(&"_add_node", kinds.Kind.WEAPON, "针", Vector2(60.0, 60.0),
		kinds.Function.NONE, kinds.WeaponKind.NEEDLE)
	var seen: Dictionary = {}
	for node: NodeData in blueprint.nodes:
		ctx.check(not seen.has(String(node.id)), "载回后新增节点的 id 不得与既有 id 重复（'%s'）" % node.id)
		seen[String(node.id)] = true
	ctx.equal(blueprint.nodes.size(), 3, "载回后应能继续加节点")
	ws.free()


## weapon_kind 的写入路径：仓库槽位（WAREHOUSE 表）→ 载荷 → _add_node → NodeData。
## 这里量的是最后一跳；仓库表本身由 _run_warehouse_checks 钉住，
## 中间那一跳（原生拖放的载荷）由 tests/integration/blueprint_smoke.gd 的真实拖拽钉住。
##
## 三段里断掉任何一段，「拖出去的锯」都会变成针（或落到 02 §9 的降级分支）——
## 而三张武器卡在画面上长得一模一样，玩家看不出来，只有这几条断言能挡住。
func _run_weapon_kind_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BlueprintWorkspace · 落节点写入 weapon_kind")
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return
	var kinds: GDScript = load(NODE_DATA_PATH)
	# 上一条用例在 SAVE_PATH 上留了 3 个节点；这份图必须从空的起，否则节点下标全错位。
	_cleanup()
	var ws: Control = _workspace(ctx, script.Area.CANVAS, CANVAS_SIZE)
	if ws == null:
		return

	var weapons: Array[int] = [kinds.WeaponKind.NEEDLE, kinds.WeaponKind.BOMB, kinds.WeaponKind.SAW]
	for index: int in weapons.size():
		ws.call(&"_add_node", kinds.Kind.WEAPON, "w%d" % index, Vector2(48.0, 48.0),
			kinds.Function.NONE, weapons[index])
	# 缺省（旧调用方 / 将来的程序化建图）必须落 NONE —— 那是 02 §9 的降级入口，
	# 而不是「随手指一把武器」：随机的那把会让调试图与玩家的图对不上。
	ws.call(&"_add_node", kinds.Kind.WEAPON, "w_default", Vector2(72.0, 72.0))
	ws.call(&"_add_node", kinds.Kind.CORE, "核心", Vector2(96.0, 96.0))

	var blueprint: BlueprintData = ws.call(&"blueprint")
	if not ctx.equal(blueprint.nodes.size(), 5, "应落出 5 个节点"):
		ws.free()
		return
	for index: int in weapons.size():
		ctx.equal(blueprint.nodes[index].weapon_kind, weapons[index],
			"第 %d 个武器节点应带上拖它出来那一槽的种类" % index)
	ctx.equal(blueprint.nodes[3].weapon_kind, kinds.WeaponKind.NONE,
		"不传种类时应落 NONE（降级入口），不得随手指一把武器")
	ctx.equal(blueprint.nodes[4].weapon_kind, kinds.WeaponKind.NONE,
		"CORE 不是武器，weapon_kind 必须留 NONE")
	ws.free()


## 装配：两个工作区节点各挂到 06 §7 的分区上，且都是**同级最后一个子节点**。
## 同级里后加入的先拾取、后绘制 —— 不是最后一个就会被分区的装饰盖住，看得见却点不到。
func _run_scene_assembly_checks(ctx: RefCounted) -> void:
	ctx.begin_case("PREPARATION · 蓝图工作区的装配（06 §7 分区归属）")
	var packed: PackedScene = load(PREP_SCENE_PATH)
	if not ctx.check(packed is PackedScene, "preparation.tscn 应能加载为 PackedScene"):
		return
	var scene: Node = packed.instantiate()
	if not ctx.check(scene != null, "preparation.tscn 应能实例化"):
		return

	var workspace_script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	var center: Control = _find(scene, "RegionCenter") as Control
	var canvas: Control = _find(scene, "BlueprintCanvas") as Control
	if ctx.check(canvas != null, "场景应有 BlueprintCanvas 节点"):
		ctx.equal(canvas.get_parent(), center, "画布应挂在中栏（§7 的蓝图工作区）")
		ctx.equal(canvas.get_script(), workspace_script, "画布应挂 blueprint_workspace.gd")
		ctx.equal(int(canvas.get(&"area")), int(workspace_script.Area.CANVAS), "画布应取 CANVAS 角色")
		ctx.equal(canvas.mouse_filter, Control.MOUSE_FILTER_STOP, "工作区必须自己接住点击（分区容器一律 IGNORE）")
		# 量 offset 而不是 size：不入树时 offset 是 .tscn 的字面量本身，不受布局解算影响
		# （同 test_preparation.gd 的 _check_region_literals）。差值即内缩 2px 后的可用尺寸。
		ctx.equal(canvas.offset_right - canvas.offset_left, CANVAS_SIZE.x, "画布宽度（中栏矩形内缩 2px）")
		ctx.equal(canvas.offset_bottom - canvas.offset_top, CANVAS_SIZE.y, "画布高度（中栏矩形内缩 2px）")
		ctx.equal(center.get_child(center.get_child_count() - 1), canvas, "画布应是中栏最后一个子节点（拾取优先）")

	var bottom: Control = _find(scene, "RegionBottom") as Control
	var warehouse: Control = _find(scene, "NodeWarehouse") as Control
	if ctx.check(warehouse != null, "场景应有 NodeWarehouse 节点"):
		ctx.equal(warehouse.get_parent(), bottom, "仓库应挂在底条（§7 的节点仓库区）")
		ctx.equal(warehouse.get_script(), workspace_script, "仓库应挂 blueprint_workspace.gd")
		ctx.equal(int(warehouse.get(&"area")), int(workspace_script.Area.WAREHOUSE), "仓库应取 WAREHOUSE 角色")
		ctx.equal(warehouse.mouse_filter, Control.MOUSE_FILTER_STOP, "仓库必须自己接住点击")
		ctx.equal(warehouse.offset_right - warehouse.offset_left, WAREHOUSE_SIZE.x, "仓库宽度（底条让开右下角的 CTA）")
		ctx.equal(warehouse.offset_bottom - warehouse.offset_top, WAREHOUSE_SIZE.y, "仓库高度（底条内缩 2px）")
		ctx.equal(bottom.get_child(bottom.get_child_count() - 1), warehouse, "仓库应是底条最后一个子节点（拾取优先）")

	if ctx.check(center != null, "场景应有 RegionCenter 分区"):
		# 06 §4：24px 的卡片放不下可读的中文，名称走 Tooltip 与右侧详情面板 —— 中栏的占位标题必须让位。
		var title: Control = center.find_child("Title", false, false) as Control
		ctx.check(title != null and not title.visible, "中栏的占位标题应隐藏，让位给画布")
	# 底条原来的横向槽位条已被工作区取代；两套并存会出现一块点不动的死区。
	ctx.check(_find(scene, "Slots") == null, "底条不应再有旧的 Slots 槽位条")
	ctx.check(_find(scene, "SlotsRow") == null, "底条不应再有旧的 SlotsRow")
	scene.free()


## 建一个不入树的工作区实例。size 决定全部几何，blueprint_path 改到测试目录。
func _workspace(ctx: RefCounted, area: int, size: Vector2) -> Control:
	var script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(script != null and script.can_instantiate(), "blueprint_workspace.gd 应能编译"):
		return null
	var ws: Control = script.new()
	if not ctx.check(ws != null, "blueprint_workspace.gd 应能实例化"):
		return null
	ws.set(&"area", area)
	ws.size = size
	ws.set(&"blueprint_path", SAVE_PATH)
	# 不入树就不会跑 _ready()，图模型由这个可重入入口建起来；顺带把上次实验的残留清干净。
	ws.call(&"reload")
	return ws


## 清掉上一次运行留在测试目录里的产物。正式存档目录一概不碰。
func _cleanup() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var dir: DirAccess = DirAccess.open(SAVE_DIR)
	if dir != null:
		dir.remove(SAVE_PATH.get_file())


func _is_on_grid(point: Vector2) -> bool:
	return is_zero_approx(fmod(point.x, GRID)) and is_zero_approx(fmod(point.y, GRID))


## 去掉注释再扫描：本仓库的文档注释里大量提到被禁的构造（正是为了声明「不许用」），
## 直接全文匹配会把「写明禁令」误判成「违反禁令」。同 test_preparation.gd 的 _strip_comments。
func _strip_comments(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		var quote: String = ""
		var cut: int = line.length()
		for index: int in line.length():
			var character: String = line[index]
			if not quote.is_empty():
				if character == quote:
					quote = ""
			elif character == "\"" or character == "'":
				quote = character
			elif character == "#":
				cut = index
				break
		kept.append(line.substr(0, cut))
	return "\n".join(kept)


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)
