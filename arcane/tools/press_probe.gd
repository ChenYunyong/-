## press_probe.gd
## 职责：实测「按钮按下态内容下移 N」与 StyleBox 上内边距的真实关系 —— docs/14 §2.4 的那条数。
## 所属系统：tools
## 依赖：ContractTheme, Palette
## 禁止：本文件不得修改任何工程状态；只读、只打印。**必须非 headless 运行**（要真的出像素）。
##
## 为什么需要它：§2.4 要的是「按下内容下移 2px」，而 Button 把文字在「尺寸 − 内容边距」里居中，
## 上内边距只有**一半**变成向下的位移 —— 直接把内边距写 2 只下移 1px。下表是实测定出来的：
##   上内边距 0 → 位移 0 · 1 → 0 · 2 → 1 · 4 → 2。
## ContractTheme.PRESS_CONTENT_MARGIN 就是照它取的（2 × PRESS_SHIFT）。
##
## 用法（在 arcane/ 工程根目录下，**不要**加 --headless）：
##   godot --path . --script res://tools/press_probe.gd

extends SceneTree

const MARGINS: Array = [[0.0, 0.0], [2.0, 0.0], [4.0, 0.0], [2.0, -2.0]]
const ROW_Y: float = 60.0
const ROW_STEP: float = 80.0
const BTN_X: float = 100.0
const BTN_W: float = 312.0
const BTN_H: float = 56.0


func _initialize() -> void:
	await process_frame
	var win: Window = get_root()
	win.size = Vector2i(960, 540)
	var theme: Theme = load("res://assets/ui/theme_main.tres")
	var holder: Control = Control.new()
	holder.size = Vector2(960.0, 540.0)
	win.add_child(holder)
	holder.add_child(_panel(Palette.Key.NAVY_900, Rect2(0.0, 0.0, 960.0, 540.0)))
	for index: int in MARGINS.size():
		holder.add_child(_button(theme, Rect2(BTN_X, ROW_Y + float(index) * ROW_STEP,
			BTN_W, BTN_H), float(MARGINS[index][0]), float(MARGINS[index][1])))
	await process_frame
	await process_frame
	await process_frame
	var image: Image = win.get_texture().get_image()
	var base: int = 0
	for index: int in MARGINS.size():
		var y: int = int(ROW_Y + float(index) * ROW_STEP)
		var rows: Vector2i = _ink_rows(image, int(BTN_X), y, int(BTN_W), int(BTN_H))
		var baseline: int = _ink_rows(image, int(BTN_X), int(ROW_Y), int(BTN_W), int(BTN_H)).x
		if index == 0:
			base = rows.x
		print("MARGIN top=%.1f bottom=%.1f ink=%d shift=%d" % [float(MARGINS[index][0]),
			float(MARGINS[index][1]), rows.x, rows.x - base - index * int(ROW_STEP)])
	quit(0)


func _panel(fill: Palette.Key, rect: Rect2) -> Panel:
	var node: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.get_color(fill)
	box.set_content_margin_all(0.0)
	node.add_theme_stylebox_override(&"panel", box)
	node.position = rect.position
	node.size = rect.size
	return node


## 一颗金底主按钮；上下 content margin 直接写进样式盒（模拟按下态的那一版）。
func _button(theme: Theme, rect: Rect2, top_margin: float, bottom_margin: float) -> Button:
	var node: Button = Button.new()
	node.theme = theme
	node.text = "NEW RUN"
	node.theme_type_variation = ContractTheme.TYPE_BUTTON_PAGE_PRIMARY
	node.position = rect.position
	node.size = rect.size
	var box: StyleBoxFlat = _copy(theme.get_stylebox(&"normal",
		ContractTheme.TYPE_BUTTON_PAGE_PRIMARY) as StyleBoxFlat)
	box.set_content_margin(SIDE_TOP, top_margin)
	box.set_content_margin(SIDE_BOTTOM, bottom_margin)
	node.add_theme_stylebox_override(&"normal", box)
	node.add_theme_color_override(&"font_color", Palette.get_color(Palette.Key.NAVY_900))
	return node


func _copy(source: StyleBoxFlat) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = source.bg_color
	box.border_color = source.border_color
	box.set_border_width_all(int(source.border_width_top))
	box.set_corner_radius_all(source.corner_radius_top_left)
	box.anti_aliasing = false
	box.set_content_margin_all(0.0)
	return box


## 该矩形里「深墨字」的行号范围（墨是 NAVY_900，金底是亮的）。
## 只扫中间那一段 x —— 圆角处露出来的深色背景会把边缘行也算成「有墨」。
func _ink_rows(image: Image, x: int, y: int, w: int, h: int) -> Vector2i:
	var first: int = -1
	var last: int = -1
	for row: int in range(y, y + h):
		var dark: int = 0
		for col: int in range(x + 40, x + w - 40):
			var c: Color = image.get_pixel(col, row)
			if c.r < 0.25 and c.g < 0.25 and c.b < 0.35:
				dark += 1
		if dark >= 3:
			if first < 0:
				first = row
			last = row
	return Vector2i(first, last)
