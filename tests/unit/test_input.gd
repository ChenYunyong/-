## test_input.gd
## 职责：统一输入层（scripts/input/）的单元测试（09 §4）—— 语义事件归一、命中区尺寸、Escape 映射。
## 所属系统：tests
## 依赖：test_context
## 禁止：本文件不得依赖执行顺序；不得引用 Autoload 标识符（--script 入口编译期约束同 run_tests.gd）。
##
## 分工：本用例只查**静态与纯函数**的部分（归一算术、命中矩形、脚本装配）。
## 「Escape 在真实场景里真的换了状态」「触摸与鼠标真的推出同一个结果」要真实 GameFlow 与输入分发，
## 归 tests/integration/input_smoke.gd 独立进程 —— 在这里真去按 Escape 会改全局状态，
## 污染同进程后面的用例。
##
## 场景实例化入树是**必须**的：命中下限适配器在 _ready() 里装（install_hit_minimum），
## 不入树就量不到 hit_rect()，只会量到视觉矩形，那正是本卡要区分的两件事。

extends RefCounted

const NORMALIZER_PATH: String = "res://scripts/input/input_normalizer.gd"
const SEMANTIC_PATH: String = "res://scripts/input/semantic_input.gd"
const HIT_MINIMUM_PATH: String = "res://scripts/input/hit_minimum.gd"
const INPUT_SCREEN_PATH: String = "res://scripts/input/input_screen.gd"

const BOOT_SCENE: String = "res://scenes/boot/boot.tscn"
const MENU_SCENE: String = "res://scenes/menu/main_menu.tscn"
const PREP_SCENE: String = "res://scenes/preparation/preparation.tscn"
const COMBAT_SCENE: String = "res://scenes/combat/combat.tscn"
const REWARD_SCENE: String = "res://scenes/reward/reward.tscn"
const RESULT_SCENE: String = "res://scenes/result/result.tscn"

## 宽屏 / 窄屏两个档位。窄屏判据是**竖屏**（w/h < 1.0，PreparationLayout.NARROW_ASPECT_MAX），
## 故这里给 360×720 而不是 720×360 —— 后者是横屏，量出来的还是宽屏布局。
const WIDE: Vector2 = Vector2(1280.0, 720.0)
const NARROW: Vector2 = Vector2(360.0, 720.0)

## 六个场景根脚本：必须继承统一输入层，且不得判断原始输入事件类型（03 §8、交付物 1）。
const SCENE_SCRIPT_PATHS: Array[String] = [
	"res://scripts/ui/boot_screen.gd",
	"res://scripts/ui/main_menu.gd",
	"res://scripts/ui/preparation_screen.gd",
	"res://scripts/ui/combat_screen.gd",
	"res://scripts/ui/reward_screen.gd",
	"res://scripts/ui/result_screen.gd",
]
## 场景内的可交互组件：同样不得碰原始事件，但它们不是场景根，不继承 InputScreen
## （奖励卡是 Panel，没有也不该有 _input —— 它的事件从 gui_input 来，先归一再看语义）。
const COMPONENT_SCRIPT_PATHS: Array[String] = [
	"res://scripts/ui/reward_card.gd",
]

