## test_project_config.gd
## 职责：核对 project.godot 的 Autoload 清单（S1-01）、06 §1 的基准分辨率，以及启动场景（S1-05）。
## 所属系统：tests
## 依赖：test_context
## 禁止：本文件不得修改 project.godot —— 只读核对。

extends RefCounted

const PROJECT_CONFIG_PATH: String = "res://project.godot"

## 03_ARCHITECTURE.md §3 只允许这些 Autoload；本批实现前五个，SaveService 属后续批次。
const EXPECTED_AUTOLOADS: Dictionary = {
	"EventBus": "res://scripts/core/event_bus.gd",
	"GameFlow": "res://scripts/core/game_flow.gd",
	"DataRegistry": "res://scripts/core/data_registry.gd",
	"RunState": "res://scripts/core/run_state.gd",
	"Settings": "res://scripts/core/settings_service.gd",
}

const BASE_VIEWPORT: Vector2i = Vector2i(320, 180)

## 启动场景固定为 BOOT（03 §1、S1-05）：数据校验通过后由 GameFlow 路由到 MAIN_MENU，
## 引擎自己只负责把 BOOT 落地，不做任何状态判断。
const MAIN_SCENE_PATH: String = "res://scenes/boot/boot.tscn"


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("project.godot · Autoload 清单")
	ctx.check(FileAccess.file_exists(PROJECT_CONFIG_PATH), "project.godot 应存在")
	for singleton_name: String in EXPECTED_AUTOLOADS:
		var expected_path: String = EXPECTED_AUTOLOADS[singleton_name]
		var setting: String = "autoload/%s" % singleton_name
		var actual: String = str(ProjectSettings.get_setting(setting, ""))
		ctx.equal(actual, "*%s" % expected_path, "%s 的注册路径" % singleton_name)

	ctx.begin_case("project.godot · 基准分辨率（06 §1）")
	ctx.equal(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)), BASE_VIEWPORT.x, "视口宽")
	ctx.equal(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)), BASE_VIEWPORT.y, "视口高")

	ctx.begin_case("project.godot · 启动场景（S1-05）")
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	ctx.equal(main_scene, MAIN_SCENE_PATH, "启动场景应为 BOOT")
	ctx.check(ResourceLoader.exists(MAIN_SCENE_PATH), "BOOT 场景文件应确实存在（配置指向不存在的场景会静默黑屏）")

	ctx.begin_case("project.godot · Autoload 实例确已就位")
	for singleton_name: String in EXPECTED_AUTOLOADS:
		var node: Node = tree.root.get_node_or_null(singleton_name)
		ctx.check(node != null, "%s 应作为 Autoload 节点存在于场景树" % singleton_name)
		if node != null:
			var expected_script: GDScript = load(EXPECTED_AUTOLOADS[singleton_name])
			ctx.equal(node.get_script(), expected_script, "%s 挂载的脚本" % singleton_name)
