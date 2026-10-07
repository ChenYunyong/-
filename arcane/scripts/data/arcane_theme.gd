## arcane_theme.gd
## 职责：把 Palette 的 Color Token 装配成全局 Theme（docs/04 §7、docs/06 §2/§3）。
## 所属系统：data
## 依赖：Palette（唯一色值来源）
## 禁止：本文件不得出现任何字面色值 —— 一切颜色必须经 Palette.get_color()，
##       否则 palette.tres 就不再是唯一色值来源（04 §4.9）。
##
## PET-85：旧工程的主题把颜色接到了 VB-03 已批准切片上；新工程**不带旧美术**，
## 因此这里全部用 StyleBoxFlat 从 Token 现画 —— 带走的只有「Token 单一真值来源」这个机制。
## 切片到位后把 _panel_box() 换成 StyleBoxTexture 即可，Token 入口不变。

@tool
class_name ArcaneTheme
extends Theme

## 960×540 画布上的几何常量。取值 = docs/06 的 320×180 参考值 ×3
## （DSH 2026-10-06：画布 960×540；原值→新值对照表见 arcane/README.md）。
const BORDER_WIDTH: int = 3
const FRAME_BORDER_WIDTH: int = 9
const CONTENT_MARGIN: int = 24
const PANEL_CONTENT_MARGIN: int = 36
## 按钮的内边距。间距系统里最小的那一档 4px（320×180 参考系）×3 = 12 ——
## 按钮高因此 ≈ 54，才放得进 72 高的顶栏（用 24 的话按钮高 78，顶栏得占掉画布一截）。
const BUTTON_CONTENT_MARGIN: int = 12
const BODY_FONT_SIZE: int = 24

## 06 §2.2：主面板标题栏高度。320×180 时代为 16px → ×3 = 48。
const TITLE_BAR_HEIGHT: int = 48

## Theme 类型变体名。场景用 theme_type_variation 引用（06 §7：不在控件上零散覆盖颜色）。
const TYPE_PANEL_FRAME: StringName = &"PanelFrame"
const TYPE_PANEL_SECONDARY: StringName = &"PanelSecondary"
const TYPE_PANEL_CANVAS: StringName = &"PanelCanvas"
const TYPE_PANEL_TITLE_BAR: StringName = &"PanelTitleBar"
const TYPE_PANEL_SHADOW: StringName = &"PanelShadow"
const TYPE_BUTTON_PRIMARY: StringName = &"ButtonPrimary"
const TYPE_BUTTON_SECONDARY: StringName = &"ButtonSecondary"
const TYPE_LABEL_SECONDARY: StringName = &"LabelSecondary"
const TYPE_LABEL_ACCENT: StringName = &"LabelAccent"
const TYPE_LABEL_DANGER: StringName = &"LabelDanger"

const BASE_TYPE_BUTTON: StringName = &"Button"
const BASE_TYPE_PANEL: StringName = &"Panel"
const BASE_TYPE_LABEL: StringName = &"Label"


func _init() -> void:
	apply_palette()


## 重建全部主题样式。palette.tres 变更后重跑即可；本函数只读 Palette，不缓存色值。
func apply_palette() -> void:
	# 字体必须是主题的 default_font，而不是逐个控件设置 —— 06 §11「文本必须走 key」的
	# 前提是文字画得出来：Godot 内置字体没有 CJK 字形，中文会整片空白（见 fonts.gd）。
	default_font = Fonts.ui_font()
	default_font_size = BODY_FONT_SIZE
	_build_button_primary()
	_build_button_secondary()
	_build_panels()
	_build_panel_title_bar()
	_build_panel_shadow()
	_build_labels()


## 06 §3 —— 主动作按钮的五态。底色/描边/文字全部走 Token。
func _build_button_primary() -> void:
	set_type_variation(TYPE_BUTTON_PRIMARY, BASE_TYPE_BUTTON)
	var states: Array[Dictionary] = [
		{"slot": &"normal", "fill": Palette.Key.GOLD_500, "border": Palette.Key.GOLD_600},
		{"slot": &"hover", "fill": Palette.Key.GOLD_400, "border": Palette.Key.GOLD_500},
		{"slot": &"pressed", "fill": Palette.Key.GOLD_600, "border": Palette.Key.GOLD_600},
		# 06 §3 Disabled：底色必须是 NAVY_800 —— GREY_500 在 NAVY_700 上仅 3.84:1，不达标。
		{"slot": &"disabled", "fill": Palette.Key.NAVY_800, "border": Palette.Key.NAVY_600},
		{"slot": &"focus", "fill": Palette.Key.GOLD_500, "border": Palette.Key.BLUE_400},
	]
	for state: Dictionary in states:
		set_stylebox(state["slot"], TYPE_BUTTON_PRIMARY, _button_box(state["fill"], state["border"]))
	var text: Color = Palette.get_color(Palette.Key.NAVY_900)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		set_color(slot, TYPE_BUTTON_PRIMARY, text)
	set_color(&"font_disabled_color", TYPE_BUTTON_PRIMARY, Palette.get_color(Palette.Key.GREY_500))


