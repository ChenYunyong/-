## test_layout.gd
## 职责：960×540 布局的验收 —— 分区不重叠不越界、间距取自间距系统、触控目标够大、中英文都排得下。
## 所属系统：tests
## 依赖：EditorLayout, UiKit, ArcaneTheme, BoardModel, CardFace, Snap, MapView, BoardView, CombatSim
## 禁止：本文件不得写入布局常量，只断言。
##
## 为什么值得单独立一条：布局错位在 headless 下**不会报错**，只会让真机上两个控件叠在一起。
## 而且这类错误最容易在切到英文时才出现（英文文案比中文长），所以下面每一项布局断言
## 都跑两遍：中文一遍、英文一遍。

extends RefCounted

## 窗口 / 画布 = 2，来自 project.godot。触控下限 44 **设备像素**（docs/06 §1）换算成 22 逻辑像素。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## docs/06 §1 的间距系统 4/8/12/16/24，在 960×540 基准下 ×3。
const SPACING_SCALE: Array[float] = [12.0, 24.0, 36.0, 48.0, 72.0]

const LOCALES: PackedStringArray = ["zh_CN", "en"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_layout")
	_check_screen_matches_project(ctx)
	_check_regions_inside(ctx)
	_check_regions_do_not_overlap(ctx)
	_check_stacking(ctx)
	_check_frames(ctx)
	_check_spacing_system(ctx)
	_check_card_size(ctx)
	_check_touch_targets(ctx)
	_check_tray_scrolls(ctx)
	_check_top_bar_both_locales(ctx, tree)
	_check_overlap_detector(ctx)


func _check_screen_matches_project(ctx: RefCounted) -> void:
	ctx.equal(EditorLayout.SCREEN.x, ProjectSettings.get_setting("display/window/size/viewport_width"),
		"布局基准宽 = project.godot 的画布宽")
	ctx.equal(EditorLayout.SCREEN.y, ProjectSettings.get_setting("display/window/size/viewport_height"),
		"布局基准高 = project.godot 的画布高")


## 四个分区都必须完整落在 960×540 里 —— 越界部分在真机上直接看不见。
func _check_regions_inside(ctx: RefCounted) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, EditorLayout.SCREEN)
	for pair: Array in _regions():
		var rect: Rect2 = pair[1]
		ctx.check(screen.encloses(rect), "%s 落在画布内 %s" % [pair[0], rect])


## 四个分区两两不重叠。
func _check_regions_do_not_overlap(ctx: RefCounted) -> void:
	var regions: Array = _regions()
	for i: int in regions.size():
		for j: int in range(i + 1, regions.size()):
			ctx.check(not _overlaps(regions[i][1], regions[j][1]),
				"%s 与 %s 不重叠" % [regions[i][0], regions[j][0]])


## 分区的相对位置：顶栏在上、画布与详情左右并排、仓库在最下。
func _check_stacking(ctx: RefCounted) -> void:
	var top: Rect2 = EditorLayout.top_bar()
	var canvas: Rect2 = EditorLayout.canvas_frame()
	var detail: Rect2 = EditorLayout.detail_panel()
	var tray: Rect2 = EditorLayout.tray()

	ctx.near(top.end.y + EditorLayout.GAP, canvas.position.y, "顶栏下方留一个间距就是画布")
	ctx.near(canvas.end.x + EditorLayout.GAP, detail.position.x, "画布右侧留一个间距就是详情")
	ctx.near(canvas.end.y + EditorLayout.GAP, tray.position.y, "画布下方留一个间距就是仓库")
	ctx.near(tray.end.y + EditorLayout.MARGIN, EditorLayout.SCREEN.y, "仓库下方留一个安全边距就是画布底")
	ctx.near(top.end.y - top.position.y, EditorLayout.TOP_BAR_HEIGHT, "顶栏高度")
	ctx.near(detail.end.y, canvas.end.y, "详情与画布等高（同一行）")
	ctx.near(tray.end.x, top.end.x, "仓库与顶栏同宽")
	# 左右各留一个安全边距，中间不留空 —— 分区必须把宽度吃满，否则右边会秃一块。
	ctx.near(canvas.position.x, EditorLayout.MARGIN, "画布贴着左边距")
	ctx.near(EditorLayout.SCREEN.x - detail.end.x, EditorLayout.MARGIN, "详情贴着右边距")


