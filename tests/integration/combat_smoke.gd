## combat_smoke.gd
## 职责：COMBAT 场景的场景冒烟（09 §1）—— 经真实 GameFlow 路由进入、两块区域的真实矩形、
##       状态带**不含任何可交互控件**、REWARD / RESULT 两个出口的真实路由换场景、
##       窄屏下状态带不挤掉战场可读性。**单独进程**运行。
## 所属系统：tests（场景冒烟层）
## 依赖：test_context, scenes/combat/combat.tscn, scripts/ui/combat_screen.gd
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 run_tests.gd 的约束）；一律 load() + 经 /root 取节点。
##       本文件不得写任何字面色值 —— 判据色一律经 Palette 取。
##
## 为什么不挂进 run_tests.gd：本用例要真的把 GameFlow 推到 COMBAT 并让路由换掉当前场景，
## 那会污染同进程里 test_state_loop.gd 的场景断言。
##
## 本批只做骨架与布局，故这里**不测任何玩法**（敌人推进 / CORE 运行 / 武器执行 / 伤害结算
## 全部属 Stage 4）—— 测的是「两块区域画在哪」「这条带是不是只读的」「两个出口通不通」。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const COMBAT_SCENE_PATH: String = "res://scenes/combat/combat.tscn"
const COMBAT_SCRIPT_PATH: String = "res://scripts/ui/combat_screen.gd"
const LAYOUT_SCRIPT_PATH: String = "res://scripts/ui/combat_layout.gd"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const PALETTE_PATH: String = "res://scripts/data/palette.gd"
const LOG_PATH: String = "res://tests/output/combat_smoke.log"

## 06 §1 基准。所有实测值都以它为参照。
const REFERENCE_VIEWPORT: Vector2 = Vector2(320.0, 180.0)
## 06 §7.1 的窄屏取样（均为竖屏），与 test_combat.gd 独立复写。
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)
## 比基准更矮的窄屏取样（120×180 竖屏）。test_combat.gd / test_reward.gd / test_result.gd
## 与本文件如今一致取这个值。
##
## 它必须**宽 < 高**：本用例是唯一把取样喂给**场景**的（`apply_layout_for` 先问 `is_narrow`），
## 而 §7.1 的判据就是宽 < 高 —— 取样若写成 180×120 那样的横屏，会被正确地判成宽屏，
## 下面的折叠断言于是恒假。120×180 才是「窄且矮」的那一档。
const SHORT_NARROW_VIEWPORT: Vector2 = Vector2(120.0, 180.0)

## 06 §8 的实测值，在本文件独立复写一遍（期望值若与被测实现同源，实现改错时两边一起错）。
## 下标即 CombatLayout.Region。两块都全宽 —— §8 明写那条带「横贯全宽」。
const REGION_NAMES: PackedStringArray = ["Battlefield", "StatusBar"]
const EXPECTED_WIDE: Array[Rect2] = [
	Rect2(0.0, 0.0, 320.0, 135.0),
	Rect2(0.0, 135.0, 320.0, 45.0),
]
## 06 §8：状态带占画面高约 25%。窄屏下它是上限（§7.1「不得挤掉战场可读性」）。
const STATUS_BAR_SHARE: float = 0.25

## 06 §8.1（v0.1.10，Codex 裁定）的 5 个只读读数块，独立复写一遍
## （期望值若与被测实现同源，实现改错时两边一起错）。
const READOUT_CAPTIONS: PackedStringArray = ["波次", "CORE", "热量", "能量", "队列"]
## `波次` 的期望值是 `1/3`：06 §8.1 的表里写的是 `1/1`，那是一局只有一波时期冻结的**占位值**；
## FIRST PLAYABLE 4/4 起一局三波，这一格由 combat_screen.gd 在 _ready() 里按
## RunState 的当前波次拼成 `n/N`，故经路由进入后看到的是第 1 波第 1 帧的 `1/3`。
## 那个 3 刻意写死在这里而不是问 RunState 要（本文件不引用 Autoload 标识符）——
## 它要钉的正是「总数真的是 3」，与 RunState.TOTAL_WAVES 对不上时这条会当场转红。
const READOUT_VALUES: PackedStringArray = ["1/3", "100%", "0%", "0%", "0项"]
## 06 §8.1 硬规则 1：热量与能量必须分格，故各自是一个独立节点。
const SPLIT_READOUTS: PackedStringArray = ["Heat", "Energy"]
## 06 §8.1 硬规则 2：CORE 用百分比读数，不用自然语言状态词。
const CORE_VALUE: String = "100%"

