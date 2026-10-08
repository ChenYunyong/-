## test_layout_p0.gd
## 职责：首屏版面缺陷的回归用例 —— 每条都先复现「坏的样子」，再钉住修好之后的数。
## 所属系统：tests
## 依赖：EditorLayout, ArcaneTheme, ContractTheme, UiKit, CardCatalog
## 禁止：本文件不得写入布局常量，只断言 —— 数字的唯一来源是 EditorLayout / docs/14。
##
## 从 test_layout 里分出来，是因为那支文件顶到了 test_source_rules 的 300 行上限。
## 分界线是**性质**而不是篇幅：test_layout 管的是「分区该在哪」（改版式才会动的大骨架），
## 这里管的是「具体哪里曾经坏掉 / 契约把哪一块量到了像素」。
##
## 四个靶子：① 仓库最右那张卡只露一半 → 停靠点必须含终点；② 两端滚动入口盖住卡 →
## §2.1 把它们挪到滚动区之外，遮挡从此不可能；③ 详情与顶栏读不出主次 → 字号阶梯与按钮主次都要能量；
## ④ 详情一开就看不见牌 → 浮层必须落在净纸里。
## （同批的「角上卡片的接口被裁切边切掉」挪去了 test_editor_state —— 那是 BoardView 的行为，
## 不是版面。）

extends RefCounted

## 触控下限 44 **设备像素**，窗口 / 画布 = 2 → 22 逻辑像素（docs/06 §1）。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## docs/14 §1 的最小互动矩形。
const MIN_INTERACTIVE: float = 24.0
## docs/06 v0.1.17 给 arcane/ 的临时字号下限：正文 ≥ 12px。
const MIN_BODY_FONT_PX: int = 12
## 两个 Token 之间「已经读不出区别」的 RGB 欧氏距离（0-255）。
## 取自 04 里水 / 雷 / 风 / 冰四色的最近距离 35.8 —— 那是被判为塌成一家的那一对。
const COLLAPSE_DISTANCE: float = 96.0
## 详情四段的**最坏行数** × §1 的行高（名字 24/32、正文 16/24、说明 12/20）。
## 32 + 8 + 24 + 8 + 72 + 8 + 60 = 212，加上名字行上方 12 与末行下方 16，正好填满 240 高的浮层。
const DETAIL_LINES: Array[int] = [1, 1, 3, 3]
const DETAIL_LINE_HEIGHT: Array[int] = [32, 24, 24, 20]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_layout_p0")
	_check_tray_scrolls(ctx)
	_check_tray_stops(ctx)
	_check_tray_geometry(ctx)
	_check_detail_popover(ctx)
	_check_detail_rows(ctx)
	_check_button_hierarchy(ctx)


## 仓库里的卡一定放不下，横向滚动必须是真的需要（否则那段代码是摆设）。
func _check_tray_scrolls(ctx: RefCounted) -> void:
	var count: int = CardCatalog.all().size()
	var content: float = EditorLayout.tray_content_width(count)
	var window: float = EditorLayout.tray_view().size.x
	ctx.check(content > window, "仓库内容 %s 宽 > 可视区 %s（所以确实要滚）" % [content, window])
	# 一步 = **一整张卡**（卡位 + 间距），而不是「间距的整数倍」—— 后者滚两下就停在第 1.14 张卡上。
	ctx.near(EditorLayout.TRAY_SCROLL_STEP, EditorLayout.tray_pitch(),
		"滚动步长 = 一个卡位节拍（一步正好一张整卡）")
	ctx.check(EditorLayout.TRAY_CHIP_SIZE <= EditorLayout.tray_view().size.y, "卡位高度不超出仓库可视区")
	ctx.check(content - window > EditorLayout.TRAY_SCROLL_STEP, "滚动余量大于一步（不是空滚）")
	# §2.1 表列值：18 卡的内容 1500 − 视区 672 = 828。它是**终点停靠点**，见下一条。
	ctx.near(EditorLayout.tray_max_offset(count), 828.0, "18 卡的终点偏移 = 表列值 828")


