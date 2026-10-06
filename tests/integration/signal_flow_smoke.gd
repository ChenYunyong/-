## signal_flow_smoke.gd
## 职责：机器运行的**真实运行**取证（FIRST PLAYABLE 2/4）—— 经 GameFlow 路由进 COMBAT 之后，
##       蓝图机器由 MachineDriver 按固定节拍真的跑起来、武器真的开火、`热量` 读数真的变化，
##       并且这些事在画面上**真的看得见**（信号火花与占位弹丸的像素证据 + 截图）。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, render_probe_harness, Palette, assets/ui/theme_main.tres,
##       scenes/combat/combat.tscn, scripts/ui/combat_screen.gd, scripts/gameplay/machine_driver.gd,
##       scripts/data/{node_data,connection_data,blueprint_data}.gd
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素，最后一段取不到图像）；
##       不得引用 Autoload 标识符 —— 它是 --script 入口，在工程注册这些之前就被编译
##       （同 combat_smoke.gd 的约束），一律 load() + 经 /root 取节点；
##       不得写任何字面色值 —— 判据色一律经 Palette 取；
##       不得落进 BlueprintData.DEFAULT_SAVE_DIR（正式存档目录只归玩家的游戏写）。
##
## 为什么这里用真实帧、而单元测试手摇 tick()：本文件要证的正是「MachineDriver 把真实帧时间
## 换成固定节拍」这一层，手摇就把它换掉了。判据仍然是**节拍号**不是真实耗时（03 §6），
## 故帧率高低只影响耗时，不影响结论（见 _advance_until）。
##
## 为什么截图走离屏画布：像素要 1:1 可读，而窗口尺寸受系统显示缩放影响
## （同 combat_probe.gd 的做法）。离屏用的是**同一个** combat.tscn，装配路径与路由进来的一致。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   负对照一 —— 机器静止（冻结在 0 拍）时，示意区内一个 BLUE_050 像素都不该有。
##   负对照二 —— 藏掉机器视图，两处判据色必须整体归零（证明像素确实来自这块视图的绘制）。
##   首发拍号 —— 断言的是「第 22 拍」这个绝对值（CORE 节拍 10 + 3 条边各 4 拍）；
##               节拍、传播、FUNCTION 转发、WEAPON 开火任一环改了时长都会转红。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const HARNESS_PATH: String = "res://tests/unit/render_probe_harness.gd"
const COMBAT_SCENE_PATH: String = "res://scenes/combat/combat.tscn"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const PALETTE_PATH: String = "res://scripts/data/palette.gd"
const NODE_SCRIPT_PATH: String = "res://scripts/data/node_data.gd"
const LINK_SCRIPT_PATH: String = "res://scripts/data/connection_data.gd"
const BLUEPRINT_SCRIPT_PATH: String = "res://scripts/data/blueprint_data.gd"
const THEME_PATH: String = "res://assets/ui/theme_main.tres"
const LOG_PATH: String = "res://tests/output/signal_flow_smoke.log"
const SHOT_PATH: String = "res://tests/output/signal_flow_"

## 测试专用落盘目录，与正式存档目录刻意分开。
const TEST_DIR: String = "user://test_blueprints"
const TEST_PATH: String = TEST_DIR + "/_flow_smoke.tres"

## 画布 = 06 §1 的 640×360 基准（PET-80 前 320×180），于是「第几个像素」可以直接读。
## 下面这几个长度全部随基准画布 ×2：战场下沿 135→270、示意区高 48→96、走廊上沿 32→64。
const CANVAS: Vector2i = Vector2i(640, 360)
const VIEWPORT: Vector2 = Vector2(640.0, 360.0)
const BAND_TOP: float = 270.0
## 机器示意区的高度（combat_screen.MACHINE_VIEW_HEIGHT，本文件独立复写）。PET-80：48 → 96。
const MACHINE_VIEW_HEIGHT: float = 96.0
## 弹丸走廊：示意区之上、占位文字带（PET-80 后 y 8–56）之下。只在走廊里找弹丸，
## 于是「上方出现了判据色」不会被别的文字墨迹污染。
const LANE_FROM_Y: int = 64
## 放大倍数：12×12 的火花（PET-80 前 6×6）在一张 640×360 的图里几乎看不出来，证据图放大后再附。
## 基准画布本身已翻倍，故这个数不跟着翻 —— 同样的 4× 在逻辑像素这一层与 PET-80 前等价。
const ZOOM: int = 4

