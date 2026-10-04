## full_loop_smoke.gd
## 职责：**一局完整循环**的集成取证（FIRST PLAYABLE 4/4）——
##       两张波次表条数一致；3 波各自的敌人配置都能真的开打；
##       走完 MAIN_MENU → PREPARATION → COMBAT(1) → REWARD → PREPARATION → COMBAT(2) → REWARD
##       → PREPARATION → COMBAT(3) → RESULT →「再来一局」→ COMBAT(1) 这一整圈，
##       并逐跳核对状态 / 场景 / `波次` 读数 / 结算的坚持波数；收尾还原到 MAIN_MENU 且不留节点泄漏。
## 所属系统：tests（集成层）
## 依赖：test_context, scripts/core/{game_flow,run_state}.gd, scripts/gameplay/combat_simulation.gd,
##       scenes/{menu,preparation,combat,reward,result}/*.tscn
## 禁止：本文件不得写任何字面色值；场景路径的**期望值**独立复写（不转抄 GameFlow.SCENE_ROUTES），
##       但「将要走哪条路」一律问 GameFlow 要。
##
## 为什么能进 run_tests.gd（其它场景冒烟都得独立进程）：它排在 TEST_SCRIPTS **末尾**，
## test_state_loop.gd 的断言此时已全部跑完，而本用例收尾把状态还原到 MAIN_MENU。
##
## 本用例**不等真实战斗打完**：20 拍/秒 × 一波上百拍 × 三波会把整份测试从秒级拖成分钟级，
## 还把结果绑到机器负载上。波次推进走的是仿真清空时调用的那个**语义入口** on_wave_cleared()，
## 与 result_smoke.gd 走 on_core_destroyed() 是同一个做法。
## 「敌人真的会死、波真的会清」由 tests/integration/combat_loop_smoke.gd 在真实帧上取证。
##
## 顺带产出**一局循环的截图序列**（验收卡要的那一段）：每走到一站就留一张，收尾拼成一张联络表。
## 它**只在真实渲染下生效**，headless 入口（run_tests.gd）里静默跳过 —— 故这些图不参与断言，
## 本文件的绿/红只由状态与场景的流转决定。要出图就单独跑一次带窗口的：
##   Godot --path . --resolution 320x180 --fixed-fps 60 --script res://tests/unit/run_tests.gd -- --task "..."
## （窗口必须是设计尺寸 320×180：同进程里 test_state_loop.gd 的合成点击按窗口坐标折算。）

extends RefCounted

const MENU_SCENE_PATH: String = "res://scenes/menu/main_menu.tscn"
const PREP_SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const COMBAT_SCENE_PATH: String = "res://scenes/combat/combat.tscn"
const REWARD_SCENE_PATH: String = "res://scenes/reward/reward.tscn"
const RESULT_SCENE_PATH: String = "res://scenes/result/result.tscn"

## 06 §8.1 的 `波次` 读数：`当前/总数`。
const WAVE_FORMAT: String = "%d/%d"
## RESULT 的波次读数（与 result_screen.gd 的 WAVE_FORMAT_KEY 同字面，独立复写一遍）。
const RESULT_WAVE_FORMAT: String = "坚持到第 %d 波"

## 三张卡的节点名，顺序即 `RewardLayout` 的列序。
const CARD_NAMES: PackedStringArray = ["Card0", "Card1", "Card2"]

## 本用例这一局的固定种子（03 §6：随机必须可复现，故不写 SEED_AUTO）。
const LOOP_SEED: int = 20261004

