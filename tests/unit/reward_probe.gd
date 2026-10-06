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
##   反向对照一 —— 藏掉 Card1，第 200 行上它的两条描边必须连同它的图标一起消失，
##                 剩下两列的 x 一个都不许动。
##   反向对照二 —— 把卡片区整体右移 8px，六条描边必须整体跟着移 8px。
##                 量不到这个位移，就说明上面那些断言只是在「某处找深色线」，
##                 证明不了它们落在 16 / 207 / 224 / 415 / 432 / 623 这几个位置上。
##   反向对照三 —— 藏掉某张卡的 PanelShadow 叠层：那张卡的右下环带必须整体归零，
##                 而它自己的 BROWN_600 描边仍在（06 §9.1 v0.1.12：卡片自身不带阴影）。
##
## 分工：本探针只量**真实渲染矩形**。布局算得对不对由 tests/unit/test_reward.gd 覆盖，
## 交互（选中后回 PREPARATION、不自动推进）由 tests/integration/reward_smoke.gd 覆盖。

extends RefCounted

const SCENE_PATH: String = "res://scenes/reward/reward.tscn"

## 画布 = 06 §1 的 640×360 基准（宽屏，PET-80 前 320×180）与 360×640（窄屏，前 180×320），
## 与布局常量同一坐标系。
const WIDE: Vector2i = Vector2i(640, 360)
const NARROW: Vector2i = Vector2i(360, 640)

## 卡片描边的扫描窗口：避开最外圈的面板框。外框是 PanelFrame（木质描边 + BROWN_600 内带）
## 再叠 GOLD_200 左高光，所以 [8, 632) 里除了卡片描边不该有第二种 BROWN_600。
## 这两条边界由 _probe_wide() 末尾的断言钉住 —— 窗口一旦挪进外框，那两条会先红。
##
## PET-80：窗口是**距画布边缘的内缩量**（各 8 逻辑像素），随基准画布 ×2：4/316 → 8/632。
const SCAN_LEFT: int = 8
const SCAN_RIGHT: int = 632

## PET-77：外框换成已批准切片后，窗口外那几列里也有 BROWN_600 —— 那是**框自己**的木质带。
## 逐像素读数（`ui_panel_frame_main_96x64`）：左带 4px = x0 BROWN_500 / x1..x2 BROWN_600 / x3 GOLD_200 高光；
## 右带 3px = 倒数第 3、2 列 BROWN_600 / 最后一列 BROWN_500。窗口边界那两条断言据此改钉
## 「只许这两条、且在此位置」。
##
## PET-80：这几列是九宫格切片的 `texture_margin_*`（**纹素**读数，本卡不动 assets/**），
## 故它们**贴边**不变：左带仍是 x0..x3（FRAME_LEFT_BAND 原样），右带仍贴右缘 ——
## 画布宽 320 → 640 后，右带从 x317/x318 变成 x637/x638。
const FRAME_LEFT_BAND: Array[int] = [1, 2]
const FRAME_RIGHT_BAND: Array[int] = [637, 638]
const SCAN_TOP: int = 8
const SCAN_BOTTOM: int = 632

## 06 §9 三个选项位在 640×360 下的**实测**描边坐标（左右各一条 × 三列）。
## 刻意写死而不是由布局公式现算：探针要证的正是「公式的结果真的落在了这几个像素上」。
## PET-80：§9 的实测读数逐项 ×2（8→16 / 103→207 / 112→224 / 207→415 / 216→432 / 311→623）。
## 注意右缘是 2·103+1 = 207（不是 206）：一条边占的是**纹素**，整条边随坐标系 ×2 后
## 末列由 2i 变成 2i+1，正是矩形 [16, 208) 的最后一列。
const WIDE_BORDER_X: Array[int] = [16, 207, 224, 415, 432, 623]
## 三列卡片的上下描边所在行（64 上沿 / 343 下沿，PET-80 前 32 / 171）。
const WIDE_CARD_TOP: int = 64
const WIDE_CARD_BOTTOM: int = 343
## 扫描用的行：落在卡片纵向中部，且避开文字基线密集处。
const WIDE_SCAN_ROW: int = 200

