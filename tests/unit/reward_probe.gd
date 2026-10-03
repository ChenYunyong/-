## reward_probe.gd
## 职责：REWARD 界面的像素取证（09 §4）—— 证明 06 §9 的「3 个选项」是**真的画成**
##       三列（宽屏）/ 三行（窄屏）的选项卡，且每张卡片的图标真的上了 06 §4 的类型色，
##       而不是「字段等于多少」。
## 所属系统：tests（09 §4 像素探针的 S1-09 用例模块）
## 依赖：Palette, assets/ui/theme_main.tres, scenes/reward/reward.tscn
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得写任何字面色值 —— 判据一律取自 Palette。
##
## 拆分理由：聚合入口 run_render_probes.gd 已近 02 §4 的 300 行上限，
## 按 09 §4 v0.1.3 的先例把 S1-09 的用例拆成模块，聚合入口只留一次调用。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   反向对照一 —— 藏掉 Card1，第 100 行上它的两条描边必须连同它的图标一起消失，
##                 剩下两列的 x 一个都不许动。
##   反向对照二 —— 把卡片区整体右移 4px，六条描边必须整体跟着移 4px。
##                 量不到这个位移，就说明上面那些断言只是在「某处找深色线」，
##                 证明不了它们落在 8 / 103 / 112 / 207 / 216 / 311 这几个位置上。
##
## 分工：本探针只量**真实渲染矩形**。布局算得对不对由 tests/unit/test_reward.gd 覆盖，
## 交互（选中后回 PREPARATION、不自动推进）由 tests/integration/reward_smoke.gd 覆盖。

extends RefCounted

const SCENE_PATH: String = "res://scenes/reward/reward.tscn"

## 画布 = 06 §1 的 320×180 基准（宽屏）与 180×320（窄屏），与布局常量同一坐标系。
const WIDE: Vector2i = Vector2i(320, 180)
const NARROW: Vector2i = Vector2i(180, 320)

## 卡片描边的扫描窗口：避开最外圈的面板框。外框是 PanelFrame（3px BROWN_500 描边 + BROWN_600 填充）
## 再叠 1px PanelHighlight 左高光，所以 [4, 316) 里除了卡片描边不该有第二种 BROWN_600。
## 这两条边界由 _probe_wide() 末尾的断言钉住 —— 窗口一旦挪进外框，那两条会先红。
const SCAN_LEFT: int = 4
const SCAN_RIGHT: int = 316
const SCAN_TOP: int = 4
const SCAN_BOTTOM: int = 316

## 06 §9 三个选项位在 320×180 下的**实测**描边坐标（左右各一条 × 三列）。
## 刻意写死而不是由布局公式现算：探针要证的正是「公式的结果真的落在了这几个像素上」。
const WIDE_BORDER_X: Array[int] = [8, 103, 112, 207, 216, 311]
## 三列卡片的上下描边所在行（32 上沿 / 171 下沿）。
const WIDE_CARD_TOP: int = 32
const WIDE_CARD_BOTTOM: int = 171
## 扫描用的行：落在卡片纵向中部，且避开文字基线密集处。
const WIDE_SCAN_ROW: int = 100

## 180×320 竖屏下三个选项位的**实测**描边坐标（上下各一条 × 三行）。
const NARROW_BORDER_Y: Array[int] = [32, 119, 128, 215, 224, 311]
const NARROW_CARD_LEFT: int = 8
const NARROW_CARD_RIGHT: int = 171
const NARROW_SCAN_COL: int = 100

## 06 §2.2：标题栏高 16px，底部 1px GOLD_600 分隔线。上沿在 y=8，故金线落在 y=23。
const TITLE_GOLD_ROW: int = 23
const WIDE_TITLE_GOLD: int = 304
const NARROW_TITLE_GOLD: int = 164

## 06 §9 的图标落点尺寸（卡片内的一块实心方色），以及三张卡片各自的类型色。
const ICON_SIZE: int = 16
const ICON_AREA: int = ICON_SIZE * ICON_SIZE

## 反向对照的位移量。
const SHIFT: float = 4.0

var _h: RefCounted = null
var _tree: SceneTree = null
var _theme: Theme = null
var _scene: Control = null
var _border: Color = Color.BLACK
var _gold: Color = Color.BLACK
var _type_colors: Array[Color] = []


