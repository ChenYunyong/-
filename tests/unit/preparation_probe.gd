## preparation_probe.gd
## 职责：PREPARATION 五分区占位布局的像素取证（09 §4）—— 证明分区**真的画在** 06 §7 的实测矩形上，
##       且右下角那块金色确实来自「主动作按钮」这个主题变体，而不是别处漏出来的。
## 所属系统：tests（09 §4 像素探针的 S1-07 用例模块）
## 依赖：Palette, palette_theme.gd, assets/ui/theme_main.tres, scenes/preparation/preparation.tscn
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得写任何字面色值 —— 判据一律取自 Palette。
##
## 拆分理由：聚合入口 run_render_probes.gd 已用到 284/300 行（02 §4），本组再塞进去会顶破上限。
## 09 §4 v0.1.3 已把「为守上限把取证基建拆成模块」立为先例，这里按同一办法把 S1-07 的用例也拆出来，
## 聚合入口只留一次调用 —— 于是 docs/09 §4 里那条命令仍然有效，本批不必改文档。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   组 6 的反向对照是「藏掉一个分区」→ 那一圈的描边像素必须整体归零，其余三个不受影响。
##   组 7 的反向对照是「换成辅助按钮变体」→ 金色必须一像素不剩。

extends RefCounted

const SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"

## 画布 = 06 §1 的 320×180 基准，与布局常量同一坐标系，于是「第几个像素」可以直接读。
const CANVAS: Vector2i = Vector2i(320, 180)
const VIEWPORT: Vector2 = Vector2(320.0, 180.0)

## 四个面板分区（CTA 是按钮，单独一组）。顺序与 PreparationLayout.Region 的前四项一致。
const PANEL_NAMES: PackedStringArray = ["RegionLeft", "RegionCenter", "RegionRight", "RegionBottom"]
const PANEL_BOXES: Array[Rect2] = [
	Rect2(15.0, 8.0, 73.0, 124.0),
	Rect2(98.0, 8.0, 128.0, 124.0),
	Rect2(226.0, 8.0, 83.0, 124.0),
	Rect2(15.0, 132.0, 294.0, 48.0),
]

## 06 §7 的 CTA 区块（64×14）装不下按钮，落位取「右下角照抄、高度向上长」→ 64×20。
const CTA_BOX: Rect2 = Rect2(246.0, 142.0, 64.0, 20.0)

var _h: RefCounted = null
var _tree: SceneTree = null
var _theme: Theme = null
var _scene: Control = null
var _edge: Color = Color.BLACK
var _fill: Color = Color.BLACK
var _gold: Color = Color.BLACK
var _gold_edge: Color = Color.BLACK


## 由聚合入口调用。harness 与 tree 都是借来的 —— 计数直接记在同一个 harness 上，
## 于是退出码与总计数不必两处维护。
func run(tree: SceneTree, harness: RefCounted, theme: Theme) -> void:
	_tree = tree
	_h = harness
	_theme = theme
	_edge = Palette.get_color(Palette.Key.BROWN_600)
	_fill = Palette.get_color(Palette.Key.NAVY_800)
	_gold = Palette.get_color(Palette.Key.GOLD_500)
	_gold_edge = Palette.get_color(Palette.Key.GOLD_600)

	print("")
	print("=== 组 6：PREPARATION 五分区画在实测矩形上（06 §7 像素取证）===")
	print("  判据色：分区描边=BROWN_600%s 分区底色=NAVY_800%s" % [_h.color_text(_edge), _h.color_text(_fill)])
	await _probe_regions()

	print("")
	print("=== 组 7：CTA 是右下角唯一的金色主动作按钮（06 §7 / §3）===")
	print("  判据色：按钮填充=GOLD_500%s 按钮描边=GOLD_600%s" % [_h.color_text(_gold), _h.color_text(_gold_edge)])
	await _probe_cta()


