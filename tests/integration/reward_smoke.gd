## reward_smoke.gd
## 职责：REWARD 场景的场景冒烟（09 §1）—— 经真实 GameFlow 路由进入、三张卡片的真实矩形、
##       06 §9 的五项展示位齐备、**不足 3 项时以「跳过」补齐**、
##       **停留 10 模拟分钟不自动离开（00 §5 硬规则第 1 条）**、
##       玩家显式选定后**经 GameFlow 回 PREPARATION**、窄屏折叠不动状态。**单独进程**运行。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, test_clock, scenes/reward/reward.tscn, scripts/ui/reward_screen.gd
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 combat_smoke.gd 的约束）；一律 load() + 经 /root 取节点。
##       本文件不得写任何字面色值 —— 判据色一律经 Palette 取。
##
## 运行：需要 --fixed-fps 60，否则「停留 600 秒不自动推进」跑不满（该用例会明确报红）。
##
## 为什么不挂进 run_tests.gd：本用例要真的把 GameFlow 一路推到 REWARD 并让路由换掉当前场景，
## 那会污染同进程里 test_state_loop.gd 的场景断言。
##
## 本批只做骨架与布局，故这里**不测任何奖励数值**（掉落池 / 稀有度权重属 Stage 4 的 S4-07）——
## 测的是「卡片画在哪」「五项都有落点」「跳过补得上」「没人点就永远不走」「点了才走」。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const CLOCK_PATH: String = "res://tests/unit/test_clock.gd"
const REWARD_SCENE_PATH: String = "res://scenes/reward/reward.tscn"
## 前两跳（PREPARATION / COMBAT）刻意写死路径而不是问 GameFlow 要 ——
## 本用例要证的就是「这条链上的每一跳都通」，问被测实现就成了同义反复。
const PREP_SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const COMBAT_SCENE_PATH: String = "res://scenes/combat/combat.tscn"
const REWARD_SCRIPT_PATH: String = "res://scripts/ui/reward_screen.gd"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const PALETTE_PATH: String = "res://scripts/data/palette.gd"
const LOG_PATH: String = "res://tests/output/reward_smoke.log"

## 06 §1 基准与 §7.1 的窄屏取样。
const REFERENCE_VIEWPORT: Vector2 = Vector2(320.0, 180.0)
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)

## R1 实测：停留 600 秒（10 分钟）模拟时间不得自动离开 REWARD。
const R1_SIMULATED_SECONDS: float = 600.0
## 漏加 --fixed-fps 时的兜底上限，与 run_tests.gd 同值。
const WALL_CLOCK_BUDGET_MS: int = 120_000

## 06 §1：卡片本身就是可点击区域，下限 44 设备像素。
const MIN_TOUCH_SIZE: float = 44.0

## 06 §9 的三个选项位，顺序即场景节点顺序。
const CARD_NAMES: PackedStringArray = ["Card0", "Card1", "Card2"]
## 06 §9 点名的五项，逐项都要有落点。
const FIELD_NAMES: PackedStringArray = ["Icon", "Name", "Type", "Value", "Rule"]
## 「跳过」补齐项**只**显示名称，其余三行整行隐藏（不显示 "N/A"）。
const SKIP_NAME: String = "跳过"
const SKIP_HIDDEN_FIELDS: PackedStringArray = ["Type", "Value", "Rule"]

## 卡片矩形**相对卡片区原点**，在本文件独立复写一遍
## （期望值若与被测实现同源，实现改错时两边一起错）。推导依据见 reward_layout.gd 的文件头。
const CARDS_AREA_WIDE: Rect2 = Rect2(8.0, 32.0, 304.0, 140.0)
const CARD_RECTS_WIDE: Array[Rect2] = [
	Rect2(0.0, 0.0, 96.0, 140.0),
	Rect2(104.0, 0.0, 96.0, 140.0),
	Rect2(208.0, 0.0, 96.0, 140.0),
]
const CARDS_AREA_NARROW: Rect2 = Rect2(8.0, 32.0, 164.0, 280.0)
const CARD_RECTS_NARROW: Array[Rect2] = [
	Rect2(0.0, 0.0, 164.0, 88.0),
	Rect2(0.0, 96.0, 164.0, 88.0),
	Rect2(0.0, 192.0, 164.0, 88.0),
]

