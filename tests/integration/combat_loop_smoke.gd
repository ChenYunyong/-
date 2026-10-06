## combat_loop_smoke.gd
## 职责：战斗闭环的**真实运行**取证（FIRST PLAYABLE 3/4）—— 经 GameFlow 路由进 COMBAT 之后，
##       一波敌人由 MachineDriver 按固定节拍真的生成、真的推进，武器真的命中、敌人真的消失，
##       一波全灭真的走到 REWARD 出口，敌人抵达终点真的把 CORE 读数打下去 ——
##       并且这些事在画面上**真的看得见**（敌人判据色的像素证据 + 截图）。
##       本卡（PET-76）再补一段**可读反馈**的取证：枪口反馈 / 弹道 / 命中闪光 / 击杀描边 / 血条，
##       以及「三把武器的反馈长得不一样」—— 同样对着同一份 combat.tscn 的真实渲染量像素。
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
##   反馈的负对照 —— 开火之前（第 12 拍）四样反馈一个都不该有，开火那一帧三样必须**同帧**齐到：
##               于是「量到了反馈」与「整块画布上一直有这些颜色」分得开。
##   三把可区分 —— 三张卡上方的反馈包围盒必须是「细高 / 方正 / 扁宽」三种形状：
##               三把若画成同一块（只是挪了位置），这一条会转红 —— 位置不同救不了形状相同。

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
## 验收机器丙：CORE → 分流 → 针 / 炸弹 / 锯。三把武器同一拍开火，用来取「三把反馈长得不一样」的证据。
const KIT_PATH: String = TEST_DIR + "/_combat_loop_kit.tres"

## 画布 = 06 §1 的 640×360 基准（PET-80 前 320×180），于是「第几个像素」可以直接读。
const CANVAS: Vector2i = Vector2i(640, 360)
const VIEWPORT: Vector2 = Vector2(640.0, 360.0)

## 敌人泳道的绘制参数（combat_screen.gd 的表现层常数，本文件独立复写）。
## 取整条道的高度而不是逐只算矩形：敌人**自己往前走**，逐只算矩形就等于把被测的推进
## 又抄进了判据里，位置算错时两边一起错。
## PET-80：32 → 64、24 → 48（combat_screen.gd 同款加倍的独立复写）。
const ENEMY_BAND_TOP: float = 64.0
const ENEMY_ROW_HEIGHT: float = 48.0

## 放大倍数：占位敌人在一张 640×360 的图里几乎看不出来，证据图放大后再附。
## PET-80 后**基准画布本身**已是原来的两倍，故同样 4× 的证据图在「逻辑像素」这一层
## 恰好与 PET-80 前逐逻辑像素相同 —— 这个数不必跟着翻倍，翻了反而变成 8× 的相对放大。
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

## PET-76 可读反馈的取样区域，坐标以**战场局部**为准（敌人层原点与战场重合，故可直接读像素）。
## 机器视图贴战场下沿、高 96px（PET-80 前 48），故它的上缘就是战场 y 174（PET-80 前 87）；
## 卡片、卡片之间的连线与火花全部画在 y ≥ 174，于是**卡片上方那一段空档里只有开火反馈**。
##
## PET-80：三段区域全部 ×2。它们都由「机器视图上缘」与「开火反馈能升到的最低点」推出来，
## 而这两个锚点各自都是长度、都随坐标系 ×2，故整段区间一起平移放大、相对关系逐条不变。
##
## 取这三段而不是「整块战场」：判据色会被别处的绘制污染，量到的就不再是「这条反馈出现了」。
const CUE_REGION: Rect2 = Rect2(92.0, 140.0, 104.0, 32.0)
## 弹道横穿的那一段。下沿 142 卡在开火反馈能升到的最低点（战场 y 142）之上，故这一段里只有弹道。
const TRACER_REGION: Rect2 = Rect2(0.0, 80.0, 640.0, 62.0)
## 两条敌人泳道合起来的那一段。命中闪光与击杀描边都落在这里。
const BAND_REGION: Rect2 = Rect2(0.0, 64.0, 640.0, 96.0)
## 第 1 条道（Runner 走的那条）那一段。「命中闪光落在哪条道上」据此判 —— 落在第 0 道就不算。
const LANE_ONE_REGION: Rect2 = Rect2(0.0, ENEMY_BAND_TOP + ENEMY_ROW_HEIGHT, 640.0, ENEMY_ROW_HEIGHT)
## 敌人身体顶边到 HP 条上沿的距离（表现层常数：缝 6px + 条厚 4px，独立复写；PET-80 前 3 + 2）。
## HP 条就画在身体**上方**这几行里，故这几行里数到的 RED_500 只可能是血条，不会混进身体。
## 条本身也厚了一倍（2 → 4），判据色的**行数**随之翻倍但**位置关系**不变。
const ENEMY_HP_ROW_OFFSET: float = 10.0
const ENEMY_HP_HEIGHT: float = 4.0

