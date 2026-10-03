## result_smoke.gd
## 职责：RESULT 场景的场景冒烟（09 §1）—— 经真实 GameFlow 路由进入（COMBAT 核心被摧毁）、
##       两个读数落点真的显示在界面上（03 §6 的种子取自 RunState）、
##       **停留 10 模拟分钟不自动离开（00 §5 硬规则第 1 条）**、
##       两个出口都**经 GameFlow 真实路由**走得掉（返回主菜单 / 再来一局）、
##       窄屏折叠不动状态、按钮 Disabled 底色经真实主题解析为 NAVY_800（04 §5.1）。**单独进程**运行。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, test_clock, scenes/result/result.tscn, scripts/ui/result_screen.gd
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 reward_smoke.gd 的约束）；一律 load() + 经 /root 取节点。
##       本文件不得写任何字面色值 —— 判据色一律经 Palette 取。
##
## 运行：需要 --fixed-fps 60，否则「停留 600 秒不自动推进」跑不满（该用例会明确报红）。
##
## 为什么不挂进 run_tests.gd：本用例要真的把 GameFlow 一路推到 RESULT 并让路由换掉当前场景，
## 那会污染同进程里 test_state_loop.gd 的场景断言。
##
## 本批只做骨架与布局，故这里**不测任何玩法统计**（波次计分 / 掉落结算属 Stage 4 的 S4-08）——
## 测的是「两个读数显示出来了」「没人点就永远不走」「点了才走，且走的是 GameFlow 路由」。
##
## 只有首个用例**逐跳**走完进入链路；后面要回到 RESULT 的用例只把它当布景，
## 直接走状态机里最短的那条边（03 §1：PREPARATION → RESULT），不把同一条链再抄一遍。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const CLOCK_PATH: String = "res://tests/unit/test_clock.gd"
const RESULT_SCENE_PATH: String = "res://scenes/result/result.tscn"
## 前三跳（PREPARATION / COMBAT）刻意写死路径而不是问 GameFlow 要 ——
## 本用例要证的就是「这条链上的每一跳都通」，问被测实现就成了同义反复。
const PREP_SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const COMBAT_SCENE_PATH: String = "res://scenes/combat/combat.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/main_menu.tscn"
const RESULT_SCRIPT_PATH: String = "res://scripts/ui/result_screen.gd"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const PALETTE_PATH: String = "res://scripts/data/palette.gd"
const LOG_PATH: String = "res://tests/output/result_smoke.log"

## 06 §1 基准与 §7.1 的窄屏取样。
const REFERENCE_VIEWPORT: Vector2 = Vector2(320.0, 180.0)
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)

## R1 实测：停留 600 秒（10 分钟）模拟时间不得自动离开 RESULT。
const R1_SIMULATED_SECONDS: float = 600.0
## 漏加 --fixed-fps 时的兜底上限，与 run_tests.gd 同值。
const WALL_CLOCK_BUDGET_MS: int = 120_000

## 06 §1：出口按钮本身就是可点击区域，下限 44 设备像素。
const MIN_TOUCH_SIZE: float = 44.0

## 03 §6：本局随机种子由 RunState 逐局记录。这里先起一局固定种子，
## 再看结算界面上的种子读数是不是**它** —— 量的是「显示的是不是那一份」，不是「有没有文字」。
const FIXED_SEED: int = 424242

## 出口按钮的矩形**相对按钮区原点**，在本文件独立复写一遍
## （期望值若与被测实现同源，实现改错时两边一起错）。推导依据见 result_layout.gd 的文件头。
const ACTIONS_AREA_WIDE: Rect2 = Rect2(8.0, 128.0, 304.0, 44.0)
const ACTION_RECTS_WIDE: Array[Rect2] = [
	Rect2(0.0, 0.0, 148.0, 44.0),
	Rect2(156.0, 0.0, 148.0, 44.0),
]
const ACTIONS_AREA_NARROW: Rect2 = Rect2(8.0, 216.0, 164.0, 96.0)
const ACTION_RECTS_NARROW: Array[Rect2] = [
	Rect2(0.0, 0.0, 164.0, 44.0),
	Rect2(0.0, 52.0, 164.0, 44.0),
]

## 顺序即场景节点顺序：0 = 返回主菜单（次要），1 = 再来一局（主要）。
const ACTION_NAMES: PackedStringArray = ["ButtonMenu", "ButtonRetry"]
const WAVE_LABEL: String = "WaveValue"
const SEED_LABEL: String = "SeedValue"

