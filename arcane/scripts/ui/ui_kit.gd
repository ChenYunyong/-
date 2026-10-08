## ui_kit.gd
## 职责：各屏共用的控件装配小工具（Label / Panel / Button / IconButton 的建立与尺寸）。
## 所属系统：ui
## 依赖：ArcaneTheme, IconButton, IconPainter, Fonts
## 禁止：本文件不得写入玩法逻辑、不得出现裸色值（颜色一律由 Theme 变体决定）。
##
## 为什么按钮宽度是算出来的而不是量出来的：各屏用的是**手工定位**（各屏的几何常量在
## EditorLayout 之类的文件里，测试要能断言「按钮排得下」），而 `get_combined_minimum_size()`
## 依赖主题与字体在树里解析完成，headless 下 SystemFont 取不到系统字体时会返回 0，
## 布局断言就失去意义。这里改用字宽估算：CJK 全角 = 1 个字宽，ASCII ≈ 0.6 个字宽，
## 与真实字形度量同量级且偏保守，headless 与真机得到同一个数。

class_name UiKit
extends RefCounted

## 全角字符的码点下界（CJK 统一表意文字从这里开始）。
const WIDE_CHAR_THRESHOLD: int = 0x2E80
## 窄字符（ASCII / 数字 / 标点）按多少个字宽算。
const NARROW_CHAR_UNITS: float = 0.6


## 一段文本占多少个「全角字宽」。纯估算，不查字体。
static func text_units(text: String) -> float:
	var units: float = 0.0
	for index: int in text.length():
		units += NARROW_CHAR_UNITS if text.unicode_at(index) < WIDE_CHAR_THRESHOLD else 1.0
	return units


## 按钮在给定文案下的宽度 = 文本宽度 + 两侧内边距。取整避免半像素描边糊掉。
static func button_width(text: String) -> float:
	return ceilf(text_units(text) * float(ArcaneTheme.BODY_FONT_SIZE)) + float(ArcaneTheme.BUTTON_CONTENT_MARGIN) * 2.0


## 按钮在给定文案下的高度 = 一行正文 + 上下内边距。
static func button_height() -> float:
	return float(ArcaneTheme.BODY_FONT_SIZE) + float(ArcaneTheme.BUTTON_CONTENT_MARGIN) * 2.0


## 建一个 Label。text 传**已 tr() 过**的文案（调用方负责走 key，见 06 §11）。
static func label(text: String, rect: Rect2, variation: StringName = &"") -> Label:
	var node: Label = Label.new()
	node.text = text
	if variation != &"":
		node.theme_type_variation = variation
	node.position = rect.position
	node.size = rect.size
	return node


## 建一个多行 Label。
##
## 它比 `label()` 多一道**进树后再钉尺寸**：`set_size()` 会把尺寸往上顶到
## `get_combined_minimum_size()`，而 Label 的最小宽在主题解析前后不是同一个数 ——
##   · 定量那一刻（还没进树、主题没解析）：AUTOWRAP_OFF 状态下它就是「整段排一行」的宽度；
##   · 进树之后（主题解析完、折行生效）：最小宽才回到 1。
## 引擎**只往大顶、从不缩回来**，所以顺序不对时那条 Label 就永远停在 490 宽（表列 384 作废）。
## PET-95 第 7 项复验量到的「英文冷进入 490×48」正是这一条：中文那句话短、顶不动 384，
## 切成英文（文本是后来改的，那时折行已经生效）也顶不动 —— 只有**建屏前就把 locale 设成 en**
## 才会露出来。`_add_pinned_label` 那类手工摆放的屏幕一直是「进树后再定量」，这里补上同一手。
static func wrapped_label(text: String, rect: Rect2, variation: StringName = &"") -> Label:
	var node: Label = label(text, rect, variation)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size = rect.size
	# tree_entered 在 NOTIFICATION_ENTER_TREE（主题在这一步解析）之后才发，故这里钉的尺寸是真的落得上去的。
	node.tree_entered.connect(func() -> void: node.size = rect.size, CONNECT_ONE_SHOT)
	return node


## 建一个面板。variation 取 ArcaneTheme 的 TYPE_PANEL_* 常量。
static func panel(variation: StringName, rect: Rect2) -> Panel:
	var node: Panel = Panel.new()
	node.theme_type_variation = variation
	node.position = rect.position
	node.size = rect.size
	return node


## 建一个按钮。text_key 是 tr() 的 key，尺寸按文案算好。
static func button(text_key: String, variation: StringName, handler: Callable) -> Button:
	# 静态函数里没有 Object 实例，故直接问 TranslationServer —— 与 Node.tr() 是同一条路径。
	var text: String = TranslationServer.translate(text_key)
	var node: Button = Button.new()
	node.text = text
	node.theme_type_variation = variation
	node.size = Vector2(button_width(text), button_height())
	if handler.is_valid():
		node.pressed.connect(handler)
	return node


## 把一个按钮摆到某个矩形的右侧、纵向居中，返回它的左边界（供下一个按钮接着往左排）。
static func place_right(button_node: Button, anchor: Rect2, cursor_right: float) -> float:
	var width: float = button_node.size.x
	var y: float = anchor.position.y + (anchor.size.y - button_node.size.y) * 0.5
	button_node.position = Vector2(cursor_right - width, y)
	return cursor_right - width


## 建一个图标控件。三处用它：头栏（40×32）· 书槽两端入口（24×48）· 浮层关闭键（24×24）——
## 各自的半径由调用方给，装配顺序（先 setup 再摆放）在这里统一，省得三处各写一遍。
## 尺寸**不在这里定**：它随用途变化，由调用方按 EditorLayout 的 rect 摆。
static func icon_button(variation: StringName, icon: IconPainter.Icon, radius: float,
		text_key: String, handler: Callable) -> IconButton:
	var node: IconButton = IconButton.new()
	node.theme_type_variation = variation
	node.icon_radius = radius
	# setup() 与 _ready() 无关：它要写 tooltip 与无障碍名，add_child() 前后都行。
	node.setup(icon, text_key)
	if handler.is_valid():
		node.pressed.connect(handler)
	return node