## 木框要让出来：控件铺在框内，否则会被 9px 的木纹压住。
func _check_frames(ctx: RefCounted) -> void:
	var border: float = EditorLayout.FRAME_BORDER
	ctx.equal(border, ArcaneTheme.FRAME_BORDER_WIDTH, "布局的木框宽度与主题同源（改主题不会静默脱节）")

	var frame: Rect2 = EditorLayout.canvas_frame()
	var view: Rect2 = EditorLayout.canvas_view()
	ctx.near(view.position.x - frame.position.x, border, "画布控件让出左框")
	ctx.near(view.position.y - frame.position.y, border, "画布控件让出上框")
	ctx.near(frame.end.x - view.end.x, border, "画布控件让出右框")
	ctx.near(frame.end.y - view.end.y, border, "画布控件让出下框")

	var panel: Rect2 = EditorLayout.detail_panel()
	var body: Rect2 = EditorLayout.detail_body()
	var title: Rect2 = EditorLayout.detail_title_bar()
	ctx.check(panel.encloses(body), "详情内芯在木框内")
	ctx.near(body.position.x - panel.position.x, border, "详情内芯让出左框")
	ctx.check(body.encloses(title), "标题栏在详情内芯里")
	ctx.near(title.position.y, body.position.y, "标题栏贴着内芯顶部")
	ctx.near(title.end.x, body.end.x, "标题栏横贯通栏")
	ctx.check(body.has_point(EditorLayout.DETAIL_CONTENT_ORIGIN), "详情内容起点在内芯里")
	ctx.check(EditorLayout.DETAIL_CONTENT_WIDTH > 0.0, "详情内容宽度为正")
	ctx.near(EditorLayout.DETAIL_CONTENT_ORIGIN.x + EditorLayout.DETAIL_CONTENT_WIDTH,
		body.end.x - EditorLayout.DETAIL_PADDING, "内容右边界留出右内边距")

	var tray_frame: Rect2 = EditorLayout.tray()
	var tray_view: Rect2 = EditorLayout.tray_view()
	ctx.check(tray_frame.encloses(tray_view), "仓库滚动区在木框内")
	ctx.near(tray_view.position.x - tray_frame.position.x, border, "仓库滚动区让出左框")
	ctx.near(tray_frame.end.y - tray_view.end.y, border, "仓库滚动区让出下框")


## 间距只能取间距系统里的档位（4/8/12/16/24 ×3）。随手写个 17 就会让节奏散掉。
func _check_spacing_system(ctx: RefCounted) -> void:
	var values: Dictionary = {
		"MARGIN": EditorLayout.MARGIN, "GAP": EditorLayout.GAP,
		"TRAY_CHIP_GAP": EditorLayout.TRAY_CHIP_GAP, "DETAIL_PADDING": EditorLayout.DETAIL_PADDING,
	}
	for name: String in values:
		ctx.check(SPACING_SCALE.has(values[name]), "%s = %s 是间距系统里的档位" % [name, values[name]])


## 「同一张牌在仓库和画布上一样大」—— 三处卡牌尺寸必须是同一个数。
func _check_card_size(ctx: RefCounted) -> void:
	ctx.equal(CardFace.SIZE, BoardModel.CARD_SIZE, "画布卡片尺寸 = 模型尺寸")
	ctx.equal(EditorLayout.TRAY_CHIP_SIZE, BoardModel.CARD_SIZE.x, "仓库卡位尺寸 = 画布卡片尺寸")
	var canvas: Rect2 = EditorLayout.canvas_view()
	ctx.check(canvas.size.x >= BoardModel.CARD_SIZE.x * 2.0 and canvas.size.y >= BoardModel.CARD_SIZE.y * 2.0,
		"画布至少放得下两张卡（%s）" % canvas.size)


## 触控目标下限 44 设备像素 = 22 逻辑像素。
func _check_touch_targets(ctx: RefCounted) -> void:
	var minimum: float = MIN_TOUCH_DEVICE_PX / DEVICE_SCALE
	var targets: Dictionary = {
		"画布卡片": BoardModel.CARD_SIZE,
		"仓库卡位": Vector2(EditorLayout.TRAY_CHIP_SIZE, EditorLayout.TRAY_CHIP_SIZE),
		"连线接口": Vector2(BoardView.PORT_HIT_RADIUS * 2.0, BoardView.PORT_HIT_RADIUS * 2.0),
		"路线图节点": Vector2(MapView.NODE_RADIUS * 2.0, MapView.NODE_RADIUS * 2.0),
	}
	for name: String in targets:
		var size: Vector2 = targets[name]
		ctx.check(size.x >= minimum and size.y >= minimum,
			"%s %s ≥ %s 逻辑像素（= %d 设备像素）" % [name, size, minimum, int(minimum * DEVICE_SCALE)])
	ctx.check(UiKit.button_height() >= minimum, "按钮高度 %s ≥ %s" % [UiKit.button_height(), minimum])


## 19 张卡的仓库一定放不下，所以横向滚动必须是**真的需要**（否则那段代码是摆设）。
func _check_tray_scrolls(ctx: RefCounted) -> void:
	var count: int = CardCatalog.all().size()
	var content: float = float(count) * EditorLayout.TRAY_CHIP_SIZE
	if count > 1:
		content += float(count - 1) * EditorLayout.TRAY_CHIP_GAP
	var window: float = EditorLayout.TRAY_VIEW_SIZE.x
	ctx.check(content > window, "仓库内容 %s 宽 > 可视区 %s（所以确实要滚）" % [content, window])
	ctx.near(fmod(EditorLayout.TRAY_SCROLL_STEP, EditorLayout.TRAY_CHIP_GAP), 0.0,
		"滚动步长是卡位间距的整数倍（滚完不会停在半张卡上）")
	ctx.check(EditorLayout.TRAY_CHIP_SIZE <= EditorLayout.TRAY_VIEW_SIZE.y,
		"卡位高度不超出仓库可视区")
	ctx.check(content - window > EditorLayout.TRAY_SCROLL_STEP,
		"滚动余量大于一步（一步滚得到东西，不是空滚）")


