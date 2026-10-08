## test_editor_state.gd
## 职责：画布状态层级的验收（PET-87 §2）—— 选中与焦点可分、辅助线只跨相关两卡、金色不兼任。
## 所属系统：tests
## 依赖：BoardRenderer, BoardStatePainter, StrokePainter, Snap, Palette, BoardModel, EditorLayout,
##       BoardView, CardFace
## 禁止：本文件不得写入几何常量或色值，只断言。
##
## §2 报的是「金色现在承担了太多职责」。这类缺陷的麻烦之处在于它**不会报错**：
## 把 Focus 也涂成金色，界面照样跑、截图照样出，只有人盯着看才发现分不出「我在编辑哪张」
## 和「我指着哪张」。所以下面把三条口径各自变成一句可执行的断言：
##   1. 焦点与选中不同色、不同粗细、不同画法（角标 vs 轮廓）；
##   2. 辅助线的**范围**只跨相关那两张卡 —— 用 Snap 真跑一次，量出来；
##   3. 金色只出现在「选中」与「对齐提示」两处，丝线是蓝的；
##   4. 丝线画在卡后、辅助线画在卡前（顺序即层级）。
##
## PET-93 把取色统一到 docs/14 §3 的「角色 → 既有 Token」表：辅助线由金改浅蓝、丝线/辅助线/选中
## 各加一条 NAVY_600 暗底（亮纸上单画浅色等于没画）。颜色分工因此**不再靠色相**，而靠线型与范围。
## 「画布四周的余量够不够放下接口圆点」也归这一支 —— 那是 BoardView 的行为，不是版面。

extends RefCounted

const BOARD_RENDERER: String = "res://scripts/editor/board_renderer.gd"
const STATE_PAINTER: String = "res://scripts/editor/board_state_painter.gd"
const THREAD_PAINTER: String = "res://scripts/editor/thread_painter.gd"


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_editor_state")
	_check_focus_vs_selected(ctx)
	_check_palette_roles(ctx)
	_check_guide_is_short(ctx)
	_check_guide_line_style(ctx)
	_check_layer_order(ctx)
	_check_no_glow(ctx)
	_check_canvas_reserve(ctx)


## 焦点与选中：语义不同源，画法与粗细也必须分得开。
func _check_focus_vs_selected(ctx: RefCounted) -> void:
	ctx.check(BoardStatePainter.SELECT_WIDTH > BoardStatePainter.FOCUS_WIDTH,
		"选中轮廓 %s 比焦点角标 %s 粗（一个要「明确」，一个是「细」）"
			% [BoardStatePainter.SELECT_WIDTH, BoardStatePainter.FOCUS_WIDTH])
	ctx.check(BoardStatePainter.FOCUS_WIDTH <= 2.0, "焦点角标确实是细线（%s）" % BoardStatePainter.FOCUS_WIDTH)
	ctx.check(BoardStatePainter.SELECT_WIDTH >= 4.0,
		"选中轮廓确实够粗，读得出是轮廓（%s）" % BoardStatePainter.SELECT_WIDTH)
	ctx.check(BoardStatePainter.SELECT_GROW > 0.0, "选中轮廓画在卡外，不压在卡缘上")
	ctx.check(BoardStatePainter.FOCUS_ARM > 0.0 and BoardStatePainter.FOCUS_ARM < BoardModel.CARD_SIZE.x * 0.5,
		"焦点角标臂长 %s 小于半张卡，四角连不成一整圈" % BoardStatePainter.FOCUS_ARM)
	# 一个画在卡外、一个画在卡缘之内 —— 两者不抢同一块位置，因此可以同时出现而读得开。
	ctx.check(BoardStatePainter.FOCUS_INSET > 0.0
			and BoardStatePainter.FOCUS_INSET < BoardStatePainter.SELECT_GROW,
		"焦点角标内缩 %s、选中轮廓外扩 %s —— 一内一外，不叠在同一条线上"
			% [BoardStatePainter.FOCUS_INSET, BoardStatePainter.SELECT_GROW])
	# §1.1：选中 = 外扩 5 的 4px 金轮廓 + 其下 6px 暗底（暗底比芯线宽，两侧各漏 1px）。
	ctx.near(BoardStatePainter.SELECT_GROW, 5.0, "选中外扩 = §1.1 的 5")
	ctx.check(BoardStatePainter.SELECT_UNDER_WIDTH > BoardStatePainter.SELECT_WIDTH,
		"选中轮廓的暗底 %s 比金线 %s 宽，两侧漏得出边"
			% [BoardStatePainter.SELECT_UNDER_WIDTH, BoardStatePainter.SELECT_WIDTH])


