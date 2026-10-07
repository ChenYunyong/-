## test_map_layout.gd
## 职责：路线图屏**版式**的验收 —— 羊皮卷 / 地图区 / 图例 / 底部动作条都落在 960×540 之内，
##       节点整颗在区内、相邻命中区不重叠、短名与图例标签不顶出纸外。
## 所属系统：tests
## 依赖：MapModel, MapLayout, MapView, MapNodePainter, ArcaneTheme, UiKit
## 禁止：本文件不得写入布局常量，只断言。
##
## 从 test_map_paint 里分出来，是因为那支文件顶到了 test_source_rules 的 300 行上限。
## 分界线是**性质**：那边管「画上去长什么样」（颜色、墨色、符号、笔），
## 这里管「东西摆在哪、摆不摆得下」（纯几何，改版式才会动）。

extends RefCounted

## 触控下限 44 **设备像素**，窗口 / 画布 = 2 → 22 逻辑像素（docs/06 §1）。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## 间距系统（4/8/12/16/24 ×3）—— 分区边距只许取这些值。
const SPACING_SCALE: PackedFloat32Array = [12.0, 24.0, 36.0, 48.0, 72.0]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_map_layout")
	_check_screen(ctx)
	_check_nodes(ctx)
	_check_touch_target(ctx)
	_check_labels(ctx)
	_check_legend(ctx)
	_check_bottom_bar(ctx)


## 整屏分区：上下三块 + 两条间距正好等于 540，左右同样收得住。
func _check_screen(ctx: RefCounted) -> void:
	var parchment: Rect2 = MapLayout.parchment()
	ctx.check(parchment.position.x >= MapLayout.MARGIN and parchment.position.y >= MapLayout.MARGIN,
		"羊皮卷离屏边留了安全边距")
	ctx.near(parchment.end.y + MapLayout.GAP + MapLayout.BOTTOM_SIZE.y + MapLayout.MARGIN,
		MapLayout.SCREEN.y, "卷 + 间距 + 底部动作条 + 边距 = 屏高 540")
	ctx.check(parchment.end.x + MapLayout.MARGIN <= MapLayout.SCREEN.x, "羊皮卷不超出屏宽")
	ctx.check(parchment.position.x + parchment.size.x <= MapLayout.SCREEN.x, "卷右边留得下边距")
	ctx.check(MapLayout.bottom_bar().end.y + MapLayout.MARGIN <= MapLayout.SCREEN.y,
		"底部动作条不超出屏底")
	for margin: float in [MapLayout.MARGIN, MapLayout.GAP, MapLayout.PADDING]:
		ctx.check(SPACING_SCALE.has(margin), "边距 %s 取自间距系统 4/8/12/16/24" % margin)

	# 卷里那四块：标题 / 当前位置 / 路线图区 / 图例，都在卷内且互不重叠。
	# *_RECT 常量是**卷内局部坐标**，所以拿一个同尺寸的局部矩形去量；
	# title_rect() / status_rect() 是屏坐标，另外比一次，把「+ 卷原点」那一步也钉住。
	var local: Rect2 = Rect2(Vector2.ZERO, MapLayout.PARCHMENT_SIZE)
	var pieces: Array[Rect2] = [MapLayout.TITLE_RECT, MapLayout.STATUS_RECT, MapLayout.MAP_RECT,
		MapLayout.LEGEND_RECT]
	for piece: Rect2 in pieces:
		ctx.check(local.encloses(piece), "区块 %s 落在羊皮卷里" % piece)
	ctx.check(parchment.encloses(MapLayout.title_rect()), "标题的屏坐标 = 卷原点 + 卷内坐标")
	ctx.check(parchment.encloses(MapLayout.status_rect()), "当前位置那行的屏坐标同理")
	ctx.check(not MapLayout.TITLE_RECT.intersects(MapLayout.STATUS_RECT),
		"标题与当前位置各占一边，不叠在一起")
	ctx.check(MapLayout.MAP_RECT.end.y <= MapLayout.LEGEND_SEAM_Y, "地图区收在折痕之上")
	ctx.near(MapLayout.LEGEND_RECT.position.y, MapLayout.LEGEND_SEAM_Y, "折痕就是图例的上沿")


