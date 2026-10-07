## test_editor_state.gd
## 职责：画布状态层级的验收（PET-87 §2）—— 选中与焦点可分、辅助线只跨相关两卡、金色不兼任。
## 所属系统：tests
## 依赖：BoardRenderer, BoardStatePainter, StrokePainter, Snap, Palette, BoardModel, EditorLayout
## 禁止：本文件不得写入几何常量或色值，只断言。
##
## §2 报的是「金色现在承担了太多职责」。这类缺陷的麻烦之处在于它**不会报错**：
## 把 Focus 也涂成金色，界面照样跑、截图照样出，只有人盯着看才发现分不出「我在编辑哪张」
## 和「我指着哪张」。所以下面把三条口径各自变成一句可执行的断言：
##   1. 焦点与选中不同色、不同粗细、不同画法（角标 vs 轮廓）；
##   2. 辅助线的**范围**只跨相关那两张卡 —— 用 Snap 真跑一次，量出来；
##   3. 金色只出现在「选中」与「对齐提示」两处，丝线是蓝的；
##   4. 丝线画在卡后、辅助线画在卡前（顺序即层级）。

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


## 状态层各画各的色 —— 逐个钉死 Token，而不是「看着不一样就行」。
func _check_palette_roles(ctx: RefCounted) -> void:
	var renderer: BoardRenderer = BoardRenderer.new()
	ctx.equal(renderer.selected, Palette.get_color(Palette.Key.GOLD_500), "选中 = 金色（唯一承担「选中」的色）")
	ctx.equal(renderer.focus, Palette.get_color(Palette.Key.BLUE_300), "焦点 = 浅蓝（不抢金色的语义）")
	ctx.check(not renderer.focus.is_equal_approx(renderer.selected),
		"焦点与选中是两支不同的颜色（%s / %s）" % [renderer.focus, renderer.selected])
	ctx.equal(renderer.guide, Palette.get_color(Palette.Key.GOLD_400), "辅助线 = 金色（对齐提示）")
	ctx.equal(renderer.link, Palette.get_color(Palette.Key.BLUE_400), "常驻丝线 = 蓝，金色不参与连线")
	ctx.check(not renderer.link.is_equal_approx(renderer.guide), "丝线与辅助线不同色")
	ctx.check(not renderer.link_active.is_equal_approx(renderer.guide), "激活丝线也不与辅助线撞色")
	ctx.check(not renderer.port_in.is_equal_approx(renderer.port_out),
		"进出口两个接口用同族深浅分开（%s / %s）" % [renderer.port_in, renderer.port_out])
	ctx.check(not renderer.card_selected.is_equal_approx(renderer.card_fill),
		"选中时底板抬一档（状态不改牌面，只抬底）")


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


## 辅助线与丝线即使同色，线型也要分得开（13 §10.1）：辅助线是虚线。
func _check_guide_line_style(ctx: RefCounted) -> void:
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


## 读一个脚本的正文，去掉注释行（注释里出现的词不该把源码扫描判红）。
static func _read_code(path: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			kept.append(line)
	return "\n".join(kept)
