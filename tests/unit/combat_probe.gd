## combat_probe.gd
## 职责：COMBAT 战场 / 状态带分界与上沿的像素取证（09 §4）—— 证明 06 §8 的「上沿 NAVY_600 分隔、
##       底色 NAVY_800、横贯全宽」是**真的画在** y=270 这条线上，而不是「字段等于多少」。
## 所属系统：tests（09 §4 像素探针的 S1-08 用例模块）
## 依赖：Palette, assets/ui/theme_main.tres, scenes/combat/combat.tscn
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得写任何字面色值 —— 判据一律取自 Palette。
##
## 拆分理由：聚合入口 run_render_probes.gd 已用到 284/300 行（02 §4），
## 按 09 §4 v0.1.3 的先例把 S1-08 的用例拆成模块，聚合入口只留一次调用。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   反向对照一 —— 把状态带整体上移 8px（PET-80 前 4px），分界必须跟着移到 y=262、
##                 y=270 必须不再是上沿。量不到这个位移，就说明断言只是在「某处找一条深色线」，
##                 证明不了它落在 270。
##   反向对照二 —— 藏掉 StatusEdge，状态带区内的 NAVY_600 必须归零、且全图不再有整行结构线。
##                 （PET-77 起战场区的节点卡切片自带 NAVY_600 卡面像素，故判据由「全图归零」
##                  改为「带内归零 + 全图无整行同色结构线」，判别力不变，见 _probe_band()。）
##   反向对照三 —— 藏掉 StatusFill，状态带内的 NAVY_800 必须归零。
##
## 分工：本探针只量**宽屏**（06 §8 的实测档）。窄屏折叠是布局问题，
## 由 tests/unit/test_combat.gd 与 tests/integration/combat_smoke.gd 覆盖。

extends RefCounted

const SCENE_PATH: String = "res://scenes/combat/combat.tscn"

## 画布 = 06 §1 的 640×360 基准（PET-80 前 320×180），与布局常量同一坐标系，
## 于是「第几个像素」可以直接读。
const CANVAS: Vector2i = Vector2i(640, 360)
const VIEWPORT: Vector2 = Vector2(640.0, 360.0)

## 06 §8 实测的分界：状态带 y 270–360（PET-80 前 135–180，逐项 ×2）。
## 上沿占第 270–271 行，填充从第 272 行起、到第 359 行止。
const BAND_TOP: int = 270
const BAND_FILL_TOP: int = 272
const BAND_BOTTOM: int = 359
## 上沿厚度（逻辑像素）。PET-80：1 → 2。
##
## StatusEdge 是 combat.tscn 里 `anchors_preset = 10` + `offset_bottom` 的 **ColorRect**，
## 由代码按布局常量画 —— 不是 assets/** 的九宫格切片（切片边距是**纹素**读数，本卡不动）。
## 故它随基准画布 ×2 是**布局**变化：2 逻辑像素在 2× 整数缩放下仍是 4 设备像素，
## 与 PET-80 前「1 逻辑像素 × 4× = 4 设备像素」逐设备像素相同。PET-81 换 2× 切片推翻不了这条。
const EDGE_ROWS: int = 2
## 反向对照的位移量。它是一条**长度**，故随坐标系 ×2（PET-80 前 4）。
const SHIFT: float = 8.0

## 06 §8.1（v0.1.10，Codex 裁定）的 5 个只读读数块，按带内从左到右的顺序，节点名同 combat.tscn。
const READOUT_BLOCKS: PackedStringArray = ["Wave", "Core", "Heat", "Energy", "Queue"]
## 反向对照三：把读数行的行距撑到远大于格宽，排在后面的格会被挤出视口。
## PET-80：格宽随坐标系 ×2，故这个「远大于」的取值也跟着 ×2（200 → 400），
## 否则它就从「远大于格宽」退化成「约等于格宽」——判别力会悄悄变弱。
const ROW_OVERFLOW_SEPARATION: int = 400

var _h: RefCounted = null
var _tree: SceneTree = null
var _theme: Theme = null
var _scene: Control = null
var _band_fill: Color = Color.BLACK
var _band_edge: Color = Color.BLACK


