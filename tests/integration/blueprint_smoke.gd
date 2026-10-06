## blueprint_smoke.gd
## 职责：FIRST PLAYABLE 1/4 的场景冒烟（09 §1）—— 在**真实场景**里用**合成指针**把节点从仓库拖到画布、
##       连成一条 CORE → FUNCTION → WEAPON 链，并核对存档真的落盘、真的能载回。**单独进程**运行。
##
## PET-75 追加：删得掉 / 撤得回 / 清得空。试玩反馈「模块装得上去、摘不下来」，
## 故这一段全部走**真实指针**（触摸点按钮、键盘按 Ctrl+Z），而不是 emit_signal ——
## 前者能证明按钮在触摸端够得着、没被别的控件盖住、快捷键真的挂对了对象；
## 后者只证明「信号连对了」，而功能坏掉时它照样全绿。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, scenes/preparation/preparation.tscn, scripts/ui/blueprint_workspace.gd
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 preparation_smoke.gd）；一律 load() + 经 /root 取节点。
##       不得写进玩家的正式存档目录（01 §7）：把工作区的 blueprint_path 指到 user://test_blueprints。
##
## 运行：**必须** `--resolution 640x360`，且**不得 headless**（要真实渲染与截图）。
##       工程是 stretch/mode=viewport + content_scale 640×360（PET-80 前 320×180）：合成事件走窗口坐标，
##       引擎再按「窗口 ÷ 设计尺寸」折算回设计坐标。窗口不是 640×360 时全部坐标会整体缩水，
##       GUI 拾取一片落空 —— 现象是「一条断言都不报错、就是什么都没发生」。
##       本仓库既有的 input_smoke 同此前提，故这里把窗口尺寸直接断言出来，避免误跑。
##
## 为什么两条输入都走 Input.parse_input_event：
##   它就是操作系统输入层用的那个入口，触摸事件在这里被 emulate_mouse_from_touch（工程默认开）
##   合成成鼠标事件 —— 真实触摸设备走的就是这条。于是「触摸能拖」证明的是引擎的合成路径，
##   而不是「我给触摸写了一个分支」（本卡一个 InputEvent 类型都没判过）。
##   两条路径都必须真的动起来才会启动拖放，故按下之后要分步移动，不能一步到位。
##
## 为什么每次合成指针之前还要 Input.warp_mouse（**本用例会移动真实光标**）：
##   引擎的**落点判定**读的是内部记录的鼠标位置，而这个位置只由真实输入更新 ——
##   投递进来的合成事件不更新它。只发合成事件的结果是：按下那一下按事件坐标命中（仓库的
##   _get_drag_data 拿到的是正确的槽位局部坐标），落点却按光标的旧位置算，两者分叉，
##   拖出去的东西落在别处（实测每条 DROP 都报同一个与本次拖拽无关的点）。
##   故合成指针的每一步都先把真实光标挪到同一个点，让两条路径看到同一个位置。
##   副作用：本用例会独占鼠标并把它挪到窗口内，需在无人在用的机器上跑。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const PREP_SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const WORKSPACE_SCRIPT_PATH: String = "res://scripts/ui/blueprint_workspace.gd"
const BLUEPRINT_DATA_PATH: String = "res://scripts/data/blueprint_data.gd"
const NODE_DATA_PATH: String = "res://scripts/data/node_data.gd"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const LOG_PATH: String = "res://tests/output/blueprint_smoke.log"
## 交付截图。tests/output 是工程内的合法产物目录（同各冒烟的 .log）。
const SHOT_PATH: String = "res://tests/output/blueprint_first_playable.png"
## PET-75 的前后对照截图：同一张图，「摘不下来」的那一版只有拖放，没有任何删除入口。
const SHOT_SELECTED_PATH: String = "res://tests/output/blueprint_edit_selected.png"
const SHOT_DELETED_PATH: String = "res://tests/output/blueprint_edit_deleted.png"
const SHOT_CLEAR_ARMED_PATH: String = "res://tests/output/blueprint_edit_clear_armed.png"

## 测试专用落盘目录，与正式存档目录刻意分开（同 test_blueprint_data.gd 的理由）。
const TEST_DIR: String = "user://test_blueprints"
const TEST_PATH: String = TEST_DIR + "/_smoke_01.tres"

## 06 §1 基准。合成事件的坐标全部按设计尺寸算，靠 --resolution 640x360 与窗口对齐。
## PET-80：320×180 → 640×360。
const DESIGN: Vector2 = Vector2(640.0, 360.0)
## 一次拖放的中间移动步数：拖放要真的动起来才启动，一步到位不会触发。
const DRAG_STEPS: int = 4
## 06 §4 的网格步长（本文件独立复写一遍）。PET-80：24 → 48。
const GRID: float = 48.0

