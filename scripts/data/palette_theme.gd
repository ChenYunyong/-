## palette_theme.gd
## 职责：把 Palette 的 Color Token 装配成全局 Theme（04_COLOR_SYSTEM.md §7、06_UI_UX_STANDARD.md §2/§3）。
## 所属系统：data
## 依赖：Palette
## 禁止：本文件不得出现任何字面色值 —— 一切颜色必须经 Palette.get_color()，
##       否则 palette.tres 就不再是唯一色值来源（04 §6）。

@tool
class_name PaletteTheme
extends Theme

## 06 §1：基准 320×180，描边统一 1px，间距只用 4/8/12/16/24，像素角（直角）。
const BORDER_WIDTH: int = 1
const FRAME_BORDER_WIDTH: int = 3
const CONTENT_MARGIN: int = 4
const PANEL_CONTENT_MARGIN: int = 12
const PANEL_SECONDARY_CONTENT_MARGIN: int = 8
const BODY_FONT_SIZE: int = 8

## Theme 类型变体名。S1-06 起的场景用 theme_type_variation 引用它们。
const TYPE_PANEL_FRAME: StringName = &"PanelFrame"
const TYPE_PANEL_CORE: StringName = &"PanelCore"
const TYPE_PANEL_SECONDARY: StringName = &"PanelSecondary"
## 06 §2.1 v0.1.4 第三层「高光」：必须有可被场景引用的落点。
const TYPE_PANEL_HIGHLIGHT: StringName = &"PanelHighlight"
const TYPE_PANEL_SELECTED: StringName = &"PanelSelected"
## 06 §2.2 的硬阴影落点，机制说明见 _build_panel_shadow()。
const TYPE_PANEL_SHADOW: StringName = &"PanelShadow"
const TYPE_BUTTON_SECONDARY: StringName = &"ButtonSecondary"
const TYPE_LABEL_SECONDARY: StringName = &"LabelSecondary"
const TYPE_LABEL_DANGER: StringName = &"LabelDanger"

const BASE_TYPE_PANEL: StringName = &"Panel"
const BASE_TYPE_BUTTON: StringName = &"Button"
const BASE_TYPE_LABEL: StringName = &"Label"


func _init() -> void:
	apply_palette()


## 重建全部主题样式。可在 palette.tres 变更后重跑；本函数只读 Palette，不缓存色值。
func apply_palette() -> void:
	default_font_size = BODY_FONT_SIZE
	_build_button()
	_build_button_secondary()
	_build_panels()
	_build_panel_highlight()
	_build_panel_shadow()
	_build_labels()


