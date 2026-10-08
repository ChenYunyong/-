## scene_smoke.gd
## 职责：五个正式场景的装配冒烟 —— 真的入树、_ready() 真的跑过、关键控件真的建出来了。
## 所属系统：tests
## 依赖：TreeProbe, CardCatalog, EditorLayout, ArcaneTheme, IconButton, RunState, RewardModel
## 禁止：本文件不得把 boot.tscn 挂进树 —— 它的 _ready() 会自检、开局并请求切场景，
##       那是 loop_smoke 的职责（loop_smoke 排在最后，它换场景不会干扰别的用例）。
##       唯一一处会动 RunState 的是奖励池拿空的那条（见 _check_reward_fallback），
##       它按快照还原书页，拿过的记录留在本局里 —— 后面的用例都会先 start_run() 把它清掉。
##
## 为什么值得入树：`_ready()` 不跑，屏幕就只是一张空 Control —— 场景文件存在、
## 脚本编译通过，都不能证明界面上真的有东西。这里的断言都是「树里数得出来的」。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCREEN_SCENES: PackedStringArray = [
	"res://scenes/main_menu.tscn",
	"res://scenes/editor.tscn",
	"res://scenes/combat.tscn",
	"res://scenes/reward.tscn",
	"res://scenes/map.tscn",
	"res://scenes/result.tscn",
]
const BOOT_SCENE: String = "res://scenes/boot.tscn"

## 奖励屏拿空时的两句文案 key。按译文找 —— 界面上的字一律经 tr() 出来。
const KEY_EMPTY_TITLE: String = "没有可拿的奖励"
const KEY_EMPTY_BODY: String = "本局的卡与加成都已拿满"
const KEY_CONTINUE: String = "继续"


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("scene_smoke")
	var autoloads: int = tree.root.get_child_count()
	_check_boot(ctx, tree)
	for path: String in SCREEN_SCENES:
		await _smoke_screen(ctx, tree, path)
	await _check_reward_fallback(ctx, tree)
	ctx.equal(tree.root.get_child_count(), autoloads, "冒烟结束后树里只剩 Autoload，没有残留节点")


## boot 是主场景：只验它的自检结论，不入树（入树会真的把游戏切到编辑器）。
func _check_boot(ctx: RefCounted, tree: SceneTree) -> void:
	var boot: Node = _instantiate(ctx, BOOT_SCENE)
	if boot == null:
		return
	ctx.check(boot is Control, "boot 根节点是 Control")
	ctx.check(boot.has_method(&"_self_check"), "boot 有启动自检")
	if boot.has_method(&"_self_check"):
		var problem: String = boot._self_check()
		ctx.equal(problem, "", "启动自检通过（palette / theme / 中文字形三项都过）")
	boot.free()


func _smoke_screen(ctx: RefCounted, tree: SceneTree, path: String) -> void:
	var screen: Node = _instantiate(ctx, path)
	if screen == null:
		return
	var file: String = path.get_file()
	ctx.check(screen is Control, "%s 根节点是 Control" % file)
	ctx.check(screen.theme != null, "%s 挂了主题（像素风靠它统一）" % file)
	ctx.check(screen.theme.default_font != null, "%s 的主题带字体（否则中文全空）" % file)

	# 手工定位的屏幕在 _ready() 里建控件，入树前子节点数应为 0。
	ctx.equal(screen.get_child_count(), 0, "%s 的控件全靠代码建（场景文件里是空的）" % file)
	tree.root.add_child(screen)
	ctx.check(screen.get_child_count() > 0, "%s 的 _ready() 建出了 %d 个控件" % [file, screen.get_child_count()])
	_check_contents(ctx, file, screen)

	screen.queue_free()
	await tree.process_frame


