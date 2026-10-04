## combat_loop_smoke.gd
## 职责：战斗闭环的**真实运行**取证（FIRST PLAYABLE 3/4）—— 经 GameFlow 路由进 COMBAT 之后，
##       一波敌人由 MachineDriver 按固定节拍真的生成、真的推进，武器真的命中、敌人真的消失，
##       一波全灭真的走到 REWARD 出口，敌人抵达终点真的把 CORE 读数打下去 ——
##       并且这些事在画面上**真的看得见**（敌人判据色的像素证据 + 截图）。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, render_probe_harness, Palette, assets/ui/theme_main.tres,
##       scenes/combat/combat.tscn, scripts/ui/combat_screen.gd,
##       scripts/gameplay/{machine_driver,combat_simulation,enemy_state,enemy_data}.gd,
##       scripts/data/{node_data,connection_data,blueprint_data}.gd
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素，最后一段取不到图像）；
##       不得引用 Autoload 标识符 —— 它是 --script 入口，在工程注册这些之前就被编译
##       （同 combat_smoke.gd / signal_flow_smoke.gd 的约束），一律 load() + 经 /root 取节点；
##       不得写任何字面色值 —— 判据色一律经 Palette 取；
##       不得落进 BlueprintData.DEFAULT_SAVE_DIR（正式存档目录只归玩家的游戏写）。
##
## 为什么不挂进 run_tests.gd：本用例要真的把 GameFlow 推到 COMBAT 并让路由换掉当前场景，
## 留在同一进程会污染 test_state_loop.gd 的状态机断言（与 combat_smoke.gd 同一条理由）。
##
## 为什么这里用真实帧、而单元测试手摇 tick()：本文件要证的正是「MachineDriver 把真实帧时间
## 换成固定节拍、并且驱动的是**整场战斗**而不是光一台机器」这一层，手摇就把它换掉了。
## 判据仍然是**节拍号**不是真实耗时（03 §6），故帧率高低只影响耗时，不影响结论。
##
## 为什么截图走离屏画布：像素要 1:1 可读，而窗口尺寸受系统显示缩放影响
## （同 combat_probe.gd / signal_flow_smoke.gd）。离屏用的是**同一个** combat.tscn。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   负对照一 —— 冻结在 0 拍时，两条泳道内一个判据色像素都不该有（下面每条正断言的前提）。
##   负对照二 —— 藏掉 EnemyLayer，两条泳道的判据色必须整体归零（证明像素确实来自这一层）。
##   负对照三 —— 第 20 拍量的是第 0 道、第 74 拍量的是第 1 道：同一次取样里另一条道必须是 0，
##               于是「量到了」与「整块画布上都有」分得开 —— 像素确实跟着敌人走。
##   拍号绝对值 —— 清空在第 82 拍、漏怪在第 80 拍，都是算得出的绝对值，不是「跑够了就算过」：
##               生成间隔、推进速度、武器伤害、尸体停留、CORE 血量任一环改了都会转红。

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
const LOG_PATH: String = "res://tests/output/combat_loop_smoke.log"
const SHOT_PATH: String = "res://tests/output/combat_loop_"

## 测试专用落盘目录，与正式存档目录刻意分开。
const TEST_DIR: String = "user://test_blueprints"
## 验收机器甲：CORE → 分流 → 针 ×2。两把针把伤害翻倍，四只敌人才能在漏掉之前全部被打死。
const CLEAR_PATH: String = TEST_DIR + "/_combat_loop_clear.tres"
## 验收机器乙：只有 CORE。它一把武器都没有，于是敌人只会一路走到终点 —— 用来取「漏怪扣血」的证据。
const BARE_PATH: String = TEST_DIR + "/_combat_loop_bare.tres"

## 画布 = 06 §1 的 320×180 基准，于是「第几个像素」可以直接读。
const CANVAS: Vector2i = Vector2i(320, 180)
const VIEWPORT: Vector2 = Vector2(320.0, 180.0)

## 敌人泳道的绘制参数（combat_screen.gd 的表现层常数，本文件独立复写）。
## 取整条道的高度而不是逐只算矩形：敌人**自己往前走**，逐只算矩形就等于把被测的推进
## 又抄进了判据里，位置算错时两边一起错。
const ENEMY_BAND_TOP: float = 32.0
const ENEMY_ROW_HEIGHT: float = 24.0