## 状态层各画各的色 —— 逐个钉死 Token，而不是「看着不一样就行」。
func _check_palette_roles(ctx: RefCounted) -> void:
	var renderer: BoardRenderer = BoardRenderer.new()
	ctx.equal(renderer.selected, Palette.get_color(Palette.Key.GOLD_500), "选中 = 金色（唯一承担「选中」的色）")
	ctx.equal(renderer.focus, Palette.get_color(Palette.Key.BLUE_300), "焦点 = 浅蓝（不抢金色的语义）")
	ctx.check(not renderer.focus.is_equal_approx(renderer.selected),
		"焦点与选中是两支不同的颜色（%s / %s）" % [renderer.focus, renderer.selected])
	# §3 的角色表：辅助线 BLUE_300、丝线 BLUE_400 —— 同族两档，靠线型 / 端点 / 范围分开
	# （§1.1：丝线实线带箭头，辅助线虚线 8/4 带端点杠）。
	ctx.equal(renderer.guide, Palette.get_color(Palette.Key.BLUE_300), "辅助线 = 浅蓝（对齐提示）")
	ctx.equal(renderer.link, Palette.get_color(Palette.Key.BLUE_400), "常驻丝线 = 蓝，金色不参与连线")
	ctx.check(not renderer.link.is_equal_approx(renderer.guide), "丝线与辅助线不同芯色")
	# 三条底线共用 NAVY_600（§3「连线/选中/焦点暗底保证边界」）—— 亮纸上单画浅色等于没画。
	for pair: Array in [["丝线", renderer.link_under], ["辅助线", renderer.guide_under],
			["选中轮廓", renderer.selected_under]]:
		ctx.equal(pair[1], Palette.get_color(Palette.Key.NAVY_600), "%s 的暗底 = NAVY_600" % pair[0])
	ctx.check(not renderer.port_in.is_equal_approx(renderer.port_out),
		"进出口两个接口用同族深浅分开（%s / %s）" % [renderer.port_in, renderer.port_out])
	ctx.check(not renderer.card_selected.is_equal_approx(renderer.card_fill),
		"选中时底板抬一档（状态不改牌面，只抬底）")
	# 写在**净纸**上的字必须是纸面墨：亮纸 GOLD_200 上卡墨 BLUE_100 只有 1.166:1。
	ctx.equal(renderer.paper_ink, Palette.get_color(Palette.Key.BROWN_700), "纸面墨 = BROWN_700")