## 停靠点：第一张与最后一张卡都必须**整张**落在可视区里（§2.1 的验收原话）。
##
## 靶子是「什么情况下最右边那张会被切掉」—— 若停靠点只取节拍整数倍，终点永远差最后几像素。
## 所以既断言终点不是节拍整数倍，也断言它真的被列进了停靠点。
func _check_tray_stops(ctx: RefCounted) -> void:
	var count: int = CardCatalog.all().size()
	var view: Rect2 = EditorLayout.tray_view()
	var limit: float = EditorLayout.tray_max_offset(count)
	var pitch: float = EditorLayout.tray_pitch()
	var stops: PackedFloat32Array = EditorLayout.tray_stops(count)

	ctx.check(stops.size() >= 2, "至少两个停靠点（否则滚不动）")
	ctx.near(stops[0], 0.0, "第一个停靠点是 0")
	ctx.near(stops[stops.size() - 1], limit, "最后一个停靠点是终点")
	ctx.check(absf(limit - roundf(limit / pitch) * pitch) > 0.5,
		"终点 %s 不是节拍 %s 的整数倍 —— 正是这一点让最后一张卡整张可见" % [limit, pitch])

	ctx.check(EditorLayout.TRAY_CHIP_SIZE <= view.size.x,
		"停在 0 时第一张卡整张可读（%s ≤ %s）" % [EditorLayout.TRAY_CHIP_SIZE, view.size.x])
	var last_right: float = float(count - 1) * pitch + EditorLayout.TRAY_CHIP_SIZE
	ctx.check(float(count - 1) * pitch >= limit, "停在终点时最后一张卡的左缘已进入可视区")
	ctx.near(last_right - limit, view.size.x, "停在终点时最后一张卡右缘恰好贴住可视区右缘")
	ctx.near(last_right, EditorLayout.tray_content_width(count), "最后一张卡的右缘 = 内容总宽")

	# 从 0 一路向右按停靠点走，必须恰好停在终点，中途不越界、不卡住。
	var offset: float = 0.0
	var steps: int = 0
	while steps < count * 2:
		steps += 1
		var next: float = EditorLayout.tray_stop_offset(offset, 1.0, count)
		ctx.check(next >= offset - 0.01 and next <= limit + 0.01,
			"第 %d 步停靠点 %s 落在 [0, 终点] 内" % [steps, next])
		if is_equal_approx(next, offset):
			break
		offset = next
	ctx.near(offset, limit, "一路向右停靠会停在终点（不会卡在中途，也不会走过头）")
	ctx.check(steps < count * 2, "走完全程只用 %d 步（没有死循环）" % steps)