## 「三把可区分」量的是卡片上缘往上第 1..14 行（战场 y 142..155；PET-80 前第 1..7 行 / y 71..77）。
## 下界 155 是有意的：再往下就有弹道斜穿而过了，那一段量到的会变成「反馈 + 恰好路过的一根线」。
## 两界都恰好是 PET-80 前的两倍（71→142、78→156），窗口高 7→14 行 —— 相对位置不变。
const CUE_ROW_TOP: int = 142
const CUE_ROW_BOTTOM: int = 156
## 卡片列宽（BlueprintWorkspace.GRID 的独立复写，PET-80：24 → 48）与三把武器所在的列号。
## 机器丙 = CORE / 分流 / 针 / 炸弹 / 锯 依次落格，故武器在第 2 / 3 / 4 列。
const CARD_COLUMN: int = 48
const KIT_FIRST_WEAPON_COLUMN: int = 2
## 三把武器的反馈每拍上升 2 逻辑像素（CUE_RISE 16 ÷ SHOT_TICKS 8；PET-80 前 1px），存活 8 拍。
## 存活拍数是**拍**、不是长度，故不随坐标系 ×2。取满这 8 拍才能保证量到的是长满的那一帧。
const KIT_WINDOW: int = 8

## 可读反馈的取样拍号（全部算得出，不是「跑够了就算过」）：
##   第 1 次齐射在第 18 拍（CORE 第 10 拍发脉冲 + 两条边各 4 拍）；
##   第 1 只（Slime，第 0 道）在第 28 拍被打死，第 2 只（Runner，第 1 道）在第 38 拍被打死。
## 取 12 / 18 / 26 / 34：前两个分别落在「还没开火」与「齐射当拍」上，
## 后两个只用来起头 —— 真正的取样点是逐帧找到那一帧，不是「到了这一拍就取」。
const READ_BEFORE_TICK: int = 12
const READ_FIRE_TICK: int = 18
const READ_KILL_TICK: int = 26
const READ_LANE_TICK: int = 34
## 墙钟上限：用例不得挂死（同 run_tests.gd 的兜底）。判据是节拍号，不是这个数。
const WALL_CLOCK_BUDGET_MS: int = 30_000

## 离屏那一幕开一局用的固定种子（03 §6：随机必须可复现；本用例只用它把波次拨回第 1 波）。
const WAVE_ONE_SEED: int = 20261004

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

## PET-76 可读反馈的判据色（同样一律取自 Palette）：
##   开火反馈与弹道 = FX 体色 BLUE_FX_600；命中闪光 = WHITE；击杀描边 = FX 芯色 BLUE_050。
## 三者与敌人身体的红、战场底 NAVY_900 都不同；WHITE 在整幕 COMBAT 里更是**只**由命中闪光画出来
## （Label 的正文色是 BLUE_100），故「量到白点」与「打中了」之间没有第二种解释。
var _cue: Color = Color.BLACK
var _flash: Color = Color.BLACK
var _kill: Color = Color.BLACK

## 蓝图里用到的枚举值。在 _initialize 里取自被测脚本，不在这里写死整数。
var _kind_core: int = 0
var _kind_function: int = 0
var _kind_weapon: int = 0
var _weapon_needle: int = 0
var _weapon_bomb: int = 0
var _weapon_saw: int = 0
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
	_cue = _palette.get_color(_palette.Key.BLUE_FX_600)
	_flash = _palette.get_color(_palette.Key.WHITE)
	_kill = _palette.get_color(_palette.Key.BLUE_050)
	_kind_core = int(_node_script.Kind.CORE)
	_kind_function = int(_node_script.Kind.FUNCTION)
	_kind_weapon = int(_node_script.Kind.WEAPON)
	_weapon_needle = int(_node_script.WeaponKind.NEEDLE)
	_weapon_bomb = int(_node_script.WeaponKind.BOMB)
	_weapon_saw = int(_node_script.WeaponKind.SAW)
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
	var kit_written: bool = _write_kit_blueprint()
	await process_frame
	# 顺序是有意的：漏怪那一局（机器乙，没有武器）不会分出胜负，场景留在 COMBAT；
	# 清空那一局（机器甲）会把场景路由去 REWARD，故它必须排在最后 —— 它之后就没有 COMBAT 场景了。
	await _run_leak_case(bare_written)
	await _run_spawn_case(clear_written)
	await _run_clear_case()
	await _run_pixel_case(clear_written)
	# 可读反馈那一段自带离屏场景（机器甲 + 机器丙），不受上面路由走掉的那一幕影响。
	await _run_readability_case(clear_written, kit_written)
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
	# 这一幕的拍号（第 20 / 74 拍取样、第 82 拍清空）全是**第 1 波**的绝对值，
	# 而 combat_screen.reload_machine() 是按 RunState 的**当前波次**建仿真的：上面那场路由用例
	# 清空了一波、把进度推到了 2，不拨回去这一幕打的就会是 6 只敌人的第 2 波 —— 82 拍永远清不完。
	# end_run() 刻意保留波次（那是 RESULT 的读数来源），复位归 start_run()，两句都要。
	var run_state: Node = _autoload("RunState")
	if not _ctx.check(run_state != null, "RunState Autoload 应存在（波次由它决定打哪一波）"):
		return
	if bool(run_state.call(&"is_active")):
		run_state.call(&"end_run")
	run_state.call(&"start_run", WAVE_ONE_SEED)

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


