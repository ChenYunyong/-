## test_project_config.gd
## 职责：校验 project.godot 的关键设置与场景路由表 —— 基准分辨率、整数倍缩放、Autoload、语言表。
## 所属系统：tests
## 依赖：GameFlow（经 /root 取）
## 禁止：本文件不得修改任何设置，只读。

extends RefCounted

## DSH 2026-10-06 裁定：画布 960×540，窗口 1920×1080，整数 2×。
const VIEWPORT_WIDTH: int = 960
const VIEWPORT_HEIGHT: int = 540
const WINDOW_WIDTH: int = 1920
const WINDOW_HEIGHT: int = 1080

const EXPECTED_AUTOLOADS: PackedStringArray = ["EventBus", "GameFlow", "RunState", "Settings"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_project_config")
	_check_resolution(ctx)
	_check_scaling(ctx)
	_check_autoloads(ctx, tree)
	_check_routes(ctx, tree)


func _check_resolution(ctx: RefCounted) -> void:
	ctx.equal(ProjectSettings.get_setting("display/window/size/viewport_width"), VIEWPORT_WIDTH, "画布宽")
	ctx.equal(ProjectSettings.get_setting("display/window/size/viewport_height"), VIEWPORT_HEIGHT, "画布高")
	ctx.equal(ProjectSettings.get_setting("display/window/size/window_width_override"), WINDOW_WIDTH, "窗口宽")
	ctx.equal(ProjectSettings.get_setting("display/window/size/window_height_override"), WINDOW_HEIGHT, "窗口高")


## 整数倍缩放：窗口必须是画布的整数倍，否则像素会被重采样成糊的。
func _check_scaling(ctx: RefCounted) -> void:
	ctx.equal(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport", "拉伸模式")
	ctx.equal(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep", "纵横比")
	ctx.equal(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer", "整数倍缩放")
	ctx.equal(WINDOW_WIDTH % VIEWPORT_WIDTH, 0, "窗口宽是画布宽的整数倍")
	ctx.equal(WINDOW_HEIGHT % VIEWPORT_HEIGHT, 0, "窗口高是画布高的整数倍")
	ctx.equal(WINDOW_WIDTH / VIEWPORT_WIDTH, WINDOW_HEIGHT / VIEWPORT_HEIGHT, "横纵缩放倍数一致")
	# 像素风：最近邻过滤，不许出现双线性插值。
	ctx.equal(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"),
		0, "默认纹理过滤 = 最近邻")
	ctx.equal(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility",
		"渲染后端 = GL Compatibility（Web 导出要求）")


func _check_autoloads(ctx: RefCounted, tree: SceneTree) -> void:
	for name: String in EXPECTED_AUTOLOADS:
		ctx.check(ProjectSettings.has_setting("autoload/%s" % name), "Autoload %s 已登记" % name)
		ctx.check(tree.root.get_node_or_null(NodePath(name)) != null, "Autoload %s 已入树" % name)
	ctx.check(tree.root.get_node_or_null(^"GameFlow") != null
		and tree.root.get_node_or_null(^"EventBus") != null, "核心单例可经 /root 取到")


## 主场景与四条状态路由必须真实存在 —— 少一个文件，那条路径就会「走到一半掉下去」。
func _check_routes(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.equal(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/boot.tscn", "主场景")
	var flow: Node = tree.root.get_node_or_null(^"GameFlow")
	if not ctx.check(flow != null, "GameFlow 存在，可查路由表"):
		return
	for state: int in [1, 2, 3, 4]:
		var path: String = flow.get_scene_path_for(state)
		ctx.check(not path.is_empty(), "状态 %d 登记了场景路径" % state)
		ctx.check(ResourceLoader.exists(path), "场景文件存在：%s" % path)
