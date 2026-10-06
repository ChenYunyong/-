## test_vb03_wiring.gd
## 职责：VB-03 已批准切片**真的接到了运行时控件上**（PET-77）—— 判据不是「Theme 里有个常量」，
##       而是「控件把样式槽解析出来的 StyleBoxTexture，其 texture 落在 assets/ui/vb03_component_language/ 下」。
##       解析走的是引擎真实路径（控件入树 + theme 链），与运行时场景取到的是同一套结果。
## 所属系统：tests
## 依赖：test_context, assets/ui/theme_main.tres, scripts/data/palette_theme.gd
## 禁止：不得写任何字面色值 —— 本文件只比类型与资源路径，颜色归 test_theme.gd 与各像素探针管。
##
## 判别力（09 §4）：每组都以一条**反向对照**收尾 —— 把同一个控件上的 theme 摘掉，
## 解析结果必须**不再**是切片纹理。摘掉后仍绿，就说明前面那些断言测的不是「这次接入」，
## 而是「引擎默认主题恰好也有个 StyleBoxTexture」这类无关事实。
## 另有一组正面对照：五个按钮态的切片文件必须互不相同 —— 否则「五态都接了」是一句空话。

extends RefCounted

const THEME_PATH: String = "res://assets/ui/theme_main.tres"
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"

## 已批准切片的落盘目录。断言的是**前缀**，不是某一张具体文件 —— 文件名归 asset_manifest.json 管，
## 这里要证的是「解析出来的纹理来自 VB-03 那一批」，而不是「恰好等于我抄下来的这个字符串」。
const SLICE_DIR: String = "res://assets/ui/vb03_component_language/"

## 六场景（03 §1 的推进顺序）。每一屏的根节点都必须挂同一个全局 Theme。
const SCENES: PackedStringArray = [
	"res://scenes/boot/boot.tscn",
	"res://scenes/menu/main_menu.tscn",
	"res://scenes/preparation/preparation.tscn",
	"res://scenes/combat/combat.tscn",
	"res://scenes/reward/reward.tscn",
	"res://scenes/result/result.tscn",
]

## 控件 → 需要解析的样式槽。类型名与变体名同 palette_theme.gd 的常量，
## 但这里刻意**写字符串**：以常量为准会让「常量改了名、场景没跟着改」这类断链一起绿掉。
const STYLEBOX_SLOTS: Array[Dictionary] = [
	{"type": "Button", "variation": "", "slot": "normal"},
	{"type": "Button", "variation": "", "slot": "hover"},
	{"type": "Button", "variation": "", "slot": "pressed"},
	{"type": "Button", "variation": "", "slot": "focus"},
	{"type": "Button", "variation": "", "slot": "disabled"},
	{"type": "Button", "variation": "ButtonSelected", "slot": "normal"},
	{"type": "Panel", "variation": "PanelFrame", "slot": "panel"},
	{"type": "Panel", "variation": "PanelSecondary", "slot": "panel"},
	{"type": "Panel", "variation": "TooltipPanel", "slot": "panel"},
	{"type": "Panel", "variation": "FocusOverlay", "slot": "panel"},
	{"type": "Panel", "variation": "SelectedOverlay", "slot": "panel"},
	{"type": "Panel", "variation": "DisabledOverlay", "slot": "panel"},
	{"type": "ProgressBar", "variation": "", "slot": "background"},
	{"type": "ProgressBar", "variation": "", "slot": "fill"},
]

var _theme: Theme = null
var _tree: SceneTree = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	_tree = tree
	var loaded: Resource = ResourceLoader.load(THEME_PATH)
	if not ctx.check(loaded != null and loaded is Theme, "theme_main.tres 应能加载为 Theme"):
		return
	_theme = loaded

	_run_source_check(ctx)
	_run_scene_theme_check(ctx)
	_run_slot_checks(ctx)
	_run_distinct_check(ctx)
	_run_reverse_control(ctx)


## 接入是「引用已批准素材」，不是「在代码里又写一份像素色」——
## 故这里只要求切片目录被引用到，不检查切片本身（那归 07 §1 的批准流程）。
func _run_source_check(ctx: RefCounted) -> void:
	ctx.begin_case("VB-03 接入 · 引用面")
	var source: String = FileAccess.get_file_as_string(THEME_SCRIPT_PATH)
	ctx.check(source.contains("vb03_component_language"),
		"palette_theme.gd 应引用 assets/ui/vb03_component_language/**（PET-77 接入点）")


