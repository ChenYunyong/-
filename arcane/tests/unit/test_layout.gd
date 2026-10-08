## test_layout.gd
## 职责：960×540 版面的验收 —— docs/14 §2.1 的几何表逐条对照，外加 §4 的 E01/E02/E03 面积账。
## 所属系统：tests
## 依赖：EditorLayout, UiKit, ContractTheme, BoardModel, CardFace, BoardView, MapView
## 禁止：本文件不得写入布局常量，只断言 —— 数字的唯一来源是 EditorLayout / docs/14。
##
## 为什么值得单独立一条：布局错位在 headless 下**不会报错**，只会让真机上两个控件叠在一起。
## 而且这类错误最容易在切到英文时才出现（英文文案比中文长），所以文字放得下的断言都跑两遍。
##
## PET-93：断言对象从旧版「左画布 + 右详情 + 底仓库」换成 §2.1 的头栏 / 书本 / 浮层 / 书槽。
## 详情从常驻侧栏变成浮层之后它**故意**压在书上，所以「分区不重叠」那条必须把它排除在外，
## 另立一条「浮层要整个落在净纸里」—— 否则要么漏掉真重叠，要么把设计当缺陷判红。

extends RefCounted

## 窗口 / 画布 = 2，来自 project.godot。触控下限 44 **设备像素**（docs/06 §1）换算成 22 逻辑像素。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## docs/14 §1 的最小互动矩形。
const MIN_INTERACTIVE: float = 24.0
## docs/14 §4 的每屏验收数字。阈值散在断言里就会变成两处口径，故集中在这里。
const E01_BOOK_RATIO: float = 0.67538
const E01_PAPER_RATIO: float = 0.59413
const E02_OPEN_RATIO: float = 0.48544
## E03：书顶的 y —— 内容顶端 16 + 头栏 40 + 净空 8。
const E03_TOP_BUDGET: float = 64.0
## §1 的间距档位（不再乘旧倍率）。
const SPACING_SCALE: Array[float] = [4.0, 8.0, 12.0, 16.0, 24.0]

const LOCALES: PackedStringArray = ["zh_CN", "en"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_layout")
	_check_screen_matches_project(ctx)
	_check_safe_area(ctx)
	_check_regions_inside(ctx)
	_check_regions_do_not_overlap(ctx)
	_check_stacking(ctx)
	_check_book_layers(ctx)
	_check_screen_areas(ctx)
	_check_spacing_system(ctx)
	_check_card_size(ctx)
	_check_touch_targets(ctx)
	_check_top_bar_both_locales(ctx, tree)
	_check_overlap_detector(ctx)


func _check_screen_matches_project(ctx: RefCounted) -> void:
	ctx.equal(EditorLayout.SCREEN.x, ProjectSettings.get_setting("display/window/size/viewport_width"),
		"布局基准宽 = project.godot 的画布宽")
	ctx.equal(EditorLayout.SCREEN.y, ProjectSettings.get_setting("display/window/size/viewport_height"),
		"布局基准高 = project.godot 的画布高")


## G03：可交互的东西一律不出 (8,8,944,524)。全屏暗底是背景不是交互包络，故不在这一组里。
func _check_safe_area(ctx: RefCounted) -> void:
	var safe: Rect2 = EditorLayout.SAFE_AREA
	ctx.check(Rect2(Vector2.ZERO, EditorLayout.SCREEN).encloses(safe), "安全区落在画布内")
	for pair: Array in _interactive():
		ctx.check(safe.encloses(pair[1]), "%s 在安全区内 %s" % [pair[0], pair[1]])


## 每个分区都必须完整落在 960×540 里 —— 越界部分在真机上直接看不见。
func _check_regions_inside(ctx: RefCounted) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, EditorLayout.SCREEN)
	for pair: Array in _regions():
		ctx.check(screen.encloses(pair[1]), "%s 落在画布内 %s" % [pair[0], pair[1]])


## 四个分区两两不重叠。浮层不在这一组里 —— 它按设计压在净纸上，见 _check_detail_popover。
func _check_regions_do_not_overlap(ctx: RefCounted) -> void:
	var regions: Array = _regions()
	for i: int in regions.size():
		for j: int in range(i + 1, regions.size()):
			ctx.check(not _overlaps(regions[i][1], regions[j][1]),
				"%s 与 %s 不重叠" % [regions[i][0], regions[j][0]])