## 由聚合入口调用。harness 与 tree 都是借来的 —— 计数直接记在同一个 harness 上，
## 于是退出码与总计数不必两处维护。
func run(tree: SceneTree, harness: RefCounted, theme: Theme) -> void:
	_tree = tree
	_h = harness
	_theme = theme
	_band_fill = Palette.get_color(Palette.Key.NAVY_800)
	_band_edge = Palette.get_color(Palette.Key.NAVY_600)

	print("")
	print("=== 组 8：COMBAT 战场 / 状态带分界与上沿（06 §8 像素取证）===")
	print("  判据色：带上沿=NAVY_600%s 带底色=NAVY_800%s" % [
		_h.color_text(_band_edge), _h.color_text(_band_fill),
	])
	await _probe_band()
	await _probe_shift()
	await _probe_layers()
	await _probe_readouts()


## 组 8：分界行、上沿厚度、带的四边与底色。
func _probe_band() -> void:
	_h.reset()
	var image: Image = await _open_scene()
	if image == null:
		return

	_assert_scanlines(image, BAND_TOP, "状态带上沿")
	# 上沿**只有 EDGE_ROWS 行**（PET-80 前 1 行）：上沿之上、以及上沿之下都不该再有 NAVY_600。
	_h.check(_h.count_row(image, BAND_TOP - 1, 0, CANVAS.x, _band_edge) == 0,
		"分界上一行 y=%d 不得是 NAVY_600（上沿之上没有第二条线）" % (BAND_TOP - 1))
	_h.check(_h.count_row(image, BAND_FILL_TOP, 0, CANVAS.x, _band_edge) == 0,
		"分界下一行 y=%d 不得是 NAVY_600（上沿只占 %d 行）" % [BAND_FILL_TOP, EDGE_ROWS])
	# 「只有这一条」。
	# 原来钉：整幅画面的 NAVY_600 == 320（= 上沿长度）—— 当时战场区一个 NAVY_600 像素都没有。
	# 现在钉：① 状态带区（y ≥ BAND_TOP）内 NAVY_600 == EDGE_ROWS × 640（= 上沿自身的像素数）；
	#         ② 全图不存在 EDGE_ROWS 行之外的第二条**整行 640px** 的 NAVY_600。
	# 为什么是同一件事：这条要证的是「分界线只有一条，别处不再有同色的结构线」。
	#   PET-80 让两个数一起 ×2（320 → 640，1 行 → 2 行），比值不变，钉的仍是同一件事。
	#   接入 VB-03 后，蓝图节点卡切片（已批准素材，`asset_manifest.json` 的 tokens 列有 NAVY_600）
	#   自带卡面描边像素，落在战场区的 MachineView 里 —— 那是 24×24 **纹素**的卡面贴到 48×48
	#   的格上，最近邻放大后单张卡面最多 48px 连续，与一整行 640px 差一个数量级。
	#   ① 把「带内唯一」钉得和原来一样死；② 比原来更精确地把「别处没有同色结构线」钉死。
	_h.check(_count_range(image, BAND_TOP, CANVAS.y, _band_edge) == CANVAS.x * EDGE_ROWS,
		"状态带区（y %d–%d）的 NAVY_600 应恰好等于上沿自身的像素数 %d（实际 %d）" % [
			BAND_TOP, BAND_BOTTOM, CANVAS.x * EDGE_ROWS,
			_count_range(image, BAND_TOP, CANVAS.y, _band_edge)])
	var full_rows: Array[int] = _full_width_rows(image, _band_edge)
	_h.check(full_rows == [BAND_TOP, BAND_FILL_TOP - 1],
		"全图应只有第 %d–%d 行是整行 %dpx 的 NAVY_600 —— 别处不得再有同色结构线（实际 %s）" % [
			BAND_TOP, BAND_FILL_TOP - 1, CANVAS.x, full_rows])

	# 战场侧：状态带的两种色一点都不能越界到 y<270。
	_h.check(_count_range(image, 0, BAND_TOP, _band_fill) == 0,
		"战场区域（y 0–%d）内不得出现 NAVY_800（实际 %d）" % [
			BAND_TOP - 1, _count_range(image, 0, BAND_TOP, _band_fill)])
	# 状态带侧：NAVY_600 只在上沿那几行，带内其余部分不许再出现。
	_h.check(_count_range(image, BAND_FILL_TOP, CANVAS.y, _band_edge) == 0,
		"状态带体内（y %d–%d）不得出现 NAVY_600（实际 %d）" % [
			BAND_FILL_TOP, BAND_BOTTOM, _count_range(image, BAND_FILL_TOP, CANVAS.y, _band_edge)])

	# 06 §8：横贯全宽、贴到画面底，且左 / 下缘没有第三条描边（§8 只规定了上沿）。
	_h.check(_h.count_col(image, 0, BAND_FILL_TOP, CANVAS.y, _band_fill) == CANVAS.y - BAND_FILL_TOP,
		"状态带左缘 x=0 应整列是 NAVY_800（左缘无描边）")
	_h.check(_h.count_col(image, CANVAS.x - 1, BAND_FILL_TOP, CANVAS.y, _band_fill) == CANVAS.y - BAND_FILL_TOP,
		"状态带右缘 x=%d 应整列是 NAVY_800（右缘无描边）" % (CANVAS.x - 1))
	_h.check(_h.count_row(image, BAND_BOTTOM, 0, CANVAS.x, _band_fill) == CANVAS.x,
		"状态带底边 y=%d 应整行是 NAVY_800（底缘无描边）" % BAND_BOTTOM)