## 六屏共用同一个 Theme —— 少一屏就是「只接了一屏」，本卡明确要求六屏都接。
func _run_scene_theme_check(ctx: RefCounted) -> void:
	ctx.begin_case("VB-03 接入 · 六场景都挂上全局 Theme")
	for path: String in SCENES:
		var packed: PackedScene = load(path)
		if not ctx.check(packed != null, "%s 应能加载" % path):
			continue
		var root: Node = packed.instantiate()
		var control: Control = root as Control
		ctx.check(control != null and control.theme == _theme,
			"%s 的根节点应挂 theme_main.tres（同一次加载的同一个实例）" % path)
		root.free()


## 逐槽解析：控件入树 → 挂 Theme → 读样式槽。这与运行时场景取到的是同一条链。
func _run_slot_checks(ctx: RefCounted) -> void:
	for entry: Dictionary in STYLEBOX_SLOTS:
		var type_name: String = String(entry["type"])
		var variation: String = String(entry["variation"])
		var slot: StringName = StringName(entry["slot"])
		var label: String = "%s%s/%s" % [type_name, ("·" + variation) if variation != "" else "", slot]
		ctx.begin_case("VB-03 接入 · %s" % label)

		var control: Control = _make_control(type_name, variation)
		if not ctx.check(control != null, "应能造出 %s 控件" % label):
			continue
		var box: StyleBox = control.get_theme_stylebox(slot)
		ctx.check(box is StyleBoxTexture,
			"%s 解析出的应是 StyleBoxTexture（实际 %s）—— 九宫格边距靠它承载，StyleBoxFlat 接不了切片"
				% [label, box.get_class() if box != null else "null"])
		ctx.check(_slice_path(box) != "", "%s 的 texture 应来自 %s（实际 %s）"
			% [label, SLICE_DIR, _slice_path(box) if _slice_path(box) != "" else _texture_path(box)])
		_retire(control)


## 五个按钮态必须各指一张不同的切片 —— 「五态都接了」的正面证据。
## 若五态指向同一张图，上面那组会全绿而五态其实没做出来。
func _run_distinct_check(ctx: RefCounted) -> void:
	ctx.begin_case("VB-03 接入 · 按钮五态各是一张不同的切片")
	var seen: Dictionary = {}
	var states: PackedStringArray = ["normal", "hover", "pressed", "focus", "disabled"]
	var control: Control = _make_control("Button", "")
	if control == null:
		ctx.check(false, "应能造出 Button")
		return
	for state: String in states:
		var box: StyleBox = control.get_theme_stylebox(StringName(state))
		var path: String = _texture_path(box)
		ctx.check(path != "", "%s 态应有切片纹理" % state)
		ctx.check(not seen.has(path), "%s 态的切片不得与前几态重复（%s 已用过）" % [state, path])
		seen[path] = state
	_retire(control)


## 反向对照：同一个控件**不挂 Theme** 时，解析结果必须不再是切片纹理。
## 变了才说明上面那 14 条数的确实是「这次接入」；没变说明它们测的是引擎默认主题。
func _run_reverse_control(ctx: RefCounted) -> void:
	ctx.begin_case("VB-03 接入 · 反向对照：摘掉 Theme 后不再是切片纹理")
	for entry: Dictionary in STYLEBOX_SLOTS:
		var control: Control = _make_control(String(entry["type"]), String(entry["variation"]))
		if control == null:
			continue
		control.theme = null
		var path: String = _slice_path(control.get_theme_stylebox(StringName(entry["slot"])))
		var label: String = "%s%s" % [String(entry["type"]), String(entry["variation"])]
		ctx.check(path == "", "摘掉 Theme 后 %s/%s 不该再解析到切片纹理（实际 %s）"
			% [label, String(entry["slot"]), path])
		_retire(control)


## 造一个挂着全局 Theme 的控件并**入树** —— 样式解析要走 ThemeOwner，
## 而 ThemeOwner 在 ENTER_TREE 时才建立；不入树的控件会直接落到引擎默认主题上。
func _make_control(type_name: String, variation: String) -> Control:
	var control: Control = null
	match type_name:
		"Button":
			control = Button.new()
		"Panel":
			control = Panel.new()
		"ProgressBar":
			control = ProgressBar.new()
	if control == null:
		return null
	control.theme = _theme
	control.theme_type_variation = StringName(variation)
	_tree.root.add_child(control)
	return control


func _retire(control: Control) -> void:
	_tree.root.remove_child(control)
	control.free()


## 解析结果 → 切片路径；不是切片纹理或不在 VB-03 目录下时返回空串。
func _slice_path(box: StyleBox) -> String:
	var path: String = _texture_path(box)
	return path if path.begins_with(SLICE_DIR) else ""


func _texture_path(box: StyleBox) -> String:
	if not (box is StyleBoxTexture):
		return ""
	var texture: Texture2D = (box as StyleBoxTexture).texture
	return "" if texture == null else texture.resource_path