## 360×640 竖屏下三个选项位的**实测**描边坐标（上下各一条 × 三行）。
## PET-80：逐项 ×2（32→64 / 119→239 / 128→256 / 215→431 / 224→448 / 311→623）。
## 同样地，末条边取 2i+1。
const NARROW_BORDER_Y: Array[int] = [64, 239, 256, 431, 448, 623]
const NARROW_CARD_LEFT: int = 16
const NARROW_CARD_RIGHT: int = 343
const NARROW_SCAN_COL: int = 200

## 06 §2.2：标题栏高 32px（PET-80 前 16），底部 GOLD_600 分隔线。上沿在 y=16（前 8），
## 故金线落在标题栏最后一行 y=47（前 23）。
##
## PET-80：这条线是 PanelTitleBar 变体 StyleBoxFlat 的 `border_width_bottom`，取自
## PaletteTheme.BORDER_WIDTH —— 代码画的**逻辑**像素（不是九宫格切片的纹素边距），
## 故厚度随坐标系 ×2：1 行 → 2 行，占第 46–47 行。判别力不变：上下各一行仍必须是零。
const TITLE_GOLD_ROW: int = 47
const TITLE_GOLD_ROWS: int = 2
const WIDE_TITLE_GOLD: int = 608
const NARROW_TITLE_GOLD: int = 328

## 06 §9 的图标落点尺寸（卡片内的一块实心方色），以及三张卡片各自的类型色。
## 取自 `reward_card.tscn` 的 `Icon.custom_minimum_size`：16×16 → 32×32。
const ICON_SIZE: int = 32
const ICON_AREA: int = ICON_SIZE * ICON_SIZE

## 06 §1 的安全边距。06 §9.1 v0.1.12：卡片是**浮动的次级面板**，右下各外扩 SHADOW_PX 像素
## 的 NAVY_900 硬阴影（与 RESULT 读数区同款）。阴影**不计入**安全区 —— 卡片矩形仍停在
## 「视口 - 16」，阴影另占安全边距的头 SHADOW_PX 列 / 行。这与 RESULT 是同一口径：
## `result_probe.gd` 里读数区矩形右缘 624 = 640 - 16，阴影列同样是 624。
## 卡片矩形若为阴影让位缩 1px，下面两条会当场红。
const SAFE_INSET: int = 16
## 末张卡片（宽屏的第三列 / 窄屏的第三行）矩形的右缘与下缘，即安全线本身。
const WIDE_CARD_RIGHT_EDGE: int = 624
const WIDE_CARD_BOTTOM_EDGE: int = 344
const NARROW_CARD_RIGHT_EDGE: int = 344
const NARROW_CARD_BOTTOM_EDGE: int = 624

## 反向对照的位移量。它是一条**长度**，故随坐标系 ×2（PET-80 前 4）。
const SHIFT: float = 8.0
## 硬阴影的厚度（**逻辑**像素）。PET-80：1 → 2。
##
## 它来自 `PaletteTheme._build_panel_shadow()` 的 `border_width_right/bottom`，
## 取值是 `BORDER_WIDTH` —— 代码画的逻辑像素（**不是**九宫格切片的纹素边距），故随坐标系 ×2。
## 于是阴影从「右下各 1 列 / 行」变成「各 2 列 / 行」，环带像素数由 w+h+1 变成 2(w+h+2)。
## 这张卡自己的 BROWN_600 描边**不跟着变**：它来自 PanelSecondary 的 StyleBoxTexture 边距
## （THIN_FRAME_MARGIN_* = 2 纹素，本卡不动 assets/**），仍是 1 逻辑像素。
const SHADOW_PX: int = 2

var _h: RefCounted = null
var _tree: SceneTree = null
var _theme: Theme = null
var _scene: Control = null
var _border: Color = Color.BLACK
var _gold: Color = Color.BLACK
var _shadow: Color = Color.BLACK
var _type_colors: Array[Color] = []