## 仓库槽位下标 -> 落点（画布局部坐标）。顺序即玩家的操作顺序：先核心，再功能，最后武器。
## 前三个用鼠标拖、第四个用触摸拖 —— 两条输入路径都要真的产出节点。
const CORE_SLOT: int = 0
const FUNCTION_SLOT_A: int = 1
const FUNCTION_SLOT_B: int = 2
const WEAPON_SLOT: int = 4
## PET-80：四个落点全部 ×2，且仍各自落在 48 网格格心上（48/144 都是 48 的整数倍），
## 于是「相邻两格 / 对角两格」这个相对关系与 PET-80 前逐格相同。
const CORE_DROP: Vector2 = Vector2(48.0, 48.0)
const FUNCTION_DROP_A: Vector2 = Vector2(144.0, 48.0)
const FUNCTION_DROP_B: Vector2 = Vector2(48.0, 144.0)
const WEAPON_DROP: Vector2 = Vector2(144.0, 144.0)

var _ctx: RefCounted = null
var _scene: PackedScene = null
var _workspace_script: GDScript = null
var _blueprint_script: GDScript = null
var _node_script: GDScript = null
var _flow_script: GDScript = null
var _lines: Array[String] = []
var _shot_size: Vector2i = Vector2i.ZERO
## 本次跑出来的截图，收尾时一并列进报告。
var _shots: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_scene = load(PREP_SCENE_PATH)
	_workspace_script = load(WORKSPACE_SCRIPT_PATH)
	_blueprint_script = load(BLUEPRINT_DATA_PATH)
	_node_script = load(NODE_DATA_PATH)
	_flow_script = load(GAME_FLOW_PATH)
	_cleanup()
	await process_frame

	await _run_entry_case()
	if _canvas() == null:
		# 进不了场景就没什么可测的，直接收尾 —— 否则下面每一条都会连锁报一串无关的失败。
		_finish()
		return

	await _run_drag_out_case()
	await _run_connect_case()
	_run_chain_case()
	# PET-75 的验收序列接在链路之后：此刻正是「4 个节点 + 2 条连线」，
	# 而删 / 撤 / 清空三条各自跑完之后都必须回到这个状态，
	# 后面 _run_persistence_case 的前置（4 节点 2 连线）才仍然成立 —— 它们互为对方的看门狗。
	await _run_delete_case()
	await _run_undo_case()
	await _run_clear_case()
	await _run_reentry_case()
	await _run_screenshot_case()
	_run_persistence_case()
	_finish()


## 前提与入口：窗口必须正好是设计尺寸（见文件头），且场景由 GameFlow 路由进入 ——
## 绕过状态机自己 add_child 的话，测的就不是玩家真正到达的那份界面。
func _run_entry_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 前提（窗口尺寸）与经 GameFlow 路由进入")
	var window: Vector2i = DisplayServer.window_get_size()
	_ctx.equal(window, Vector2i(DESIGN), "窗口应正好是设计尺寸（漏了 --resolution 640x360？）")
	_ctx.check(root.get_final_transform().is_equal_approx(Transform2D.IDENTITY),
		"设计坐标到窗口坐标应是恒等变换（实际 %s）" % root.get_final_transform())

	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.check(bool(flow.call(&"change_state", _state("MAIN_MENU"))), "BOOT → MAIN_MENU 应被接受")
	await process_frame
	_ctx.check(bool(flow.call(&"change_state", _state("PREPARATION"))), "MAIN_MENU → PREPARATION 应被接受")
	await process_frame
	await process_frame
	var scene: Node = current_scene
	if not _ctx.check(scene != null, "切换后应存在当前场景"):
		return
	_ctx.equal(scene.scene_file_path, PREP_SCENE_PATH, "当前场景应是路由表登记的 PREPARATION")

	# 工作区的两个角色都要真的在场，且都比分区容器更靠后（同级里后加入的先拾取）。
	var canvas: Control = _canvas()
	var warehouse: Control = _warehouse()
	if not _ctx.check(canvas != null and warehouse != null, "场景里应有 BlueprintCanvas 与 NodeWarehouse"):
		return
	_ctx.equal(canvas.get_parent(), _find(scene, "RegionCenter"), "画布应挂在中栏")
	_ctx.equal(warehouse.get_parent(), _find(scene, "RegionBottom"), "仓库应挂在底条")
	# 存档路径改到测试目录并重载：正式存档目录只归玩家的游戏写。
	canvas.set(&"blueprint_path", TEST_PATH)
	canvas.call(&"reload")
	await process_frame
	_ctx.equal((canvas.call(&"blueprint") as Resource).get(&"nodes").size(), 0, "前置：画布初始应为空")
	_ctx.equal((warehouse.call(&"_slot_layout") as Dictionary)["shown"], 7, "前置：宽屏仓库应有 7 个槽位")

	# 内容区必须与 06 §7 的实测矩形逐值对上。量的是**全局**矩形：分区自己就带偏移
	# （RegionCenter 在 196,16、RegionBottom 在 30,264），坐标空间搞错时内容会整体平移出去 ——
	# 逻辑照样跑得通（合成事件按同一套错坐标发，拖放全都「成功」），屏幕上却什么都看不见。
	#
	# PET-80：两条期望值都**恰好是 PET-80 前的两倍** —— (100,10,124,120) → (200,20,248,240)、
	# (17,134,227,44) → (34,268,454,88)。它们本就是分区矩形内缩 2px（现在 4px）算出来的，
	# 而分区矩形与内缩量都随坐标系 ×2，故整条链一起放大、倍率是 1。
	_ctx.equal(canvas.get_global_rect(), Rect2(200.0, 20.0, 248.0, 240.0),
		"画布的全局矩形（06 §7 中栏 256×248 内缩 4px）")
	_ctx.equal(warehouse.get_global_rect(), Rect2(34.0, 268.0, 454.0, 88.0),
		"仓库的全局矩形（06 §7 底条内缩 4px 并让开右下角的 CTA）")
	# 反向核对：内容既不得盖住 CTA，也不得压到分区那圈描边上（PET-80：2px → 4px）。
	var cta: Control = _find(scene, "ButtonStartCombat") as Control
	_ctx.check(warehouse.get_global_rect().end.x <= cta.get_global_rect().position.x - 4.0,
		"仓库不得伸到 CTA 底下（仓库右缘 %.1f，CTA 左缘 %.1f）" % [
			warehouse.get_global_rect().end.x, cta.get_global_rect().position.x])


