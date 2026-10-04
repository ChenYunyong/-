## preparation_smoke.gd
## 职责：PREPARATION 场景的场景冒烟（09 §1）—— 经真实 GameFlow 路由进入、五分区矩形、
##       CTA 唯一性与点击后的提示路径、**停留 10 模拟分钟不自动推进（R1 回归）**、
##       窄屏折叠不动状态、重复进入不残留。**单独进程**运行。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, test_clock, scenes/preparation/preparation.tscn, scripts/ui/preparation_screen.gd
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 run_tests.gd 的约束）；一律 load() + 经 /root 取节点。
##
## 运行：需要 --fixed-fps 60，否则 R1 的 600 秒模拟时间跑不满（该用例会明确报红）。
##
## 为什么不挂进 run_tests.gd：本用例要真的把 GameFlow 推到 PREPARATION 并让路由换掉当前场景，
## 那会污染同进程里 test_state_loop.gd 的场景断言。
##
## 验收要求 PREPARATION 是「时间停止」的场景：停留任意时长都不得自行进入 COMBAT，
## 且 COMBAT 未实现时点击 CTA 必须给出**可读**提示 —— 前者量模拟时间，后者量屏幕上看得见的中文。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const CLOCK_PATH: String = "res://tests/unit/test_clock.gd"
const PREP_SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
## S1-08 起「开始战斗」会真的路由到这里。刻意写死路径而不是问 GameFlow 要 ——
## 本用例要证的就是「路由表登记的就是这个文件」，问了被测实现就成了同义反复。
const COMBAT_SCENE_PATH: String = "res://scenes/combat/combat.tscn"
const PREP_SCRIPT_PATH: String = "res://scripts/ui/preparation_screen.gd"
const LAYOUT_SCRIPT_PATH: String = "res://scripts/ui/preparation_layout.gd"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const LOG_PATH: String = "res://tests/output/preparation_smoke.log"

## 06 §1 基准。所有实测值都以它为参照。
const REFERENCE_VIEWPORT: Vector2 = Vector2(320.0, 180.0)
## 06 §7.1 的窄屏取样。
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)
## R1 实测：停留 600 秒（10 分钟）模拟时间不得自动推进。
const R1_SIMULATED_SECONDS: float = 600.0
## 漏加 --fixed-fps 时的兜底上限，与 run_tests.gd 同值。
const WALL_CLOCK_BUDGET_MS: int = 120_000

## 06 §7 的实测值，在本文件独立复写一遍（同 tests/unit/test_preparation.gd 的理由：
## 期望值若与被测实现同源，实现改错时两边一起错）。下标即 PreparationLayout.Region。
const REGION_NAMES: PackedStringArray = [
	"RegionLeft", "RegionCenter", "RegionRight", "RegionBottom", "RegionAction",
]
const EXPECTED_WIDE: Array[Rect2] = [
	Rect2(15.0, 8.0, 73.0, 124.0),
	Rect2(98.0, 8.0, 128.0, 124.0),
	Rect2(226.0, 8.0, 83.0, 124.0),
	Rect2(15.0, 132.0, 294.0, 48.0),
	Rect2(246.0, 148.0, 64.0, 14.0),
]
const EXPECTED_NARROW: Array[Rect2] = [
	Rect2(0.0, 0.0, 180.0, 16.0),
	Rect2(8.0, 16.0, 164.0, 149.33333),
	Rect2(0.0, 165.33333, 180.0, 106.66667),
	Rect2(0.0, 272.0, 180.0, 48.0),
	Rect2(128.0, 268.0, 44.0, 44.0),
]

var _ctx: RefCounted = null
var _scene: PackedScene = null
var _prep_script: GDScript = null
var _layout: GDScript = null
var _flow_script: GDScript = null
var _clock: Node = null
var _lines: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_scene = load(PREP_SCENE_PATH)
	_prep_script = load(PREP_SCRIPT_PATH)
	_layout = load(LAYOUT_SCRIPT_PATH)
	_flow_script = load(GAME_FLOW_PATH)
	_clock = Node.new()
	_clock.set_script(load(CLOCK_PATH))
	_clock.name = "SmokeClock"
	root.add_child(_clock)

	await process_frame
	await _run_routed_entry_case()
	_run_region_case()
	_check_cta_case()
	await _run_r1_time_stop_case()
	await _run_narrow_case()
	await _run_reentry_case()
	# 「开始战斗」会把当前场景换成 COMBAT，故必须排在最后 —— 否则后面每个用例的
	# `current_scene` 都已经不是整备界面，会连锁报一串与它们本身无关的失败。
	await _run_start_combat_case()
	_finish()


