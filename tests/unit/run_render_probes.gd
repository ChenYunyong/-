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
## S1-07 / S1-08 的用例模块。聚合入口只留一次调用，见 09 §4 v0.1.3 的拆分先例。
const PREP_PROBE_PATH: String = "res://tests/unit/preparation_probe.gd"
const COMBAT_PROBE_PATH: String = "res://tests/unit/combat_probe.gd"
const REWARD_PROBE_PATH: String = "res://tests/unit/reward_probe.gd"
const RESULT_PROBE_PATH: String = "res://tests/unit/result_probe.gd"
const THEME_PATH: String = "res://assets/ui/theme_main.tres"
const PANEL_SCENE_PATH: String = "res://scenes/components/message_panel.tscn"
const TITLE_BAR_SCENE_PATH: String = "res://scenes/components/panel_title_bar.tscn"
## 组 0–3 的离屏画布与单面板矩形。这一组量的是**探针自己搭的** StyleBoxFlat
## （见 _measure_edge_box / _measure_shadow_box 里字面的 1），属引擎性质取证，
## 与设计坐标系无关 —— 故 PET-80 的布局 ×2 **不动这几个数**。
const SIZE: Vector2i = Vector2i(48, 32)
## 单面板矩形：四周留白，使四条边与 1px 阴影都落在画布内。
const BOX: Rect2 = Rect2(4, 4, 12, 12)
## 接线探针的矩形与画布。必须**大于 MessagePanel 的最小尺寸**（PET-80 前实测 25×61，
## 由 Frame 的内容边距 + 两个 Label 撑出）：根节点是 Control 而非 Container，不会把子节点的
## 最小尺寸上抛，给的矩形一旦偏小，Frame 就会被自己的最小尺寸撑出矩形、把 Shadow 叠层整个盖住。
##
## PET-80：这个「最小尺寸」是**由主题常量撑出来的**（正文字号 8→16、内容边距等），
## 随基准画布 ×2，故这里的矩形与画布一并 ×2，保持原来那份余量。
## 给少了会当场红在上面那条 `frame.get_rect().size <= WIRED_BOX.size` 上。
const WIRED_BOX: Rect2 = Rect2(8, 8, 80, 144)
const WIRED_SIZE: Vector2i = Vector2i(104, 168)
## 标题栏探针：矩形高度就是这个探针要证的那个数（PET-80 后 32，前 16）；宽度取 40 以便与高度区分
## 行 / 列两个方向（宽高不等的盒子把行列表现在写反了也会红）。
##
## PET-80：这个高度取自 PaletteTheme.TITLE_BAR_HEIGHT（16 → 32），而该值正是标题栏组件的
## `custom_minimum_size.y` —— Control.set_size 会被最小尺寸顶住，给的矩形矮了控件就会自己长大、
## 顶出画布。故矩形与画布一并 ×2，下面的三条几何断言（含两条反向对照）逐条照旧成立。
const TITLE_BOX: Rect2 = Rect2(4, 4, 40, 32)
## 画布高度留到 40：反向对照要把控件撑到 33px，撑开后底边连同 `_dump_title_bar` 的
## 「再下一行」仍要落在画布内。
const TITLE_SIZE: Vector2i = Vector2i(48, 40)
## 标题栏底部金线的厚度（逻辑像素）。PET-80：1 → 2。
##
## 它来自 PanelTitleBar 变体 StyleBoxFlat 的 `border_width_bottom`，取值是 PaletteTheme.BORDER_WIDTH
## —— 代码画的逻辑像素（**不是**九宫格切片的纹素边距），故随坐标系 ×2。
const TITLE_GOLD_ROWS: int = 2

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
	await _probe_title_bar()
	# S1-07 的 PREPARATION 布局取证拆在 preparation_probe.gd 里（本文件已近 02 §4 的 300 行上限）。
	# 它借用同一个 harness，故计数直接汇入下面的结论行。
	await load(PREP_PROBE_PATH).new().run(self, _h, _theme)
	# S1-08 的 COMBAT 战场 / 状态带取证同样拆成模块（本文件仍在 02 §4 的上限内）。
	await load(COMBAT_PROBE_PATH).new().run(self, _h, _theme)
	# S1-09 的 REWARD 三列 / 竖排选项卡与类型图标取证。
	await load(REWARD_PROBE_PATH).new().run(self, _h, _theme)
	# S1-10 的 RESULT 读数区（次级面板 + 硬阴影）与两个出口按钮取证。
	await load(RESULT_PROBE_PATH).new().run(self, _h, _theme)

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
	# 厚度 1 是**写死的**：这个盒子由 _measure_edge_box 现搭（border_width_* = 1 + expand_margin = 1），
	# 不走主题常量，故不随 PET-80 的坐标系 ×2。它证的是引擎这套组合能不能画出精确硬边。
	_assert_ring(outside, BOX, "G", 1)


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
	# 阴影厚度取自主题：Shadow 叠层的 PanelShadow 变体用 BORDER_WIDTH（PET-80 后 2）做
	# border_width_right/bottom，再以同值 expand_margin 推到矩形外。组 2 那个 1 是探针自搭的盒子，两者不同源。
	_assert_ring(stats, WIRED_BOX, "接线后", _script.BORDER_WIDTH)
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