## 03 §2 与本卡的固定常数，独立复写一遍 —— 期望值若与被测实现同源，实现改错时两边一起错。
const CORE_PERIOD: int = 10
const TRAVEL: int = 4
const HEAT_PER_STEP: String = "2%"
## 验收机器 CORE → Split → Amplify → Needle：三条边，故首发落在 10 + 3×4 = 22 拍。
const CHAIN_EDGES: int = 3
const FIRST_FIRE_TICK: int = CORE_PERIOD + CHAIN_EDGES * TRAVEL
## 取样拍号：越过首发一拍，此时弹丸（存活 8 拍）与在途信号都还在画面上。
const SAMPLE_TICK: int = FIRST_FIRE_TICK + 1
## MachineDriver 单帧最多推进的拍数（MAX_CATCH_UP_TICKS）。取样点因此最多过冲这么多拍，
## 22 + 5 = 27 仍落在弹丸存活期内 —— 下面的像素断言于是与帧率无关。
const MAX_CATCH_UP: int = 5
## 墙钟上限：用例不得挂死（同 run_tests.gd 的兜底）。判据是节拍号，不是这个数。
const WALL_CLOCK_BUDGET_MS: int = 10_000

var _ctx: RefCounted = null
var _h: RefCounted = null
var _theme: Theme = null
var _node_script: GDScript = null
var _link_script: GDScript = null
var _blueprint_script: GDScript = null
var _flow_script: GDScript = null
var _palette: GDScript = null

## 判据色：火花（芯）/ 弹丸体 / 画布底。三层 FX 里取最有辨识度的两层做判据（04 §3.10）。
var _spark: Color = Color.BLACK
var _body: Color = Color.BLACK
var _backdrop: Color = Color.BLACK

## 蓝图里用到的枚举值。在 _initialize 里取自被测脚本，不在这里写死整数。
var _kind_core: int = 0
var _kind_function: int = 0
var _kind_weapon: int = 0
var _fn_none: int = 0
var _fn_split: int = 0
var _fn_amplify: int = 0

var _lines: Array[String] = []
var _fire_ticks: Array[int] = []
## 正在被真实帧驱动的运行时。收回调里靠它读**当时的**节拍号。
var _driven: Object = null


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_h = load(HARNESS_PATH).new()
	_theme = load(THEME_PATH)
	_flow_script = load(GAME_FLOW_PATH)
	_palette = load(PALETTE_PATH)
	_node_script = load(NODE_SCRIPT_PATH)
	_link_script = load(LINK_SCRIPT_PATH)
	_blueprint_script = load(BLUEPRINT_SCRIPT_PATH)

	_spark = _palette.get_color(_palette.Key.BLUE_050)
	_body = _palette.get_color(_palette.Key.BLUE_FX_600)
	_backdrop = _palette.get_color(_palette.Key.NAVY_900)
	_kind_core = int(_node_script.Kind.CORE)
	_kind_function = int(_node_script.Kind.FUNCTION)
	_kind_weapon = int(_node_script.Kind.WEAPON)
	_fn_none = int(_node_script.Function.NONE)
	_fn_split = int(_node_script.Function.SPLIT)
	_fn_amplify = int(_node_script.Function.AMPLIFY)

	_h.backdrop = _backdrop
	_h.fill = _spark
	_h.shadow = _body
	_h.open(self, CANVAS, _backdrop)

	print("")
	print("SMOKE 环境：Godot %s / 渲染驱动 %s / 窗口 %s" % [
		Engine.get_version_info()["string"],
		RenderingServer.get_video_adapter_name(),
		str(DisplayServer.window_get_size()),
	])
	print("SMOKE 判据色：火花芯=BLUE_050%s 弹丸体=BLUE_FX_600%s 底=NAVY_900%s" % [
		_h.color_text(_spark), _h.color_text(_body), _h.color_text(_backdrop),
	])

	_cleanup()
	var written: bool = _write_acceptance_blueprint()
	await process_frame
	await _run_routed_case(written)
	await _run_visibility_case(written)
	_cleanup()
	_finish()