## 由聚合入口调用。harness 与 tree 都是借来的 —— 计数直接记在同一个 harness 上，
## 于是退出码与总计数不必两处维护。
func run(tree: SceneTree, harness: RefCounted, theme: Theme) -> void:
	_tree = tree
	_h = harness
	_theme = theme
	_border = Palette.get_color(Palette.Key.BROWN_600)
	_gold = Palette.get_color(Palette.Key.GOLD_600)
	_shadow = Palette.get_color(Palette.Key.NAVY_900)
	_type_colors = [
		Palette.get_color(Palette.Key.GOLD_400),
		Palette.get_color(Palette.Key.BLUE_400),
		Palette.get_color(Palette.Key.ORANGE_500),
	]

	print("")
	print("=== 组 10：REWARD 三列 / 竖排选项卡与类型图标（06 §9 像素取证）===")
	print("  判据色：卡片描边=BROWN_600%s 标题栏分隔线=GOLD_600%s 阴影=NAVY_900%s 类型色=%s/%s/%s" % [
		_h.color_text(_border), _h.color_text(_gold), _h.color_text(_shadow),
		_h.color_text(_type_colors[0]), _h.color_text(_type_colors[1]), _h.color_text(_type_colors[2]),
	])
	await _probe_wide()
	await _probe_icons()
	await _probe_narrow()
	await _probe_shadow()
	await _probe_reverse()


