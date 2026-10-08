## test_map_layout.gd
## 职责：路线图屏版面的验收 —— docs/14 §2.2 的几何表逐条对照，外加 §4 的 M01/M03 面积与净空账。
## 所属系统：tests
## 依赖：MapLayout, MapModel, MapView, MapNodePainter, UiKit, ContractTheme
## 禁止：本文件不得写入布局常量，只断言 —— 数字的唯一来源是 MapLayout / docs/14。
##
## 为什么值得单独立一条：布局错位在 headless 下**不会报错**，只会让真机上两个控件叠在一起。
## 而这一屏的每个数字契约都直接给了（§2.2 的「rect @960」列），所以这里的断言就是**逐字对照**：
## 常量抄错一个数，test 立刻红，不必等拿尺子去量截图。
##
## PET-93 换了版式：旧版的自定义版面（MARGIN / GAP / PADDING ×3 倍率、折痕分界）整套作废，
## 换成 §2.2 的绝对坐标表。纸内坐标与屏坐标的分工见 MapLayout 的文件头。

extends RefCounted

## 窗口 / 画布 = 2，来自 project.godot。触控下限 44 **设备像素**（docs/06 §1）换算成 22 逻辑像素。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## docs/14 §1 的最小互动矩形。
const MIN_INTERACTIVE: float = 24.0
## docs/14 §4 M01：地图面积占安全区的比例。
const M01_MAP_RATIO_MIN: float = 0.73
const M01_MAP_RATIO: float = 0.73541
## §1 的间距档位（不再乘旧倍率）。
const SPACING_SCALE: Array[float] = [4.0, 8.0, 12.0, 16.0, 24.0]