## 组 5：06 §2.2 的面板标题栏 —— 高 32px（PET-80 前 16；分隔线算在这 32 里）、底色 NAVY_700、
## 底边整条 GOLD_600 分隔线（PET-80 后 2 行，前 1 行）。09 §4 v0.1.1 明确要求视觉结果必须有像素证据，
## 所以这里量的是渲染出来的行，而不是「custom_minimum_size 等于 16」这种字段断言。
##
## 两条反向对照（09 §4 v0.1.2：探针必须能被一次「故意改坏」打红）：
##   高度对照 —— 把控件撑到 33px（PET-80 前 17），金线必须整体下移。量不到这个位移，
##              就说明探针只是在「矩形最底下一行」找金色，证明不了高度与常量一致。
##   变体对照 —— 换成 PanelCore，金色必须一像素不剩，证明金线来自标题栏变体本身。
func _probe_title_bar() -> void:
	print("")
	print("=== 组 5：面板标题栏 32px + 底部 2px 分隔线（06 §2.2 像素取证）===")
	_h.reset()
	# 复用基建里「判据色」两个槽位：fill 记标题栏底色，shadow 记分隔线色，
	# 于是 mark() 与 stats() 不必为这一组另开一套。
	_h.fill = Palette.get_color(Palette.Key.NAVY_700)
	_h.shadow = Palette.get_color(Palette.Key.GOLD_600)
	print("  判据色：底=WHITE%s 标题栏底色=NAVY_700%s 分隔线=GOLD_600%s" % [
		_h.color_text(_h.backdrop), _h.color_text(_h.fill), _h.color_text(_h.shadow),
	])

	var packed: PackedScene = load(TITLE_BAR_SCENE_PATH)
	if not _h.check(packed != null, "panel_title_bar.tscn 应能加载"):
		return
	_h.set_canvas_size(TITLE_SIZE)
	var bar: Control = packed.instantiate()
	bar.position = TITLE_BOX.position
	bar.size = TITLE_BOX.size
	bar.theme = _theme
	_h.adopt(bar)
	# 这条是**改动前就有的回声断言**（拿主题常量比它自己派生出的属性，恒真），
	# PET-80 没碰它、也没把它当高度证据 —— 高度由下面那三条**像素**断言证明。
	# 留着是为了记录接线关系；判别力不在这条上，故不必（也不该）在此处补强。
	_h.check(bar.custom_minimum_size.y == float(_script.TITLE_BAR_HEIGHT),
		"组件高度应取自 PaletteTheme.TITLE_BAR_HEIGHT（%d）" % _script.TITLE_BAR_HEIGHT)

	var stats: Dictionary = await _h.settle()
	_dump_title_bar(stats["image"])
	_assert_title_bar(stats["image"], int(TITLE_BOX.size.y) - TITLE_GOLD_ROWS, "标题栏 32px")
	# 整幅画面上的金像素 = 分隔线长 × 线厚。PET-80：线厚 1 → TITLE_GOLD_ROWS，故 40 → 80。
	# 命题不变：金像素只许出现在分隔线本身，多一个就说明有金色漏到别处。
	_h.check(int(stats["shadow"]) == int(TITLE_BOX.size.x) * TITLE_GOLD_ROWS,
		"整幅画面上的金像素应恰好等于分隔线面积 %d×%d（实际 %d）" % [
			int(TITLE_BOX.size.x), TITLE_GOLD_ROWS, int(stats["shadow"])])
	_h.check(int(stats["other"]) == 0,
		"除底色与金线外不得有第三种像素 —— 零羽化、零抗锯齿（实际 %d）" % int(stats["other"]))

	# 真实菜单里的标题栏是**带中文标题**的：文字必须被挡在分隔线之上，既不能把那 2px 金线打断，
	# 也不能因为 Label 的最小行高超过可用高度而把标题栏顶高（顶高了 06 §2.2 的高度就守不住）。
	bar.call(&"set_title_key", "主菜单")
	stats = await _h.settle()
	_h.check(int(stats["other"]) > 0,
		"带中文标题时：标题栏内应确有这样的文字墨迹（实际非判据色像素 %d）—— 否则下一条是空断言" % int(stats["other"]))
	for offset: int in TITLE_GOLD_ROWS:
		_h.check(_h.count_row(stats["image"], int(TITLE_BOX.position.y + TITLE_BOX.size.y) - 1 - offset,
				int(TITLE_BOX.position.x), int(TITLE_BOX.position.x + TITLE_BOX.size.x),
				_h.shadow) == int(TITLE_BOX.size.x),
			"带中文标题时：分隔线第 %d 行仍应是整条 %d px（文字不得压到金线上）" % [
				int(TITLE_BOX.size.y) - 1 - offset, int(TITLE_BOX.size.x)])
	_h.check(bar.size.y == TITLE_BOX.size.y, "带中文标题时：标题栏高度仍是 32px（不得被文字撑高）")
	bar.call(&"set_title_key", "")

	bar.size.y = TITLE_BOX.size.y + 1.0
	stats = await _h.settle()
	_assert_title_bar(stats["image"], int(TITLE_BOX.size.y) + 1 - TITLE_GOLD_ROWS, "反向对照：撑到 33px")

	bar.size.y = TITLE_BOX.size.y
	bar.theme_type_variation = _script.TYPE_PANEL_CORE
	stats = await _h.settle()
	_h.check(int(stats["shadow"]) == 0,
		"反向对照：换成 PanelCore 后金像素应归零（实际 %d）—— 金线来自标题栏变体" % int(stats["shadow"]))