## 截图：每一站一张（序号即玩家走到的顺序），收尾再拼一张联络表。
const SHOT_PREFIX: String = "res://tests/output/full_loop_"
const SHEET_PATH: String = "res://tests/output/full_loop_sheet.png"
## 联络表的列数与放大倍数。单图 320×180 直接拼成一排读不清，放大后再拼。
const SHEET_COLUMNS: int = 5
const SHEET_ZOOM: int = 2
## 一格的设计尺寸（06 §1 基准，本文件独立复写）。
const FRAME_SIZE: Vector2i = Vector2i(320, 180)
## 截图用的机器落盘位置。**不落进 BlueprintData.DEFAULT_SAVE_DIR** ——
## 正式存档目录只归玩家的游戏写（同 combat_loop_smoke.gd 的约束）。
const SHOT_BLUEPRINT_PATH: String = "user://test_blueprints/_full_loop_machine.tres"
## 战斗那一站拍到第几拍。取值要**早于本波最后一只的出场拍**（第 1/2/3 波分别是 70 / 110 / 150），
## 否则仿真会自己把这一波清空、把场景路由走，后面手动触发的清空就落空了。
const SHOT_TICK: int = 50
## 等这一拍时的帧数上限。到了就照拍，不挂死。
const SHOT_FRAME_CAP: int = 1200

## PET-65 取证时第 1 波的那四只。第 1 波**必须**保持原样 ——
## combat_loop_smoke.gd 的击杀拍号与截图都按它取样。
const WAVE_ONE: Array = [
	EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER, EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER,
]

var _tree: SceneTree = null
var _flow: Node = null
var _flow_script: GDScript = null
var _run_state: Node = null
## 进入循环之前的节点数基线。09 §3.1 的「无内存 / 节点泄漏」以它为唯一参照。
var _baseline: Dictionary = {}
## 这一局各站的截图（按走到顺序）。headless 下始终为空。
var _frames: Array[Image] = []


func run(ctx: RefCounted, tree: SceneTree) -> void:
	_tree = tree
	_flow = tree.root.get_node_or_null(NodePath("GameFlow"))
	_run_state = tree.root.get_node_or_null(NodePath("RunState"))
	if not ctx.check(_flow != null and _run_state != null, "GameFlow / RunState 应可用"):
		return
	_flow_script = _flow.get_script()

	_run_wave_table_case(ctx)
	_baseline = _snapshot()
	await _run_loop_case(ctx)
	_run_leak_case(ctx)
	_compose_sheet()


## 两张波次表必须一致：`RunState.TOTAL_WAVES` 是「一局有多长」的唯一来源，
## 敌人配置表在 gameplay 侧（core 不得反向依赖上层）。两张表一旦漂开，
## 症状是「第 3 波打到一半忽然结算」或「打完了却没有第 3 波」，两者都不会报错。
func _run_wave_table_case(ctx: RefCounted) -> void:
	ctx.begin_case("波次表 · 两张表条数一致且每波都能开打")
	var total: int = int(_run_state.get_script().TOTAL_WAVES)
	ctx.equal(CombatSimulation.WAVES.size(), total,
		"敌人配置表的条数必须等于 RunState.TOTAL_WAVES")
	ctx.check(total >= 2, "一局至少要两波，否则「打完一波回整备再打下一波」这条回路走不通")
	ctx.equal(int(_run_state.get_script().FIRST_WAVE), 1, "波次从 1 起（读数写成人读的 n/N）")

	for index: int in total:
		ctx.check(CombatSimulation.WAVES[index].size() > 0, "第 %d 波不得是空表" % (index + 1))
	ctx.equal(CombatSimulation.WAVES[0], WAVE_ONE, "第 1 波的敌人序列（PET-65 的取证值）")
	# 难度靠出怪条数递增。反过来（越往后越少）说明两张表接错了顺序，而画面上一时看不出来。
	for index: int in range(1, total):
		ctx.check(CombatSimulation.WAVES[index].size() >= CombatSimulation.WAVES[index - 1].size(),
			"第 %d 波的条数不应少于上一波" % (index + 1))

	# 每一波都要能真的用起来：wave_index 从 1 起，越界一律夹进表内。
	var blueprint: BlueprintData = _machine_blueprint()
	for index: int in total:
		var sim: CombatSimulation = CombatSimulation.new(blueprint, index + 1)
		ctx.equal(sim.wave_index(), index + 1, "第 %d 场的 wave_index" % (index + 1))
		ctx.equal(sim.wave_size(), CombatSimulation.WAVES[index].size(),
			"第 %d 场出的敌人条数" % (index + 1))
		for _tick: int in 5:
			sim.tick()
		ctx.check(not sim.is_over(), "第 %d 场空跑 5 拍不得已经分出结果" % (index + 1))
	ctx.equal(CombatSimulation.new(blueprint, 0).wave_index(), 1, "越界的小值应夹进第 1 波")
	ctx.equal(CombatSimulation.new(blueprint, total + 5).wave_index(), total, "越界的大值应夹进末波")