## 03 §1.1 R2 的两个出口各自该去的场景路径，独立复写一遍，不转抄 GameFlow.SCENE_ROUTES ——
## 期望值若与被测实现同源，路由表被改错时两边一起错，用例就成了同义反复。
const REWARD_SCENE_PATH: String = "res://scenes/reward/reward.tscn"
const RESULT_SCENE_PATH: String = "res://scenes/result/result.tscn"

var _ctx: RefCounted = null
var _scene: PackedScene = null
var _combat_script: GDScript = null
var _layout: GDScript = null
var _flow_script: GDScript = null
var _palette: GDScript = null
var _lines: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_scene = load(COMBAT_SCENE_PATH)
	_combat_script = load(COMBAT_SCRIPT_PATH)
	_layout = load(LAYOUT_SCRIPT_PATH)
	_flow_script = load(GAME_FLOW_PATH)
	_palette = load(PALETTE_PATH)

	await process_frame
	await _run_routed_entry_case()
	_run_region_case()
	_run_status_bar_case()
	_run_readout_case()
	_run_narrow_case()
	# 两个出口都会把当前场景换掉，故必须排在最后（同 REWARD / RESULT 各自冒烟的排法）——
	# 否则后面每个用例的 current_scene 都已经不是战斗界面，会连锁报一串与它们本身无关的失败。
	await _run_exit_case()
	_finish()


## 验收第一条：COMBAT 必须由 GameFlow 的路由进入，且**只能**由玩家显式点击「开始战斗」触发
## （03 §1.1 R1 / R3、06 §10.2）。故这里不手工挂场景，而是走完整链路：
## BOOT → MAIN_MENU → PREPARATION →（点 CTA）→ COMBAT。
func _run_routed_entry_case() -> void:
	_ctx.begin_case("COMBAT 冒烟 · 经 GameFlow 路由进入（PREPARATION 点 CTA）")
	var flow: Node = _autoload("GameFlow")
	if not _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		return
	_ctx.check(bool(flow.call(&"change_state", _state("MAIN_MENU"))), "BOOT → MAIN_MENU 应被接受")
	await process_frame
	_ctx.check(bool(flow.call(&"change_state", _state("PREPARATION"))), "MAIN_MENU → PREPARATION 应被接受")
	await process_frame
	await process_frame

	var prep: Node = current_scene
	if not _ctx.check(prep != null, "应先进入 PREPARATION 场景"):
		return
	var cta: Button = _find(prep, "ButtonStartCombat") as Button
	if not _ctx.check(cta != null, "整备界面应有「开始战斗」按钮"):
		return

	_ctx.equal(String(flow.call(&"get_scene_path_for", _state("COMBAT"))), COMBAT_SCENE_PATH,
		"GameFlow 登记的 COMBAT 路由路径")
	_press(cta)
	_ctx.equal(_state_of_flow(), _state("COMBAT"), "点击 CTA 后状态应为 COMBAT")

	await process_frame
	await process_frame
	var combat: Node = current_scene
	if not _ctx.check(combat != null, "切换后应存在当前场景"):
		return
	_ctx.equal(combat.scene_file_path, COMBAT_SCENE_PATH, "当前场景应来自路由表登记的路径")
	_ctx.equal(combat.get_script(), _combat_script, "当前场景应挂着 combat_screen.gd")
	_ctx.equal(combat.get_parent(), root, "当前场景应挂在 root 下")


