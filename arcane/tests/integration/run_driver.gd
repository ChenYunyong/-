## run_driver.gd
## 职责：两个端到端用例（defeat_smoke / full_run_smoke）共用的「真人操作」驱动 ——
##       启一局、摆卡连线、按按钮、等换屏、在路线图上点亮下一站、把一场打完。
## 所属系统：tests
## 依赖：TreeProbe, CardCatalog, MapLayout, MapView, MapModel, BoardModel, CombatSim
## 禁止：本文件不是用例（不进 TEST_SCRIPTS）：它自己零断言，只把「成没成」交回给调用方去断。
##       不得把 GameFlow 的私有状态当常规接口 —— reset_to_boot() 只服务「同一个进程里再启一次」。
##
## 为什么把驱动抽出来：两条端到端走的是同一条路（启一局 → 摆卡 → 打 → 结算），差别只在
## 「怎么输」和「打几层」。各写一套点按钮的代码，迟早只有一份跟着界面改。loop_smoke **不动**。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const BOOT_SCENE: String = "res://scenes/boot.tscn"

## 按钮文案的 key。界面上的字一律经 UiKit → TranslationServer 出来，故按译文找。
const KEY_NEW_RUN: String = "开始新一局"
const KEY_START_BATTLE: String = "开始战斗"
const KEY_CHOOSE: String = "选择"
const KEY_CONTINUE: String = "继续"
const KEY_SETTLE: String = "结算"
const KEY_MENU: String = "回到主菜单"
const KEY_AGAIN: String = "再来一局"

## 等一次换屏最多等几帧。
const SWITCH_FRAMES: int = 12
## 战斗按**真实计时器**走（20Hz）：三波是 30 秒真实时间。压 time_scale 而不是去戳战斗屏的
## 内部方法 —— 戳内部就绕开了「计时器真的在跑」这件事，而那正是这些用例要证明的。用完还原。
const FIGHT_TIME_SCALE: float = 50.0
const MAX_FIGHT_FRAMES: int = 8000

var _tree: SceneTree = null
var _flow: Node = null
var _run: Node = null
var _last_error: String = ""
## 开跑前的书页快照。收尾时照它还原 —— 见 teardown()。
var _board_before: Dictionary = {}


func setup(tree: SceneTree) -> bool:
	_tree = tree
	_flow = tree.root.get_node_or_null(^"GameFlow")
	_run = tree.root.get_node_or_null(^"RunState")
	if _flow == null or _run == null:
		return _fail("GameFlow / RunState 单例不全")
	_board_before = _run.board().snapshot()
	return true


func flow() -> Node:
	return _flow


func run_state() -> Node:
	return _run


func scene() -> Node:
	return _tree.current_scene


## 上一步为什么没成。调用方在断言里带上它，失败时不必去猜是哪一环断的。
func last_error() -> String:
	return _last_error


# ------------------------------------------------------------------ 启一局

## 把状态机摆回 BOOT。同一个进程里只能**启动**一次（状态图里没有回到 BOOT 的边），
## 但两个端到端用例都得从「引擎刚起来」那一刻开始 —— 这一行是测试侧的夹具：
## 只改状态，不发信号、不换屏，也不进游戏代码。
func reset_to_boot() -> void:
	_flow.set(&"_state", _flow.GameState.BOOT)
	_last_error = ""


## 引擎启动走的那条路：落地 boot → 自检 → 主菜单。
func boot_into_menu() -> bool:
	var packed: PackedScene = load(BOOT_SCENE)
	if packed == null:
		return _fail("boot.tscn 加载不了")
	var boot: Node = packed.instantiate()
	_tree.root.add_child(boot)
	# 引擎会把主场景记成 current_scene，这一步必须补：change_scene_to_file() 只回收
	# current_scene，不补的话 boot 会留在树里跟下一屏并存。
	_tree.current_scene = boot
	return await await_until(_changed_from(boot.get_instance_id()), SWITCH_FRAMES)


