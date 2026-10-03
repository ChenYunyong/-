## test_state_loop.gd
## 职责：在真实 Autoload 单例 + **真实场景路由**上跑状态流转（09 §1 集成层）。
##       四段：
##       ① 既有接线核对 —— 五个 Autoload 就位、EventBus 转发、RunState 种子与生命周期；
##       ② S1-12 · 十轮完整循环：状态与场景逐轮成对、逐轮序列逐项相同（不漂移）；
##       ③ S1-12 · R5 防重入：切换进行中的再次请求 / 同帧连点不得多切一次；
##       ④ S1-12 · R1 不自动推进：PREPARATION / COMBAT / REWARD 各停 10 分钟模拟时间纹丝不动，
##          并各配一次「真实确认」的反向对照，证明停住不是因为整条链路是死的。
## 所属系统：tests
## 依赖：test_context, GameFlow / EventBus / RunState / DataRegistry 四个 Autoload
## 禁止：本文件不得改动 Autoload 的业务状态 —— 用完必须还原到 MAIN_MENU；
##       不得绕过 GameFlow 的迁移表直接写 _state（一律走 change_state / request_* 三个语义入口）；
##       不得读真实时间（停留时长由 TestClock 的模拟 tick 计量，靠 --fixed-fps 压缩）；
##       不得依赖真实随机（RunState 一律显式 seed）；不得直接调场景的私有回调当作「玩家操作」。

extends RefCounted

const EXPECTED_AUTOLOADS: PackedStringArray = ["EventBus", "GameFlow", "DataRegistry", "RunState", "Settings"]

## S1-12 / 09 §3.1：完整往返跑 10 轮。
const ROUND_COUNT: int = 10
## 一轮的完整状态路径（每步入一个状态，共 7 步，回到 MAIN_MENU）。
## 首轮的 BOOT → MAIN_MENU 由既有接线段完成，不计入轮内 —— 否则第 1 轮会比第 10 轮多一项，
## 「逐项相同」就成了不可能命题。
const ROUND_PATH: PackedStringArray = [
	"PREPARATION", "COMBAT", "REWARD", "PREPARATION", "COMBAT", "RESULT", "MAIN_MENU",
]
## R1 实测的停留时长：10 分钟模拟时间（09 §3.1）。
const HOLD_SECONDS: float = 600.0
## 场景语义尺寸。与工程视口一致（project.godot 的 320×180），
## 也让 apply_layout_for() 拿到真实档位 —— CTA / 卡片的命中矩形要在这个尺寸下才有面积。
const VIEWPORT: Vector2 = Vector2(320.0, 180.0)
## 本局固定种子（03 §6：全项目随机必须且只能来自 RunState，且必须可复现）。
const RUN_SEED: int = 20261003
## S1-12 四段至少应有的断言条数（实测 313，取 300 作下限）。
## 反向对照实测：让路由整体失效后，本文件的断言数会从 313 掉到 ~201 ——
## 因为「场景里找不到 CTA / 卡片」这类前置会连带跳过后续断言。
## 少了这条下限，那种情况只表现为「失败的没几条」，很容易被读成「基本没事」。
const MIN_ASSERTIONS: int = 300

var _ctx: RefCounted = null
var _tree: SceneTree = null
var _flow: Node = null
var _run_state: Node = null
var _flow_script: GDScript = null
## 真实 GameFlow 的 state_changed 全量记录，用于「状态变化次数 vs 合法请求数」。
var _transitions: Array = []


