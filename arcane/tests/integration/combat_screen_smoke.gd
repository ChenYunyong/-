## combat_screen_smoke.gd
## 职责：战斗屏**装配之后**的控件账 —— §2.3 的每一条 rect 上都真的有控件，角色也对。
## 所属系统：tests
## 依赖：TreeProbe, CombatLayout, CombatView, CombatChain, ContractTheme, ContractScreenTheme
## 禁止：本文件不得按任何按钮，也不得空转计时器 —— 「结算」会把这一局真的收尾。
##
## 为什么单独立一条而不是写进 scene_smoke：那个文件已经顶到源码的 300 行上限。
## 而「常量对常量」在 test_combat_layout 里比过之后还剩一件事没量 —— **控件的真实 rect**。
## Button 的最小尺寸 = 文字 + 内边距，主题的内边距一旦偏大，引擎会把控件顶得比表列值宽：
## 那时常量表全绿，而底栏上结果行与按钮已经叠在一起了（编辑器那边 24 → 28 就是这么发生的）。
##
## 另外两条只有入树才量得到：
##   战场必须是屏的**直接子节点**（tools/capture_combat.gd 按这个层级取它）；
##   进行中**没有**可点的动作按钮（C02 的原话），那颗结算键只在核心被摧毁后出现。
##
## 入树才量得到 rect：position / size 要等 _ready() 摆完，get_global_rect() 才有意义。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCREEN_PATH: String = "res://scenes/combat.tscn"
## G02 的原话：误差 ≤1 逻辑像素。
const TOLERANCE: float = 1.0


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("combat_screen_smoke")
	var packed: PackedScene = load(SCREEN_PATH)
	if not ctx.check(packed != null, "%s 可加载" % SCREEN_PATH):
		return
	var screen: Control = packed.instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	_check_field(ctx, screen)
	_check_chain(ctx, screen)
	_check_panels(ctx, screen)
	_check_labels(ctx, screen)
	_check_bars(ctx, screen)
	_check_actions(ctx, screen)
	screen.queue_free()
	await tree.process_frame
	# queue_free 之后 screen 已经是**悬空引用**，再点它的方法就是拿已释放的实例当活人用。
	# 顺序不能反：is_instance_valid 先判，or 的短路才护得住后面那一下。
	var gone: bool = not is_instance_valid(screen) or not screen.is_inside_tree()
	ctx.check(tree.root.get_child_count() > 0 and gone, "用完就自己撤了，树里不留这一屏")


## 战场：整块落在 FIELD 上，而且是屏的**直接子节点** —— 采集工具按这个层级找它。
func _check_field(ctx: RefCounted, screen: Control) -> void:
	var views: Array[Node] = TreeProbe.find_all(screen, "CombatView")
	if not ctx.check(views.size() == 1, "屏里有一块战场（数到 %d）" % views.size()):
		return
	var field: CombatView = views[0] as CombatView
	ctx.check(field != null, "那块战场就是 CombatView")
	ctx.check(field.get_parent() == screen, "战场是屏的直接子节点（采集工具按这一层取它）")
	ctx.check(_within(field.get_global_rect(), CombatLayout.FIELD, TOLERANCE),
		"战场铺满 COMBAT_FIELD 896×280（实为 %s）" % field.get_global_rect())
	ctx.equal(field.mouse_filter, Control.MOUSE_FILTER_IGNORE, "战场不吃指针事件")


## 卡链：一个控件，落在 ACTIVE_CHAIN 上，且它自己不处理输入（一条读数，不是交互件）。
func _check_chain(ctx: RefCounted, screen: Control) -> void:
	var chains: Array[Node] = TreeProbe.find_all(screen, "CombatChain")
	if not ctx.check(chains.size() == 1, "屏里有一条施法链（数到 %d）" % chains.size()):
		return
	var chain: CombatChain = chains[0] as CombatChain
	ctx.check(chain != null, "那条链就是 CombatChain")
	ctx.check(_within(Rect2(chain.position, chain.size), CombatLayout.ACTIVE_CHAIN, TOLERANCE),
		"卡链落在 §2.3 的 %s 上（实为 %s）" % [CombatLayout.ACTIVE_CHAIN, Rect2(chain.position, chain.size)])
	ctx.equal(chain.mouse_filter, Control.MOUSE_FILTER_IGNORE, "卡链不吃指针事件")
	ctx.equal(chain.window().y <= CombatLayout.CHAIN_SLOTS, true,
		"这一帧最多画 %d 张卡（C02）" % CombatLayout.CHAIN_SLOTS)


## 面板数：暗底 / 头栏 / 纸框 / 战场底 / 底栏 / 当前读数 / 队列加成 7 块，外加两条读数条的槽 = 9。
## 多一块就是谁又铺了一层 —— 而多铺的那层在画面上往往是「颜色差一点点」，肉眼查不出来。
func _check_panels(ctx: RefCounted, screen: Control) -> void:
	ctx.equal(TreeProbe.count_of(screen, "Panel"), 9, "九块面板：底 / 头栏 / 纸框 / 战场 / 底栏 / 读数 / 加成 + 两条槽")
	ctx.equal(TreeProbe.count_of(screen, "CombatView"), 1, "战场只有一个")
	ctx.equal(TreeProbe.count_of(screen, "CombatChain"), 1, "卡链只有一条")