## 分区的相对位置与间距：头栏在上、书本撑满、书槽在下，三个间距都取自间距档位。
## E03 的「顶部预算」也在这里量：内容顶端 16 + 头栏 40 + 净空 8 = 书顶 64。
func _check_stacking(ctx: RefCounted) -> void:
	var header: Rect2 = EditorLayout.top_bar()
	var book: Rect2 = EditorLayout.book()
	var tray: Rect2 = EditorLayout.tray()

	ctx.near(header.position.y, EditorLayout.SPACING_16, "内容顶端 = 默认内容边距")
	ctx.near(header.size.y, EditorLayout.SPACING_24 + EditorLayout.SPACING_16, "头栏高度 40")
	ctx.near(book.position.y, header.end.y + EditorLayout.SPACING_8, "头栏到书本净空 8")
	ctx.check(book.position.y <= E03_TOP_BUDGET,
		"E03 书本上方总预算 ≤ %s（实际 %s）" % [E03_TOP_BUDGET, book.position.y])
	ctx.near(tray.position.y, book.end.y + EditorLayout.SPACING_12, "书本到书槽间距 12")
	ctx.near(tray.end.x, EditorLayout.SCREEN.x - EditorLayout.SPACING_16, "书槽右边距 16")
	ctx.near(tray.position.x, EditorLayout.SPACING_16, "书槽左边距 16")
	ctx.near(tray.end.y, EditorLayout.SCREEN.y - EditorLayout.SPACING_16, "书槽下边距 16")
	ctx.near(book.end.x, tray.end.x, "书本与书槽同宽")
	ctx.near(book.position.x, tray.position.x, "书本与书槽同左缘")


## 书本三层：8px 暖色边带包住净纸，净纸再内缩 16；书脊是中间那条 16 宽的装饰折影。
func _check_book_layers(ctx: RefCounted) -> void:
	var book: Rect2 = EditorLayout.book()
	var paper: Rect2 = EditorLayout.paper()
	var spine: Rect2 = EditorLayout.spine()

	ctx.check(book.encloses(paper), "净纸在书本内")
	ctx.near(paper.position.x - book.position.x, EditorLayout.SPACING_16, "净纸让出左内缩 16")
	ctx.near(paper.position.y - book.position.y, EditorLayout.SPACING_16, "净纸让出上内缩 16")
	ctx.near(book.end.x - paper.end.x, EditorLayout.SPACING_16, "净纸让出右内缩 16")
	ctx.near(book.end.y - paper.end.y, EditorLayout.SPACING_16, "净纸让出下内缩 16")
	# 净纸内缩 16，其中最外那 8 是材质边带（ContractTheme.PAGE_BAND）—— 边带因此贴着书本轮廓
	# 而不是贴着纸，纸看上去是「放」在书上，不是被框住。
	ctx.equal(ContractTheme.PAGE_BAND, 8.0, "材质边带 8")
	ctx.check(ContractTheme.PAGE_BAND < paper.position.x - book.position.x,
		"边带比净纸内缩窄，两者之间留得出书本底色")

	ctx.check(paper.encloses(spine), "书脊在净纸内")
	ctx.near(spine.position.x + spine.size.x * 0.5, paper.position.x + paper.size.x * 0.5,
		"书脊居中于净纸")
	ctx.near(spine.position.y, paper.position.y, "书脊与净纸等高、同顶")
	ctx.near(spine.size.y, paper.size.y, "书脊贯穿净纸整高")
	# 画布控件就是净纸本身：多扣一层内缩会让 E01 的净纸面积对不上 §2.1。
	ctx.equal(EditorLayout.canvas_view(), paper, "画布控件矩形 = 净纸")