## PET-76 可读反馈：不看 HUD 也能说出「哪把武器发动 → 打到谁 → 什么结果」（09 §4 像素取证）。
##
## 三次取样对着这条因果链的三个时刻，全部取自**同一份 combat.tscn 的真实渲染**：
##   read_before —— 第 1 只敌人在场、血条满，四样反馈一个都没有（负对照）；
##   read_fire   —— 第 1 次齐射：枪口反馈 / 弹道 / 命中闪光**同帧**齐到，
##                  且同一帧里血条已经短了、`热量` 读数已经涨了（因果同拍，不是「数字自己在跳」）；
##   read_kill   —— 打死那一拍：尸体外面多一圈一次性描边；
##   read_lane   —— 挨打的是第 1 条道上的 Runner：弹道与闪光都落在第 1 条道，
##                  不是「只有第 0 道会亮」。
##
## 「三把可区分」另开一台机器丙（CORE → 分流 → 针 / 炸弹 / 锯）：三把同拍开火，
## 三张卡上方的反馈形态必须一眼分得开。04 §3.10 只给了一套 FX 配色，
## 于是能用来区分的只有**形状** —— 判据也就只能是形状（包围盒的横竖比）。
func _run_readability_case(clear_written: bool, kit_written: bool) -> void:
	_ctx.begin_case("战斗冒烟 · PET-76 可读反馈：哪把武器 / 打到谁 / 什么结果（09 §4）")
	if not clear_written:
		return
	var scene: Control = await _open_offscreen(CLEAR_PATH)
	if scene == null:
		_ctx.check(false, "应能挂起一台载着验收机器甲的离屏 COMBAT")
		return
	var view: Control = _find(scene, "MachineView") as Control
	var driver: Node = _find(scene, "MachineDriver") as Node
	var sim: Object = driver.get(&"combat") if driver != null else null
	if not _ctx.check(view != null and driver != null and sim != null,
			"离屏场景应有机器视图、节拍器与一场战斗"):
		return

	# 取样一：还没开火。四样反馈都不该有 —— 下面每条正断言的前提。
	var reached: bool = await _advance_until(sim, READ_BEFORE_TICK)
	driver.call(&"bind", null)
	if not _ctx.check(reached, "应在 %d ms 内跑到第 %d 拍（实际第 %d 拍）" % [
			WALL_CLOCK_BUDGET_MS, READ_BEFORE_TICK, _tick_of(sim)]):
		return
	var before_image: Image = (await _h.settle())["image"]
	if not _ctx.check(before_image != null, "应能取到离屏图像（本用例不得加 --headless 运行）"):
		return
	var stillness: bool = _count_rect(before_image, CUE_REGION, _cue) == 0 \
		and _count_rect(before_image, TRACER_REGION, _cue) == 0 \
		and _count_rect(before_image, BAND_REGION, _flash) == 0 \
		and _count_rect(before_image, BAND_REGION, _kill) == 0
	_ctx.check(stillness,
		"负对照：第 %d 拍还没开火，枪口反馈 / 弹道 / 命中闪光 / 击杀描边都不该出现" % _tick_of(sim))
	var hp_before: int = _hp_fill(before_image, 0)
	_ctx.check(hp_before > 0 and _count_lane(before_image, 0).x > 0,
		"第 %d 拍第 1 只敌人已在场且血条是满的（血条填充 %d px）" % [_tick_of(sim), hp_before])
	var heat_before: int = _heat_percent(scene)
	_ctx.equal(heat_before, 0, "第 %d 拍的 `热量` 读数（还没开火）" % _tick_of(sim))
	_save(before_image, "read_before")

	# 取样二：第 1 次齐射。三样反馈必须同帧 —— 这是本卡要治的病「看不出在干嘛」的正解。
	driver.call(&"bind_combat", sim)
	var fire: Dictionary = await _await_frame(sim, READ_FIRE_TICK, Callable(self, &"_is_volley_frame"))
	driver.call(&"bind", null)
	var fire_image: Image = fire["image"]
	if not _ctx.check(fire_image != null, "应能取到齐射那一帧"):
		return
	var at_fire: int = _tick_of(sim)
	_ctx.check(_count_rect(fire_image, CUE_REGION, _cue) > 0,
		"第 %d 拍：开火那张卡的上方应有枪口反馈（BLUE_FX_600 %d px）—— 「哪把武器发动」" % [
			at_fire, _count_rect(fire_image, CUE_REGION, _cue)])
	_ctx.check(_count_rect(fire_image, TRACER_REGION, _cue) > 0,
		"第 %d 拍：同一帧里应有弹道（BLUE_FX_600 %d px）—— 「打到谁」中间那一段" % [
			at_fire, _count_rect(fire_image, TRACER_REGION, _cue)])
	var flash_box: Rect2 = _color_box(fire_image, BAND_REGION, _flash)
	_ctx.check(flash_box.size.x > 0.0,
		"第 %d 拍：同一帧里命中点上应有一枚短促闪光（WHITE %s）—— 「打中了」" % [
			at_fire, _rect_text(flash_box)])
	# 「打到谁」的完整形式：弹道**末端**要落在闪光的那个身位上，而不是随便指向某个固定位置。
	var tip: Vector2i = _top_row(fire_image, TRACER_REGION, _cue)
	var flash_middle: int = int(flash_box.position.x + flash_box.size.x * 0.5)
	_ctx.check(tip.x >= 0 and absi(tip.x - flash_middle) <= 8,
		"第 %d 拍：弹道末端指向闪光那一点（末端 x=%d @ y=%d，命中点 x=%d，相差 %d px ≤ 一个身位）" % [
			at_fire, tip.x, tip.y, flash_middle, absi(tip.x - flash_middle)])
	# 因果同拍：读数与画面在同一帧里一起变，不是「数字自己在跳」。
	var hp_after: int = _hp_fill(fire_image, 0)
	_ctx.check(hp_after < hp_before,
		"第 %d 拍：同一帧里血条真的短了（%d px → %d px）—— 「什么结果」" % [
			at_fire, hp_before, hp_after])
	var heat_after: int = _heat_percent(scene)
	_ctx.check(heat_after > heat_before,
		"第 %d 拍：同一帧里 `热量` 读数已经涨了（%d%% → %d%%）—— 开火与读数同拍，不是分开的两件事" % [
			at_fire, heat_before, heat_after])
	_save(fire_image, "read_fire")

	# 取样三：第 1 只被打死。击杀是一次性的（负对照已证明开枪前没有这圈描边）。
	driver.call(&"bind_combat", sim)
	var killed: Dictionary = await _await_frame(sim, READ_KILL_TICK, Callable(self, &"_is_kill_frame"))
	driver.call(&"bind", null)
	var killed_image: Image = killed["image"]
	if not _ctx.check(killed_image != null, "应能取到击杀那一帧"):
		return
	_ctx.check(_count_rect(killed_image, BAND_REGION, _kill) > 0,
		"第 %d 拍：尸体外面应有一圈击杀描边（BLUE_050 %d px）—— 一次性的「死了」" % [
			_tick_of(sim), _count_rect(killed_image, BAND_REGION, _kill)])
	_save(killed_image, "read_kill")

	# 取样四：挨打的是第 1 条道上的 Runner —— 「打到谁」不是只有第 0 道会亮。
	driver.call(&"bind_combat", sim)
	var lane: Dictionary = await _await_frame(sim, READ_LANE_TICK, Callable(self, &"_is_lane_frame"))
	driver.call(&"bind", null)
	var lane_image: Image = lane["image"]
	if not _ctx.check(lane_image != null, "应能取到第 1 条道挨打的那一帧"):
		return
	var lane_flash: Rect2 = _color_box(lane_image, LANE_ONE_REGION, _flash)
	_ctx.check(lane_flash.size.x > 0.0 and _count_rect(lane_image, TRACER_REGION, _cue) > 0,
		"第 %d 拍：弹道与命中闪光都落在第 1 条道上（闪光 %s，弹道 %d px）—— 换一条道也跟得上" % [
			_tick_of(sim), _rect_text(lane_flash), _count_rect(lane_image, TRACER_REGION, _cue)])
	_save(lane_image, "read_lane")

	# 「三把可区分」：换机器丙，三把武器同拍开火，量三张卡上方的反馈形状。
	if not kit_written:
		return
	var kit_scene: Control = await _open_offscreen(KIT_PATH)
	if kit_scene == null:
		_ctx.check(false, "应能挂起一台载着验收机器丙（针 / 炸弹 / 锯）的离屏 COMBAT")
		return
	var kit_driver: Node = _find(kit_scene, "MachineDriver") as Node
	var kit_sim: Object = kit_driver.get(&"combat") if kit_driver != null else null
	if not _ctx.check(kit_sim != null, "机器丙应有三把武器与一场战斗"):
		return
	var kit: Dictionary = await _await_kit_frame(kit_sim, READ_FIRE_TICK)
	kit_driver.call(&"bind", null)
	var kit_image: Image = kit["image"]
	if not _ctx.check(kit_image != null, "应能取到三把一起开火的那一帧"):
		return
	var boxes: Array[Rect2] = []
	for index: int in 3:
		boxes.append(_cue_box(kit_image, index))
	for index: int in 3:
		_ctx.check(boxes[index].size.x > 0.0 and boxes[index].size.y > 0.0,
			"机器丙第 %d 张卡的上方应有开火反馈（%s）" % [KIT_FIRST_WEAPON_COLUMN + index, _rect_text(boxes[index])])
	print("SMOKE 像素取证 · 三把反馈的形状（宽×高）：针 %d×%d / 炸弹 %d×%d / 锯 %d×%d"
		% [int(boxes[0].size.x), int(boxes[0].size.y), int(boxes[1].size.x), int(boxes[1].size.y),
			int(boxes[2].size.x), int(boxes[2].size.y)])
	# PET-80：三条里的**绝对长度**门槛全部 ×2（2→4、4→8、1→2、8→16）；
	# 两条按比值写的（size.y ≥ 2×size.x、size.x ≥ 2×size.y）是形状判据，与坐标系无关，原样保留。
	# 之所以绝对门槛也必须翻倍而不是「反正变宽了肯定过」：门槛不翻倍就退化成**恒真**，
	# 那才是把断言弱化掉。翻倍之后它钉的仍是同一件事 —— 外框内缩之后剩下的那几像素。
	_ctx.check(boxes[0].size.x <= 4.0 and boxes[0].size.y >= boxes[0].size.x * 2.0,
		"针的反馈是**细高**的一条：%s" % _rect_text(boxes[0]))
	_ctx.check(boxes[1].size.x >= 8.0 and absf(boxes[1].size.x - boxes[1].size.y) <= 2.0,
		"炸弹的反馈是**方正**的一块：%s" % _rect_text(boxes[1]))
	_ctx.check(boxes[2].size.x >= 16.0 and boxes[2].size.x >= boxes[2].size.y * 2.0,
		"锯的反馈是**扁宽**的一条：%s" % _rect_text(boxes[2]))
	_save(kit_image, "read_kinds")
	_sheet([before_image, fire_image, killed_image, lane_image], "read_sheet")


