## test_settings.gd
## 职责：Settings 的默认值、范围校验、非法输入降级与变更信号。
## 所属系统：tests
## 依赖：test_context, scripts/core/settings_service.gd
## 禁止：本文件不得改动用户的显示/音频设置 —— 全部在独立实例上进行，不碰真 Autoload。

extends RefCounted

const SETTINGS_PATH: String = "res://scripts/core/settings_service.gd"


func run(ctx: RefCounted, tree: SceneTree) -> void:
	var script: GDScript = load(SETTINGS_PATH)
	if not ctx.check(script != null, "settings_service.gd 应能加载"):
		return
	_run_default_checks(ctx, tree, script)
	_run_volume_checks(ctx, tree, script)
	_run_locale_checks(ctx, tree, script)
	_run_resolution_checks(ctx, tree, script)


func _run_default_checks(ctx: RefCounted, tree: SceneTree, script: GDScript) -> void:
	ctx.begin_case("Settings · 默认值来自 project.godot")
	var settings: Node = _spawn(tree, script)
	var expected: Vector2i = Vector2i(
		int(ProjectSettings.get_setting("display/window/size/window_width_override", 0)),
		int(ProjectSettings.get_setting("display/window/size/window_height_override", 0)))
	ctx.equal(settings.call(&"get_resolution"), expected, "默认分辨率应与 project.godot 一致")
	ctx.check(expected.x > 0 and expected.y > 0, "默认分辨率应为正数")
	ctx.equal(settings.call(&"get_master_volume"), 1.0, "默认主音量应为 1.0（无衰减）")
	ctx.equal(settings.call(&"get_locale"), TranslationServer.get_locale(), "默认语言应跟随引擎")
	_release(settings)


func _run_volume_checks(ctx: RefCounted, tree: SceneTree, script: GDScript) -> void:
	ctx.begin_case("Settings · 音量范围与信号")
	var settings: Node = _spawn(tree, script)
	var changes: Array = []
	var handler: Callable = func(key) -> void: changes.append(key)
	settings.connect(&"setting_changed", handler)

	settings.call(&"set_master_volume", 0.5)
	ctx.equal(settings.call(&"get_master_volume"), 0.5, "音量应被接受")
	ctx.equal(changes.size(), 1, "应发出一次 setting_changed")
	if changes.size() == 1:
		ctx.equal(changes[0], script.KEY_MASTER_VOLUME, "变更 key")

	settings.call(&"set_master_volume", 9.0)
	ctx.equal(settings.call(&"get_master_volume"), 1.0, "越界上限应被钳制")
	settings.call(&"set_master_volume", -3.0)
	ctx.equal(settings.call(&"get_master_volume"), 0.0, "越界下限应被钳制")

	settings.call(&"set_master_volume", 0.0)
	ctx.equal(changes.size(), 3, "重复设同一值不应重复发信号")
	settings.disconnect(&"setting_changed", handler)
	_release(settings)


func _run_locale_checks(ctx: RefCounted, tree: SceneTree, script: GDScript) -> void:
	ctx.begin_case("Settings · 语言 key 校验")
	var settings: Node = _spawn(tree, script)
	var original: String = String(settings.call(&"get_locale"))
	settings.call(&"set_locale", "")
	ctx.equal(settings.call(&"get_locale"), original, "空语言 key 应被拒绝且保持原值")
	settings.call(&"set_locale", "en")
	ctx.equal(settings.call(&"get_locale"), "en", "合法语言 key 应被接受")
	_translation_server_restore(original)
	_release(settings)


func _run_resolution_checks(ctx: RefCounted, tree: SceneTree, script: GDScript) -> void:
	ctx.begin_case("Settings · 分辨率校验")
	var settings: Node = _spawn(tree, script)
	var original: Vector2i = settings.call(&"get_resolution")
	settings.call(&"set_resolution", Vector2i(640, 360))
	ctx.equal(settings.call(&"get_resolution"), Vector2i(640, 360), "合法分辨率应被接受")
	settings.call(&"set_resolution", Vector2i(0, 360))
	ctx.equal(settings.call(&"get_resolution"), Vector2i(640, 360), "零宽应被拒绝且保持原值")
	settings.call(&"set_resolution", Vector2i(640, -1))
	ctx.equal(settings.call(&"get_resolution"), Vector2i(640, 360), "负高应被拒绝且保持原值")
	_release(settings)


## 独立实例也会改到 TranslationServer 的全局 locale，测完还原，避免影响其它用例。
func _translation_server_restore(locale: String) -> void:
	if not locale.is_empty():
		TranslationServer.set_locale(locale)


func _spawn(tree: SceneTree, script: GDScript) -> Node:
	var node: Node = script.new()
	node.name = "SettingsUnderTest"
	tree.root.add_child(node)
	return node


func _release(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()