## 标题栏几何契约：第 0..gold_top-1 行整行底色，第 gold_top..gold_top+TITLE_GOLD_ROWS-1 行整行金线
## （每列恰好 TITLE_GOLD_ROWS 个金像素），再下一行不得有任何标题栏像素 —— 最后一条把「高度到此为止」也钉住。
##
## PET-80：金线由 1 行变 TITLE_GOLD_ROWS 行，于是「底面行数」与「线内行数」各自成为独立的一段。
## 判别力只增不减 —— 原来「每列恰好 1 个金像素」在 1 行的区间里数 1 个，是「线厚 1px」这句话的回声；
## 现在线厚 2，这句真的开始排除「线被画厚 / 画薄」：厚一行数出 3，薄一行数出 1，都会当场红。
func _assert_title_bar(image: Image, gold_top: int, label: String) -> void:
	if image == null:
		return
	var left: int = int(TITLE_BOX.position.x)
	var top: int = int(TITLE_BOX.position.y)
	var width: int = int(TITLE_BOX.size.x)
	var bad_rows: int = 0
	for offset: int in gold_top:
		if _h.count_row(image, top + offset, left, left + width, _h.fill) != width:
			bad_rows += 1
		elif _h.count_row(image, top + offset, left, left + width, _h.shadow) != 0:
			bad_rows += 1
	_h.check(bad_rows == 0,
		"%s：第 0~%d 行应整行是 NAVY_700 底色（违例 %d 行）" % [label, gold_top - 1, bad_rows])
	for offset: int in TITLE_GOLD_ROWS:
		_h.check(_h.count_row(image, top + gold_top + offset, left, left + width, _h.shadow) == width,
			"%s：第 %d 行应整行是 GOLD_600（%d px）" % [label, gold_top + offset, width])
	_h.check(_h.count_col(image, left + width / 2, top, top + gold_top + TITLE_GOLD_ROWS, _h.shadow)
			== TITLE_GOLD_ROWS,
		"%s：任一列在标题栏内应恰好 %d 个金像素（分隔线厚 %dpx）" % [label, TITLE_GOLD_ROWS, TITLE_GOLD_ROWS])
	var below: int = top + gold_top + TITLE_GOLD_ROWS
	_h.check(_h.count_row(image, below, left, left + width, _h.fill) == 0
			and _h.count_row(image, below, left, left + width, _h.shadow) == 0,
		"%s：第 %d 行不得再有标题栏像素（高度到此为止）" % [label, gold_top + TITLE_GOLD_ROWS])