## 把一份 combat.tscn 挂到离屏画布上、载好蓝图并跑起来，返回场景根（取节点用 _find）。
##
## 波次拨回第 1 波：`reload_machine()` 按 RunState 的**当前波次**建仿真，
## 而路由用例已经把进度推到了 2（理由同 _run_pixel_case）。
##
## 清空出口一律断开：本用例证的是**画出来的东西**，不是路由；不断的话清空那一拍
## 会把离屏场景也路由走，后面几次取样就全部对着一个已经被释放的场景。
func _open_offscreen(blueprint_path: String) -> Control:
	var packed: PackedScene = load(COMBAT_SCENE_PATH)
	var run_state: Node = _autoload("RunState")
	if packed == null or run_state == null:
		return null
	if bool(run_state.call(&"is_active")):
		run_state.call(&"end_run")
	run_state.call(&"start_run", WAVE_ONE_SEED)

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
	if view == null or driver == null:
		return null
	view.set(&"blueprint_path", blueprint_path)
	scene.call(&"reload_machine")
	var sim: Object = driver.get(&"combat")
	if sim == null:
		return null
	var exit: Callable = Callable(scene, &"on_wave_cleared")
	if sim.is_connected(&"wave_cleared", exit):
		sim.disconnect(&"wave_cleared", exit)
	driver.call(&"bind_combat", sim)
	return scene


