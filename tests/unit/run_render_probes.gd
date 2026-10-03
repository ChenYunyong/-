## run_render_probes.gd
## 职责：像素探针聚合入口（09 §4）—— 合并原 render_shadow_probe.gd 与 render_highlight_probe.gd，
##       并新增 PanelShadow 接线探针；一次运行、汇总退出码。
## 所属系统：tests（取证工具 —— 需要真实渲染上下文，故不挂进 run_tests.gd 常规回归）
## 依赖：Palette, palette_theme.gd, assets/ui/theme_main.tres, scenes/components/message_panel.tscn,
##       render_probe_harness.gd（取证基建；入口只留用例，见该文件头的拆分理由）
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得写任何字面色值 —— 判据一律取自 Palette，于是「画了没有」「糊没糊」
##       可以由像素是否**恰好等于**该色直接判定。
##
## 合并说明：09 §4 v0.1.2 记录的两条旧运行命令已随本次合并失效。docs/** 由 DSH 维护，
## 本批不修改，改由交付说明报备（见 09 §4 的探针入口一节）。

extends SceneTree

const HARNESS_PATH: String = "res://tests/unit/render_probe_harness.gd"
const THEME_PATH: String = "res://assets/ui/theme_main.tres"
const PANEL_SCENE_PATH: String = "res://scenes/components/message_panel.tscn"
const SIZE: Vector2i = Vector2i(48, 32)
## 单面板矩形：四周留白，使四条边与 1px 阴影都落在画布内。
const BOX: Rect2 = Rect2(4, 4, 12, 12)
## 接线探针的矩形与画布。必须**大于 MessagePanel 的最小尺寸**（实测 25×61，由
## Frame 的内容边距 + 两个 Label 撑出）：根节点是 Control 而非 Container，不会把子节点的
## 最小尺寸上抛，给的矩形一旦偏小，Frame 就会被自己的最小尺寸撑出矩形、把 Shadow 叠层整个盖住。
const WIRED_BOX: Rect2 = Rect2(4, 4, 40, 72)
const WIRED_SIZE: Vector2i = Vector2i(52, 84)

var _h: RefCounted = null
var _theme: Theme = null
var _script: GDScript = null
var _warm: Color = Color.BLACK
var _selected: Color = Color.BLACK


func _initialize() -> void:
	_script = load("res://scripts/data/palette_theme.gd")
	var theme_resource: Resource = ResourceLoader.load(THEME_PATH)
	if theme_resource is Theme:
		_theme = theme_resource
	if _theme == null or _script == null:
		print("!! 无法加载 theme_main.tres 或 palette_theme.gd")
		quit(1)
		return

	_h = load(HARNESS_PATH).new()
	_h.backdrop = Palette.get_color(Palette.Key.WHITE)
	_h.fill = Palette.get_color(Palette.Key.NAVY_800)
	_h.shadow = Palette.get_color(Palette.Key.NAVY_900)
	_warm = Palette.get_color(Palette.Key.GOLD_200)
	_selected = Palette.get_color(Palette.Key.BLUE_300)
	_h.open(self, SIZE, _h.backdrop)

	print("PROBE 环境：Godot %s / 渲染驱动 %s" % [
		Engine.get_version_info()["string"],
		RenderingServer.get_video_adapter_name(),
	])
	print("PROBE 判据色：底=WHITE%s 填充=NAVY_800%s 阴影=NAVY_900%s 暖=GOLD_200%s 选中=BLUE_300%s" % [
		_h.color_text(_h.backdrop), _h.color_text(_h.fill), _h.color_text(_h.shadow),
		_h.color_text(_warm), _h.color_text(_selected),
	])

	_probe_shadow_properties()
	await _probe_shadow_asterisks()
	await _probe_hard_edge()
	await _probe_highlights()
	await _probe_panel_shadow_wiring()

	print("")
	print("PROBE 结论：通过 %d / 失败 %d" % [_h.passed, _h.failed])
	quit(0 if _h.failed == 0 else 1)


## 组 0：直接向引擎问「StyleBoxFlat 到底有哪些阴影 / 羽化开关」—— 比读文档可靠。
func _probe_shadow_properties() -> void:
	print("")
	print("=== 组 0：StyleBoxFlat 的 shadow / blur / feather 相关属性（引擎自述）===")
	var found: int = 0
	var feather_switch: String = ""
	for property: Dictionary in ClassDB.class_get_property_list(&"StyleBoxFlat", true):
		var property_name: String = String(property["name"])
		if property_name.contains("shadow") or property_name.contains("feather") or property_name.contains("blur"):
			print("  %s : %s" % [property_name, property["type"]])
			found += 1
			if property_name.contains("feather") or property_name.contains("blur"):
				feather_switch = property_name
	_h.check(found > 0, "引擎应暴露 shadow_* 属性（命中 %d 项）" % found)
	_h.check(feather_switch.is_empty(),
		"引擎未提供关闭羽化的开关 —— 这正是 06 §2.2 甲案弃用 shadow_* 的原因（若此处命中，说明该结论需重审）")