## 验收主线：机器必须在**经路由进入的** COMBAT 场景里真的跑起来。
## 刻意不手工挂场景、也不手摇 tick()：手工挂场景就把「路由是否交得出一个会跑的机器」换掉了。
func _run_routed_case(written: bool) -> void:
	_ctx.begin_case("信号流冒烟 · 经 GameFlow 路由进入 COMBAT（03 §1.1 R1）")
	if not _ctx.check(written, "验收机器应已写入 %s" % TEST_PATH):
		return
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.check(bool(flow.call(&"change_state", _state("MAIN_MENU"))), "BOOT → MAIN_MENU 应被接受")
	await process_frame
	_ctx.check(bool(flow.call(&"change_state", _state("PREPARATION"))), "MAIN_MENU → PREPARATION 应被接受")
	await process_frame
	await process_frame
	var cta: Button = _find(current_scene, "ButtonStartCombat") as Button
	if not _ctx.check(cta != null, "整备界面应有「开始战斗」按钮（R1 指定的唯一入口）"):
		return
	cta.emit_signal(&"pressed")
	await process_frame
	await process_frame
	var combat: Node = current_scene
	if not _ctx.check(combat != null and combat.scene_file_path == COMBAT_SCENE_PATH,
			"点 CTA 后当前场景应是 COMBAT（实际 %s）" % _scene_path()):
		return
	combat.call(&"apply_layout_for", VIEWPORT)

	_ctx.begin_case("信号流冒烟 · 机器在真实帧上跑起来（03 §2）")
	var view: Control = _find(combat, "MachineView") as Control
	if not _ctx.check(view != null, "COMBAT 应有机器视图 MachineView"):
		return
	# 06 §8：机器示意区贴战场下沿，上方留给弹丸与（PET-65 的）敌人生成区。
	_ctx.equal(view.get_global_rect(), Rect2(0.0, BAND_TOP - MACHINE_VIEW_HEIGHT,
		VIEWPORT.x, MACHINE_VIEW_HEIGHT), "机器示意区应贴战场下沿 96 逻辑像素（PET-80 前 48）")

	view.set(&"blueprint_path", TEST_PATH)
	combat.call(&"reload_machine")
	var runtime: Object = view.get(&"runtime")
	if not _ctx.check(runtime != null, "载入验收机器后应建出运行时"):
		return
	_ctx.check(bool(runtime.call(&"has_core")), "验收机器应有 CORE（没有它一步都不会动）")
	_ctx.equal(_heat_text(combat), "0%", "开战瞬间的 `热量` 读数")
	_ctx.check(not _notice_visible(combat), "有机器时不得显示「还没有机器」的提示")
	_ctx.equal(int(runtime.call(&"tick_index")), 0, "刚载入时应停在 0 拍")

	# 探针必须在第一帧之前挂上：晚一拍就抓不到首发。
	_driven = runtime
	runtime.connect(&"weapon_fired", _on_weapon_fired)
	var reached: bool = await _advance_until(runtime, FIRST_FIRE_TICK)
	_driven = null
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, FIRST_FIRE_TICK, _tick_of(runtime)]):
		return
	_ctx.equal(_fire_ticks.size(), 1, "第 %d 拍时应恰好开火一次" % FIRST_FIRE_TICK)
	if _fire_ticks.size() > 0:
		_ctx.equal(_fire_ticks[0], FIRST_FIRE_TICK,
			"首发的**节拍号**（CORE 节拍 %d + %d 条边各 %d 拍）—— 与帧率无关" % [
				CORE_PERIOD, CHAIN_EDGES, TRAVEL])
	_ctx.equal(_heat_text(combat), HEAT_PER_STEP, "首发的 `热量` 读数（每发 +2）")