## 反向对照一：状态带整体上移 8px（PET-80 前 4px），分界必须跟着走。
## 这条把「探针读的是确切那一行」和「那条线确实由状态带的位置决定」一起钉死：
## 若探针只是在某处找一条深色线，位移之后它仍然会绿。
func _probe_shift() -> void:
	_h.check(_scene != null, "应有已装载的 COMBAT 场景")
	if _scene == null:
		return
	var bar: Control = _scene.find_child("StatusBar", true, false) as Control
	if not _h.check(bar != null, "场景应有 StatusBar 容器"):
		return

	var origin: Vector2 = bar.position
	bar.position = Vector2(origin.x, origin.y - SHIFT)
	var image: Image = (await _h.settle())["image"]
	if image == null:
		return
	_assert_scanlines(image, BAND_TOP - int(SHIFT), "反向对照：状态带上移 8 逻辑像素后")
	_h.check(_h.count_row(image, BAND_TOP, 0, CANVAS.x, _band_edge) == 0,
		"反向对照：上移后原来的 y=%d 不该再有 NAVY_600" % BAND_TOP)
	_h.check(_count_range(image, CANVAS.y - int(SHIFT), CANVAS.y, _band_fill) == 0,
		"反向对照：上移后画面最底部 %d 行不该再有 NAVY_800（带已经跟着走了）" % int(SHIFT))
	bar.position = origin


## 反向对照二 / 三：藏掉上沿 → 判据色归零；藏掉底色 → 带内 NAVY_800 归零。
## 归零失败就说明组 8 数到的像素并非来自这两层，本组没有判别力。
func _probe_layers() -> void:
	if _scene == null:
		return
	var edge: Node = _scene.find_child("StatusEdge", true, false)
	var fill: Node = _scene.find_child("StatusFill", true, false)
	if not _h.check(edge != null and fill != null, "场景应有 StatusEdge 与 StatusFill 两层"):
		return

	edge.set(&"visible", false)
	var control: Image = (await _h.settle())["image"]
	if control == null:
		return
	# 原来钉：藏掉 StatusEdge 后全图 NAVY_600 归零。
	# 现在钉：状态带区内 NAVY_600 归零 **且** 全图不再有任何整行 640px 的 NAVY_600。
	# 为什么是同一件事：这条要证的是「组 8 数到的那些像素确实来自 StatusEdge 这一层」。
	#   带内那 1280 个像素（2 行 × 640）与那两条整行结构线同属上沿，两层判据一起看，
	#   来源仍是唯一的一层。PET-80 只让「1280」和「两条」替代「320」和「一条」，命题不变。
	_h.check(_count_range(control, BAND_TOP, CANVAS.y, _band_edge) == 0,
		"反向对照：藏掉上沿后状态带区内的 NAVY_600 应归零（实际 %d）"
			% _count_range(control, BAND_TOP, CANVAS.y, _band_edge))
	_h.check(_full_width_rows(control, _band_edge).is_empty(),
		"反向对照：藏掉上沿后全图不该再有整行 %dpx 的 NAVY_600（实际 %s）" % [
			CANVAS.x, _full_width_rows(control, _band_edge)])
	edge.set(&"visible", true)

	fill.set(&"visible", false)
	control = (await _h.settle())["image"]
	if control == null:
		return
	_h.check(_count_range(control, BAND_FILL_TOP, CANVAS.y, _band_fill) == 0,
		"反向对照：藏掉底色后带内 NAVY_800 应归零（实际 %d）" % _count_range(control, BAND_FILL_TOP, CANVAS.y, _band_fill))
	# 上沿与底色是两层：藏掉底色不该把上沿一起带走，否则「上沿分隔」这条就无从谈起。
	_h.check(_h.count_row(control, BAND_TOP, 0, CANVAS.x, _band_edge) == CANVAS.x,
		"反向对照：藏掉底色后上沿仍应是整条 %d px" % CANVAS.x)
	fill.set(&"visible", true)