## 从第 from 拍起逐帧找**第一帧**满足 wanted 的画面。找不到时返回最后一帧（调用方的断言会打红）。
##
## 逐帧而不是「跑到某一拍再取一张」：三样反馈各自只活 3~8 拍，
## 「枪口反馈 + 弹道 + 命中闪光同帧」这个窗口只有 3 拍宽 —— 按拍取样看运气，逐帧取样不看。
func _await_frame(sim: Object, from: int, wanted: Callable) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + WALL_CLOCK_BUDGET_MS
	while _tick_of(sim) < from and Time.get_ticks_msec() < deadline:
		await process_frame
	var frame: Dictionary = await _h.settle()
	while not bool(wanted.call(frame["image"])) and Time.get_ticks_msec() < deadline:
		frame = await _h.settle()
	return frame


## 三把武器的反馈形状：逐帧量三个卡位那几行里的像素，取**总量最大**的那一帧。
##
## 为什么取最大而不是取第一帧：反馈每拍上升 2 逻辑像素（PET-80 前 1px），越老越完整地落进那片窗口；
## 总量随拍数单调增，于是「最大」这一帧一定是长满的那一帧 —— 三把的形态在同一拍上才可比。
## 也不取**并集**：并集会把「上升」也算进高度，三把的高度就都被撑成一样，形状反而分不开了。
func _await_kit_frame(sim: Object, from: int) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + WALL_CLOCK_BUDGET_MS
	while _tick_of(sim) < from and Time.get_ticks_msec() < deadline:
		await process_frame
	var best: Dictionary = await _h.settle()
	var best_total: int = _kit_total(best["image"])
	while _tick_of(sim) < from + KIT_WINDOW and Time.get_ticks_msec() < deadline:
		var frame: Dictionary = await _h.settle()
		var total: int = _kit_total(frame["image"])
		if total > best_total:
			best_total = total
			best = frame
	return best


