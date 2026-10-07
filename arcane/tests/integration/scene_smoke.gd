## scene_smoke.gd
## 职责：四个正式场景的装配冒烟 —— 真的入树、_ready() 真的跑过、关键控件真的建出来了。
## 所属系统：tests
## 依赖：TreeProbe, CardCatalog, EditorLayout
## 禁止：本文件不得把 boot.tscn 挂进树 —— 它的 _ready() 会自检、开局并请求切场景，
##       那是 loop_smoke 的职责（loop_smoke 排在最后，它换场景不会干扰别的用例）。
##
## 为什么值得入树：`_ready()` 不跑，屏幕就只是一张空 Control —— 场景文件存在、
## 脚本编译通过，都不能证明界面上真的有东西。这里的断言都是「树里数得出来的」。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCREEN_SCENES: PackedStringArray = [
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
		"editor.tscn":
			ctx.equal(TreeProbe.count_of(screen, "BoardView"), 1, "编辑器有一块书页画布")
			ctx.equal(TreeProbe.count_of(screen, "CardChip"), CardCatalog.all().size(),
				"仓库里 %d 张卡一张不少" % CardCatalog.all().size())
			ctx.equal(TreeProbe.count_of(screen, "Button"), EditorLayout.TOP_BUTTONS.size(),
				"顶栏 %d 个按钮" % EditorLayout.TOP_BUTTONS.size())
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


func _instantiate(ctx: RefCounted, path: String) -> Node:
	var packed: PackedScene = load(path)
	if not ctx.check(packed != null, "%s 可加载" % path.get_file()):
		return null
	var node: Node = packed.instantiate()
	if not ctx.check(node != null, "%s 可实例化" % path.get_file()):
		return null
	return node
