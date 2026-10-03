## combat_smoke.gd
## 职责：COMBAT 场景的场景冒烟（09 §1）—— 经真实 GameFlow 路由进入、两块区域的真实矩形、
##       状态带**不含任何可交互控件**、REWARD / RESULT 两个出口的可读提示路径、
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
## 06 §7.1 的窄屏取样，与 test_combat.gd 同值但独立复写。
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)
const SHORT_NARROW_VIEWPORT: Vector2 = Vector2(180.0, 120.0)

## 06 §8 的实测值，在本文件独立复写一遍（期望值若与被测实现同源，实现改错时两边一起错）。
## 下标即 CombatLayout.Region。两块都全宽 —— §8 明写那条带「横贯全宽」。
const REGION_NAMES: PackedStringArray = ["Battlefield", "StatusBar"]
const EXPECTED_WIDE: Array[Rect2] = [
	Rect2(0.0, 0.0, 320.0, 135.0),
	Rect2(0.0, 135.0, 320.0, 45.0),
]
## 06 §8：状态带占画面高约 25%。窄屏下它是上限（§7.1「不得挤掉战场可读性」）。
const STATUS_BAR_SHARE: float = 0.25

## 06 §8 点名的状态 / 预览项，独立复写。
const READOUT_CAPTIONS: PackedStringArray = ["波次", "CORE", "热量 / 能量", "待发射队列"]

## 两个出口的提示必须让玩家看得出「要往哪去」。这里只核关键词，不核整句 ——
## 整句由实现自己定，核整句就成了同义反复。
const EXPECT_REWARD_KEYWORD: String = "REWARD"
const EXPECT_RESULT_KEYWORD: String = "RESULT"

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
	_run_exit_notice_case()
	_run_narrow_case()
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


## 验收：COMBAT → REWARD / COMBAT → RESULT 的**触发入口存在**，但目标场景尚未实现
## （REWARD 属 S1-09、RESULT 属 S1-10），故当前只做**可读提示**，不静默无效、也不崩。
##
## 提示刻意做成战场里的只读 Label 而不是模态面板：06 §10.3 禁止 COMBAT 期间弹出
## 需要玩家即时反应的模态窗口，而这条提示只是告知「出口还没做好」，不该打断观察。
func _run_exit_notice_case() -> void:
	_ctx.begin_case("COMBAT 冒烟 · REWARD / RESULT 出口给出可读提示（场景尚未实现）")
	var scene: Node = current_scene
	if not _ctx.check(scene != null, "应已进入 COMBAT 场景"):
		return
	for entry: Array in [
		[&"on_wave_cleared", _state("REWARD"), EXPECT_REWARD_KEYWORD, "本波清空 → REWARD"],
		[&"on_core_destroyed", _state("RESULT"), EXPECT_RESULT_KEYWORD, "CORE 被摧毁 → RESULT"],
	]:
		var target: int = int(entry[1])
		var label: String = String(entry[3])
		_ctx.check(String(_flow_script.SCENE_ROUTES.get(target, {}).get("path", "")).is_empty()
				or not ResourceLoader.exists(String(_flow_script.SCENE_ROUTES[target]["path"])),
			"前置：%s 的目标场景当前确实尚未实现（否则本用例会空转）" % label)
		if not _ctx.check(scene.has_method(entry[0]), "%s 的触发入口应存在" % label):
			continue

		var notice: Label = _find(scene, "NoticeLabel") as Label
		if not _ctx.check(notice != null, "应有可读提示控件"):
			continue
		notice.visible = false

		scene.call(entry[0])
		_ctx.check(notice.visible, "%s 必须给出提示，不得静默无效" % label)
		_ctx.check(notice.text.contains(String(entry[2])),
			"%s 的提示应指明要去的场景（应含 `%s`，实际：%s）" % [label, entry[2], notice.text])
		_ctx.check(_has_cjk(notice.text), "%s 的提示必须是中文（屏幕上要读得懂）" % label)
		_ctx.equal(_state_of_flow(), _state("COMBAT"), "%s 在目标场景未实现时状态必须停在 COMBAT" % label)
		_ctx.equal(current_scene, scene, "%s 在目标场景未实现时不得换场景" % label)
		_ctx.check(_has_no_window_ancestor(notice, scene), "%s 的提示不得是模态窗口（06 §10.3）" % label)


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
		_ctx.equal(bar.position.y, battlefield.end.y, "%s：两块区域应首尾相接" % sample)
		_ctx.equal(bar.end.y, sample.y, "%s：状态带应贴到画面底" % sample)
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


## 06 §10.3：COMBAT 期间不得弹出需要玩家即时反应的模态窗口。
## 提示必须挂在普通 Control 树上 —— 场景自己的子树里一旦出现 Window / Popup，它就是模态的了。
##
## 只走到场景根为止：再往上必然经过 SceneTree 的 root，而那本身就是一个 Window，
## 一路走到底会让这条断言恒假（写成 `notice is Window` 则恒真）—— 两种写法都没有判别力。
func _has_no_window_ancestor(node: Node, scene: Node) -> bool:
	var current: Node = node
	while current != null and current != scene:
		if current is Window or current is Popup:
			return false
		current = current.get_parent()
	return true


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


func _has_cjk(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


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
	_lines.append("- 手动场景：COMBAT 经路由进入(点 CTA) · 两块区域矩形 · 状态带只读性 · REWARD/RESULT 出口提示 · 窄屏折叠")
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