## 06 §3 辅助按钮：底色 NAVY_700、描边 NAVY_600、文字 GREY_300。
func _build_button_secondary() -> void:
	set_type_variation(TYPE_BUTTON_SECONDARY, BASE_TYPE_BUTTON)
	var box: StyleBoxFlat = _button_box(Palette.Key.NAVY_700, Palette.Key.NAVY_600)
	for slot: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		set_stylebox(slot, TYPE_BUTTON_SECONDARY, box)
	var text: Color = Palette.get_color(Palette.Key.GREY_300)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		set_color(slot, TYPE_BUTTON_SECONDARY, text)
	set_color(&"font_disabled_color", TYPE_BUTTON_SECONDARY, Palette.get_color(Palette.Key.GREY_500))


## 06 §2.1 三层结构：木质外框包住深蓝内芯。
##   PanelFrame    = 主面板（厚木框，BROWN_600 填充 + BROWN_500 描边）
##   PanelSecondary= 面板内卡片（NAVY_800 内芯 + 1px 级 BROWN_600 描边）
##   PanelCanvas   = 模块编辑器的书页画布（内芯 NAVY_900，比卡片更深一档，让卡片浮起来）
func _build_panels() -> void:
	set_type_variation(TYPE_PANEL_FRAME, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_FRAME,
		_panel_box(Palette.Key.BROWN_600, Palette.Key.BROWN_500, FRAME_BORDER_WIDTH))

	set_type_variation(TYPE_PANEL_SECONDARY, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_SECONDARY, _panel_box(Palette.Key.NAVY_800, Palette.Key.BROWN_600))

	# 书页画布：NAVY_900 内芯 + 9px BROWN_600 厚边 —— 像一页嵌在木框里的纸，
	# 与外层木框（PanelFrame）同色系但更深，卡片浮在它上面。
	set_type_variation(TYPE_PANEL_CANVAS, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_CANVAS,
		_panel_box(Palette.Key.NAVY_900, Palette.Key.BROWN_600, FRAME_BORDER_WIDTH))


## 06 §2.2 面板标题栏：底色 NAVY_700 + 底边 GOLD_600 分隔线，其余三边为 0。
## 描边画在 stylebox 内侧，故「高度 48px」里第 48 行就是那条金线。
func _build_panel_title_bar() -> void:
	set_type_variation(TYPE_PANEL_TITLE_BAR, BASE_TYPE_PANEL)
	var box: StyleBoxFlat = _panel_box(Palette.Key.NAVY_700, Palette.Key.GOLD_600)
	box.border_width_left = 0
	box.border_width_top = 0
	box.border_width_right = 0
	box.set_content_margin_all(0.0)
	set_stylebox(&"panel", TYPE_PANEL_TITLE_BAR, box)


## 06 §2.2 的「右下 1px NAVY_900 硬阴影（不模糊）」。旧工程实测证明 StyleBoxFlat.shadow_*
## 无法同时满足「有阴影」与「不羽化」（shadow_size = 0 时一个像素都不画），
## 故改用 border + expand_margin 把右下两边推出矩形外侧。机制照搬，值 ×3。
func _build_panel_shadow() -> void:
	set_type_variation(TYPE_PANEL_SHADOW, BASE_TYPE_PANEL)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Palette.get_color(Palette.Key.NAVY_900)
	box.border_width_left = 0
	box.border_width_top = 0
	box.border_width_right = BORDER_WIDTH
	box.border_width_bottom = BORDER_WIDTH
	box.expand_margin_right = float(BORDER_WIDTH)
	box.expand_margin_bottom = float(BORDER_WIDTH)
	box.anti_aliasing = false
	set_stylebox(&"panel", TYPE_PANEL_SHADOW, box)


## 正文 BLUE_100（04 §5.1 在 NAVY_800 上 11.75:1，首选）；次要 GREY_300；危险 RED_400。
func _build_labels() -> void:
	set_color(&"font_color", BASE_TYPE_LABEL, Palette.get_color(Palette.Key.BLUE_100))
	set_type_variation(TYPE_LABEL_SECONDARY, BASE_TYPE_LABEL)
	set_color(&"font_color", TYPE_LABEL_SECONDARY, Palette.get_color(Palette.Key.GREY_300))
	set_type_variation(TYPE_LABEL_ACCENT, BASE_TYPE_LABEL)
	set_color(&"font_color", TYPE_LABEL_ACCENT, Palette.get_color(Palette.Key.GOLD_500))
	set_type_variation(TYPE_LABEL_DANGER, BASE_TYPE_LABEL)
	set_color(&"font_color", TYPE_LABEL_DANGER, Palette.get_color(Palette.Key.RED_400))


func _button_box(fill: Palette.Key, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = _panel_box(fill, border)
	box.set_content_margin_all(float(BUTTON_CONTENT_MARGIN))
	return box


## 06 §1：像素直角、无抗锯齿、无模糊阴影。
func _panel_box(fill: Palette.Key, border: Palette.Key, width: int = BORDER_WIDTH) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.get_color(fill)
	box.border_color = Palette.get_color(border)
	box.set_border_width_all(width)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.set_content_margin_all(float(PANEL_CONTENT_MARGIN))
	return box