## 玩家动作：按「开始新一局」，把这一局开出来。
func start_new_run() -> bool:
	var button: Button = button_for(scene(), KEY_NEW_RUN)
	if button == null:
		return _fail("主菜单上没有「%s」" % KEY_NEW_RUN)
	return await press_and_wait(button, _flow.GameState.EDITOR)


# ------------------------------------------------------------------ 摆卡与连线

## 点仓库里的卡位，把一张卡摆上书页（走 CardChip 的 chosen 信号，与玩家点它同一条）。
func place_card(card_id: StringName) -> BoardModel.PlacedCard:
	var chip: Node = _chip_for(card_id)
	if chip == null:
		_fail("仓库里没有 %s 的卡位" % card_id)
		return null
	chip.chosen.emit(card_id)
	return placed_of(card_id)


## 连线。真实路径是「从输出接口拖到输入接口」，那条手势链由 BoardView 自己的用例负责；
## 这里走的是它的出口 —— 画布发出的连线请求真的落到书页上。
func link(from_uid: int, to_uid: int) -> bool:
	var canvas: Node = _first_of("BoardView")
	if canvas == null:
		return _fail("编辑器里没有书页画布")
	canvas.link_requested.emit(from_uid, to_uid)
	return _run.board().has_link(from_uid, to_uid)


func placed_of(card_id: StringName) -> BoardModel.PlacedCard:
	for placed: BoardModel.PlacedCard in _run.board().cards():
		if placed.card_id == card_id:
			return placed
	return null


# ------------------------------------------------------------------ 路线图

## 在路线图上点亮下一站：press() 是 MapView 的公开入口（与 map_view_smoke 同一条路），
## 它自己判命中与可走，走成了才 select() 并发出 node_chosen。返回走到的节点 id。
func select_next_node() -> int:
	var view: MapView = _first_of("MapView") as MapView
	var options: Array[MapModel.MapNode] = _run.map().selectable()
	if view == null or options.is_empty():
		_fail("路线图上没有可走的一站")
		return -1
	var node: MapModel.MapNode = options[0]
	view.press(MapLayout.node_position(node.tier, node.column))
	return _run.map().current_id()


## 一张图的指纹：每个节点的位置 + 类型 + 出边。用来比较两张图是不是同一张。
func map_fingerprint() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node: MapModel.MapNode in _run.map().nodes():
		parts.append("%d/%d:%d:%s" % [node.tier, node.column, int(node.kind), str(node.next)])
	return "|".join(parts)


# ------------------------------------------------------------------ 打

## 打到这一场自然收场（离战斗屏为止）：打赢了会去奖励屏 / 结算屏。
func fight_to_end() -> bool:
	Engine.time_scale = FIGHT_TIME_SCALE
	var left: bool = await await_until(func() -> bool:
		return _flow.get_state() != _flow.GameState.COMBAT, MAX_FIGHT_FRAMES)
	Engine.time_scale = 1.0
	if not left:
		_fail("战斗在帧预算内没有结束")
	return left


## 打到「核心被摧毁」为止。这一场**不会自己离开战斗屏**（先让玩家看见那句话），
## 所以等的是那颗「结算」出现，而不是等状态变化。
func fight_until_settle() -> bool:
	Engine.time_scale = FIGHT_TIME_SCALE
	var ready: bool = await await_until(func() -> bool:
		return visible_button(KEY_SETTLE) != null, MAX_FIGHT_FRAMES)
	Engine.time_scale = 1.0
	if not ready:
		_fail("核心没有被摧毁（%d 帧内没等到「%s」）" % [MAX_FIGHT_FRAMES, KEY_SETTLE])
	return ready


# ------------------------------------------------------------------ 按按钮与等待

## 按下并等到「状态切到 expected **且**场景真的换过」。
func press_and_wait(button: Button, expected: int) -> bool:
	var from_id: int = scene().get_instance_id()
	button.pressed.emit()
	var ok: bool = await await_until(func() -> bool:
		return _flow.get_state() == expected and _tree.current_scene != null \
			and _tree.current_scene.get_instance_id() != from_id, SWITCH_FRAMES)
	if not ok:
		_fail("按下「%s」后没等到 %s（现在是 %s）"
			% [button.text, _flow.state_name(expected), _flow.state_name(_flow.get_state())])
	return ok