## 验收第一条：能**拖出**节点。鼠标拖 3 个、触摸拖 1 个，四个都要真的落到画布上。
func _run_drag_out_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 拖出节点（鼠标 ×3 + 触摸 ×1）")
	await _drag_with_mouse(_slot_center(CORE_SLOT), _drop_point(CORE_DROP))
	_ctx.equal(_nodes().size(), 1, "鼠标拖出第 1 个节点后应有 1 个节点")
	await _drag_with_mouse(_slot_center(FUNCTION_SLOT_A), _drop_point(FUNCTION_DROP_A))
	await _drag_with_mouse(_slot_center(FUNCTION_SLOT_B), _drop_point(FUNCTION_DROP_B))
	_ctx.equal(_nodes().size(), 3, "鼠标拖出 3 个节点后应有 3 个节点")

	await _drag_with_touch(_slot_center(WEAPON_SLOT), _drop_point(WEAPON_DROP))
	_ctx.equal(_nodes().size(), 4, "触摸拖出第 4 个节点后应有 4 个节点（验收要求 ≥4）")

	# 类型与顺序：槽位 0/1/2/4 依次是 CORE、两个 FUNCTION、WEAPON。
	var kinds: GDScript = _node_script
	var expected: Array[int] = [
		kinds.Kind.CORE, kinds.Kind.FUNCTION, kinds.Kind.FUNCTION, kinds.Kind.WEAPON,
	]
	for index: int in expected.size():
		if not _ctx.check(index < _nodes().size(), "第 %d 个节点应存在" % index):
			continue
		_ctx.equal(int((_nodes()[index] as Resource).get(&"kind")), expected[index],
			"第 %d 个节点的类型" % index)

	# 落格（06 §4）：每个节点都要在网格上、都在画布内 —— 这一条只有真的走了拾取与落点判定才可能成立。
	var boxes: Dictionary = _canvas().get(&"_boxes")
	_ctx.equal(boxes.size(), 4, "4 个节点都应有落位矩形")
	var canvas: Control = _canvas()
	for node: Resource in _nodes():
		var id: StringName = StringName(node.get(&"id"))
		if not _ctx.check(boxes.has(id), "节点 %s 应有落位矩形" % id):
			continue
		var rect: Rect2 = boxes[id]
		_ctx.check(is_zero_approx(fmod(rect.position.x, GRID)) and is_zero_approx(fmod(rect.position.y, GRID)),
			"节点 %s 应吸附到 48px 网格（实际 %s）" % [id, rect.position])
		_ctx.check(rect.position.x >= 0.0 and rect.position.y >= 0.0
			and rect.end.x <= canvas.size.x + 0.01 and rect.end.y <= canvas.size.y + 0.01,
			"节点 %s 应落在画布内（实际 %s）" % [id, rect])

	# 拖出来的武器必须带上**它那一槽**的武器种类 —— 这是本卡新接上的那条路，也是「拖出去的是
	# 针还是锯」的唯一来源（按显示名反查的那条桥已删）。三张武器卡在画面上长得一模一样，
	# 这一条断了，三把武器会全部落到 02 §9 的降级分支，而界面上看不出任何异常。
	# 期望值取自仓库表本身：这里证的是「表里的值真的走到了节点上」，表本身的值由
	# tests/unit/test_blueprint_workspace.gd 独立钉住。
	var weapon_slot_kind: int = int(_workspace_script.WAREHOUSE[WEAPON_SLOT]["weapon_kind"])
	if _ctx.check(weapon_slot_kind != kinds.WeaponKind.NONE,
			"仓库第 %d 槽应写明武器种类（否则下面这条断言是空的）" % WEAPON_SLOT):
		var dragged_weapons: int = 0
		for node: Resource in _nodes():
			if int(node.get(&"kind")) != kinds.Kind.WEAPON:
				continue
			dragged_weapons += 1
			_ctx.equal(int(node.get(&"weapon_kind")), weapon_slot_kind,
				"拖出来的武器节点应带上它那一槽的武器种类（节点 %s）" % node.get(&"id"))
		_ctx.equal(dragged_weapons, 1, "本用例只从武器槽拖出过 1 个节点")

	# 仓库是「无限取用」的图章，不是消耗品：拖出 4 个之后仍应有 7 个槽位。
	_ctx.equal(int((_warehouse().call(&"_slot_layout") as Dictionary)["shown"]), 7,
		"拖出节点不得消耗仓库槽位")


