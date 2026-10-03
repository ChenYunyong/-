## test_theme.gd
## 职责：全局 Theme 是否按 06 §2/§3 装配，且颜色全部来自 Palette（04 §6/§7）。
## 所属系统：tests
## 依赖：test_context, Palette, PaletteTheme
## 禁止：本文件不得硬编码色值 —— 期望值一律写成 Palette.get_color(...)。

extends RefCounted

const THEME_PATH: String = "res://assets/ui/theme_main.tres"
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"

## 06 §1：正文 ≥ 8px。06 §2.2：主面板外框 3px，其余描边 1px。
const EXPECTED_BODY_FONT_SIZE: int = 8
const EXPECTED_BORDER_WIDTH: int = 1
const EXPECTED_FRAME_BORDER_WIDTH: int = 3


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	var theme_resource: Resource = ResourceLoader.load(THEME_PATH)
	if not ctx.check(theme_resource != null, "theme_main.tres 应能加载"):
		return
	if not ctx.check(theme_resource is Theme, "theme_main.tres 应为 Theme 资源"):
		return
	var theme: Theme = theme_resource
	var theme_script: GDScript = load(THEME_SCRIPT_PATH)
	if not ctx.check(theme_script != null, "palette_theme.gd 应能加载"):
		return

	_run_source_checks(ctx, theme_script)
	_run_basics(ctx, theme, theme_script)
	_run_button_checks(ctx, theme, theme_script)
	_run_panel_checks(ctx, theme, theme_script)
	_run_highlight_checks(ctx, theme, theme_script)
	_run_shadow_checks(ctx, theme, theme_script)
	_run_label_checks(ctx, theme, theme_script)


## 04 §6：Theme 不得自带字面色值，否则 palette.tres 就不再是唯一来源。
func _run_source_checks(ctx: RefCounted, theme_script: GDScript) -> void:
	ctx.begin_case("Theme · 色值只来自 Palette")
	var literal: RegEx = RegEx.new()
	literal.compile("Color\\(")
	ctx.check(literal.search(FileAccess.get_file_as_string(THEME_PATH)) == null, "theme_main.tres 不得内嵌 Color(...) 字面量")
	ctx.check(FileAccess.get_file_as_string(THEME_PATH).contains("palette_theme.gd"), "theme_main.tres 应挂载 PaletteTheme 脚本")

	var theme_source: String = FileAccess.get_file_as_string(THEME_SCRIPT_PATH)
	var bare: RegEx = RegEx.new()
	bare.compile("Color\\(\\s*\"#")
	ctx.check(bare.search(theme_source) == null, "palette_theme.gd 不得出现裸色值")
	ctx.check(not theme_source.contains("Color("), "palette_theme.gd 不得构造任何 Color 字面量 —— 一切经 Palette.get_color()")
	ctx.check(theme_script != null, "PaletteTheme 脚本可实例化")


func _run_basics(ctx: RefCounted, theme: Theme, theme_script: GDScript) -> void:
	ctx.begin_case("Theme · 基本设定")
	ctx.equal(theme.get_script(), theme_script, "Theme 应由 PaletteTheme 装配")
	ctx.equal(theme.default_font_size, EXPECTED_BODY_FONT_SIZE, "正文字号（06 §1）")


## 06 §3 的按钮五态：Normal / Hover / Pressed / Disabled / Selected(=focus)。
func _run_button_checks(ctx: RefCounted, theme: Theme, theme_script: GDScript) -> void:
	ctx.begin_case("Theme · Button 五态（06 §3）")
	ctx.equal(theme.get_color(&"font_color", &"Button"), Palette.get_color(Palette.Key.NAVY_900), "Normal 文字")
	ctx.equal(theme.get_color(&"font_hover_color", &"Button"), Palette.get_color(Palette.Key.NAVY_900), "Hover 文字")
	ctx.equal(theme.get_color(&"font_pressed_color", &"Button"), Palette.get_color(Palette.Key.NAVY_900), "Pressed 文字")
	ctx.equal(theme.get_color(&"font_disabled_color", &"Button"), Palette.get_color(Palette.Key.GREY_500), "Disabled 文字")
	ctx.equal(theme.get_color(&"font_focus_color", &"Button"), Palette.get_color(Palette.Key.NAVY_900), "Selected 文字")

	_check_box(ctx, theme.get_stylebox(&"normal", &"Button"), Palette.Key.GOLD_500, Palette.Key.GOLD_600, "Button Normal", EXPECTED_BORDER_WIDTH)
	_check_box(ctx, theme.get_stylebox(&"hover", &"Button"), Palette.Key.GOLD_400, Palette.Key.GOLD_500, "Button Hover", EXPECTED_BORDER_WIDTH)
	_check_box(ctx, theme.get_stylebox(&"pressed", &"Button"), Palette.Key.GOLD_600, Palette.Key.GOLD_600, "Button Pressed", EXPECTED_BORDER_WIDTH)
	_check_box(ctx, theme.get_stylebox(&"disabled", &"Button"), Palette.Key.NAVY_800, Palette.Key.NAVY_600, "Button Disabled", EXPECTED_BORDER_WIDTH)
	_check_box(ctx, theme.get_stylebox(&"focus", &"Button"), Palette.Key.GOLD_400, Palette.Key.BLUE_400, "Button Selected", EXPECTED_BORDER_WIDTH)

	ctx.check(theme.get_type_variation_list(&"Button").has(theme_script.TYPE_BUTTON_SECONDARY), "应注册辅助按钮变体")
	ctx.equal(theme.get_color(&"font_color", theme_script.TYPE_BUTTON_SECONDARY), Palette.get_color(Palette.Key.GREY_300), "辅助按钮文字色")
	_check_box(ctx, theme.get_stylebox(&"normal", theme_script.TYPE_BUTTON_SECONDARY), Palette.Key.NAVY_700, Palette.Key.NAVY_600, "辅助按钮 Normal", EXPECTED_BORDER_WIDTH)


