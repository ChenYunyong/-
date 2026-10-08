## contract_theme.gd
## 职责：docs/14 §1/§2.1/§3 的 Theme 变体层 —— 契约的纸、深浮层、字号阶梯与纸面按钮。
## 所属系统：data
## 依赖：Palette（唯一色值来源）
## 禁止：本文件不得出现任何字面色值；不得新增 Palette.Key（契约 §3 只允许既有 35 色的映射）。
##
## 为什么与 arcane_theme.gd 分两支：那一支里的 ×3 常量（边距 24 / 描边 3 / 字号 24-30）是 PET-85
## 的旧基准，路线图、战斗、主菜单三屏还在用。契约要求**一次一屏、一屏一提交**，所以这一层只
## **新增**变体、不覆盖旧变体 —— 否则改第一屏就会顺手把另外三屏一起改掉。
## 第一屏（书页卡牌画布）落地后其余三屏逐屏搬过来，搬完这一支就是四屏共用的那张角色表。
##
## §3 的取色只走「视觉角色 → 既有 Token」：羊皮纸面 GOLD_200、纸边 8px 边带 WARM_500、
## 纸面折影 BROWN_300 / 书脊 BROWN_700+BROWN_600、深面板 NAVY_800、关键边 GREY_300、
## 材质上左高光 GOLD_200、按下内嵌暗边 NAVY_600。

@tool
class_name ContractTheme
extends RefCounted

## §1 的材质几何：圆角 4、普通轮廓 1、纸框材质边带 8。
const CORNER_RADIUS: int = 4
const HAIRLINE: int = 1
const PAGE_BAND: int = 8
## §1 的字号阶梯。正文与屏标题相差 8 —— G05 量的就是这个差。
const FONT_BODY: int = 16
const FONT_CAPTION: int = 12
const FONT_BUTTON: int = 20
const FONT_TITLE: int = 24
## §1 的两组投影。**方向固定为右下**（G08：阴影重心相对物体 Δx>0、Δy>0）。
const CARD_SHADOW_OFFSET: Vector2 = Vector2(2.0, 4.0)
const CARD_SHADOW_SIZE: int = 4
const CARD_SHADOW_ALPHA: float = 0.22
const BOOK_SHADOW_OFFSET: Vector2 = Vector2(4.0, 8.0)
const BOOK_SHADOW_SIZE: int = 8
const BOOK_SHADOW_ALPHA: float = 0.28
## §3「纸纹/地图装饰墨 alpha≤0.08」—— 折痕、书脊折影这类**装饰**纹样都取这个上界。
const DECOR_ALPHA: float = 0.08
## §2.4 的按下态：**内容下移 2**、内嵌暗边 1（见 apply_press 的实测表）。
const PRESS_SHIFT: float = 2.0
## 样式盒要写的上内边距。**不是** PRESS_SHIFT 本身：Button 把文字在「尺寸 − 内容边距」里居中，
## 上内边距只有一半变成向下的位移。真渲染实测（tools/press_probe.gd，960×540）：
##   上内边距 0 → 位移 0 · 1 → 0 · 2 → 1 · 4 → 2。
## 故写 2 × PRESS_SHIFT 才真的下移 2px；下内边距不动，内容区高度因此不变。
const PRESS_CONTENT_MARGIN: float = PRESS_SHIFT * 2.0

## 变体名。屏①（编辑器）用到的全部在此；后续三屏按同一张角色表继续往这里加。
const TYPE_BACKDROP: StringName = &"Backdrop"
const TYPE_PAGE_BAND: StringName = &"PageBand"
const TYPE_PAGE_LEAF: StringName = &"PageLeaf"
const TYPE_PAGE_HILIGHT: StringName = &"PageHilight"
const TYPE_PAGE_SPINE: StringName = &"PageSpine"
const TYPE_POPOVER: StringName = &"CardPopover"
const TYPE_LABEL_DETAIL_NAME: StringName = &"LabelDetailName"
const TYPE_LABEL_BODY: StringName = &"LabelBody"
const TYPE_LABEL_BODY_MUTED: StringName = &"LabelBodyMuted"
const TYPE_LABEL_CAPTION_DANGER: StringName = &"LabelCaptionDanger"
const TYPE_BUTTON_PAGE_PRIMARY: StringName = &"ButtonPagePrimary"
const TYPE_BUTTON_PAGE_ICON: StringName = &"ButtonPageIcon"
## 屏②的次按钮（§2.2 MAP_BACK，16/24）。与 ButtonPageIcon 同一张 NAVY 填色表，但那一支是
## **无文字图标控件**（scene_smoke 钉着「图标控件不含文字」），带文字的次按钮不能借它的名。
const TYPE_BUTTON_DARK_SECONDARY: StringName = &"ButtonDarkSecondary"