## 验收第二条：能从输出端口拖到输入端口**连成线**。鼠标连一条、触摸连一条。
func _run_connect_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 连线（鼠标 ×1 + 触摸 ×1）")
	var core_id: StringName = _id_at_kind_index(_node_script.Kind.CORE, 0)
	var split_id: StringName = _id_at_kind_index(_node_script.Kind.FUNCTION, 0)
	var weapon_id: StringName = _id_at_kind_index(_node_script.Kind.WEAPON, 0)
	if not _ctx.check(not String(core_id).is_empty() and not String(split_id).is_empty()
		and not String(weapon_id).is_empty(), "三种类型的节点都应存在"):
		return

	await _drag_with_mouse(_card_center(core_id), _card_center(split_id))
	_ctx.equal(_connections().size(), 1, "鼠标从 CORE 拖到 FUNCTION 后应有 1 条连线")
	await _drag_with_touch(_card_center(split_id), _card_center(weapon_id))
	_ctx.equal(_connections().size(), 2, "触摸从 FUNCTION 拖到 WEAPON 后应有 2 条连线")

	# 06 §4.2 的端口语义：起点一律输出、终点一律输入。引擎把「按住卡片」翻成连接拖拽时，
	# 这两条就是它翻对了的证据。
	for link: Resource in _connections():
		_ctx.equal(String(link.get(&"from_port")), "out", "起点的端口应是输出")
		_ctx.equal(String(link.get(&"to_port")), "in", "终点的端口应是输入")

	# 反向核对：自己连自己必须落空。落点仍在同一张卡片内（PET-80：卡片 48×48，中心偏移 10 → 20
	# 仍在里面 —— 20 < 24，与 10 < 12 是同一个不等式），所以这是一次真的拖拽，
	# 只是终点落在起点自己身上。
	await _drag_with_mouse(_card_center(core_id), _card_center(core_id) + Vector2(0.0, 20.0))
	_ctx.equal(_connections().size(), 2, "把卡片拖回它自己不得新增连线（自环应被挡掉）")
	# 同一对节点再连一次也不得重复（重复边会画成两条重叠的线）。
	await _drag_with_mouse(_card_center(core_id), _card_center(split_id))
	_ctx.equal(_connections().size(), 2, "同一对节点重复连线不得新增（重复边应被挡掉）")


## 验收原文：连成**一条 CORE → FUNCTION → WEAPON 链**。
## 这里真的沿有向边走一遍，而不是只数连线个数 —— 数个数的话两条 CORE→WEAPON 也能骗过验收。
func _run_chain_case() -> void:
	_ctx.begin_case("蓝图冒烟 · CORE → FUNCTION → WEAPON 链（验收原文）")
	var cores: Array[StringName] = _ids_of_kind(_node_script.Kind.CORE)
	var functions: Array[StringName] = _ids_of_kind(_node_script.Kind.FUNCTION)
	var weapons: Array[StringName] = _ids_of_kind(_node_script.Kind.WEAPON)
	var found: bool = false
	for core_id: StringName in cores:
		for function_id: StringName in functions:
			if not _has_edge(core_id, function_id):
				continue
			for weapon_id: StringName in weapons:
				if _has_edge(function_id, weapon_id):
					_ctx.check(true, "应存在一条 CORE(%s) → FUNCTION(%s) → WEAPON(%s) 链" % [
						core_id, function_id, weapon_id])
					found = true
	_ctx.check(found, "应存在一条 CORE → FUNCTION → WEAPON 链（实际连线 %d 条）" % _connections().size())