## 06 §8：两块区域必须是实测矩形。量的是入树后 layout 出来的真实矩形，
## 不是「场景里 offset 写了多少」—— 字段对而画错（被最小尺寸撑开、被上层盖住）正是要抓的。
func _run_region_case() -> void:
	_ctx.begin_case("COMBAT 冒烟 · 战场与状态带的真实矩形（06 §8）")
	var scene: Node = current_scene
	if not _ctx.check(scene != null, "应已进入 COMBAT 场景"):
		return
	# headless 下可用区可能是 0×0，而退化尺寸**不得**被误判成窄屏。
	_ctx.check(not bool(scene.call(&"is_narrow_layout")), "退化尺寸不得被判定为窄屏")

	for index: int in REGION_NAMES.size():
		_check_region(scene, index, EXPECTED_WIDE[index], "")

	scene.call(&"apply_layout_for", REFERENCE_VIEWPORT)
	_ctx.begin_case("COMBAT 冒烟 · 按 320×180 重落一次布局")
	for index: int in REGION_NAMES.size():
		_check_region(scene, index, EXPECTED_WIDE[index], "")


func _check_region(scene: Node, index: int, expected: Rect2, label: String) -> void:
	var region: Control = _find(scene, REGION_NAMES[index]) as Control
	if not _ctx.check(region != null, "场景应有 %s 区域容器" % REGION_NAMES[index]):
		return
	_ctx.equal(region.position, expected.position, "%s%s 的位置" % [REGION_NAMES[index], label])
	_ctx.equal(region.size, expected.size, "%s%s 的尺寸" % [REGION_NAMES[index], label])


## 验收核心：这条带的性质是「状态 / 预览」，**不是**实时动作栏。
## 00 §5 交互硬规则第 3 条：COMBAT 阶段玩家不直接操控单位 —— 一切影响都必须在进入战斗前
## 写进蓝图。故整幕 COMBAT 里不许存在任何按钮 / 输入框 / 滑条。
## 这里量的是装配出来的节点类型，不是「脚本里有没有那个 if」。
func _run_status_bar_case() -> void:
	_ctx.begin_case("COMBAT 冒烟 · 状态带是只读展示，不是动作栏（06 §8 / 00 §5）")
	var scene: Node = current_scene
	if not _ctx.check(scene != null, "应已进入 COMBAT 场景"):
		return
	var bar: Control = _find(scene, "StatusBar") as Control
	if not _ctx.check(bar != null, "应有 StatusBar 区域容器"):
		return

	var interactive: Array[Node] = []
	_collect_interactive(scene, interactive)
	_ctx.equal(interactive.size(), 0,
		"整幕 COMBAT 不得存在任何可交互控件（实际：%s）" % _names(interactive))
	var in_bar: Array[Node] = []
	_collect_interactive(bar, in_bar)
	_ctx.equal(in_bar.size(), 0, "状态带内尤其不得出现动作按钮（实际：%s）" % _names(in_bar))
	# 06 §10.3：COMBAT 期间不得弹出需要玩家即时反应的模态窗口。
	_ctx.check(_find(scene, "NoticePanel") == null, "COMBAT 不得内嵌模态提示面板（06 §10.3）")

	# 只读性正面证明：带内可显示的控件只能是 Label，且恰好 4 组「标题 + 读数」。
	var labels: Array[Label] = []
	_collect_labels(bar, labels)
	_ctx.equal(labels.size(), READOUT_CAPTIONS.size() * 2,
		"状态带内应恰好有 %d 个 Label（%d 组「标题 + 读数」）" % [
			READOUT_CAPTIONS.size() * 2, READOUT_CAPTIONS.size()])
	var texts: PackedStringArray = []
	for item: Label in labels:
		texts.append(item.text)
	for caption: String in READOUT_CAPTIONS:
		_ctx.check(texts.has(caption), "状态带应展示「%s」（06 §8 点名的状态 / 预览）" % caption)

	# 06 §8 的配色：底色 NAVY_800、上沿 1px NAVY_600。色值必须来自 Palette（06 §10.7）。
	# 06 §7.1：窄屏下带内读数「改为横向滚动」。
	var fill: ColorRect = _find(bar, "StatusFill") as ColorRect
	var edge: ColorRect = _find(bar, "StatusEdge") as ColorRect
	var scroll: ScrollContainer = _find(bar, "Readouts") as ScrollContainer
	if not _ctx.check(fill != null and edge != null, "状态带应有底色层与上沿分隔条"):
		return
	_ctx.equal(fill.color, _color("NAVY_800"), "状态带底色应取自 Palette 的 NAVY_800")
	_ctx.equal(edge.color, _color("NAVY_600"), "状态带上沿应取自 Palette 的 NAVY_600")
	_ctx.equal(edge.size.y, 1.0, "上沿厚度应为 1px（06 §8）")
	_ctx.equal(edge.size.x, EXPECTED_WIDE[_layout.Region.STATUS_BAR].size.x, "上沿应铺满整条带宽")
	if _ctx.check(scroll != null, "带内读数应装在 ScrollContainer 里"):
		_ctx.check(scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
			"窄屏下带内读数靠横向滚动（§7.1）")
		_ctx.check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"这条带是固定高的一条，不该竖向滚动")
	_ctx.check(fill.get_index() < edge.get_index(), "上沿应画在底色之上，否则会被盖掉")