## 组 10a：640×360 下三列横排 —— 六条竖描边、每条贯穿整张卡片、列间留 16px 空隙、
## 两端各留 16px 安全边距，标题栏分隔线横贯 608px。（PET-80 前：320×180 / 8px / 304px。）
func _probe_wide() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return

	var hits: Array[int] = _row_hits(image, WIDE_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border)
	_h.check(hits == WIDE_BORDER_X,
		"第 %d 行应恰好在这 6 个 x 上是 BROWN_600：%s（实际 %s）" % [WIDE_SCAN_ROW, WIDE_BORDER_X, hits])

	# 每条竖描边贯穿整张卡片：两列之间那 16px 空隙里一个描边像素都没有。
	for index: int in 3:
		var left: int = WIDE_BORDER_X[index * 2]
		var right: int = WIDE_BORDER_X[index * 2 + 1]
		_h.check(right - left + 1 == 192, "第 %d 列的内宽应为 192px（实际 %d）" % [index + 1, right - left + 1])
		_h.check(_h.count_col(image, left, WIDE_CARD_TOP, WIDE_CARD_BOTTOM + 1, _border) == 280,
			"第 %d 列左缘 x=%d 应整列是描边（280px）" % [index + 1, left])
		_h.check(_h.count_row(image, WIDE_CARD_TOP, left, right + 1, _border) == right - left + 1,
			"第 %d 列上沿 y=%d 应整行是描边" % [index + 1, WIDE_CARD_TOP])
		_h.check(_h.count_row(image, WIDE_CARD_BOTTOM, left, right + 1, _border) == right - left + 1,
			"第 %d 列下沿 y=%d 应整行是描边" % [index + 1, WIDE_CARD_BOTTOM])
	# 三列等宽、间距 16、两端各留 16 —— 由描边坐标本身推出，不是另抄一份尺寸。
	_h.check(WIDE_BORDER_X[2] - WIDE_BORDER_X[1] - 1 == 16, "第 1、2 列之间的空隙应为 16px")
	_h.check(WIDE_BORDER_X[4] - WIDE_BORDER_X[3] - 1 == 16, "第 2、3 列之间的空隙应为 16px")
	_h.check(WIDE_BORDER_X[0] == 16, "首列左安全边距应为 16px")
	_h.check(WIDE.x - 1 - WIDE_BORDER_X[5] == 16, "末列右安全边距应为 16px")
	_h.check(_h.count_row(image, WIDE_SCAN_ROW, WIDE_BORDER_X[1] + 1, WIDE_BORDER_X[2], _border) == 0,
		"列间空隙里不得有描边（否则「三列」就成了一整块）")

	# 标题栏分隔线：整条 608px，且只占标题栏最后 TITLE_GOLD_ROWS 行 —— 再往上、再往下都不许有。
	# PET-80：线厚 1 → 2（BORDER_WIDTH ×2），判别力不变（上下各一行仍必须是零）。
	for offset: int in TITLE_GOLD_ROWS:
		_h.check(_h.count_row(image, TITLE_GOLD_ROW - offset, 0, WIDE.x, _gold) == WIDE_TITLE_GOLD,
			"标题栏分隔线第 %d 行应是整条 %dpx" % [TITLE_GOLD_ROW - offset, WIDE_TITLE_GOLD])
	_h.check(_h.count_row(image, TITLE_GOLD_ROW - TITLE_GOLD_ROWS, 0, WIDE.x, _gold) == 0,
		"第 %d 行不得有金像素（分隔线只占 %d 行）" % [TITLE_GOLD_ROW - TITLE_GOLD_ROWS, TITLE_GOLD_ROWS])
	_h.check(_h.count_row(image, TITLE_GOLD_ROW + 1, 0, WIDE.x, _gold) == 0,
		"第 %d 行不得有金像素（标题栏到此为止）" % (TITLE_GOLD_ROW + 1))

	# 钉住扫描窗口的两条边界：窗口外（最外圈面板框那一带）只许出现**外框切片自己**那两条
	# BROWN_600 木质带，且必须落在固定列上 —— 否则上面那条「恰好 6 个」随时可能被外框顶掉。
	#
	# 原来钉：窗口外命中 0（旧外框是 StyleBoxFlat：3px 描边 + BROWN_500 填充，
	#         而窗口外那几列恰好落在填充上，所以当时确实是 0）。
	# 现在钉：命中数 == 2，且命中列 == 外框自带的那两条（左 x1/x2、右 x637/x638）。
	# 为什么是同一件事：这条要证的是「窗口外那几列只属于外框，不掺本界面自己的任何描边」。
	#   外框改用已批准切片后，切片在描边内侧多了一条 BROWN_600（旧 StyleBoxFlat 那里是填充），
	#   于是「0」这个数字不再成立；改钉「恰好 2 且位置固定」把同一件事证得更死 ——
	#   数量或位置任一变化（多一条、挪一列、本界面有描边漏出窗口）都会转红。
	#   PET-80：切片边距是纹素读数，故这 3 列**贴边**不动，只是画布宽了、右带整体右移了 320 列。
	var left_out: Array[int] = _row_hits(image, WIDE_SCAN_ROW, 0, SCAN_LEFT, _border)
	_h.check(left_out == FRAME_LEFT_BAND,
		"扫描窗口左侧（x< %d）应恰好是外框自带的那两条木质带 %s（实际 %s）" % [
			SCAN_LEFT, FRAME_LEFT_BAND, left_out])
	var right_out: Array[int] = _row_hits(image, WIDE_SCAN_ROW, SCAN_RIGHT, WIDE.x, _border)
	_h.check(right_out == FRAME_RIGHT_BAND,
		"扫描窗口右侧（x>= %d）应恰好是外框自带的那两条木质带 %s（实际 %s）" % [
			SCAN_RIGHT, FRAME_RIGHT_BAND, right_out])


## 组 10b：06 §4 的类型标识色 —— 三张卡片各有一块 32×32 的实心图标，
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
			WIDE_BORDER_X[index * 2 + 1] - WIDE_BORDER_X[index * 2] + 1, 280)
		_h.check(cell.encloses(box),
			"第 %d 张卡的图标应落在该卡矩形 %s 内（实际 %s）" % [index + 1, str(cell), str(box)])