var _ctx: RefCounted = null
var _screen_script: GDScript = null
var _flow_script: GDScript = null
var _palette: GDScript = null
var _clock: Node = null
var _lines: Array[String] = []
## 全程只连一次 state_changed；每个用例在开始前 clear()，
## 于是「这一段里有几次切换」与信号的生命周期解耦（不必每处各写一份 connect / disconnect）。
var _transitions: Array = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_screen_script = load(RESULT_SCRIPT_PATH)
	_flow_script = load(GAME_FLOW_PATH)
	_palette = load(PALETTE_PATH)
	_clock = Node.new()
	_clock.set_script(load(CLOCK_PATH))
	_clock.name = "SmokeClock"
	root.add_child(_clock)

	await process_frame
	_run_run_state_case()
	await _run_routed_entry_case()
	_run_readout_case()
	_run_action_layout_case()
	await _run_no_auto_advance_case()
	_run_narrow_case()
	# 两个出口都会把当前场景换掉，故必须排在最后 ——
	# 否则后面每个用例的 current_scene 都已经不是结算界面，会连锁报一串与它们本身无关的失败。
	await _run_exit_case()
	_finish()


func _on_state_changed(from: int, to: int) -> void:
	_transitions.append([from, to])


## 开始记录一段新的切换窗口。信号只连一次，见 _transitions 的说明。
func _watch_transitions(flow: Node) -> void:
	_transitions.clear()
	if not flow.is_connected(&"state_changed", _on_state_changed):
		flow.connect(&"state_changed", _on_state_changed)


## 03 §6：种子由 RunState 逐局记录，结算界面读它。先起一局固定种子，
## 于是后面「界面上的种子等于多少」才有确定的期望值。
func _run_run_state_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 本局种子由 RunState 记录（03 §6）")
	var run_state: Node = _autoload("RunState")
	if not _ctx.check(run_state != null, "RunState Autoload 应存在"):
		return
	run_state.call(&"start_run", FIXED_SEED)
	_ctx.equal(int(run_state.call(&"get_run_seed")), FIXED_SEED, "RunState 应记下本局种子")


## 验收第 4 条：RESULT 必须由 GameFlow 的路由进入（03 §1.1 R3），
## 且 03 §1.1 R2 规定 COMBAT → RESULT **只能**由关键单位被摧毁 / 本局结束触发。故走完整链路：
## BOOT → MAIN_MENU → PREPARATION →（点 CTA）→ COMBAT →（on_core_destroyed）→ RESULT。
func _run_routed_entry_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 经 GameFlow 路由进入（核心被摧毁）")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.check(bool(flow.call(&"change_state", _state("MAIN_MENU"))), "BOOT → MAIN_MENU 应被接受")
	await process_frame
	_ctx.check(bool(flow.call(&"change_state", _state("PREPARATION"))), "MAIN_MENU → PREPARATION 应被接受")
	await process_frame
	await process_frame
	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("RESULT"))), RESULT_SCENE_PATH,
		"GameFlow 登记的 RESULT 路由路径")

	var prep: Node = current_scene
	var cta: Button = (_find(prep, "ButtonStartCombat") as Button) if prep != null else null
	if not _ctx.check(cta != null, "整备界面应有「开始战斗」按钮"):
		return
	_press(cta)
	await process_frame
	await process_frame
	var combat: Node = current_scene
	if not _ctx.check(combat != null and combat.scene_file_path == COMBAT_SCENE_PATH,
			"点 CTA 后应进入 COMBAT 场景（实际 %s）" % (combat.scene_file_path if combat != null else "null")):
		return

	# 03 §1.1 R2：COMBAT → RESULT 只在核心被摧毁时发生（不是本波清空）。
	combat.call(&"on_core_destroyed")
	_ctx.equal(_state_of_flow(), _state("RESULT"), "核心被摧毁后状态应为 RESULT")

	await process_frame
	await process_frame
	var result: Node = current_scene
	if not _ctx.check(result != null, "切换后应存在当前场景"):
		return
	_ctx.equal(result.scene_file_path, RESULT_SCENE_PATH, "当前场景应来自路由表登记的路径")
	_ctx.equal(result.get_script(), _screen_script, "当前场景应挂着 result_screen.gd")
	_ctx.equal(result.get_parent(), root, "当前场景应挂在 root 下")
	_ctx.check(not is_instance_valid(combat), "切换后旧场景应被释放（不得两份界面同时挂着）")