## 书槽的横向排布：入口 · 视区 · 入口 · 主按钮，四件纵向同线。
##
## 靶子有两个。一是**入口盖住卡**：§2.1 把入口挪到滚动区**之外**，于是遮挡不再需要靠自隐回避，
## 自隐现在只管「按钮别假装能滚」。二是**槽里的东西忽高忽低**：四件的中心必须在同一条线上。
func _check_tray_geometry(ctx: RefCounted) -> void:
	var tray: Rect2 = EditorLayout.tray()
	var view: Rect2 = EditorLayout.tray_view()
	var left: Rect2 = EditorLayout.tray_arrow_rect(-1.0)
	var right: Rect2 = EditorLayout.tray_arrow_rect(1.0)
	var primary: Rect2 = EditorLayout.primary_rect()
	var minimum: float = maxf(MIN_TOUCH_DEVICE_PX / DEVICE_SCALE, MIN_INTERACTIVE)

	for pair: Array in [["滚动区", view], ["左入口", left], ["右入口", right], ["主按钮", primary]]:
		ctx.check(tray.encloses(pair[1]), "%s 在书槽内 %s" % [pair[0], pair[1]])
	ctx.check(not _overlaps(view, left) and not _overlaps(view, right),
		"两个入口都在滚动区之外 —— 盖住卡位这件事在几何上不可能发生")
	ctx.check(not _overlaps(left, right) and not _overlaps(right, primary), "槽内四件两两不重叠")
	for pair: Array in [["左", left], ["右", right]]:
		var rect: Rect2 = pair[1]
		ctx.check(rect.size.x >= minimum and rect.size.y >= minimum,
			"%s入口 %s ≥ %s 逻辑像素（= %d 设备像素）"
				% [pair[0], rect.size, minimum, int(minimum * DEVICE_SCALE)])

	ctx.near(left.position.x - tray.position.x, EditorLayout.SPACING_8, "左入口贴住书槽左内缩")
	ctx.near(right.position.x - view.end.x, EditorLayout.SPACING_12, "右入口距滚动区 12")
	ctx.near(primary.position.x - right.end.x, EditorLayout.SPACING_16, "主按钮距右入口 16")
	ctx.near(tray.end.x - primary.end.x, EditorLayout.SPACING_16, "主按钮贴住书槽右内缩")
	ctx.near(view.size.y, EditorLayout.TRAY_CHIP_SIZE, "滚动区高度 = 一个卡位")
	var centre: float = tray.position.y + tray.size.y * 0.5
	for pair: Array in [["滚动区", view], ["左入口", left], ["右入口", right], ["主按钮", primary]]:
		ctx.near(pair[1].position.y + pair[1].size.y * 0.5, centre, "%s 纵向居中" % pair[0])
	# 视区里至少放得下 8 张卡，否则「末卡完整 72」那条 E05 没地方站。
	ctx.check(view.size.x >= EditorLayout.TRAY_CHIP_SIZE * 8.0, "视区至少放得下 8 张卡（%s）" % view.size.x)

	# 自隐规则之所以安全，是因为**在两端按它不会动**，于是那两颗此刻必然是隐藏的。
	var count: int = CardCatalog.all().size()
	var limit: float = EditorLayout.tray_max_offset(count)
	ctx.near(EditorLayout.tray_stop_offset(0.0, -1.0, count), 0.0, "停在第一格时再往左按，原地不动")
	ctx.near(EditorLayout.tray_stop_offset(limit, 1.0, count), limit, "停在终点时再往右按，原地不动")


## 详情浮层的外框：整个落在净纸里，名字行与收起键各就各位。
##
## 靶子是「详情一开，牌就看不见了」—— 旧版详情是常驻右栏，占了画布右侧一整条。
## 现在它是浮层，扣掉之后纸面还剩 48.544%（E02 量的就是这一块，见 test_layout）。
func _check_detail_popover(ctx: RefCounted) -> void:
	var paper: Rect2 = EditorLayout.paper()
	var popover: Rect2 = EditorLayout.popover()
	ctx.check(paper.encloses(popover), "浮层整个落在净纸内 %s" % popover)

	var name_rect: Rect2 = EditorLayout.detail_name_rect()
	var close_rect: Rect2 = EditorLayout.detail_close_rect()
	ctx.check(popover.encloses(name_rect) and popover.encloses(close_rect), "名字与收起键都在浮层内")
	ctx.check(not _overlaps(name_rect, close_rect), "名字与收起键不重叠")
	ctx.near(close_rect.position.x - name_rect.end.x, EditorLayout.SPACING_4, "收起键与名字间距 4")
	# 收起键与名字**同顶**（§2.1 两行都给 y=92）。名字行 32 高、键 24 高，故键的下方留 8 ——
	# 这里钉的是「同顶」而不是「居中」：居中会让键比名字低 4，和表列值差一行。
	ctx.near(close_rect.position.y, name_rect.position.y, "收起键与名字同顶")
	ctx.check(close_rect.end.y <= name_rect.end.y, "收起键不越过名字行下缘")
	# 名字行左内缩 12、上内缩 12；内容列右内缩 16。
	ctx.near(name_rect.position.x - popover.position.x, EditorLayout.SPACING_12, "名字行左内缩 12")
	ctx.near(name_rect.position.y - popover.position.y, EditorLayout.SPACING_12, "名字行上内缩 12")
	ctx.check(popover.encloses(name_rect), "名字行在浮层内 %s" % name_rect)
	# 名字行**故意比内容列窄**：它得给收起键让位，所以右缘停在键的前一站，不参与「内容列同宽」。
	ctx.near(name_rect.position.x, EditorLayout.DETAIL_CONTENT_X, "名字行与内容列同左缘")
	ctx.check(name_rect.size.x < EditorLayout.DETAIL_CONTENT_WIDTH,
		"名字行 %s 比内容列 %s 窄 —— 让出收起键那一段" % [name_rect.size.x, EditorLayout.DETAIL_CONTENT_WIDTH])

	# 类型 / 参数 / 说明三段才是「同宽同左缘」的那一组（§2.1 都给 716 / 196）。
	for row: Rect2 in _content_rows():
		ctx.check(popover.encloses(row), "内容行在浮层内 %s" % row)
		ctx.near(row.position.x, EditorLayout.DETAIL_CONTENT_X, "内容行左缘对齐")
		ctx.near(row.size.x, EditorLayout.DETAIL_CONTENT_WIDTH, "内容行同宽")
	ctx.near(popover.end.x - EditorLayout.detail_note_rect().end.x, EditorLayout.SPACING_16,
		"内容列右内缩 16")