## 由聚合入口调用。harness 与 tree 都是借来的 —— 计数直接记在同一个 harness 上，
## 于是退出码与总计数不必两处维护。
func run(tree: SceneTree, harness: RefCounted, theme: Theme) -> void:
	_tree = tree
	_h = harness
	_theme = theme
	_border = Palette.get_color(Palette.Key.BROWN_600)
	_gold = Palette.get_color(Palette.Key.GOLD_600)
	_type_colors = [
		Palette.get_color(Palette.Key.GOLD_400),
		Palette.get_color(Palette.Key.BLUE_400),
		Palette.get_color(Palette.Key.ORANGE_500),
	]

	print("")
	print("=== 组 10：REWARD 三列 / 竖排选项卡与类型图标（06 §9 像素取证）===")
	print("  判据色：卡片描边=BROWN_600%s 标题栏分隔线=GOLD_600%s 类型色=%s/%s/%s" % [
		_h.color_text(_border), _h.color_text(_gold),
		_h.color_text(_type_colors[0]), _h.color_text(_type_colors[1]), _h.color_text(_type_colors[2]),
	])
	await _probe_wide()
	await _probe_icons()
	await _probe_narrow()
	await _probe_reverse()


## 组 10a：320×180 下三列横排 —— 六条竖描边、每条贯穿整张卡片、列间留 8px 空隙、
## 两端各留 8px 安全边距，标题栏分隔线横贯 304px。
func _probe_wide() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return

	var hits: Array[int] = _row_hits(image, WIDE_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border)
	_h.check(hits == WIDE_BORDER_X,
		"第 %d 行应恰好在这 6 个 x 上是 BROWN_600：%s（实际 %s）" % [WIDE_SCAN_ROW, WIDE_BORDER_X, hits])

	# 每条竖描边贯穿整张卡片：两列之间那 8px 空隙里一个描边像素都没有。
	for index: int in 3:
		var left: int = WIDE_BORDER_X[index * 2]
		var right: int = WIDE_BORDER_X[index * 2 + 1]
		_h.check(right - left + 1 == 96, "第 %d 列的内宽应为 96px（实际 %d）" % [index + 1, right - left + 1])
		_h.check(_h.count_col(image, left, WIDE_CARD_TOP, WIDE_CARD_BOTTOM + 1, _border) == 140,
			"第 %d 列左缘 x=%d 应整列是描边（140px）" % [index + 1, left])
		_h.check(_h.count_row(image, WIDE_CARD_TOP, left, right + 1, _border) == right - left + 1,
			"第 %d 列上沿 y=%d 应整行是描边" % [index + 1, WIDE_CARD_TOP])
		_h.check(_h.count_row(image, WIDE_CARD_BOTTOM, left, right + 1, _border) == right - left + 1,
			"第 %d 列下沿 y=%d 应整行是描边" % [index + 1, WIDE_CARD_BOTTOM])
	# 三列等宽、间距 8、两端各留 8 —— 由描边坐标本身推出，不是另抄一份尺寸。
	_h.check(WIDE_BORDER_X[2] - WIDE_BORDER_X[1] - 1 == 8, "第 1、2 列之间的空隙应为 8px")
	_h.check(WIDE_BORDER_X[4] - WIDE_BORDER_X[3] - 1 == 8, "第 2、3 列之间的空隙应为 8px")
	_h.check(WIDE_BORDER_X[0] == 8, "首列左安全边距应为 8px")
	_h.check(WIDE.x - 1 - WIDE_BORDER_X[5] == 8, "末列右安全边距应为 8px")
	_h.check(_h.count_row(image, WIDE_SCAN_ROW, WIDE_BORDER_X[1] + 1, WIDE_BORDER_X[2], _border) == 0,
		"列间空隙里不得有描边（否则「三列」就成了一整块）")

	# 标题栏分隔线：整条 304px，且只在第 23 行 —— 上下各一行都不许有。
	_h.check(_h.count_row(image, TITLE_GOLD_ROW, 0, WIDE.x, _gold) == WIDE_TITLE_GOLD,
		"标题栏分隔线应是第 %d 行上的整条 %dpx" % [TITLE_GOLD_ROW, WIDE_TITLE_GOLD])
	_h.check(_h.count_row(image, TITLE_GOLD_ROW - 1, 0, WIDE.x, _gold) == 0,
		"第 %d 行不得有金像素（分隔线厚 1px）" % (TITLE_GOLD_ROW - 1))
	_h.check(_h.count_row(image, TITLE_GOLD_ROW + 1, 0, WIDE.x, _gold) == 0,
		"第 %d 行不得有金像素（标题栏到此为止）" % (TITLE_GOLD_ROW + 1))

	# 钉住扫描窗口的两条边界：窗口外（最外圈面板框那一带）不得混进卡片描边色，
	# 否则上面那条「恰好 6 个」随时可能被外框的像素顶掉而失去判别力。
	_h.check(_h.count_row(image, WIDE_SCAN_ROW, 0, SCAN_LEFT, _border) == 0,
		"扫描窗口左侧（x< %d）不得有卡片描边色" % SCAN_LEFT)
	_h.check(_h.count_row(image, WIDE_SCAN_ROW, SCAN_RIGHT, WIDE.x, _border) == 0,
		"扫描窗口右侧（x>= %d）不得有卡片描边色" % SCAN_RIGHT)