## 验收第三条（PET-75）：**删得掉**。选中一个节点 → 触摸点「删除」→ 它连同挂在它身上的线一起消失。
##
## 删除入口走合成触摸而不是 emit_signal(&"pressed")：本卡明写「触摸端必须够得着」，
## 而 emit_signal 只证明信号连对了 —— 按钮位置算错、被别的控件盖住、在窄屏被裁掉，
## 它全都照样绿。真的按下去才把「够得着」也一起证了。
func _run_delete_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 删除节点（触摸点按钮，连线连带消失）")
	var canvas: Control = _canvas()
	var split_id: StringName = _id_at_kind_index(_node_script.Kind.FUNCTION, 0)
	if not _ctx.check(not String(split_id).is_empty(), "前置：应有一个 FUNCTION 节点"):
		return
	_ctx.equal(_nodes().size(), 4, "前置：应有 4 个节点")
	_ctx.equal(_connections().size(), 2, "前置：应有 2 条连线")

	# 选中：点卡片中心。点选本身一个节点都不许少 —— 这是「选中与执行分两步」的第一半，
	# 也是本卡对 06 §10.4 的实现方式（触摸端一下手势只能做一件事，点一下就删等于误触即毁）。
	await _tap(_card_center(split_id))
	_ctx.equal(String(canvas.call(&"selected_node_id")), String(split_id), "点卡片应选中它")
	_ctx.equal(_nodes().size(), 4, "点选不得改图")

	var delete_button: Button = _find(current_scene, "ButtonDelete") as Button
	var undo_button: Button = _find(current_scene, "ButtonUndo") as Button
	var clear_button: Button = _find(current_scene, "ButtonClear") as Button
	if not _ctx.check(delete_button != null and undo_button != null and clear_button != null,
			"整备界面应有删除 / 撤销 / 清空三个动作按钮"):
		return
	_ctx.check(not delete_button.disabled, "选中之后「删除」应可用")
	_ctx.check(not undo_button.disabled, "已经改过图，「撤销」应可用")
	_ctx.check(not clear_button.disabled, "图里有内容，「清空」应可用")
	await _capture(SHOT_SELECTED_PATH, "选中态：三个动作按钮在场，「删除」可用")

	await _tap_control(delete_button)
	_ctx.equal(_nodes().size(), 3, "删除后应剩 3 个节点")
	_ctx.equal(_connections().size(), 0, "挂在被删节点上的两条线都应一起消失")
	_ctx.check(not canvas.call(&"has_selection"), "删除后应清空选中")
	_ctx.check(delete_button.disabled, "删除后没有选中，「删除」应自己变灰")
	await _capture(SHOT_DELETED_PATH, "删除后：节点与它的两条线都没了")

	# 删掉的东西必须当场落盘（09 §3.2）：重进场景看到的就是删过之后的图。
	var loaded: Resource = _blueprint_script.load_from(TEST_PATH)
	if _ctx.check(loaded != null, "删除后应能载回存档"):
		_ctx.equal((loaded.get(&"nodes") as Array).size(), 3, "落盘的节点数应是删过之后的")
		_ctx.equal((loaded.get(&"connections") as Array).size(), 0, "落盘的连线数应是删过之后的")


## 验收第四条（PET-75）：**撤得回**。Ctrl+Z 把上一次删除整张还原 —— 节点与它的两条线一起回来。
##
## 走真的键盘事件（Input.parse_input_event）而不是直接调 canvas.undo()：键位挂在 .tscn 的
## Button.shortcut 上，脚本里一个键码都不出现，除了这里没有第二处会走到那条装配。
func _run_undo_case() -> void:
	_ctx.begin_case("蓝图冒烟 · Ctrl+Z 撤销（真实键盘事件）")
	_ctx.equal(_nodes().size(), 3, "前置：上一用例删掉了一个节点")
	_ctx.equal(_connections().size(), 0, "前置：两条线被连带删掉了")

	await _press_key(KEY_Z, true)
	_ctx.equal(_nodes().size(), 4, "Ctrl+Z 后应还原被删的节点")
	_ctx.equal(_connections().size(), 2, "Ctrl+Z 必须把被连带删掉的线一并还原（只还节点就是一次静默的错误撤销）")

	var loaded: Resource = _blueprint_script.load_from(TEST_PATH)
	if _ctx.check(loaded != null, "撤销后应能载回存档"):
		_ctx.equal((loaded.get(&"nodes") as Array).size(), 4, "撤销也要落盘：重进场景看到的应是撤回来的图")
		_ctx.equal((loaded.get(&"connections") as Array).size(), 2, "撤销也要落盘：连线数")


## 验收第五条（PET-75）：**清得空**，而且按一下不算数。
##
## 06 §10.4 要求破坏性操作要么二次确认要么可撤销；清空两条都给 ——
## 它是唯一一个一下能毁掉整张图的动作，代价不对称。这里把「按一下就清掉」钉死成失败：
## 真正危险的实现不是清不掉，而是**一次误触就把玩家的机器拆了**。
func _run_clear_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 清空蓝图（二次确认 + 可撤销）")
	var clear_button: Button = _find(current_scene, "ButtonClear") as Button
	if not _ctx.check(clear_button != null, "应有「清空蓝图」按钮"):
		return

	_ctx.equal(_nodes().size(), 4, "前置：撤销之后应有 4 个节点")
	_ctx.equal(clear_button.text, "清空蓝图", "前置：清空按钮的初始文案")

	await _tap_control(clear_button)
	_ctx.equal(_nodes().size(), 4, "第一次点「清空」不得真的清空")
	_ctx.not_equal(clear_button.text, "清空蓝图",
		"第一次点应把文案换成确认问句（实际 '%s'）" % clear_button.text)
	await _capture(SHOT_CLEAR_ARMED_PATH, "清空的二次确认：按第二下才真的清")

	await _tap_control(clear_button)
	_ctx.equal(_nodes().size(), 0, "第二次点「清空」才真的清空")
	_ctx.equal(_connections().size(), 0, "清空后连线也没了")
	_ctx.check(clear_button.disabled, "清空之后没内容可清，「清空」应自己变灰")
	_ctx.equal(clear_button.text, "清空蓝图", "清空之后文案应收回原样")
	var delete_button: Button = _find(current_scene, "ButtonDelete") as Button
	if _ctx.check(delete_button != null, "应有「删除」按钮"):
		_ctx.check(delete_button.disabled, "清空之后没有选中，「删除」应也是灰的")

	await _press_key(KEY_Z, true)
	_ctx.equal(_nodes().size(), 4, "Ctrl+Z 应能把清空整张还原")
	_ctx.equal(_connections().size(), 2, "撤销清空后连线也回来")