## 齐射帧：枪口反馈、弹道、命中闪光三样**同帧**都在。
func _is_volley_frame(image: Image) -> bool:
	return _count_rect(image, CUE_REGION, _cue) > 0 \
		and _count_rect(image, TRACER_REGION, _cue) > 0 \
		and _count_rect(image, BAND_REGION, _flash) > 0


## 击杀帧：尸体外面出现一次性描边，且同一帧里还看得见那条道上正在收缩的身体 ——
## 描边不是凭空出现的，它套在一具正在消失的尸体上。
func _is_kill_frame(image: Image) -> bool:
	return _count_rect(image, BAND_REGION, _kill) > 0 \
		and _count_rect(image, BAND_REGION, _slime) > 0


## 第 1 条道上的挨打帧：弹道在飞、第 1 条道上有 Runner、且命中闪光落在第 1 条道那一段里。
func _is_lane_frame(image: Image) -> bool:
	return _count_rect(image, TRACER_REGION, _cue) > 0 \
		and _count_lane(image, 1).y > 0 \
		and _color_box(image, LANE_ONE_REGION, _flash).size.x > 0.0


## 三张武器卡上方那几行里，BLUE_FX_600 的像素总数。
func _kit_total(image: Image) -> int:
	var total: int = 0
	for index: int in 3:
		total += _count_rect(image, _cue_window(index), _cue)
	return total


## 某一张武器卡上方那片取样窗口。窗口只覆盖卡片上缘往上的第 1..7 行（见 CUE_ROW_*）。
func _cue_window(index: int) -> Rect2:
	return Rect2(float((KIT_FIRST_WEAPON_COLUMN + index) * CARD_COLUMN), float(CUE_ROW_TOP),
		float(CARD_COLUMN), float(CUE_ROW_BOTTOM - CUE_ROW_TOP))