## 验收第一条：PREPARATION 必须由 GameFlow 路由进入，不得绕过状态机自己 add_child。
func _run_routed_entry_case() -> void:
	_ctx.begin_case("PREPARATION 冒烟 · 经 GameFlow 路由进入")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.check(bool(flow.call(&"change_state", _state("MAIN_MENU"))), "BOOT → MAIN_MENU 应被接受")
	await process_frame
	var path: String = String(flow.call(&"get_scene_path_for", _state("PREPARATION")))
	_ctx.equal(path, PREP_SCENE_PATH, "GameFlow 登记的 PREPARATION 路由路径")
	_ctx.check(bool(flow.call(&"change_state", _state("PREPARATION"))), "MAIN_MENU → PREPARATION 应被接受")
	await process_frame
	await process_frame

	var scene: Node = current_scene
	if not _ctx.check(scene != null, "切换后应存在当前场景"):
		return
	_ctx.equal(scene.scene_file_path, PREP_SCENE_PATH, "当前场景应来自路由表登记的路径")
	_ctx.equal(scene.get_script(), _prep_script, "当前场景应挂着 preparation_screen.gd")
	_ctx.check(bool(flow.call(&"is_state", _state("PREPARATION"))), "状态应为 PREPARATION")


## 06 §7：五分区矩形必须是实测值。量的是入树后 layout 出来的真实矩形。
## 先量「_ready() 刚跑完」的状态：headless 下可用区可能是 0×0，而退化尺寸**不得**被误判成窄屏。
func _run_region_case() -> void:
	_ctx.begin_case("PREPARATION 冒烟 · 五分区矩形（06 §7）")
	var scene: Node = _scene_root()
	if not _ctx.check(scene != null, "应已进入 PREPARATION 场景"):
		return
	_ctx.check(scene.size.x <= 0.0 or scene.size.is_equal_approx(REFERENCE_VIEWPORT),
		"可用区应是基准尺寸或退化尺寸（实际 %s）—— 本用例的期望值以基准为准" % scene.size)
	_ctx.check(not bool(scene.call(&"is_narrow_layout")), "退化尺寸不得被判定为窄屏")

	for index: int in REGION_NAMES.size():
		_check_region(scene, index)

	scene.call(&"apply_layout_for", REFERENCE_VIEWPORT)
	_ctx.begin_case("PREPARATION 冒烟 · 按 320×180 重落一次布局")
	for index: int in REGION_NAMES.size():
		_check_region(scene, index)


func _check_region(scene: Node, index: int) -> void:
	var region: Control = _find(scene, REGION_NAMES[index]) as Control
	if not _ctx.check(region != null, "场景应有 %s 分区容器" % REGION_NAMES[index]):
		return
	var expected: Rect2 = EXPECTED_WIDE[index]
	_ctx.equal(region.position, expected.position, "%s 的位置" % REGION_NAMES[index])
	_ctx.equal(region.size, expected.size, "%s 的尺寸" % REGION_NAMES[index])


## 06 §7：「开始战斗」是右下角**唯一**的主动作按钮。这里量的是渲染前的真实矩形，
## 并拿它自己报告的最小尺寸回代坐标换算公式 —— 最小尺寸一旦变化，落位必须跟着变。
##
## PET-75：判据收窄到**主动作**按钮（无主题变体 = GOLD 填充）。该卡在左栏加了
## 「删除 / 撤销 / 清空蓝图」三个 ButtonSecondary 辅助按钮，它们不争夺这个位置；
## 收窄之后本用例测的正是它标题里写的那件事。
func _check_cta_case() -> void:
	_ctx.begin_case("PREPARATION 冒烟 · CTA 唯一性与落位（06 §7）")
	var scene: Node = _scene_root()
	if not _ctx.check(scene != null, "应已进入 PREPARATION 场景"):
		return
	var buttons: Array[Button] = _primary_buttons(scene)
	if not _ctx.check(buttons.size() == 1, "整备界面应只有一个主动作按钮（实际 %d 个）" % buttons.size()):
		return

	var button: Button = buttons[0]
	var minimum: Vector2 = button.get_combined_minimum_size()
	_ctx.equal(button.name, "ButtonStartCombat", "那唯一的按钮应是「开始战斗」")
	_ctx.equal(button.text, "开始战斗", "CTA 文案")
	var action: Rect2 = EXPECTED_WIDE[_layout.Region.ACTION]
	_ctx.equal(button.position, _layout.action_button_rect(action, minimum).position, "CTA 的位置")
	_ctx.equal(button.size, _layout.action_button_rect(action, minimum).size, "CTA 的尺寸")
	_ctx.equal(button.get_global_rect().end, action.end, "CTA 右下角必须与 §7 实测的区块右下角重合（实际最小 %s）" % minimum)


