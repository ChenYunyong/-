## scene_smoke.gd
## 职责：五个正式场景的装配冒烟 —— 真的入树、_ready() 真的跑过、关键控件真的建出来了。
## 所属系统：tests
## 依赖：TreeProbe, CardCatalog, ContractTheme, EditorLayout, IconButton, RunState, RewardModel
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
			ctx.equal(TreeProbe.count_of(screen, "Button"), 6,
				"主菜单：四个入口 + 语言开关 + 浮层关闭键")
			ctx.equal(TreeProbe.count_of(screen, "Panel"), 3,
				"主菜单三块面：整屏底 / 纸背 / 设置浮层（都不再是 ColorRect）")
			ctx.equal(TreeProbe.count_of(screen, "Label"), 5,
				"主菜单 5 行文字：Logo / 置灰原因 / 浮层标题 / 语言行 / 说明")
		"editor.tscn":
			ctx.equal(TreeProbe.count_of(screen, "BoardView"), 1, "编辑器有一块书页画布")
			ctx.equal(TreeProbe.count_of(screen, "CardChip"), CardCatalog.all().size(),
				"仓库里 %d 张卡一张不少" % CardCatalog.all().size())
			_check_editor_buttons(ctx, screen)
		"combat.tscn":
			ctx.equal(TreeProbe.count_of(screen, "Timer"), 1, "战斗屏有一个固定步长计时器")
			ctx.equal(TreeProbe.count_of(screen, "Label"), 11, "战斗屏 11 行读数（§2.3：头栏 6 + 底栏 5）")
			ctx.equal(TreeProbe.count_of(screen, "CombatView"), 1, "战斗屏有一块战场")
			ctx.equal(TreeProbe.count_of(screen, "CombatChain"), 1, "战斗屏有一条施法链")
			ctx.equal(TreeProbe.count_of(screen, "ColorRect"), 2, "两条读数条各只有一个填充块（槽走 Theme 变体）")
			ctx.equal(TreeProbe.count_of(screen, "Button"), 1, "进行中只有那颗结算键，且此刻不可见（C02）")
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


## 编辑器屏的按钮按**位置**分三组，各数各的。
##
## 分组而不是「总数 = 某常量」：三组会各自增长（头栏以后可能加键、书槽以后可能加分类），
## 而总数断言只会让人把另一个常量改一改糊过去；分组断言则要求新的那颗按钮真的落在它该在的
## 区里。三组之外不许有漏网的 —— 那条等式是分组的兜底，也正因为它，第 7 颗按钮（浮层的
## 收起键）当初没被静悄悄漏掉。
##
## PET-93 换了版式：强主动作从顶栏搬到了书槽右端（§2.1 EDITOR_PRIMARY），书槽因此是
## 「两端滚动入口 + 唯一的主按钮」三颗，而顶栏只剩三颗图标控件。
func _check_editor_buttons(ctx: RefCounted, screen: Node) -> void:
	var all: Array[Button] = []
	var top: Array[Button] = []
	var tray: Array[Button] = []
	var popover: Array[Button] = []
	for node: Node in TreeProbe.find_all(screen, "Button"):
		var button: Button = node as Button
		all.append(button)
		var rect: Rect2 = button.get_global_rect()
		if EditorLayout.top_bar().encloses(rect):
			top.append(button)
		elif EditorLayout.tray().encloses(rect):
			tray.append(button)
		elif EditorLayout.popover().encloses(rect):
			popover.append(button)
	ctx.equal(top.size(), EditorLayout.TOP_BUTTONS.size(),
		"顶栏 %d 个按钮" % EditorLayout.TOP_BUTTONS.size())
	ctx.equal(tray.size(), 3, "书槽 3 个按钮：两端滚动入口 + 主按钮（数到 %d 个）" % tray.size())
	ctx.equal(popover.size(), 1, "详情浮层 1 个收起键（数到 %d 个）" % popover.size())
	ctx.equal(top.size() + tray.size() + popover.size(), all.size(),
		"每颗按钮都落在头栏 / 书槽 / 浮层里（三组之外没有漏网的，共 %d 颗）" % all.size())
	_check_editor_roles(ctx, all)
	_check_editor_rects(ctx, all)


