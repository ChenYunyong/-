## contract_screen_theme.gd
## 职责：docs/14 §2.3/§2.4 两屏（③ 战斗 / ④ 主菜单）新增的 Theme 变体 —— 三块深面板、四支字、一支 20/28 次入口。
## 所属系统：data
## 依赖：Palette（唯一色值来源）、ContractTheme（§1 的圆角 / 描边 / 字号档）
## 禁止：本文件不得出现任何字面色值；不得覆盖 contract_theme.gd 的既有变体（屏①②已入库并复核）；
##       不得引用节点 / 场景 —— 它只往宿主 Theme 里装变体。
##
## 为什么与 contract_theme.gd 分两支：那一支是屏①②的变体层，源码有 300 行上限，③④ 这九个变体挤不进去。
## 两支合起来才是「四屏共用的那张角色表」，由 ArcaneTheme.apply_palette() 依次装入。
##
## 取色逐字来自 §3：深面板 NAVY_800、凹陷底与条槽 NAVY_900、普通框 1px GREY_300、核心框 1px GOLD_600、
## 当前施法强调 GOLD_500、亮纸上的小字一律墨色 BROWN_700。三块面板都**不带投影** —— 它们是屏内的分区，
## 不是浮层。④ 的四入口与设置开关是 20/28，与屏② 的 16/24 同族不同档，不能互相借用。

class_name ContractScreenTheme
extends RefCounted

## §2.4 的菜单 Logo 档（36/48）—— 全工程唯一一处比屏标题还大的字号。
const FONT_LOGO: int = 36

## 变体名。屏③④ 用到的全部在此。
const TYPE_PANEL_DARK_GOLD: StringName = &"PanelDarkGold"
const TYPE_PANEL_DARK_SILVER: StringName = &"PanelDarkSilver"
const TYPE_PANEL_SUNK: StringName = &"PanelSunk"
const TYPE_LABEL_ACTIVE: StringName = &"LabelActive"
const TYPE_LABEL_CAPTION: StringName = &"LabelCaption"
const TYPE_LABEL_LOGO: StringName = &"LabelLogo"
const TYPE_LABEL_PAGE_CAPTION: StringName = &"LabelPageCaption"
const TYPE_BUTTON_DARK_ENTRY: StringName = &"ButtonDarkEntry"

const BASE_TYPE_PANEL: StringName = &"Panel"
const BASE_TYPE_LABEL: StringName = &"Label"
const BASE_TYPE_BUTTON: StringName = &"Button"


## 把这一层装进宿主主题。由 ArcaneTheme.apply_palette() 在 ContractTheme 之后调一次 ——
## 顺序不影响结果（两边变体名不重叠），但先①后③④读起来与屏幕顺序一致。
static func apply(theme: Theme) -> void:
	_dark_panel(theme, TYPE_PANEL_DARK_GOLD, Palette.Key.NAVY_800, Palette.Key.GOLD_600)
	_dark_panel(theme, TYPE_PANEL_DARK_SILVER, Palette.Key.NAVY_800, Palette.Key.GREY_300)
	_dark_panel(theme, TYPE_PANEL_SUNK, Palette.Key.NAVY_900, Palette.Key.GREY_300)
	# 当前施法名 20/28（§3「当前施法强调 GOLD_500」）；12/20 的结算行与队列摘要走 GREY_300（9.37:1）。
	_label(theme, TYPE_LABEL_ACTIVE, ContractTheme.FONT_BUTTON, Palette.Key.GOLD_500)
	_label(theme, TYPE_LABEL_CAPTION, ContractTheme.FONT_CAPTION, Palette.Key.GREY_300)
	_label(theme, TYPE_LABEL_LOGO, FONT_LOGO, Palette.Key.GOLD_200)
	_label(theme, TYPE_LABEL_PAGE_CAPTION, ContractTheme.FONT_CAPTION, Palette.Key.BROWN_700)
	_build_dark_entry(theme)


## 一块深面板。与 ContractTheme.TYPE_POPOVER 同一套材质，只少了投影。
static func _dark_panel(theme: Theme, name: StringName, fill: Palette.Key,
		border: Palette.Key) -> void:
	theme.set_type_variation(name, BASE_TYPE_PANEL)
	theme.set_stylebox(&"panel", name, _box(fill, border))


## 一条只有字号与墨色的文字变体。
static func _label(theme: Theme, name: StringName, size: int, ink: Palette.Key) -> void:
	theme.set_type_variation(name, BASE_TYPE_LABEL)
	theme.set_font_size(&"font_size", name, size)
	theme.set_color(&"font_color", name, Palette.get_color(ink))


## §2.4 的四入口与设置开关。同一个 rect、同一张 NAVY 三态 + GREY_300 普通边 + BLUE_100 墨。
## 按下态另给：内容下移 2 + 1px 内嵌暗边（NAVY_600，§3 的深面板细分隔）—— 尺寸早被 rect 给死，
## 压下只是文字自己下一格，按钮不挪，也不改变任何布局。
static func _build_dark_entry(theme: Theme) -> void:
	theme.set_type_variation(TYPE_BUTTON_DARK_ENTRY, BASE_TYPE_BUTTON)
	for state: Dictionary in [
		{"slot": &"normal", "fill": Palette.Key.NAVY_800, "edge": Palette.Key.GREY_300},
		{"slot": &"hover", "fill": Palette.Key.NAVY_700, "edge": Palette.Key.GREY_300},
		{"slot": &"pressed", "fill": Palette.Key.NAVY_900, "edge": Palette.Key.NAVY_600},
		{"slot": &"disabled", "fill": Palette.Key.NAVY_800, "edge": Palette.Key.GREY_300},
		{"slot": &"focus", "fill": Palette.Key.NAVY_700, "edge": Palette.Key.GREY_300},
	]:
		var box: StyleBoxFlat = _box(state["fill"], state["edge"])
		if state["slot"] == &"pressed":
			box.set_content_margin(SIDE_TOP, 2.0)
		theme.set_stylebox(state["slot"], TYPE_BUTTON_DARK_ENTRY, box)
	var dim: Color = Palette.get_color(Palette.Key.BLUE_100)
	for slot: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		theme.set_color(slot, TYPE_BUTTON_DARK_ENTRY, dim)
	theme.set_color(&"font_disabled_color", TYPE_BUTTON_DARK_ENTRY,
		Palette.get_color(Palette.Key.GREY_500))
	theme.set_font_size(&"font_size", TYPE_BUTTON_DARK_ENTRY, ContractTheme.FONT_BUTTON)


# ---------------------------------------------------------------- 工具

## 契约的材质底面：圆角 4、无抗锯齿（像素风）、内容内缩 0。
##
## 内缩 0 是 G02 第三条「宽高不能由字体撑开」要求的：Button 的最小尺寸 = 内容 + 内边距，
## 留了内边距就等于把尺寸交给字体去定（ContractTheme._build_buttons 里有实测数字）。
## 字号仍然管着文字自己多大，只是不再管控件多大；文字在盒子里居中，视觉上与内边距等效。
static func _box(fill: Palette.Key, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.get_color(fill)
	box.set_corner_radius_all(ContractTheme.CORNER_RADIUS)
	box.anti_aliasing = false
	box.set_content_margin_all(0.0)
	box.border_color = Palette.get_color(border)
	box.set_border_width_all(ContractTheme.HAIRLINE)
	return box