## 06 §8.1（v0.1.10，Codex 裁定）：读数区恰好 5 个只读读数块，`热量` 与 `能量` 各自独立成块
## （Heat 橙 / Energy 蓝语义不同，合并成一格 `0% / 0%` 时告警读不出是哪个系统），
## CORE 改用可比较的百分比读数，且本批新增**零个**可点击控件。
##
## 这里量的是经路由进入后真实装配出来的节点；「这 5 格真的被画到屏幕上」归
## tests/unit/combat_probe.gd 的像素取证（09 §4：视觉结果不能只断言配置项）。
func _run_readout_case() -> void:
	_ctx.begin_case("COMBAT 冒烟 · 读数区 5 个只读读数块（06 §8.1）")
	var scene: Node = current_scene
	if not _ctx.check(scene != null, "应已进入 COMBAT 场景"):
		return
	var row: Node = _find(scene, "ReadoutsRow")
	if not _ctx.check(row != null, "状态带应有读数行的容器 ReadoutsRow"):
		return

	var blocks: Array[Node] = row.get_children()
	if not _ctx.equal(blocks.size(), READOUT_CAPTIONS.size(),
			"读数区应恰好 %d 个读数块" % READOUT_CAPTIONS.size()):
		return
	for index: int in READOUT_CAPTIONS.size():
		var block: Node = blocks[index]
		_ctx.check(block is VBoxContainer,
			"第 %d 块应是「标题 + 读数」的纵向容器" % (index + 1))
		var caption: Label = _find(block, "Caption") as Label
		var value: Label = _find(block, "Value") as Label
		if not _ctx.check(caption != null and value != null,
				"第 %d 块应有 Caption 与 Value 两个只读 Label" % (index + 1)):
			continue
		_ctx.equal(caption.text, READOUT_CAPTIONS[index], "第 %d 块的 Caption" % (index + 1))
		_ctx.equal(value.text, READOUT_VALUES[index], "第 %d 块的读数" % (index + 1))

	# 硬规则 1：热量与能量必须分格 —— 是两个不同的节点、且相邻。
	var heat: Node = _find(row, SPLIT_READOUTS[0])
	var energy: Node = _find(row, SPLIT_READOUTS[1])
	if _ctx.check(heat != null and energy != null, "热量与能量应各自有独立的读数块"):
		_ctx.check(heat != energy, "热量与能量必须是两个不同的节点，不得是同一格的两种说法")
		_ctx.equal(heat.get_index() + 1, energy.get_index(), "热量与能量应是相邻的两块")

	# 硬规则 2：CORE 用可比较的百分比读数，不用 `完好` 这类自然语言状态词。
	var core: Node = _find(row, "Core")
	if _ctx.check(core != null, "应有 CORE 读数块（节点名 Core）"):
		var core_value: Label = _find(core, "Value") as Label
		if _ctx.check(core_value != null, "CORE 读数块应有 Value"):
			_ctx.equal(core_value.text, CORE_VALUE,
				"CORE 应是百分比读数，不得再用自然语言状态词")

	# 硬规则 3 / 06 §10.3：本批新增零个 Button，整幕仍不得有可点击控件。
	var buttons: Array[Node] = []
	_collect_buttons(scene, buttons)
	_ctx.equal(buttons.size(), 0, "整幕 COMBAT 应仍零 Button（实际：%s）" % _names(buttons))