func _check_contents(ctx: RefCounted, file: String, screen: Node) -> void:
	match file:
		"main_menu.tscn":
			ctx.equal(TreeProbe.count_of(screen, "Button"), 5,
				"主菜单：四个入口 + 设置面板里那颗语言开关")
			ctx.check(TreeProbe.count_of(screen, "ColorRect") >= 2,
				"主菜单有整屏底色与入口板")
			ctx.check(TreeProbe.count_of(screen, "Label") >= 3,
				"主菜单有 %d 行文字（标题 / 置灰说明 / 设置行）" % TreeProbe.count_of(screen, "Label"))
		"editor.tscn":
			ctx.equal(TreeProbe.count_of(screen, "BoardView"), 1, "编辑器有一块书页画布")
			ctx.equal(TreeProbe.count_of(screen, "CardChip"), CardCatalog.all().size(),
				"仓库里 %d 张卡一张不少" % CardCatalog.all().size())
			_check_editor_buttons(ctx, screen)
		"combat.tscn":
			ctx.equal(TreeProbe.count_of(screen, "Timer"), 1, "战斗屏有一个固定步长计时器")
			ctx.check(TreeProbe.count_of(screen, "Label") >= 8,
				"战斗屏有 %d 行状态文字" % TreeProbe.count_of(screen, "Label"))
			ctx.check(TreeProbe.count_of(screen, "ColorRect") >= 1, "战斗屏有血条色块")
		"reward.tscn":
			_check_reward(ctx, screen)
		"map.tscn":
			ctx.equal(TreeProbe.count_of(screen, "MapView"), 1, "路线图屏有一张图")
			ctx.check(TreeProbe.count_of(screen, "Button") >= 1, "路线图屏有返回按钮")
		"result.tscn":
			ctx.equal(TreeProbe.count_of(screen, "Button"), 2, "结算屏两条出口：回到主菜单 / 再来一局")
			ctx.check(TreeProbe.count_of(screen, "Label") >= 4,
				"结算屏有 %d 行文字（结局 / 到过几层 / 账目标题 / 账目）"
					% TreeProbe.count_of(screen, "Label"))
			ctx.check(TreeProbe.count_of(screen, "Panel") >= 1, "结算屏的账目落在一块面板上")


## 奖励屏的选项是**掷出来的**（本局种子 + 波次），所以这里不能写死「三张卡四个按钮」——
## 断的是「界面画出来的数量 = 本次真的抽到的数量」，掷出什么就画什么。
func _check_reward(ctx: RefCounted, screen: Node) -> void:
	var options: Array[Dictionary] = RunState.roll_rewards()
	ctx.check(options.size() > 0, "这一次确实有可选的奖励（否则下面两条是空断言）")
	var cards: int = 0
	for option: Dictionary in options:
		if RewardModel.is_card(option):
			cards += 1
	ctx.equal(TreeProbe.count_of(screen, "CardChip"), cards, "奖励屏的卡位 = 本次抽到的卡数")
	ctx.equal(TreeProbe.count_of(screen, "Button"), options.size() + 1,
		"每个选项一颗「选择」+ 一颗收尾键（跳过 / 继续）")


## 池子被拿空时的兜底：给一句说明 + 一颗「继续」，**不是一张空白屏**。
## 「拿满」是本局真实可达的处境（17 张卡 + 2 个加成），不是人为构造的边界 ——
## 所以这里真的一条条拿过去，而不是把某个内部标志位翻一下。
func _check_reward_fallback(ctx: RefCounted, tree: SceneTree) -> void:
	var run: Node = tree.root.get_node_or_null(^"RunState")
	if not ctx.check(run != null, "RunState 单例在，可构造「拿满」的局面"):
		return
	var before: Dictionary = run.board().snapshot()
	run.take_reward({"kind": RewardModel.Kind.POWER}, EditorLayout.CANVAS_VIEW_SIZE)
	run.take_reward({"kind": RewardModel.Kind.MANA}, EditorLayout.CANVAS_VIEW_SIZE)
	var taken: int = 0
	for id: String in RewardModel.pool_ids():
		if run.take_reward({"kind": RewardModel.Kind.CARD, "card_id": StringName(id)},
				EditorLayout.CANVAS_VIEW_SIZE):
			taken += 1
	ctx.equal(taken, RewardModel.pool_ids().size(), "池子里的卡一张张都拿得下来")
	ctx.equal(run.roll_rewards().size(), 0, "全部拿过之后抽不出任何选项")

	var packed: PackedScene = load("res://scenes/reward.tscn")
	var screen: Node = packed.instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	ctx.equal(TreeProbe.count_of(screen, "CardChip"), 0, "没有可选项时不画空卡位")
	ctx.equal(TreeProbe.count_of(screen, "Button"), 1, "只有一颗「继续」，没有可跳过的奖励")
	ctx.check(TreeProbe.count_of(screen, "Panel") >= 1, "兜底那句说明落在一块面板上，不是空白屏")
	ctx.check(_has_label(screen, KEY_EMPTY_TITLE), "写明了「%s」" % KEY_EMPTY_TITLE)
	ctx.check(_has_label(screen, KEY_EMPTY_BODY), "写明了「%s」" % KEY_EMPTY_BODY)
	var buttons: Array[Node] = TreeProbe.find_all(screen, "Button")
	if buttons.size() == 1:
		ctx.equal((buttons[0] as Button).text, TranslationServer.translate(KEY_CONTINUE),
			"那颗键是「%s」" % KEY_CONTINUE)

	screen.queue_free()
	await tree.process_frame
	run.board().restore(before)
	ctx.equal(run.board().cards().size(), before["cards"].size(), "书页按快照还原（那 17 张卡不进后面的用例）")


