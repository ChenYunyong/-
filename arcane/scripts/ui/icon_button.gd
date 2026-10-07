## icon_button.gd
## 职责：顶栏的**紧凑方形图标控件** —— 只有一个图标、没有文字，靠 tooltip 自报家门。
## 所属系统：ui
## 依赖：IconPainter, Palette, ArcaneTheme（变体名由调用方给）
## 禁止：本文件不得出现裸色值；不得自己画按钮底（底色 / 描边 / 禁用态一律走 Theme 变体）。
##
## PET-87 §3：撤销 / 删除 / 路线图原本是与「开始战斗」同级的文字大按钮，四个按钮长得一样重，
## 主次读不出来。改成一个文字主动作 + 三个方形图标控件之后：
##   · 「开始战斗」是顶栏唯一的强主动作（金色 ButtonPrimary）；
##   · 另外三个是 48×48 的次级图标控件，靠**图标**认，靠 **tooltip** 说全名。
##
## 图标画在**子控件**上而不是本控件的 _draw() 里：Button 的 C++ 侧要在 NOTIFICATION_DRAW 时
## 画 stylebox 与文字，脚本 _draw() 与它谁先谁后不是本项目能保证的事；子节点后画则是引擎保证的。

class_name IconButton
extends Button

## 图标半径（逻辑像素）。48×48 的控件里留出四周呼吸位。
const ICON_RADIUS: float = 11.0

var _icon: IconPainter.Icon = IconPainter.Icon.NONE
var _surface: Control = null


## 绑定图标与文案 key。文案只用于 tooltip 与无障碍名 —— 控件上不显示文字。
## 必须在 add_child() **之前或之后**调用都可以：图标存在按钮自己身上，绘制时才读。
func setup(icon: IconPainter.Icon, text_key: String) -> void:
	_icon = icon
	var text: String = TranslationServer.translate(text_key)
	tooltip_text = text
	# 没有文字标签的控件必须能被读屏念出来（godot-ui：no_accessible_name）。
	accessibility_name = text
	refresh()


func icon() -> IconPainter.Icon:
	return _icon


func _ready() -> void:
	_surface = _Surface.new()
	_surface.host = self
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	# 全铺父控件。必须用 set_anchors_and_offsets_preset —— 只设 anchors 会保留旧 offset，
	# 子控件尺寸不会跟着父控件走。
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_entered.connect(refresh)
	mouse_exited.connect(refresh)


## 状态变了（尤其是 disabled）之后重画一次图标。disabled 是内建属性，没有变更信号，
## 因此由 editor 在 _refresh() 里显式调用 —— 比每帧轮询便宜，也比忘记重画安全。
func refresh() -> void:
	if _surface != null:
		_surface.queue_redraw()


## 图标层。单独一个 Control 是为了拿到「画在按钮底之上」这个保证。
class _Surface:
	extends Control

	var host: IconButton = null

	func _draw() -> void:
		if host == null:
			return
		IconPainter.paint(self, host.icon(), size * 0.5, IconButton.ICON_RADIUS, _tint())

	## 图标色。三种状态各自取 Token：常态正文蓝、悬停提亮、禁用灰。
	## disabled 必须与常态分得开 —— 撤销栈空着时按不动，这件事要看得见。
	func _tint() -> Color:
		if host.disabled:
			return Palette.get_color(Palette.Key.GREY_500)
		if host.is_hovered():
			return Palette.get_color(Palette.Key.BLUE_050)
		return Palette.get_color(Palette.Key.BLUE_100)