## 详情的四段文字（§2.1 的四行 rect + §1 的字号阶梯）。
##
## 靶子是「名字 / 类型 / 参数 字号与亮度太接近」，两个维度都得能测：
## 字号是 24 / 16 / 16 / 12 三档（名字·正文·说明），亮度靠**名字独占金色**拉开 ——
## 金对灰实测 113、金对蓝 140（0-255 的 RGB 欧氏距离；对照：被判为「塌成一家」的水雷风冰只有 35.8）。
func _check_detail_rows(ctx: RefCounted) -> void:
	var theme: Theme = ArcaneTheme.new()
	var rows: Array[Rect2] = _detail_rows()
	var variations: Array[StringName] = [ContractTheme.TYPE_LABEL_DETAIL_NAME,
		ContractTheme.TYPE_LABEL_BODY_MUTED, ContractTheme.TYPE_LABEL_BODY,
		ContractTheme.TYPE_LABEL_CAPTION_DANGER]
	var fonts: Array[int] = []
	var inks: Array[Color] = []
	for variation: StringName in variations:
		fonts.append(theme.get_font_size(&"font_size", variation))
		inks.append(theme.get_color(&"font_color", variation))

	# 每一段的行数 × §1 的行高必须装得下，且段间距一致 —— 这是「排过版」与「堆在一起」的分界。
	var previous: Rect2 = rows[0]
	for index: int in rows.size():
		var row: Rect2 = rows[index]
		var need: float = float(DETAIL_LINES[index] * DETAIL_LINE_HEIGHT[index])
		ctx.check(row.size.y + 0.01 >= need,
			"第 %d 段高 %s 放得下 %d 行（需 %s）" % [index + 1, row.size.y, DETAIL_LINES[index], need])
		if index > 0:
			ctx.near(row.position.y - previous.end.y, EditorLayout.SPACING_8, "第 %d 段与上一段间距 8" % (index + 1))
		previous = row
	ctx.near(rows[rows.size() - 1].end.y,
		EditorLayout.popover().end.y - EditorLayout.SPACING_16, "最后一段到浮层底留出 16")

	# 字号阶梯：三档，名字走标题档、说明走小字档，相邻两档差得出来。
	ctx.check(fonts[0] != fonts[1] and fonts[1] == fonts[2] and fonts[2] != fonts[3],
		"三档字号：名字 %d / 正文 %d / 说明 %d" % [fonts[0], fonts[1], fonts[3]])
	ctx.check(fonts[0] == ContractTheme.FONT_TITLE and fonts[3] == ContractTheme.FONT_CAPTION,
		"名字走标题档 %d、说明走小字档 %d" % [fonts[0], fonts[3]])
	ctx.check(fonts[0] - fonts[1] >= 4, "名字与类型至少差 4px（%d → %d）" % [fonts[0], fonts[1]])
	ctx.check(fonts[1] >= MIN_BODY_FONT_PX, "正文 %d ≥ docs/06 的临时下限 %d" % [fonts[1], MIN_BODY_FONT_PX])

	# 亮度分级：名字独占金色，并且和另外两级拉得比「塌成一家」的那对远得多。
	ctx.check(_rgb_distance(inks[0], inks[1]) >= COLLAPSE_DISTANCE,
		"名字的金与类型的灰相距 %.1f ≥ %.1f" % [_rgb_distance(inks[0], inks[1]), COLLAPSE_DISTANCE])
	ctx.check(_rgb_distance(inks[0], inks[2]) >= COLLAPSE_DISTANCE,
		"名字的金与正文的蓝相距 %.1f ≥ %.1f" % [_rgb_distance(inks[0], inks[2]), COLLAPSE_DISTANCE])
	ctx.check(not inks[3].is_equal_approx(inks[2]), "说明行用的是另一支颜色，不混在正文里")