## 03 §1.1 R2：COMBAT 的两条出口**各自**只能由特定事件触发 —— 本波清空 → REWARD、
## CORE 被摧毁 → RESULT；且两条都必须真的经 GameFlow 换掉当前场景（R3）。
##
## 两个出口都会换掉 current_scene，故必须排在最后（同 REWARD / RESULT 各自冒烟的排法）——
## 否则后面每个用例的 current_scene 都已经不是战斗界面，会连锁报一串与它们本身无关的失败。
func _run_exit_case() -> void:
	await _check_exit(&"on_wave_cleared", "REWARD", REWARD_SCENE_PATH, "本波清空")
	await _reenter_combat()
	await _check_exit(&"on_core_destroyed", "RESULT", RESULT_SCENE_PATH, "CORE 被摧毁")


## 验一条出口：触发入口存在 → 状态真的切过去 → 当前场景真的来自路由表登记的路径 → 旧场景被释放。
## 判别力：路由表路径写错、或入口只改状态不换场景，这里都会红。
func _check_exit(method: StringName, target: String, scene_path: String, label: String) -> void:
	_ctx.begin_case("COMBAT 冒烟 · %s → %s（03 §1.1 R2）" % [label, target])
	var combat: Node = current_scene
	if not _ctx.check(combat != null and combat.scene_file_path == COMBAT_SCENE_PATH,
			"应已进入 COMBAT 场景（实际 %s）" % _scene_path()):
		return
	if not _ctx.check(combat.has_method(method), "%s 的触发入口应存在" % label):
		return
	combat.call(method)
	_ctx.equal(_state_of_flow(), _state(target), "%s 后状态应为 %s" % [label, target])
	await process_frame
	await process_frame
	_ctx.equal(_scene_path(), scene_path, "%s 后当前场景应来自路由表登记的路径" % label)
	_ctx.check(not is_instance_valid(combat), "切换后旧场景应被释放（不得两份界面同时挂着）")


## 第一条出口把场景换到了 REWARD；验第二条之前先回 COMBAT：
## REWARD → PREPARATION 是 03 §1 允许的边，再由 R1 指定的**唯一**入口 request_start_combat() 进战斗。
func _reenter_combat() -> void:
	var flow: Node = _autoload("GameFlow")
	flow.call(&"change_state", _state("PREPARATION"))
	await process_frame
	await process_frame
	flow.call(&"request_start_combat")
	await process_frame
	await process_frame
	_ctx.begin_case("COMBAT 冒烟 · 复位：REWARD → PREPARATION →（request_start_combat）→ COMBAT")
	_ctx.equal(_scene_path(), COMBAT_SCENE_PATH, "验完第一条出口后应能再次经路由回到 COMBAT")