## 命中区量测表（本卡交付物 2 的机器可判定形式）。
## 每行 [节点路径, 视觉尺寸, 命中尺寸]；命中尺寸 = hit_rect().size（没有该方法的取 size）。
## 数值来自实测（见报告的量测表），不是照着规范反推的期望值 —— 反推的期望值只能证明算术自洽。
const HIT_TABLE: Dictionary = {
	MENU_SCENE: {
		"wide": [
			["MenuPanel/Body/ButtonStart", Vector2(90.0, 20.0), Vector2(90.0, 24.0)],
			["MenuPanel/Body/ButtonContinue", Vector2(90.0, 20.0), Vector2(90.0, 24.0)],
			["MenuPanel/Body/ButtonSettings", Vector2(90.0, 20.0), Vector2(90.0, 24.0)],
			["MenuPanel/Body/ButtonExit", Vector2(90.0, 20.0), Vector2(90.0, 24.0)],
		],
	},
	PREP_SCENE: {
		"wide": [
			["ButtonStartCombat", Vector2(64.0, 20.0), Vector2(64.0, 24.0)],
			["RegionLeft", Vector2(73.0, 124.0), Vector2(73.0, 124.0)],
		],
		"narrow": [
			["ButtonStartCombat", Vector2(44.0, 44.0), Vector2(44.0, 44.0)],
			["RegionLeft", Vector2(360.0, 16.0), Vector2(360.0, 24.0)],
		],
	},
	COMBAT_SCENE: {"wide": [], "narrow": []},
	REWARD_SCENE: {
		"wide": [
			["CardsArea/Card0", Vector2(96.0, 140.0), Vector2(96.0, 140.0)],
			["CardsArea/Card1", Vector2(96.0, 140.0), Vector2(96.0, 140.0)],
			["CardsArea/Card2", Vector2(96.0, 140.0), Vector2(96.0, 140.0)],
		],
		"narrow": [
			["CardsArea/Card0", Vector2(344.0, 140.0), Vector2(344.0, 140.0)],
			["CardsArea/Card1", Vector2(344.0, 140.0), Vector2(344.0, 140.0)],
			["CardsArea/Card2", Vector2(344.0, 140.0), Vector2(344.0, 140.0)],
		],
	},
	RESULT_SCENE: {
		"wide": [
			["Actions/ButtonMenu", Vector2(148.0, 44.0), Vector2(148.0, 44.0)],
			["Actions/ButtonRetry", Vector2(148.0, 44.0), Vector2(148.0, 44.0)],
		],
		"narrow": [
			["Actions/ButtonMenu", Vector2(344.0, 44.0), Vector2(344.0, 44.0)],
			["Actions/ButtonRetry", Vector2(344.0, 44.0), Vector2(344.0, 44.0)],
		],
	},
}


func run(ctx: RefCounted, tree: SceneTree) -> void:
	_run_normalizer_checks(ctx)
	_run_reverse_control_checks(ctx)
	_run_hit_minimum_checks(ctx)
	_run_layer_discipline_checks(ctx)
	_run_escape_declaration_checks(ctx)
	await _run_hit_table_checks(ctx, tree)


## 交付物 1 的核心：触摸与鼠标归一到**同一条**语义事件。
## 判据是 same_action_as() —— 它刻意不比 Source，正是「来源不同、语义相同」的机器可判定形式。
func _run_normalizer_checks(ctx: RefCounted) -> void:
	ctx.begin_case("输入层 · 触摸与鼠标归一到同一条语义事件（03 §8）")
	var normalizer: GDScript = load(NORMALIZER_PATH)
	var semantic: GDScript = load(SEMANTIC_PATH)
	if not ctx.check(normalizer != null and semantic != null, "输入层脚本应能加载"):
		return

	var at: Vector2 = Vector2(37.0, 51.0)
	for pressed: bool in [true, false]:
		var from_touch: Variant = normalizer.call(&"from_event", _touch(at, pressed))
		var from_mouse: Variant = normalizer.call(&"from_event", _mouse(at, pressed, MOUSE_BUTTON_LEFT))
		var label: String = "按下" if pressed else "抬起"
		if not ctx.check(from_touch != null and from_mouse != null, "%s应各产出一条语义事件" % label):
			continue
		ctx.check(bool(from_touch.call(&"same_action_as", from_mouse)),
			"同一位置%s：触摸与鼠标应是同一个语义动作（触摸 %s / 鼠标 %s）" % [
				label, from_touch.call(&"describe"), from_mouse.call(&"describe")])
		ctx.equal(from_touch.get("action"), from_mouse.get("action"), "%s的动作码" % label)
		ctx.equal(from_touch.get("position"), at, "%s应带上指针位置" % label)
		# 来源标注必须**保留差异** —— 否则「归一」就变成了「丢信息」，
		# 也就无法在测试与遥测里证明两条路径真的都被走到了。
		ctx.not_equal(from_touch.get("source"), from_mouse.get("source"), "%s的来源标注应可区分" % label)

	var touch_down: Variant = normalizer.call(&"from_event", _touch(at, true))
	var touch_up: Variant = normalizer.call(&"from_event", _touch(at, false))
	ctx.check(not bool(touch_down.call(&"same_action_as", touch_up)), "按下与抬起不得是同一个语义动作")
	ctx.check(not bool(touch_down.call(&"same_action_as",
		normalizer.call(&"from_event", _touch(at + Vector2(1.0, 0.0), true)))),
		"位置不同不得算同一个语义动作")

	ctx.equal(normalizer.call(&"from_event", _key(KEY_ESCAPE)).get("action"),
		semantic.Action.NAV_BACK, "Escape 应映射为 NAV_BACK")
	ctx.equal(normalizer.call(&"from_event", _key(KEY_ENTER)).get("action"),
		semantic.Action.NAV_CONFIRM, "Enter 应映射为 NAV_CONFIRM")
	ctx.equal(normalizer.call(&"from_event", _key(KEY_SPACE)).get("action"),
		semantic.Action.NAV_CONFIRM, "空格应映射为 NAV_CONFIRM")
	for pair: Array in [[KEY_UP, "NAV_UP"], [KEY_DOWN, "NAV_DOWN"], [KEY_LEFT, "NAV_LEFT"], [KEY_RIGHT, "NAV_RIGHT"]]:
		var expected: int = semantic.Action[String(pair[1])]
		ctx.equal(normalizer.call(&"from_event", _key(pair[0])).get("action"), expected,
			"%s 应映射为 %s" % [OS.get_keycode_string(pair[0]), pair[1]])