## 验收第 1 条：界面上至少要能读到「坚持到第几波」与「随机种子」。
## 量的是经 _ready() 填过内容之后的真实控件 —— 不是「场景里有没有那个节点」。
func _run_readout_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 两个读数真的显示在界面上（03 §6 / 验收第 1 条）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 RESULT 场景"):
		return

	var wave: Label = _find(screen, WAVE_LABEL) as Label
	var seed_label: Label = _find(screen, SEED_LABEL) as Label
	if not _ctx.check(wave != null and seed_label != null, "结算界面应有两个读数的落点"):
		return
	_ctx.check(wave.visible and seed_label.visible, "两个读数都应可见")

	# 波次的真实数据属 Stage 4 的 S4-08，本批只给占位读数。
	_ctx.equal(wave.text, String(_screen_script.WAVE_FORMAT_KEY) % int(_screen_script.WAVE_PLACEHOLDER),
		"波次读数应按格式串显示占位值（真实数据属 Stage 4 的 S4-08）")
	# 种子读的是 RunState 那一份 —— 上面刚起的固定种子应当逐字出现在界面上。
	_ctx.equal(seed_label.text, String(_screen_script.SEED_FORMAT_KEY) % FIXED_SEED,
		"种子读数应显示 RunState 记下的本局种子（03 §6）")
	_ctx.equal(int(screen.call(&"get_run_seed_displayed")), FIXED_SEED, "界面持有的种子读数")

	# 注入通道（Stage 4 的 S4-08 走这条）：给什么就显示什么，界面自己不计算。
	screen.call(&"set_result", 7, 4242)
	_ctx.equal(wave.text, String(_screen_script.WAVE_FORMAT_KEY) % 7, "注入后波次读数应更新")
	_ctx.equal(seed_label.text, String(_screen_script.SEED_FORMAT_KEY) % 4242, "注入后种子读数应更新")
	_ctx.equal(int(screen.call(&"get_wave_reached")), 7, "界面持有的波次读数应更新")

	# 验收第 5 条：两个出口按 06 §3 取色，Disabled 底色经**真实主题解析**必须是 NAVY_800
	# （04 §5.1：GREY_500 在 NAVY_700 上仅 3.84:1 不达标，在 NAVY_800 上 4.80:1 达标）。
	var navy_800: Color = _palette.get_color(_palette.Key.NAVY_800)
	for index: int in ACTION_NAMES.size():
		var button: Button = _find(screen, ACTION_NAMES[index]) as Button
		if button == null:
			continue
		var disabled: StyleBox = button.get_theme_stylebox(&"disabled")
		_ctx.check(disabled != null and disabled.bg_color == navy_800,
			"%s 的 Disabled 底色应解析为 NAVY_800（06 §3 / 04 §5.1）" % ACTION_NAMES[index])


## 验收第 2 条：两个出口的矩形必须是实测值。量的是入树后 layout 出来的真实矩形，
## 不是「场景里 offset 写了多少」—— 字段对而画错（被内容撑大、被上层盖住）正是要抓的。
## headless 下根窗口是 0×0，故这里的「初始」一档同时是退化尺寸的取证。
func _run_action_layout_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 两个出口的真实矩形与触摸下限（06 §1）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 RESULT 场景"):
		return
	_ctx.check(not bool(screen.call(&"is_narrow_layout")), "退化尺寸不得被判定为窄屏")
	_check_actions_area(screen, ACTIONS_AREA_WIDE, "初始")
	for index: int in ACTION_NAMES.size():
		_check_action_rect(screen, index, ACTION_RECTS_WIDE[index], "初始")


## 00 §5 交互硬规则第 1 条：RESULT 永远等玩家 —— 不得有倒计时、不得自动回主菜单。
## 这条跑在**真实场景 + 真实单例**上，比单测里那份纯状态机更能证明场景自身没有自动推进的构造。
func _run_no_auto_advance_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 停留 10 分钟不自动离开（00 §5）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 RESULT 场景"):
		return
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_watch_transitions(flow)
	_clock.set(&"elapsed", 0.0)

	var deadline: int = Time.get_ticks_msec() + WALL_CLOCK_BUDGET_MS
	while float(_clock.get(&"elapsed")) < R1_SIMULATED_SECONDS and Time.get_ticks_msec() < deadline:
		await process_frame

	var reached: float = float(_clock.get(&"elapsed"))
	_ctx.check(reached >= R1_SIMULATED_SECONDS,
		"模拟时间应跑满 %.0f 秒，实际 %.1f 秒（是否漏了 --fixed-fps 60？）" % [R1_SIMULATED_SECONDS, reached])
	_ctx.equal(_state_of_flow(), _state("RESULT"), "10 分钟后应仍停留在 RESULT")
	_ctx.equal(_transitions.size(), 0, "停留期间不应发生任何状态切换（尤其不得自动回 MAIN_MENU）")
	_ctx.equal(current_scene, screen, "停留期间不得换掉场景")