## 组 10c：360×640 竖屏下三行竖排 —— 六条横描边、同处一列、标题栏随可用宽收窄。
func _probe_narrow() -> void:
	var image: Image = await _open_scene(NARROW)
	if image == null:
		return

	var hits: Array[int] = _col_hits(image, NARROW_SCAN_COL, SCAN_TOP, SCAN_BOTTOM, _border)
	_h.check(hits == NARROW_BORDER_Y,
		"第 %d 列应恰好在这 6 个 y 上是 BROWN_600：%s（实际 %s）" % [NARROW_SCAN_COL, NARROW_BORDER_Y, hits])

	# 三行同处一列：左缘 x=16 整列是描边（三段各 176px，中间隔 16px 空隙）。
	# PET-80：三段总长 88×3 → 176×3，跨度内的两段空隙 8×2 → 16×2，故 264 → 528。
	_h.check(_h.count_col(image, NARROW_CARD_LEFT, WIDE_CARD_TOP, NARROW_BORDER_Y[5] + 1, _border) == 528,
		"折叠后三张卡片的左缘应在同一条 x=%d 上（三段各 176px）" % NARROW_CARD_LEFT)
	# 第 152 行落在首张卡纵向中部（PET-80 前 76），此列横切过去只该碰到左右两条描边。
	_h.check(_h.count_row(image, 152, SCAN_LEFT, 352, _border) == 2,
		"折叠后第 152 行应只有左右两条描边（x=%d / x=%d）" % [NARROW_CARD_LEFT, NARROW_CARD_RIGHT])
	_h.check(NARROW_CARD_RIGHT - NARROW_CARD_LEFT + 1 == 328, "折叠后卡片应铺满可用宽（328px）")
	for index: int in 3:
		var top: int = NARROW_BORDER_Y[index * 2]
		var bottom: int = NARROW_BORDER_Y[index * 2 + 1]
		_h.check(bottom - top + 1 == 176, "第 %d 行卡片的高应为 176px（实际 %d）" % [index + 1, bottom - top + 1])
	_h.check(NARROW_BORDER_Y[5] == NARROW.y - SAFE_INSET - 1,
		"第三张卡片应贴到底部安全线（下沿 %d）" % NARROW_BORDER_Y[5])

	_h.check(_h.count_row(image, TITLE_GOLD_ROW, 0, NARROW.x, _gold) == NARROW_TITLE_GOLD,
		"标题栏分隔线应随可用宽收窄到 %dpx" % NARROW_TITLE_GOLD)