## 反向对照：断掉归一之后这些用例必须变红。
## 只断言「正确输入产出正确结果」是不够的 —— 一个永远返回同一件事的实现也能全绿。
func _run_reverse_control_checks(ctx: RefCounted) -> void:
	ctx.begin_case("输入层 · 反向对照（归一不得过宽或过窄）")
	var normalizer: GDScript = load(NORMALIZER_PATH)
	var at: Vector2 = Vector2(10.0, 10.0)

	for pair: Array in [
		[MOUSE_BUTTON_RIGHT, "右键"], [MOUSE_BUTTON_MIDDLE, "中键"], [MOUSE_BUTTON_WHEEL_UP, "滚轮"],
	]:
		ctx.check(normalizer.call(&"from_event", _mouse(at, true, pair[0])) == null,
			"%s 不得被当作主指针按下" % pair[1])

	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	ctx.check(normalizer.call(&"from_event", motion) == null, "鼠标移动不得产出指针按下")

	var released: InputEventKey = _key(KEY_ESCAPE)
	released.pressed = false
	ctx.check(normalizer.call(&"from_event", released) == null, "按键抬起不得产出导航动作")

	var echo: InputEventKey = _key(KEY_DOWN)
	echo.echo = true
	ctx.check(normalizer.call(&"from_event", echo) == null,
		"按住不放的自动重复不得产出导航动作（否则长按方向键会乱窜）")

	ctx.check(normalizer.call(&"from_event", _key(KEY_F5)) == null, "未登记的按键不得产出导航动作")


## 交付物 2 的算术部分：44 设备像素 ↔ 2× ↔ 22 逻辑像素，以及「按中心扩到下限」。
func _run_hit_minimum_checks(ctx: RefCounted) -> void:
	ctx.begin_case("输入层 · 命中下限算术（06 §1）")
	var hit: GDScript = load(HIT_MINIMUM_PATH)
	if not ctx.check(hit != null, "hit_minimum.gd 应能加载"):
		return
	ctx.equal(hit.MIN_TOUCH_DEVICE_PX, 44.0, "06 §1 的触摸下限是 44 设备像素")
	ctx.equal(hit.MIN_SCALE, 2.0, "双端最小缩放是 2×（03 §8）")
	ctx.equal(hit.HARD_MIN_LOGICAL, 22.0, "44 设备像素 ÷ 2× = 22 逻辑像素")
	ctx.equal(hit.required_size(), Vector2(24.0, 24.0), "本层执行的下限是 06 §1 点名的 24 逻辑像素")
	ctx.equal(hit.device_px(Vector2(24.0, 24.0)), Vector2(48.0, 48.0), "24 逻辑像素在 2× 下折合 48 设备像素")
	ctx.check(_ge(hit.device_px(hit.required_size()), Vector2(44.0, 44.0)),
		"本层下限折合的设备像素必须 ≥ 44（实际 %s）" % hit.device_px(hit.required_size()))

	var grown: Rect2 = hit.pad_rect(Rect2(Vector2(0.0, 0.0), Vector2(64.0, 20.0)))
	ctx.equal(grown.size, Vector2(64.0, 24.0), "64×20 应按中心补到 64×24")
	ctx.equal(grown.position.y, -2.0, "补高 4px 应上下各让 2px（中心不动）")
	ctx.equal(grown.position.x, 0.0, "宽度已达标，横向不得外扩")
	ctx.equal(hit.pad_rect(Rect2(Vector2(5.0, 6.0), Vector2(148.0, 44.0))),
		Rect2(Vector2(5.0, 6.0), Vector2(148.0, 44.0)), "已达标的矩形必须原样返回")

	ctx.check(hit.meets(Vector2(24.0, 24.0)), "24×24 应达标")
	ctx.check(not hit.meets(Vector2(24.0, 23.0)), "只有宽度达标不算达标（命中区是二维的）")
	ctx.check(not hit.meets(Vector2(23.0, 24.0)), "只有高度达标不算达标")