## §4 的三条面积账。分母一律是安全区 944×524 —— 混用窗口面积会让数字看着达标而实际不是。
func _check_screen_areas(ctx: RefCounted) -> void:
	var safe: float = EditorLayout.SAFE_AREA.size.x * EditorLayout.SAFE_AREA.size.y
	var book: Rect2 = EditorLayout.book()
	var paper: Rect2 = EditorLayout.paper()
	var popover: Rect2 = EditorLayout.popover()

	var book_ratio: float = book.size.x * book.size.y / safe
	var paper_ratio: float = paper.size.x * paper.size.y / safe
	ctx.near(book_ratio, E01_BOOK_RATIO, "E01 书本占安全区 %.5f" % book_ratio)
	ctx.check(book_ratio >= 0.67, "E01 书本 ≥ 67%%（%.5f）" % book_ratio)
	ctx.near(paper_ratio, E01_PAPER_RATIO, "E01 净纸占安全区 %.5f" % paper_ratio)
	ctx.check(paper_ratio >= 0.59, "E01 净纸 ≥ 59%%（%.5f）" % paper_ratio)

	var open_area: float = paper.size.x * paper.size.y - popover.size.x * popover.size.y
	var open_ratio: float = open_area / safe
	ctx.near(open_ratio, E02_OPEN_RATIO, "E02 详情打开后剩余纸面 %.5f" % open_ratio)
	ctx.check(open_ratio >= 0.48, "E02 扣掉浮层后仍 ≥ 48%%（%.5f）" % open_ratio)


## 间距只能取间距档位（4/8/12/16/24）。随手写个 17 就会让节奏散掉。
func _check_spacing_system(ctx: RefCounted) -> void:
	var values: Dictionary = {
		"SPACING_4": EditorLayout.SPACING_4, "SPACING_8": EditorLayout.SPACING_8,
		"SPACING_12": EditorLayout.SPACING_12, "SPACING_16": EditorLayout.SPACING_16,
		"SPACING_24": EditorLayout.SPACING_24, "TRAY_CHIP_GAP": EditorLayout.TRAY_CHIP_GAP,
	}
	for name: String in values:
		ctx.check(SPACING_SCALE.has(values[name]), "%s = %s 是间距系统里的档位" % [name, values[name]])
	# 停靠节拍 = 一个卡位 + 一个间距 —— 卡位与间距都得是档位，节拍才不是拼出来的怪数。
	ctx.near(EditorLayout.tray_pitch(),
		EditorLayout.TRAY_CHIP_SIZE + EditorLayout.TRAY_CHIP_GAP, "滚动节拍 = 卡位 + 间距")


## 「同一张牌在仓库和画布上一样大」—— 三处卡牌尺寸必须是同一个数。
func _check_card_size(ctx: RefCounted) -> void:
	ctx.equal(CardFace.SIZE, BoardModel.CARD_SIZE, "画布卡片尺寸 = 模型尺寸")
	ctx.equal(EditorLayout.TRAY_CHIP_SIZE, BoardModel.CARD_SIZE.x, "仓库卡位尺寸 = 画布卡片尺寸")
	var canvas: Rect2 = EditorLayout.canvas_view()
	ctx.check(canvas.size.x >= BoardModel.CARD_SIZE.x * 2.0 and canvas.size.y >= BoardModel.CARD_SIZE.y * 2.0,
		"净纸至少放得下两张卡（%s）" % canvas.size)


## 触控目标下限 44 设备像素 = 22 逻辑像素；§2.1 另外给了可交互矩形的 24 下限。
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
	for pair: Array in _interactive():
		var rect: Rect2 = pair[1]
		ctx.check(rect.size.x >= MIN_INTERACTIVE and rect.size.y >= MIN_INTERACTIVE,
			"%s %s 不小于 §1 的最小互动矩形 %s" % [pair[0], rect.size, MIN_INTERACTIVE])
	ctx.check(UiKit.button_height() >= minimum, "按钮高度 %s ≥ %s" % [UiKit.button_height(), minimum])