var _ctx: RefCounted = null
var _screen_script: GDScript = null
var _flow_script: GDScript = null
var _palette: GDScript = null
var _clock: Node = null
var _lines: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_screen_script = load(REWARD_SCRIPT_PATH)
	_flow_script = load(GAME_FLOW_PATH)
	_palette = load(PALETTE_PATH)
	_clock = Node.new()
	_clock.set_script(load(CLOCK_PATH))
	_clock.name = "SmokeClock"
	root.add_child(_clock)

	await process_frame
	await _run_routed_entry_case()
	_run_card_layout_case()
	_run_option_fields_case()
	_run_skip_padding_case()
	await _run_no_auto_advance_case()
	_run_narrow_case()
	# 「选定后回 PREPARATION」会把当前场景换成整备界面，故必须排在最后 ——
	# 否则后面每个用例的 current_scene 都已经不是奖励界面，会连锁报一串与它们本身无关的失败。
	await _run_selection_case()
	_finish()


## 验收第一条：REWARD 必须由 GameFlow 的路由进入（03 §1.1 R3），且 03 §1.1 R2 规定
## COMBAT → REWARD **只能**由「本波清空」触发。故这里走完整链路：
## BOOT → MAIN_MENU → PREPARATION →（点 CTA）→ COMBAT →（on_wave_cleared）→ REWARD。
func _run_routed_entry_case() -> void:
	_ctx.begin_case("REWARD 冒烟 · 经 GameFlow 路由进入（点 CTA → 本波清空）")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.check(bool(flow.call(&"change_state", _state("MAIN_MENU"))), "BOOT → MAIN_MENU 应被接受")
	await process_frame
	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("PREPARATION"))), PREP_SCENE_PATH,
		"GameFlow 登记的 PREPARATION 路由路径")
	_ctx.check(bool(flow.call(&"change_state", _state("PREPARATION"))), "MAIN_MENU → PREPARATION 应被接受")
	await process_frame
	await process_frame

	var prep: Node = current_scene
	if not _ctx.check(prep != null, "应先进入 PREPARATION 场景"):
		return
	var cta: Button = _find(prep, "ButtonStartCombat") as Button
	if not _ctx.check(cta != null, "整备界面应有「开始战斗」按钮"):
		return
	_press(cta)
	await process_frame
	await process_frame

	var combat: Node = current_scene
	if not _ctx.check(combat != null and combat.scene_file_path == COMBAT_SCENE_PATH,
			"点 CTA 后应进入 COMBAT 场景（实际 %s）" % (combat.scene_file_path if combat != null else "null")):
		return

	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("REWARD"))), REWARD_SCENE_PATH,
		"GameFlow 登记的 REWARD 路由路径")
	combat.call(&"on_wave_cleared")
	_ctx.equal(_state_of_flow(), _state("REWARD"), "本波清空后状态应为 REWARD")

	await process_frame
	await process_frame
	var reward: Node = current_scene
	if not _ctx.check(reward != null, "切换后应存在当前场景"):
		return
	_ctx.equal(reward.scene_file_path, REWARD_SCENE_PATH, "当前场景应来自路由表登记的路径")
	_ctx.equal(reward.get_script(), _screen_script, "当前场景应挂着 reward_screen.gd")
	_ctx.equal(reward.get_parent(), root, "当前场景应挂在 root 下")
	_ctx.check(not is_instance_valid(combat), "切换后旧场景应被释放（不得两份界面同时挂着）")


## 06 §9：三张选项卡的矩形必须是实测值。量的是入树后 layout 出来的真实矩形，
## 不是「场景里 offset 写了多少」—— 字段对而画错（被内容撑大、被上层盖住）正是要抓的。
func _run_card_layout_case() -> void:
	_ctx.begin_case("REWARD 冒烟 · 三张卡片的真实矩形与触摸下限（06 §9 / §1）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 REWARD 场景"):
		return
	# headless 下可用区可能是 0×0，而退化尺寸**不得**被误判成窄屏。
	_ctx.check(not bool(screen.call(&"is_narrow_layout")), "退化尺寸不得被判定为窄屏")
	_check_cards_area(screen, CARDS_AREA_WIDE, "初始")
	for index: int in CARD_NAMES.size():
		_check_card_rect(screen, index, CARD_RECTS_WIDE[index], "初始")

	screen.call(&"apply_layout_for", REFERENCE_VIEWPORT)
	_ctx.begin_case("REWARD 冒烟 · 按 320×180 重落一次布局")
	_check_cards_area(screen, CARDS_AREA_WIDE, "320×180")
	for index: int in CARD_NAMES.size():
		_check_card_rect(screen, index, CARD_RECTS_WIDE[index], "320×180")


