## test_layout_p0.gd
## 职责：PET-87 §3 四条首屏缺陷的回归用例 —— 每条都先复现「坏的样子」，再钉住修好之后的数。
## 所属系统：tests
## 依赖：EditorLayout, ArcaneTheme, CardCatalog, BoardView, BoardStatePainter, CardFace
## 禁止：本文件不得写入布局常量，只断言。
##
## 从 test_layout 里分出来，是因为那支文件已经顶到 test_source_rules 的 300 行上限。
## 分界线是**性质**而不是篇幅：test_layout 管的是「分区该在哪」（静态几何，改版式才会动），
## 这里管的是「具体哪里曾经坏掉」（缺陷回归，每条都能追到 §3 的一句话）。
##
## 四条缺陷与各自的靶子：
##   1. 仓库最右那张「加速」只露一半 → 停靠点必须含终点，第一张与最后一张都整张可读；
##   2. 两端的滚动入口会盖住卡 → 只可能盖住已被切掉的那一端，且在两端按它不会动；
##   3. 角上卡片的输出接口被裁剪边切掉 → 四周余量按「卡外最远要画到哪」反推；
##   4. 详情三级字 / 顶栏四个同级大按钮 → 字号阶梯与主次都要能量出来。

extends RefCounted

## 触控下限 44 **设备像素**，窗口 / 画布 = 2 → 22 逻辑像素（docs/06 §1）。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## docs/06 v0.1.17 给 arcane/ 的临时字号下限：正文 ≥ 12px、标题 ≥ 16px。
const MIN_BODY_FONT_PX: int = 12
const MIN_TITLE_FONT_PX: int = 16
## 系统字体的行高比（字号 × 它 = 一行实际占的高度）。详情面板的行高按它算，不拍脑袋。
const LINE_RATIO: float = 1.25
## 详情面板四段的**最坏行数**：名字 1、类型 1、参数 3（一张卡最多三个字段）、警告 2。
const DETAIL_LINES: Array[int] = [1, 1, 3, 2]
## 两个 Token 之间「已经读不出区别」的 RGB 欧氏距离（0-255）。
## 取自 04 里水 / 雷 / 风 / 冰四色的最近距离 35.8 —— 那是被判为塌成一家的那一对。
const COLLAPSE_DISTANCE: float = 96.0


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_layout_p0")
	_check_tray_scrolls(ctx)
	_check_tray_stops(ctx)
	_check_tray_arrows(ctx)
	_check_canvas_reserve(ctx)
	_check_detail_rows(ctx)
	_check_top_bar_hierarchy(ctx)


## 仓库里的卡一定放不下，横向滚动必须是真的需要（否则那段代码是摆设）。
func _check_tray_scrolls(ctx: RefCounted) -> void:
	var count: int = CardCatalog.all().size()
	var content: float = EditorLayout.tray_content_width(count)
	var window: float = EditorLayout.TRAY_VIEW_SIZE.x
	ctx.check(content > window, "仓库内容 %s 宽 > 可视区 %s（所以确实要滚）" % [content, window])
	# §3 的修法：一步 = **一整张卡**（卡位 + 间距），而不是「间距的整数倍」。
	# 原来一步 96、节拍 84，滚两下就停在第 1.14 张卡上。
	ctx.near(EditorLayout.TRAY_SCROLL_STEP, EditorLayout.tray_pitch(),
		"滚动步长 = 一个卡位节拍（一步正好一张整卡）")
	ctx.near(fmod(EditorLayout.TRAY_SCROLL_STEP, EditorLayout.TRAY_CHIP_GAP), 0.0,
		"滚动步长同时也是卡位间距的整数倍")
	ctx.check(EditorLayout.TRAY_CHIP_SIZE <= EditorLayout.TRAY_VIEW_SIZE.y, "卡位高度不超出仓库可视区")
	ctx.check(content - window > EditorLayout.TRAY_SCROLL_STEP, "滚动余量大于一步（不是空滚）")