## 组 6：四个面板分区的 1px 描边必须严丝合缝落在 §7 实测矩形的四条边上。
## 量的是渲染出来的像素，不是「position/size 字段等于多少」—— 字段对而画错（被上层盖住、
## 画到别的坐标、被最小尺寸撑开）正是 S1-06 那次教训里字段层全绿而像素图唯一暴露的那类问题。
func _probe_regions() -> void:
	_h.reset()
	var image: Image = await _open_scene()
	if image == null:
		return

	for index: int in PANEL_NAMES.size():
		# 只有底条的右边缘被 CTA 压住；其余三个分区四周都完整。
		var occluder: Rect2 = CTA_BOX if index == 3 else Rect2()
		_assert_edges(image, PANEL_BOXES[index], PANEL_NAMES[index], _edge, occluder)

	# 反向对照一：藏掉右栏。那一圈描边必须整体归零 —— 归零不了就说明组 6 数的像素
	# 并非来自被测分区，本组没有判别力。
	var hidden: Node = _scene.find_child("RegionRight", true, false)
	if not _h.check(hidden != null, "应有 RegionRight 分区"):
		return
	hidden.set(&"visible", false)
	var control: Image = (await _h.settle())["image"]
	if control == null:
		return
	_h.check(_ring_pixels(control, PANEL_BOXES[2], _edge) == 0,
		"反向对照：藏掉右栏后它那一圈描边应为 0 px（实际 %d）" % _ring_pixels(control, PANEL_BOXES[2], _edge))
	# 同时其余三个必须毫发无伤 —— 否则上面那条归零可能只是整幅画面都没画出来。
	# 注意只核对没被藏掉的那三个（0 / 1 / 3），把 2 自己排掉。
	for index: int in [0, 1, 3]:
		var occluder: Rect2 = CTA_BOX if index == 3 else Rect2()
		_h.check(_ring_pixels(control, PANEL_BOXES[index], _edge) == _expected_ring(PANEL_BOXES[index], occluder),
			"反向对照：藏掉右栏不得影响 %s 的描边" % PANEL_NAMES[index])


## 四条边各断言一次（而不是只报一个总数）：描边一旦整体偏移，失败信息要能指出是哪条边。
##
## occluder 非空时，右边缘被它盖住的那几行要按覆盖数扣掉：06 §7 的 CTA 区块
## （246–310 × 148–162）本来就压在底条（15–309 × 132–180）的右下角上 —— 那是参考图实测的
## 样子，不是缺陷，探针得照着实际画面临认，而不是断言一个画面上不存在的整条边。
func _assert_edges(image: Image, box: Rect2, label: String, wanted: Color,
		occluder: Rect2 = Rect2()) -> void:
	var left: int = int(box.position.x)
	var top: int = int(box.position.y)
	var width: int = int(box.size.x)
	var height: int = int(box.size.y)
	var right: int = left + width - 1
	var covered: int = _covered_rows(right, top, height, occluder)
	_h.check(_h.count_row(image, top, left, left + width, wanted) == width,
		"%s：上边 y=%d 应是整条 %d px 描边" % [label, top, width])
	_h.check(_h.count_row(image, top + height - 1, left, left + width, wanted) == width,
		"%s：下边 y=%d 应是整条 %d px 描边" % [label, top + height - 1, width])
	_h.check(_h.count_col(image, left, top, top + height, wanted) == height,
		"%s：左边 x=%d 应是整条 %d px 描边" % [label, left, height])
	_h.check(_h.count_col(image, right, top, top + height, wanted) == height - covered,
		"%s：右边 x=%d 应是 %d px 描边（整条 %d px 减去被上层盖住的 %d 行）" % [
			label, right, height - covered, height, covered])
	# 反向对照二：往里挪一像素就不该再是描边 —— 证明上面四条读的是**确切的那一列/行**，
	# 而不是一条宽容的色带。
	_h.check(_h.count_col(image, left + 1, top, top + height, wanted) < height,
		"%s：左边内侧 x=%d 不应整列都是描边（否则测的是色带不是边）" % [label, left + 1])


## column 这一列上，落在 occluder 纵向区间内的行数。occluder 的横向区间不含该列时返回 0。
func _covered_rows(column: int, top: int, height: int, occluder: Rect2) -> int:
	if occluder.size.x <= 0.0:
		return 0
	if float(column) < occluder.position.x or float(column) >= occluder.end.x:
		return 0
	var first: int = maxi(top, int(occluder.position.y))
	var last: int = mini(top + height, int(occluder.end.y))
	return maxi(last - first, 0)