## 交付物 1 的结构面：六个场景与 reward_card 都不得再碰原始输入事件类型，
## 且原始类型只允许出现在 input_normalizer.gd 一处。
func _run_layer_discipline_checks(ctx: RefCounted) -> void:
	ctx.begin_case("输入层 · 原始事件类型只有一个出口（03 §8）")
	var layer: GDScript = load(INPUT_SCREEN_PATH)
	ctx.check(layer != null and layer.can_instantiate(), "input_screen.gd 应能编译")
	ctx.check(ClassDB.class_exists("Control") and layer != null and layer.get_base_script() == null,
		"InputScreen 应是可直接挂到场景根的脚本")
	for path: String in SCENE_SCRIPT_PATHS + COMPONENT_SCRIPT_PATHS:
		var source: String = _strip_comments(FileAccess.get_file_as_string(path))
		if not ctx.check(not source.is_empty(), "%s 应能读取" % path):
			continue
		for raw: String in ["InputEventMouseButton", "InputEventScreenTouch", "InputEventKey"]:
			ctx.check(not source.contains(raw), "%s 不得引用 %s（原始事件只在 input_normalizer.gd 翻译）" % [path, raw])
		ctx.check(not source.contains("func _input("),
			"%s 不得自己写 _input —— 输入入口只能由 InputScreen 提供" % path)
	for path: String in SCENE_SCRIPT_PATHS:
		var source: String = _strip_comments(FileAccess.get_file_as_string(path))
		ctx.check(source.contains("extends InputScreen"), "%s 应继承 InputScreen" % path)


## 交付物 3 的声明面：BOOT 不得有返回，其余五个场景必须有。
## 「返回到哪个状态」属行为，归 input_smoke.gd —— 在这里真调一次会改全局状态。
func _run_escape_declaration_checks(ctx: RefCounted) -> void:
	ctx.begin_case("输入层 · Escape 映射的声明（交付物 3）")
	var with_back: Array[String] = [
		"res://scripts/ui/main_menu.gd",
		"res://scripts/ui/preparation_screen.gd",
		"res://scripts/ui/combat_screen.gd",
		"res://scripts/ui/reward_screen.gd",
		"res://scripts/ui/result_screen.gd",
	]
	for path: String in with_back:
		var source: String = _strip_comments(FileAccess.get_file_as_string(path))
		ctx.check(source.contains("func _on_back_requested()"),
			"%s 应覆盖 _on_back_requested()" % path)
	var boot: String = _strip_comments(FileAccess.get_file_as_string("res://scripts/ui/boot_screen.gd"))
	ctx.check(not boot.contains("func _on_back_requested()"),
		"BOOT 不得覆盖 _on_back_requested()（03 §1.1 R1：它没有入边，没有上一态可回）")