## 停靠点：第一张与最后一张卡都必须**整张**落在可视区里（§3 的验收原话）。
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

	# 停在 0：第一张卡整张在可视区里。
	ctx.check(EditorLayout.TRAY_CHIP_SIZE <= view.size.x,
		"停在 0 时第一张卡整张可读（%s ≤ %s）" % [EditorLayout.TRAY_CHIP_SIZE, view.size.x])
	# 停在终点：最后一张卡的左缘还在可视区内，右缘恰好贴住视宽 ——「恰好」而不是「超出」。
	var last_left: float = float(count - 1) * pitch
	var last_right: float = last_left + EditorLayout.TRAY_CHIP_SIZE
	ctx.check(last_left >= limit, "停在终点时最后一张卡的左缘已进入可视区（不是只露一条边）")
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


## 仓库两端的滚动入口。它们压在卡位之上，必须保证**只在卡已被切掉的那一端**出现。
func _check_tray_arrows(ctx: RefCounted) -> void:
	var view: Rect2 = EditorLayout.tray_view()
	var left: Rect2 = EditorLayout.tray_arrow_rect(-1.0)
	var right: Rect2 = EditorLayout.tray_arrow_rect(1.0)
	var minimum: float = MIN_TOUCH_DEVICE_PX / DEVICE_SCALE

	ctx.check(view.encloses(left) and view.encloses(right), "两个滚动入口都落在仓库可视区内")
	ctx.near(left.position.x, view.position.x, "左入口贴可视区左缘")
	ctx.near(right.end.x, view.end.x, "右入口贴可视区右缘")
	ctx.check(not left.intersects(right), "左右两个入口不重叠")
	ctx.near(left.position.y + left.size.y * 0.5, view.position.y + view.size.y * 0.5, "入口纵向居中")
	for pair: Array in [["左", left], ["右", right]]:
		var rect: Rect2 = pair[1]
		ctx.check(rect.size.x >= minimum and rect.size.y >= minimum,
			"%s入口 %s ≥ %s 逻辑像素（= %d 设备像素）"
				% [pair[0], rect.size, minimum, int(minimum * DEVICE_SCALE)])

	# 自隐规则之所以安全，是因为**在两端按它不会动**：停在第一格时按左、停在终点时按右，
	# 位置原地不动，于是那两颗按钮此刻必然隐藏，也就永远不会盖住完整的第一张 / 最后一张。
	var count: int = CardCatalog.all().size()
	var limit: float = EditorLayout.tray_max_offset(count)
	ctx.near(EditorLayout.tray_stop_offset(0.0, -1.0, count), 0.0, "停在第一格时再往左按，原地不动")
	ctx.near(EditorLayout.tray_stop_offset(limit, 1.0, count), limit, "停在终点时再往右按，原地不动")


## 画布四周必须留出「接口圆点 + 状态边」画得下的余量（§3）。
##
## 报的缺陷是自由摆放的卡停在角上时，输出接口（画在卡片右缘外 6px）被 clip_contents 切掉半个圆。
## 这里不看截图、也不复述常量，而是把余量拿去和「最远要画到哪」逐个比，再用恒等式钉住它。
func _check_canvas_reserve(ctx: RefCounted) -> void:
	var reach: float = maxf(BoardView.PORT_RADIUS,
		BoardStatePainter.SELECT_GROW + BoardStatePainter.SELECT_WIDTH * 0.5)
	ctx.check(BoardView.EDGE_PADDING >= reach,
		"四周余量 %s ≥ 卡外最远要画到的 %s（接口半径与选中轮廓取大）"
			% [BoardView.EDGE_PADDING, reach])

	var view: BoardView = BoardView.new()
	view.size = EditorLayout.CANVAS_VIEW_SIZE
	var origin: Vector2 = view.play_origin()
	var limit: Vector2 = view.play_limit()
	ctx.check(limit.x >= 0.0 and limit.y >= 0.0, "可移动范围非负 %s" % limit)
	# 恒等式：最远落点 + 卡宽 + 余量 = 画布宽。余量是**留出来**的，不是碰巧够。
	ctx.near(origin.x + limit.x + CardFace.SIZE.x + BoardView.EDGE_PADDING, view.size.x,
		"横向：最右落点 + 卡宽 + 余量 = 画布宽")
	ctx.near(origin.y + limit.y + CardFace.SIZE.y + BoardView.EDGE_PADDING, view.size.y,
		"纵向：最下落点 + 卡高 + 余量 = 画布高")
	ctx.near(origin.x, BoardView.EDGE_PADDING, "左余量 = EDGE_PADDING")

	# 右上角：卡贴在极限位置上时，输出接口整个圆仍然落在画布内。
	var port: Vector2 = origin + limit + Vector2(CardFace.SIZE.x, CardFace.SIZE.y * 0.5)
	ctx.check(port.x + BoardView.PORT_RADIUS <= view.size.x,
		"右上角落点的输出接口右缘 %s ≤ 画布宽 %s" % [port.x + BoardView.PORT_RADIUS, view.size.x])
	ctx.check(port.y - BoardView.PORT_RADIUS >= 0.0 and port.y + BoardView.PORT_RADIUS <= view.size.y,
		"输出接口纵向也在画布内")
	ctx.check(origin.x - BoardView.PORT_RADIUS >= 0.0, "左上角落点的输入接口整个画得下")

	# 夹取真的生效：给出格外的坐标，落点必须回到合法范围内。
	var low: Vector2 = view.clamp_to_play(Vector2(-999.0, -999.0))
	var high: Vector2 = view.clamp_to_play(Vector2(99999.0, 99999.0))
	ctx.near(low.x, origin.x, "越界坐标被夹回左边界")
	ctx.near(low.y, origin.y, "越界坐标被夹回上边界")
	ctx.near(high.x, origin.x + limit.x, "越界坐标被夹回右边界")
	ctx.near(high.y, origin.y + limit.y, "越界坐标被夹回下边界")
	view.free()