## 验收：点击 CTA 必须**真的经 GameFlow 路由进入 COMBAT**（03 §1.1 R1 / R3、06 §10.2）。
##
## S1-07 交付时这里断言的是「停在整备界面 + 未实现提示」（当时 combat.tscn 还不存在）。
## 那条行为随 S1-08 落地而合法失效 —— 它不是被改坏了，而是它守的那个前提没了。
## 「未实现 → 可读提示」这条路径本身没有失去覆盖：主菜单冒烟的设置 / 退出两条走的是同一套机制，
## preparation_screen.gd 里那个路由就绪判断也仍然在，它现在守的是真正的路由故障。
##
## 本用例必须排在**最后**：它会把当前场景换成 COMBAT。
func _run_start_combat_case() -> void:
	_ctx.begin_case("PREPARATION 冒烟 · 点击开始战斗（经路由进入 COMBAT）")
	var scene: Node = _scene_root()
	if not _ctx.check(scene != null, "应已进入 PREPARATION 场景"):
		return
	var notice: Control = _find(scene, "NoticePanel") as Control
	if not _ctx.check(notice != null, "应有提示面板"):
		return
	_ctx.check(not notice.visible, "前置：提示面板初始不可见")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("COMBAT"))), COMBAT_SCENE_PATH,
		"按钮将要走的正是路由表登记的那条路径")

	# R1 的反向核对落在这里：停留 600 秒零切换（上一条用例）证明「不会自动推进」，
	# 显式输入恰好产生一次切换证明「入口没坏」。两者缺一，另一条都可能是空断言。
	var transitions: Array = []
	var handler: Callable = func(from, to) -> void: transitions.append([from, to])
	flow.connect(&"state_changed", handler)

	_press(_find(scene, "ButtonStartCombat") as Button)
	_ctx.equal(_state_of_flow(), _state("COMBAT"), "点击 CTA 后状态应为 COMBAT")
	_ctx.equal(transitions.size(), 1, "点击 CTA 应恰好产生一次切换")
	_ctx.check(not notice.visible, "路由就绪时不得弹出「未实现」提示")
	flow.disconnect(&"state_changed", handler)

	# change_scene_to_file 是延迟落地的，等两帧再看当前场景。
	await process_frame
	await process_frame
	var combat: Node = current_scene
	if not _ctx.check(combat != null, "切换后应存在当前场景"):
		return
	_ctx.equal(combat.scene_file_path, COMBAT_SCENE_PATH, "当前场景应是路由表登记的 COMBAT 路径")
	_ctx.equal(combat.get_parent(), root, "当前场景应挂在 root 下")
	_ctx.check(combat.get_script() != null, "COMBAT 场景应挂上自己的脚本")
	_ctx.check(not is_instance_valid(scene), "切换后旧场景应被释放（不得两份界面同时挂着）")


## R1 回归（验收点名）：PREPARATION 是时间停止的场景 —— 停留 600 模拟秒不得自行进入 COMBAT。
## 这条跑在**真实场景 + 真实单例**上，比单测里那份纯状态机更能证明场景自身没有自动推进的构造。
func _run_r1_time_stop_case() -> void:
	_ctx.begin_case("PREPARATION 冒烟 · R1 实测：停留 10 分钟不进入 COMBAT")
	var scene: Node = _scene_root()
	if not _ctx.check(scene != null, "应已进入 PREPARATION 场景"):
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
	_ctx.equal(_state_of_flow(), _state("PREPARATION"), "10 分钟后应仍停留在 PREPARATION")
	_ctx.equal(transitions.size(), 0, "停留期间不应发生任何状态切换（尤其不得进入 COMBAT）")
	_ctx.equal(current_scene, scene, "停留期间不得换掉场景")
	flow.disconnect(&"state_changed", handler)
	# 反向核对（「入口没坏，只是没被触发」）随 S1-08 落地搬到了最后一条用例：
	# request_start_combat() 现在会真的换掉场景，留在这里会把后面每条用例的前提掀掉。
	# 那条用例按的是真实 CTA、断言恰好一次切换，判别力不降。