## 组 10b：06 §4 的类型标识色 —— 三张卡片各有一块 16×16 的实心图标，
## 颜色分别是 CORE / FUNCTION / WEAPON 的类型色，且各自落在**自己那张卡**的矩形内。
##
## 这一组是「图标」这个展示位唯一能被像素证明的部分：它在不在、多大、什么色、在谁的格子里。
func _probe_icons() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return
	for index: int in 3:
		var wanted: Color = _type_colors[index]
		var found: Dictionary = _measure(image, wanted)
		var box: Rect2i = found["box"]
		_h.check(int(found["count"]) == ICON_AREA,
			"第 %d 张卡的图标应恰好 %d 个判据像素（实际 %d）—— 图标色只许出现在图标上" % [
				index + 1, ICON_AREA, int(found["count"])])
		_h.check(box.size == Vector2i(ICON_SIZE, ICON_SIZE),
			"第 %d 张卡的图标应是 %d×%d 的实心块（实际 %s）" % [index + 1, ICON_SIZE, ICON_SIZE, str(box.size)])
		var cell: Rect2i = Rect2i(WIDE_BORDER_X[index * 2], WIDE_CARD_TOP,
			WIDE_BORDER_X[index * 2 + 1] - WIDE_BORDER_X[index * 2] + 1, 140)
		_h.check(cell.encloses(box),
			"第 %d 张卡的图标应落在该卡矩形 %s 内（实际 %s）" % [index + 1, str(cell), str(box)])


## 组 10c：180×320 竖屏下三行竖排 —— 六条横描边、同处一列、标题栏随可用宽收窄。
func _probe_narrow() -> void:
	var image: Image = await _open_scene(NARROW)
	if image == null:
		return

	var hits: Array[int] = _col_hits(image, NARROW_SCAN_COL, SCAN_TOP, SCAN_BOTTOM, _border)
	_h.check(hits == NARROW_BORDER_Y,
		"第 %d 列应恰好在这 6 个 y 上是 BROWN_600：%s（实际 %s）" % [NARROW_SCAN_COL, NARROW_BORDER_Y, hits])

	# 三行同处一列：左缘 x=8 整列是描边（三段各 88px），右缘 x=171 同理。
	_h.check(_h.count_col(image, NARROW_CARD_LEFT, WIDE_CARD_TOP, NARROW_BORDER_Y[5] + 1, _border) == 264,
		"折叠后三张卡片的左缘应在同一条 x=%d 上（三段各 88px）" % NARROW_CARD_LEFT)
	_h.check(_h.count_row(image, 76, SCAN_LEFT, 176, _border) == 2,
		"折叠后第 76 行应只有左右两条描边（x=%d / x=%d）" % [NARROW_CARD_LEFT, NARROW_CARD_RIGHT])
	_h.check(NARROW_CARD_RIGHT - NARROW_CARD_LEFT + 1 == 164, "折叠后卡片应铺满可用宽（164px）")
	for index: int in 3:
		var top: int = NARROW_BORDER_Y[index * 2]
		var bottom: int = NARROW_BORDER_Y[index * 2 + 1]
		_h.check(bottom - top + 1 == 88, "第 %d 行卡片的高应为 88px（实际 %d）" % [index + 1, bottom - top + 1])
	_h.check(NARROW_BORDER_Y[5] == NARROW.y - 9, "第三张卡片应贴到底部安全线（下沿 %d）" % NARROW_BORDER_Y[5])

	_h.check(_h.count_row(image, TITLE_GOLD_ROW, 0, NARROW.x, _gold) == NARROW_TITLE_GOLD,
		"标题栏分隔线应随可用宽收窄到 %dpx" % NARROW_TITLE_GOLD)