func run(ctx: RefCounted, tree: SceneTree) -> void:
	_ctx = ctx
	_tree = tree
	var asserted_before: int = ctx.passed + ctx.failed

	ctx.begin_case("集成 · 五个 Autoload 就位")
	for singleton_name: String in EXPECTED_AUTOLOADS:
		ctx.check(tree.root.get_node_or_null(NodePath(singleton_name)) != null, "%s 应已作为 Autoload 加载" % singleton_name)

	var bus: Node = tree.root.get_node_or_null(NodePath("EventBus"))
	_flow = tree.root.get_node_or_null(NodePath("GameFlow"))
	_run_state = tree.root.get_node_or_null(NodePath("RunState"))
	if not ctx.check(bus != null and _flow != null and _run_state != null, "EventBus / GameFlow / RunState 应可用"):
		return
	_flow_script = _flow.get_script()

	ctx.begin_case("集成 · EventBus 收到真实 GameFlow 的状态切换")
	var seen: Array = []
	var handler: Callable = func(from, to) -> void: seen.append([from, to])
	bus.connect(&"state_changed", handler)

	ctx.check(_flow.call(&"change_state", _flow_script.GameState.MAIN_MENU), "BOOT → MAIN_MENU")
	ctx.check(_flow.call(&"change_state", _flow_script.GameState.PREPARATION), "MAIN_MENU → PREPARATION")
	ctx.check(_flow.call(&"request_start_combat"), "PREPARATION → COMBAT（玩家动作入口）")
	ctx.check(_flow.call(&"change_state", _flow_script.GameState.REWARD), "COMBAT → REWARD")
	ctx.check(_flow.call(&"change_state", _flow_script.GameState.PREPARATION), "REWARD → PREPARATION")
	ctx.equal(seen.size(), 5, "EventBus 应收到 5 次切换")
	ctx.equal(int(_flow.call(&"get_state")), _flow_script.GameState.PREPARATION, "最终状态")

	ctx.begin_case("集成 · RunState 种子可复现（03 §6）")
	_run_state.call(&"start_run", 20261003)
	ctx.equal(int(_run_state.call(&"get_run_seed")), 20261003, "显式种子应被采纳")
	var rng: RandomNumberGenerator = _run_state.call(&"get_rng")
	ctx.check(rng != null, "应能取到随机源")
	var first: int = rng.randi()
	rng.seed = 20261003
	ctx.equal(rng.randi(), first, "同一种子必须产生同一序列")

	ctx.begin_case("集成 · RunState 生命周期")
	_run_state.call(&"end_run")
	ctx.check(not bool(_run_state.call(&"is_active")), "结束本局后 is_active 应为 false")
	_run_state.call(&"end_run")
	ctx.check(not bool(_run_state.call(&"is_active")), "重复结束不得崩溃")

	# 还原全局状态，避免污染后续用例。
	bus.disconnect(&"state_changed", handler)
	_flow.call(&"change_state", _flow_script.GameState.RESULT)
	_flow.call(&"change_state", _flow_script.GameState.MAIN_MENU)
	ctx.equal(int(_flow.call(&"get_state")), _flow_script.GameState.MAIN_MENU, "已还原到 MAIN_MENU")

	# ===== 以下为 S1-12 新增：真实路由下的循环 / 防重入 / 不自动推进 =====
	_start_recording()
	await _settle()  # 让上面那两次延迟路由落地：起点是真实的 main_menu 场景 + MAIN_MENU。
	var wave_rolls: Array = await _run_round_loop(ctx)
	_run_run_state_replay(ctx, wave_rolls)
	_run_pairing_discrimination(ctx)
	await _run_reentrancy(ctx)
	await _run_hold_checks(ctx)
	_stop_recording()

	ctx.begin_case("S1-12 · 收尾还原")
	await _goto("MAIN_MENU")
	ctx.equal(int(_flow.call(&"get_state")), _state("MAIN_MENU"), "收尾应还原到 MAIN_MENU")
	ctx.equal(_scene_path(), _path_of("MAIN_MENU"), "收尾场景应与状态成对")

	# 覆盖度下限：某个用例中途返回会让后面的断言**一条都不跑**，而报告仍是「失败项：无」——
	# 那不是通过，是没跑（同 input_smoke.gd 的 MIN_ASSERTIONS）。
	ctx.check(ctx.passed + ctx.failed - asserted_before >= MIN_ASSERTIONS,
		"S1-12 四段应至少产生 %d 条断言（实际 %d）—— 低于此数说明有用例中途没跑完" % [
			MIN_ASSERTIONS, ctx.passed + ctx.failed - asserted_before,
		])


