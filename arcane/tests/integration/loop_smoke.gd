## loop_smoke.gd
## 职责：一局完整循环的端到端冒烟 —— 启动 → 主菜单开新局 → 编辑器摆卡连线 → 自动施法战斗 →
##       奖励 → 路线图选下一站 → 回编辑器。
## 所属系统：tests
## 依赖：TreeProbe, CardCatalog, BoardModel, CombatSim, RewardModel, MapModel, MapLayout
## 禁止：本文件**必须留在 TEST_SCRIPTS 的最后一行** —— 它会一路把真实的 GameFlow 换过去。
##
## 与其它用例的分工：别的用例都刻意避开单例副作用（造副本、只读、只算数）；这一条恰恰相反，
## 它要证明的就是**真实那条路真的通** —— 任何一环断开这条就红。
## PET-92：奖励之后去路线图选下一站；这一条只走到「回到编辑器」为止（「继续」会真的开打），
## 从开局一路打到通关那条在 full_run_smoke 里。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const BOOT_SCENE: String = "res://scenes/boot.tscn"

## 战斗按**真实计时器**走：三波 30 秒真实时间。压 time_scale 而不是去戳战斗屏的内部方法 ——
## 戳内部就绕开了「计时器真的在跑」这件事，而那正是本用例要证明的。用完必须还原。
const FIGHT_TIME_SCALE: float = 50.0
const MAX_FRAMES: int = 8000
## 按钮文案的 key。按钮上的字是 UiKit 用 TranslationServer 翻好的，故按译文找。
const KEY_NEW_RUN: String = "开始新一局"
const KEY_START_BATTLE: String = "开始战斗"
const KEY_BACK_EDITOR: String = "返回编辑器"

var _tree: SceneTree = null
var _flow: Node = null
var _run: Node = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("loop_smoke")
	_tree = tree
	_flow = tree.root.get_node_or_null(^"GameFlow")
	_run = tree.root.get_node_or_null(^"RunState")
	if not ctx.check(_flow != null and _run != null, "GameFlow / RunState 两个单例都在"):
		return
	if not await _boot(ctx):
		return
	if not await _blueprint(ctx):
		return
	if not await _fight(ctx):
		return
	if not await _reward(ctx):
		return
	_check_loop_closed(ctx)


# ---------------------------------------------------------------- 第一步：启动

## 引擎启动走的就是这条路：落地 boot → 自检 → 主菜单，再由玩家按「开始新一局」把这一局开出来。
func _boot(ctx: RefCounted) -> bool:
	var packed: PackedScene = load(BOOT_SCENE)
	if not ctx.check(packed != null, "boot.tscn 可加载"):
		return false
	var boot: Node = packed.instantiate()
	_tree.root.add_child(boot)
	# 引擎把主场景记成 current_scene，这一步必须补：change_scene_to_file() 只回收 current_scene。
	_tree.current_scene = boot
	var boot_id: int = boot.get_instance_id()

	var routed: bool = await _await_until(func() -> bool: return _scene_changed_from(boot_id), 12)
	if not ctx.check(routed, "boot 自检通过并请求了切场景"):
		return false
	ctx.equal(_flow.get_state(), _flow.GameState.MAIN_MENU, "启动后落在主菜单")
	ctx.check(not _run.is_active(), "启动时**没有**替玩家开局（否则「继续」会永远是亮的）")
	ctx.check(_tree.current_scene is Control, "当前场景是主菜单")

	# 玩家动作：按「开始新一局」。必须走**按钮** —— 直接调 start_run() 就绕开了「主菜单真的接对了线」。
	var menu: Node = _tree.current_scene
	var start: Button = _button_for(menu, KEY_NEW_RUN)
	if not ctx.check(start != null, "主菜单有「开始新一局」按钮"):
		return false
	var menu_id: int = menu.get_instance_id()
	start.pressed.emit()
	var entered: bool = await _await_until(func() -> bool:
		return _flow.get_state() == _flow.GameState.EDITOR and _scene_changed_from(menu_id), 12)
	if not ctx.check(entered, "按「开始新一局」后真的切到了编辑器"):
		return false
	ctx.check(_run.is_active(), "按下去才真的开了一局")
	ctx.equal(_run.current_wave(), 1, "新的一局从第 1 波开始")
	ctx.check(_tree.current_scene is Control, "当前场景是编辑器")
	return true


# ------------------------------------------------- 第二步：在编辑器里搭最小可用的蓝图