## 详情面板的三级文字阶梯与四段行高（§3）。
##
## 报的缺陷是「名字 / 类型 / 费用与伤害 字号与亮度太接近」，两个维度都得能测：
## 字号是 30 / 24 / 20 的三级阶梯；亮度靠**名字独占金色**拉开 —— 金对灰实测 113、金对蓝 140
## （0-255 的 RGB 欧氏距离；对照：色板里被判为「塌成一家」的水雷风冰只有 35.8）。
## 类型与参数之间只靠字号分：两者色差只有 40.8，再插一级亮度会破坏内芯既有的三层结构，
## 而 24 与 20 这四像素差在 216 宽的面板里已经读得出来。
func _check_detail_rows(ctx: RefCounted) -> void:
	var theme: Theme = ArcaneTheme.new()
	var rows: Array[Rect2] = [EditorLayout.detail_name_rect(), EditorLayout.detail_type_rect(),
		EditorLayout.detail_stats_rect(), EditorLayout.detail_warn_rect()]
	var fonts: Array[int] = [
		theme.get_font_size(&"font_size", ArcaneTheme.TYPE_LABEL_TITLE),
		theme.get_font_size(&"font_size", ArcaneTheme.TYPE_LABEL_SECONDARY),
		theme.get_font_size(&"font_size", ArcaneTheme.TYPE_LABEL_PARAM),
		theme.get_font_size(&"font_size", ArcaneTheme.TYPE_LABEL_WARN),
	]
	var total: float = 0.0
	var cursor: float = EditorLayout.DETAIL_CONTENT_ORIGIN.y
	for index: int in rows.size():
		var row: Rect2 = rows[index]
		var need: float = float(fonts[index]) * LINE_RATIO * float(DETAIL_LINES[index])
		ctx.near(row.position.y, cursor, "第 %d 段接上一段的下沿" % (index + 1))
		ctx.near(row.position.x, EditorLayout.DETAIL_CONTENT_ORIGIN.x, "第 %d 段左对齐内容区" % (index + 1))
		ctx.near(row.size.x, EditorLayout.DETAIL_CONTENT_WIDTH, "第 %d 段横贯内容区" % (index + 1))
		ctx.check(row.size.y >= need,
			"第 %d 段高 %s 放得下 %d 行 %dpx 字（需 %s）"
				% [index + 1, row.size.y, DETAIL_LINES[index], fonts[index], need])
		total += row.size.y
		cursor = row.end.y
	ctx.check(total <= EditorLayout.DETAIL_CONTENT_HEIGHT,
		"四段总高 %s ≤ 内容区 %s（以后加一段也不会溢出面板）"
			% [total, EditorLayout.DETAIL_CONTENT_HEIGHT])

	# 三级字号阶梯：严格递减、每级至少差 4px，否则「拆成三级」只是一句话。
	ctx.check(fonts[0] > fonts[1] and fonts[1] > fonts[2],
		"名字 %d > 类型 %d > 参数 %d（三级严格递减）" % [fonts[0], fonts[1], fonts[2]])
	ctx.check(fonts[0] - fonts[1] >= 4 and fonts[1] - fonts[2] >= 4,
		"相邻两级至少差 4px（%d → %d → %d）" % [fonts[0], fonts[1], fonts[2]])
	ctx.check(fonts[2] >= MIN_BODY_FONT_PX and fonts[0] >= MIN_TITLE_FONT_PX,
		"字号仍高于 docs/06 的临时下限（正文 %d / 标题 %d）" % [MIN_BODY_FONT_PX, MIN_TITLE_FONT_PX])

	# 亮度分级：名字独占金色，并且和另外两级拉得比「塌成一家」的那对远得多。
	var name_ink: Color = theme.get_color(&"font_color", ArcaneTheme.TYPE_LABEL_TITLE)
	var type_ink: Color = theme.get_color(&"font_color", ArcaneTheme.TYPE_LABEL_SECONDARY)
	var param_ink: Color = theme.get_color(&"font_color", ArcaneTheme.TYPE_LABEL_PARAM)
	var warn_ink: Color = theme.get_color(&"font_color", ArcaneTheme.TYPE_LABEL_WARN)
	ctx.check(_rgb_distance(name_ink, type_ink) >= COLLAPSE_DISTANCE,
		"名字的金与类型的灰相距 %.1f ≥ %.1f" % [_rgb_distance(name_ink, type_ink), COLLAPSE_DISTANCE])
	ctx.check(_rgb_distance(name_ink, param_ink) >= COLLAPSE_DISTANCE,
		"名字的金与参数的蓝相距 %.1f ≥ %.1f" % [_rgb_distance(name_ink, param_ink), COLLAPSE_DISTANCE])
	ctx.check(not warn_ink.is_equal_approx(param_ink), "警告行用的是另一支颜色，不混在参数里")