## 验收第六条（PET-75）：**重进场景仍是一致的**。
##
## 真的重实例化一份整备界面并让它跑完 _ready()，而不是只调 canvas.reload()：
## 「重进场景」在玩家那里就是这条路，而 _refresh_actions() 只有在 _ready() 里才跑得到 ——
## 少了它，玩家回来会看到三个按钮停在场景文件写的初始状态上（删除没灰、清空是亮的）。
func _run_reentry_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 重进场景（新实例 + _ready 全跑）")
	var fresh: Node = _scene.instantiate()
	var fresh_canvas: Control = _find(fresh, "BlueprintCanvas") as Control
	if not _ctx.check(fresh_canvas != null, "新实例应有画布"):
		fresh.free()
		return
	# 落盘路径必须在入树**之前**改掉：入树即跑 _ready()，那时它已经去读默认存档了。
	fresh_canvas.set(&"blueprint_path", TEST_PATH)
	root.add_child(fresh)
	await process_frame
	await process_frame

	var fresh_nodes: Array = (fresh_canvas.call(&"blueprint") as Resource).get(&"nodes")
	var fresh_links: Array = (fresh_canvas.call(&"blueprint") as Resource).get(&"connections")
	_ctx.equal(fresh_nodes.size(), 4, "重进场景后应载回 4 个节点")
	_ctx.equal(fresh_links.size(), 2, "重进场景后应载回 2 条连线")
	_ctx.equal((fresh_canvas.get(&"_boxes") as Dictionary).size(), 4, "重进场景后每个节点都应重新落格")

	# 选中态与撤销栈**不进存档**：新实例刚进来，两个按钮都该是灰的，哪怕图里有内容。
	# 这一条反过来钉住了「撤销栈跟着 reload 清空」——留着上一次的栈，第一次 Ctrl+Z
	# 会把上一张图整张搬回来，比撤不动更难理解。
	var fresh_delete: Button = _find(fresh, "ButtonDelete") as Button
	var fresh_undo: Button = _find(fresh, "ButtonUndo") as Button
	var fresh_clear: Button = _find(fresh, "ButtonClear") as Button
	if _ctx.check(fresh_delete != null and fresh_undo != null and fresh_clear != null, "新实例应有三个动作按钮"):
		_ctx.check(fresh_delete.disabled, "新实例没有选中，「删除」应是灰的")
		_ctx.check(fresh_undo.disabled, "新实例的撤销栈是空的，「撤销」应是灰的（它不进存档）")
		_ctx.check(not fresh_clear.disabled, "新实例图里有内容，「清空」应是亮的")

	root.remove_child(fresh)
	fresh.free()
	await process_frame


## 交付物：一张渲染截图。取的是根视口**真实画出来的**那一帧，不是自己重画的示意图。
func _run_screenshot_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 交付截图（非 headless 才有）")
	# 拖放结束后的重绘要落地：等两帧再取像。
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	if not _ctx.check(image != null, "应能取到根视口的渲染结果（是否误加了 --headless？）"):
		return
	_shot_size = image.get_size()
	_ctx.check(_shot_size.x > 0 and _shot_size.y > 0, "截图尺寸应有效（实际 %s）" % _shot_size)
	_ctx.equal(image.save_png(SHOT_PATH), OK, "截图应能写入 %s" % SHOT_PATH)