## 放大倍数：8×8 的占位敌人在一张 320×180 的图里几乎看不出来，证据图放大后再附。
const ZOOM: int = 4

## 03 §2 与本卡的固定常数，独立复写一遍 —— 期望值若与被测实现同源，实现改错时两边一起错。
const CORE_PERIOD: int = 10
const TRAVEL: int = 4
const SPAWN_FIRST: int = 10
const SPAWN_EVERY: int = 20
## 验收机器甲的两把针落在分流之后：CORE 节拍 + 2 条边各 4 拍。
const FIRST_FIRE_TICK: int = CORE_PERIOD + TRAVEL * 2
## 机器甲的一波四只分别在 28 / 38 / 68 / 78 拍被打死，最后一只的尸体在第 82 拍退场 → 本波清空。
const CLEAR_TICK: int = 82
## 机器乙：Runner 第 30 拍出场、每拍 0.02 进度，50 拍走完全程 → 第 80 拍抵达终点。
const LEAK_TICK: int = 80
const LEAK_READOUT: String = "75%"

## 取样拍号。全部选在「往前推 MAX_CATCH_UP 拍也仍然成立」的窗口里 ——
## MachineDriver 单帧最多推进 5 拍，故取样点最多过冲 5 拍，下面每条断言都不受它影响。
##   第 20 拍：第 1 只（Slime，第 10 拍出场）活着且已走了一段；第 2 只还没出场。
const SAMPLE_SPAWN: int = 20
##   第 74 拍：第 3 只（Slime，第 68 拍被打死）已在第 72 拍退场，第 0 道空；第 4 只（Runner）还在。
const SAMPLE_KILLED: int = 74
const MAX_CATCH_UP: int = 5
## 墙钟上限：用例不得挂死（同 run_tests.gd 的兜底）。判据是节拍号，不是这个数。
const WALL_CLOCK_BUDGET_MS: int = 30_000

var _ctx: RefCounted = null
var _h: RefCounted = null
var _theme: Theme = null
var _node_script: GDScript = null
var _link_script: GDScript = null
var _blueprint_script: GDScript = null
var _flow_script: GDScript = null
var _palette: GDScript = null

## 判据色：Slime 身体（04 §3.7 危险暗部）/ Runner 身体（危险亮部）/ 画布底。
var _slime: Color = Color.BLACK
var _runner: Color = Color.BLACK
var _backdrop: Color = Color.BLACK

## 蓝图里用到的枚举值。在 _initialize 里取自被测脚本，不在这里写死整数。
var _kind_core: int = 0
var _kind_function: int = 0
var _kind_weapon: int = 0
var _fn_none: int = 0
var _fn_split: int = 0

var _lines: Array[String] = []

## 经路由进入的 COMBAT 场景，以及它身上的机器视图与节拍器。
## 场景被路由换掉之后（本波清空 → REWARD）这三个引用全部置空 —— 它们指向的节点已被释放。
var _combat: Node = null
var _view: Control = null
var _driver: Node = null


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_h = load(HARNESS_PATH).new()
	_theme = load(THEME_PATH)
	_flow_script = load(GAME_FLOW_PATH)
	_palette = load(PALETTE_PATH)
	_node_script = load(NODE_SCRIPT_PATH)
	_link_script = load(LINK_SCRIPT_PATH)
	_blueprint_script = load(BLUEPRINT_SCRIPT_PATH)

	_slime = _palette.get_color(_palette.Key.RED_600)
	_runner = _palette.get_color(_palette.Key.RED_500)
	_backdrop = _palette.get_color(_palette.Key.NAVY_900)
	_kind_core = int(_node_script.Kind.CORE)
	_kind_function = int(_node_script.Kind.FUNCTION)
	_kind_weapon = int(_node_script.Kind.WEAPON)
	_fn_none = int(_node_script.Function.NONE)
	_fn_split = int(_node_script.Function.SPLIT)

	_h.backdrop = _backdrop
	_h.fill = _runner
	_h.shadow = _slime
	_h.open(self, CANVAS, _backdrop)

	print("")
	print("SMOKE 环境：Godot %s / 渲染驱动 %s / 窗口 %s" % [
		Engine.get_version_info()["string"],
		RenderingServer.get_video_adapter_name(),
		str(DisplayServer.window_get_size()),
	])
	print("SMOKE 判据色：Slime=RED_600%s Runner=RED_500%s 底=NAVY_900%s" % [
		_h.color_text(_slime), _h.color_text(_runner), _h.color_text(_backdrop),
	])

	_cleanup()
	var clear_written: bool = _write_clear_blueprint()
	var bare_written: bool = _write_bare_blueprint()
	await process_frame
	# 顺序是有意的：漏怪那一局（机器乙，没有武器）不会分出胜负，场景留在 COMBAT；
	# 清空那一局（机器甲）会把场景路由去 REWARD，故它必须排在最后 —— 它之后就没有 COMBAT 场景了。
	await _run_leak_case(bare_written)
	await _run_spawn_case(clear_written)
	await _run_clear_case()
	await _run_pixel_case(clear_written)
	_cleanup()
	_finish()