## 06 §3 的按钮五态。Selected 态映射到 Theme 的 focus 样式（外框 1px 蓝）。
func _build_button() -> void:
	set_color(&"font_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_hover_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_pressed_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_focus_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_disabled_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.GREY_500))
	set_stylebox(&"normal", BASE_TYPE_BUTTON, _button_box(Palette.Key.GOLD_500, Palette.Key.GOLD_600))
	set_stylebox(&"hover", BASE_TYPE_BUTTON, _button_box(Palette.Key.GOLD_400, Palette.Key.GOLD_500))
	set_stylebox(&"pressed", BASE_TYPE_BUTTON, _button_box(Palette.Key.GOLD_600, Palette.Key.GOLD_600))
	set_stylebox(&"disabled", BASE_TYPE_BUTTON, _button_box(Palette.Key.NAVY_800, Palette.Key.NAVY_600))
	set_stylebox(&"focus", BASE_TYPE_BUTTON, _button_box(Palette.Key.GOLD_400, Palette.Key.BLUE_400))


## 06 §3 辅助按钮：底色 NAVY_700，描边 NAVY_600，文字 GREY_300。
func _build_button_secondary() -> void:
	set_type_variation(TYPE_BUTTON_SECONDARY, BASE_TYPE_BUTTON)
	var text: Color = Palette.get_color(Palette.Key.GREY_300)
	var box: StyleBoxFlat = _button_box(Palette.Key.NAVY_700, Palette.Key.NAVY_600)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		set_color(state, TYPE_BUTTON_SECONDARY, text)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		set_stylebox(state, TYPE_BUTTON_SECONDARY, box)


## 06 §2.2：主面板 = 3px 木质外框；内芯 = NAVY_800 + 1px NAVY_600；
## 次级面板（面板内卡片）= NAVY_800 + 1px BROWN_600。
func _build_panels() -> void:
	set_type_variation(TYPE_PANEL_FRAME, BASE_TYPE_PANEL)
	var frame: StyleBoxFlat = _panel_box(Palette.Key.BROWN_600, Palette.Key.BROWN_500)
	frame.border_width_left = FRAME_BORDER_WIDTH
	frame.border_width_top = FRAME_BORDER_WIDTH
	frame.border_width_right = FRAME_BORDER_WIDTH
	frame.border_width_bottom = FRAME_BORDER_WIDTH
	frame.content_margin_left = PANEL_CONTENT_MARGIN
	frame.content_margin_top = PANEL_CONTENT_MARGIN
	frame.content_margin_right = PANEL_CONTENT_MARGIN
	frame.content_margin_bottom = PANEL_CONTENT_MARGIN
	set_stylebox(&"panel", TYPE_PANEL_FRAME, frame)

	set_type_variation(TYPE_PANEL_CORE, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_CORE, _panel_box(Palette.Key.NAVY_800, Palette.Key.NAVY_600))

	set_type_variation(TYPE_PANEL_SECONDARY, BASE_TYPE_PANEL)
	var secondary: StyleBoxFlat = _panel_box(Palette.Key.NAVY_800, Palette.Key.BROWN_600)
	secondary.content_margin_left = PANEL_SECONDARY_CONTENT_MARGIN
	secondary.content_margin_top = PANEL_SECONDARY_CONTENT_MARGIN
	secondary.content_margin_right = PANEL_SECONDARY_CONTENT_MARGIN
	secondary.content_margin_bottom = PANEL_SECONDARY_CONTENT_MARGIN
	set_stylebox(&"panel", TYPE_PANEL_SECONDARY, secondary)


## 06 §2.1 第三层「高光」。本层是叠在内芯之上的装饰层，只画 1px 描边、不填中心
## （draw_center = false），场景把它当作 Panel 的 theme_type_variation 叠在外框内沿即可。
## BLUE_300 按 DSH 裁定**始终留在 Theme**，不随外框素材化移交。
##
## **边数（v0.1.6，Codex 裁定）：两者不得共用同一套边数。**
##   GOLD_200 静态内高光 → 仅上边 + 左边。材质受光有方向性，与 05 §3「光源方向统一为左上」
##                          一致；四边整圈会退化成「无方向的金色描边框」。
##   BLUE_300 选中辉光   → 四边整圈。状态提示而非材质受光，密集蓝图网格上需包围式轮廓才读得稳。
## 两种几何必须分开落笔：共用一条路径会让改高光时连带削掉选中态的包围轮廓，削弱其可发现性。
func _build_panel_highlight() -> void:
	set_type_variation(TYPE_PANEL_HIGHLIGHT, BASE_TYPE_PANEL)
	var warm: StyleBoxFlat = _highlight_box(Palette.Key.GOLD_200)
	warm.border_width_right = 0
	warm.border_width_bottom = 0
	set_stylebox(&"panel", TYPE_PANEL_HIGHLIGHT, warm)

	set_type_variation(TYPE_PANEL_SELECTED, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_SELECTED, _highlight_box(Palette.Key.BLUE_300))


## 06 §2.2 的「右下 1px NAVY_900 硬阴影（不模糊）」落点。
##
## 为什么不用 StyleBoxFlat.shadow_*（实测证据见 tests/unit/render_shadow_probe.gd，
## gl_compatibility / forward_plus / mobile 三个后端结果一致）：
##   shadow_size = 0             → 一个阴影像素都不画，且与 shadow_offset 无关；
##   shadow_size = 1, offset(1,1) → 紧贴右下确有 1px 纯 NAVY_900，但其外仍多出 1px 50% 透明的羽化带。
## 引擎只暴露 shadow_color / shadow_size / shadow_offset 三个开关，没有关闭羽化的手段，
## 而 shadow_size 同时决定「有没有阴影」和「羽化带多宽」，两者无法解耦。
## 因此改用 border + expand_margin：右下各 1px NAVY_900 描边，再用 expand_margin 推到矩形外侧。
## 实测该组合的羽化像素数为 0 —— 既满足「1px」也满足「不模糊」。
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
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.shadow_size = 0
	set_stylebox(&"panel", TYPE_PANEL_SHADOW, box)


## 高光层的**整圈**基底盒：四边各 1px 描边，不填中心，颜色只来自 Palette。
## 仅 `PanelSelected` 直接使用它；`PanelHighlight` 另需把右/下两边清零，见 _build_panel_highlight()。
func _highlight_box(token: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Palette.get_color(token)
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.shadow_size = 0
	return box


## 正文用 BLUE_100（04 §5.1 在 NAVY_800 上 11.75:1，首选）；
## 次要文字 GREY_300（06 §5）；危险小号文字 RED_400（04 §3.7）。
func _build_labels() -> void:
	set_color(&"font_color", BASE_TYPE_LABEL, Palette.get_color(Palette.Key.BLUE_100))
	set_type_variation(TYPE_LABEL_SECONDARY, BASE_TYPE_LABEL)
	set_color(&"font_color", TYPE_LABEL_SECONDARY, Palette.get_color(Palette.Key.GREY_300))
	set_type_variation(TYPE_LABEL_DANGER, BASE_TYPE_LABEL)
	set_color(&"font_color", TYPE_LABEL_DANGER, Palette.get_color(Palette.Key.RED_400))


func _button_box(fill: Palette.Key, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = _panel_box(fill, border)
	box.content_margin_left = CONTENT_MARGIN
	box.content_margin_top = CONTENT_MARGIN
	box.content_margin_right = CONTENT_MARGIN
	box.content_margin_bottom = CONTENT_MARGIN
	return box


## 06 §1：像素直角、无抗锯齿。
## 本盒**不设任何 shadow_\* 配置** —— 06 §2.2 v0.1.5 起面板自身不带阴影，硬阴影由
## TYPE_PANEL_SHADOW 叠层单独承载（见 _build_panel_shadow()）。此前这里残留的三行
## shadow_color / shadow_size / shadow_offset 是 S1-A 早期方案的遗迹，实测全部无效
## （shadow_size = 0 时引擎一个阴影像素都不画），留着只会被误读成「面板自带阴影」。
func _panel_box(fill: Palette.Key, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.get_color(fill)
	box.border_color = Palette.get_color(border)
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.content_margin_left = PANEL_CONTENT_MARGIN
	box.content_margin_top = PANEL_CONTENT_MARGIN
	box.content_margin_right = PANEL_CONTENT_MARGIN
	box.content_margin_bottom = PANEL_CONTENT_MARGIN
	return box