## 顶栏的主次（§3）：原来四个同级大按钮读不出主次 —— 现在只有「开始战斗」带文字。
func _check_top_bar_hierarchy(ctx: RefCounted) -> void:
	var primary: Vector2 = EditorLayout.top_button_size(EditorLayout.TOP_PRIMARY_KEY)
	var icon: Vector2 = Vector2(EditorLayout.TOP_ICON_BUTTON, EditorLayout.TOP_ICON_BUTTON)
	ctx.equal(EditorLayout.TOP_BUTTONS[0], EditorLayout.TOP_PRIMARY_KEY, "最右那颗就是主动作")
	ctx.check(primary.x > icon.x, "主动作 %s 比图标控件 %s 宽 —— 顶栏上只有它一个强按钮" % [primary, icon])
	ctx.near(primary.y, icon.y, "主动作与图标控件等高（顶栏不会忽高忽低）")

	var icons: int = 0
	for key: String in EditorLayout.TOP_BUTTONS:
		if key == EditorLayout.TOP_PRIMARY_KEY:
			continue
		icons += 1
		ctx.equal(EditorLayout.top_button_size(key), icon, "「%s」退成 %s 的方形图标控件" % [key, icon])
	ctx.equal(icons, EditorLayout.TOP_BUTTONS.size() - 1, "其余 %d 个键全部是图标控件" % icons)
	ctx.check(icon.x >= MIN_TOUCH_DEVICE_PX / DEVICE_SCALE,
		"图标控件 %s 仍不小于触控下限 %s" % [icon.x, MIN_TOUCH_DEVICE_PX / DEVICE_SCALE])
	# 预算：状态右缘 + 一个间距 ≤ 按钮组左缘。加第五个键时这一条当场变红，
	# 而不是等到切到英文才发现按钮压住了状态文字。
	var rects: Array[Rect2] = EditorLayout.top_button_rects()
	ctx.check(EditorLayout.TOP_STATUS_RECT.end.x + EditorLayout.GAP
			<= rects[rects.size() - 1].position.x + 0.01,
		"状态右缘 %s 之后仍留得下一个间距再放按钮组（组左缘 %s）"
			% [EditorLayout.TOP_STATUS_RECT.end.x, rects[rects.size() - 1].position.x])


## 两个颜色的 RGB 欧氏距离，量纲换算到 0-255（方便和 04 文档里的距离数对照）。
static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 255.0