## 06 §7.1：折叠只改变布局，**不改变任何玩法规则与状态流**；
## 验收另点明「窄屏下状态带不得挤掉战场可读性」。
func _run_narrow_case() -> void:
	_ctx.begin_case("COMBAT 冒烟 · 窄屏折叠不挤掉战场、不动状态（06 §7.1）")
	var scene: Node = current_scene
	if not _ctx.check(scene != null, "应已进入 COMBAT 场景"):
		return
	var state_before: int = _state_of_flow()

	for sample: Vector2 in [NARROW_VIEWPORT, SHORT_NARROW_VIEWPORT]:
		scene.call(&"apply_layout_for", sample)
		_ctx.check(bool(scene.call(&"is_narrow_layout")), "%s 应切到折叠布局" % sample)
		var battlefield: Control = _find(scene, REGION_NAMES[0]) as Control
		var bar: Control = _find(scene, REGION_NAMES[1]) as Control
		if battlefield == null or bar == null:
			continue
		_ctx.check(battlefield.size.y > bar.size.y,
			"%s：战场必须是主区（战场 %.0f > 状态带 %.0f）" % [sample, battlefield.size.y, bar.size.y])
		_ctx.check(bar.size.y <= sample.y * STATUS_BAR_SHARE + 0.001,
			"%s：状态带不得超过画面高的 25%%（实际 %.0f%%，§7.1 不得挤掉战场可读性）" % [
				sample, bar.size.y / sample.y * 100.0])
		# `.end` 是 Rect2 的属性，Control 上没有 —— 必须经 get_rect() 取（写 `battlefield.end`
		# 会在运行期抛错，把本用例从这一行起整个中断，后面几条断言一条都不会跑）。
		_ctx.equal(bar.position.y, battlefield.get_rect().end.y, "%s：两块区域应首尾相接" % sample)
		_ctx.equal(bar.get_rect().end.y, sample.y, "%s：状态带应贴到画面底" % sample)
		_ctx.check(not battlefield.get_global_rect().intersects(bar.get_global_rect()),
			"%s：两块区域不得重叠" % sample)

	_ctx.equal(_state_of_flow(), state_before, "折叠不得改变状态（§7.1 末条）")
	_ctx.equal(current_scene, scene, "折叠不得换场景")

	scene.call(&"apply_layout_for", REFERENCE_VIEWPORT)
	_ctx.check(not bool(scene.call(&"is_narrow_layout")), "回到基准尺寸应恢复宽屏布局")
	_ctx.equal(_find(scene, "StatusBar").size, EXPECTED_WIDE[_layout.Region.STATUS_BAR].size,
		"恢复宽屏后状态带应回到 §8 实测尺寸")


## 可交互控件：按钮、滑条、输入框。ScrollContainer 不算 —— 它只是被动滚动一个只读列表，
## 既不产生动作也不改变任何状态（06 §8 要的是「不得需要玩家长按 / 连点」）。
func _collect_interactive(node: Node, found: Array[Node]) -> void:
	if node is BaseButton or node is Range or node is LineEdit or node is TextEdit:
		found.append(node)
	for child: Node in node.get_children():
		_collect_interactive(child, found)


## 06 §8.1 硬规则 3：本批新增零个 Button。与 _collect_interactive 分开数，
## 是为了让「零 Button」这条在失败信息里单独可见，而不是混在「可交互控件」里。
func _collect_buttons(node: Node, found: Array[Node]) -> void:
	if node is BaseButton:
		found.append(node)
	for child: Node in node.get_children():
		_collect_buttons(child, found)


func _collect_labels(node: Node, found: Array[Label]) -> void:
	var label: Label = node as Label
	if label != null:
		found.append(label)
	for child: Node in node.get_children():
		_collect_labels(child, found)


func _names(nodes: Array[Node]) -> String:
	var out: PackedStringArray = []
	for node: Node in nodes:
		out.append("%s(%s)" % [node.name, node.get_class()])
	return ", ".join(out) if out.size() > 0 else "无"


func _press(button: Button) -> void:
	if button != null:
		button.emit_signal(&"pressed")


func _color(key_name: String) -> Color:
	return _palette.get_color(_palette.Key[key_name])


## 按名字找节点。刻意不用 `%` 唯一名：子场景实例的唯一名作用域挂在各自 owner 上，
## 跨子场景边界时语义容易出意外；按名字搜是确定的。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


func _state_of_flow() -> int:
	var flow: Node = _autoload("GameFlow")
	if flow == null:
		return -1
	return int(flow.call(&"get_state"))


func _state(name: String) -> int:
	return int(_flow_script.GameState[name])


## 当前场景的场景路径。无当前场景时为空串 —— 失败信息里要看得见「实际是什么」。
func _scene_path() -> String:
	return String(current_scene.scene_file_path) if current_scene != null else ""


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：S1-08（PET-43）COMBAT 场景：占位战场 + 底部状态带")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：COMBAT 经路由进入(点 CTA) · 两块区域矩形 · 状态带只读性 · 窄屏折叠 · 本波清空→REWARD / CORE 被摧毁→RESULT 各自真实换场景")
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\combat_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("combat_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
