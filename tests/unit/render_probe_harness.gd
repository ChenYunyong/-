## render_probe_harness.gd
## 职责：像素探针的取证基建 —— 离屏画布、逐像素统计、判据色标记、断言计数。
## 所属系统：tests（09 §4 v0.1.2 像素探针的共用件）
## 依赖：无 —— 判据色由调用方从 Palette 取好传入，本文件不写任何字面色值。
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得自行决定判据色 —— 判据属各探针组的规范依据，混进基建就分不清「测什么」与「怎么测」。
##
## 拆分理由（02 §4：单文件 ≤300 行，不含注释与空行）：把原 render_shadow_probe.gd 与
## render_highlight_probe.gd 合并进单一入口后，光是取证基建就占掉约百行代码，入口会顶破硬上限。
## 按「基建 / 用例」切开后，入口只剩本批要取证的四组探针，改探针时也不必穿过一堆像素工具函数。

extends RefCounted

## 浮点比较容差：颜色经渲染管线往返后的量化误差。
const EPSILON: float = 0.004

var passed: int = 0
var failed: int = 0

## 判据色：由调用方从 Palette 取好填入，基建只负责比对。
var backdrop: Color = Color.BLACK
var fill: Color = Color.BLACK
var shadow: Color = Color.BLACK

var _tree: SceneTree = null
var _canvas: SubViewport = null
var _panel: Panel = null


## 建离屏画布。必须由调用方把 SceneTree 传进来 —— 本类不是 SceneTree，
## 自己取不到 process_frame 信号，而等帧是取像素的前提。
func open(tree: SceneTree, size: Vector2i, clear_color: Color) -> void:
	_tree = tree
	RenderingServer.set_default_clear_color(clear_color)
	_canvas = SubViewport.new()
	_canvas.size = size
	_canvas.transparent_bg = false
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(_canvas)


func set_canvas_size(size: Vector2i) -> void:
	_canvas.size = size


## 当前被测量的面板：组 2 直接改它的 stylebox，组 3 直接改它的 theme_type_variation。
func panel() -> Panel:
	return _panel


## 清台，放一个落在 box 上的新 Panel 并返回它。
func subject(box: Rect2) -> Panel:
	reset()
	_panel = Panel.new()
	_panel.position = box.position
	_panel.size = box.size
	adopt(_panel)
	return _panel


## 把外部节点（如实例化出来的场景）挂上画布。
func adopt(node: Control) -> void:
	_canvas.add_child(node)


func reset() -> void:
	for child: Node in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()


## 把 stylebox 应用到当前面板，重绘并取像素。
func apply(box: StyleBoxFlat) -> Dictionary:
	_panel.add_theme_stylebox_override(&"panel", box)
	_panel.queue_redraw()
	return await settle()


## 等两帧让渲染落地，再取像素统计。region 非空时只统计该矩形**之外**的像素。
func settle(region: Rect2 = Rect2()) -> Dictionary:
	await _tree.process_frame
	await _tree.process_frame
	var image: Image = _canvas.get_texture().get_image()
	if image == null:
		failed += 1
		print("  [FAIL] 取不到图像（渲染上下文不可用）")
		return {"image": null, "shadow": 0, "other": 0, "fill": 0}
	return stats(image, region)


func stats(image: Image, region: Rect2) -> Dictionary:
	var skip_inside: bool = region.size.x > 0.0
	var extent: Vector2i = image.get_size()
	var shadow_count: int = 0
	var other: int = 0
	var fill_count: int = 0
	for y: int in extent.y:
		for x: int in extent.x:
			if skip_inside and region.has_point(Vector2(x, y)):
				continue
			var pixel: Color = image.get_pixel(x, y)
			if near(pixel, shadow):
				shadow_count += 1
			elif near(pixel, fill):
				fill_count += 1
			elif not near(pixel, backdrop):
				other += 1
	return {"image": image, "shadow": shadow_count, "other": other, "fill": fill_count}


func count_row(image: Image, y: int, from_x: int, to_x: int, wanted: Color) -> int:
	var hits: int = 0
	for x: int in range(from_x, to_x):
		if near(image.get_pixel(x, y), wanted):
			hits += 1
	return hits


func count_col(image: Image, x: int, from_y: int, to_y: int, wanted: Color) -> int:
	var hits: int = 0
	for y: int in range(from_y, to_y):
		if near(image.get_pixel(x, y), wanted):
			hits += 1
	return hits


func dump(image: Image) -> void:
	if image == null:
		return
	for y: int in image.get_size().y:
		var row: String = ""
		for x: int in image.get_size().x:
			row += mark(image.get_pixel(x, y))
		print("%2d %s" % [y, row])
	print("  （S=NAVY_900  #=NAVY_800  .=底 WHITE  ?=其他色）")


## 只印右下角窗口与两条扫描线：对 40×72 的大矩形，整幅 ASCII 图既冗长又不便读数，
## 而「1px 精确、零羽化」最直接的证据本来就只是边上的那几个像素。
func dump_corner(image: Image, box: Rect2) -> void:
	if image == null:
		return
	var left: int = int(box.position.x)
	var top: int = int(box.position.y)
	var right: int = left + int(box.size.x)
	var bottom: int = top + int(box.size.y)
	print("  右下角窗口（列=x，行=y）：")
	var header: String = "       "
	for x: int in range(right - 2, right + 3):
		header += "%5d" % x
	print(header)
	for y: int in range(bottom - 2, bottom + 3):
		var row: String = "%5d  " % y
		for x: int in range(right - 2, right + 3):
			row += "%5s" % mark(image.get_pixel(x, y))
		print(row)
	var mid_y: int = top + int(box.size.y) / 2
	var mid_x: int = left + int(box.size.x) / 2
	print("  右缘横扫 y=%d：%s" % [mid_y, _scan_row(image, mid_y, right - 2, right + 3)])
	print("  下缘纵扫 x=%d：%s" % [mid_x, _scan_col(image, mid_x, bottom - 2, bottom + 3)])


func mark(pixel: Color) -> String:
	if near(pixel, shadow):
		return "S"
	if near(pixel, fill):
		return "#"
	if near(pixel, backdrop):
		return "."
	return "?"


func check(condition: bool, label: String) -> bool:
	if condition:
		passed += 1
		print("  [OK] %s" % label)
	else:
		failed += 1
		print("  [FAIL] %s" % label)
	return condition


func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < EPSILON and absf(a.g - b.g) < EPSILON \
		and absf(a.b - b.b) < EPSILON and absf(a.a - b.a) < EPSILON


func color_text(c: Color) -> String:
	return "(%.4f,%.4f,%.4f,%.4f)" % [c.r, c.g, c.b, c.a]


func _scan_row(image: Image, y: int, from_x: int, to_x: int) -> String:
	var parts: PackedStringArray = []
	for x: int in range(from_x, to_x):
		parts.append("x%d=%s" % [x, mark(image.get_pixel(x, y))])
	return " ".join(parts)


func _scan_col(image: Image, x: int, from_y: int, to_y: int) -> String:
	var parts: PackedStringArray = []
	for y: int in range(from_y, to_y):
		parts.append("y%d=%s" % [y, mark(image.get_pixel(x, y))])
	return " ".join(parts)