## 组 9：06 §8.1（v0.1.10，Codex 裁定）的读数区 —— 5 个只读读数块**真的都被画到了屏幕上**。
## 09 §4 明写「禁止用配置项等于某个值代替可见结果确实出现」，而「ReadoutsRow 有几个子节点」
## 正是配置项：5 个块若被挤出视口、或被裁掉半格，节点数照样是 5。
## 故这里量的是**每一格矩形内有没有文字墨迹**，以及它是否完整落在读数视口内。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   反向对照一 —— 藏掉末格（队列）：那一格墨迹必须归零，且其余四格的矩形与墨迹逐一不变。
##                 「藏一个不会有这种局部效果」说明五格是各自独立画出来的，不是同一格。
##   反向对照二 —— 整条状态带移出画布：5 格墨迹必须全部归零（证明墨迹来自这条带）。
##   反向对照三 —— 把行距撑到 400：完整落在视口内的格数必须少于 5、末格墨迹归零
##                 （证明「5 格都画出来」这条不是恒真）。
func _probe_readouts() -> void:
	print("")
	print("=== 组 9：COMBAT 读数区 5 格都画出来了（06 §8.1 像素取证）===")
	_h.reset()
	var image: Image = await _open_scene()
	if image == null:
		return
	var viewport_rect: Rect2 = _readouts_rect()
	var rects: Array = _block_rects()
	if not _h.check(rects.size() == READOUT_BLOCKS.size(),
			"读数区应有 %d 格（实际 %d）" % [READOUT_BLOCKS.size(), rects.size()]):
		return
	var inks: Array = []
	for index: int in READOUT_BLOCKS.size():
		inks.append(_ink(image, rects[index]))

	for index: int in READOUT_BLOCKS.size():
		_h.check(int(inks[index]) > 0,
			"第 %d 格（%s）矩形内应真有文字墨迹 —— 它被画出来了（实际 %d px）" % [
				index + 1, READOUT_BLOCKS[index], int(inks[index])])
		_h.check(viewport_rect.encloses(rects[index]),
			"第 %d 格（%s）应完整落在读数视口内，没有被裁掉" % [index + 1, READOUT_BLOCKS[index]])
		if index + 1 < READOUT_BLOCKS.size():
			_h.check(_is_blank(image, _gap_between(rects[index], rects[index + 1])),
				"第 %d 格（%s）与第 %d 格（%s）之间应是一条空带 —— 它们是两格，不是同一格" % [
					index + 1, READOUT_BLOCKS[index], index + 2, READOUT_BLOCKS[index + 1]])

	await _probe_readout_blank_last(rects, inks)
	await _probe_readout_band_shift()
	await _probe_readout_row_overflow(viewport_rect)


## 反向对照一：藏掉**末格**（队列 —— 它右边没有别的格，藏掉它不会移动任何格）。
## 末格墨迹归零、其余四格的矩形与墨迹逐一不变 —— 这条同时钉住「墨迹计数读的确实是那一格」
## 与「五格各自独立绘制」，若五格其实是同一格，藏一个不会有这种局部效果。
func _probe_readout_blank_last(rects: Array, inks: Array) -> void:
	var last_index: int = READOUT_BLOCKS.size() - 1
	var last: Control = _block(READOUT_BLOCKS[last_index])
	if not _h.check(last != null, "应有末格（%s）读数块" % READOUT_BLOCKS[last_index]):
		return

	last.visible = false
	var image: Image = (await _h.settle())["image"]
	var after: Array = _block_rects()
	_h.check(_ink(image, rects[last_index]) == 0,
		"反向对照：藏掉末格后那一格不得再有墨迹（实际 %d px）" % _ink(image, rects[last_index]))
	var changed: int = 0
	for index: int in last_index:
		if after[index] != rects[index] or _ink(image, after[index]) != int(inks[index]):
			changed += 1
	_h.check(changed == 0,
		"反向对照：藏掉末格不该移动或改变其余 %d 格（违例 %d 格）" % [last_index, changed])
	last.visible = true
	var restored: Image = (await _h.settle())["image"]
	_h.check(_ink(restored, _block_rects()[last_index]) == int(inks[last_index]),
		"还原末格后该格墨迹应回到藏之前的值（%d → %d）" % [
			int(inks[last_index]), _ink(restored, _block_rects()[last_index])])