const BASE_TYPE_PANEL: StringName = &"Panel"
const BASE_TYPE_LABEL: StringName = &"Label"
const BASE_TYPE_BUTTON: StringName = &"Button"


## 把契约层装进宿主主题。ArcaneTheme.apply_palette() 里调一次 —— 那里已有全部旧变体的落点。
static func apply(theme: Theme) -> void:
	_build_backdrop(theme)
	_build_page(theme)
	_build_popover(theme)
	_build_labels(theme)
	_build_buttons(theme)


## 全屏暗背景。**存在的理由是 G06**：不铺满这一层，书页之外的区域露的就是引擎默认灰 RGB(76,76,76)。
## 它必须是最先加进场景的那个兄弟节点，否则会盖住后面所有东西。
static func _build_backdrop(theme: Theme) -> void:
	theme.set_type_variation(TYPE_BACKDROP, BASE_TYPE_PANEL)
	theme.set_stylebox(&"panel", TYPE_BACKDROP, _flat(Palette.Key.NAVY_900, 0))


## 书页三层：外框（8px 暖色边带）+ 净纸（亮纸面）+ 来光/折影。
##
## 三层各自单独一个变体，而不是一个变体画完 —— StyleBoxFlat 一个状态只有一支 border_color，
## 而 G08 要的正是**上左与下右不同**：上左是受光的 WARM_300，下右是折影的 BROWN_300。
static func _build_page(theme: Theme) -> void:
	theme.set_type_variation(TYPE_PAGE_BAND, BASE_TYPE_PANEL)
	var band: StyleBoxFlat = _flat(Palette.Key.GOLD_200, CORNER_RADIUS)
	band.border_color = Palette.get_color(Palette.Key.WARM_500)
	band.set_border_width_all(PAGE_BAND)
	# §1 书本投影：偏移 (4,8) / 模糊 8 / alpha 0.28。
	band.shadow_color = _tinted(Palette.Key.NAVY_900, BOOK_SHADOW_ALPHA)
	band.shadow_size = BOOK_SHADOW_SIZE
	band.shadow_offset = BOOK_SHADOW_OFFSET
	theme.set_stylebox(&"panel", TYPE_PAGE_BAND, band)

	theme.set_type_variation(TYPE_PAGE_LEAF, BASE_TYPE_PANEL)
	var leaf: StyleBoxFlat = _flat(Palette.Key.GOLD_200, CORNER_RADIUS)
	leaf.border_color = _tinted(Palette.Key.BROWN_300, DECOR_ALPHA)
	leaf.border_width_top = 0
	leaf.border_width_left = 0
	leaf.border_width_right = HAIRLINE
	leaf.border_width_bottom = HAIRLINE
	theme.set_stylebox(&"panel", TYPE_PAGE_LEAF, leaf)

	theme.set_type_variation(TYPE_PAGE_HILIGHT, BASE_TYPE_PANEL)
	var lit: StyleBoxFlat = _flat(Palette.Key.GOLD_200, CORNER_RADIUS)
	lit.draw_center = false
	lit.border_color = Palette.get_color(Palette.Key.WARM_300)
	lit.border_width_top = HAIRLINE
	lit.border_width_left = HAIRLINE
	lit.border_width_right = 0
	lit.border_width_bottom = 0
	theme.set_stylebox(&"panel", TYPE_PAGE_HILIGHT, lit)

	# 书脊：16px 中带的**折影**，不是一条实心暗杠（§2.1 原话「两侧低对比折影；纯装饰」）。
	# 取色按 §3 的角色表：书脊 / 皮革走 **BROWN_700 底 + BROWN_600 折影线**
	# （PET-95 记作「书脊 Token 偏离契约」）；BROWN_400 / BROWN_300 是「边带 / 纸纹」那一行，
	# 不属于书脊。alpha 仍取装饰上界，故底与折影只差一档、读起来是折影不是暗杠。
	theme.set_type_variation(TYPE_PAGE_SPINE, BASE_TYPE_PANEL)
	var spine: StyleBoxFlat = _flat_tinted(Palette.Key.BROWN_700, DECOR_ALPHA, 0)
	spine.border_color = _tinted(Palette.Key.BROWN_600, DECOR_ALPHA)
	spine.border_width_left = HAIRLINE
	spine.border_width_right = HAIRLINE
	theme.set_stylebox(&"panel", TYPE_PAGE_SPINE, spine)