## 06 §7.1：折叠只改变布局，**不改变任何玩法规则与状态流**。
## 两个出口由横排改竖排；收尾再落回基准尺寸，顺带证明宽屏布局是可恢复的。
func _run_narrow_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 窄屏折叠不动状态（06 §7.1）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 RESULT 场景"):
		return
	var state_before: int = _state_of_flow()

	screen.call(&"apply_layout_for", NARROW_VIEWPORT)
	_ctx.check(bool(screen.call(&"is_narrow_layout")), "180×320 应切到折叠布局")
	_check_actions_area(screen, ACTIONS_AREA_NARROW, "180×320")
	for index: int in ACTION_NAMES.size():
		_check_action_rect(screen, index, ACTION_RECTS_NARROW[index], "180×320")
	# 折叠的形态由「同 x、递增 y」证明 —— 两个出口的矩形都由上一条断言逐分量钉住。
	var first: Button = _find(screen, ACTION_NAMES[0]) as Button
	var second: Button = _find(screen, ACTION_NAMES[1]) as Button
	_ctx.equal(first.position.x, second.position.x, "折叠后两个出口应同处一列")
	_ctx.check(first.get_rect().end.y <= second.position.y, "折叠后两个出口应自上而下依次排列")

	_ctx.equal(_state_of_flow(), state_before, "折叠不得改变状态（§7.1 末条）")
	_ctx.equal(current_scene, screen, "折叠不得换场景")

	screen.call(&"apply_layout_for", REFERENCE_VIEWPORT)
	_ctx.check(not bool(screen.call(&"is_narrow_layout")), "回到基准尺寸应恢复宽屏布局")
	_check_actions_area(screen, ACTIONS_AREA_WIDE, "恢复宽屏")
	for index: int in ACTION_NAMES.size():
		_check_action_rect(screen, index, ACTION_RECTS_WIDE[index], "恢复宽屏")


func _check_actions_area(screen: Node, expected: Rect2, label: String) -> void:
	var area: Control = _find(screen, "Actions") as Control
	if not _ctx.check(area != null, "应有两个出口的容器"):
		return
	_ctx.check(area.position == expected.position and area.size == expected.size,
		"%s：按钮区应为 %s（实际 %s）" % [label, expected, area.get_rect()])


func _check_action_rect(screen: Node, index: int, expected: Rect2, label: String) -> void:
	var button: Button = _find(screen, ACTION_NAMES[index]) as Button
	if not _ctx.check(button != null, "场景应有 %s" % ACTION_NAMES[index]):
		return
	_ctx.check(button.position == expected.position and button.size == expected.size,
		"%s：%s 的矩形（相对按钮区）应为 %s（实际 %s）" % [
			label, ACTION_NAMES[index], expected, button.get_rect()])
	_ctx.check(button.size.x >= MIN_TOUCH_SIZE and button.size.y >= MIN_TOUCH_SIZE,
		"%s：%s 的可点击区域不得低于 %s（实际 %s）" % [label, ACTION_NAMES[index], MIN_TOUCH_SIZE, button.size])
	_ctx.equal(button.mouse_filter, Control.MOUSE_FILTER_STOP,
		"%s：%s 必须收点击" % [label, ACTION_NAMES[index]])


## 验收第 2 条的核心：两个出口都**真的走得掉**，且走的是 GameFlow 的真实路由。
##
## 本用例必须排在**最后**：两个出口都会把当前场景换掉。
func _run_exit_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 「再来一局」经 GameFlow 回 PREPARATION")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 RESULT 场景"):
		return
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_watch_transitions(flow)

	var retry: Button = _find(screen, ACTION_NAMES[1]) as Button
	if not _ctx.check(retry != null, "应有「再来一局」按钮"):
		return
	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("PREPARATION"))), PREP_SCENE_PATH,
		"「再来一局」将要走的正是路由表登记的那条路径")

	# 反向核对：右键、以及未被真正按下的鼠标事件，都不得触发离开 ——
	# 否则「点了才走」这条守不住，界面上随便一次点击也会被算成出口。
	_right_click(retry)
	_ctx.equal(_transitions.size(), 0, "右键不得触发离开")
	_ctx.equal(_state_of_flow(), _state("RESULT"), "未被真正点击时状态应仍是 RESULT")

	_press(retry)
	_ctx.equal(_state_of_flow(), _state("PREPARATION"), "点「再来一局」后状态应为 PREPARATION")
	_ctx.equal(_transitions.size(), 1, "点「再来一局」应恰好产生一次切换")
	await process_frame
	await process_frame
	var prep: Node = current_scene
	if not _ctx.check(prep != null, "切换后应存在当前场景"):
		return
	_ctx.equal(prep.scene_file_path, PREP_SCENE_PATH, "当前场景应是路由表登记的 PREPARATION 路径")
	_ctx.check(not is_instance_valid(screen), "切换后结算场景应被释放")

	await _run_menu_exit_case()