## 一张核心 + 一张要付费的法术 + 一条丝线。这是战斗能出伤害的最小配置。
func _blueprint(ctx: RefCounted) -> bool:
	var editor: Node = _tree.current_scene
	var chips: Array[Node] = TreeProbe.find_all(editor, "CardChip")
	if not ctx.equal(chips.size(), CardCatalog.all().size(), "仓库里卡位与卡表一一对应"):
		return false

	var core: CardData = _first_card(true)
	var spell: CardData = _first_card(false)
	if not ctx.check(core != null and spell != null, "卡表里既有核心卡、也有要付费的法术卡"):
		return false

	var board: BoardModel = _run.board()
	var before: int = board.cards().size()
	# 玩家动作：点仓库里的卡位。
	_chip_for(chips, core.id).chosen.emit(core.id)
	_chip_for(chips, spell.id).chosen.emit(spell.id)
	ctx.equal(board.cards().size(), before + 2, "点两下卡位，书页上多了两张卡")

	var placed_core: BoardModel.PlacedCard = _placed_of(board, core.id)
	var placed_spell: BoardModel.PlacedCard = _placed_of(board, spell.id)
	if not ctx.check(placed_core != null and placed_spell != null, "两张卡都在书页上找得到"):
		return false
	ctx.check(placed_core.position != placed_spell.position, "两张卡没有叠在同一个坐标上")

	# 真实路径是「拖接口」，那条手势链由 BoardView 自己的用例负责；这里验它的出口。
	var canvas: Node = TreeProbe.find_all(editor, "BoardView")[0]
	canvas.link_requested.emit(placed_core.uid, placed_spell.uid)
	ctx.equal(board.links().size(), 1, "从核心拖出一条丝线接到法术上")

	# 反向对照：这条丝线得真的能被战斗看见。看不见的话下面战斗会一张牌都不放。
	var probe: CombatSim = CombatSim.new()
	probe.begin(board, 1)
	ctx.check(not probe.cast_order().is_empty(),
		"战斗队列里排到了 %d 张法术（证明编辑器改的就是战斗读的那份书页）" % probe.cast_order().size())

	# 开打。按钮文案是 tr 过的，按译文找。
	var start: Button = _button_for(editor, KEY_START_BATTLE)
	if not ctx.check(start != null, "顶栏有「开始战斗」按钮"):
		return false
	var editor_id: int = editor.get_instance_id()
	start.pressed.emit()
	var entered: bool = await _await_until(func() -> bool:
		return _flow.get_state() == _flow.GameState.COMBAT and _scene_changed_from(editor_id), 12)
	if not ctx.check(entered, "按「开始战斗」后真的切到了战斗屏"):
		return false
	# 计时器是战斗屏在 _ready() 里 Timer.new() 出来的，名字由引擎生成（`@Timer@2`），
	# 不是场景文件里写死的「Timer」—— 按类型找，别按名字找。
	ctx.check(_tick_timer() != null, "战斗屏的计时器在树里")
	return true


# ---------------------------------------------------------------- 第三步：打完三波

func _fight(ctx: RefCounted) -> bool:
	var timer: Timer = _tick_timer()
	if not ctx.check(timer != null and not timer.is_stopped(), "战斗计时器真的在跑"):
		return false
	# 「固定步长」得真的验：步长必须是 1/CombatSim.TICK_HZ，而不是随便一个 timer。
	ctx.near(timer.wait_time, 1.0 / float(CombatSim.TICK_HZ), "步长是 20Hz（1/%d 秒）" % CombatSim.TICK_HZ)

	Engine.time_scale = FIGHT_TIME_SCALE
	var left_combat: bool = await _await_until(func() -> bool:
		return _flow.get_state() != _flow.GameState.COMBAT, MAX_FRAMES)
	Engine.time_scale = 1.0

	if not ctx.check(left_combat, "战斗在帧预算内结束（既没卡死，也没被核心被摧毁拖住）"):
		return false
	ctx.equal(_run.current_wave(), _run.TOTAL_WAVES, "打完的是最后一波（不是中途溜走）")
	ctx.equal(_flow.get_state(), _flow.GameState.REWARD, "打完进奖励屏")
	return true


# ------------------------------------------------- 第四步：领奖励 → 路线图 → 编辑器

## 领奖励。奖励是「种子 + 波次」推出来的，这里不预设是哪张，只挑**卡**那一项 ——
## 两个加成不改书页，验不了「奖励真的落到了书页上」。§2：选完去路线图，不再回编辑器。
func _reward(ctx: RefCounted) -> bool:
	var reward: Node = _tree.current_scene
	var reward_id: int = reward.get_instance_id()
	var options: Array[Dictionary] = _run.roll_rewards()
	var index: int = _first_card_option(options)
	if not ctx.check(index >= 0, "这一波的奖励里有可拿的卡"):
		return false
	# 选项顺序 = 界面建按钮的顺序（reward_screen 按下标建），故第 index 颗「选择」就是它。
	var buttons: Array[Node] = TreeProbe.find_all(reward, "Button")
	if not ctx.check(buttons.size() == options.size() + 1,
			"奖励屏：每个选项一颗「选择」+ 一颗跳过（数到 %d 颗）" % buttons.size()):
		return false

	var board: BoardModel = _run.board()
	var before: int = board.cards().size()
	(buttons[index] as Button).pressed.emit()
	if not ctx.check(await _await_until(func() -> bool:
			return _flow.get_state() == _flow.GameState.MAP and _scene_changed_from(reward_id), 12),
			"选完奖励去路线图"):
		return false
	ctx.equal(board.cards().size(), before + 1, "奖励卡真的加进了书页")
	# 只放不连的话它一次都不会被施放 —— 这条丝线就是「选择真的改变下一波」的那根线。
	ctx.equal(board.links().size(), 2, "新卡也从核心拉了一条丝线")
	return await _leave_map(ctx)