## 交付物 1：十轮完整往返。每轮记录**实测**的状态序列，再把第 1 轮与第 N 轮并列比较。
func _run_round_loop(ctx: RefCounted) -> Array:
	ctx.begin_case("S1-12 · 十轮完整循环：状态与场景逐轮成对（09 §3.1）")
	ctx.equal(int(_flow.call(&"get_state")), _state("MAIN_MENU"), "循环起点应为 MAIN_MENU")
	ctx.equal(_scene_path(), _path_of("MAIN_MENU"), "循环起点场景应是 MAIN_MENU 的责任场景")

	_run_state.call(&"start_run", RUN_SEED)
	var waves: Array = []
	var rounds: Array = []
	var moved_from: int = _transitions.size()

	for round_index: int in ROUND_COUNT:
		var label: String = "第 %d 轮" % (round_index + 1)
		waves.append(int((_run_state.call(&"get_rng") as RandomNumberGenerator).randi()))
		var seq: Array[String] = []
		await _step(ctx, seq, "%s MAIN_MENU → PREPARATION" % label, _ask_change("PREPARATION"), "PREPARATION")
		# 噪声请求：重复切到当前态必须被忽略。10 轮各来一次，盯住「循环不会被重复请求推快」——
		# 若它生效，下面那条「状态变化次数应恰为 7」当场变成 8。
		ctx.check(not bool(_flow.call(&"change_state", _state("PREPARATION"))),
			"%s：重复切到当前态应被忽略" % label)
		await _step(ctx, seq, "%s PREPARATION → COMBAT" % label, _ask_start_combat(), "COMBAT")
		await _step(ctx, seq, "%s COMBAT → REWARD" % label, _ask_change("REWARD"), "REWARD")
		await _step(ctx, seq, "%s REWARD → PREPARATION" % label, _ask_change("PREPARATION"), "PREPARATION")
		await _step(ctx, seq, "%s PREPARATION → COMBAT" % label, _ask_start_combat(), "COMBAT")
		await _step(ctx, seq, "%s COMBAT → RESULT" % label, _ask_end_run(), "RESULT")
		await _step(ctx, seq, "%s RESULT → MAIN_MENU" % label, _ask_change("MAIN_MENU"), "MAIN_MENU")

		var moved: int = _transitions.size() - moved_from
		ctx.equal(moved, ROUND_PATH.size(),
			"%s 的状态变化次数应恰为合法请求数 %d（多一次即说明循环被推快）" % [label, ROUND_PATH.size()])
		moved_from = _transitions.size()
		ctx.equal(seq, _path_array(), "%s 的状态序列应与约定路径逐项相同" % label)
		rounds.append(seq)

	ctx.equal(rounds.size(), ROUND_COUNT, "完成的轮数")
	var baseline: Array = rounds[0]
	for index: int in range(1, ROUND_COUNT):
		var label: String = "第 %d 轮" % (index + 1)
		if index == ROUND_COUNT - 1:
			label += "（末轮）"
		ctx.equal(rounds[index], baseline, "%s 的状态序列应与第 1 轮逐项相同" % label)
	return waves