func _check_cards_area(screen: Node, expected: Rect2, label: String) -> void:
	var area: Control = _find(screen, "CardsArea") as Control
	if not _ctx.check(area != null, "应有卡片区容器"):
		return
	_ctx.equal(area.position, expected.position, "%s：卡片区的位置" % label)
	_ctx.equal(area.size, expected.size, "%s：卡片区的尺寸" % label)


func _check_card_rect(screen: Node, index: int, expected: Rect2, label: String) -> void:
	var card: Control = _find(screen, CARD_NAMES[index]) as Control
	if not _ctx.check(card != null, "场景应有 %s" % CARD_NAMES[index]):
		return
	_ctx.equal(card.position, expected.position, "%s%s 的位置（相对卡片区）" % [label, CARD_NAMES[index]])
	_ctx.equal(card.size, expected.size, "%s%s 的尺寸（相对卡片区）" % [label, CARD_NAMES[index]])
	_ctx.check(card.size.x >= MIN_TOUCH_SIZE and card.size.y >= MIN_TOUCH_SIZE,
		"%s%s 的可点击区域不得低于 %d×%d（实际 %s）" % [
			label, CARD_NAMES[index], int(MIN_TOUCH_SIZE), int(MIN_TOUCH_SIZE), str(card.size)])
	# 卡片是 Panel + gui_input（Theme 里没有「卡片按钮」变体），故「能点」= 它收鼠标事件。
	_ctx.equal(card.mouse_filter, Control.MOUSE_FILTER_STOP,
		"%s%s 必须收点击" % [label, CARD_NAMES[index]])


## 06 §9：每个选项要显示 **图标 · 名称 · 类型 · 数值 · 特殊规则** 五项。
## 这里量的是经 _ready() 填过内容之后的真实控件，不是「场景里有没有那个节点」。
func _run_option_fields_case() -> void:
	_ctx.begin_case("REWARD 冒烟 · 每张卡片五项俱备（06 §9）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 REWARD 场景"):
		return
	var type_colors: Array[Color] = [
		_palette.get_color(_palette.Key.GOLD_400),
		_palette.get_color(_palette.Key.BLUE_400),
		_palette.get_color(_palette.Key.ORANGE_500),
	]
	for index: int in CARD_NAMES.size():
		var card: Control = _find(screen, CARD_NAMES[index]) as Control
		if not _ctx.check(card != null, "场景应有 %s" % CARD_NAMES[index]):
			continue
		for field: String in FIELD_NAMES:
			var node: Control = _find(card, field) as Control
			if not _ctx.check(node != null, "%s 应有「%s」展示位" % [CARD_NAMES[index], field]):
				continue
			_ctx.check(node.visible, "%s 的「%s」应可见" % [CARD_NAMES[index], field])
			if node is Label:
				_ctx.check(not (node as Label).text.is_empty(),
					"%s 的「%s」应有内容" % [CARD_NAMES[index], field])
		var icon: ColorRect = _find(card, "Icon") as ColorRect
		if icon != null:
			_ctx.check(type_colors.has(icon.color),
				"%s 的图标应取 06 §4 的类型标识色（实际 %s）" % [CARD_NAMES[index], icon.color])