## 一张卡上方那枚反馈自己的形状盒：先自下而上找到反馈所在的那一行，
## 取该行里离卡片中心最近的那一段连续判据色像素，再自下而上量出这一段自己的高度。
##
## 不能像命中闪光那样整窗取包围盒：弹道同是 BLUE_FX_600，会**横穿**某个取样窗口被并进盒子。
## 实测（PET-80 前）「锯」那一格的整窗盒子宽 17px，其中只有 9px 是锯本身，剩下 8px 是路过的弹道。
## PET-80 后这三个读数随坐标系一起 ×2（17→34 / 9→18 / 8→16，比例不变）——
## 那样锯就算画成 2 逻辑像素宽也照样能过。形状判据只许量反馈自己那几个像素。
func _cue_box(image: Image, index: int) -> Rect2:
	if image == null:
		return Rect2()
	var window: Rect2 = _cue_window(index)
	var extent: Vector2i = image.get_size()
	var top: int = clampi(int(window.position.y), 0, extent.y)
	var bottom: int = clampi(int(window.end.y), 0, extent.y)
	var from_x: int = clampi(int(window.position.x), 0, extent.x)
	var to_x: int = clampi(int(window.end.x), 0, extent.x)
	var centre: int = (from_x + to_x) / 2
	for y: int in range(bottom - 1, top - 1, -1):
		var run: Vector2i = _nearest_run(image, y, from_x, to_x, centre)
		if run.x < 0:
			continue
		var height: int = 0
		for up: int in range(y, top - 1, -1):
			if not _row_has(image, up, run.x, run.y):
				break
			height += 1
		return Rect2(float(run.x), float(y - height + 1), float(run.y - run.x + 1), float(height))
	return Rect2()


## 第 y 行 [from_x, to_x) 里离 centre 最近的那一段连续判据色像素，返回 (起, 止)。
## 一段都没有时返回 (-1, -1)。
func _nearest_run(image: Image, y: int, from_x: int, to_x: int, centre: int) -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_gap: int = -1
	var start: int = -1
	for x: int in range(from_x, to_x + 1):
		var hit: bool = x < to_x and _h.near(image.get_pixel(x, y), _cue)
		if hit and start < 0:
			start = x
		elif not hit and start >= 0:
			var gap: int = absi((start + x - 1) / 2 - centre)
			if best_gap < 0 or gap < best_gap:
				best = Vector2i(start, x - 1)
				best_gap = gap
			start = -1
	return best


## 第 y 行 [from_x, to_x] 这段列区间里有没有判据色像素。
func _row_has(image: Image, y: int, from_x: int, to_x: int) -> bool:
	for x: int in range(from_x, to_x + 1):
		if _h.near(image.get_pixel(x, y), _cue):
			return true
	return false


## 某一条道里敌人 HP 条的**已存段**像素数（RED_500）。
## 量的是身体上方那条缝（身体顶边往上 5px 起的两行）—— 身体在它下面，故这两行里
## 数到的 RED_500 只可能是血条本身，不会混进同色的 Runner 身体。
func _hp_fill(image: Image, lane: int) -> int:
	var top: float = ENEMY_BAND_TOP + float(lane) * ENEMY_ROW_HEIGHT + ENEMY_HP_ROW_OFFSET
	return _count_rect(image, Rect2(0.0, top, VIEWPORT.x, ENEMY_HP_HEIGHT), _runner)


## 弹道在取样窗口里**最上面那一行**的像素中点，返回图像坐标 (x, y)。一个都没有时返回 (-1, -1)。
##
## 取最上面一行而不是最下面：机器在战场下沿，敌人在地面上方，故弹道的**命中端在高处**——
## 最上面那一行就是它末端落在的那个身位。
func _top_row(image: Image, rect: Rect2, wanted: Color) -> Vector2i:
	if image == null:
		return Vector2i(-1, -1)
	var extent: Vector2i = image.get_size()
	var from_x: int = clampi(int(rect.position.x), 0, extent.x)
	var to_x: int = clampi(int(rect.end.x), 0, extent.x)
	for y: int in range(clampi(int(rect.position.y), 0, extent.y),
			clampi(int(rect.end.y), 0, extent.y)):
		var sum: int = 0
		var hits: int = 0
		for x: int in range(from_x, to_x):
			if _h.near(image.get_pixel(x, y), wanted):
				sum += x
				hits += 1
		if hits > 0:
			return Vector2i(sum / hits, y)
	return Vector2i(-1, -1)


## 某一格矩形内判据色像素的包围盒。一个都没有时返回空 Rect2。
## 只用来量**命中闪光**（WHITE 在 COMBAT 里只有这一处，不会被别的东西并进来）；
## 武器反馈的盒子走 _cue_box —— 它同色于弹道，不能整窗取包围盒。
func _color_box(image: Image, rect: Rect2, wanted: Color) -> Rect2:
	if image == null:
		return Rect2()
	var extent: Vector2i = image.get_size()
	var left: int = -1
	var top: int = -1
	var right: int = -1
	var bottom: int = -1
	for y: int in range(clampi(int(rect.position.y), 0, extent.y), clampi(int(rect.end.y), 0, extent.y)):
		for x: int in range(clampi(int(rect.position.x), 0, extent.x), clampi(int(rect.end.x), 0, extent.x)):
			if not _h.near(image.get_pixel(x, y), wanted):
				continue
			left = x if left < 0 else mini(left, x)
			top = y if top < 0 else mini(top, y)
			right = maxi(right, x)
			bottom = maxi(bottom, y)
	if right < 0:
		return Rect2()
	return Rect2(left, top, right - left + 1, bottom - top + 1)