## 第二个出口。要回到 RESULT 才能再测一次 —— 进入链路已由首个用例逐跳证明过，
## 故这里只走状态机最短的一条边（03 §1：PREPARATION → RESULT）当布景，不再重走 CTA → 核心被摧毁。
func _run_menu_exit_case() -> void:
	_ctx.begin_case("RESULT 冒烟 · 「返回主菜单」经 GameFlow 回 MAIN_MENU")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("MAIN_MENU"))), MENU_SCENE_PATH,
		"「返回主菜单」将要走的正是路由表登记的那条路径")

	_ctx.check(bool(flow.call(&"change_state", _state("RESULT"))), "PREPARATION → RESULT 应被接受")
	await process_frame
	await process_frame
	var screen: Node = current_scene
	if not _ctx.check(screen != null and screen.scene_file_path == RESULT_SCENE_PATH,
			"应再次进入 RESULT 场景"):
		return
	_watch_transitions(flow)

	var menu: Button = _find(screen, ACTION_NAMES[0]) as Button
	if not _ctx.check(menu != null, "应有「返回主菜单」按钮"):
		return
	_right_click(menu)
	_ctx.equal(_transitions.size(), 0, "右键不得触发离开")
	_press(menu)
	_ctx.equal(_state_of_flow(), _state("MAIN_MENU"), "点「返回主菜单」后状态应为 MAIN_MENU")
	_ctx.equal(_transitions.size(), 1, "点「返回主菜单」应恰好产生一次切换")
	await process_frame
	await process_frame
	var menu_scene: Node = current_scene
	if not _ctx.check(menu_scene != null, "切换后应存在当前场景"):
		return
	_ctx.equal(menu_scene.scene_file_path, MENU_SCENE_PATH, "当前场景应是路由表登记的 MAIN_MENU 路径")
	_ctx.check(not is_instance_valid(screen), "切换后结算场景应被释放")


## 把一次不被按钮理会的鼠标事件送到按钮的 gui_input 上。
##
## 走 gui_input 而不是 Input.parse_input_event()：后者的 GUI 命中测试依赖视口尺寸，
## 而 headless 下根窗口是 0×0。这里要证的是「按钮之外的鼠标事件不会放行」——
## 按钮是不是真的铺在那个矩形上（因而点得到），由矩形断言与 tests/unit/result_probe.gd 的像素取证负责。
func _right_click(button: Button) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = button.get_global_rect().get_center()
	button.gui_input.emit(event)


func _press(button: Button) -> void:
	if button != null:
		button.emit_signal(&"pressed")


func _state_of_flow() -> int:
	var flow: Node = _autoload("GameFlow")
	if flow == null:
		return -1
	return int(flow.call(&"get_state"))


func _state(name: String) -> int:
	return int(_flow_script.GameState[name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


## 按名字找节点。刻意不用 `%` 唯一名：子场景实例的唯一名作用域挂在各自 owner 上，
## 跨子场景边界时语义容易出意外；按名字搜是确定的。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false) if node != null else null


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：S1-10（PET-48）RESULT 场景：结算 + 返回（Stage 1 第七批 · 最后一个场景）")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元 / 集成测试：见 tests/output/unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：RESULT 经路由进入(点 CTA→核心被摧毁) · 两个读数落点 · 两个出口的实测矩形 · 停留 10 分钟不离开 · 窄屏折叠 · 「再来一局」回 PREPARATION · 「返回主菜单」回 MAIN_MENU")
	_lines.append("- 失败项：%s" % ("无" if _ctx.failures.is_empty() else "%d 条" % _ctx.failures.size()))
	for failure: String in _ctx.failures:
		_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\result_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("result_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
