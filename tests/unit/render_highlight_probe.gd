## render_highlight_probe.gd
## 职责：像素级验证 06 §2.1 v0.1.6 的两套高光几何**真的被画出来**，且边数各自正确。
## 所属系统：tests（取证工具 —— 不挂进 run_tests.gd 常规回归，因为它需要真实渲染上下文）
## 依赖：Palette, theme_main.tres
## 禁止：本文件不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       本文件不得写任何字面色值 —— 判据直接用生产色值本身：
##       底色 WHITE / 暖高光 GOLD_200 / 选中辉光 BLUE_300。
##
## 为什么需要这个探针（09 §4 v0.1.1）：
##   「border_width_top = 1」只是字段值。字段全绿而一个像素都没画，是这条规则点名的失效模式。
##   本探针**不设任何 stylebox override**，让 Panel 走 Theme 的 theme_type_variation 解析 ——
##   于是它同时验证了「变体落点可用」和「边确实落在正确的边上」两件事。

extends SceneTree

const THEME_PATH: String = "res://assets/ui/theme_main.tres"
const SIZE: int = 24
## 面板矩形：四周留白，使四条边都落在画布内且互不重叠。
const BOX: Rect2 = Rect2(4, 4, 12, 12)
## 浮点比较容差：颜色经渲染管线往返后的量化误差。
const EPSILON: float = 0.004

var _backdrop: Color = Color.BLACK
var _warm: Color = Color.BLACK
var _selected: Color = Color.BLACK

var _canvas: SubViewport = null
var _panel: Panel = null
var _theme: Theme = null
var _script: GDScript = null

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	_backdrop = Palette.get_color(Palette.Key.WHITE)
	_warm = Palette.get_color(Palette.Key.GOLD_200)
	_selected = Palette.get_color(Palette.Key.BLUE_300)
	_script = load("res://scripts/data/palette_theme.gd")

	var theme_resource: Resource = ResourceLoader.load(THEME_PATH)
	if theme_resource is Theme:
		_theme = theme_resource
	print("PROBE 环境：Godot %s / 渲染驱动 %s" % [
		Engine.get_version_info()["string"],
		RenderingServer.get_video_adapter_name(),
	])
	print("PROBE 判据色：底=WHITE%s 暖高光=GOLD_200%s 选中辉光=BLUE_300%s" % [
		_str(_backdrop), _str(_warm), _str(_selected),
	])
	if _theme == null or _script == null:
		print("!! 无法加载 theme_main.tres 或 palette_theme.gd")
		quit(1)
		return

	RenderingServer.set_default_clear_color(_backdrop)
	_canvas = SubViewport.new()
	_canvas.size = Vector2i(SIZE, SIZE)
	_canvas.transparent_bg = false
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_canvas)

	_panel = Panel.new()
	_panel.position = BOX.position
	_panel.size = BOX.size
	# 刻意不设 stylebox override：全部样式必须由 Theme 的变体解析得来。
	_panel.theme = _theme
	_canvas.add_child(_panel)

	await _run_variant("PanelHighlight（GOLD_200）", _script.TYPE_PANEL_HIGHLIGHT, true)
	await _run_variant("PanelSelected（BLUE_300）", _script.TYPE_PANEL_SELECTED, false)

	print("")
	print("PROBE 结论：通过 %d / 失败 %d" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


## warm_top_left = true → 只断言上/左两条边；false → 断言四边整圈。
func _run_variant(title: String, variation: StringName, warm_top_left: bool) -> void:
	_panel.theme_type_variation = variation
	_panel.queue_redraw()
	await process_frame
	await process_frame

	var image: Image = _canvas.get_texture().get_image()
	print("")
	print("=== %s ===" % title)
	if image == null:
		print("  !! 取不到图像（渲染上下文不可用）")
		_failed += 1
		return
	_dump(image)

	var wanted: Color = _warm if warm_top_left else _selected
	var top: int = int(BOX.position.y)
	var left: int = int(BOX.position.x)
	var bottom: int = top + int(BOX.size.y) - 1
	var right: int = left + int(BOX.size.x) - 1

	# 上边 / 左边：两个变体都必须有。
	_count_edge(image, "上边 y=%d" % top, wanted, true, top, 0, true)
	_count_edge(image, "左边 x=%d" % left, wanted, false, left, 0, true)
	# 下边 / 右边：暖高光必须为空，选中辉光必须有。
	# 暖高光时这两条边整体不画，但它们的**起点**分别落在左边/上边的端点上（角点只画一次），
	# 故 skip=1 跳过该端点 —— 否则会把垂直边的角点误判成「下边/右边被画出来了」。
	var skip: int = 0 if not warm_top_left else 1
	_count_edge(image, "下边 y=%d" % bottom, wanted, true, bottom, skip, not warm_top_left)
	_count_edge(image, "右边 x=%d" % right, wanted, false, right, skip, not warm_top_left)


## 数一条边上「恰好等于判据色」的像素数。expect_drawn=false 时要求为 0。
## horizontal=true 扫第 fixed **行**（沿 x 走）；false 扫第 fixed **列**（沿 y 走）。
## 注意 fixed 必须由调用方按被检的那条边给出 —— 早期版本从 BOX.position 推，导致
## 「下边」「右边」实际扫的是上边和左边，四条断言全部打在同一个位置。
## skip：从该边起点跳过几个采样点（用于排除属于垂直邻边的角点）。
func _count_edge(image: Image, label: String, wanted: Color, horizontal: bool, fixed: int, skip: int, expect_drawn: bool) -> void:
	var hits: int = 0
	var first: int = int(BOX.position.x if horizontal else BOX.position.y) + skip
	var last: int = int(BOX.position.x if horizontal else BOX.position.y) \
		+ int(BOX.size.x if horizontal else BOX.size.y)
	for i: int in range(first, last):
		var pixel: Color = image.get_pixel(i, fixed) if horizontal else image.get_pixel(fixed, i)
		if _near(pixel, wanted):
			hits += 1
	var drawn: bool = hits > 0
	if drawn == expect_drawn:
		_passed += 1
		print("  [OK] %s 判据色像素 %d 个（期望%s）" % [label, hits, "有" if expect_drawn else "无"])
	else:
		_failed += 1
		print("  [FAIL] %s 判据色像素 %d 个，但期望%s" % [label, hits, "有" if expect_drawn else "无"])


func _dump(image: Image) -> void:
	var lines: PackedStringArray = []
	for y: int in SIZE:
		var row: String = ""
		for x: int in SIZE:
			var pixel: Color = image.get_pixel(x, y)
			if _near(pixel, _warm):
				row += "W"
			elif _near(pixel, _selected):
				row += "B"
			elif _near(pixel, _backdrop):
				row += "."
			else:
				row += "?"
		lines.append("%2d %s" % [y, row])
	for line: String in lines:
		print(line)
	print("  （W=GOLD_200  B=BLUE_300  .=底 WHITE  ?=其他色）")


func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < EPSILON and absf(a.g - b.g) < EPSILON \
		and absf(a.b - b.b) < EPSILON and absf(a.a - b.a) < EPSILON


func _str(c: Color) -> String:
	return "(%.4f,%.4f,%.4f,%.4f)" % [c.r, c.g, c.b, c.a]