## 七行读数各就各位：头栏四组 + 底栏当前读数两行 + 链标题 + 摘要 + 结果行 = 11 行。
## 其中魔力与敌群是**两个** Label 共用一个 rect（标签退后、数值在前）—— 这正是 §2.3 的
## 「标签与真实数值分清」，故那一格上数到 2 才是对的。
func _check_labels(ctx: RefCounted, screen: Control) -> void:
	ctx.equal(TreeProbe.count_of(screen, "Label"), 11, "十一条 Label（头栏 6 + 底栏 5）")
	for row: Array in [["屏标题", CombatLayout.TITLE_RECT, 1], ["魔力", CombatLayout.MANA_LABEL_RECT, 2],
			["波次", CombatLayout.WAVE_RECT, 1], ["敌群", CombatLayout.ENEMY_LABEL_RECT, 2],
			["当前施法名", CombatLayout.ACTIVE_NAME_RECT, 1],
			["当前施法数值", CombatLayout.ACTIVE_VALUE_RECT, 1],
			["链标题", CombatLayout.QUEUE_TITLE_RECT, 1], ["加成摘要", CombatLayout.QUEUE_SUMMARY_RECT, 1],
			["结果行", CombatLayout.RESULT_RECT, 1]]:
		var wanted: Rect2 = row[1]
		var found: Array[Label] = _labels_at(screen, wanted.position, row[2])
		ctx.equal(found.size(), row[2], "%s 那一格上有 %d 行字（数到 %d）" % [row[0], row[2], found.size()])
		for label: Label in found:
			ctx.check(_within(Rect2(label.position, label.size), wanted, TOLERANCE),
				"%s 的框就是表列值 %s（实为 %s）" % [row[0], wanted, Rect2(label.position, label.size)])


## 两条读数条：各一个填充块，内缩 1、内高 10，且不越出条槽。
## 只有填充是 ColorRect —— 槽要有圆角与那条 1px 边，那一层走 Theme 变体。
func _check_bars(ctx: RefCounted, screen: Control) -> void:
	var fills: Array[Node] = TreeProbe.find_all(screen, "ColorRect")
	ctx.equal(fills.size(), 2, "两条读数条各一个填充块（数到 %d）" % fills.size())
	for pair: Array in [["血条", CombatLayout.ENEMY_HP_TRACK], ["法力条", CombatLayout.MANA_TRACK]]:
		var track: Rect2 = pair[1]
		var hits: int = 0
		for node: Node in fills:
			var block: ColorRect = node as ColorRect
			var rect: Rect2 = Rect2(block.position, block.size)
			if not _inside(rect, track):
				continue
			hits += 1
			ctx.near(rect.size.y, CombatLayout.BAR_INNER_HEIGHT, "%s 的内高就是 10" % pair[0])
			ctx.near(rect.position.y, track.position.y + CombatLayout.BAR_INSET, "%s 的填充内缩 1" % pair[0])
		ctx.equal(hits, 1, "%s 上有一个填充块（数到 %d）" % [pair[0], hits])


## 进行中**没有**可点的动作按钮（C02）：那颗结算键此刻不可见，而且它是唯一的一颗。
func _check_actions(ctx: RefCounted, screen: Control) -> void:
	var buttons: Array[Node] = TreeProbe.find_all(screen, "Button")
	if not ctx.check(buttons.size() == 1, "全屏只有一颗按钮（数到 %d）%s"
			% [buttons.size(), _rect_list(buttons)]):
		return
	var done: Button = buttons[0] as Button
	ctx.equal(done.text, TranslationServer.translate("结算"), "那颗键是「结算」")
	ctx.check(not done.visible, "进行中它不可见 —— 屏幕上没有动作按钮（C02）")
	ctx.check(_within(Rect2(done.position, done.size), CombatLayout.DONE_BUTTON, TOLERANCE),
		"结算键落在 §2.3 的 %s 上（实为 %s）" % [CombatLayout.DONE_BUTTON, Rect2(done.position, done.size)])
	ctx.equal(done.theme_type_variation, ContractTheme.TYPE_BUTTON_PAGE_PRIMARY,
		"结算键走主按钮那一支（实际 %s）" % done.theme_type_variation)
	ctx.check(CombatLayout.SAFE_AREA.encloses(Rect2(done.position, done.size)),
		"结算键的可交互包络不出安全区（G03）")


## 落在某一格上的全部 Label。魔力与敌群那一格上各有两个（标签 + 数值）。
func _labels_at(root: Node, position: Vector2, expected: int) -> Array[Label]:
	var found: Array[Label] = []
	for node: Node in TreeProbe.find_all(root, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(position):
			found.append(label)
	return found


## 屏上控件的真实 rect 一行报全 —— 打回时要能一眼看出控件跑到哪去了。
static func _rect_list(nodes: Array[Node]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node: Node in nodes:
		var control: Control = node as Control
		parts.append(str(Rect2(control.position, control.size)))
	return ", ".join(parts)


## 一个矩形整份落在另一个里（含容差）。
static func _inside(a: Rect2, b: Rect2) -> bool:
	return a.position.x >= b.position.x - 1.0 and a.position.y >= b.position.y - 1.0 \
		and a.end.x <= b.end.x + 1.0 and a.end.y <= b.end.y + 1.0


## 两个矩形四边都在容差内 —— G02 的原话是「误差 ≤1 逻辑像素」。
static func _within(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return absf(a.position.x - b.position.x) <= tolerance \
		and absf(a.position.y - b.position.y) <= tolerance \
		and absf(a.size.x - b.size.x) <= tolerance \
		and absf(a.size.y - b.size.y) <= tolerance