## 像素取证：同一份 combat.tscn，挂到离屏画布上跑同一台机器，量屏幕上真的出现了什么。
func _run_visibility_case(written: bool) -> void:
	_ctx.begin_case("信号流冒烟 · 信号与弹丸真的画出来了（09 §4 像素取证）")
	if not written:
		return
	var packed: PackedScene = load(COMBAT_SCENE_PATH)
	if not _ctx.check(packed != null, "combat.tscn 应能加载"):
		return
	_h.reset()
	_h.set_canvas_size(CANVAS)
	var scene: Control = packed.instantiate()
	scene.theme = _theme
	_h.adopt(scene)
	await _h.settle()
	scene.size = VIEWPORT
	scene.call(&"apply_layout_for", VIEWPORT)

	var view: Control = _find(scene, "MachineView") as Control
	var driver: Node = _find(scene, "MachineDriver") as Node
	if not _ctx.check(view != null and driver != null, "离屏场景应有机器视图与节拍器"):
		return
	view.set(&"blueprint_path", TEST_PATH)
	scene.call(&"reload_machine")
	var runtime: Object = view.get(&"runtime")
	if not _ctx.check(runtime != null, "离屏场景载入验收机器后应建出运行时"):
		return

	var view_rect: Rect2 = view.get_global_rect()
	# 走廊下沿收在示意区上沿**之上 2 逻辑像素**（PET-80 前 1px）：卡片贴带顶摆，
	# 点亮描边那条描边的外半行落在带外（实测 y=172，点亮的两张卡合 98px）。
	# 不排掉这一行，走廊里的 BLUE_050 就混着描边，判据便不再只讲弹丸 ——
	# 而「弹丸真升起来了」正是这一段要证的。
	# 排除量是**长度**（描边的半行），故随坐标系 ×2：1 → 2。
	var lane: Rect2 = Rect2(0.0, float(LANE_FROM_Y), VIEWPORT.x,
		view_rect.position.y - 2.0 - float(LANE_FROM_Y))
	# 冻结在 0 拍再取第一张：机器静止时画面上不该有判据色 —— 这是下面两条正断言的负对照。
	driver.call(&"bind", null)
	var before: Image = (await _h.settle())["image"]
	if not _ctx.check(before != null, "应能取到离屏图像（本用例不得加 --headless 运行）"):
		return
	var still_sparks: int = _count_rect(before, view_rect, _spark)
	var still_shots: int = _count_rect(before, lane, _spark)
	_ctx.check(still_sparks == 0,
		"负对照：静止的机器在示意区内不该有一个火花像素（实际 %d）" % still_sparks)
	_ctx.check(still_shots == 0,
		"负对照：静止的机器在弹丸走廊内不该有像素（实际 %d）" % still_shots)
	_save(before, "before")
	# 数字也印进日志：证据不止「这一条绿了」，还要看得见量到了多少像素。
	print("SMOKE 像素取证 · 第 0 拍（冻结）：示意区 BLUE_050 = %d px，走廊 BLUE_050 = %d px（负对照，均应为 0）"
		% [still_sparks, still_shots])

	# 解冻、等真实帧推到取样拍、再冻结 —— 冻结后画面不再变，像素断言与证据图都可复现。
	driver.call(&"bind", runtime)
	var reached: bool = await _advance_until(runtime, SAMPLE_TICK)
	driver.call(&"bind", null)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍" % [WALL_CLOCK_BUDGET_MS, SAMPLE_TICK]):
		return
	var at: int = _tick_of(runtime)
	_ctx.check(at >= FIRST_FIRE_TICK and at <= FIRST_FIRE_TICK + MAX_CATCH_UP,
		"取样拍号应落在 [%d, %d]（实际第 %d 拍）—— 下面两条像素断言依赖它落在弹丸存活期内" % [
			FIRST_FIRE_TICK, FIRST_FIRE_TICK + MAX_CATCH_UP, at])
	_ctx.equal(_heat_text(scene), HEAT_PER_STEP, "取样时的 `热量` 读数")

	var after: Image = (await _h.settle())["image"]
	if not _ctx.check(after != null, "应能取到离屏图像"):
		return
	var sparks: int = _count_rect(after, view_rect, _spark)
	var shots: int = _count_rect(after, lane, _spark)
	var bodies: int = _count_rect(after, lane, _body)
	_ctx.check(sparks > 0,
		"运行中的机器在示意区内应有信号火花（BLUE_050，实际 %d px）—— 信号在连线与节点上可见" % sparks)
	_ctx.check(shots > 0,
		"开火后弹丸走廊内应升起占位弹丸（弹丸芯 BLUE_050，实际 %d px）—— 武器真的开火了" % shots)
	_ctx.check(bodies > 0,
		"弹丸应有 04 §3.10 的中间层（弹丸体 BLUE_FX_600，实际 %d px）—— 该色全画面只此一处，三层 FX 缺一层即打回" % bodies)
	_save(after, "after")
	print("SMOKE 像素取证 · 第 %d 拍（冻结）：示意区 BLUE_050 = %d px（信号火花 + 点亮描边），走廊内 弹丸芯 BLUE_050 = %d px、弹丸体 BLUE_FX_600 = %d px"
		% [at, sparks, shots, bodies])

	# 负对照：藏掉示意区，两处判据色必须整体归零 —— 归零失败说明数到的像素并非来自这块视图。
	view.visible = false
	var hidden: Image = (await _h.settle())["image"]
	_ctx.check(_count_rect(hidden, view_rect, _spark) == 0,
		"负对照：藏掉示意区后火花像素应归零（实际 %d）" % _count_rect(hidden, view_rect, _spark))
	_ctx.check(_count_rect(hidden, lane, _spark) == 0,
		"负对照：藏掉示意区后弹丸像素应归零（实际 %d）" % _count_rect(hidden, lane, _spark))
	view.visible = true