## 组 1：StyleBoxFlat.shadow_* 的成像 —— 06 §2.2 弃用它、改用 border + expand_margin 的证据。
func _probe_shadow_asterisks() -> void:
	print("")
	print("=== 组 1：StyleBoxFlat.shadow_* 成像（06 §2.2 存疑项取证）===")
	_h.subject(BOX)

	var control: Dictionary = await _measure_shadow_box(0, Vector2(1, 1))
	_h.check(int(control["shadow"]) == 0 and int(control["other"]) == 0,
		"负对照 shadow_size=0 → 一个阴影像素都不画（实际 阴影 %d / 羽化 %d）" % [
			int(control["shadow"]), int(control["other"]),
		])

	var cases: Array[Dictionary] = [
		{"size": 1, "offset": Vector2(1, 1)},
		{"size": 2, "offset": Vector2(1, 1)},
		{"size": 0, "offset": Vector2(3, 3)},
		{"size": 1, "offset": Vector2(0, 0)},
	]
	for item: Dictionary in cases:
		var stats: Dictionary = await _measure_shadow_box(int(item["size"]), item["offset"])
		print("  shadow_size=%d offset=%s → 精确阴影 %d px，羽化 %d px" % [
			int(item["size"]), str(item["offset"]), int(stats["shadow"]), int(stats["other"]),
		])
	print("  读法：只要 shadow_size > 0，就必然同时出现「精确 1px」与「其外的半透明羽化带」，")
	print("        且 shadow_size 同时决定两者，无法解耦 —— 故甲案不用它。")


## 组 2：甲案形态 —— border + expand_margin 造右下 1px 硬边。G 是生产落点，F 仅作对照。
func _probe_hard_edge() -> void:
	print("")
	print("=== 组 2：border + expand_margin 硬边（06 §2.2 甲案）===")
	_h.subject(BOX)

	var inside: Dictionary = await _measure_edge_box(false)
	print("  F 边落在矩形内 → 阴影 %d px，羽化 %d px（矩形内被填充盖住，仅取证）" % [
		int(inside["shadow"]), int(inside["other"]),
	])

	var outside: Dictionary = await _measure_edge_box(true)
	_h.dump(outside["image"])
	_assert_ring(outside, BOX, "G")


## 组 3：06 §2.1 v0.1.6 的两套高光几何。刻意不设 stylebox override ——
## 全部样式必须由 Theme 的 theme_type_variation 解析得来，于是同时验证了「变体落点可用」。
func _probe_highlights() -> void:
	print("")
	print("=== 组 3：PanelHighlight / PanelSelected 高光边 ===")
	_h.subject(BOX)
	_h.panel().theme = _theme

	await _assert_highlight("PanelHighlight", _script.TYPE_PANEL_HIGHLIGHT, _warm, true)
	await _assert_highlight("PanelSelected", _script.TYPE_PANEL_SELECTED, _selected, false)


## 组 4：06 §2.2 甲案的接线实测 —— 面板本体不携带阴影，硬阴影由外层 PanelShadow 叠层单独承载。
func _probe_panel_shadow_wiring() -> void:
	print("")
	print("=== 组 4：PanelShadow 接线（message_panel.tscn）===")
	_h.reset()
	var packed: PackedScene = load(PANEL_SCENE_PATH)
	if not _h.check(packed != null, "message_panel.tscn 应能加载"):
		return

	_h.set_canvas_size(WIRED_SIZE)
	var panel: Control = packed.instantiate()
	panel.position = WIRED_BOX.position
	panel.size = WIRED_BOX.size
	panel.theme = _theme
	_h.adopt(panel)

	var stats: Dictionary = await _h.settle(WIRED_BOX)
	_h.dump_corner(stats["image"], WIRED_BOX)
	_assert_ring(stats, WIRED_BOX, "接线后")
	# Frame 必须完整落在矩形内，否则它会把 Shadow 盖住 —— 这正是上面那条
	# 「接线后矩形必须大于最小尺寸」的成因，钉住它免得将来改小场景尺寸时静默退化。
	var frame: Control = panel.get_node_or_null(NodePath("Frame")) as Control
	if _h.check(frame != null, "Frame 应存在"):
		_h.check(frame.get_rect().size.x <= WIRED_BOX.size.x and frame.get_rect().size.y <= WIRED_BOX.size.y,
			"Frame 应完整落在矩形内（实际 %s）" % str(frame.get_rect().size))

	# 负对照：藏掉 Shadow 叠层。若「面板本体不携带阴影」成立，画面上的阴影像素必须整体归零；
	# 若归零失败，说明上面数到的像素并非来自这一层，本探针就没有区分力（09 §4 v0.1.2）。
	var shadow_layer: Node = panel.get_node_or_null(NodePath("Shadow"))
	if not _h.check(shadow_layer != null, "Shadow 叠层应存在"):
		return
	shadow_layer.set(&"visible", false)
	var control: Dictionary = await _h.settle(WIRED_BOX)
	_h.check(int(control["shadow"]) == 0,
		"负对照：藏掉 Shadow 叠层后阴影像素应为 0（实际 %d）—— 面板本体不携带阴影" % int(control["shadow"]))
	_h.check(int(control["other"]) == 0,
		"负对照：藏掉 Shadow 叠层后仍应零羽化（实际 %d）" % int(control["other"]))