## 头栏在两种语言下都要排得下：标题、计数、三个图标控件互不重叠且都在条内。
## 英文文案比中文长，是最坏情况 —— 只测中文等于没测。
func _check_top_bar_both_locales(ctx: RefCounted, tree: SceneTree) -> void:
	var settings: Node = tree.root.get_node_or_null(^"Settings")
	if not ctx.check(settings != null, "Settings 单例存在，可做双语断言"):
		return
	var original: String = settings.get_locale()
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
	var title: Rect2 = EditorLayout.TITLE_RECT
	var counts: Rect2 = EditorLayout.COUNTS_RECT
	var buttons: Array[Rect2] = EditorLayout.top_button_rects()

	ctx.check(bar.encloses(title) and bar.encloses(counts), "[%s] 标题与计数都在头栏内" % locale)
	ctx.check(not _overlaps(title, counts), "[%s] 标题与计数不重叠" % locale)
	# 文字必须真的放得下：它们是 Label，字太长不会被裁而是画出去。
	var title_text: String = TranslationServer.translate("模块编辑器")
	var counts_text: String = TranslationServer.translate("卡片 %d · 丝线 %d") % [12, 8]
	ctx.check(UiKit.text_units(title_text) * float(ContractTheme.FONT_TITLE) <= title.size.x,
		"[%s] 标题文案「%s」放得下" % [locale, title_text])
	ctx.check(UiKit.text_units(counts_text) * float(ContractTheme.FONT_BODY) <= counts.size.x,
		"[%s] 计数文案「%s」放得下" % [locale, counts_text])
	# 空书页时这一行改说引导语，它也得放得下 —— 换一句话就撑破是迟早的事。
	var hint_text: String = TranslationServer.translate("点下方仓库的卡片放到书页上")
	ctx.check(UiKit.text_units(hint_text) * float(ContractTheme.FONT_BODY) <= counts.size.x,
		"[%s] 空态引导「%s」放得下" % [locale, hint_text])

	ctx.equal(buttons.size(), EditorLayout.TOP_BUTTONS.size(), "[%s] 图标控件数一致" % locale)
	for index: int in buttons.size():
		var button: Rect2 = buttons[index]
		var key: String = EditorLayout.TOP_BUTTONS[index]
		ctx.check(bar.encloses(button), "[%s] 按钮「%s」在头栏内" % [locale, key])
		ctx.check(button.position.x >= counts.end.x,
			"[%s] 按钮「%s」不压到计数行上（%s ≥ %s）" % [locale, key, button.position.x, counts.end.x])
		ctx.equal(button.size, EditorLayout.HEADER_BUTTON_SIZE, "[%s] 按钮「%s」尺寸固定" % [locale, key])
		if index > 0:
			ctx.near(buttons[index - 1].position.x - button.end.x, EditorLayout.SPACING_8,
				"[%s] 按钮「%s」与右邻间距 8" % [locale, key])
	ctx.near(buttons[0].end.x, EditorLayout.HEADER_BUTTONS_RIGHT, "[%s] 最右按钮贴住头栏右缘" % locale)
	# 按钮纵向居中：三颗的中心与头栏中心同高。
	var centre: float = bar.position.y + bar.size.y * 0.5
	for button: Rect2 in buttons:
		ctx.near(button.position.y + button.size.y * 0.5, centre, "[%s] 按钮纵向居中" % locale)


## 反向对照：重叠判定本身必须抓得到重叠。一个永远返回 false 的判定会让上面全绿。
func _check_overlap_detector(ctx: RefCounted) -> void:
	ctx.check(_overlaps(Rect2(0.0, 0.0, 10.0, 10.0), Rect2(5.0, 5.0, 10.0, 10.0)), "反向对照：明显重叠被判为重叠")
	ctx.check(not _overlaps(Rect2(0.0, 0.0, 10.0, 10.0), Rect2(10.0, 0.0, 10.0, 10.0)),
		"反向对照：仅相邻（不交叠）不算重叠")


# ---------------------------------------------------------------- 工具

## 参与重叠 / 越界检查的**分区**。浮层与书脊不在里面：它们按设计压在别的分区上。
func _regions() -> Array:
	return [
		["头栏", EditorLayout.top_bar()],
		["书本", EditorLayout.book()],
		["书槽", EditorLayout.tray()],
	]


## 可交互包络：G03 与 §1 的 24×24 都对这一组生效。
func _interactive() -> Array:
	return [
		["头栏图标控件", EditorLayout.top_button_rects()[0]],
		["书槽左入口", EditorLayout.tray_arrow_rect(-1.0)],
		["书槽右入口", EditorLayout.tray_arrow_rect(1.0)],
		["书槽主按钮", EditorLayout.primary_rect()],
		["详情收起键", EditorLayout.detail_close_rect()],
	]


## 严格重叠判定。Rect2.intersects() 默认把「仅相邻」也算相交，这里不要那种口径。
static func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x \
		and a.position.y < b.end.y and b.position.y < a.end.y