## 六个层三个列：每个节点整颗（含外圈外扩那一圈）都在地图区里，相邻的圆不重叠。
func _check_nodes(ctx: RefCounted) -> void:
	var grown: float = MapLayout.NODE_RADIUS + _max_ring_grow()
	var centers: Array[Vector2] = []
	var outside: PackedStringArray = PackedStringArray()
	for tier: int in MapModel.TIERS:
		for column: int in MapModel.COLUMNS:
			var at: Vector2 = MapLayout.node_position(tier, column)
			centers.append(at)
			if not MapLayout.MAP_RECT.grow(-grown).has_point(at):
				outside.append("(%d,%d)" % [tier, column])
	ctx.equal(centers.size(), MapModel.TIERS * MapModel.COLUMNS, "六层三列一个不少")
	ctx.equal(outside.size(), 0,
		"每个节点都整颗落在地图区里" if outside.is_empty() else "越界：%s" % ", ".join(outside))

	# 层间节拍要容得下两颗相邻的节点 —— 不然上一层的圆会压到下一层的圆上。
	ctx.check(MapLayout.tier_pitch() >= MapLayout.NODE_RADIUS * 2.0,
		"层间节拍 %.0f ≥ 一个节点直径" % MapLayout.tier_pitch())
	# 第 0 层在**下**：层号越大越靠上（从下往上走）。
	ctx.check(MapLayout.node_position(0, 0).y > MapLayout.node_position(MapModel.TIERS - 1, 0).y,
		"第 0 层在最下面")

	var too_close: int = 0
	for one: int in centers.size():
		for other: int in range(one + 1, centers.size()):
			if centers[one].distance_to(centers[other]) < MapView.NODE_RADIUS * 2.0:
				too_close += 1
	ctx.equal(too_close, 0, "相邻节点的圆不重叠（点哪个就是哪个）")


## 命中区够不够手指点。命中区**就是**画出来那个圆（MapLayout.NODE_RADIUS 只定义一次），
## 于是这里量的是节点尺寸本身，而不是另一套隐形数字。
func _check_touch_target(ctx: RefCounted) -> void:
	var device_px: float = MapView.NODE_RADIUS * 2.0 * DEVICE_SCALE
	ctx.check(device_px >= MIN_TOUCH_DEVICE_PX,
		"命中区直径 %.0f 设备像素 ≥ %.0f 下限" % [device_px, MIN_TOUCH_DEVICE_PX])
	# 反向对照：图例那种小节点（半径 7）只有 28 设备像素，过不了这条线 ——
	# 说明下面这个下限不是随便画个圆就满足得了的，上面那条量的是尺寸本身。
	var legend_px: float = MapLayout.LEGEND_NODE_RADIUS * 2.0 * DEVICE_SCALE
	ctx.check(legend_px < MIN_TOUCH_DEVICE_PX,
		"反向对照：图例小节点只有 %.0f 设备像素，不够当点击目标" % legend_px)


## 节点右边那行短名不能顶出纸外。
func _check_labels(ctx: RefCounted) -> void:
	var font: float = float(ArcaneTheme.PARAM_FONT_SIZE)
	var overflow: PackedStringArray = PackedStringArray()
	var kinds: Array[MapModel.Kind] = [MapModel.Kind.BATTLE, MapModel.Kind.WORKSHOP]
	for kind: MapModel.Kind in kinds:
		var width: float = UiKit.text_units(MapView.kind_text(kind)) * font
		var right: float = MapLayout.node_position(0, MapModel.COLUMNS - 1).x \
			+ MapLayout.NODE_RADIUS + MapLayout.NODE_LABEL_GAP + width
		if right > MapLayout.PARCHMENT_SIZE.x:
			overflow.append("%s 到 %.0f" % [MapView.kind_text(kind), right])
	ctx.equal(overflow.size(), 0,
		"最右一列的短名不顶出纸外" if overflow.is_empty() else "顶出去了：%s" % ", ".join(overflow))
	# 反向对照：短名的起点一定在节点右边，不是压在符号上。
	ctx.check(MapLayout.node_label_baseline(0, 0).x > MapLayout.node_position(0, 0).x,
		"短名写在节点的右边")