## 06 §9：选项 3 个，**不足时以「跳过」补齐**。
##
## 补进去的「跳过」只有名称，其余三行整行隐藏 —— 不给它编造类型 / 数值 / 特殊规则。
## 用 default_options().slice(0, 1) 而不是自己拼数组：那是**强类型**的 Array[RewardOption]，
## 而本文件是 --script 入口，连 RewardOption 这个名字都还不能引用。
func _run_skip_padding_case() -> void:
	_ctx.begin_case("REWARD 冒烟 · 不足 3 项时以「跳过」补齐（06 §9）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 REWARD 场景"):
		return

	screen.call(&"set_options", _screen_script.default_options().slice(0, 1))
	var first: Control = _find(screen, CARD_NAMES[0]) as Control
	var first_option: Variant = first.call(&"get_option")
	_ctx.check(not bool(first_option.is_skip()), "已给出的那一项不得被补齐改动")

	for index: int in range(1, CARD_NAMES.size()):
		var card: Control = _find(screen, CARD_NAMES[index]) as Control
		if not _ctx.check(card != null, "场景应有 %s" % CARD_NAMES[index]):
			continue
		var option: Variant = card.call(&"get_option")
		if not _ctx.check(option != null and bool(option.is_skip()),
				"%s 应被补成「跳过」（实际 %s）" % [CARD_NAMES[index], option]):
			continue
		_ctx.equal((_find(card, "Name") as Label).text, SKIP_NAME, "%s 的名称" % CARD_NAMES[index])
		_ctx.check((_find(card, "Icon") as Control).visible, "%s 仍应有图标落点" % CARD_NAMES[index])
		for field: String in SKIP_HIDDEN_FIELDS:
			_ctx.check(not (_find(card, field) as Control).visible,
				"「跳过」的 %s 行应整行隐藏（不得编造内容）" % field)

	# 还原成三张真实占位卡，免得后面的用例量到一副被补过位的界面。
	screen.call(&"set_options", _screen_script.default_options())
	for index: int in CARD_NAMES.size():
		_ctx.check(not bool((_find(screen, CARD_NAMES[index]) as Control).call(&"get_option").is_skip()),
			"还原后 %s 应回到真实选项" % CARD_NAMES[index])


## 00 §5 交互硬规则第 1 条：REWARD 由玩家选择才离开 —— 不得有倒计时、不得自动选中、不得自动离开。
## 这条跑在**真实场景 + 真实单例**上，比单测里那份纯状态机更能证明场景自身没有自动推进的构造。
func _run_no_auto_advance_case() -> void:
	_ctx.begin_case("REWARD 冒烟 · 停留 10 分钟不自动离开（00 §5）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 REWARD 场景"):
		return
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return

	var transitions: Array = []
	var handler: Callable = func(from, to) -> void: transitions.append([from, to])
	flow.connect(&"state_changed", handler)
	_clock.set(&"elapsed", 0.0)

	var deadline: int = Time.get_ticks_msec() + WALL_CLOCK_BUDGET_MS
	while float(_clock.get(&"elapsed")) < R1_SIMULATED_SECONDS and Time.get_ticks_msec() < deadline:
		await process_frame

	var reached: float = float(_clock.get(&"elapsed"))
	_ctx.check(reached >= R1_SIMULATED_SECONDS,
		"模拟时间应跑满 %.0f 秒，实际 %.1f 秒（是否漏了 --fixed-fps 60？）" % [R1_SIMULATED_SECONDS, reached])
	_ctx.equal(_state_of_flow(), _state("REWARD"), "10 分钟后应仍停留在 REWARD")
	_ctx.equal(transitions.size(), 0, "停留期间不应发生任何状态切换（尤其不得自动回 PREPARATION）")
	_ctx.equal(current_scene, screen, "停留期间不得换掉场景")
	flow.disconnect(&"state_changed", handler)
	# 反向核对（「出口没坏，只是没人点」）随最后一条用例：显式点击恰好一次切换。
	# 两者缺一，另一条都可能是空断言。


## 06 §7.1：折叠只改变布局，**不改变任何玩法规则与状态流**。
## 三列横排改三行竖排，形态由「同 x、递增 y」证明。
func _run_narrow_case() -> void:
	_ctx.begin_case("REWARD 冒烟 · 窄屏折叠不动状态（06 §7.1）")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 REWARD 场景"):
		return
	var state_before: int = _state_of_flow()

	screen.call(&"apply_layout_for", NARROW_VIEWPORT)
	_ctx.check(bool(screen.call(&"is_narrow_layout")), "180×320 应切到折叠布局")
	_check_cards_area(screen, CARDS_AREA_NARROW, "180×320")
	for index: int in CARD_NAMES.size():
		_check_card_rect(screen, index, CARD_RECTS_NARROW[index], "180×320")
	var first: Control = _find(screen, CARD_NAMES[0]) as Control
	var third: Control = _find(screen, CARD_NAMES[2]) as Control
	_ctx.equal(first.position.x, third.position.x, "折叠后三张卡片应同处一列")
	_ctx.check(first.get_rect().end.y <= third.position.y, "折叠后三张卡片应自上而下依次排列")

	_ctx.equal(_state_of_flow(), state_before, "折叠不得改变状态（§7.1 末条）")
	_ctx.equal(current_scene, screen, "折叠不得换场景")

	screen.call(&"apply_layout_for", REFERENCE_VIEWPORT)
	_ctx.check(not bool(screen.call(&"is_narrow_layout")), "回到基准尺寸应恢复宽屏布局")
	_ctx.equal((_find(screen, CARD_NAMES[2]) as Control).size, CARD_RECTS_WIDE[2].size,
		"恢复宽屏后卡片应回到三列尺寸")