## 交付物 1 的收尾：十轮之后本局种子与波次序列仍可复现（03 §6）。
func _run_run_state_replay(ctx: RefCounted, waves: Array) -> void:
	ctx.begin_case("S1-12 · 十轮之后 RunState 的波次与种子可复现（03 §6）")
	ctx.equal(int(_run_state.call(&"get_run_seed")), RUN_SEED, "十轮往返不得改写本局种子")
	ctx.check(bool(_run_state.call(&"is_active")), "十轮往返期间本局应一直是进行中的一局")
	ctx.equal(waves.size(), ROUND_COUNT, "十轮应各留下一次波次掷点")

	_run_state.call(&"start_run", RUN_SEED)
	var replay: Array = []
	for _index: int in ROUND_COUNT:
		replay.append(int((_run_state.call(&"get_rng") as RandomNumberGenerator).randi()))
	ctx.equal(replay, waves, "同一 seed 重放应得到逐项相同的波次序列")

	# 反向对照：换一个 seed 必须换一条序列 —— 否则上面那条「相同」可能只是恒定的常量。
	_run_state.call(&"start_run", RUN_SEED + 1)
	var other: Array = []
	for _index: int in ROUND_COUNT:
		other.append(int((_run_state.call(&"get_rng") as RandomNumberGenerator).randi()))
	ctx.not_equal(other, replay, "换一个 seed 应得到不同序列（反向对照）")

	_run_state.call(&"end_run")
	ctx.check(not bool(_run_state.call(&"is_active")), "收尾：本局应已结束，不给后续留一个进行中的局")


## 「状态与场景成对」这条断言的判别力自证：它必须能对**别的状态**判false。
## 若 get_scene_path_for() 退化成一个恒等值、或成对判断被写成恒真，这几条会立刻变红。
func _run_pairing_discrimination(ctx: RefCounted) -> void:
	ctx.begin_case("S1-12 · 成对断言的判别力（不是恒真）")
	var current: int = int(_flow.call(&"get_state"))
	ctx.check(_pairing_ok(current), "当前状态与当前场景应判为成对")
	var others: Array[String] = []
	for state_name: String in ROUND_PATH:
		if _state(state_name) != current and not others.has(state_name):
			others.append(state_name)
	for state_name: String in others:
		ctx.check(not _pairing_ok(_state(state_name)),
			"当前场景对 %s 必须判为脱钩 —— 否则成对判断恒真" % state_name)
	ctx.equal(others.size(), 4, "应对除当前态外的 4 个其它状态各判一次")