## G02 的实机版：§2.1 的每一条按钮 rect 上都必须有**真控件**，误差 ≤1 逻辑像素。
##
## 为什么单独立这一条：常量对常量在 test_layout 里已经比过一遍了，而「控件的真实 rect」是
## 另一回事 —— Button 的最小尺寸 = 内容 + 内边距，主题的内边距一旦偏大，引擎就会把控件顶得
## 比表列值宽。那时常量表可以全绿，画面上那颗按钮已经压过了邻居
## （书槽箭头与浮层收起键的 24 宽 → 28 就是这么发生的）。
func _check_editor_rects(ctx: RefCounted, buttons: Array[Button]) -> void:
	var declared: Array = []
	var top_rects: Array[Rect2] = EditorLayout.top_button_rects()
	for index: int in top_rects.size():
		declared.append(["头栏「%s」" % EditorLayout.TOP_BUTTONS[index], top_rects[index]])
	declared.append(["书槽左入口", EditorLayout.tray_arrow_rect(-1.0)])
	declared.append(["书槽右入口", EditorLayout.tray_arrow_rect(1.0)])
	declared.append(["书槽主按钮", EditorLayout.primary_rect()])
	declared.append(["浮层收起键", EditorLayout.detail_close_rect()])
	ctx.equal(declared.size(), buttons.size(), "表列的按钮 rect 数与屏上按钮数相等（%d / %d）"
		% [declared.size(), buttons.size()])
	for item: Array in declared:
		var wanted: Rect2 = item[1]
		var hits: int = 0
		for button: Button in buttons:
			if _within(button.get_global_rect(), wanted, 1.0):
				hits += 1
		# 打回时把屏上真实的 rect 一并报出来 —— 只说「数到 0」看不出那颗控件跑到哪去了。
		ctx.equal(hits, 1, "%s：表列 %s 上有且只有一个真控件（数到 %d）%s"
			% [item[0], wanted, hits, "" if hits == 1 else "；屏上实为 %s" % _rect_list(buttons)])


## 屏上按钮的真实 rect，一行报全 —— G02 打回时要能一眼看出控件跑到哪去了。
static func _rect_list(buttons: Array[Button]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for button: Button in buttons:
		parts.append(str(button.get_global_rect()))
	return ", ".join(parts)


## 两个矩形四边都在容差内 —— G02 的原话是「误差 ≤1 逻辑像素」。
static func _within(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return absf(a.position.x - b.position.x) <= tolerance \
		and absf(a.position.y - b.position.y) <= tolerance \
		and absf(a.size.x - b.size.x) <= tolerance \
		and absf(a.size.y - b.size.y) <= tolerance


## 主次必须**在树上**读得出来 —— 这是在跑起来的界面里验，不是读常量表。
##
## PET-87 §3 报的是「四个同级大按钮读不出主次」。§2.1 把主次落成两半，缺一半就退回原样：
##   1. 全屏**只有一颗**带文字的金底按钮（ButtonPagePrimary），它落在书槽右端的契约矩形上；
##   2. 其余全是无文字的图标控件 —— 于是它们**必须**自带 tooltip 与无障碍名，
##      否则主次是分开了，代价是用户认不出那颗按钮是干什么的。
func _check_editor_roles(ctx: RefCounted, buttons: Array[Button]) -> void:
	var primaries: Array[Button] = []
	for button: Button in buttons:
		if button.theme_type_variation == ContractTheme.TYPE_BUTTON_PAGE_PRIMARY:
			primaries.append(button)
			continue
		_check_icon_button(ctx, button)
	ctx.equal(primaries.size(), 1, "全屏有且只有一个强主动作（数到 %d 个）" % primaries.size())
	if not primaries.is_empty():
		_check_primary(ctx, primaries[0])


## 无文字的图标控件：顶栏三颗与书槽两端入口都是这一档。
func _check_icon_button(ctx: RefCounted, button: Button) -> void:
	ctx.equal(button.theme_type_variation, ContractTheme.TYPE_BUTTON_PAGE_ICON,
		"图标控件走 ButtonPageIcon 变体")
	ctx.check(button.text.strip_edges().is_empty(), "图标控件不含文字（有文字就又是同级大按钮）")
	ctx.check(not button.tooltip_text.strip_edges().is_empty(),
		"无文字的图标控件必须靠 tooltip 自报家门")
	ctx.check(not button.accessibility_name.strip_edges().is_empty(),
		"无文字的图标控件必须有无障碍名（否则读屏念不出来）")
	ctx.check(button is IconButton, "图标控件是 IconButton（图标画在子控件上，压在按钮底之上）")


## 唯一的主按钮：文案是契约那一句，矩形是 §2.1 给的 EDITOR_PRIMARY，且比图标控件宽。
func _check_primary(ctx: RefCounted, primary: Button) -> void:
	ctx.check(not primary.text.strip_edges().is_empty(),
		"主动作「%s」带文字（强按钮是靠文字读的）" % primary.text)
	ctx.equal(primary.text, TranslationServer.translate(EditorLayout.PRIMARY_KEY),
		"主动作的文案就是契约里的那一句")
	var wanted: Rect2 = EditorLayout.primary_rect()
	var rect: Rect2 = primary.get_global_rect()
	ctx.near(rect.position.x, wanted.position.x, "主动作落在 §2.1 的矩形上（左缘）")
	ctx.near(rect.position.y, wanted.position.y, "主动作落在 §2.1 的矩形上（上缘）")
	ctx.near(rect.size.x, wanted.size.x, "主动作矩形 = §2.1 的 EDITOR_PRIMARY")
	ctx.check(rect.size.x > EditorLayout.HEADER_BUTTON_SIZE.x,
		"主动作 %s 比图标控件 %s 宽 —— 才是主次关系" % [rect.size.x, EditorLayout.HEADER_BUTTON_SIZE])


func _instantiate(ctx: RefCounted, path: String) -> Node:
	var packed: PackedScene = load(path)
	if not ctx.check(packed != null, "%s 可加载" % path.get_file()):
		return null
	var node: Node = packed.instantiate()
	if not ctx.check(node != null, "%s 可实例化" % path.get_file()):
		return null
	return node