## 一整圈：状态起点由 test_state_loop.gd 的收尾给出（MAIN_MENU）；
## **一局的进度必须由本用例自己归零** —— 见下面两句的说明。
func _run_loop_case(ctx: RefCounted) -> void:
	ctx.begin_case("完整循环 · 第 1 波 → 奖励 → 整备 → 第 2 波")
	ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "起点应是 MAIN_MENU")

	# 这里不能假设「起点没有进行中的一局」：test_state_loop.gd 的 R1 停留用例会真的进 COMBAT
	# 并调 on_wave_cleared()（波次因此被推到 2），而战斗界面只在 `not is_active()` 时才开新的一局
	# —— 那个残留会一路带进本用例，症状是「第 1 波的读数是 2/3」。故先把一局掐掉再重开：
	# end_run() **刻意保留波次**（那是 RESULT 的读数来源），波次的复位归 start_run()，两句都要。
	if bool(_run_state.call(&"is_active")):
		_run_state.call(&"end_run")
	_run_state.call(&"start_run", LOOP_SEED)
	ctx.check(bool(_run_state.call(&"is_active")), "起点应有一局在进行")
	ctx.equal(int(_run_state.call(&"current_wave")), 1, "起点应是第 1 波")

	await _shoot("01_menu")

	var total: int = int(_run_state.get_script().TOTAL_WAVES)
	ctx.check(_goto("PREPARATION"), "MAIN_MENU → PREPARATION")
	await _settle()
	ctx.equal(_scene_path(), PREP_SCENE_PATH, "整备场景")
	await _shoot("02_preparation")

	var combat: Node = await _start_combat()
	if not ctx.check(combat != null and combat.scene_file_path == COMBAT_SCENE_PATH,
			"点「开始战斗」应进入 COMBAT（实际 %s）" % _scene_path()):
		return
	ctx.check(bool(_run_state.call(&"is_active")), "开打应意味着一局已经开始")
	ctx.equal(_wave_readout(combat), WAVE_FORMAT % [1, total], "第 1 波的 `波次` 读数")
	await _shoot_combat(combat, "03_combat_wave1")

	# 第 1 波清空：非末波，进 REWARD 并把进度推到第 2 波。
	combat.call(&"on_wave_cleared")
	await _settle()
	ctx.equal(int(_run_state.call(&"current_wave")), 2, "第 1 波清空应推进到第 2 波")
	ctx.equal(_state_of_flow(), _state("REWARD"), "非末波清空应进 REWARD")
	ctx.equal(_scene_path(), REWARD_SCENE_PATH, "奖励场景")
	ctx.check(not is_instance_valid(combat), "离开 COMBAT 后旧场景应被释放")

	# 三选一：三张卡都必须是**真实选项**，不是补齐出来的「跳过」。
	var reward: Node = _tree.current_scene
	for index: int in CARD_NAMES.size():
		var card: Control = _find(reward, CARD_NAMES[index]) as Control
		if not ctx.check(card != null, "奖励场景应有 %s" % CARD_NAMES[index]):
			continue
		var option: Variant = card.call(&"get_option")
		ctx.check(option != null and not bool(option.is_skip()),
			"%s 应是真实选项（本批起不再是占位池）" % CARD_NAMES[index])

	await _shoot("04_reward")

	var first_card: Control = _find(reward, CARD_NAMES[0]) as Control
	if not ctx.check(first_card != null, "应有可点的第 1 张卡"):
		return
	_click(first_card, true)
	await _settle()
	ctx.equal(_state_of_flow(), _state("PREPARATION"), "选定奖励后应回 PREPARATION")
	ctx.equal(_scene_path(), PREP_SCENE_PATH, "回整备继续改造机器（蓝图原样保留）")
	ctx.equal(int(_run_state.call(&"current_wave")), 2, "选奖励不该改动波次")
	await _shoot("05_preparation_wave2")

	ctx.begin_case("完整循环 · 第 2 波 → 奖励 → 整备 → 第 3 波")
	combat = await _start_combat()
	if not ctx.check(combat != null, "应能再次开打（第 2 波）"):
		return
	ctx.equal(_wave_readout(combat), WAVE_FORMAT % [2, total], "第 2 波的 `波次` 读数")
	await _shoot_combat(combat, "06_combat_wave2")
	combat.call(&"on_wave_cleared")
	await _settle()
	ctx.equal(int(_run_state.call(&"current_wave")), 3, "第 2 波清空应推进到第 3 波")
	ctx.equal(_state_of_flow(), _state("REWARD"), "第 2 波清空仍应进 REWARD")

	first_card = _find(_tree.current_scene, CARD_NAMES[0]) as Control
	if not ctx.check(first_card != null, "第 2 次奖励也应有卡可点"):
		return
	_click(first_card, true)
	await _settle()
	ctx.equal(_state_of_flow(), _state("PREPARATION"), "第二次选定后应回 PREPARATION")

	ctx.begin_case("完整循环 · 第 3 波（末波）→ RESULT → 再来一局")
	combat = await _start_combat()
	if not ctx.check(combat != null, "应能开打末波"):
		return
	ctx.equal(_wave_readout(combat), WAVE_FORMAT % [3, total], "第 3 波的 `波次` 读数")
	ctx.check(bool(_run_state.call(&"is_final_wave")), "第 3 波应是末波")
	await _shoot_combat(combat, "07_combat_wave3")

	combat.call(&"on_wave_cleared")
	await _settle()
	ctx.equal(_state_of_flow(), _state("RESULT"), "末波清空应进 RESULT（而不是 REWARD）")
	ctx.equal(_scene_path(), RESULT_SCENE_PATH, "结算场景")
	ctx.check(not bool(_run_state.call(&"is_active")), "末波打完本局应已结束")
	ctx.equal(int(_run_state.call(&"current_wave")), 3,
		"结束时波次应停在 3 —— 结算要显示「坚持到第 N 波」，清早了就永远是 1")

	var result: Node = _tree.current_scene
	var wave_label: Label = _find(result, "WaveValue") as Label
	if ctx.check(wave_label != null, "结算场景应有波次读数落点"):
		ctx.equal(wave_label.text, RESULT_WAVE_FORMAT % 3, "结算应显示「坚持到第 3 波」")
	await _shoot("08_result")

	var retry: Button = _find(result, "ButtonRetry") as Button
	if not ctx.check(retry != null, "结算场景应有「再来一局」"):
		return
	retry.emit_signal(&"pressed")
	await _settle()
	ctx.equal(_state_of_flow(), _state("PREPARATION"), "「再来一局」应回 PREPARATION")
	ctx.check(bool(_run_state.call(&"is_active")), "「再来一局」应开新的一局")
	ctx.equal(int(_run_state.call(&"current_wave")), 1, "新的一局必须从第 1 波开始（否则等于没重开）")
	await _shoot("09_retry_preparation")

	combat = await _start_combat()
	if not ctx.check(combat != null, "重开后应能再开打"):
		return
	ctx.equal(_wave_readout(combat), WAVE_FORMAT % [1, total], "重开后的第 1 波读数（循环真的回到起点）")

	# 收尾还原：从 COMBAT 结束本局回 RESULT，再回 MAIN_MENU（03 §1 状态图的两条边）。
	combat.call(&"on_core_destroyed")
	await _settle()
	ctx.check(not bool(_run_state.call(&"is_active")), "收尾结束本局后不应留下进行中的一局")
	ctx.check(_goto("MAIN_MENU"), "RESULT → MAIN_MENU")
	await _settle()
	ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "收尾应还原到 MAIN_MENU")
	ctx.equal(_scene_path(), MENU_SCENE_PATH, "收尾场景应与状态成对")


