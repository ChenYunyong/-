## scene_smoke.gd
## 职责：四个正式场景的装配冒烟 —— 真的入树、_ready() 真的跑过、关键控件真的建出来了。
## 所属系统：tests
## 依赖：TreeProbe, CardCatalog, EditorLayout, ArcaneTheme, IconButton
## 禁止：本文件不得把 boot.tscn 挂进树 —— 它的 _ready() 会自检、开局并请求切场景，
##       那是 loop_smoke 的职责（loop_smoke 排在最后，它换场景不会干扰别的用例）。
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
]
const BOOT_SCENE: String = "res://scenes/boot.tscn"


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("scene_smoke")
	var autoloads: int = tree.root.get_child_count()
	_check_boot(ctx, tree)
	for path: String in SCREEN_SCENES:
		await _smoke_screen(ctx, tree, path)
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
			ctx.equal(TreeProbe.count_of(screen, "CardChip"), 3, "奖励屏三选一（三个卡位）")
			ctx.equal(TreeProbe.count_of(screen, "Button"), 4, "三个「选择」+ 一个跳过")
		"map.tscn":
			ctx.equal(TreeProbe.count_of(screen, "MapView"), 1, "路线图屏有一张图")
			ctx.check(TreeProbe.count_of(screen, "Button") >= 1, "路线图屏有返回按钮")


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