## 组 10d：06 §9.1 v0.1.12 —— 卡片是**浮动的次级面板**，右下各外扩 NAVY_900 硬阴影
## （做法与 RESULT 读数区同款，见 result_probe.gd 的 _assert_readout_shadow）。
##
## 三条一起才说清「真的画成了」：
##   ① 三张卡各自的右下环带数与几何一致（PET-80 后 2(w + h + 2)，前 w + h + 1），上 / 左一个都没有；
##   ② 整幅画面的 NAVY_900 **恰好**是这三条环带之和 —— 多一个像素就说明阴影漫进了卡片，
##      于是「不覆盖文字」由像素总数钉死，而不是靠「配置项写了 draw_center = false」宣称；
##   ③ 阴影落在安全边距里，卡片矩形不为它让位 —— 与 RESULT 同口径。
func _probe_shadow() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return
	var ring: int = 0
	for index: int in 3:
		ring += _assert_card_shadow(image, WIDE_BORDER_X[index * 2], WIDE_CARD_TOP,
			WIDE_BORDER_X[index * 2 + 1], WIDE_CARD_BOTTOM, "640×360 第 %d 张卡" % (index + 1))
	_check_shadow_inset(image, WIDE_BORDER_X[4], WIDE_BORDER_X[5], WIDE_CARD_TOP, WIDE_CARD_BOTTOM,
		WIDE, "640×360")
	_assert_shadow_total(image, ring, "640×360")

	image = await _open_scene(NARROW)
	if image == null:
		return
	ring = 0
	for index: int in 3:
		ring += _assert_card_shadow(image, NARROW_CARD_LEFT, NARROW_BORDER_Y[index * 2],
			NARROW_CARD_RIGHT, NARROW_BORDER_Y[index * 2 + 1], "360×640 第 %d 张卡" % (index + 1))
	_check_shadow_inset(image, NARROW_CARD_LEFT, NARROW_CARD_RIGHT, NARROW_BORDER_Y[4],
		NARROW_BORDER_Y[5], NARROW, "360×640")
	_assert_shadow_total(image, ring, "360×640")

	# 反向对照三：藏掉 Card1 的 Shadow 叠层 —— 那张卡的右下环带必须整体归零，另两张一个像素不动。
	# 量不到这个「少 2(w+h+2)」，上面那条总数断言就只是碰巧对上。
	image = await _open_scene(WIDE)
	if image == null:
		return
	var card: Node = _scene.find_child("Card1", true, false)
	var layer: Node = (card.find_child("Shadow", true, false) if card != null else null)
	if not _h.check(layer != null, "Card1 应有 Shadow 叠层"):
		return
	layer.set(&"visible", false)
	var hidden: Image = (await _h.settle())["image"]
	if hidden == null:
		return
	_h.check(_h.count_col(hidden, WIDE_BORDER_X[3] + 1, WIDE_CARD_TOP,
			WIDE_CARD_BOTTOM + SHADOW_PX + 1, _shadow) == 0
			and _h.count_row(hidden, WIDE_CARD_BOTTOM + 1, WIDE_BORDER_X[2],
				WIDE_BORDER_X[3] + SHADOW_PX + 1, _shadow) == 0,
		"反向对照：藏掉 Card1 的 Shadow 后它的右下环带应一个阴影像素都不剩")
	# 藏掉的是**叠层**，卡片本体的描边必须原样还在 —— 否则「阴影由叠层承载」就无从谈起。
	_h.check(_h.count_col(hidden, WIDE_BORDER_X[2], WIDE_CARD_TOP, WIDE_CARD_BOTTOM + 1,
			_border) == WIDE_CARD_BOTTOM - WIDE_CARD_TOP + 1,
		"反向对照：藏掉 Shadow 后 Card1 自己的 BROWN_600 描边仍在（卡片自身不带阴影）")
	var expected: int = 2 * _ring_size(WIDE_BORDER_X[0], WIDE_BORDER_X[1], WIDE_CARD_TOP, WIDE_CARD_BOTTOM)
	var left_count: int = int(_measure(hidden, _shadow)["count"])
	_h.check(left_count == expected,
		"反向对照：藏掉 Card1 的 Shadow 后全图 NAVY_900 应只剩另两张卡的环带 %d px（实际 %d）" % [
			expected, left_count])


## 一张卡的硬阴影契约：右边 SHADOW_PX 列、下边 SHADOW_PX 行各外扩到矩形之外，上 / 左没有；
## 且**卡片矩形内零阴影**。返回该卡的环带像素数（由几何推出，不是抄来的魔数）。
##
## PET-80：外扩量 1 → 2（SHADOW_PX），故第一列 / 第一行上量到的连续长度也各多 1。
## 形状不变：仍然是「紧贴右下、正上方与正左侧一个都没有、矩形内一个都没有」。
func _assert_card_shadow(image: Image, left: int, top: int, right: int, bottom: int,
		label: String) -> int:
	var width: int = right - left + 1
	var height: int = bottom - top + 1
	_h.check(_h.count_col(image, right + 1, top, bottom + SHADOW_PX + 1, _shadow) == height + SHADOW_PX,
		"%s：右边应外扩 %dpx NAVY_900，共 %d 个" % [label, SHADOW_PX, height + SHADOW_PX])
	_h.check(_h.count_row(image, bottom + 1, left, right + SHADOW_PX + 1, _shadow) == width + SHADOW_PX,
		"%s：下边应外扩 %dpx NAVY_900，共 %d 个" % [label, SHADOW_PX, width + SHADOW_PX])
	_h.check(_h.count_row(image, top - 1, left, right + 1, _shadow) == 0,
		"%s：上边不得有阴影" % label)
	_h.check(_h.count_col(image, left - 1, top, bottom + 1, _shadow) == 0,
		"%s：左边不得有阴影" % label)
	# 不覆盖文字：卡片矩形内一个阴影像素都不许有。阴影若被画成填满中心、四边整圈，或整层被排到
	# 内容之后而压住文字，这一条立刻变红 —— 正是 Codex 点名的那个风险。
	_h.check(_count_rect(image, Rect2i(left, top, width, height), _shadow) == 0,
		"%s：卡片矩形内不得有阴影像素 —— 右下 %dpx 不得压到文字上" % [label, SHADOW_PX])
	return _ring_size(left, right, top, bottom)