## 06 §2.2：主面板 = 3px 木质外框；内芯 = NAVY_800 + 1px NAVY_600；次级面板 = 1px BROWN_600。
func _run_panel_checks(ctx: RefCounted, theme: Theme, theme_script: GDScript) -> void:
	ctx.begin_case("Theme · Panel 三层（06 §2.2）")
	var variations: PackedStringArray = theme.get_type_variation_list(&"Panel")
	ctx.check(variations.has(theme_script.TYPE_PANEL_FRAME), "应注册主面板外框变体")
	ctx.check(variations.has(theme_script.TYPE_PANEL_CORE), "应注册面板内芯变体")
	ctx.check(variations.has(theme_script.TYPE_PANEL_SECONDARY), "应注册次级面板变体")

	_check_box(ctx, theme.get_stylebox(&"panel", theme_script.TYPE_PANEL_FRAME), Palette.Key.BROWN_600, Palette.Key.BROWN_500, "主面板外框", EXPECTED_FRAME_BORDER_WIDTH)
	_check_box(ctx, theme.get_stylebox(&"panel", theme_script.TYPE_PANEL_CORE), Palette.Key.NAVY_800, Palette.Key.NAVY_600, "面板内芯", EXPECTED_BORDER_WIDTH)
	_check_box(ctx, theme.get_stylebox(&"panel", theme_script.TYPE_PANEL_SECONDARY), Palette.Key.NAVY_800, Palette.Key.BROWN_600, "次级面板", EXPECTED_BORDER_WIDTH)


## 06 §2.1 v0.1.4：第三层「高光」必须有可被场景引用的落点；
## 且 DSH 裁定「选中辉光」BLUE_300 必须始终留在 Theme，不得随外框素材化移交。
func _run_highlight_checks(ctx: RefCounted, theme: Theme, theme_script: GDScript) -> void:
	ctx.begin_case("Theme · Panel 高光层（06 §2.1 v0.1.4 第三层）")
	var variations: PackedStringArray = theme.get_type_variation_list(&"Panel")
	ctx.check(variations.has(theme_script.TYPE_PANEL_HIGHLIGHT), "应注册 1px 暖高光变体")
	ctx.check(variations.has(theme_script.TYPE_PANEL_SELECTED), "应注册选中辉光变体")

	_check_highlight(ctx, theme.get_stylebox(&"panel", theme_script.TYPE_PANEL_HIGHLIGHT),
		Palette.Key.GOLD_200, "暖高光")
	_check_highlight(ctx, theme.get_stylebox(&"panel", theme_script.TYPE_PANEL_SELECTED),
		Palette.Key.BLUE_300, "选中辉光")

	ctx.check(_theme_uses_token(theme, Palette.Key.GOLD_200), "Theme 必须实际引用 GOLD_200")
	ctx.check(_theme_uses_token(theme, Palette.Key.BLUE_300), "Theme 必须实际引用 BLUE_300（DSH 裁定：始终留在 Theme）")


## 06 §2.2 的硬阴影落点。不用 shadow_* 的原因见 render_shadow_probe.gd 的实测：
## shadow_size 同时决定「有没有阴影」与「羽化带多宽」，无法解耦，故改用 border + expand_margin。
func _run_shadow_checks(ctx: RefCounted, theme: Theme, theme_script: GDScript) -> void:
	ctx.begin_case("Theme · 硬阴影落点（06 §2.2）")
	ctx.check(theme.get_type_variation_list(&"Panel").has(theme_script.TYPE_PANEL_SHADOW),
		"应注册硬阴影变体")
	var box: StyleBox = theme.get_stylebox(&"panel", theme_script.TYPE_PANEL_SHADOW)
	if not ctx.check(box is StyleBoxFlat, "PanelShadow 应为 StyleBoxFlat"):
		return
	var flat: StyleBoxFlat = box
	ctx.equal(flat.border_color, Palette.get_color(Palette.Key.NAVY_900), "阴影色")
	ctx.equal(flat.border_width_right, EXPECTED_BORDER_WIDTH, "右侧 1px")
	ctx.equal(flat.border_width_bottom, EXPECTED_BORDER_WIDTH, "下侧 1px")
	ctx.equal(flat.border_width_left, 0, "左侧不得有边")
	ctx.equal(flat.border_width_top, 0, "上侧不得有边")
	ctx.equal(flat.expand_margin_right, float(EXPECTED_BORDER_WIDTH), "右边应外扩 1px（落到矩形外）")
	ctx.equal(flat.expand_margin_bottom, float(EXPECTED_BORDER_WIDTH), "下边应外扩 1px（落到矩形外）")
	ctx.equal(flat.expand_margin_left, 0.0, "左边不得外扩")
	ctx.equal(flat.expand_margin_top, 0.0, "上边不得外扩")
	ctx.check(not flat.draw_center, "阴影层应只画边、不填中心")
	ctx.check(not flat.anti_aliasing, "不得开抗锯齿")
	ctx.equal(flat.shadow_size, 0, "不得再叠 shadow_*（实测会引入 1px 羽化）")