func _has_label(root: Node, text_key: String) -> bool:
	var wanted: String = TranslationServer.translate(text_key)
	for node: Node in TreeProbe.find_all(root, "Label"):
		if (node as Label).text == wanted:
			return true
	return false


## 编辑器屏的按钮分两组，各数各的。
##
## 原来这里数的是「屏幕上所有 Button」＝ 顶栏数 —— PET-87 §3 给仓库两端加了两个滚动
## 入口之后这个等式就不成立了。改按**位置**分组的理由是：两组按钮会各自增长
## （顶栏以后可能加键、仓库以后可能加分类），而「总数 = 某一个常量」只会让人把
## 另一个常量改一改糊过去；分组断言则要求新的那颗按钮真的落在它该在的区里。
func _check_editor_buttons(ctx: RefCounted, screen: Node) -> void:
	var top: Array[Button] = []
	var tray: int = 0
	for node: Node in TreeProbe.find_all(screen, "Button"):
		var rect: Rect2 = (node as Control).get_global_rect()
		if EditorLayout.top_bar().encloses(rect):
			top.append(node as Button)
		elif EditorLayout.tray().encloses(rect):
			tray += 1
	ctx.equal(top.size(), EditorLayout.TOP_BUTTONS.size(),
		"顶栏 %d 个按钮" % EditorLayout.TOP_BUTTONS.size())
	ctx.equal(tray, 2, "仓库两端 2 个滚动入口（只靠滚轮的话触屏没法滚）")
	_check_top_bar_roles(ctx, top)


## 顶栏的主次必须**在树上**读得出来 —— 这是在跑起来的界面里验，不是读常量表。
##
## PET-87 §3 报的是「四个同级大按钮读不出主次」。改法有两半，缺一半就退回原样：
##   1. 只有「开始战斗」是强主动作（金色 ButtonPrimary），**有且只有一个**；
##   2. 另外三个退成无文字的图标控件 —— 于是它们**必须**自带 tooltip 与无障碍名，
##      否则主次是分开了，代价是用户认不出那颗按钮是干什么的。
func _check_top_bar_roles(ctx: RefCounted, top: Array[Button]) -> void:
	var primary: int = 0
	for button: Button in top:
		if button.theme_type_variation == ArcaneTheme.TYPE_BUTTON_PRIMARY:
			primary += 1
			ctx.check(not button.text.strip_edges().is_empty(),
				"主动作「%s」带文字（强按钮是靠文字读的）" % button.text)
			continue
		ctx.equal(button.theme_type_variation, ArcaneTheme.TYPE_BUTTON_SECONDARY,
			"次级按钮走次级变体")
		ctx.check(button.text.strip_edges().is_empty(), "次级按钮不含文字（有文字就又是同级大按钮）")
		ctx.check(not button.tooltip_text.strip_edges().is_empty(),
			"无文字的图标控件必须靠 tooltip 自报家门")
		ctx.check(not button.accessibility_name.strip_edges().is_empty(),
			"无文字的图标控件必须有无障碍名（否则读屏念不出来）")
		ctx.check(button is IconButton, "次级按钮是 IconButton（图标画在子控件上，压在按钮底之上）")
	ctx.equal(primary, 1, "顶栏有且只有一个强主动作（数到 %d 个）" % primary)


func _instantiate(ctx: RefCounted, path: String) -> Node:
	var packed: PackedScene = load(path)
	if not ctx.check(packed != null, "%s 可加载" % path.get_file()):
		return null
	var node: Node = packed.instantiate()
	if not ctx.check(node != null, "%s 可实例化" % path.get_file()):
		return null
	return node