## 敌人抵达终点 → CORE 掉血。这条用一台**没有任何武器**的机器来取：
## 敌人只会一路走到终点，于是「漏怪扣血」与「打死敌人」两件事在证据上分得开。
##
## 本函数顺带把场景经 GameFlow 路由进 COMBAT —— 刻意不手工挂场景、也不手摇 tick()：
## 手工挂场景就把「路由是否交得出一场会打的战斗」换掉了（03 §1.1 R1）。
func _run_leak_case(written: bool) -> void:
	_ctx.begin_case("战斗冒烟 · 经 GameFlow 路由进入 COMBAT（03 §1.1 R1）")
	if not _ctx.check(written, "验收机器乙应已写入 %s" % BARE_PATH):
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
	_combat = current_scene
	if not _ctx.check(_combat != null and _combat.scene_file_path == COMBAT_SCENE_PATH,
			"点 CTA 后当前场景应是 COMBAT（实际 %s）" % _scene_path()):
		return
	_combat.call(&"apply_layout_for", VIEWPORT)

	_ctx.begin_case("战斗冒烟 · 敌人抵达终点 → CORE 读数掉血（03 §1.1 R2）")
	_view = _find(_combat, "MachineView") as Control
	_driver = _find(_combat, "MachineDriver") as Node
	if not _ctx.check(_view != null and _driver != null, "COMBAT 应有机器视图与节拍器"):
		return
	_view.set(&"blueprint_path", BARE_PATH)
	_combat.call(&"reload_machine")
	# 本节拍器驱动的必须是**整场战斗**而不是光一台机器：驱动错了对象，敌人一步都不会动，
	# 而症状只是「机器在跑、战场是空的」。
	var sim: Object = _driver.get(&"combat")
	if not _ctx.check(sim != null, "载入验收机器后，节拍器应驱动一场战斗（CombatSimulation）"):
		return
	_ctx.equal(_driver.get(&"runtime"), null, "两种驱动对象互斥：驱动战斗时不得同时驱动一台裸机器")
	_ctx.equal(_core_text(_combat), "100%", "开战瞬间的 `CORE` 读数")
	_ctx.check(not _notice_visible(_combat), "有机器时不得显示「还没有机器」的提示")
	_ctx.equal(_tick_of(sim), 0, "刚载入时应停在 0 拍")

	var reached: bool = await _advance_until(sim, LEAK_TICK - 1)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, LEAK_TICK - 1, _tick_of(sim)]):
		return
	_ctx.equal(_core_text(_combat), "100%", "第 %d 拍还没有敌人抵达终点，读数不动" % (LEAK_TICK - 1))
	reached = await _advance_until(sim, LEAK_TICK)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, LEAK_TICK, _tick_of(sim)]):
		return
	# CORE_MAX 取 100，故血量本身就是百分比，读数应恰好是 100 - 25 = 75。
	_ctx.equal(_core_text(_combat), LEAK_READOUT,
		"第 %d 拍 Runner 抵达终点，`CORE` 读数应掉一份血（100%% → %s）" % [LEAK_TICK, LEAK_READOUT])
	_ctx.check(not bool(sim.call(&"is_cleared")), "漏了怪的这一局不得算清空")