## 交付物 2：R5 防重入。断言的是「状态变化次数与合法请求数的关系」，不是只看最终状态。
func _run_reentrancy(ctx: RefCounted) -> void:
	ctx.begin_case("S1-12 · 防重入：只有合法请求能推动循环")
	await _goto("PREPARATION")
	# 三类噪声请求各来一次。它们都不得产生切换 —— 状态变化次数必须等于**合法**请求数，
	# 而不是「调用了几次」。
	var before_noise: int = _transitions.size()
	ctx.check(not bool(_flow.call(&"change_state", _state("COMBAT"))),
		"change_state 不得把 PREPARATION 推进 COMBAT（R1）")
	ctx.check(not bool(_flow.call(&"change_state", _state("PREPARATION"))),
		"重复切到当前态应被忽略")
	ctx.check(bool(_flow.call(&"request_start_combat")), "第一次「开始战斗」应成功")
	ctx.check(not bool(_flow.call(&"request_start_combat")), "紧接着的第二次「开始战斗」应被拒绝")
	ctx.equal(_transitions.size() - before_noise, 1, "四次调用里只有 1 次合法：状态变化次数必须恰为 1")
	ctx.equal(int(_flow.call(&"get_state")), _state("COMBAT"), "噪声请求后应停在 COMBAT")
	await _settle()
	ctx.equal(_scene_path(), _path_of("COMBAT"), "场景应与状态成对")

	ctx.begin_case("S1-12 · R5 防重入：切换进行中的再次请求不得多切一次")
	await _goto("MAIN_MENU")

	# 嵌套请求：在 state_changed 回调里再请求一次切换。
	# 挑的是 PREPARATION → RESULT —— 它在迁移表里**合法**，因此唯一能拒掉它的只有 R5 重入闸门；
	# 用一条本来就不合法的边去测，会把「闸门生效」与「迁移表不允许」混成一个结果。
	var before_nested: int = _transitions.size()
	var nested_results: Array = []
	var nested: Callable = func(_from: int, _to: int) -> void:
		if _to == _state("PREPARATION"):
			nested_results.append(bool(_flow.call(&"change_state", _state("RESULT"))))
	_flow.connect(&"state_changed", nested)
	var accepted: bool = bool(_flow.call(&"change_state", _state("PREPARATION")))
	_flow.disconnect(&"state_changed", nested)

	ctx.check(accepted, "MAIN_MENU → PREPARATION 应成功")
	ctx.equal(nested_results.size(), 1, "切换回调应在切换进行中被调用一次")
	if nested_results.size() == 1:
		ctx.check(not bool(nested_results[0]), "回调内再次请求切换应被拒绝（R5）")
	ctx.equal(int(_flow.call(&"get_state")), _state("PREPARATION"), "重入被拒后应停在 PREPARATION，不得被推到 RESULT")
	ctx.equal(_transitions.size() - before_nested, 1, "1 次合法请求只应产生 1 次状态变化")
	await _settle()
	ctx.equal(_scene_path(), _path_of("PREPARATION"), "重入被拒后场景仍应与状态成对")

	# 反向对照：去掉重入上下文后，同一条边必须真的能走通 ——
	# 否则上面那条「被拒绝」也可能只是因为 RESULT 这条路整个是死的。
	var before_plain: int = _transitions.size()
	ctx.check(bool(_flow.call(&"change_state", _state("RESULT"))),
		"非重入上下文中 PREPARATION → RESULT 应成功（排除「链路本来就是死的」）")
	ctx.equal(_transitions.size() - before_plain, 1, "这次合法请求应恰好产生 1 次状态变化")
	await _settle()
	ctx.equal(_scene_path(), _path_of("RESULT"), "RESULT 场景应与状态成对")

	# 同帧连点：两次 POINTER_PRESS 之间不放帧，只允许产生一次切换。
	# 走的是引擎真实的 GUI 拾取（root.push_input），不是直接调场景的私有回调。
	await _goto("PREPARATION")
	var cta: Control = _find_control("ButtonStartCombat")
	if not ctx.check(cta != null, "PREPARATION 场景应有唯一 CTA（ButtonStartCombat）"):
		return
	var before_double: int = _transitions.size()
	await _click(cta, 2)
	ctx.equal(_transitions.size() - before_double, 1, "同帧连点两次 CTA 只应发生 1 次切换")
	ctx.equal(int(_flow.call(&"get_state")), _state("COMBAT"), "同帧连点后应停在 COMBAT")
	ctx.equal(_scene_path(), _path_of("COMBAT"), "场景应与状态成对")


## 交付物 3：R1 不自动推进 + 每站的「真实确认」反向对照。
func _run_hold_checks(ctx: RefCounted) -> void:
	var clock: Node = _tree.get(&"clock")
	ctx.begin_case("S1-12 · R1：PREPARATION 停 10 分钟不动，一次真实点击必须动")
	await _goto("PREPARATION")
	await _expect_frozen(ctx, clock, "PREPARATION")
	var cta: Control = _find_control("ButtonStartCombat")
	if ctx.check(cta != null, "PREPARATION 场景应有唯一 CTA"):
		var before: int = _transitions.size()
		await _click(cta, 1)
		ctx.equal(_transitions.size() - before, 1, "点击唯一 CTA 应恰好产生 1 次切换")
		ctx.equal(int(_flow.call(&"get_state")), _state("COMBAT"), "确认后应进入 COMBAT")
		ctx.equal(_scene_path(), _path_of("COMBAT"), "确认后场景应与状态成对")

	ctx.begin_case("S1-12 · R1：COMBAT 停 10 分钟不动，本波清空必须动")
	await _goto("COMBAT")
	await _expect_frozen(ctx, clock, "COMBAT")
	var battle: Node = _tree.current_scene
	if ctx.check(battle != null and battle.has_method(&"on_wave_cleared"),
			"COMBAT 场景应有本波清空入口（Stage 4 的玩法触发点）"):
		var before_wave: int = _transitions.size()
		battle.call(&"on_wave_cleared")
		await _settle()
		ctx.equal(_transitions.size() - before_wave, 1, "本波清空应恰好产生 1 次切换")
		ctx.equal(int(_flow.call(&"get_state")), _state("REWARD"), "清空本波后应进入 REWARD")
		ctx.equal(_scene_path(), _path_of("REWARD"), "清空本波后场景应与状态成对")

	ctx.begin_case("S1-12 · R1：REWARD 停 10 分钟不动，选定奖励项必须动")
	await _goto("REWARD")
	await _expect_frozen(ctx, clock, "REWARD")
	var card: Control = _find_control("Card1")
	if ctx.check(card != null, "REWARD 场景应有可点击的选项卡（Card1）"):
		var before_pick: int = _transitions.size()
		await _click(card, 1)
		ctx.equal(_transitions.size() - before_pick, 1, "选定奖励项应恰好产生 1 次切换")
		ctx.equal(int(_flow.call(&"get_state")), _state("PREPARATION"), "选定后应回 PREPARATION")
		ctx.equal(_scene_path(), _path_of("PREPARATION"), "选定后场景应与状态成对")


