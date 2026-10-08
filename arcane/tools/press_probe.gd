## press_probe.gd
## 职责：实测 §2.4 的「按下态内容下移 2px」—— 把 Theme 里那两支**真**样式盒（normal / pressed）
##       各摆一颗金底主按钮，量文字行在屏上的真实位移。
## 所属系统：tools
## 依赖：ContractTheme, Palette
## 禁止：本文件不得修改任何工程状态；只读、只打印。**必须非 headless 运行**（要真的出像素）。
##
## 为什么需要它：§2.4 要的是「内容下移 2」，而 Button 把文字在「尺寸 − 内容边距」里居中，
## 上内边距只有**一半**变成向下的位移 —— 直接把内边距写 2 只会下移 1px。实测（见下表）：
##   上内边距 0 → 位移 0 · 1 → 0 · 2 → 1 · 4 → 2。
## ContractTheme.PRESS_CONTENT_MARGIN = 2 × PRESS_SHIFT 就是照它取的。
##
## 输出里两行 `STATE ...` 的 `ink_top` 之差就是本条要的那个数；`shift` 是折半之后的可见位移。
##
## 用法（在 arcane/ 工程根目录下，**不要**加 --headless）：
##   godot --path . --script res://tools/press_probe.gd

extends SceneTree

const BTN_X: float = 100.0
const BTN_W: float = 312.0
const BTN_H: float = 56.0
const ROW_Y: float = 100.0
const ROW_STEP: float = 120.0


func _initialize() -> void:
	await process_frame
	var win: Window = get_root()
	win.size = Vector2i(960, 540)
	var theme: Theme = load("res://assets/ui/theme_main.tres")
	var holder: Control = Control.new()
	holder.size = Vector2(960.0, 540.0)
	win.add_child(holder)
	holder.add_child(_panel(Palette.Key.NAVY_900, Rect2(0.0, 0.0, 960.0, 540.0)))
	# 两颗按钮：一颗用常态样式盒，一颗用**按下态**样式盒（Button 的 is_pressed 只能由真按驱动，
	# 要逐像素对照就得把那一支直接摆上来）。
	for index: int in 2:
		holder.add_child(_button(theme, &"normal" if index == 0 else &"pressed",
			Rect2(BTN_X, ROW_Y + float(index) * ROW_STEP, BTN_W, BTN_H)))
	await process_frame
	await process_frame
	await process_frame
	var image: Image = win.get_texture().get_image()
	var normal_top: int = _ink_rows(image, int(ROW_Y)).x
	var pressed_top: int = _ink_rows(image, int(ROW_Y + ROW_STEP)).x
	for index: int in 2:
		var slot: StringName = &"normal" if index == 0 else &"pressed"
		var box: StyleBoxFlat = theme.get_stylebox(slot, ContractTheme.TYPE_BUTTON_PAGE_PRIMARY) as StyleBoxFlat
		print("STATE %s margin_top=%.0f margin_bottom=%.0f border=%s width=%d ink_top=%d" % [
			slot, box.get_margin(SIDE_TOP), box.get_margin(SIDE_BOTTOM),
			str(box.border_color), box.border_width_top,
			_ink_rows(image, int(ROW_Y + float(index) * ROW_STEP)).x])
	print("SHIFT ink_top %d → %d = %d px（§2.4 要的是 %.0f）" % [
		normal_top, pressed_top, pressed_top - normal_top - int(ROW_STEP), ContractTheme.PRESS_SHIFT])
	print("PRESS_SHIFT=%.0f PRESS_CONTENT_MARGIN=%.0f" % [
		ContractTheme.PRESS_SHIFT, ContractTheme.PRESS_CONTENT_MARGIN])
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


## 一颗金底主按钮，底色直接取 Theme 里那一支状态盒（不改它，只拿来看）。
func _button(theme: Theme, slot: StringName, rect: Rect2) -> Button:
	var node: Button = Button.new()
	node.theme = theme
	node.text = "NEW RUN"
	node.theme_type_variation = ContractTheme.TYPE_BUTTON_PAGE_PRIMARY
	node.position = rect.position
	node.size = rect.size
	node.add_theme_stylebox_override(&"normal", theme.get_stylebox(slot,
		ContractTheme.TYPE_BUTTON_PAGE_PRIMARY))
	node.add_theme_color_override(&"font_color", Palette.get_color(Palette.Key.NAVY_900))
	return node


## 金底上「深墨字」的行号范围（墨是 NAVY_900）。只扫中间那一段 x —— 圆角处露出来的深色背景
## 会把边缘行也算成「有墨」。
func _ink_rows(image: Image, y: int) -> Vector2i:
	var first: int = -1
	var last: int = -1
	for row: int in range(y, y + int(BTN_H)):
		var dark: int = 0
		for col: int in range(int(BTN_X) + 40, int(BTN_X + BTN_W) - 40):
			var c: Color = image.get_pixel(col, row)
			if c.r < 0.25 and c.g < 0.25 and c.b < 0.35:
				dark += 1
		if dark >= 3:
			if first < 0:
				first = row
			last = row
	return Vector2i(first, last)