const LOCALES: PackedStringArray = ["zh_CN", "en"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_map_layout")
	_check_screen_matches_project(ctx)
	_check_stacking(ctx)
	_check_header(ctx)
	_check_paper(ctx)
	_check_map_area(ctx)
	_check_nodes(ctx)
	_check_clearance(ctx)
	_check_labels(ctx)
	_check_legend(ctx)
	_check_actions(ctx)
	_check_touch_targets(ctx)
	_check_spacing_system(ctx)
	_check_both_locales(ctx, tree)


func _check_screen_matches_project(ctx: RefCounted) -> void:
	ctx.equal(MapLayout.SCREEN.x, ProjectSettings.get_setting("display/window/size/viewport_width"),
		"布局基准宽 = project.godot 的画布宽")
	ctx.equal(MapLayout.SCREEN.y, ProjectSettings.get_setting("display/window/size/viewport_height"),
		"布局基准高 = project.godot 的画布高")
	ctx.check(Rect2(Vector2.ZERO, MapLayout.SCREEN).encloses(MapLayout.SAFE_AREA), "安全区落在画布内")


## §2.2 的三段纵向账：16 + 头栏 40 + 8 + 纸 392 + 12 + 动作条 56 + 16 = 540。
## 这不是「大概齐」—— 契约给的就是这一串绝对坐标，加不满 540 就是版面漏了一截。
func _check_stacking(ctx: RefCounted) -> void:
	ctx.near(MapLayout.HEADER.position.x, 16.0, "左内容边距 16")
	ctx.near(MapLayout.HEADER.end.x, MapLayout.SCREEN.x - 16.0, "右内容边距 16")
	ctx.near(MapLayout.HEADER.size.y, 40.0, "头栏高 40")
	ctx.near(MapLayout.PAPER.position.y, MapLayout.HEADER.end.y + 8.0, "头栏到纸净空 8")
	ctx.near(MapLayout.PAPER.end.x, MapLayout.SCREEN.x - 16.0, "纸右边距 16")
	ctx.near(MapLayout.ACTIONS.position.y, MapLayout.PAPER.end.y + 12.0, "纸到动作条间距 12")
	ctx.near(MapLayout.ACTIONS.end.y, MapLayout.SCREEN.y - 16.0, "动作条下边距 16")
	ctx.near(MapLayout.PAPER.size.y + MapLayout.ACTIONS.size.y + MapLayout.HEADER.size.y,
		MapLayout.SCREEN.y - 16.0 - 8.0 - 12.0 - 16.0, "40 + 392 + 56 = 540 − 上下留白与两处净空")
	ctx.check(MapLayout.PAPER.encloses(MapLayout.GRAPH) and MapLayout.PAPER.encloses(MapLayout.LEGEND),
		"图区与图例都在纸内")


## 头栏 40 里两行字：标题 24/32 靠左、当前位置 16/24 右对齐。两行都纵向居中于头栏。
func _check_header(ctx: RefCounted) -> void:
	ctx.check(MapLayout.HEADER.encloses(MapLayout.TITLE_RECT), "标题在头栏内")
	ctx.check(MapLayout.HEADER.encloses(MapLayout.STATUS_RECT), "当前位置在头栏内")
	ctx.check(not _overlaps(MapLayout.TITLE_RECT, MapLayout.STATUS_RECT), "标题与当前位置不重叠")
	ctx.near(MapLayout.TITLE_RECT.size.y, 32.0, "标题行高 32（24/32）")
	ctx.near(MapLayout.TITLE_RECT.position.x - MapLayout.HEADER.position.x, 8.0, "标题左内缩 8")
	ctx.near(MapLayout.STATUS_RECT.end.x, MapLayout.HEADER.end.x - 16.0, "当前位置右内缩 16")
	ctx.check(MapLayout.STATUS_RECT.position.x > MapLayout.TITLE_RECT.end.x,
		"当前位置排在标题右边（%s > %s）" % [MapLayout.STATUS_RECT.position.x, MapLayout.TITLE_RECT.end.x])
	var middle: float = MapLayout.HEADER.position.y + MapLayout.HEADER.size.y * 0.5
	ctx.near(MapLayout.TITLE_RECT.position.y + MapLayout.TITLE_RECT.size.y * 0.5, middle, "标题纵向居中")
	ctx.near(MapLayout.STATUS_RECT.position.y + MapLayout.STATUS_RECT.size.y * 0.5, middle,
		"当前位置纵向居中")


## 纸：8px 材质边带 + 16 内容内缩；纸内自上而下 24 + 图区 316 + 12 + 图例 24 + 16 = 392。
func _check_paper(ctx: RefCounted) -> void:
	ctx.equal(MapLayout.PAPER.size, Vector2(928.0, 392.0), "MAP_PAPER 928×392")
	ctx.equal(MapLayout.PAPER_BAND, ContractTheme.PAGE_BAND, "纸的材质边带 = §1 的 8")
	ctx.equal(MapLayout.PAPER_INSET, 16.0, "内容内缩 16")
	ctx.equal(MapLayout.GRAPH.size, Vector2(896.0, 316.0), "MAP_GRAPH 896×316")
	ctx.equal(MapLayout.LEGEND.size, Vector2(896.0, 24.0), "MAP_LEGEND 896×24")
	ctx.near(MapLayout.GRAPH.position.x - MapLayout.PAPER.position.x, 16.0, "图区左内缩 16")
	ctx.near(MapLayout.GRAPH.end.x, MapLayout.PAPER.end.x - 16.0, "图区右内缩 16")
	ctx.near(MapLayout.LEGEND.position.y, MapLayout.GRAPH.end.y + 12.0, "图例距图区 12")
	ctx.near(MapLayout.GRAPH.position.y - MapLayout.PAPER.position.y, 24.0, "纸顶到图区 24")
	ctx.near(MapLayout.PAPER.end.y - MapLayout.LEGEND.end.y, 16.0, "图例到纸底 16")
	ctx.near(MapLayout.GRAPH.size.y + 24.0 + 12.0 + MapLayout.LEGEND.size.y + 16.0,
		MapLayout.PAPER.size.y, "纸内纵向账 24 + 316 + 12 + 24 + 16 = 392")
	ctx.check(MapLayout.PAPER.size.y > MapLayout.GRAPH.size.y, "图区与图例是纸内的两层，不是同一块")


## M01：地图面积 ≥ 安全区的 73%。分母一律是安全区 —— 混用窗口面积会让数字看着达标而实际不是。
func _check_map_area(ctx: RefCounted) -> void:
	var safe: float = MapLayout.SAFE_AREA.size.x * MapLayout.SAFE_AREA.size.y
	var ratio: float = MapLayout.PAPER.size.x * MapLayout.PAPER.size.y / safe
	ctx.near(ratio, M01_MAP_RATIO, "M01 地图占安全区 %.5f" % ratio)
	ctx.check(ratio >= M01_MAP_RATIO_MIN, "M01 地图 ≥ 73%%（%.5f）" % ratio)


## M01/M03 的落点账：3 列 6 层 18 个节点，中心 x = 200 + 280c、y = 384 − 52t（屏坐标）。
## 节点中心在图区内；**可见圆**（含当前圈的外扩）落在纸的内容区里。
func _check_nodes(ctx: RefCounted) -> void:
	var model: MapModel = MapModel.new()
	model.generate(20261008)
	ctx.equal(model.nodes().size(), MapModel.TIERS * MapModel.COLUMNS,
		"3 列 6 层 = %d 个节点" % (MapModel.TIERS * MapModel.COLUMNS))
	var worst: int = 0
	for tier: int in MapModel.TIERS:
		for column: int in MapModel.COLUMNS:
			var on_screen: Vector2 = MapLayout.to_screen(MapLayout.node_position(tier, column))
			ctx.near(on_screen.x, 200.0 + 280.0 * float(column),
				"第 %d 层第 %d 列的中心 x = 200 + 280c" % [tier, column])
			ctx.near(on_screen.y, 384.0 - 52.0 * float(tier),
				"第 %d 层第 %d 列的中心 y = 384 − 52t" % [tier, column])
			if not MapLayout.GRAPH.has_point(on_screen):
				worst += 1
	ctx.equal(worst, 0, "18 个节点中心都落在 MAP_GRAPH 里")
	# 可见圆 + 当前圈的外扩。外扩 4 是 §2.2 给当前圈的数。
	var reach: float = MapLayout.NODE_RADIUS + MapNodePainter.RING_GROW
	var content: Rect2 = MapLayout.PAPER.grow(-MapLayout.PAPER_INSET)
	var outside: int = 0
	for tier: int in MapModel.TIERS:
		for column: int in MapModel.COLUMNS:
			var on_screen: Vector2 = MapLayout.to_screen(MapLayout.node_position(tier, column))
			var box: Rect2 = Rect2(on_screen - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
			if not content.encloses(box):
				outside += 1
	ctx.equal(outside, 0, "每个节点的可见圆（含当前圈外扩 4）都在纸的内容区内")


## M03：可见圆 / 命中圆直径 40；相邻行中心 52 → 净空 12；列跨度 280 是图布局参数不是间距档位。
func _check_clearance(ctx: RefCounted) -> void:
	ctx.equal(MapLayout.NODE_RADIUS * 2.0, 40.0, "节点直径 40（可见圆 = 命中圆）")
	ctx.equal(MapView.NODE_RADIUS, MapLayout.NODE_RADIUS, "画的圆与命中的圆是同一个半径")
	ctx.near(MapLayout.tier_pitch(), 52.0, "相邻行中心间距 52")
	ctx.near(MapLayout.tier_pitch() - MapLayout.NODE_RADIUS * 2.0, 12.0, "行间净空 52 − 40 = 12")
	ctx.check(MapLayout.column_pitch() > MapLayout.NODE_RADIUS * 2.0, "列跨度比一个节点宽得多（不挤在一起）")
	ctx.equal(MapLayout.SYMBOL_RADIUS * 2.0, 24.0, "符号框 24×24")
	# 可见圆 = 命中圆 = Ø40（M03）。外圈的**外缘**停在这个圆上，线心因此内缩半个环宽 ——
	# 线心摆在外缘上的话，1 宽的环会把看得见的轮廓撑到 Ø41，两个「同一个圆」当场差 1。
	var edge: float = _ring_edge(MapLayout.NODE_RADIUS, MapNodePainter.State.UNREACHABLE)
	ctx.near(edge * 2.0, 40.0, "普通节点的可见轮廓 = Ø40（M03：可见圆/命中圆直径 40）")
	ctx.near(edge * 2.0, MapView.NODE_RADIUS * 2.0, "可见圆与命中圆是同一个 Ø40")
	ctx.near(_ring_edge(MapLayout.NODE_RADIUS, MapNodePainter.State.CURRENT) * 2.0, 48.0,
		"当前圈外缘 = Ø40 + 外扩 4×2（§2.2 的「外扩 4」按外缘算）")


## 某状态外圈的**外缘**半径：画的路径内缩了半个环宽，外缘才是契约上那个圆。
static func _ring_edge(radius: float, state: MapNodePainter.State) -> float:
	return MapNodePainter.ring_path(radius + MapNodePainter.STATE_RING_GROW[state], state) \
		+ MapNodePainter.STATE_RING_WIDTH[state] * 0.5


## 短名框：rect(center.x + 28, center.y − 12, 96, 24)、字 16。它整份落在纸的内容区里，
## 与节点自身的可见圆**不相交**（M03：标签框与节点交集面积 = 0）。
func _check_labels(ctx: RefCounted) -> void:
	var gap: float = MapLayout.LABEL_GAP - MapLayout.NODE_RADIUS
	ctx.check(gap > 0.0, "短名框让开节点圆 %.2f px" % gap)
	ctx.equal(MapLayout.LABEL_FONT_SIZE, 16, "短名 16 号字")
	ctx.near(MapLayout.LABEL_BASELINE_RATIO, 0.35, "基线与行心的偏移沿用全工程那一处口径")
	var content: Rect2 = MapLayout.PAPER.grow(-MapLayout.PAPER_INSET)
	for tier: int in MapModel.TIERS:
		for column: int in MapModel.COLUMNS:
			var local: Rect2 = MapLayout.node_label_rect(tier, column)
			var center: Vector2 = MapLayout.node_position(tier, column)
			ctx.near(local.position.x, center.x + 28.0, "短名框左缘 = 中心 + 28")
			ctx.near(local.size, MapLayout.LABEL_SIZE, "短名框 96×24")
			ctx.near(local.position.y + local.size.y * 0.5, center.y, "短名框与节点同一行心")
			var on_paper: Rect2 = Rect2(MapLayout.to_screen(local.position), local.size)
			ctx.check(content.encloses(on_paper),
				"第 %d 层第 %d 列的短名框在纸的内容区内 %s" % [tier, column, on_paper])
			ctx.check(local.position.x >= center.x + MapLayout.NODE_RADIUS,
				"短名框不压在节点圆上（%s ≥ %s）" % [local.position.x, center.x + MapLayout.NODE_RADIUS])
			var baseline: Vector2 = MapLayout.node_label_baseline(tier, column)
			ctx.check(baseline.x >= local.position.x and baseline.x < local.end.x,
				"基线起点落在短名框内")
			ctx.check(baseline.y > local.position.y and baseline.y < local.end.y,
				"基线落在短名框的行高之间")


## 图例：4 项 × 224 = 896 正好铺满那一条；圆 Ø12、文字距圆 8（6 + 6 + 8 = 20）。
func _check_legend(ctx: RefCounted) -> void:
	ctx.near(MapLayout.LEGEND_ITEM_WIDTH * 4.0, MapLayout.LEGEND.size.x, "四项正好铺满图例那一条")
	ctx.equal(MapLayout.LEGEND_NODE_RADIUS * 2.0, 12.0, "图例圆直径 12")
	ctx.near(MapLayout.LEGEND_LABEL_X - MapLayout.LEGEND_NODE_X - MapLayout.LEGEND_NODE_RADIUS, 8.0,
		"文字距圆 8")
	ctx.equal(MapLayout.LEGEND_FONT_SIZE, 12, "图例名 12 号字")
	ctx.equal(MapView.LEGEND_STATES.size(), 4, "图例四项")
	for index: int in 4:
		var center: Vector2 = MapLayout.legend_node_position(index)
		var baseline: Vector2 = MapLayout.legend_label_baseline(index)
		ctx.near(center.y, MapLayout.to_local(Vector2(0.0, MapLayout.LEGEND.position.y
			+ MapLayout.LEGEND.size.y * 0.5)).y, "图例圆在图例行里纵向居中")
		ctx.check(baseline.x > center.x + MapLayout.LEGEND_NODE_RADIUS, "文字排在圆的右边")
		ctx.check(baseline.x < MapLayout.to_local(
			Vector2(MapLayout.LEGEND.position.x + MapLayout.LEGEND_ITEM_WIDTH * float(index + 1), 0.0)).x,
			"第 %d 项的文字不越出它自己那一格" % index)


## 动作条 56：提示靠左、返回与继续靠右，两颗按钮间距 16、主按钮贴住右缘。
func _check_actions(ctx: RefCounted) -> void:
	for pair: Array in [["提示", MapLayout.HINT_RECT], ["返回编辑器", MapLayout.BACK_RECT],
			["继续", MapLayout.PRIMARY_RECT]]:
		ctx.check(MapLayout.ACTIONS.encloses(pair[1]), "%s 在动作条内" % pair[0])
	ctx.check(not _overlaps(MapLayout.HINT_RECT, MapLayout.BACK_RECT), "提示不让返回按钮")
	ctx.check(not _overlaps(MapLayout.HINT_RECT, MapLayout.PRIMARY_RECT), "提示不让主按钮")
	ctx.check(not _overlaps(MapLayout.BACK_RECT, MapLayout.PRIMARY_RECT), "返回与继续不重叠")
	ctx.near(MapLayout.PRIMARY_RECT.position.x - MapLayout.BACK_RECT.end.x, 16.0, "返回与继续间距 16")
	ctx.near(MapLayout.PRIMARY_RECT.end.x, MapLayout.SCREEN.x - 16.0, "主按钮贴住内容右缘")
	ctx.equal(MapLayout.BACK_RECT.size.y, 48.0, "返回键高 48")
	ctx.equal(MapLayout.PRIMARY_RECT.size, Vector2(144.0, 48.0), "继续键 144×48")
	for rect: Rect2 in [MapLayout.BACK_RECT, MapLayout.PRIMARY_RECT]:
		ctx.near(rect.position.y + rect.size.y * 0.5, MapLayout.ACTIONS.position.y
			+ MapLayout.ACTIONS.size.y * 0.5, "按钮在动作条里纵向居中")
	ctx.check(MapLayout.HINT_RECT.end.x <= MapLayout.BACK_RECT.position.x, "提示的右缘不越过返回键")


## 触控目标下限 44 设备像素 = 22 逻辑像素；§1 另外给了可交互矩形的 24 下限。
func _check_touch_targets(ctx: RefCounted) -> void:
	var minimum: float = MIN_TOUCH_DEVICE_PX / DEVICE_SCALE
	var node: float = MapLayout.NODE_RADIUS * 2.0 * DEVICE_SCALE
	ctx.check(node >= MIN_TOUCH_DEVICE_PX,
		"节点命中圆 %d 设备像素 ≥ %d" % [int(node), int(MIN_TOUCH_DEVICE_PX)])
	for pair: Array in [["返回编辑器", MapLayout.BACK_RECT], ["继续", MapLayout.PRIMARY_RECT]]:
		var rect: Rect2 = pair[1]
		ctx.check(rect.size.x >= MIN_INTERACTIVE and rect.size.y >= MIN_INTERACTIVE,
			"%s %s 不小于 §1 的最小互动矩形 %s" % [pair[0], rect.size, MIN_INTERACTIVE])


## 间距只能取间距档位（4/8/12/16/24）。随手写个 17 就会让节奏散掉。
func _check_spacing_system(ctx: RefCounted) -> void:
	var values: Dictionary = {
		"SPACING_8": MapLayout.SPACING_8, "SPACING_12": MapLayout.SPACING_12,
		"SPACING_16": MapLayout.SPACING_16, "PAPER_BAND": MapLayout.PAPER_BAND,
		"PAPER_INSET": MapLayout.PAPER_INSET,
	}
	for name: String in values:
		ctx.check(SPACING_SCALE.has(values[name]), "%s = %s 是间距系统里的档位" % [name, values[name]])
	# 短名框的 28 与列跨度 280 都**不是**间距档位：前者是 §2.2 给死的相对偏移，
	# 后者是图布局参数（§2.2 原话）—— 它们不该出现在档位表里。
	ctx.equal(MapLayout.LABEL_GAP, 28.0, "短名框偏移 28（§2.2 给死的相对量，不是档位）")
	ctx.check(not SPACING_SCALE.has(MapLayout.LABEL_GAP), "短名框偏移不是间距档位")
	ctx.check(not SPACING_SCALE.has(MapLayout.column_pitch()), "列跨度 280 不是间距档位")


## G10：两种语言下按钮与文字都得一行放得下。英文比中文长，是最坏情况 —— 只测中文等于没测。
func _check_both_locales(ctx: RefCounted, tree: SceneTree) -> void:
	var settings: Node = tree.root.get_node_or_null(^"Settings")
	if not ctx.check(settings != null, "Settings 单例存在，可做双语断言"):
		return
	var original: String = settings.get_locale()
	for locale: String in LOCALES:
		settings.set_locale(locale, false)
		_check_text_fits(ctx, locale)
	settings.set_locale(original, false)
	ctx.equal(settings.get_locale(), original, "测试结束后语言恢复原样")


## 一行文字放不放得下，用的就是 UiKit 那把尺（与屏幕摆位同一处口径）。
##
## 当前位置那行是**拼**出来的，跟 map_screen._status_text 一样 —— 直接写一整句中文的话，
## 英文那一遍查不到 key，只会原样返回中文，双语断言就白做了。
func _check_text_fits(ctx: RefCounted, locale: String) -> void:
	var status: String = TranslationServer.translate("当前位置：") \
		+ TranslationServer.translate("第 %d 层") % MapModel.TIERS \
		+ " · " + TranslationServer.translate("工坊")
	var rows: Array = [
		["标题", TranslationServer.translate("路线图"), MapLayout.TITLE_RECT, ContractTheme.FONT_TITLE],
		["提示", TranslationServer.translate("点亮的节点可以前往"), MapLayout.HINT_RECT,
			ContractTheme.FONT_BODY],
		["返回键", TranslationServer.translate("返回编辑器"), MapLayout.BACK_RECT,
			ContractTheme.FONT_BODY],
		["继续键", TranslationServer.translate("继续"), MapLayout.PRIMARY_RECT,
			ContractTheme.FONT_BUTTON],
		["当前位置", status, MapLayout.STATUS_RECT, ContractTheme.FONT_BODY],
	]
	for row: Array in rows:
		var text: String = row[1]
		var width: float = UiKit.text_units(text) * float(row[3])
		ctx.check(width <= float(row[2].size.x),
			"[%s] %s「%s」占 %.1f ≤ %s" % [locale, row[0], text, width, row[2].size.x])


## 严格重叠判定。Rect2.intersects() 默认把「仅相邻」也算相交，这里不要那种口径。
static func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x \
		and a.position.y < b.end.y and b.position.y < a.end.y