## 反向对照一 / 二：证明上面数到的像素确实来自卡片本身、且位置由布局决定。
func _probe_reverse() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return
	var card: Node = _scene.find_child("Card1", true, false)
	if not _h.check(card != null, "场景应有 Card1"):
		return
	card.set(&"visible", false)
	var hidden: Image = (await _h.settle())["image"]
	if hidden == null:
		return
	_h.check(_row_hits(hidden, WIDE_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border)
			== [WIDE_BORDER_X[0], WIDE_BORDER_X[1], WIDE_BORDER_X[4], WIDE_BORDER_X[5]],
		"反向对照：藏掉 Card1 后应只剩第 1、3 两列的描边")
	_h.check(_measure(hidden, _type_colors[1])["count"] == 0,
		"反向对照：藏掉 Card1 后蓝色图标应一并消失（说明那块图标真的属于这张卡）")
	_h.check(_measure(hidden, _type_colors[0])["count"] == ICON_AREA
			and _measure(hidden, _type_colors[2])["count"] == ICON_AREA,
		"反向对照：藏掉 Card1 不得动到另外两张卡的图标")

	# 反向对照二：整体右移 4px，六条描边必须整体跟着走。
	image = await _open_scene(WIDE)
	if image == null:
		return
	var area: Control = _scene.find_child("CardsArea", true, false) as Control
	if not _h.check(area != null, "场景应有 CardsArea"):
		return
	area.position += Vector2(SHIFT, 0.0)
	var shifted: Image = (await _h.settle())["image"]
	if shifted == null:
		return
	var moved: Array[int] = []
	for column: int in WIDE_BORDER_X:
		moved.append(column + int(SHIFT))
	_h.check(_row_hits(shifted, WIDE_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border) == moved,
		"反向对照：卡片区右移 %dpx 后六条描边应整体跟着移（期望 %s）" % [int(SHIFT), moved])


## 把 reward.tscn 挂上画布、按给定画布尺寸落一次布局，再取像素。
## 显式调 apply_layout_for 而不是依赖画布尺寸推断 —— 探针要证的是「布局画在哪」，
## 折叠与否这件事已由 test_reward.gd 与 reward_smoke.gd 覆盖。
func _open_scene(canvas: Vector2i) -> Image:
	var packed: PackedScene = load(SCENE_PATH)
	if not _h.check(packed != null, "reward.tscn 应能加载"):
		return null
	_h.reset()
	_h.set_canvas_size(canvas)
	_scene = packed.instantiate()
	_scene.theme = _theme
	_h.adopt(_scene)
	await _h.settle()
	_scene.size = Vector2(canvas)
	_scene.call(&"apply_layout_for", Vector2(canvas))
	return (await _h.settle())["image"]


func _row_hits(image: Image, y: int, from_x: int, to_x: int, wanted: Color) -> Array[int]:
	var hits: Array[int] = []
	for x: int in range(from_x, to_x):
		if _h.near(image.get_pixel(x, y), wanted):
			hits.append(x)
	return hits


func _col_hits(image: Image, x: int, from_y: int, to_y: int, wanted: Color) -> Array[int]:
	var hits: Array[int] = []
	for y: int in range(from_y, to_y):
		if _h.near(image.get_pixel(x, y), wanted):
			hits.append(y)
	return hits


## 全图扫一遍判据色，同时给出计数与包围盒 —— 两者一起才能说清「是不是一块 16×16 的实心块」。
func _measure(image: Image, wanted: Color) -> Dictionary:
	var extent: Vector2i = image.get_size()
	var count: int = 0
	var min_x: int = extent.x
	var min_y: int = extent.y
	var max_x: int = -1
	var max_y: int = -1
	for y: int in extent.y:
		for x: int in extent.x:
			if not _h.near(image.get_pixel(x, y), wanted):
				continue
			count += 1
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	var box: Rect2i = Rect2i()
	if count > 0:
		box = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	return {"count": count, "box": box}