## 敌人真的出场、真的往前走 —— 在**真实帧**上，而不是手工手摇 tick()。
func _run_spawn_case(written: bool) -> void:
	_ctx.begin_case("战斗冒烟 · 敌人真的出场并按固定节拍推进（03 §2 / 03 §6）")
	if not _ctx.check(written, "验收机器甲应已写入 %s" % CLEAR_PATH):
		return
	if not _ctx.check(is_instance_valid(_combat), "上一步之后应还停在 COMBAT 场景"):
		return
	_view.set(&"blueprint_path", CLEAR_PATH)
	_combat.call(&"reload_machine")
	var sim: Object = _driver.get(&"combat")
	if not _ctx.check(sim != null, "换图后节拍器应驱动新的一场战斗"):
		return
	_ctx.equal(_core_text(_combat), "100%", "换图后读数应回到满血")
	_ctx.equal(_tick_of(sim), 0, "换图后应重新从 0 拍开始")

	var reached: bool = await _advance_until(sim, SPAWN_FIRST)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, SPAWN_FIRST, _tick_of(sim)]):
		return
	var first: Object = _enemy(sim, 0)
	if not _ctx.check(first != null, "第 %d 拍应有第 1 只敌人出场" % SPAWN_FIRST):
		return
	_ctx.equal(int(first.get(&"data").get(&"kind")), 0, "第 1 只是 Slime")
	_ctx.equal(int(first.get(&"lane")), 0, "第 1 只走第 0 条道")
	_ctx.equal(int(sim.call(&"enemies").size()), 1, "第 %d 拍场上应恰好 1 只" % SPAWN_FIRST)

	# 同一只敌人在**真实帧**上往前走 —— 这是「推进真的在跑」而不仅仅是「生成了一次」。
	var progress_at_spawn: float = float(first.get(&"progress"))
	reached = await _advance_until(sim, SAMPLE_SPAWN)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, SAMPLE_SPAWN, _tick_of(sim)]):
		return
	_ctx.check(float(first.get(&"progress")) > progress_at_spawn,
		"第 %d 拍时第 1 只应已向前推进（出场时 %.3f → 现在 %.3f）—— 敌人在真实帧上真的在走"
			% [SAMPLE_SPAWN, progress_at_spawn, float(first.get(&"progress"))])
	_ctx.equal(int(sim.call(&"enemies").size()), 1, "第 %d 拍场上仍应是 1 只（第 2 只还没到）" % SAMPLE_SPAWN)

	reached = await _advance_until(sim, SPAWN_FIRST + SPAWN_EVERY)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, SPAWN_FIRST + SPAWN_EVERY, _tick_of(sim)]):
		return
	var second: Object = _enemy(sim, 1)
	if not _ctx.check(second != null, "第 %d 拍应有第 2 只敌人出场" % (SPAWN_FIRST + SPAWN_EVERY)):
		return
	_ctx.equal(int(second.get(&"data").get(&"kind")), 1, "第 2 只是 Runner")
	_ctx.equal(int(second.get(&"lane")), 1, "第 2 只走第 1 条道（与第 1 只错开，不然两只叠成一个方块）")