## 整幅画面的 NAVY_900 必须**恰好**等于各卡环带之和。多一个像素就说明阴影漫到了别处
## （铺进卡片、盖住文字、或溢出到卡片之外），是「不覆盖文字」的全局版断言。
func _assert_shadow_total(image: Image, expected: int, label: String) -> void:
	var count: int = int(_measure(image, _shadow)["count"])
	_h.check(count == expected,
		"%s：全图 NAVY_900 应恰好是三张卡的右下环带共 %d px（实际 %d）—— 一个像素都不许多" % [
			label, expected, count])


## 安全区口径（06 §9.2 边界说明，Codex 明确要求与 RESULT 一致）：右下装饰阴影**不计入**安全区。
## RESULT 侧：读数区矩形右缘 624（= 640 - 16），阴影列同样是 624（result_probe.gd）。
## REWARD 侧必须同款 —— 卡片矩形停在安全线上，阴影另占安全边距的头 SHADOW_PX 列 / 行。
func _check_shadow_inset(image: Image, left: int, right: int, top: int, bottom: int,
		canvas: Vector2i, label: String) -> void:
	_h.check(right + 1 == canvas.x - SAFE_INSET and bottom + 1 == canvas.y - SAFE_INSET,
		"%s：末张卡片矩形应停在安全线上（x=%d / y=%d = 视口 - %d），不得为阴影让位" % [
			label, right + 1, bottom + 1, SAFE_INSET])
	_h.check(_h.count_col(image, canvas.x - SAFE_INSET, top, bottom + SHADOW_PX + 1, _shadow)
			== bottom - top + SHADOW_PX + 1
			and _h.count_row(image, canvas.y - SAFE_INSET, left, right + SHADOW_PX + 1, _shadow)
			== right - left + SHADOW_PX + 1,
		"%s：阴影那 %dpx 应恰好落在安全边距的头 %d 列 / 行（从 x=%d / y=%d 起）—— 与 RESULT 读数区同口径" % [
			label, SHADOW_PX, SHADOW_PX, canvas.x - SAFE_INSET, canvas.y - SAFE_INSET])


## 环带像素数：右边 SHADOW_PX 列 × (h + SHADOW_PX) 行 + 下边 SHADOW_PX 行 × (w + SHADOW_PX) 列，
## 右下那个 SHADOW_PX×SHADOW_PX 的角块被数了两次，故减 SHADOW_PX²。
## 化简后 = SHADOW_PX × (w + h + SHADOW_PX)。PET-80 前 SHADOW_PX = 1，退化成 w + h + 1。
func _ring_size(left: int, right: int, top: int, bottom: int) -> int:
	var width: int = right - left + 1
	var height: int = bottom - top + 1
	return SHADOW_PX * (width + height + SHADOW_PX)


## 矩形内的判据色计数 —— 用来证明「阴影只画在矩形外侧」。
func _count_rect(image: Image, rect: Rect2i, wanted: Color) -> int:
	var hits: int = 0
	for y: int in range(rect.position.y, rect.end.y):
		hits += _h.count_row(image, y, rect.position.x, rect.end.x, wanted)
	return hits


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

	# 反向对照二：整体右移 8px（PET-80 前 4px），六条描边必须整体跟着走。
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