## 按钮主次（§2.1）：头栏三颗 40×32 图标控件全等，全屏唯一带文字的主按钮在书槽右端。
##
## 靶子是「四个同级大按钮读不出主次」—— 修法是让主动作**只有一个**，且它一个人带文字。
func _check_button_hierarchy(ctx: RefCounted) -> void:
	var rects: Array[Rect2] = EditorLayout.top_button_rects()
	var icon_size: Vector2 = EditorLayout.HEADER_BUTTON_SIZE
	for index: int in rects.size():
		ctx.equal(rects[index].size, icon_size,
			"头栏「%s」= %s 的图标控件" % [EditorLayout.TOP_BUTTONS[index], icon_size])
	ctx.check(not EditorLayout.TOP_BUTTONS.has(EditorLayout.PRIMARY_KEY),
		"主动作「%s」不在头栏的图标控件里" % EditorLayout.PRIMARY_KEY)

	var primary: Rect2 = EditorLayout.primary_rect()
	var theme: Theme = ArcaneTheme.new()
	ctx.check(primary.size.x > icon_size.x,
		"主按钮 %s 比图标控件 %s 宽 —— 才是主次关系" % [primary.size, icon_size])
	# 主按钮的文案要放得下：它是全屏唯一带字的按钮，撑破了没有第二处会报错。
	var text: String = TranslationServer.translate(EditorLayout.PRIMARY_KEY)
	ctx.check(UiKit.text_units(text) * float(ContractTheme.FONT_BUTTON) <= primary.size.x,
		"主按钮文案「%s」放得下 %s" % [text, primary.size.x])
	ctx.equal(theme.get_font_size(&"font_size", ContractTheme.TYPE_BUTTON_PAGE_PRIMARY),
		ContractTheme.FONT_BUTTON, "主按钮字号 = 契约的按钮档 %d" % ContractTheme.FONT_BUTTON)
	# 预算：计数行右缘之后仍留得下一个间距再放按钮组。加第四颗键时这一条当场变红，
	# 而不是等到切到英文才发现按钮压住了计数文字。
	ctx.check(EditorLayout.COUNTS_RECT.end.x + EditorLayout.SPACING_8
			<= rects[rects.size() - 1].position.x + 0.01,
		"计数行右缘 %s 之后留得下按钮组（组左缘 %s）"
			% [EditorLayout.COUNTS_RECT.end.x, rects[rects.size() - 1].position.x])


# ---------------------------------------------------------------- 工具

## 浮层的四段内容行，顺序与 DETAIL_LINES / 字号阶梯一致。
func _detail_rows() -> Array[Rect2]:
	return [EditorLayout.detail_name_rect(), EditorLayout.detail_type_rect(),
		EditorLayout.detail_stats_rect(), EditorLayout.detail_note_rect()]


## 其中同宽的那三段。名字行不在里面 —— 它短一截是为了给收起键让位（§2.1）。
func _content_rows() -> Array[Rect2]:
	return [EditorLayout.detail_type_rect(), EditorLayout.detail_stats_rect(),
		EditorLayout.detail_note_rect()]


## 严格重叠判定。Rect2.intersects() 默认把「仅相邻」也算相交，这里不要那种口径。
static func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x \
		and a.position.y < b.end.y and b.position.y < a.end.y


## 两个颜色的 RGB 欧氏距离，量纲换算到 0-255（方便和 04 文档里的距离数对照）。
static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 255.0