## 按下之后等状态离开当前这个值（下一屏是哪一个由用例自己断）。
func press_and_leave(button: Button) -> bool:
	var from_id: int = scene().get_instance_id()
	var was: int = _flow.get_state()
	button.pressed.emit()
	var ok: bool = await await_until(func() -> bool:
		return _flow.get_state() != was and _tree.current_scene != null \
			and _tree.current_scene.get_instance_id() != from_id, SWITCH_FRAMES)
	if not ok:
		_fail("按下「%s」后没有离开 %s" % [button.text, _flow.state_name(was)])
	return ok


## 等到条件成立为止（最多 limit 帧），返回条件最终是否成立。
func await_until(condition: Callable, limit: int) -> bool:
	for _frame: int in limit:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()


## current_scene 是否已经不再是 from_id 那个实例。
## 闭包只带 int（实例 id）：被换下去的场景会被引擎立刻回收，捕获了它就会在下一帧变成
## 「Lambda capture was freed. Passed null instead」。
func _changed_from(from_id: int) -> Callable:
	return func() -> bool:
		return _tree.current_scene != null and _tree.current_scene.get_instance_id() != from_id


## 把当前场景摘掉，让下一个用例从干净的树开始（否则上一屏会一直挂在 root 下）。
func drop_scene() -> void:
	if _tree.current_scene != null:
		_tree.current_scene.queue_free()
		_tree.current_scene = null
	await _tree.process_frame


## 收尾：摘掉场景、把这一局收掉、书页按**开跑前**的快照还原、状态机摆回 BOOT。
## 后面还有用例假定自己从「引擎刚起来」那一刻开始（loop_smoke 跑在最后）—— 而
## RunState.start_run() 有意不清空书页（书页是玩家搭的成果），抹痕迹只能由这里做。
func teardown() -> void:
	await drop_scene()
	_run.end_run()
	_run.board().restore(_board_before)
	_flow.set(&"_state", _flow.GameState.BOOT)


# ------------------------------------------------------------------ 树里找东西

func button_for(root: Node, text_key: String) -> Button:
	var wanted: String = TranslationServer.translate(text_key)
	for node: Node in TreeProbe.find_all(root, "Button"):
		if (node as Button).text == wanted:
			return node as Button
	return null


func buttons_of(root: Node, text_key: String) -> Array[Node]:
	var wanted: String = TranslationServer.translate(text_key)
	var found: Array[Node] = []
	for node: Node in TreeProbe.find_all(root, "Button"):
		if (node as Button).text == wanted:
			found.append(node)
	return found


## 屏幕上**看得见**的那颗按钮。战斗屏的「结算」一直都在树里，只是平时藏着。
func visible_button(text_key: String) -> Button:
	var button: Button = button_for(scene(), text_key)
	if button == null or not button.is_visible_in_tree():
		return null
	return button


func has_label(root: Node, text_key: String) -> bool:
	var wanted: String = TranslationServer.translate(text_key)
	for node: Node in TreeProbe.find_all(root, "Label"):
		if (node as Label).text == wanted:
			return true
	return false


## 含某段文字的那一行（整串）。账目那种「几笔拼成一行」的，逐条精确匹配是匹配不上的。
## 找不到返回空串。
func label_containing(root: Node, needle: String) -> String:
	for node: Node in TreeProbe.find_all(root, "Label"):
		var text: String = (node as Label).text
		if text.contains(needle):
			return text
	return ""


func _chip_for(card_id: StringName) -> Node:
	for node: Node in TreeProbe.find_all(scene(), "CardChip"):
		if node.card_id == card_id:
			return node
	return null


func _first_of(kind: String) -> Node:
	var found: Array[Node] = TreeProbe.find_all(scene(), kind)
	return found[0] if not found.is_empty() else null


func _fail(note: String) -> bool:
	_last_error = note
	return false