## 在 state_name 停留 HOLD_SECONDS 模拟秒，断言状态 / 场景 / 切换次数三者一动不动。
func _expect_frozen(ctx: RefCounted, clock: Node, state_name: String) -> void:
	if not ctx.check(clock != null, "测试时钟应已挂载（TestClock）"):
		return
	var state_before: int = int(_flow.call(&"get_state"))
	var scene_before: String = _scene_path()
	var moved_before: int = _transitions.size()
	clock.set(&"elapsed", 0.0)
	var deadline: int = Time.get_ticks_msec() + int(_tree.call(&"wall_clock_budget_ms"))
	while float(clock.get(&"elapsed")) < HOLD_SECONDS and Time.get_ticks_msec() < deadline:
		await _tree.process_frame

	var reached: float = float(clock.get(&"elapsed"))
	ctx.check(reached >= HOLD_SECONDS,
		"%s 应跑满 %.0f 秒模拟时间，实际 %.1f 秒（是否漏了 --fixed-fps？）" % [state_name, HOLD_SECONDS, reached])
	ctx.equal(int(_flow.call(&"get_state")), state_before, "%s 停留 10 分钟后状态不得变化" % state_name)
	ctx.equal(_scene_path(), scene_before, "%s 停留 10 分钟后场景不得被换掉" % state_name)
	ctx.equal(_transitions.size(), moved_before, "%s 停留 10 分钟内不得发生任何一次切换" % state_name)


## 走一步：请求 → 断言请求本身被接受 → 等路由落地 → 断言「状态与场景成对」。
## 每轮的状态序列因此是**实测出来的**，不是照着预期抄一遍。
func _step(ctx: RefCounted, seq: Array[String], label: String, request: Callable, expected: String) -> void:
	ctx.check(bool(request.call()), "%s 的请求应被接受" % label)
	ctx.equal(int(_flow.call(&"get_state")), _state(expected), "%s 后的状态" % label)
	seq.append(expected)
	await _settle()
	ctx.equal(_scene_path(), _path_of(expected), "%s 后场景应与状态成对（不得脱钩）" % label)


## 注入一次**真实**点击：走引擎的 GUI 拾取（root.push_input），而不是直接调场景的私有回调 ——
## 后者只能证明那个函数写了什么，证明不了玩家的一指头按下去真的会走到它（input_smoke.gd 的立身之本）。
## presses > 1 时刻意**不放帧**，用于「同帧连点只生效一次」。
func _click(control: Control, presses: int) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for _index: int in presses:
		var press: InputEventMouseButton = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.position = at
		press.pressed = true
		_tree.root.push_input(press)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = at
	release.pressed = false
	_tree.root.push_input(release)
	await _settle()