## 06 §7.1：折叠只改变布局，**不改变任何玩法规则与状态流**。这里用显式调用代替改窗口尺寸，
## 因为要证的正是「折叠这个动作本身不碰状态」。
func _run_narrow_case() -> void:
	_ctx.begin_case("PREPARATION 冒烟 · 窄屏折叠不动状态（06 §7.1）")
	var scene: Node = _scene_root()
	if not _ctx.check(scene != null, "应已进入 PREPARATION 场景"):
		return
	var state_before: int = _state_of_flow()

	scene.call(&"apply_layout_for", NARROW_VIEWPORT)
	_ctx.check(bool(scene.call(&"is_narrow_layout")), "180×320 应切到折叠布局")
	for index: int in REGION_NAMES.size():
		var region: Control = _find(scene, REGION_NAMES[index]) as Control
		if region == null:
			continue
		_ctx.equal(region.position, EXPECTED_NARROW[index].position, "%s 的折叠位置" % REGION_NAMES[index])
	_ctx.equal(_find(scene, "RegionLeft").size.y, 16.0, "左栏应收起为 16px 信息条")
	var action: Control = _find(scene, "RegionAction") as Control
	_ctx.equal(action.size, Vector2(44.0, 44.0), "窄屏 CTA 应达 44×44 触摸下限")
	# §7.1：右栏窄屏改底部弹层，「选中节点时弹出」。本批没有选中，故弹层收起 ——
	# 它是不是弹层由矩形位置证明，不由可见性证明。
	_ctx.check(not (_find(scene, "RegionRight") as Control).visible, "窄屏下右栏弹层应收起")

	_ctx.equal(_state_of_flow(), state_before, "折叠不得改变状态（§7.1 末条）")
	_ctx.equal(current_scene, scene, "折叠不得换场景")

	scene.call(&"apply_layout_for", REFERENCE_VIEWPORT)
	_ctx.check(not bool(scene.call(&"is_narrow_layout")), "回到基准尺寸应恢复宽屏布局")
	_ctx.equal((_find(scene, "RegionRight") as Control).visible, true, "宽屏下右栏应恢复可见")
	_ctx.equal(_state_of_flow(), state_before, "展开回来同样不得改变状态")


## 09 §2 第 7 类：重新进入场景。再实例化一份不得推状态、不得残留节点。
func _run_reentry_case() -> void:
	_ctx.begin_case("PREPARATION 冒烟 · 重复进入不残留")
	var base: int = root.get_child_count()
	var second: Node = _scene.instantiate()
	root.add_child(second)
	await process_frame
	await process_frame

	_ctx.equal(root.get_child_count(), base + 1, "第二次实例化应只多一个节点")
	_ctx.equal(_state_of_flow(), _state("PREPARATION"), "再次进入 PREPARATION 不得推进状态")
	_ctx.equal(_primary_buttons(second).size(), 1, "第二份实例同样只应有一个主动作按钮")

	root.remove_child(second)
	second.free()
	await process_frame
	_ctx.equal(root.get_child_count(), base, "释放后不应残留节点")


## 提示文案的三条核对（正文存在 / 含预期中文 / 确实是中文）随 S1-08 一并移交：
## 整备界面现在只有「路由故障」一个提示出口，而那条路在冒烟里跑不到。
## 承接它们的是 tests/integration/combat_smoke.gd —— COMBAT 的 REWARD / RESULT 出口当前仍是
## 「未实现 → 可读提示」，那条路真的走得通，断言在那边才不是空转。
func _press(button: Button) -> void:
	if button != null:
		button.emit_signal(&"pressed")


func _scene_root() -> Node:
	return current_scene


func _state_of_flow() -> int:
	var flow: Node = _autoload("GameFlow")
	if flow == null:
		return -1
	return int(flow.call(&"get_state"))


func _collect_buttons(node: Node, found: Array[Button]) -> void:
	var button: Button = node as Button
	if button != null:
		found.append(button)
	for child: Node in node.get_children():
		_collect_buttons(child, found)


## 主动作按钮 = 没挂主题变体的 Button（基础变体 = GOLD 填充，06 §3）。
## PET-75 的「删除 / 撤销 / 清空蓝图」挂的是 ButtonSecondary（NAVY 填充），不在其列。
func _primary_buttons(node: Node) -> Array[Button]:
	var all: Array[Button] = []
	_collect_buttons(node, all)
	var primary: Array[Button] = []
	for candidate: Button in all:
		if candidate.theme_type_variation == &"":
			primary.append(candidate)
	return primary


## 按名字找节点。刻意不用 `%` 唯一名：子场景实例的唯一名作用域挂在各自 owner 上，
## 跨子场景边界时语义容易出意外；按名字搜是确定的。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


func _state(name: String) -> int:
	return int(_flow_script.GameState[name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：S1-07（PET-42）PREPARATION 骨架 + 五分区占位布局")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：PREPARATION 经路由进入 · 五分区矩形 · CTA 唯一性 · R1 停留 10 分钟 · 窄屏折叠 · 重复进入 · 点击开始战斗(→COMBAT)")
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\preparation_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("preparation_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