## 一波全灭 → 路由到 REWARD。这一条同时证明了胜负判定与 R2 那条唯一的边。
## **本函数之后没有 COMBAT 场景了** —— 场景被路由换掉，旧引用全部作废。
func _run_clear_case() -> void:
	_ctx.begin_case("战斗冒烟 · 一波全灭 → 路由到 REWARD（03 §1.1 R2）")
	if not _ctx.check(is_instance_valid(_combat) and is_instance_valid(_driver),
			"上一步之后应还在 COMBAT 场景"):
		return
	var sim: Object = _driver.get(&"combat")
	if not _ctx.check(sim != null, "节拍器应仍驱动着验收机器甲"):
		return
	var reached: bool = await _advance_until(sim, CLEAR_TICK)
	if not _ctx.check(reached, "应在 %d ms 内打到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, CLEAR_TICK, _tick_of(sim)]):
		return
	_ctx.check(bool(sim.call(&"is_cleared")), "第 %d 拍应已本波清空" % CLEAR_TICK)
	_ctx.check(not bool(sim.call(&"is_failed")), "清空的那一局不得同时算失败")
	_ctx.equal(int(sim.call(&"enemies").size()), 0, "清空时场上连尸体都不该剩")
	_ctx.equal(float(sim.call(&"core_hp")), 100.0, "四只全被打死 —— CORE 一滴血都没掉")
	# R2 只给 COMBAT → REWARD 这一条由「本波清空」触发的边。REWARD 场景已就绪，
	# 故此刻当前场景应真的被换掉 —— 这一条同时盖住判定的触发条件与路由本身。
	# 目标路径向 GameFlow 自己问（唯一路由来源），不在这里另抄一份路径。
	var reward_path: String = String(_autoload("GameFlow").call(&"get_scene_path_for", _state("REWARD")))
	if not _ctx.check(not reward_path.is_empty(), "GameFlow 应为 REWARD 登记一个场景路径"):
		return
	var routed: bool = await _await_scene(reward_path)
	_ctx.check(routed, "本波清空后应在若干帧内路由到 REWARD（实际停在 %s）" % _scene_path())
	_ctx.equal(_scene_path(), reward_path, "本波清空应把当前场景换成 REWARD")
	# 场景已换，旧场景（连同它的节拍器与机器视图）已被释放。
	_combat = null
	_view = null
	_driver = null
	_ctx.check(not is_instance_valid(_combat), "换场景后旧场景的引用必须作废 —— 后面几段一律不再碰它")


## 像素取证：同一份 combat.tscn，挂到离屏画布上跑同一台机器，量屏幕上真的出现了什么。
func _run_pixel_case(written: bool) -> void:
	_ctx.begin_case("战斗冒烟 · 敌人真的画出来了、打死了真的消失（09 §4 像素取证）")
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
	var layer: Control = _find(scene, "EnemyLayer") as Control
	var field: Control = _find(scene, "Battlefield") as Control
	var driver: Node = _find(scene, "MachineDriver") as Node
	if not _ctx.check(view != null and layer != null and field != null and driver != null,
			"离屏场景应有战场、机器视图、敌人层与节拍器"):
		return
	view.set(&"blueprint_path", CLEAR_PATH)
	scene.call(&"reload_machine")
	var sim: Object = driver.get(&"combat")
	if not _ctx.check(sim != null, "离屏场景载入验收机器后应建出战斗"):
		return
	# 本用例证的是**渲染**，不是路由：断掉清空出口，免得第 82 拍那一下把离屏场景也路由一遍
	# （那条边已在上面的路由用例里证过）。断之前先问一句，免得断空连打出一条 ERROR。
	var exit: Callable = Callable(scene, &"on_wave_cleared")
	if sim.is_connected(&"wave_cleared", exit):
		sim.disconnect(&"wave_cleared", exit)
	# 敌人层铺满**战场**（不是整个视口）：状态带不属于战场，敌人不该画到状态带上去。
	_ctx.equal(layer.get_global_rect(), Rect2(Vector2.ZERO, field.get_global_rect().size),
		"敌人层应铺满战场且原点与战场重合 —— 「第几像素」才可以直接读")

	# 冻结在 0 拍再取第一张：场上没有敌人时画面上不该有判据色 —— 这是下面每条正断言的前提。
	driver.call(&"bind", null)
	var before: Image = (await _h.settle())["image"]
	if not _ctx.check(before != null, "应能取到离屏图像（本用例不得加 --headless 运行）"):
		return
	var still_0: Vector2i = _count_lane(before, 0)
	var still_1: Vector2i = _count_lane(before, 1)
	_ctx.check(still_0 == Vector2i.ZERO and still_1 == Vector2i.ZERO,
		"负对照：第 0 拍时两条泳道内都不该有敌人像素（实际 第0道 %s / 第1道 %s）"
			% [_pair_text(still_0), _pair_text(still_1)])
	_save(before, "before")
	print("SMOKE 像素取证 · 冻结在第 0 拍：第0道 %s，第1道 %s（负对照，均应为 0）"
		% [_pair_text(still_0), _pair_text(still_1)])

	# 取样一：第 1 只（Slime）已出场并走了一段。它走第 0 道，故第 1 道此刻必须是空的 ——
	# 同一次取样里两条道一有一无，才能把「量到了敌人」与「整块画布上到处都有」分开。
	driver.call(&"bind_combat", sim)
	var reached: bool = await _advance_until(sim, SAMPLE_SPAWN)
	driver.call(&"bind", null)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍" % [WALL_CLOCK_BUDGET_MS, SAMPLE_SPAWN]):
		return
	var at_spawn: int = _tick_of(sim)
	_ctx.check(at_spawn <= SAMPLE_SPAWN + MAX_CATCH_UP,
		"取样拍号应不超过第 %d 拍（实际第 %d 拍）—— 下面每条断言都依赖它落在窗口里" % [
			SAMPLE_SPAWN + MAX_CATCH_UP, at_spawn])
	var spawn_shot: Image = (await _h.settle())["image"]
	var spawn_0: Vector2i = _count_lane(spawn_shot, 0)
	var spawn_1: Vector2i = _count_lane(spawn_shot, 1)
	_ctx.check(spawn_0.x > 0,
		"第 %d 拍时第 0 道应有 Slime 的身体（RED_600，实际 %d px）—— 敌人在屏幕上真的看得见" % [
			at_spawn, spawn_0.x])
	_ctx.check(spawn_1 == Vector2i.ZERO,
		"第 %d 拍时第 1 道不该有敌人像素（实际 %s）—— 判据色确实跟着敌人走，不是整块画布上都有" % [
			at_spawn, _pair_text(spawn_1)])
	_save(spawn_shot, "spawn")
	print("SMOKE 像素取证 · 第 %d 拍：第0道 %s（Slime 在场），第1道 %s"
		% [at_spawn, _pair_text(spawn_0), _pair_text(spawn_1)])

	# 取样二：第 3 只（Slime，第 68 拍被打死）已在第 72 拍退场，第 0 道空了；
	# 第 4 只（Runner）正在第 1 道上 —— 「武器命中后敌人消失」在像素上的最强形式：
	# 同一屏里一条道上的敌人没了，另一条道上的还在。
	driver.call(&"bind_combat", sim)
	reached = await _advance_until(sim, SAMPLE_KILLED)
	driver.call(&"bind", null)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍" % [WALL_CLOCK_BUDGET_MS, SAMPLE_KILLED]):
		return
	var at_killed: int = _tick_of(sim)
	_ctx.check(at_killed <= SAMPLE_KILLED + MAX_CATCH_UP,
		"取样拍号应不超过第 %d 拍（实际第 %d 拍）" % [SAMPLE_KILLED + MAX_CATCH_UP, at_killed])
	var killed_shot: Image = (await _h.settle())["image"]
	var killed_0: Vector2i = _count_lane(killed_shot, 0)
	var killed_1: Vector2i = _count_lane(killed_shot, 1)
	_ctx.check(killed_0 == Vector2i.ZERO,
		"第 %d 拍时第 0 道应已清空（实际 %s）—— 那把针真的把它打死了，尸体也退场了" % [
			at_killed, _pair_text(killed_0)])
	_ctx.check(killed_1.y > 0,
		"第 %d 拍时第 1 道应还有 Runner（RED_500，实际 %d px）—— 空的是被打死的那条道，不是整块战场" % [
			at_killed, killed_1.y])
	_save(killed_shot, "killed")
	print("SMOKE 像素取证 · 第 %d 拍：第0道 %s（已清空），第1道 %s（Runner 在场）"
		% [at_killed, _pair_text(killed_0), _pair_text(killed_1)])

	# 负对照：藏掉敌人层，两条泳道的判据色必须整体归零 —— 归零失败说明数到的像素并非来自这一层。
	layer.visible = false
	var hidden: Image = (await _h.settle())["image"]
	_ctx.check(_count_lane(hidden, 0) == Vector2i.ZERO and _count_lane(hidden, 1) == Vector2i.ZERO,
		"负对照：藏掉敌人层后两条泳道的敌人像素应归零（实际 第0道 %s / 第1道 %s）" % [
			_pair_text(_count_lane(hidden, 0)), _pair_text(_count_lane(hidden, 1))])
	layer.visible = true

	# 取样三：一波全灭之后，两条道都空了 —— 胜负与像素在这里对齐。
	driver.call(&"bind_combat", sim)
	reached = await _advance_until(sim, CLEAR_TICK)
	driver.call(&"bind", null)
	if not _ctx.check(reached and bool(sim.call(&"is_cleared")),
			"应在 %d ms 内打到第 %d 拍并已清空" % [WALL_CLOCK_BUDGET_MS, CLEAR_TICK]):
		return
	var after: Image = (await _h.settle())["image"]
	var done_0: Vector2i = _count_lane(after, 0)
	var done_1: Vector2i = _count_lane(after, 1)
	_ctx.check(done_0 == Vector2i.ZERO and done_1 == Vector2i.ZERO,
		"本波清空后两条泳道都不该再有敌人像素（实际 第0道 %s / 第1道 %s）" % [
			_pair_text(done_0), _pair_text(done_1)])
	_save(after, "cleared")
	print("SMOKE 像素取证 · 第 %d 拍（本波清空）：第0道 %s，第1道 %s"
		% [_tick_of(sim), _pair_text(done_0), _pair_text(done_1)])


## 写验收机器甲：CORE → 分流 → 针 ×2。走数据类落盘，于是这份图与玩家在整备界面拖出来的
## 是同一种东西，机器重建也走同一条路（09 §3.2）。
func _write_clear_blueprint() -> bool:
	var spec: Array = [
		["core", "核心", _kind_core, _fn_none],
		["split", "分流", _kind_function, _fn_split],
		["needle_a", "针", _kind_weapon, _fn_none],
		["needle_b", "针", _kind_weapon, _fn_none],
	]
	var edges: Array = [["core", "split"], ["split", "needle_a"], ["split", "needle_b"]]
	var blueprint: Resource = _build_blueprint(spec, edges, "验收机器甲")
	return bool(blueprint.call(&"save_to", CLEAR_PATH)) if blueprint != null else false


## 写验收机器乙：只有 CORE。没有武器，敌人只会一路走到终点。
func _write_bare_blueprint() -> bool:
	var spec: Array = [["core", "核心", _kind_core, _fn_none]]
	var blueprint: Resource = _build_blueprint(spec, [], "验收机器乙")
	return bool(blueprint.call(&"save_to", BARE_PATH)) if blueprint != null else false


func _build_blueprint(spec: Array, edges: Array, label: String) -> Resource:
	var blueprint: Resource = _blueprint_script.new()
	for item: Array in spec:
		var node: Resource = _node_script.new()
		node.set(&"id", StringName(item[0]))
		node.set(&"display_name", String(item[1]))
		node.set(&"kind", int(item[2]))
		node.set(&"function_kind", int(item[3]))
		blueprint.get(&"nodes").append(node)
	for edge: Array in edges:
		var link: Resource = _link_script.new()
		link.set(&"from_node_id", StringName(edge[0]))
		link.set(&"from_port", &"out")
		link.set(&"to_node_id", StringName(edge[1]))
		link.set(&"to_port", &"in")
		blueprint.get(&"connections").append(link)
	_ctx.equal(blueprint.get(&"nodes").size(), spec.size(), "%s 的节点数" % label)
	_ctx.equal(blueprint.get(&"connections").size(), edges.size(), "%s 的连线数" % label)
	return blueprint


## 等真实帧把战斗推到 target 拍。上限用的是**墙钟**（用例不得挂死），
## 但判据是节拍号 —— 帧率高低只影响耗时，不影响结论（03 §6）。
func _advance_until(sim: Object, target: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + WALL_CLOCK_BUDGET_MS
	while _tick_of(sim) < target and Time.get_ticks_msec() < deadline:
		await process_frame
	return _tick_of(sim) >= target


func _tick_of(sim: Object) -> int:
	return int(sim.call(&"tick_index"))


## 等当前场景被路由换成 path。change_scene_to_file 落在帧末，故这里最多等几帧。
## 等不到不是「再等等就好」—— 它意味着路由根本没发生，上面那条断言会把它打红。
func _await_scene(path: String, frames: int = 8) -> bool:
	for _index: int in frames:
		if _scene_path() == path:
			return true
		await process_frame
	return _scene_path() == path


## 场上第 index 只敌人（含尚未消失的尸体）。顺序即出场顺序。
func _enemy(sim: Object, index: int) -> Object:
	var list: Array = sim.call(&"enemies")
	return list[index] if index < list.size() else null


## 某一条泳道内的 (RED_600 像素数, RED_500 像素数)。
## 第 0 位是 Slime 的身体色，第 1 位是 Runner 的身体色 —— 两者**不可混读**：
## Slime 走第 0 道、Runner 走第 1 道，故「第 0 道有 Slime」看 .x，「第 1 道有 Runner」看 .y。
func _count_lane(image: Image, lane: int) -> Vector2i:
	var rect := Rect2(0.0, ENEMY_BAND_TOP + float(lane) * ENEMY_ROW_HEIGHT,
		VIEWPORT.x, ENEMY_ROW_HEIGHT)
	return Vector2i(_count_rect(image, rect, _slime), _count_rect(image, rect, _runner))


func _pair_text(pair: Vector2i) -> String:
	return "RED_600 %d px / RED_500 %d px" % [pair.x, pair.y]


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


## 存证据图：原图与最近邻放大各一张。放大是为了让 8×8 的占位敌人在人工复核时看得见。
func _save(image: Image, tag: String) -> void:
	if image == null:
		return
	_ctx.check(image.save_png(SHOT_PATH + tag + ".png") == OK, "应能写出证据图 %s.png" % tag)
	var big: Image = Image.new()
	big.copy_from(image)
	big.resize(CANVAS.x * ZOOM, CANVAS.y * ZOOM, Image.INTERPOLATE_NEAREST)
	_ctx.check(big.save_png("%s%s_%dx.png" % [SHOT_PATH, tag, ZOOM]) == OK,
		"应能写出 %d× 放大的证据图 %s" % [ZOOM, tag])


func _core_text(combat: Node) -> String:
	var block: Node = _find(combat, "Core")
	if block == null:
		return ""
	var value: Label = block.get_node_or_null(^"Value") as Label
	return value.text if value != null else ""


func _notice_visible(combat: Node) -> bool:
	var label: Label = _find(combat, "NoticeLabel") as Label
	return label != null and label.visible


## 清掉测试产物。正式存档目录一概不碰。
func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for file_name: String in [CLEAR_PATH.get_file(), BARE_PATH.get_file()]:
		if FileAccess.file_exists(TEST_DIR + "/" + file_name):
			dir.remove(file_name)


## 按名字找节点。刻意不用 `%` 唯一名：子场景实例的唯一名作用域挂在各自 owner 上，
## 跨子场景边界时语义容易出意外；按名字搜是确定的（同 combat_smoke.gd）。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false) if node != null else null


func _scene_path() -> String:
	return String(current_scene.scene_file_path) if current_scene != null else ""


func _state(state_name: String) -> int:
	return int(_flow_script.GameState[state_name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：FIRST PLAYABLE 3/4（PET-65）COMBAT 真实：Slime/Runner 生成推进 + 三武器伤害结算")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %s / 渲染驱动 %s" % [
		version["string"], str(DisplayServer.window_get_size()),
		RenderingServer.get_video_adapter_name()])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：经路由进 COMBAT(点 CTA) · 验收机器甲 CORE→Split→针×2 · 敌人在真实帧上生成并推进 · 第 %d 拍本波清空并把场景路由到 REWARD · 机器乙的漏怪把 `CORE` 读数打到 %s · 敌人判据色与消失的像素取证" % [CLEAR_TICK, LEAK_READOUT])
	_lines.append("- 证据图：%s{before,spawn,killed,cleared}.png 与 %s{before,spawn,killed,cleared}_%dx.png" % [SHOT_PATH, SHOT_PATH, ZOOM])
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\combat_loop_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("combat_loop_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