## 辅助线的**范围**：只跨相关的那两张卡，不是通高 / 通宽一条亮线。
## 用 Snap 真跑一次吸附，量它回报的 span，而不是读代码猜。
##
## 三件事分开量，因为它们的失效方式不同：
##   1. **长度**：恰好 = 那两张卡的并集 + 两端余量。多一分就是画过头，少一分端点杠落不下。
##   2. **落在哪个轴**：竖直辅助线在固定的 x 上，它跨的必须是 **y** 区间。
##      这两个轴写反过一次，症状是线被画到画布顶上 —— 卡对了，线却不在它们之间。
##   3. **无关的卡不入账**：加一张远处的卡，长度必须一个像素都不变。
func _check_guide_is_short(ctx: RefCounted) -> void:
	var size: Vector2 = BoardModel.CARD_SIZE
	var canvas: Vector2 = EditorLayout.CANVAS_VIEW_SIZE
	# 两张几乎重合的卡：错开 3px，于是 X 与 Y 各自都吸上（两个轴的范围都能量到）。
	var obstacle: Rect2 = Rect2(200.0, 60.0, size.x, size.y)
	var moving: Rect2 = Rect2(203.0, 63.0, size.x, size.y)
	# 第三张远在下面（纵向差 268px，远超吸附半径）—— 它不该参与任何一条辅助线的范围。
	var away: Rect2 = Rect2(200.0, 400.0, size.x, size.y)
	var result: Snap.Result = Snap.resolve(moving, [obstacle, away] as Array[Rect2])

	ctx.check(result.snapped, "反向对照：这次吸附确实发生了（否则下面的范围断言是空的）")
	ctx.equal(result.guides_v.size(), 1, "竖直方向命中一条辅助线")
	ctx.equal(result.guides_h.size(), 1, "水平方向也命中一条")
	ctx.equal(result.spans_v.size(), result.guides_v.size(), "spans_v 与 guides_v 一一对应同序")
	ctx.equal(result.spans_h.size(), result.guides_h.size(), "spans_h 与 guides_h 一一对应同序")
	# 吸附后两张卡是同一个矩形，并集就是一张卡的边长。
	var union: float = size.y + Snap.GUIDE_MARGIN * 2.0
	var height: float = result.spans_v[0].y - result.spans_v[0].x
	var width: float = result.spans_h[0].y - result.spans_h[0].x
	ctx.near(height, union, "竖直辅助线长度 = 两张卡的并集 + 两端余量（%s）" % union)
	ctx.near(width, union, "水平辅助线长度同理（%s）" % union)
	ctx.check(height < canvas.y * 0.5 and width < canvas.x * 0.5,
		"两条辅助线（%s / %s）都远短于画布（%s）—— 不再是通高 / 通宽一条亮线"
			% [height, width, canvas])

	# 竖直辅助线画在 x = guides_v[0] 上，因此它的两端是 **y** 坐标，必须夹住那两张卡。
	# 轴写反时这里给出的是 x 区间，头一条就挂。
	var span: Vector2 = result.spans_v[0]
	ctx.check(span.x <= obstacle.position.y,
		"竖直辅助线的起点 %s 不高过最上面那张卡（%s）" % [span.x, obstacle.position.y])
	ctx.check(span.y >= obstacle.end.y, "竖直辅助线的终点 %s 不短于最下面那张卡" % span.y)
	ctx.check(span.y <= away.position.y, "远处的卡没有把辅助线拉长到它那里（%s ≤ %s）" % [span.y, away.position.y])

	var horizontal: Vector2 = result.spans_h[0]
	ctx.check(horizontal.x <= obstacle.position.x and horizontal.y >= obstacle.end.x,
		"水平辅助线两端夹住两张卡的 x 区间（%s）" % horizontal)


## 辅助线与丝线即使同族同色，线型也要分得开（13 §10.1）：辅助线是虚线 8/4，两端各一杠。
func _check_guide_line_style(ctx: RefCounted) -> void:
	# §1.1 把虚线的节拍写死了：实段 8、间隔 4。改这两个数就等于改「虚线长什么样」。
	ctx.near(StrokePainter.DASH_LENGTH, 8.0, "虚线实段 = §1.1 的 8")
	ctx.near(StrokePainter.DASH_GAP, 4.0, "虚线间隔 = §1.1 的 4")
	# GUIDE_TICK 是**半长**（paint_tick 往两端各画一截），故总长 = 2×它。
	ctx.near(BoardStatePainter.GUIDE_TICK * 2.0, 8.0, "端点杠总长 = §1.1 的 8（常量存的是半长）")
	ctx.check(BoardStatePainter.GUIDE_UNDER_WIDTH > BoardStatePainter.GUIDE_WIDTH,
		"辅助线的暗底 %s 比芯线 %s 宽"
			% [BoardStatePainter.GUIDE_UNDER_WIDTH, BoardStatePainter.GUIDE_WIDTH])

	var period: float = StrokePainter.DASH_LENGTH + StrokePainter.DASH_GAP
	# 取节拍的整十倍长 —— 长度不是整数个节拍时，末尾会多出一小截被截断的实线，
	# 占空比就不再等于节拍比（那是分段器的正常行为，不是「虚线被画成了实线」）。
	var length: float = period * 10.0
	var line: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
	var dashes: Array[PackedVector2Array] = StrokePainter.dashed(line)
	ctx.check(dashes.size() > 1, "%spx 的辅助线被切成 %d 段（不是一整条实线）" % [length, dashes.size()])
	var covered: float = 0.0
	for dash: PackedVector2Array in dashes:
		covered += dash[0].distance_to(dash[dash.size() - 1])
	var ratio: float = covered / length
	var expected: float = StrokePainter.DASH_LENGTH / period
	ctx.near(ratio, expected, "实线部分占 %.2f，等于虚线节拍的占空比" % expected)
	ctx.check(ratio < 0.95, "确实留有间隔，是虚线而不是被切碎的实线")
	# 再远一层：丝线走的是采样过的贝塞尔曲线，**不**经那支直线笔。所以即使同为浅蓝，
	# 「一条弯的实线 + 箭头」和「一串直角短线 + 端点杠」也读不成同一个东西。
	var thread: String = _read_code(THREAD_PAINTER)
	ctx.check(thread.contains("draw_polyline(") and not thread.contains("StrokePainter."),
		"丝线是曲线（draw_polyline），不走辅助线那支直线笔")


