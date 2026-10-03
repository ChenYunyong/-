## render_shadow_probe.gd
## 职责：实证 StyleBoxFlat 硬阴影的成像行为（06 §2.2 存疑项取证），输出像素级证据。
## 所属系统：tests（取证工具 —— 不挂进 run_tests.gd 常规回归，因为它需要真实渲染上下文）
## 依赖：Palette
## 禁止：本文件不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       本文件不得写任何字面色值 —— 判据直接用生产色值本身：
##       底色 WHITE / 面板填充 NAVY_800 / 阴影 NAVY_900。
##       于是「阴影有没有出来」「有没有被模糊」可以由像素是否**恰好等于** NAVY_900 直接判定。

extends SceneTree

const SIZE: int = 24
## 面板矩形：留出足够边距，使 (1,1) 与 (3,3) 两种偏移的落点都落在画布内。
const BOX: Rect2 = Rect2(4, 4, 12, 12)
## 浮点比较容差：颜色经渲染管线往返后的量化误差。
const EPSILON: float = 0.004

var _backdrop: Color = Color.BLACK
var _fill: Color = Color.BLACK
var _shadow: Color = Color.BLACK

var _canvas: SubViewport = null
var _panel: Panel = null


func _initialize() -> void:
	_backdrop = Palette.get_color(Palette.Key.WHITE)
	_fill = Palette.get_color(Palette.Key.NAVY_800)
	_shadow = Palette.get_color(Palette.Key.NAVY_900)

	RenderingServer.set_default_clear_color(_backdrop)

	_canvas = SubViewport.new()
	_canvas.size = Vector2i(SIZE, SIZE)
	_canvas.transparent_bg = false
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_canvas)

	_panel = Panel.new()
	_panel.position = BOX.position
	_panel.size = BOX.size
	_canvas.add_child(_panel)

	print("PROBE 环境：Godot %s / 渲染驱动 %s" % [
		Engine.get_version_info()["string"],
		RenderingServer.get_video_adapter_name(),
	])
	print("PROBE 判据色：底=WHITE%s 填充=NAVY_800%s 阴影=NAVY_900%s" % [
		_str(_backdrop), _str(_fill), _str(_shadow),
	])
	_dump_shadow_properties()

	await _run_case("A", 0, Vector2(1, 1))
	await _run_case("B", 1, Vector2(1, 1))
	await _run_case("C", 2, Vector2(1, 1))
	await _run_case("D", 0, Vector2(3, 3))
	await _run_case("E", 1, Vector2(0, 0))
	# F/G：不用 shadow_*，改用 border + expand_margin 造硬边 —— 验证「零羽化 1px」是否可达。
	await _run_box("F border 右下1px（边在矩形内）", _make_edge_box(false))
	await _run_box("G border+expand_margin 右下1px（边在矩形外）", _make_edge_box(true))

	quit(0)


## 硬边方案：右下各 1px NAVY_900 描边；expand=true 时再用 expand_margin 把它推到矩形外侧。
func _make_edge_box(expand: bool) -> StyleBoxFlat:
	var box: StyleBoxFlat = _make_box(0, Vector2.ZERO)
	box.border_color = _shadow
	box.border_width_right = 1
	box.border_width_bottom = 1
	if expand:
		box.expand_margin_right = 1.0
		box.expand_margin_bottom = 1.0
	return box


func _run_case(label: String, shadow_size: int, offset: Vector2) -> void:
	await _run_box("CASE %s : shadow_size=%d shadow_offset=%s" % [label, shadow_size, offset],
		_make_box(shadow_size, offset))


func _run_box(title: String, box: StyleBoxFlat) -> void:
	_panel.add_theme_stylebox_override(&"panel", box)
	_panel.queue_redraw()
	await process_frame
	await process_frame

	var image: Image = _canvas.get_texture().get_image()
	print("")
	print("=== %s ===" % title)
	if image == null:
		print("  !! 取不到图像（渲染上下文不可用）")
		return
	_dump(image)


## 只用 Palette 取色，不出现任何字面色值。
func _make_box(shadow_size: int, offset: Vector2) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _fill
	box.shadow_color = _shadow
	box.shadow_size = shadow_size
	box.shadow_offset = offset
	box.anti_aliasing = false
	box.corner_radius_top_left = 0
	box.corner_radius_top_right = 0
	box.corner_radius_bottom_left = 0
	box.corner_radius_bottom_right = 0
	return box


func _dump(image: Image) -> void:
	var exact_shadow: int = 0
	var blended: int = 0
	var fill_pixels: int = 0
	var lines: PackedStringArray = []
	for y: int in SIZE:
		var row: String = ""
		for x: int in SIZE:
			var pixel: Color = image.get_pixel(x, y)
			if _near(pixel, _shadow):
				row += "S"
				exact_shadow += 1
			elif _near(pixel, _fill):
				row += "#"
				fill_pixels += 1
			elif _near(pixel, _backdrop):
				row += "."
			else:
				row += "?"
				blended += 1
		lines.append("%2d %s" % [y, row])
	for line: String in lines:
		print(line)
	print("  统计：填充#=%d  精确阴影S=%d  非判据色?=%d" % [fill_pixels, exact_shadow, blended])

	# 逐像素数值：横向扫过面板右缘（y=8, x=14..19）、纵向扫过下缘（x=8, y=14..19）。
	# 只有这一层数值才能区分「1px 实心」与「1px 实心 + 若干半透明羽化」。
	var across: PackedStringArray = []
	for x: int in range(14, 20):
		across.append("x%d=%s" % [x, _str(image.get_pixel(x, 8))])
	var down: PackedStringArray = []
	for y: int in range(14, 20):
		down.append("y%d=%s" % [y, _str(image.get_pixel(8, y))])
	print("  右缘横扫 y=8: " + " ".join(across))
	print("  下缘纵扫 x=8: " + " ".join(down))


## 直接向引擎问「StyleBoxFlat 到底有哪些阴影开关」—— 这比读文档可靠。
func _dump_shadow_properties() -> void:
	print("")
	print("=== StyleBoxFlat 与 shadow 相关的可用属性（引擎自述）===")
	var found: int = 0
	for property: Dictionary in ClassDB.class_get_property_list(&"StyleBoxFlat", true):
		var property_name: String = String(property["name"])
		if property_name.contains("shadow") or property_name.contains("feather") or property_name.contains("blur"):
			print("  %s : %s" % [property_name, property["type"]])
			found += 1
	print("  命中 %d 项；不存在 shadow_blur / shadow_feather 之类开关 = 引擎未提供关闭羽化的手段" % found)


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < EPSILON and absf(a.g - b.g) < EPSILON \
		and absf(a.b - b.b) < EPSILON and absf(a.a - b.a) < EPSILON


func _str(c: Color) -> String:
	return "(%.4f,%.4f,%.4f,%.4f)" % [c.r, c.g, c.b, c.a]