## 09 §3.1：这一圈下来不得留下节点泄漏。判据与 test_state_loop.gd 相同 ——
## children 抓「旧场景只摘不 free」，orphans 抓「摘下来却没 free」。
func _run_leak_case(ctx: RefCounted) -> void:
	ctx.begin_case("完整循环 · 收尾无节点泄漏（09 §3.1）")
	var now: Dictionary = _snapshot()
	ctx.equal(int(now["children"]), int(_baseline["children"]),
		"/root 的子节点数应回到基线 %d（每一跳的旧场景都要被摘干净）" % int(_baseline["children"]))
	ctx.equal(int(now["orphans"]), int(_baseline["orphans"]),
		"孤儿节点数不得增长（基线 %d，实得 %d）—— 旧场景被摘下来却没 free" % [
			int(_baseline["orphans"]), int(now["orphans"])])


## 给当前这一站留一张证据图。**headless 下静默跳过**（dummy 渲染驱动不产像素），
## 故这里一条断言都不写：截不到图不是本用例的失败，它证的是状态与场景的流转。
func _shoot(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _tree.process_frame
	await RenderingServer.frame_post_draw
	var viewport: ViewportTexture = _tree.root.get_texture()
	var image: Image = viewport.get_image() if viewport != null else null
	if image == null:
		return
	var path: String = SHOT_PREFIX + label + ".png"
	if image.save_png(path) != OK:
		return
	_frames.append(image)
	print("SMOKE 循环取证 · 第 %d 站 %s（%dx%d）" % [
		_frames.size(), label, image.get_width(), image.get_height()])


## 战斗那一站的证据图：先给场上装一台机器、让它真的跑起来，再拍。
## 本用例自己不画蓝图（那是整备界面的活），故这里把验收机器 CORE → 针 落到**测试专用目录**
## 再让这一场指向它 —— 落的是数据类，与玩家在整备界面拖出来的是同一种东西（09 §3.2）。
## 空战场拍下来什么都证不了：既看不到敌人，也看不到机器在动。
func _shoot_combat(combat: Node, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var view: Node = _find(combat, "MachineView")
	var driver: Node = _find(combat, "MachineDriver")
	if view == null or driver == null:
		return
	var blueprint: BlueprintData = _machine_blueprint()
	if not blueprint.save_to(SHOT_BLUEPRINT_PATH):
		return
	view.set(&"blueprint_path", SHOT_BLUEPRINT_PATH)
	combat.call(&"reload_machine")
	# 固定节拍由 MachineDriver 按真实帧喂（TICK_RATE 20，--fixed-fps 60 下 3 帧 1 拍）。
	var frames: int = 0
	while frames < SHOT_FRAME_CAP:
		var sim: Object = driver.get(&"combat")
		if sim != null and int(sim.call(&"tick_index")) >= SHOT_TICK:
			break
		await _tree.process_frame
		frames += 1
	await _shoot(label)


## 各站拼成一张联络表 —— 一串单图在评论里读不出「这是一条路」。
func _compose_sheet() -> void:
	if _frames.is_empty():
		return
	var cell: Vector2i = FRAME_SIZE * SHEET_ZOOM
	var rows: int = int(ceilf(float(_frames.size()) / float(SHEET_COLUMNS)))
	var sheet: Image = Image.create_empty(cell.x * SHEET_COLUMNS, cell.y * rows, false,
		Image.FORMAT_RGBA8)
	for index: int in _frames.size():
		var frame: Image = _frames[index].duplicate() as Image
		frame.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, cell),
			Vector2i(index % SHEET_COLUMNS, index / SHEET_COLUMNS) * cell)
	if sheet.save_png(SHEET_PATH) == OK:
		print("SMOKE 循环取证 · 联络表 %s（%d 站，%dx%d）" % [
			SHEET_PATH, _frames.size(), sheet.get_width(), sheet.get_height()])