## 09 §3.2：改动即落盘；重载后图完全一致，且节点重新落格（位置不进 NodeData）。
func _run_persistence_case() -> void:
	_ctx.begin_case("蓝图冒烟 · 存档落盘与重载（09 §3.2 / 01 §7）")
	_ctx.check(FileAccess.file_exists(TEST_PATH), "改动后应已落盘到 %s" % TEST_PATH)
	_ctx.check(not TEST_PATH.begins_with(_default_save_dir()),
		"测试路径不得落在玩家的正式存档目录（%s）" % _default_save_dir())

	var loaded: Resource = _blueprint_script.load_from(TEST_PATH)
	if not _ctx.check(loaded != null, "load_from 应能取回蓝图"):
		return
	_ctx.equal((loaded.get(&"nodes") as Array).size(), 4, "载回的节点数应与画布上一致")
	_ctx.equal((loaded.get(&"connections") as Array).size(), 2, "载回的连线数应与画布上一致")
	var counts: Dictionary = _kind_counts(loaded)
	_ctx.equal(int(counts.get(_node_script.Kind.CORE, 0)), 1, "载回的 CORE 数量")
	_ctx.equal(int(counts.get(_node_script.Kind.FUNCTION, 0)), 2, "载回的 FUNCTION 数量")
	_ctx.equal(int(counts.get(_node_script.Kind.WEAPON, 0)), 1, "载回的 WEAPON 数量")

	# 让**画布自己**重载一次：它读的必须是同一份文件，且节点要重新落格（而不是全叠在原点）。
	var canvas: Control = _canvas()
	canvas.call(&"reload")
	_ctx.equal(_nodes().size(), 4, "画布重载后应仍有 4 个节点")
	_ctx.equal(_connections().size(), 2, "画布重载后应仍有 2 条连线")
	var boxes: Dictionary = canvas.get(&"_boxes")
	_ctx.equal(boxes.size(), 4, "重载后每个节点都应重新落格")
	var seen: Dictionary = {}
	for node: Resource in _nodes():
		var id: StringName = StringName(node.get(&"id"))
		_ctx.check(not seen.has(id), "重载后节点 id 不得重复（'%s'）" % id)
		seen[id] = true
		if not _ctx.check(boxes.has(id), "重载后节点 %s 应有落位矩形" % id):
			continue
		var rect: Rect2 = boxes[id]
		_ctx.check(rect.position.x >= 0.0 and rect.position.y >= 0.0
			and rect.end.x <= canvas.size.x + 0.01 and rect.end.y <= canvas.size.y + 0.01,
			"重载后节点 %s 应落在画布内（实际 %s）" % [id, rect])
	# 载回后继续加节点不得撞 id —— 撞车的后果是 _boxes 这个以 id 为键的字典把旧节点顶掉。
	canvas.call(&"_add_node", _node_script.Kind.WEAPON, "锯", Vector2(120.0, 120.0),
		_node_script.Function.NONE, _node_script.WeaponKind.SAW)
	_ctx.equal(_nodes().size(), 5, "载回后应能继续加节点")
	var ids: Dictionary = {}
	for node: Resource in _nodes():
		ids[String(node.get(&"id"))] = true
	_ctx.equal(ids.size(), 5, "载回后新增节点的 id 不得与既有 id 重复")


# ── 场景与数据 ────────────────────────────────────────────────────────────────

func _canvas() -> Control:
	return _find(current_scene, "BlueprintCanvas") as Control


func _warehouse() -> Control:
	return _find(current_scene, "NodeWarehouse") as Control


func _nodes() -> Array:
	var blueprint: Resource = _canvas().call(&"blueprint")
	return blueprint.get(&"nodes")


func _connections() -> Array:
	var blueprint: Resource = _canvas().call(&"blueprint")
	return blueprint.get(&"connections")


func _ids_of_kind(kind: int) -> Array[StringName]:
	var ids: Array[StringName] = []
	for node: Resource in _nodes():
		if int(node.get(&"kind")) == kind:
			ids.append(StringName(node.get(&"id")))
	return ids


func _id_at_kind_index(kind: int, index: int) -> StringName:
	var ids: Array[StringName] = _ids_of_kind(kind)
	return ids[index] if index < ids.size() else &""


func _has_edge(from_id: StringName, to_id: StringName) -> bool:
	for link: Resource in _connections():
		if StringName(link.get(&"from_node_id")) == from_id and StringName(link.get(&"to_node_id")) == to_id:
			return true
	return false