## 写验收机器的蓝图：CORE → Split → Amplify → Needle（卡面点名的那一台）。
## 走数据类落盘，于是这份图与玩家在整备界面拖出来的是同一种东西，机器重建也走同一条路（09 §3.2）。
func _write_acceptance_blueprint() -> bool:
	var blueprint: Resource = _blueprint_script.new()
	var spec: Array = [
		["core", "核心", _kind_core, _fn_none],
		["split", "分流", _kind_function, _fn_split],
		["amp", "增幅", _kind_function, _fn_amplify],
		["needle", "针", _kind_weapon, _fn_none],
	]
	for item: Array in spec:
		var node: Resource = _node_script.new()
		node.set(&"id", StringName(item[0]))
		node.set(&"display_name", String(item[1]))
		node.set(&"kind", int(item[2]))
		node.set(&"function_kind", int(item[3]))
		blueprint.get(&"nodes").append(node)
	var edges: Array = [["core", "split"], ["split", "amp"], ["amp", "needle"]]
	for edge: Array in edges:
		var link: Resource = _link_script.new()
		link.set(&"from_node_id", StringName(edge[0]))
		link.set(&"from_port", &"out")
		link.set(&"to_node_id", StringName(edge[1]))
		link.set(&"to_port", &"in")
		blueprint.get(&"connections").append(link)
	_ctx.equal(blueprint.get(&"nodes").size(), spec.size(), "验收机器应有 4 个节点")
	_ctx.equal(blueprint.get(&"connections").size(), edges.size(), "验收机器应有 3 条连线")
	return bool(blueprint.call(&"save_to", TEST_PATH))