## 卡片详情浮层。§3 的深面板角色：NAVY_800 底 + GREY_300 关键边（它浮在亮纸上，边必须读得出）。
static func _build_popover(theme: Theme) -> void:
	theme.set_type_variation(TYPE_POPOVER, BASE_TYPE_PANEL)
	var box: StyleBoxFlat = _flat(Palette.Key.NAVY_800, CORNER_RADIUS)
	box.border_color = Palette.get_color(Palette.Key.GREY_300)
	box.set_border_width_all(HAIRLINE)
	box.shadow_color = _tinted(Palette.Key.NAVY_900, CARD_SHADOW_ALPHA)
	box.shadow_size = CARD_SHADOW_SIZE
	box.shadow_offset = CARD_SHADOW_OFFSET
	theme.set_stylebox(&"panel", TYPE_POPOVER, box)


## §1 的四个字号档。屏标题走主题的 default_font_size（24，就是这一档），故此处不另开变体。
static func _build_labels(theme: Theme) -> void:
	# 详情名：深面板上唯一的暖色标题。GOLD_400 / NAVY_800 = 8.46:1（≥4.5，标题另计 ≥3）。
	# 它同时挂 ContractFont.tightened()：英文最长的一张卡名 `Projectile Count` 在 24 号上
	# 实测宽 183 > 176（表列 DETAIL_NAME 宽），会伸进收起键的框里 3px。§1 不许截断、
	# 不许缩字号（G05 要 24 − 16 = 8），故按 §1 给的是**字距**口径。
	theme.set_type_variation(TYPE_LABEL_DETAIL_NAME, BASE_TYPE_LABEL)
	theme.set_font(&"font", TYPE_LABEL_DETAIL_NAME, ContractFont.tightened())
	theme.set_font_size(&"font_size", TYPE_LABEL_DETAIL_NAME, FONT_TITLE)
	theme.set_color(&"font_color", TYPE_LABEL_DETAIL_NAME, Palette.get_color(Palette.Key.GOLD_400))
	# 正文：卡墨 BLUE_100 / NAVY_800 = 11.75:1。
	theme.set_type_variation(TYPE_LABEL_BODY, BASE_TYPE_LABEL)
	theme.set_font_size(&"font_size", TYPE_LABEL_BODY, FONT_BODY)
	theme.set_color(&"font_color", TYPE_LABEL_BODY, Palette.get_color(Palette.Key.BLUE_100))
	# 副墨：GREY_300 / NAVY_800 = 9.37:1。顶栏计数行也用它（同样落在暗底上）。
	theme.set_type_variation(TYPE_LABEL_BODY_MUTED, BASE_TYPE_LABEL)
	theme.set_font_size(&"font_size", TYPE_LABEL_BODY_MUTED, FONT_BODY)
	theme.set_color(&"font_color", TYPE_LABEL_BODY_MUTED, Palette.get_color(Palette.Key.GREY_300))
	# 说明：12/20 档，暗底小字用 RED_400（RED_500 只画血条，§3）。
	theme.set_type_variation(TYPE_LABEL_CAPTION_DANGER, BASE_TYPE_LABEL)
	theme.set_font_size(&"font_size", TYPE_LABEL_CAPTION_DANGER, FONT_CAPTION)
	theme.set_color(&"font_color", TYPE_LABEL_CAPTION_DANGER, Palette.get_color(Palette.Key.RED_400))