func _kind_counts(blueprint: Resource) -> Dictionary:
	var counts: Dictionary = {}
	for node: Resource in blueprint.get(&"nodes"):
		var kind: int = int(node.get(&"kind"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts


func _default_save_dir() -> String:
	return String(_blueprint_script.DEFAULT_SAVE_DIR)


# ── 坐标 ──────────────────────────────────────────────────────────────────────

## 设计坐标 -> 本次运行的窗口坐标。--resolution 640x360 下是恒等变换（上面已断言），
## 写出来是为了让「窗口不是设计尺寸」这件事有一个显式的换算点，而不是让坐标悄悄失配。
func _to_window(point: Vector2) -> Vector2:
	return root.get_final_transform() * point


## 仓库槽位中心的窗口坐标。槽位矩形由工作区按自身尺寸现算，这里不另抄一份几何。
func _slot_center(index: int) -> Vector2:
	var warehouse: Control = _warehouse()
	var rect: Rect2 = warehouse.call(&"_slot_rect", index)
	return _to_window(warehouse.global_position + rect.position + rect.size * 0.5)


## 画布局部落点 -> 窗口坐标。
func _drop_point(local: Vector2) -> Vector2:
	return _to_window(_canvas().global_position + local)


## 卡片中心的窗口坐标。落格矩形由工作区自己算，这里只做查询。
func _card_center(node_id: StringName) -> Vector2:
	var canvas: Control = _canvas()
	var boxes: Dictionary = canvas.get(&"_boxes")
	if not boxes.has(node_id):
		return Vector2.ZERO
	return _to_window(canvas.global_position + (boxes[node_id] as Rect2).get_center())


# ── 合成指针 ──────────────────────────────────────────────────────────────────

## 一次完整的鼠标拖放：按下 → 分步移动 → 松开。
## 每步都带上真实的 relative —— 拖放的启动看的是位移累积，relative 恒为零等于没动过。
func _drag_with_mouse(from: Vector2, to: Vector2) -> void:
	await _warp(from)
	await _push_mouse(from, true)
	var previous: Vector2 = from
	for step: int in DRAG_STEPS:
		var point: Vector2 = from.lerp(to, float(step + 1) / float(DRAG_STEPS))
		await _warp(point)
		await _push_motion(previous, point)
		previous = point
	await _warp(to)
	await _push_mouse(to, false)


## 一次完整的触摸拖放。走 Input.parse_input_event，即引擎真实的触摸 → 鼠标合成路径。
func _drag_with_touch(from: Vector2, to: Vector2) -> void:
	await _warp(from)
	await _parse_touch(from, true)
	var previous: Vector2 = from
	for step: int in DRAG_STEPS:
		var point: Vector2 = from.lerp(to, float(step + 1) / float(DRAG_STEPS))
		await _warp(point)
		await _parse_screen_drag(previous, point)
		previous = point
	await _warp(to)
	await _parse_touch(to, false)


## 一次触摸**点按**（按下即抬起，中途不动）。
##
## 与拖放分开写是有意的：拖放必须在按下后**移动**才启动，而点按不能移动 ——
## 一动就成了「从这张卡拉一根线出去」，选中的是别的意思。两条路径各自只做一件事。
func _tap(at: Vector2) -> void:
	await _warp(at)
	await _parse_touch(at, true)
	await _parse_touch(at, false)


## 点一个控件（合成触摸）。走的是引擎真实的触摸 → 鼠标合成路径，
## 于是「这个按钮在触摸端够得着」也被一并证了 —— 只发 pressed 信号是证不到的。
func _tap_control(control: Control) -> void:
	await _tap(_to_window(control.global_position + control.size * 0.5))


## 按一次键（含修饰键）。走 Input.parse_input_event，与操作系统输入层同一个入口。
##
## 键位本身不在任何脚本里：它挂在 .tscn 的 Button.shortcut 上（03 §8），
## 故这里按下的是**玩家真的会按的那个键**，而不是绕过装配直接调方法。
func _press_key(keycode: int, ctrl: bool) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
		await process_frame


## 存一张当前帧的截图（取的是根视口真实画出来的那一帧，同 _run_screenshot_case）。
func _capture(path: String, label: String) -> void:
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	if not _ctx.check(image != null, "应能取到渲染结果（%s）" % label):
		return
	if _ctx.check(image.save_png(path) == OK, "截图应能写入 %s" % path):
		_shots.append("%s（%s）" % [path.get_file(), label])


## 把**真实光标**移到合成指针将要使用的同一点。这一步不是可选的，见文件头「落点判定跟随真实光标」。
func _warp(point: Vector2) -> void:
	# 窗口没在前台时系统会忽略 warp，那样光标状态就不会更新 —— 先挪到前台再挪光标。
	if DisplayServer.window_is_focused() == false:
		DisplayServer.window_move_to_foreground()
	Input.warp_mouse(point)
	await process_frame
	await process_frame


func _push_mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	event.pressed = pressed
	# 走 Input.parse_input_event 而不是 root.push_input：前者才是操作系统输入层用的入口，
	# 触摸合成鼠标也在这里发生。位置本身仍要靠调用方先 _warp（见文件头）。
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _push_motion(from: Vector2, to: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	# 按住不放：拖放是「按下 + 移动」才启动的，button_mask 漏了就不会有拖拽。
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = to
	event.global_position = to
	event.relative = to - from
	Input.parse_input_event(event)
	await process_frame
	await process_frame


## 触摸事件经 parse_input_event 要多等一帧：合成出的鼠标事件是与触摸事件分开派发的。
func _parse_touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _parse_screen_drag(from: Vector2, to: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = to
	event.relative = to - from
	Input.parse_input_event(event)
	await process_frame
	await process_frame


# ── 杂项 ──────────────────────────────────────────────────────────────────────

## 清掉上一次运行留在测试目录与输出目录里的产物。正式存档目录一概不碰。
func _cleanup() -> void:
	if FileAccess.file_exists(TEST_PATH):
		var dir: DirAccess = DirAccess.open(TEST_DIR)
		if dir != null:
			dir.remove(TEST_PATH.get_file())


func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false) if node != null else null


func _state(name: String) -> int:
	return int(_flow_script.GameState[name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：PET-63 FIRST PLAYABLE 1/4 蓝图可编辑（节点拖放 + 连线）")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d（设计尺寸 %dx%d）" % [
		version["string"], window.x, window.y, int(DESIGN.x), int(DESIGN.y)])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：PREPARATION 经路由进入 · 鼠标×3 + 触摸×1 拖出 4 个节点 · 鼠标+触摸各连 1 条 · CORE→FUNCTION→WEAPON 链 · 存档落盘与重载")
	_lines.append("- 手动场景（PET-75）：触摸点「删除」删节点（连线连带消失）· 真实 Ctrl+Z 还原 · 「清空」二次确认 · 重进场景一致")
	_lines.append("- 截图：%s（%dx%d）" % [SHOT_PATH, _shot_size.x, _shot_size.y])
	for shot: String in _shots:
		_lines.append("- 截图：%s" % shot)
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：%s" % LOG_PATH)

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("blueprint_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