## 等路由落地并落一次布局。change_scene_to_file 是**延迟**的：调用当帧 current_scene 先变 null，
## 新场景要到帧末才挂上来。少等一帧就会读到上一个场景，把「还没落地」误判成「脱钩」。
func _settle() -> void:
	for _frame: int in 3:
		await _tree.process_frame
	if _tree.current_scene is Control:
		(_tree.current_scene as Control).size = VIEWPORT
	if _tree.current_scene != null and _tree.current_scene.has_method(&"apply_layout_for"):
		_tree.current_scene.call(&"apply_layout_for", VIEWPORT)
	await _tree.process_frame


## 沿**合法边**走到目标状态。本用例自己不得绕过 GameFlow 的迁移表。
func _goto(state_name: String) -> bool:
	var target: int = _state(state_name)
	for _step_count: int in 8:
		var current: int = int(_flow.call(&"get_state"))
		if current == target:
			await _settle()
			return true
		var next: int = _next_hop(current, target)
		if next < 0:
			return false
		if current == _state("PREPARATION") and next == _state("COMBAT"):
			_flow.call(&"request_start_combat")
		elif current == _state("COMBAT") and next == _state("RESULT"):
			_flow.call(&"request_end_run")
		else:
			_flow.call(&"change_state", next)
		await _settle()
	return int(_flow.call(&"get_state")) == target


## 从 from 到 to 的下一跳，在 ALLOWED_TRANSITIONS 上做广度优先。
## 额外补一条 PREPARATION → COMBAT：它在迁移表里刻意缺席，只能经 request_start_combat() 走
## （03 §1.1 R1），但玩家要到达 COMBAT 就只有这一条路，导航时必须认它。
func _next_hop(from: int, to: int) -> int:
	var adjacency: Dictionary = {}
	for key: int in _flow_script.ALLOWED_TRANSITIONS:
		adjacency[key] = (Array(_flow_script.ALLOWED_TRANSITIONS[key]) as Array).duplicate()
	adjacency[_state("PREPARATION")].append(_state("COMBAT"))
	var queue: Array[int] = [from]
	var came: Dictionary = {from: -1}
	while not queue.is_empty():
		var node: int = queue.pop_front()
		for neighbour: int in adjacency.get(node, []):
			if came.has(neighbour):
				continue
			came[neighbour] = node
			if neighbour == to:
				var hop: int = to
				while int(came[hop]) != from and int(came[hop]) != -1:
					hop = int(came[hop])
				return hop
			queue.append(neighbour)
	return -1


func _start_recording() -> void:
	_transitions.clear()
	_flow.connect(&"state_changed", _on_state_changed)


func _stop_recording() -> void:
	_flow.disconnect(&"state_changed", _on_state_changed)


func _on_state_changed(_from: int, _to: int) -> void:
	_transitions.append(_to)


func _ask_change(state_name: String) -> Callable:
	return func() -> bool: return bool(_flow.call(&"change_state", _state(state_name)))


func _ask_start_combat() -> Callable:
	return func() -> bool: return bool(_flow.call(&"request_start_combat"))


func _ask_end_run() -> Callable:
	return func() -> bool: return bool(_flow.call(&"request_end_run"))


func _path_array() -> Array[String]:
	var names: Array[String] = []
	for state_name: String in ROUND_PATH:
		names.append(state_name)
	return names


func _pairing_ok(state: int) -> bool:
	var expected: String = _path_of_state(state)
	if expected.is_empty():
		return _tree.current_scene == null
	return _scene_path() == expected


func _scene_path() -> String:
	return _tree.current_scene.scene_file_path if _tree.current_scene != null else ""


func _path_of(state_name: String) -> String:
	return _path_of_state(_state(state_name))


func _path_of_state(state: int) -> String:
	return String(_flow.call(&"get_scene_path_for", state))


func _find_control(node_name: String) -> Control:
	if _tree.current_scene == null:
		return null
	return _tree.current_scene.find_child(node_name, true, false) as Control


func _state(state_name: String) -> int:
	return int(_flow_script.GameState[state_name])