## 顶栏在两种语言下都要排得下：标题、状态、按钮组互不重叠且都在条内。
## 英文文案比中文长，是最坏情况 —— 只测中文等于没测。
func _check_top_bar_both_locales(ctx: RefCounted, tree: SceneTree) -> void:
	var settings: Node = tree.root.get_node_or_null(^"Settings")
	if not ctx.check(settings != null, "Settings 单例存在，可做双语断言"):
		return
	var original: String = settings.get_locale()
	# 先证明这个测试有牙：造一个超长按钮，它必须被判为越界。
	var bar: Rect2 = EditorLayout.top_bar()
	var huge: Rect2 = Rect2(bar.end.x, bar.position.y, 400.0, UiKit.button_height())
	ctx.check(not bar.encloses(huge), "反向对照：越界的按钮会被判为放不下")

	for locale: String in LOCALES:
		settings.set_locale(locale, false)
		_check_top_bar(ctx, locale)
	settings.set_locale(original, false)
	ctx.equal(settings.get_locale(), original, "测试结束后语言恢复原样")


func _check_top_bar(ctx: RefCounted, locale: String) -> void:
	var bar: Rect2 = EditorLayout.top_bar()
	var title: Rect2 = EditorLayout.TOP_TITLE_RECT
	var status: Rect2 = EditorLayout.TOP_STATUS_RECT
	var buttons: Array[Rect2] = EditorLayout.top_button_rects()

	ctx.check(bar.encloses(title), "[%s] 标题在顶栏内" % locale)
	ctx.check(bar.encloses(status), "[%s] 状态在顶栏内" % locale)
	ctx.check(bar.encloses(status) and not _overlaps(title, status), "[%s] 标题与状态不重叠" % locale)
	# 文字必须真的放得下：标题与状态是 Label，字太长不会被裁而是画出去。
	var title_text: String = TranslationServer.translate("模块编辑器")
	var status_text: String = TranslationServer.translate("卡片 %d · 丝线 %d") % [12, 8]
	ctx.check(UiKit.text_units(title_text) * float(ArcaneTheme.BODY_FONT_SIZE) <= title.size.x,
		"[%s] 标题文案「%s」放得下" % [locale, title_text])
	ctx.check(UiKit.text_units(status_text) * float(ArcaneTheme.BODY_FONT_SIZE) <= status.size.x,
		"[%s] 状态文案「%s」放得下" % [locale, status_text])

	ctx.equal(buttons.size(), EditorLayout.TOP_BUTTONS.size(), "[%s] 按钮数一致" % locale)
	for index: int in buttons.size():
		var button: Rect2 = buttons[index]
		var key: String = EditorLayout.TOP_BUTTONS[index]
		ctx.check(bar.encloses(button), "[%s] 按钮「%s」在顶栏内" % [locale, key])
		ctx.check(button.position.x >= status.end.x,
			"[%s] 按钮「%s」不压到状态文字上（%s ≥ %s）" % [locale, key, button.position.x, status.end.x])
		if index > 0:
			ctx.check(buttons[index - 1].position.x - button.end.x >= EditorLayout.GAP - 0.01,
				"[%s] 按钮「%s」与右邻保持一个间距" % [locale, key])
	# 最右的按钮必须贴着右边距 —— 主动作不能飘在中间。
	ctx.near(buttons[0].end.x, bar.end.x, "[%s] 最右按钮贴住顶栏右边界" % locale)
	# 按钮纵向居中。
	var centre: float = bar.position.y + bar.size.y * 0.5
	ctx.near(buttons[0].position.y + buttons[0].size.y * 0.5, centre, "[%s] 按钮纵向居中" % locale)


## 反向对照：重叠判定本身必须抓得到重叠。一个永远返回 false 的判定会让上面全绿。
func _check_overlap_detector(ctx: RefCounted) -> void:
	ctx.check(_overlaps(Rect2(0.0, 0.0, 10.0, 10.0), Rect2(5.0, 5.0, 10.0, 10.0)), "反向对照：明显重叠被判为重叠")
	ctx.check(not _overlaps(Rect2(0.0, 0.0, 10.0, 10.0), Rect2(10.0, 0.0, 10.0, 10.0)),
		"反向对照：仅相邻（不交叠）不算重叠")


# ---------------------------------------------------------------- 工具

## 参与重叠 / 越界检查的分区。左画布与详情同属一行，也要彼此不重叠。
func _regions() -> Array:
	return [
		["顶栏", EditorLayout.top_bar()],
		["书页画布", EditorLayout.canvas_frame()],
		["卡片详情", EditorLayout.detail_panel()],
		["卡牌仓库", EditorLayout.tray()],
	]


## 严格重叠判定。Rect2.intersects() 默认把「仅相邻」也算相交，这里不要那种口径。
static func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x \
		and a.position.y < b.end.y and b.position.y < a.end.y