## 组 7：CTA 是右下角唯一的金色块，且金色来自主动作按钮变体。
func _probe_cta() -> void:
	_h.reset()
	var image: Image = await _open_scene()
	if image == null:
		return
	var button: Button = _scene.find_child("ButtonStartCombat", true, false) as Button
	if not _h.check(button != null, "应有 ButtonStartCombat"):
		return

	var live: Rect2 = button.get_global_rect()
	_h.check(live.is_equal_approx(CTA_BOX),
		"CTA 的实机矩形应是 §7 区块换算出的 %s（实际 %s）" % [CTA_BOX, live])
	_assert_edges(image, CTA_BOX, "CTA", _gold_edge)

	_h.check(_count_rect(image, CTA_BOX, _gold) > 0,
		"CTA 矩形内应有 GOLD_500 填充（实际 %d px）" % _count_rect(image, CTA_BOX, _gold))
	# 「唯一」：整幅画面上除了这一块，不许再有第二个 GOLD_500 区域。
	_h.check(_count_outside(image, CTA_BOX, _gold) == 0,
		"CTA 之外不得出现 GOLD_500（实际 %d px）—— 主动作按钮只能有一个" % _count_outside(image, CTA_BOX, _gold))
	# 边与填充同源同矩：四条边必须是 GOLD_600 而中心是 GOLD_500，两者不得串位。
	_h.check(_ring_pixels(image, CTA_BOX, _gold_edge) == _expected_ring(CTA_BOX),
		"CTA 四周应整圈是 GOLD_600 描边（期望 %d px，实际 %d）" % [
			_expected_ring(CTA_BOX), _ring_pixels(image, CTA_BOX, _gold_edge)])

	# 反向对照：换成辅助按钮变体（NAVY_700 底 + NAVY_600 描边），金色必须一像素不剩 ——
	# 归零失败就说明组 7 数的金色并非来自「主动作按钮」这个变体。
	var theme_script: GDScript = load(THEME_SCRIPT_PATH)
	button.theme_type_variation = theme_script.TYPE_BUTTON_SECONDARY
	button.queue_redraw()
	var control: Image = (await _h.settle())["image"]
	if control == null:
		return
	_h.check(_count_rect(control, CTA_BOX, _gold) == 0,
		"反向对照：换成辅助变体后 CTA 内 GOLD_500 应归零（实际 %d）" % _count_rect(control, CTA_BOX, _gold))
	_h.check(_ring_pixels(control, CTA_BOX, _gold_edge) == 0,
		"反向对照：换成辅助变体后 CTA 的 GOLD_600 描边应归零（实际 %d）"
			% _ring_pixels(control, CTA_BOX, _gold_edge))


## 把 preparation.tscn 挂上画布、按 320×180 落一次布局，再取像素。
## 显式调 apply_layout_for 而不是依赖画布尺寸推断 —— 探针要证的是「布局画在哪」，
## 折叠与否这件事已由 test_preparation.gd 单独覆盖，这里把它钉死在宽屏档。
func _open_scene() -> Image:
	var packed: PackedScene = load(SCENE_PATH)
	if not _h.check(packed != null, "preparation.tscn 应能加载"):
		return null
	_h.set_canvas_size(CANVAS)
	_scene = packed.instantiate()
	_scene.theme = _theme
	_h.adopt(_scene)
	await _h.settle()
	_scene.size = VIEWPORT
	_scene.call(&"apply_layout_for", VIEWPORT)
	return (await _h.settle())["image"]


## 分区那一圈描边的像素总数：上 / 下两行 + 左 / 右两列。四个角各被数了两次，故期望值
## 是 2×(宽+高)，不是周长减 4 —— 这里刻意留着重数，好让「某条边整条缺失」直接表现为数目不足。
## occluder 同 _assert_edges：被上层盖住的行不计入。
func _ring_pixels(image: Image, box: Rect2, wanted: Color, occluder: Rect2 = Rect2()) -> int:
	var left: int = int(box.position.x)
	var top: int = int(box.position.y)
	var width: int = int(box.size.x)
	var height: int = int(box.size.y)
	return _h.count_row(image, top, left, left + width, wanted) \
		+ _h.count_row(image, top + height - 1, left, left + width, wanted) \
		+ _h.count_col(image, left, top, top + height, wanted) \
		+ _h.count_col(image, left + width - 1, top, top + height, wanted)


func _expected_ring(box: Rect2, occluder: Rect2 = Rect2()) -> int:
	return 2 * (int(box.size.x) + int(box.size.y)) \
		- _covered_rows(int(box.position.x + box.size.x) - 1, int(box.position.y), int(box.size.y), occluder)


func _count_rect(image: Image, box: Rect2, wanted: Color) -> int:
	var total: int = 0
	for y: int in range(int(box.position.y), int(box.position.y + box.size.y)):
		total += _h.count_row(image, y, int(box.position.x), int(box.position.x + box.size.x), wanted)
	return total


## 矩形之外的判据色像素数。「唯一」这类断言靠它 —— 只数内部数不出「别处还有一块」。
func _count_outside(image: Image, box: Rect2, wanted: Color) -> int:
	var total: int = 0
	for y: int in image.get_size().y:
		for x: int in image.get_size().x:
			if box.has_point(Vector2(x, y)):
				continue
			if _h.near(image.get_pixel(x, y), wanted):
				total += 1
	return total