## 图例：四格铺满折痕下面那条，每格的标签不撞到下一格、也不顶出纸外。
func _check_legend(ctx: RefCounted) -> void:
	ctx.check(MapLayout.LEGEND_RECT.end.y + MapLayout.PADDING <= MapLayout.PARCHMENT_SIZE.y,
		"图例之下还留着内边距")
	ctx.near(MapLayout.LEGEND_ITEM_WIDTH * float(MapView.LEGEND_STATES.size()),
		MapLayout.LEGEND_RECT.size.x, "四格正好铺满图例那一条")
	var previous_end: float = 0.0
	for index: int in MapView.LEGEND_STATES.size():
		var center: Vector2 = MapLayout.legend_node_position(index)
		var baseline: Vector2 = MapLayout.legend_label_baseline(index)
		ctx.check(MapLayout.LEGEND_RECT.has_point(center), "图例第 %d 个小节点在那一格里" % index)
		ctx.check(center.x > previous_end, "图例第 %d 格不与上一格叠在一起" % index)
		ctx.check(baseline.x < center.x + MapLayout.LEGEND_ITEM_WIDTH, "图例标签在它自己那格里")
		previous_end = baseline.x + UiKit.text_units(MapView.state_text(MapView.LEGEND_STATES[index])) \
			* float(ArcaneTheme.PARAM_FONT_SIZE)
		ctx.check(previous_end <= MapLayout.LEGEND_RECT.end.x, "图例第 %d 格的标签不顶出纸外" % index)
	# 四个状态一个不漏 —— 少一个，玩家就得靠猜剩下那个是什么意思。
	var listed: Dictionary = {}
	for state: MapNodePainter.State in MapView.LEGEND_STATES:
		listed[state] = true
	ctx.equal(listed.size(), 4, "图例把四种状态都列了")


## 底部动作条：提示文字与两颗按钮各占一边，互不重叠，且都在条内。
##
## 这里量的是**文字宽度**而不是提示 Label 那个 648 宽的矩形：English 的两颗按钮
## 比中文宽得多（BACK TO EDITOR / CONTINUE），拿矩形去比会在英文下假报重叠 ——
## 而真正会撞的只有文字本身。
func _check_bottom_bar(ctx: RefCounted) -> void:
	var bar: Rect2 = MapLayout.bottom_bar()
	var hint: Rect2 = MapLayout.bottom_hint_rect()
	ctx.check(bar.encloses(hint), "提示文字落在动作条里")

	# 按两颗按钮的真实宽度从右往左摆一遍（与 map_screen 同一套 UiKit 估算）。
	var continue_width: float = UiKit.button_width(TranslationServer.translate("继续"))
	var back_width: float = UiKit.button_width(TranslationServer.translate("返回编辑器"))
	var back_left: float = bar.end.x - continue_width - MapLayout.GAP - back_width
	var hint_text: float = hint.position.x + UiKit.text_units(
		TranslationServer.translate("点亮的节点可以前往")) * float(ArcaneTheme.BODY_FONT_SIZE)
	ctx.check(back_left > hint_text,
		"两颗按钮排在提示文字的右边（%.0f > %.0f）" % [back_left, hint_text])
	ctx.check(back_left >= bar.position.x, "两颗按钮都还在动作条里")
	ctx.check(continue_width + MapLayout.GAP + back_width < bar.size.x,
		"两颗按钮加间距窄于动作条（还留得下提示文字）")
	var height: float = UiKit.button_height()
	ctx.check(height <= bar.size.y, "按钮高 %.0f 放得进 %.0f 的动作条" % [height, bar.size.y])


## 全部状态里最大的外圈外扩量 —— 判定越界要连它一起算，否则外扩那一圈会压出界。
static func _max_ring_grow() -> float:
	var most: float = 0.0
	for grow: float in MapNodePainter.STATE_RING_GROW:
		most = maxf(most, grow)
	return most