## 只印标题栏及其上下各一行：整幅 ASCII 图的其余部分全是底色，没有信息量。
## 不用基建的 dump() —— 它的图例写死了 S=NAVY_900 / #=NAVY_800，本组换过判据色，读图例会读错。
func _dump_title_bar(image: Image) -> void:
	if image == null:
		return
	print("  每字符一像素，横轴从 x=%d 起：# = NAVY_700（底色）  s = GOLD_600（分隔线）  . = WHITE（画布底）" % int(TITLE_BOX.position.x))
	var from_y: int = int(TITLE_BOX.position.y) - 1
	var to_y: int = int(TITLE_BOX.position.y + TITLE_BOX.size.y) + 1
	var from_x: int = int(TITLE_BOX.position.x) - 1
	var to_x: int = int(TITLE_BOX.position.x + TITLE_BOX.size.x) + 1
	for y: int in range(from_y, to_y + 1):
		var row: String = "%3d " % y
		for x: int in range(from_x, to_x):
			row += _title_mark(image.get_pixel(x, y))
		print(row)


func _title_mark(pixel: Color) -> String:
	if _h.near(pixel, _h.fill):
		return "#"
	if _h.near(pixel, _h.shadow):
		return "s"
	if _h.near(pixel, _h.backdrop):
		return "."
	return "?"


## 硬阴影契约：矩形右边与下边各外扩 thickness 像素精确判据色，上 / 左没有，且画面零羽化。
## 总阴影数由几何推出（thickness × (w + h + thickness)，右下角块只画一次），不是抄来的魔数。
##
## 厚度做成参数，是因为两条调用路径的来源不同：组 2 量的是探针自己搭的 StyleBoxFlat
## （_measure_edge_box 里字面的 1，引擎性质取证，与设计坐标无关）；组 4 量的是 message_panel
## 的 Shadow 叠层，其 border_width_right/bottom 取自 PaletteTheme.BORDER_WIDTH，随基准画布 ×2。
## 契约本身（右 / 下各有、上 / 左没有、总数与几何相符、零羽化）两边完全一样。
func _assert_ring(stats: Dictionary, box: Rect2, label: String, thickness: int) -> void:
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
	# 参数写反了也看不出来 —— 所以接线探针刻意用宽高不等的长方盒，让这一点没法蒙混。
	_h.check(_h.count_col(image, right, top, bottom + thickness, _h.shadow) == height + thickness,
		"%s：右边 x=%d 应有 %d 个 NAVY_900" % [label, right, height + thickness])
	_h.check(_h.count_row(image, bottom, left, right + thickness, _h.shadow) == width + thickness,
		"%s：下边 y=%d 应有 %d 个 NAVY_900" % [label, bottom, width + thickness])
	# 采样范围一并放宽到把整条外扩带盖住：只到 right / bottom 的话，
	# 多出来的那一列 / 行即使被画到矩形正上方 / 正左侧也量不到。
	_h.check(_h.count_row(image, top - 1, left, right + thickness, _h.shadow) == 0,
		"%s：上边不得有阴影" % label)
	_h.check(_h.count_col(image, left - 1, top, bottom + thickness, _h.shadow) == 0,
		"%s：左边不得有阴影" % label)
	_h.check(int(stats["shadow"]) == thickness * (width + height + thickness),
		"%s：阴影总数应为 %d×(w+h+%d)=%d（实际 %d）" % [
			label, thickness, thickness, thickness * (width + height + thickness), int(stats["shadow"])])
	_h.check(int(stats["other"]) == 0,
		"%s：零羽化 —— 非判据色像素应为 0（实际 %d）" % [label, int(stats["other"])])


## 两套高光几何：上 / 左两边恒有；下 / 右两边只有整圈变体才画。
## 暖高光的下 / 右两边整体不画，但它们的**起点**分别落在左边 / 上边的端点上（角点只画一次），
## 故起点跳过 thickness 个采样 —— 否则会把垂直边的角点误判成「下边 / 右边被画出来了」。
##
## PET-80：这个跳过量原来是字面的 1，现在必须取 `_highlight_box()` 的描边厚度
## （它用的是 set_border_width_all(BORDER_WIDTH)，本卡 1 → 2）。跳过量偏小会把角块数成
## 「下边被画出来了」而误报，故它与描边厚度同源、同步 —— 不能各写一份。
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
	var skip: int = _script.BORDER_WIDTH if top_left_only else 0

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