## 验收核心：**由玩家选择**后回到 PREPARATION —— 走 GameFlow 的真实路由，不得自己换场景。
##
## 本用例必须排在**最后**：它会把当前场景换成整备界面。
func _run_selection_case() -> void:
	_ctx.begin_case("REWARD 冒烟 · 玩家选定后经 GameFlow 回 PREPARATION")
	var screen: Node = current_scene
	if not _ctx.check(screen != null, "应已进入 REWARD 场景"):
		return
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	var card: Control = _find(screen, CARD_NAMES[0]) as Control
	if not _ctx.check(card != null, "应有 %s" % CARD_NAMES[0]):
		return
	var chosen: Variant = card.call(&"get_option")
	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("PREPARATION"))), PREP_SCENE_PATH,
		"选定将要走的正是路由表登记的那条路径")

	var transitions: Array = []
	var handler: Callable = func(from, to) -> void: transitions.append([from, to])
	flow.connect(&"state_changed", handler)

	# 反向核对前两条：右键、以及左键的**抬起**，都不得触发选择 ——
	# 否则「点了才走」这条守不住，一次点击也会被算成两下。
	_click(card, MOUSE_BUTTON_RIGHT, true)
	_click(card, MOUSE_BUTTON_LEFT, false)
	_ctx.equal(transitions.size(), 0, "右键与抬起都不得触发选择")
	_ctx.equal(_state_of_flow(), _state("REWARD"), "未被真正点击时状态应仍是 REWARD")

	_click(card, MOUSE_BUTTON_LEFT, true)
	_ctx.equal(_state_of_flow(), _state("PREPARATION"), "选定后状态应为 PREPARATION")
	_ctx.equal(transitions.size(), 1, "选定应恰好产生一次切换")
	_ctx.equal(screen.call(&"get_chosen_option"), chosen, "被记下的应是玩家点中的那一项")
	flow.disconnect(&"state_changed", handler)

	await process_frame
	await process_frame
	var prep: Node = current_scene
	if not _ctx.check(prep != null, "切换后应存在当前场景"):
		return
	_ctx.equal(prep.scene_file_path, PREP_SCENE_PATH, "当前场景应是路由表登记的 PREPARATION 路径")
	_ctx.equal(prep.get_parent(), root, "当前场景应挂在 root 下")
	_ctx.check(not is_instance_valid(screen), "切换后奖励场景应被释放")


## 把一次鼠标事件送到卡片的 gui_input 上。
##
## 走 gui_input 信号而不是 Input.parse_input_event()：后者的 GUI 命中测试依赖视口尺寸，
## 而 headless 下根窗口是 0×0。这里要证的是「卡片自己的点击处理会不会放行」——
## 它是不是真的铺在那个矩形上（因而点得到），由鼠标过滤位与矩形断言、以及
## tests/unit/reward_probe.gd 的像素取证分别负责。
func _click(card: Control, button_index: int, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = pressed
	event.position = card.get_global_rect().get_center()
	card.gui_input.emit(event)


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
	return node.find_child(node_name, true, false)


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：S1-09（PET-45）REWARD 场景：3 选项 + 跳过 + 玩家选择后回 PREPARATION")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：REWARD 经路由进入(点 CTA→本波清空) · 三张卡片矩形 · 五项俱备 · 「跳过」补齐 · 停留 10 分钟不离开 · 窄屏折叠 · 选定后回 PREPARATION")
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\reward_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("reward_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