## §3 的两支按钮。主按钮的金色三态 + 次按钮的 NAVY 三态都是既有映射，这里只补**契约字号 20**。
##
## 两支都**不留内边距**，尺寸整份由 §2.1 的 rect 给死。这是 G02 第三条「宽高不能由字体撑开」
## 要求的：Button 的最小尺寸 = 内容 + 内边距，留了内边距就等于把尺寸交给字体去定 ——
## 给 14 的话，图标控件的最小边长变成 28（§2.1 要的是 24，实测被顶宽 4px），
## 主按钮的最小高变成字体行高 28 + 28 = 56（表列要的是 48，实测被顶高 8px）。
## 字号仍然管着文字自己多大，只是不再管控件多大；文字在盒子里居中，视觉上与内边距等效。
##
## PET-97 补的是 §2.4 的**按下态**：按下内容下移 2 + 内嵌暗边 1。它原来只有「换一档金底」，
## 内边距与边都没动 —— 按下去与常态长得一样，玩家读不到「这一下按下去了」。
static func _build_buttons(theme: Theme) -> void:
	theme.set_type_variation(TYPE_BUTTON_PAGE_PRIMARY, BASE_TYPE_BUTTON)
	for state: Dictionary in [
		{"slot": &"normal", "fill": Palette.Key.GOLD_500, "edge": Palette.Key.GOLD_600},
		{"slot": &"hover", "fill": Palette.Key.GOLD_200, "edge": Palette.Key.GOLD_600},
		{"slot": &"pressed", "fill": Palette.Key.GOLD_600, "edge": Palette.Key.NAVY_600},
		{"slot": &"disabled", "fill": Palette.Key.NAVY_800, "edge": Palette.Key.GOLD_600},
		{"slot": &"focus", "fill": Palette.Key.GOLD_500, "edge": Palette.Key.GOLD_600},
	]:
		var box: StyleBoxFlat = _button_box(state["fill"], state["edge"])
		if state["slot"] == &"pressed":
			box.set_content_margin(SIDE_TOP, PRESS_CONTENT_MARGIN)
		theme.set_stylebox(state["slot"], TYPE_BUTTON_PAGE_PRIMARY, box)
	var ink: Color = Palette.get_color(Palette.Key.NAVY_900)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		theme.set_color(slot, TYPE_BUTTON_PAGE_PRIMARY, ink)
	theme.set_color(&"font_disabled_color", TYPE_BUTTON_PAGE_PRIMARY,
		Palette.get_color(Palette.Key.GREY_500))
	theme.set_font_size(&"font_size", TYPE_BUTTON_PAGE_PRIMARY, FONT_BUTTON)

	theme.set_type_variation(TYPE_BUTTON_PAGE_ICON, BASE_TYPE_BUTTON)
	for state: Dictionary in [
		{"slot": &"normal", "fill": Palette.Key.NAVY_800},
		{"slot": &"hover", "fill": Palette.Key.NAVY_700},
		{"slot": &"pressed", "fill": Palette.Key.NAVY_900},
		{"slot": &"disabled", "fill": Palette.Key.NAVY_800},
		{"slot": &"focus", "fill": Palette.Key.NAVY_700},
	]:
		theme.set_stylebox(state["slot"], TYPE_BUTTON_PAGE_ICON,
			_button_box(state["fill"], Palette.Key.GREY_300))

	# 带文字的次按钮。同一张 NAVY 三态 + GREY_300 关键边（§3「次按钮 NAVY_800 / NAVY_700 /
	# NAVY_900 + 墨 BLUE_100 + 边 GREY_300」），只有字号与图标控件不同：§2.2 给的是 16/24。
	theme.set_type_variation(TYPE_BUTTON_DARK_SECONDARY, BASE_TYPE_BUTTON)
	for state: Dictionary in [
		{"slot": &"normal", "fill": Palette.Key.NAVY_800},
		{"slot": &"hover", "fill": Palette.Key.NAVY_700},
		{"slot": &"pressed", "fill": Palette.Key.NAVY_900},
		{"slot": &"disabled", "fill": Palette.Key.NAVY_800},
		{"slot": &"focus", "fill": Palette.Key.NAVY_700},
	]:
		theme.set_stylebox(state["slot"], TYPE_BUTTON_DARK_SECONDARY,
			_button_box(state["fill"], Palette.Key.GREY_300))
	var dim: Color = Palette.get_color(Palette.Key.BLUE_100)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		theme.set_color(slot, TYPE_BUTTON_DARK_SECONDARY, dim)
	theme.set_color(&"font_disabled_color", TYPE_BUTTON_DARK_SECONDARY,
		Palette.get_color(Palette.Key.GREY_500))
	theme.set_font_size(&"font_size", TYPE_BUTTON_DARK_SECONDARY, FONT_BODY)


# ---------------------------------------------------------------- 工具

## 契约的材质底面：圆角 4、无抗锯齿（像素风）、内容内缩 0（这些矩形一律由 §2 的几何表给死）。
static func _flat(fill: Palette.Key, radius: int) -> StyleBoxFlat:
	return _flat_tinted(fill, 1.0, radius)


static func _flat_tinted(fill: Palette.Key, alpha: float, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _tinted(fill, alpha)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	box.set_content_margin_all(0.0)
	return box


## 按钮底面 = 材质底面 + 1px 普通轮廓，**不带内边距**（理由见 _build_buttons 的文件头一段）。
static func _button_box(fill: Palette.Key, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = _flat(fill, CORNER_RADIUS)
	box.border_color = Palette.get_color(border)
	box.set_border_width_all(HAIRLINE)
	return box


## 给一个 Token 加装饰用 alpha。**色相仍来自 Palette** —— 这里不引入任何新色。
static func _tinted(key: Palette.Key, alpha: float) -> Color:
	var color: Color = Palette.get_color(key)
	color.a = alpha
	return color