## 硬阴影契约：矩形右边与下边各外扩 1px 精确判据色，上 / 左没有，且画面零羽化。
## 总阴影数由几何推出（w + h + 1，右下角点只画一次），不是抄来的魔数。
func _assert_ring(stats: Dictionary, box: Rect2, label: String) -> void:
	var image: Image = stats["image"]
	if image == null:
		return
	var left: int = int(box.position.x)
	var top: int = int(box.position.y)
	var right: int = left + int(box.size.x)
	var bottom: int = top + int(box.size.y)
	var width: int = int(box.size.x)
	var height: int = int(box.size.y)

	# 右边是**列**（沿 y 走），下边是**行**（沿 x 走）。两者在 12×12 的方盒上数值相同，
	# 参数写反了也看不出来 —— 所以接线探针刻意用 40×72 的长方盒，让宽高不等来钉死这一点。
	_h.check(_h.count_col(image, right, top, bottom + 1, _h.shadow) == height + 1,
		"%s：右边 x=%d 应有 %d 个 NAVY_900" % [label, right, height + 1])
	_h.check(_h.count_row(image, bottom, left, right + 1, _h.shadow) == width + 1,
		"%s：下边 y=%d 应有 %d 个 NAVY_900" % [label, bottom, width + 1])
	_h.check(_h.count_row(image, top - 1, left, right, _h.shadow) == 0, "%s：上边不得有阴影" % label)
	_h.check(_h.count_col(image, left - 1, top, bottom, _h.shadow) == 0, "%s：左边不得有阴影" % label)
	_h.check(int(stats["shadow"]) == width + height + 1,
		"%s：阴影总数应为 w+h+1=%d（实际 %d）" % [label, width + height + 1, int(stats["shadow"])])
	_h.check(int(stats["other"]) == 0,
		"%s：零羽化 —— 非判据色像素应为 0（实际 %d）" % [label, int(stats["other"])])


## 两套高光几何：上 / 左两边恒有；下 / 右两边只有整圈变体才画。
## 暖高光的下 / 右两边整体不画，但它们的**起点**分别落在左边 / 上边的端点上（角点只画一次），
## 故起点跳过 1 个采样 —— 否则会把垂直边的角点误判成「下边 / 右边被画出来了」。
func _assert_highlight(label: String, variation: StringName, wanted: Color, top_left_only: bool) -> void:
	_h.panel().theme_type_variation = variation
	_h.panel().queue_redraw()
	var stats: Dictionary = await _h.settle()
	var image: Image = stats["image"]
	if image == null:
		return
	var left: int = int(BOX.position.x)
	var top: int = int(BOX.position.y)
	var right: int = left + int(BOX.size.x) - 1
	var bottom: int = top + int(BOX.size.y) - 1
	var width: int = int(BOX.size.x)
	var height: int = int(BOX.size.y)
	var skip: int = 1 if top_left_only else 0

	_h.check(_h.count_row(image, top, left, right + 1, wanted) == width, "%s：上边应有 %d 个判据色" % [label, width])
	_h.check(_h.count_col(image, left, top, bottom + 1, wanted) == height, "%s：左边应有 %d 个判据色" % [label, height])
	var expect_bottom: int = 0 if top_left_only else width
	var expect_right: int = 0 if top_left_only else height
	_h.check(_h.count_row(image, bottom, left + skip, right + 1, wanted) == expect_bottom,
		"%s：下边判据色应为 %d 个" % [label, expect_bottom])
	_h.check(_h.count_col(image, right, top + skip, bottom + 1, wanted) == expect_right,
		"%s：右边判据色应为 %d 个" % [label, expect_right])


func _measure_shadow_box(shadow_size: int, offset: Vector2) -> Dictionary:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _h.fill
	box.shadow_color = _h.shadow
	box.shadow_size = shadow_size
	box.shadow_offset = offset
	box.anti_aliasing = false
	box.set_corner_radius_all(0)
	return await _h.apply(box)


func _measure_edge_box(expand: bool) -> Dictionary:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = _h.fill
	box.border_color = _h.shadow
	box.border_width_right = 1
	box.border_width_bottom = 1
	if expand:
		box.expand_margin_right = 1.0
		box.expand_margin_bottom = 1.0
	box.anti_aliasing = false
	box.set_corner_radius_all(0)
	return await _h.apply(box)