## 在路线图上点亮下一站，再回编辑器 —— 「一局」的推进到这里才算真的接上。
## 走「返回编辑器」而不是「继续」：后者会真的开打，打通关那条在 full_run_smoke 里。
func _leave_map(ctx: RefCounted) -> bool:
	var screen: Node = _tree.current_scene
	var view: Node = TreeProbe.find_all(screen, "MapView")[0]
	var next_node: MapModel.MapNode = _run.map().selectable()[0]
	view.press(MapLayout.node_position(next_node.tier, next_node.column))
	ctx.equal(_run.map().current_id(), next_node.id, "在路线图上点亮了下一站")
	var screen_id: int = screen.get_instance_id()
	var back: Button = _button_for(screen, KEY_BACK_EDITOR)
	if not ctx.check(back != null, "路线图屏有「返回编辑器」"):
		return false
	back.pressed.emit()
	return ctx.check(await _await_until(func() -> bool:
			return _flow.get_state() == _flow.GameState.EDITOR and _scene_changed_from(screen_id), 12),
			"从路线图回到编辑器")


## 回到编辑器之后，前面那两张卡和那条丝线必须还在 —— 编辑器读的得是同一份书页。
## 这正是「两份书页」这类断链会露馅的地方：卡加进了 RunState，界面却显示另一份。
func _check_loop_closed(ctx: RefCounted) -> void:
	var editor: Node = _tree.current_scene
	ctx.check(editor is Control, "回到的是编辑器")
	var board: BoardModel = _run.board()
	ctx.check(board.cards().size() >= 3, "书页上留着 %d 张卡（原有的 + 奖励的）" % board.cards().size())
	ctx.equal(board.links().size(), 2, "丝线还在：原来那条 + 奖励卡接上核心的那条")
	ctx.check(TreeProbe.count_of(editor, "BoardView") == 1, "编辑器画布还在")
	# 状态栏是编辑器自己算的：它跟书页对得上，才说明界面真的按新书页刷新过。
	var expected: String = TranslationServer.translate("卡片 %d · 丝线 %d") % [board.cards().size(), board.links().size()]
	var status: Label = _label_with_text(editor, expected)
	ctx.check(status != null, "编辑器状态栏与书页一致：%s" % expected)


# ---------------------------------------------------------------- 工具

## 卡表里第一张核心 / 第一张要付费的非核心卡。
func _first_card(want_core: bool) -> CardData:
	for card: CardData in CardCatalog.all():
		if card.is_core() == want_core and (want_core or card.mana_cost > 0):
			return card
	return null


## 选项里第一个「拿卡」的下标。找不到返回 -1（池子只剩两个加成时会这样）。
static func _first_card_option(options: Array[Dictionary]) -> int:
	for index: int in options.size():
		if RewardModel.is_card(options[index]):
			return index
	return -1


## 战斗屏自己的那个节拍计时器。
func _tick_timer() -> Timer:
	for node: Node in TreeProbe.find_all(_tree.current_scene, "Timer"):
		return node
	return null


func _chip_for(chips: Array[Node], card_id: StringName) -> Node:
	for chip: Node in chips:
		if chip.card_id == card_id:
			return chip
	return chips[0]


func _placed_of(board: BoardModel, card_id: StringName) -> BoardModel.PlacedCard:
	for placed: BoardModel.PlacedCard in board.cards():
		if placed.card_id == card_id:
			return placed
	return null


func _button_for(root: Node, text_key: String) -> Button:
	var wanted: String = TranslationServer.translate(text_key)
	for node: Node in TreeProbe.find_all(root, "Button"):
		var button: Button = node
		if button.text == wanted:
			return button
	return null


## 编辑器顶栏的状态栏。按**算好的整串**精确匹配 —— 详情面板的「核心卡 · 法术」也含「·」。
func _label_with_text(root: Node, text: String) -> Label:
	for node: Node in TreeProbe.find_all(root, "Label"):
		var label: Label = node
		if label.text == text:
			return label
	return null


## current_scene 是否已经不再是 from_id 那个实例 —— 也就是场景真的换过了。
## 闭包里只带 int：被换下去的场景会被引擎立刻回收，捕获了它下一帧就变成 capture was freed。
func _scene_changed_from(from_id: int) -> bool:
	return _tree.current_scene != null and _tree.current_scene.get_instance_id() != from_id


## 等到条件成立为止（最多 limit 帧），返回条件最终是否成立。
## 不写成死循环 + 计数：条件不成立时也要能带着上下文返回，而不是把整个套件挂死。
func _await_until(condition: Callable, limit: int) -> bool:
	for _frame: int in limit:
		if condition.call():
			return true
		await _tree.process_frame
	return condition.call()