## 反向对照二：整条状态带移出画布 → 5 格墨迹全部归零。
func _probe_readout_band_shift() -> void:
	if _scene == null:
		return
	var bar: Control = _scene.find_child("StatusBar", true, false) as Control
	if not _h.check(bar != null, "场景应有 StatusBar 容器"):
		return

	var origin: Vector2 = bar.position
	bar.position = Vector2(origin.x, float(CANVAS.y))
	var moved: Image = (await _h.settle())["image"]
	var rects: Array = _block_rects()
	var leaked: int = 0
	for index: int in rects.size():
		leaked += _ink(moved, rects[index])
	_h.check(leaked == 0,
		"反向对照：整条带移出画布后 5 格墨迹应全部归零（实际 %d px）—— 它们确实画在这条带上" % leaked)
	bar.position = origin


## 反向对照三：把读数行的行距撑到 400（PET-80 前 200，随格宽 ×2），后面的格被挤出视口。
## 这条直接打在「5 格都画出来」上：量不出这个变化，就说明那 5 条断言只是在数节点。
func _probe_readout_row_overflow(viewport_rect: Rect2) -> void:
	var row: Control = _scene.find_child("ReadoutsRow", true, false) as Control
	if not _h.check(row != null, "场景应有读数行容器 ReadoutsRow"):
		return

	var origin: int = row.get_theme_constant(&"separation")
	row.add_theme_constant_override(&"separation", ROW_OVERFLOW_SEPARATION)
	var image: Image = (await _h.settle())["image"]
	var rects: Array = _block_rects()
	# 只看**横向**是否落在视口内：行距一撑开，横向装不下的格会被推到视口外。
	# 纵向不参与这条 —— 撑开后横向滚动条会占掉一点高度，纵向的位移是那件事的副产品，
	# 混进来会让这条断言看起来「连首格都没画」，读不出它真正要证的东西。
	var across: int = 0
	for index: int in rects.size():
		if rects[index].position.x >= viewport_rect.position.x and rects[index].end.x <= viewport_rect.end.x:
			across += 1
	var last_index: int = rects.size() - 1
	_h.check(across == 1,
		"反向对照：行距撑到 %d 后，横向仍落在读数视口（x %.0f–%.0f）内的格数应从 %d 掉到 1（实际 %d）" % [
			ROW_OVERFLOW_SEPARATION, viewport_rect.position.x, viewport_rect.end.x,
			READOUT_BLOCKS.size(), across])
	_h.check(not viewport_rect.encloses(rects[last_index]),
		"反向对照：末格应被挤出读数视口（末格右缘 %.0f，视口右缘 %.0f）" % [
			rects[last_index].end.x, viewport_rect.end.x])
	_h.check(_ink(image, rects[last_index]) == 0,
		"反向对照：被挤出视口的末格数不到墨迹（实际 %d px）" % _ink(image, rects[last_index]))
	row.add_theme_constant_override(&"separation", origin)

	var back: Image = (await _h.settle())["image"]
	var restored: Array = _block_rects()
	var again: int = 0
	for index: int in restored.size():
		if viewport_rect.encloses(restored[index]) and _ink(back, restored[index]) > 0:
			again += 1
	_h.check(again == READOUT_BLOCKS.size(),
		"还原行距后 %d 格应重新全部完整画出来（实际 %d 格）" % [READOUT_BLOCKS.size(), again])


## 相邻两格之间的那条竖直空带（行距）。
func _gap_between(left: Rect2, right: Rect2) -> Rect2:
	return Rect2(left.end.x, left.position.y, right.position.x - left.end.x, left.size.y)


func _is_blank(image: Image, rect: Rect2) -> bool:
	return rect.size.x > 0.0 and _ink(image, rect) == 0


## 5 个读数块的全局矩形，顺序同 READOUT_BLOCKS。找不到的格以空矩形占位，
## 于是「少了一格」会在数组长度上被本组第一条断言先抓住。
func _block_rects() -> Array:
	var rects: Array = []
	for block_name: String in READOUT_BLOCKS:
		var block: Control = _block(block_name)
		rects.append(block.get_global_rect() if block != null else Rect2())
	return rects