## 点整备界面的 CTA 并返回新的 COMBAT 场景。找不到按钮时返回 null，由调用方断言。
func _start_combat() -> Node:
	var prep: Node = _tree.current_scene
	var cta: Button = _find(prep, "ButtonStartCombat") as Button
	if cta == null:
		return null
	cta.emit_signal(&"pressed")
	await _settle()
	return _tree.current_scene


## 让一次切换落完：路由走 call_deferred（game_flow.gd 的 _apply_scene_change），
## 换场景要到下一帧才发生。两帧是既有用例（result_smoke.gd）的取值，够用且不必轮询。
func _settle() -> void:
	await _tree.process_frame
	await _tree.process_frame


## 06 §8.1 的 `波次` 读数。取值路径与 combat_screen.gd 一致：读数块（`Wave`）下的 `Value`。
func _wave_readout(combat: Node) -> String:
	var block: Node = _find(combat, "Wave")
	if block == null:
		return ""
	var value: Label = block.get_node_or_null(^"Value") as Label
	return value.text if value != null else ""


## 把一次左键**按下**送到卡片的 gui_input 上（抬起不算选定，故不送）。
##
## 走 gui_input 而不是 Input.parse_input_event()：后者的 GUI 命中测试依赖视口尺寸，
## 而 headless 下根窗口是 0×0。卡片是不是真的铺在那个矩形上归 reward_probe.gd 的像素取证。
func _click(card: Control, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = card.get_global_rect().get_center()
	card.gui_input.emit(event)


## 验收卡点名的那台机器：CORE →-- 针。够建武器表、够跑起来，且不牵扯 FUNCTION。
func _machine_blueprint() -> BlueprintData:
	var blueprint: BlueprintData = BlueprintData.new()
	var core := NodeData.new()
	core.id = &"core"
	core.display_name = "核心"
	core.kind = NodeData.Kind.CORE
	var needle := NodeData.new()
	needle.id = &"needle"
	needle.display_name = "针"
	needle.kind = NodeData.Kind.WEAPON
	blueprint.nodes.append(core)
	blueprint.nodes.append(needle)
	var edge := ConnectionData.new()
	edge.from_node_id = &"core"
	edge.from_port = &"out"
	edge.to_node_id = &"needle"
	edge.to_port = &"in"
	blueprint.connections.append(edge)
	return blueprint


func _snapshot() -> Dictionary:
	return {
		"children": _tree.root.get_child_count(),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


func _goto(state_name: String) -> bool:
	return bool(_flow.call(&"change_state", _state(state_name)))


func _state_of_flow() -> int:
	return int(_flow.call(&"get_state"))


func _state(state_name: String) -> int:
	return int(_flow_script.GameState[state_name])


func _scene_path() -> String:
	return String(_tree.current_scene.scene_file_path) if _tree.current_scene != null else ""


## 按名字找节点。刻意不用 `%` 唯一名：子场景实例的唯一名作用域挂在各自 owner 上，
## 跨子场景边界时语义容易出意外；按名字搜是确定的（同 combat_smoke.gd）。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false) if node != null else null