func _check_highlight(ctx: RefCounted, box: StyleBox, token: Palette.Key, label: String) -> void:
	if not ctx.check(box is StyleBoxFlat, "%s 应为 StyleBoxFlat" % label):
		return
	var flat: StyleBoxFlat = box
	ctx.equal(flat.border_color, Palette.get_color(token), "%s 描边色" % label)
	ctx.equal(flat.border_width_left, EXPECTED_BORDER_WIDTH, "%s 左描边宽" % label)
	ctx.equal(flat.border_width_top, EXPECTED_BORDER_WIDTH, "%s 上描边宽" % label)
	ctx.equal(flat.border_width_right, EXPECTED_BORDER_WIDTH, "%s 右描边宽" % label)
	ctx.equal(flat.border_width_bottom, EXPECTED_BORDER_WIDTH, "%s 下描边宽" % label)
	ctx.check(not flat.draw_center, "%s 应为叠层（不填中心）" % label)
	ctx.equal(flat.corner_radius_top_left, 0, "%s 应为像素直角" % label)
	ctx.check(not flat.anti_aliasing, "%s 不得开抗锯齿" % label)
	ctx.equal(flat.shadow_size, 0, "%s 不得带 shadow_*" % label)


## 扫遍 Theme 里全部 stylebox 与 color 条目，确认某个 Token 真的被引用（不只是写在常量里）。
func _theme_uses_token(theme: Theme, key: Palette.Key) -> bool:
	var wanted: Color = Palette.get_color(key)
	for type_name: StringName in theme.get_stylebox_type_list():
		for box_name: StringName in theme.get_stylebox_list(type_name):
			var box: StyleBox = theme.get_stylebox(box_name, type_name)
			if box is StyleBoxFlat:
				var flat: StyleBoxFlat = box
				if flat.border_color == wanted or flat.bg_color == wanted or flat.shadow_color == wanted:
					return true
	for type_name: StringName in theme.get_color_type_list():
		for color_name: StringName in theme.get_color_list(type_name):
			if theme.get_color(color_name, type_name) == wanted:
				return true
	return false


func _run_label_checks(ctx: RefCounted, theme: Theme, theme_script: GDScript) -> void:
	ctx.begin_case("Theme · Label 取色（04 §5.1 / §3.7）")
	ctx.equal(theme.get_color(&"font_color", &"Label"), Palette.get_color(Palette.Key.BLUE_100), "正文首选色")
	ctx.equal(theme.get_color(&"font_color", theme_script.TYPE_LABEL_SECONDARY), Palette.get_color(Palette.Key.GREY_300), "次要文字色")
	ctx.equal(theme.get_color(&"font_color", theme_script.TYPE_LABEL_DANGER), Palette.get_color(Palette.Key.RED_400), "危险小号文字色")


## 06 §1：像素直角、无抗锯齿；06 §2.2：右下 1px NAVY_900 硬阴影（不模糊）。
func _check_box(ctx: RefCounted, box: StyleBox, fill: Palette.Key, border: Palette.Key, label: String, border_width: int) -> void:
	if not ctx.check(box is StyleBoxFlat, "%s 应为 StyleBoxFlat" % label):
		return
	var flat: StyleBoxFlat = box
	ctx.equal(flat.bg_color, Palette.get_color(fill), "%s 底色" % label)
	ctx.equal(flat.border_color, Palette.get_color(border), "%s 描边色" % label)
	ctx.equal(flat.border_width_left, border_width, "%s 左边框宽度" % label)
	ctx.equal(flat.border_width_top, border_width, "%s 上边框宽度" % label)
	ctx.equal(flat.border_width_right, border_width, "%s 右边框宽度" % label)
	ctx.equal(flat.border_width_bottom, border_width, "%s 下边框宽度" % label)
	ctx.equal(flat.corner_radius_top_left, 0, "%s 应为像素直角" % label)
	ctx.check(not flat.anti_aliasing, "%s 不得开抗锯齿" % label)
	ctx.equal(flat.shadow_color, Palette.get_color(Palette.Key.NAVY_900), "%s 硬阴影色" % label)
	ctx.equal(flat.shadow_size, 0, "%s 不得带 shadow_*（实测会引入 1px 羽化，违反「不模糊」）" % label)
	ctx.equal(flat.shadow_offset, Vector2(1, 1), "%s 阴影应为右下 1px" % label)