## 等真实帧把机器推到 target 拍。上限用的是**墙钟**（用例不得挂死），
## 但判据是节拍号 —— 帧率高低只影响耗时，不影响结论（03 §6）。
func _advance_until(runtime: Object, target: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + WALL_CLOCK_BUDGET_MS
	while _tick_of(runtime) < target and Time.get_ticks_msec() < deadline:
		await process_frame
	return _tick_of(runtime) >= target


func _on_weapon_fired(_weapon_id: StringName) -> void:
	if _driven != null:
		_fire_ticks.append(_tick_of(_driven))


func _tick_of(runtime: Object) -> int:
	return int(runtime.call(&"tick_index"))


## 某一格矩形内的判据色像素数。矩形先夹回图像范围，越界的取样一律不数。
func _count_rect(image: Image, rect: Rect2, wanted: Color) -> int:
	if image == null:
		return 0
	var extent: Vector2i = image.get_size()
	var from_x: int = clampi(int(rect.position.x), 0, extent.x)
	var to_x: int = clampi(int(rect.end.x), 0, extent.x)
	var from_y: int = clampi(int(rect.position.y), 0, extent.y)
	var to_y: int = clampi(int(rect.end.y), 0, extent.y)
	var hits: int = 0
	for y: int in range(from_y, to_y):
		hits += _h.count_row(image, y, from_x, to_x, wanted)
	return hits


## 存证据图：原图与最近邻放大各一张。放大是为了让 12×12 的火花（PET-80 前 6×6）
## 在人工复核时看得见。
func _save(image: Image, tag: String) -> void:
	_ctx.check(image.save_png(SHOT_PATH + tag + ".png") == OK, "应能写出证据图 %s.png" % tag)
	var big: Image = Image.new()
	big.copy_from(image)
	big.resize(CANVAS.x * ZOOM, CANVAS.y * ZOOM, Image.INTERPOLATE_NEAREST)
	_ctx.check(big.save_png("%s%s_%dx.png" % [SHOT_PATH, tag, ZOOM]) == OK,
		"应能写出 %d× 放大的证据图 %s" % [ZOOM, tag])


func _heat_text(combat: Node) -> String:
	var block: Node = _find(combat, "Heat")
	if block == null:
		return ""
	var value: Label = block.get_node_or_null(^"Value") as Label
	return value.text if value != null else ""


func _notice_visible(combat: Node) -> bool:
	var label: Label = _find(combat, "NoticeLabel") as Label
	return label != null and label.visible


## 清掉测试产物。正式存档目录一概不碰。
func _cleanup() -> void:
	if not FileAccess.file_exists(TEST_PATH):
		return
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir != null:
		dir.remove(TEST_PATH.get_file())


## 按名字找节点。刻意不用 `%` 唯一名：子场景实例的唯一名作用域挂在各自 owner 上，
## 跨子场景边界时语义容易出意外；按名字搜是确定的（同 combat_smoke.gd）。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


func _scene_path() -> String:
	return String(current_scene.scene_file_path) if current_scene != null else ""


func _state(state_name: String) -> int:
	return int(_flow_script.GameState[state_name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：FIRST PLAYABLE 2/4（PET-64）机器运行：CORE 信号 + FUNCTION 三件 + WEAPON 开火 + 基础 Heat")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %s / 渲染驱动 %s" % [
		version["string"], str(DisplayServer.window_get_size()),
		RenderingServer.get_video_adapter_name()])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：经路由进 COMBAT(点 CTA) · 验收机器 CORE→Split→Amplify→Needle 在真实帧上跑起来 · 首发拍号 · `热量` 读数 · 信号火花与占位弹丸的像素取证")
	_lines.append("- 证据图：%s{before,after}.png 与 %s{before,after}_%dx.png" % [SHOT_PATH, SHOT_PATH, ZOOM])
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\signal_flow_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("signal_flow_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