## 交付物 2 的实测量测：把每个场景真的挂进树（触发 _ready 装适配器），
## 按表逐元素核对视觉尺寸与命中尺寸，并核对「表是完整的」—— 没有表外的可交互元素漏网。
func _run_hit_table_checks(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("输入层 · 命中区实测表（交付物 2）")
	for scene_path: String in HIT_TABLE:
		for mode: String in HIT_TABLE[scene_path]:
			await _measure_scene(ctx, tree, scene_path, mode)
	await _measure_boot(ctx, tree)


func _measure_scene(ctx: RefCounted, tree: SceneTree, scene_path: String, mode: String) -> void:
	var packed: PackedScene = load(scene_path)
	if not ctx.check(packed != null, "%s 应能加载" % scene_path):
		return
	var scene: Node = packed.instantiate()
	tree.root.add_child(scene)
	await tree.process_frame
	var viewport_size: Vector2 = NARROW if mode == "narrow" else WIDE
	if scene.has_method(&"apply_layout_for"):
		scene.call(&"apply_layout_for", viewport_size)
	await tree.process_frame

	var expected: Array = HIT_TABLE[scene_path][mode]
	var live: Array[Node] = _interactive(scene)
	ctx.equal(live.size(), expected.size(),
		"%s[%s] 的可交互元素个数（表必须完整，不得有漏网或多余）" % [scene_path, mode])
	for row: Array in expected:
		_measure_row(ctx, scene, String(row[0]), mode, row[1], row[2])
	scene.queue_free()
	await tree.process_frame


func _measure_row(ctx: RefCounted, scene: Node, node_path: String, mode: String, visual: Vector2, hit: Vector2) -> void:
	var control: Control = scene.get_node_or_null(NodePath(node_path)) as Control
	if not ctx.check(control != null, "%s[%s] 应有 %s" % [scene.get_scene_file_path(), mode, node_path]):
		return
	var hit_size: Vector2 = control.call(&"hit_rect").size if control.has_method(&"hit_rect") else control.size
	ctx.equal(control.size, visual, "%s[%s] 的视觉尺寸（不得因命中区而改变）" % [node_path, mode])
	ctx.equal(hit_size, hit, "%s[%s] 的命中尺寸" % [node_path, mode])
	var need: Vector2 = load(HIT_MINIMUM_PATH).required_size()
	ctx.check(_ge(hit_size, need), "%s[%s] 命中区应 ≥ %s（实际 %s）" % [node_path, mode, need, hit_size])
	ctx.check(_ge(hit_size * 2.0, Vector2(44.0, 44.0)),
		"%s[%s] 命中区折合设备像素应 ≥ 44（实际 %s）" % [node_path, mode, hit_size * 2.0])


## BOOT 刻意**不入树**：它的 _ready() 会把真实 GameFlow 从 BOOT 推到 MAIN_MENU，
## 那会污染同进程里 test_state_loop.gd 的断言。它本来也没有可交互元素，不入树就够查。
func _measure_boot(ctx: RefCounted, tree: SceneTree) -> void:
	var scene: Node = (load(BOOT_SCENE) as PackedScene).instantiate()
	ctx.equal(_interactive(scene).size(), 0, "BOOT 按 06 §5 只有自检提示，不得有可交互元素")
	scene.free()
	await tree.process_frame


## 可交互 = 会对指针按下作出反应：Button，或连了 gui_input 的控件（奖励卡、窄屏信息条）。
## 刻意**不用** mouse_filter == STOP 当判据 —— 那是控件的默认值，背景板与标题栏也会命中，
## 量出来的是装饰不是交互面。
func _interactive(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			stack.append(child)
		var control: Control = node as Control
		if control == null or control == root or not control.visible:
			continue
		if control is Button or control.has_connections(&"gui_input"):
			found.append(control)
	return found


func _touch(at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	return event


func _mouse(at: Vector2, pressed: bool, button: int) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.position = at
	event.pressed = pressed
	return event


func _key(code: int) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event


## 去掉注释后再做源码检查。本仓库的注释里大量引用事件类名（"不得判断 InputEventMouseButton"），
## 不去注释的话，规制本身的说明会把规制检查打红。
func _strip_comments(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		var cut: int = line.find("#")
		kept.append(line if cut < 0 else line.substr(0, cut))
	return "\n".join(kept)


func _ge(actual: Vector2, minimum: Vector2) -> bool:
	return actual.x >= minimum.x and actual.y >= minimum.y