## `热量` 读数格的百分比。读数形如 `4%`；拆不出来时返回 -1（断言会打红，而不是静默当 0）。
func _heat_percent(combat: Node) -> int:
	var block: Node = _find(combat, "Heat")
	if block == null:
		return -1
	var value: Label = block.get_node_or_null(^"Value") as Label
	if value == null or not value.text.ends_with("%"):
		return -1
	return int(value.text.trim_suffix("%"))


func _rect_text(box: Rect2) -> String:
	if box.size.x <= 0.0 or box.size.y <= 0.0:
		return "（没有像素）"
	return "%d×%d @ (%d,%d)" % [int(box.size.x), int(box.size.y), int(box.position.x), int(box.position.y)]


## 拼一张 2×2 的对照图：四帧各放大后并排，人工复核时一眼能顺着因果关系看下去。
func _sheet(tiles: Array, tag: String) -> void:
	var cell := Vector2i(CANVAS.x * ZOOM, CANVAS.y * ZOOM)
	var sheet: Image = Image.create_empty(cell.x * 2, cell.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(_backdrop)
	for index: int in tiles.size():
		var tile: Image = Image.new()
		tile.copy_from(tiles[index])
		tile.resize(cell.x, cell.y, Image.INTERPOLATE_NEAREST)
		if tile.get_format() != Image.FORMAT_RGBA8:
			tile.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(tile, Rect2i(Vector2i.ZERO, cell), Vector2i(index % 2 * cell.x, index / 2 * cell.y))
	_ctx.check(sheet.save_png("%s%s.png" % [SHOT_PATH, tag]) == OK, "应能写出四帧拼图 %s.png" % tag)


## 写验收机器丙：CORE → 分流 → 针 / 炸弹 / 锯。三把武器同一拍开火，
## 用来取「三把的反馈形态一眼分得开」的证据。
func _write_kit_blueprint() -> bool:
	var spec: Array = [
		["core", "核心", _kind_core, _fn_none],
		["split", "分流", _kind_function, _fn_split],
		["needle", "针", _kind_weapon, _fn_none, _weapon_needle],
		["bomb", "炸弹", _kind_weapon, _fn_none, _weapon_bomb],
		["saw", "锯", _kind_weapon, _fn_none, _weapon_saw],
	]
	var edges: Array = [["core", "split"], ["split", "needle"], ["split", "bomb"], ["split", "saw"]]
	var blueprint: Resource = _build_blueprint(spec, edges, "验收机器丙")
	return bool(blueprint.call(&"save_to", KIT_PATH)) if blueprint != null else false


## 写验收机器甲：CORE → 分流 → 针 ×2。走数据类落盘，于是这份图与玩家在整备界面拖出来的
## 是同一种东西，机器重建也走同一条路（09 §3.2）。
func _write_clear_blueprint() -> bool:
	var spec: Array = [
		["core", "核心", _kind_core, _fn_none],
		["split", "分流", _kind_function, _fn_split],
		# 第 5 项是武器种类：机器要打的伤害只由它决定，显示名不参与解析
		# （按显示名反查的那条桥已删，见 scripts/data/weapon_data.gd）。
		["needle_a", "针", _kind_weapon, _fn_none, _weapon_needle],
		["needle_b", "针", _kind_weapon, _fn_none, _weapon_needle],
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
		# 武器种类可选：非武器节点不写，留 NONE（它们没有武器种类可言）。
		if item.size() > 4:
			node.set(&"weapon_kind", int(item[4]))
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


## 存证据图：原图与最近邻放大各一张。放大是为了让 16×16 的占位敌人（PET-80 前 8×8）
## 在人工复核时看得见。
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
	for file_name: String in [CLEAR_PATH.get_file(), BARE_PATH.get_file(), KIT_PATH.get_file()]:
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
	_lines.append("- 可读反馈（PET-76）：机器甲的开火前 / 齐射 / 击杀 / 第 1 条道挨打 四帧 + 机器丙（针/炸弹/锯）三把形态对照")
	_lines.append("- 证据图：%s{before,spawn,killed,cleared,read_before,read_fire,read_kill,read_lane,read_kinds}.png 与 %s*_%dx.png、四帧拼图 %sread_sheet.png" % [SHOT_PATH, SHOT_PATH, ZOOM, SHOT_PATH])
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