## 顺序即层级（立即模式绘制没有 z_index 可用）：丝线在卡后，辅助线在卡前。
func _check_layer_order(ctx: RefCounted) -> void:
	var body: String = _read_code(BOARD_RENDERER)
	var links: int = body.find("_paint_links(target, model)")
	var cards: int = body.find("_paint_card(target, card)")
	var guides: int = body.find("BoardStatePainter.paint_guides(target")
	ctx.check(links >= 0 and cards >= 0 and guides >= 0, "三层的调用点都找得到（改名字就要回来重看层级）")
	ctx.check(links < cards, "丝线先画、卡片后画 —— 常驻丝线退到卡后")
	ctx.check(cards < guides, "辅助线最后画 —— 吸附提示压在卡前，看得见")
	# 连线预览（拖动中的那根）跟在最后：它是「当前手势」的反馈，不能被任何东西盖住。
	var preview: int = body.find("paint_link_preview(target, model, pointer)")
	ctx.check(preview < 0 or preview > guides, "拖拉中的丝线预览画在最上层")


## 「不堆辉光」：状态层只有线与端点，一笔填充、一层光晕都没有。
func _check_no_glow(ctx: RefCounted) -> void:
	var body: String = _read_code(STATE_PAINTER)
	ctx.check(not body.contains("draw_"), "状态层没有任何直接绘制调用（全经那一支笔）")
	for forbidden: String in ["glow", "shader", "modulate", "WorldEnvironment", "draw_texture"]:
		ctx.check(not body.to_lower().contains(forbidden.to_lower()),
			"状态层没有出现「%s」—— 不堆辉光" % forbidden)


## 画布四周必须留出「接口圆点 + 状态边」画得下的余量。
##
## 靶子是自由摆放的卡停在角上时，输出接口（画在卡片右缘外）被 clip_contents 切掉半个圆。
## 这里不看截图、也不复述常量，而是把余量拿去和「最远要画到哪」逐个比，再用恒等式钉住它。
func _check_canvas_reserve(ctx: RefCounted) -> void:
	var reach: float = maxf(BoardView.PORT_RADIUS,
		BoardStatePainter.SELECT_GROW + BoardStatePainter.SELECT_WIDTH * 0.5)
	ctx.check(BoardView.EDGE_PADDING >= reach,
		"四周余量 %s ≥ 卡外最远要画到的 %s（接口半径与选中轮廓取大）"
			% [BoardView.EDGE_PADDING, reach])
	# §1.1：卡到裁切边 ≥16（E05）—— 余量本身就是契约给的这条数。
	ctx.near(BoardView.EDGE_PADDING, 16.0, "四周余量 = §1.1 的卡到裁切边 16")

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


## 读一个脚本的正文，去掉注释行（注释里出现的词不该把源码扫描判红）。
static func _read_code(path: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			kept.append(line)
	return "\n".join(kept)