func _block(block_name: String) -> Control:
	if _scene == null:
		return null
	return _scene.find_child(block_name, true, false) as Control


func _readouts_rect() -> Rect2:
	if _scene == null:
		return Rect2()
	var readouts: Control = _scene.find_child("Readouts", true, false) as Control
	return readouts.get_global_rect() if readouts != null else Rect2()


## 一格内的「墨迹」：既不是状态带底色、也不是带上沿的像素 —— 即文字本身。
## 不写死字体色，于是改主题配色不会把这条断言变成假绿。
func _ink(image: Image, rect: Rect2) -> int:
	var extent: Vector2i = image.get_size()
	var from_x: int = clampi(int(rect.position.x), 0, extent.x)
	var to_x: int = clampi(int(rect.end.x), 0, extent.x)
	var from_y: int = clampi(int(rect.position.y), 0, extent.y)
	var to_y: int = clampi(int(rect.end.y), 0, extent.y)
	var ink: int = 0
	for y: int in range(from_y, to_y):
		for x: int in range(from_x, to_x):
			if not _h.near(image.get_pixel(x, y), _band_fill):
				ink += 1
	return ink


## 「第 y 行整行都是 wanted」+「上沿这一列恰好 EDGE_ROWS 个」。
## 分界行与反向对照后的新分界行共用同一条断言。
##
## PET-80：原来第二句只在 1 行的区间里数 1 个像素，恒真 —— 它当时只是「上沿厚 1px」这句话的
## 回声。上沿 ×2 成 EDGE_ROWS 行之后，这句改成在**整段上沿**里数 EDGE_ROWS 个，
## 于是它真的开始排除「上沿被画厚 / 画薄」：厚一行会数出 3，薄一行会数出 1。判别力只增不减。
func _assert_scanlines(image: Image, edge_row: int, label: String) -> void:
	_h.check(_h.count_row(image, edge_row, 0, CANVAS.x, _band_edge) == CANVAS.x,
		"%s：第 %d 行应是整条 %d px 的 NAVY_600" % [label, edge_row, CANVAS.x])
	_h.check(_h.count_col(image, CANVAS.x / 2, edge_row, edge_row + EDGE_ROWS, _band_edge) == EDGE_ROWS,
		"%s：任一列在上沿第 %d–%d 行应恰好 %d 个 NAVY_600（上沿厚 %d 逻辑像素）" % [
			label, edge_row, edge_row + EDGE_ROWS - 1, EDGE_ROWS, EDGE_ROWS])


## 把 combat.tscn 挂上画布、按 640×360 落一次布局，再取像素。
## 显式调 apply_layout_for 而不是依赖画布尺寸推断 —— 探针要证的是「布局画在哪」，
## 折叠与否这件事已由 test_combat.gd 单独覆盖，这里把它钉死在宽屏档。
func _open_scene() -> Image:
	var packed: PackedScene = load(SCENE_PATH)
	if not _h.check(packed != null, "combat.tscn 应能加载"):
		return null
	_h.set_canvas_size(CANVAS)
	_scene = packed.instantiate()
	_scene.theme = _theme
	_h.adopt(_scene)
	await _h.settle()
	_scene.size = VIEWPORT
	_scene.call(&"apply_layout_for", VIEWPORT)
	return (await _h.settle())["image"]


## 整行铺满判据色的那些行号 —— 即画面上**横贯全宽的结构线**。
## 「别处不得再有同色结构线」这条判据靠它：卡面 / 图标那类小色块最多几十像素连续
## （PET-80 后单张卡面最多 48px），凑不满一整行 640px，于是它们不会污染这条断言，
## 而一条真的漏出来的分界线一定跑不掉。
func _full_width_rows(image: Image, wanted: Color) -> Array[int]:
	var rows: Array[int] = []
	for y: int in image.get_size().y:
		if _h.count_row(image, y, 0, image.get_size().x, wanted) == image.get_size().x:
			rows.append(y)
	return rows


## 逐行累计判据色像素数。[from_y, to_y) 半开区间。
func _count_range(image: Image, from_y: int, to_y: int, wanted: Color) -> int:
	var total: int = 0
	for y: int in range(from_y, to_y):
		total += _h.count_row(image, y, 0, image.get_size().x, wanted)
	return total
