## result_probe.gd
## 职责：RESULT 界面的像素取证（09 §4）—— 证明 06 §1·§2.2·§3 的版面是**真的画成**
##       那几块矩形（读数区那块次级面板、两个出口按钮），而不是「字段等于多少」。
## 所属系统：tests（09 §4 像素探针的 S1-10 用例模块）
## 依赖：Palette, assets/ui/theme_main.tres, scenes/result/result.tscn
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得写任何字面色值 —— 判据一律取自 Palette。
##
## 拆分理由：聚合入口 run_render_probes.gd 已近 02 §4 的 300 行上限，
## 按 09 §4 v0.1.3 的先例把 S1-10 的用例拆成模块，聚合入口只留一次调用。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   反向对照一 —— 藏掉按钮区：金色块与次要按钮底色必须整体归零，读数区的描边一个都不许动。
##                 量不到，就说明上面数到的像素并非来自那两个出口。
##   反向对照二 —— 把按钮区整体右移 8px（PET-80 前 4px，长度随坐标系 ×2），金色块必须跟着移 8px。
##                 量不到这个位移，就说明「恰好落在这几个 x 上」那几条只是碰巧。
##   反向对照三 —— 藏掉读数区的 PanelShadow 叠层：右下那圈 NAVY_900 必须整体归零，
##                 而读数区自己的 BROWN_600 描边仍在（06 §2.2 v0.1.5 甲案：面板自身不带阴影）。
##
## 分工：本探针只量**真实渲染矩形**。布局算得对不对由 tests/unit/test_result.gd 覆盖，
## 交互（两个出口经 GameFlow、不自动推进）由 tests/integration/result_smoke.gd 覆盖。

extends RefCounted

const SCENE_PATH: String = "res://scenes/result/result.tscn"
## 窗口右界的唯一真值来源（见 SCAN_RIGHT 的推导）。
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"

## 画布 = 06 §1 的 640×360 基准（宽屏，PET-80 前 320×180）与 360×640（窄屏，前 180×320），
## 与布局常数同一坐标系。
const WIDE: Vector2i = Vector2i(640, 360)
const NARROW: Vector2i = Vector2i(360, 640)

## 扫描窗口：只圈住主面板**内芯以内**的区域，避开两样东西 —— 最外圈的切片外框，以及
## 内芯自己那圈 NAVY_600 环带。两条边界的依据**不同源**，因为它们避的不是同一样东西：
##
##   左界 4 —— 外框切片自带的左带占 x0..x3（**纹素**读数，FRAME_MARGIN_LEFT = 4，
##             本卡不动 assets/**，故不随坐标系 ×2）。这条与 PET-80 前一样。
##   右界 632 —— 内芯在 Shell 里按 FRAME_BORDER_WIDTH 内缩（本卡 6），右环带再占 BORDER_WIDTH 列
##             （本卡 2），故环带左沿 = 640 − 6 − 2 = 632。这一条是**设计尺寸**，随坐标系 ×2。
##
## 为什么右界不能像左界那样也取「距边缘 4」= 636：那会把内芯自己的 NAVY_600 右环带
## （632–633）圈进窗口，于是「第 300 行恰好只有出口按钮那 4 个 x 是 NAVY_600」当场破裂 ——
## 主面板的环带被算成了第三条。PET-80 前它侥幸没破裂：内芯内缩 3（= 当时 1× 的
## FRAME_BORDER_WIDTH）时环带只占 1 列，且恰好落在 316 这个被排除的边界列上。
## 下面 `_probe_actions_wide()` 里有一条断言把这条边界钉成可验证的事实，而不是随手取的数字。
##
## 于是 [4, 632) 里除了本界面自己的描边不该有第二种 BROWN_600。
const SCAN_LEFT: int = 4
const SCAN_RIGHT: int = 632

## PET-77：外框换成已批准切片后，窗口外那几列里也有 BROWN_600 —— 那是**框自己**的木质带。
## 逐像素读数（`ui_panel_frame_main_96x64`）：左带 4px = x0 BROWN_500 / x1..x2 BROWN_600 / x3 GOLD_200 高光；
## 右带 3px = x317..x318 BROWN_600 / x319 BROWN_500。窗口边界那两条断言据此改钉「只许这两条、且在此位置」。
##
## PET-80：这几列同样是**纹素**读数，故**贴边**不变：左带仍是 x0..x3（FRAME_LEFT_BAND 原样），
## 右带仍贴右缘 —— 画布宽 320 → 640 后，右带从 x317/x318 变成 x637/x638。
const FRAME_LEFT_BAND: Array[int] = [1, 2]
const FRAME_RIGHT_BAND: Array[int] = [637, 638]
const SCAN_TOP: int = 4
const SCAN_BOTTOM: int = 632

## 06 §2.2：标题栏高 32px（PET-80 前 16），底部 GOLD_600 分隔线。上沿在 y=16（前 8），
## 故金线落在标题栏最后 TITLE_GOLD_ROWS 行（y=47 与 y=46）。
##
## PET-80：这条线是 PanelTitleBar 变体 StyleBoxFlat 的 `border_width_bottom`，取自
## PaletteTheme.BORDER_WIDTH —— 代码画的**逻辑**像素（不是九宫格切片的纹素边距），
## 故厚度随坐标系 ×2：1 行 → 2 行。判别力不变：线上 / 线下各一行仍必须是零。
const TITLE_GOLD_ROW: int = 47
const TITLE_GOLD_ROWS: int = 2
const WIDE_TITLE_GOLD: int = 608
const NARROW_TITLE_GOLD: int = 328

## 06 §1 / §2.2 下读数区（次级面板）的**实测**矩形与它那圈 BROWN_600。
## 刻意写死而不是由布局公式现算：探针要证的正是「公式的结果真的落在了这几个像素上」。
##
## PET-80：布局读数逐项 ×2（8→16 / 32→64 / 304→608 / 88→176；右缘 2·311+1 = 623、下缘 2·119+1 = 239）。
## 但那圈描边**仍是 1 逻辑像素**（PET-80 前如此）：它来自次级面板切片的 `texture_margin_*`
## （THIN_FRAME_MARGIN_* = 2 **纹素**，本卡不动 assets/**），不是代码画的逻辑像素。
const WIDE_READOUT_TOP: int = 64
const WIDE_READOUT_BOTTOM: int = 239
const WIDE_READOUT_LEFT: int = 16
const WIDE_READOUT_RIGHT: int = 623
## 读数区内的扫描行：落在面板上沿之下、居中文字之上（文字块被 VBox 居中，离上沿很远）。
## PET-80：原来取「上沿 + 4」，这条偏移是**长度**，随坐标系 ×2 → 上沿 + 8。
const READOUT_SCAN_ROW: int = 72

## 两个出口的**实测**矩形（屏幕坐标）。按钮区在 y=256，按钮高 88。
## PET-80：逐项 ×2（8→16 / 155→311 / 164→328 / 311→623 / 128→256 / 171→343 / 150→300）。
const BUTTON_SCAN_ROW: int = 300
const WIDE_MENU_LEFT: int = 16
const WIDE_MENU_RIGHT: int = 311
const WIDE_RETRY_LEFT: int = 328
const WIDE_RETRY_RIGHT: int = 623
## 描边内缩后的实心块：x329..622（294）、y258..341（84）。
## PET-77：主按钮改用已批准切片 `ui_button_primary_*_64x20`，切片在 GOLD_500 填充之上
## 还各占 1px（上 = GOLD_600 描边之内的 GOLD_200 高光；下 = GOLD_600 描边之下的烘焙投影），
## 故填充块比盒子矮 4 行 —— 按钮**盒子**仍是同一个 88px，见 BUTTON_CHROME。
##
## PET-80：这些内缩量读的是切片自身的**纹素**结构（本卡不动 assets/**），故横向仍是 1px、
## 纵向仍是 2px —— 不随坐标系 ×2，只是跟着盒子一起平移 / 变宽变高。
const WIDE_RETRY_GOLD: Rect2i = Rect2i(329, 258, 294, 84)
## 描边内缩后的实心块上沿（两个出口同高）。
const BUTTON_FILL_TOP: int = 258
## 按钮盒子在填充之上额外占的行数（每侧 2：1px 描边 + 1px 高光 / 投影）。
## 总高 = 填充 84 + 2×2 = 88，正好是 06 §1 的触摸下限；这条换算就是 _probe_actions_wide() 末段的依据。
const BUTTON_CHROME: int = 2
## 出口按钮盒子的上下沿（屏幕坐标）：按钮区在 y=256、整高 88。
const BUTTON_BOX_TOP: int = 256
const BUTTON_BOX_BOTTOM: int = 343
## 两个出口之间那道 16px 空隙必须露出主面板底色。
const WIDE_GAP_LEFT: int = 312
const WIDE_GAP_RIGHT: int = 328

## 360×640 竖屏下读数区与两个出口的**实测**坐标（PET-80 前 180×320，逐项 ×2：100→200 / 32→64 /
## 207→415 / 171→343 / 216→432 / 268→536 / 240→480）。
const NARROW_SCAN_COL: int = 200
const NARROW_READOUT_TOP: int = 64
const NARROW_READOUT_BOTTOM: int = 415
const NARROW_READOUT_RIGHT: int = 343
const NARROW_MENU_TOP: int = 432
const NARROW_RETRY_TOP: int = 536
const NARROW_RETRY_GOLD: Rect2i = Rect2i(17, 538, 326, 84)
const NARROW_MENU_SCAN_ROW: int = 480

## 硬阴影的厚度（**逻辑**像素）。PET-80：1 → 2。
##
## 它来自 `PaletteTheme._build_panel_shadow()` 的 `border_width_right/bottom`，取值是 `BORDER_WIDTH`
## —— 代码画的逻辑像素（**不是**九宫格切片的纹素边距），故随坐标系 ×2。
## 于是阴影从「右下各 1 列 / 行」变成「各 2 列 / 行」，阴影像素总数由 w + h + 1 变成 2(w + h + 2)。
## 读数区**自己**那圈 BROWN_600 描边不跟着变：它来自 PanelSecondary 的 StyleBoxTexture 边距
## （THIN_FRAME_MARGIN_* = 2 纹素，本卡不动 assets/**），仍是 1 逻辑像素。
const SHADOW_PX: int = 2

## 06 §1：可点击区域下限（设备像素）。实测填充块加两侧 BUTTON_CHROME 即按钮整高。
## PET-80：44 → 88（06 §1 的触摸下限随基准画布 ×2）。
const MIN_TOUCH_SIZE: int = 88

## 反向对照的位移量。它是一条**长度**，故随坐标系 ×2（PET-80 前 4）。
const SHIFT: float = 8.0

var _h: RefCounted = null
var _tree: SceneTree = null
var _theme: Theme = null
var _scene: Control = null
var _script: GDScript = null
var _border: Color = Color.BLACK
var _gold: Color = Color.BLACK
var _gold_edge: Color = Color.BLACK
var _secondary: Color = Color.BLACK
var _secondary_edge: Color = Color.BLACK
var _core: Color = Color.BLACK
var _shadow: Color = Color.BLACK


## 由聚合入口调用。harness 与 tree 都是借来的 —— 计数直接记在同一个 harness 上，
## 于是退出码与总计数不必两处维护。
func run(tree: SceneTree, harness: RefCounted, theme: Theme) -> void:
	_tree = tree
	_h = harness
	_theme = theme
	_script = load(THEME_SCRIPT_PATH)
	_border = Palette.get_color(Palette.Key.BROWN_600)
	_gold = Palette.get_color(Palette.Key.GOLD_500)
	_gold_edge = Palette.get_color(Palette.Key.GOLD_600)
	_secondary = Palette.get_color(Palette.Key.NAVY_700)
	_secondary_edge = Palette.get_color(Palette.Key.NAVY_600)
	_core = Palette.get_color(Palette.Key.NAVY_800)
	_shadow = Palette.get_color(Palette.Key.NAVY_900)

	print("")
	print("=== 组 11：RESULT 读数区与两个出口按钮（06 §1 / §2.2 / §3 像素取证）===")
	print("  判据色：读数区描边=BROWN_600%s 主要按钮=GOLD_500%s 次要按钮=NAVY_700%s 阴影=NAVY_900%s" % [
		_h.color_text(_border), _h.color_text(_gold), _h.color_text(_secondary), _h.color_text(_shadow),
	])
	await _probe_readout_wide()
	await _probe_actions_wide()
	await _probe_narrow()
	await _probe_reverse()


## 组 11a：640×360 下读数区是一块 608×176 的次级面板（1 逻辑像素 BROWN_600 描边 ——
## 那圈描边读的是切片纹素，不随坐标系 ×2、NAVY_800 内芯），右下各外扩 SHADOW_PX 像素
## NAVY_900 硬阴影（06 §2.2 阴影行 / v0.1.5 甲案），标题栏分隔线横贯 608px。
func _probe_readout_wide() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return

	var hits: Array[int] = _row_hits(image, READOUT_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border)
	_h.check(hits == [WIDE_READOUT_LEFT, WIDE_READOUT_RIGHT],
		"第 %d 行应恰好在这 2 个 x 上是 BROWN_600：%s（实际 %s）" % [
			READOUT_SCAN_ROW, [WIDE_READOUT_LEFT, WIDE_READOUT_RIGHT], hits])
	_h.check(WIDE_READOUT_RIGHT - WIDE_READOUT_LEFT + 1 == 608, "读数区的内宽应为 608px")
	_h.check(WIDE_READOUT_BOTTOM - WIDE_READOUT_TOP + 1 == 176, "读数区的高应为 176px")
	_h.check(_h.count_row(image, WIDE_READOUT_TOP, SCAN_LEFT, SCAN_RIGHT, _border) == 608,
		"读数区上沿 y=%d 应整行是描边" % WIDE_READOUT_TOP)
	_h.check(_h.count_row(image, WIDE_READOUT_BOTTOM, SCAN_LEFT, SCAN_RIGHT, _border) == 608,
		"读数区下沿 y=%d 应整行是描边" % WIDE_READOUT_BOTTOM)
	_h.check(_h.count_col(image, WIDE_READOUT_LEFT, WIDE_READOUT_TOP, WIDE_READOUT_BOTTOM + 1, _border) == 176,
		"读数区左缘 x=%d 应整列是描边" % WIDE_READOUT_LEFT)
	_h.check(_h.count_col(image, WIDE_READOUT_RIGHT, WIDE_READOUT_TOP, WIDE_READOUT_BOTTOM + 1, _border) == 176,
		"读数区右缘 x=%d 应整列是描边" % WIDE_READOUT_RIGHT)

	# 硬阴影：右边是**列**（沿 y 走），下边是**行**（沿 x 走）。两者在方盒上数值相同，
	# 这里 608×176 宽高不等，参数写反了会当场红。
	_assert_readout_shadow(image, WIDE_READOUT_LEFT, WIDE_READOUT_TOP, WIDE_READOUT_RIGHT,
		WIDE_READOUT_BOTTOM, "640×360")

	# 标题栏分隔线：整条 608px，且只占标题栏最后 TITLE_GOLD_ROWS 行 —— 再往上、再往下都不许有。
	# PET-80：线厚 1 行 → TITLE_GOLD_ROWS 行（BORDER_WIDTH ×2），判别力不变（上下各一行仍必须是零）。
	for offset: int in TITLE_GOLD_ROWS:
		_h.check(_h.count_row(image, TITLE_GOLD_ROW - offset, 0, WIDE.x, _gold_edge) == WIDE_TITLE_GOLD,
			"标题栏分隔线第 %d 行应是整条 %dpx" % [TITLE_GOLD_ROW - offset, WIDE_TITLE_GOLD])
	_h.check(_h.count_row(image, TITLE_GOLD_ROW - TITLE_GOLD_ROWS, 0, WIDE.x, _gold_edge) == 0
			and _h.count_row(image, TITLE_GOLD_ROW + 1, 0, WIDE.x, _gold_edge) == 0,
		"分隔线上下各一行都不许有金像素（分隔线只占 %d 行）" % TITLE_GOLD_ROWS)
	# 钉住扫描窗口的两条边界：窗口外（最外圈面板框那一带）只许出现**外框切片自己**那两条
	# BROWN_600 木质带，且必须落在固定列上 —— 否则上面那条「恰好 2 个」随时可能被外框顶掉。
	#
	# 原来钉：窗口外命中 0（旧外框是 StyleBoxFlat：3px 描边 + BROWN_500 填充，
	#         而窗口外那几列恰好落在填充上，所以当时确实是 0）。
	# 现在钉：命中数 == 2，且命中列 == 外框自带的那两条（左 x1/x2、右 x637/x638）。
	# 为什么是同一件事：这条要证的是「窗口外那几列只属于外框，不掺本界面自己的任何描边」。
	#   外框改用已批准切片后，切片在描边内侧多了一条 BROWN_600（旧 StyleBoxFlat 那里是填充），
	#   于是「0」这个数字不再成立；改钉「恰好 2 且位置固定」把同一件事证得更死 ——
	#   数量或位置任一变化（多一条、挪一列、本界面有描边漏出窗口）都会转红。
	#   PET-80：切片边距是纹素读数，故这 3 列**贴边**不动，只是画布宽了、右带整体右移了 320 列。
	#   窗口边界同理贴着边（SCAN_LEFT / SCAN_RIGHT 的定义处有说明），于是窗口外仍是同一块区域。
	var left_out: Array[int] = _row_hits(image, READOUT_SCAN_ROW, 0, SCAN_LEFT, _border)
	_h.check(left_out == FRAME_LEFT_BAND,
		"扫描窗口左侧（x< %d）应恰好是外框自带的那两条木质带 %s（实际 %s）" % [
			SCAN_LEFT, FRAME_LEFT_BAND, left_out])
	var right_out: Array[int] = _row_hits(image, READOUT_SCAN_ROW, SCAN_RIGHT, WIDE.x, _border)
	_h.check(right_out == FRAME_RIGHT_BAND,
		"扫描窗口右侧（x>= %d）应恰好是外框自带的那两条木质带 %s（实际 %s）" % [
			SCAN_RIGHT, FRAME_RIGHT_BAND, right_out])


## 组 11b：两个出口按钮的实心块 —— 主按钮 GOLD_500、次按钮 NAVY_700，各 296×88，
## 中间留 16px、两端各留 16px 安全边距；实测整高不得低于 06 §1 的 88 触摸下限。
func _probe_actions_wide() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return

	var gold: Dictionary = _measure(image, _gold)
	var box: Rect2i = gold["box"]
	var area: int = WIDE_RETRY_GOLD.size.x * WIDE_RETRY_GOLD.size.y
	# 包围盒相等即「所有 GOLD_500 都落在这块矩形里」—— 外面再有一个像素，包围盒就会胀出去。
	_h.check(box == WIDE_RETRY_GOLD,
		"主按钮的实心块应落在 %s（实际 %s）" % [WIDE_RETRY_GOLD, box])
	# 块内除了底色就是按钮文字的那点墨迹：墨迹必须是少数派，
	# 否则说明画的是一圈描边或压根不是这块底色。
	var ink: int = area - int(gold["count"])
	_h.check(ink > 0, "主按钮上应确有文字墨迹（实际 %d px）—— 否则下一条是空断言" % ink)
	_h.check(ink * 4 < area, "文字墨迹应只占实心块的一小部分（实际 %d/%d）" % [ink, area])
	_h.check(_h.count_col(image, WIDE_RETRY_GOLD.position.x, WIDE_RETRY_GOLD.position.y,
			WIDE_RETRY_GOLD.end.y, _gold) == WIDE_RETRY_GOLD.size.y,
		"主按钮实心块的左缘应整列是 GOLD_500")

	# 「再来一局」是主要出口：默认 Button（GOLD 底 + GOLD_600 描边）。
	var gold_hits: Array[int] = _row_hits(image, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _gold_edge)
	_h.check(gold_hits == [WIDE_RETRY_LEFT, WIDE_RETRY_RIGHT],
		"第 %d 行应恰好在这 2 个 x 上是主按钮描边 GOLD_600：%s（实际 %s）" % [
			BUTTON_SCAN_ROW, [WIDE_RETRY_LEFT, WIDE_RETRY_RIGHT], gold_hits])
	# 「返回主菜单」是次要出口：ButtonSecondary（NAVY_700 底 + NAVY_600 描边）。
	# 量的是**首末命中**而不是连续段长：扫描行穿过按钮文字，段长会被墨迹打断，
	# 而「底色一直铺到左右两条描边内侧」正是这里要证的那件事。
	#
	# PET-80：内缩量由 1 变 2 —— 次按钮是 StyleBoxFlat，描边取自 BORDER_WIDTH（1 → 2），
	# 跟着坐标系 ×2；这不像主按钮那样读切片纹素。故实心块首末命中各内缩 2，不是 1。
	_h.check(_span_row(image, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _secondary)
			== [WIDE_MENU_LEFT + 2, WIDE_MENU_RIGHT - 2],
		"次按钮的实心块应恰好铺满 x%d..%d（实际 %s）" % [WIDE_MENU_LEFT + 2, WIDE_MENU_RIGHT - 2,
			_span_row(image, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _secondary)])
	# 原来钉：这 2 个 x 上是次按钮描边（StyleBoxFlat 各 1px）。
	# 现在钉：这 4 个 x —— 描边厚 2px，左右各占 2 列。
	# 为什么是同一件事：这条要证的是「实心块两侧各有一条 NAVY_600 描边，且只有这两条」。
	#   描边变厚只是同一件事的又一个读数：若描边哪天又从 2 变回 1、或挪了位置、
	#   或多出第三条（比如主面板底色漏出 NAVY_600），这个 4 元组都会当场破裂。
	var navy_hits: Array[int] = _row_hits(image, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _secondary_edge)
	_h.check(navy_hits == [WIDE_MENU_LEFT, WIDE_MENU_LEFT + 1, WIDE_MENU_RIGHT - 1, WIDE_MENU_RIGHT],
		"第 %d 行应恰好在这 4 个 x 上是次按钮描边 NAVY_600：%s（实际 %s）" % [
			BUTTON_SCAN_ROW,
			[WIDE_MENU_LEFT, WIDE_MENU_LEFT + 1, WIDE_MENU_RIGHT - 1, WIDE_MENU_RIGHT], navy_hits])

	# 窗口右界不是随手取的数字：它必须**正好压在内芯 NAVY_600 右环带的左沿**上 ——
	# 扫描行上它本身是环带、左邻一列不是、再往右 BORDER_WIDTH 列之外也不是（环带恰好 BORDER_WIDTH 列宽）。
	# 内芯内缩量或描边厚度一变，这里先红，于是「为什么是 632」是一个可验证的事实，不是一句注释。
	_h.check(SCAN_RIGHT == WIDE.x - _script.FRAME_BORDER_WIDTH - _script.BORDER_WIDTH,
		"窗口右界应等于内芯环带左沿（%d − FRAME_BORDER_WIDTH %d − BORDER_WIDTH %d）" % [
			WIDE.x, _script.FRAME_BORDER_WIDTH, _script.BORDER_WIDTH])
	_h.check(_h.near(image.get_pixel(SCAN_RIGHT, BUTTON_SCAN_ROW), _secondary_edge)
			and not _h.near(image.get_pixel(SCAN_RIGHT - 1, BUTTON_SCAN_ROW), _secondary_edge)
			and not _h.near(image.get_pixel(SCAN_RIGHT + _script.BORDER_WIDTH, BUTTON_SCAN_ROW),
				_secondary_edge),
		"第 %d 行上 x=%d 应是内芯右环带（%d 列宽，左沿在此），左邻一列与环带之外都不该是" % [
			BUTTON_SCAN_ROW, SCAN_RIGHT, _script.BORDER_WIDTH])

	# 两个出口之间的空隙：16px，且必须是主面板底色 —— 露不出底色就说明两块连成了一片。
	_h.check(_h.count_row(image, BUTTON_SCAN_ROW, WIDE_GAP_LEFT, WIDE_GAP_RIGHT, _core)
			== WIDE_GAP_RIGHT - WIDE_GAP_LEFT,
		"两个出口之间应留 %dpx 主面板底色" % (WIDE_GAP_RIGHT - WIDE_GAP_LEFT))
	# 两端的安全边距由上面那两组描边坐标本身推出，不是另抄一份尺寸。
	_h.check(WIDE_MENU_LEFT == 16, "首个出口的左安全边距应为 16px（06 §1）")
	_h.check(WIDE.x - 1 - WIDE_RETRY_RIGHT == 16, "末个出口的右安全边距应为 16px（06 §1）")

	# 触摸下限：实测填充块高 84，加上下各 2px（描边 + 高光 / 投影）即按钮整高，必须 ≥ 88。
	# 原来用 `+ BUTTON_BORDER * 2`；PET-77 主按钮换成切片后非填充部分由 2px 变 4px，
	# 判据仍是「盒子整高 ≥ 触摸下限」，算式跟着换成 BUTTON_CHROME。
	# PET-80：填充 40 → 84、下限 44 → 88，两边一起 ×2，「填充 + 非填充 == 下限」这个等式不变。
	var button_height: int = WIDE_RETRY_GOLD.size.y + BUTTON_CHROME * 2
	_h.check(button_height >= MIN_TOUCH_SIZE,
		"出口按钮实测整高 %dpx 不得低于 06 §1 的 %d 触摸下限" % [button_height, MIN_TOUCH_SIZE])
	# 原来钉（PET-77 之前）：次按钮的 NAVY_700 填充块高 == 主按钮 GOLD_500 填充块高
	#   （两者都是 StyleBoxFlat，各 1px 描边，故填充块也同高）。
	# PET-77 改钉：次按钮填充纵向比主按钮各多一行（[129,170] vs [130,169]）—— 主按钮切片自带
	#   上下各 1px 的高光 / 投影，填充自然矮 2px；当时只能靠这个间接关系表达「盒子同高」。
	# 现在钉（PET-80）：**两者重新完全相等**（[258,341] vs [258,341]）。
	# 为什么是同一件事：这条要证的从来是「两个出口是同一个尺寸的盒子，没有一高一矮」。
	#   次按钮的 StyleBoxFlat 描边随 BORDER_WIDTH 由 1px 变 2px，正好补上主按钮切片多占的那一行，
	#   于是两块实心区又回到同一矩形 —— 命题没变，表达反而更强：PET-77 那阵子「各差一行」
	#   需要读者先接受一个间接换算，现在直接钉**相等**，任一侧盒子高一像素都会当场破裂。
	var menu_fill: Array = _span_col(image, WIDE_MENU_LEFT + 2, BUTTON_BOX_TOP,
		BUTTON_BOX_BOTTOM + 1, _secondary)
	_h.check(menu_fill == [WIDE_RETRY_GOLD.position.y, WIDE_RETRY_GOLD.end.y - 1],
		"次按钮的填充块应恰好与主按钮同一矩形（期望 %s，实际 %s）" % [
			[WIDE_RETRY_GOLD.position.y, WIDE_RETRY_GOLD.end.y - 1], menu_fill])


## 组 11c：360×640 竖屏下两个出口改竖排 —— 同处一列、自上而下、仍贴底部安全线。
## PET-80：折叠档的读数逐项 ×2（180×320 → 360×640、44 → 88、8 → 16、164 → 328）。
func _probe_narrow() -> void:
	var image: Image = await _open_scene(NARROW)
	if image == null:
		return

	var hits: Array[int] = _col_hits(image, NARROW_SCAN_COL, SCAN_TOP, SCAN_BOTTOM, _border)
	_h.check(hits == [NARROW_READOUT_TOP, NARROW_READOUT_BOTTOM],
		"第 %d 列应恰好在这 2 个 y 上是读数区描边：%s（实际 %s）" % [
			NARROW_SCAN_COL, [NARROW_READOUT_TOP, NARROW_READOUT_BOTTOM], hits])
	_h.check(_h.count_row(image, NARROW_READOUT_TOP, SCAN_LEFT, 352, _border) == 328
			and _h.count_row(image, NARROW_READOUT_BOTTOM, SCAN_LEFT, 352, _border) == 328,
		"折叠后读数区应铺满可用宽（328px）")
	_assert_readout_shadow(image, 16, NARROW_READOUT_TOP, NARROW_READOUT_RIGHT,
		NARROW_READOUT_BOTTOM, "360×640")
	_h.check(_h.count_row(image, TITLE_GOLD_ROW, 0, NARROW.x, _gold_edge) == NARROW_TITLE_GOLD,
		"标题栏分隔线应随可用宽收窄到 %dpx" % NARROW_TITLE_GOLD)

	# 折叠的形态由「同 x、递增 y」证明，而不是由某个宽高数字证明。
	# PET-80：段落长度 44 → 88（按钮整高 ×2），首末命中各内缩 2（StyleBoxFlat 描边 1 → 2）。
	_h.check(_span_col(image, NARROW_SCAN_COL, NARROW_MENU_TOP, NARROW_MENU_TOP + 88, _secondary)
			== [NARROW_MENU_TOP + 2, NARROW_MENU_TOP + 85],
		"次按钮应落在 y%d 起的那一段（实际 %s）" % [NARROW_MENU_TOP,
			_span_col(image, NARROW_SCAN_COL, NARROW_MENU_TOP, NARROW_MENU_TOP + 88, _secondary)])
	var gold: Dictionary = _measure(image, _gold)
	_h.check(gold["box"] == NARROW_RETRY_GOLD,
		"主按钮的实心块应落在 %s（实际 %s）" % [NARROW_RETRY_GOLD, gold["box"]])
	_h.check(NARROW_MENU_TOP - (NARROW_READOUT_BOTTOM + 1) == 16,
		"读数区与按钮区之间应隔 16px（%d → %d）" % [NARROW_READOUT_BOTTOM, NARROW_MENU_TOP])
	_h.check(NARROW_RETRY_TOP - (NARROW_MENU_TOP + 88) == 16, "两个出口之间应隔 16px")
	_h.check(NARROW.y - 1 - (NARROW_RETRY_TOP + 87) == 16, "末个出口应贴底部安全线")
	_h.check(_span_row(image, NARROW_MENU_SCAN_ROW, SCAN_LEFT, 352, _secondary) == [18, 341],
		"折叠后次按钮的实心块宽应铺满可用宽（x18..341，实际 %s）" % [
			_span_row(image, NARROW_MENU_SCAN_ROW, SCAN_LEFT, 352, _secondary)])


## 反向对照：证明上面数到的像素确实来自那两个出口与那层阴影，且位置由布局决定。
func _probe_reverse() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return
	var actions: Control = _scene.find_child("Actions", true, false) as Control
	var readout: Panel = _scene.find_child("ReadoutPanel", true, false) as Panel
	if not _h.check(actions != null and readout != null, "场景应有 Actions 与 ReadoutPanel"):
		return

	actions.visible = false
	var hidden: Image = (await _h.settle())["image"]
	if hidden == null:
		return
	_h.check(_measure(hidden, _gold)["count"] == 0,
		"反向对照：藏掉按钮区后主按钮的金色块应整体消失")
	_h.check(_h.count_row(hidden, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _secondary) == 0
			and _h.count_row(hidden, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _gold_edge) == 0,
		"反向对照：藏掉按钮区后次要按钮底色与主按钮描边都应一并消失")
	_h.check(_row_hits(hidden, READOUT_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border)
			== [WIDE_READOUT_LEFT, WIDE_READOUT_RIGHT],
		"反向对照：藏掉按钮区不得动到读数区的描边（两者互不遮挡）")

	# 反向对照二：整体右移 8px（PET-80 前 4px），实心块必须整体跟着走。
	image = await _open_scene(WIDE)
	if image == null:
		return
	actions = _scene.find_child("Actions", true, false) as Control
	if not _h.check(actions != null, "场景应有 Actions"):
		return
	actions.position += Vector2(SHIFT, 0.0)
	var shifted: Image = (await _h.settle())["image"]
	if shifted == null:
		return
	_h.check(_measure(shifted, _gold)["box"]
			== Rect2i(WIDE_RETRY_GOLD.position + Vector2i(int(SHIFT), 0), WIDE_RETRY_GOLD.size),
		"反向对照：按钮区右移 %dpx 后金色块应整体跟着移" % int(SHIFT))

	# 反向对照三：藏掉读数区的阴影叠层 —— 右下那圈 NAVY_900 归零，而描边仍在
	# （06 §2.2 v0.1.5 甲案：面板自身不带阴影，硬阴影由场景叠层单独承载）。
	image = await _open_scene(WIDE)
	if image == null:
		return
	readout = _scene.find_child("ReadoutPanel", true, false) as Panel
	var shadow_layer: Node = (readout.find_child("Shadow", true, false) if readout != null else null)
	if not _h.check(shadow_layer != null, "读数区应有 Shadow 叠层"):
		return
	shadow_layer.set(&"visible", false)
	var no_shadow: Image = (await _h.settle())["image"]
	if no_shadow == null:
		return
	# PET-80：阴影外扩量 1 → SHADOW_PX，采样范围跟着放宽到把整条环带盖住。
	_h.check(_h.count_col(no_shadow, WIDE_READOUT_RIGHT + 1, WIDE_READOUT_TOP,
			WIDE_READOUT_BOTTOM + SHADOW_PX + 1, _shadow) == 0
			and _h.count_row(no_shadow, WIDE_READOUT_BOTTOM + 1, WIDE_READOUT_LEFT,
				WIDE_READOUT_RIGHT + SHADOW_PX + 1, _shadow) == 0,
		"反向对照：藏掉 Shadow 叠层后读数区右下应一个阴影像素都不剩")
	_h.check(_row_hits(no_shadow, READOUT_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border)
			== [WIDE_READOUT_LEFT, WIDE_READOUT_RIGHT],
		"反向对照：藏掉 Shadow 叠层后读数区自己的描边仍在（面板自身不带阴影）")

	# 反向对照四：把读数区换成 PanelCore，那圈 BROWN_600 必须消失 —— 证明它来自次级面板变体本身。
	image = await _open_scene(WIDE)
	if image == null:
		return
	readout = _scene.find_child("ReadoutPanel", true, false) as Panel
	if readout == null:
		return
	readout.theme_type_variation = &"PanelCore"
	readout.queue_redraw()
	var swapped: Image = (await _h.settle())["image"]
	if swapped == null:
		return
	_h.check(_row_hits(swapped, READOUT_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border).is_empty(),
		"反向对照：换成 PanelCore 后读数区的 BROWN_600 描边应归零 —— 描边来自次级面板变体")


## 读数区的硬阴影契约：右边 SHADOW_PX 列、下边 SHADOW_PX 行各外扩到矩形之外，上 / 左没有。
## 总阴影数由几何推出（SHADOW_PX × (w + h + SHADOW_PX)，右下角块只画一次），不是抄来的魔数。
##
## PET-80：外扩量 1 → SHADOW_PX。形状不变：仍是「紧贴右下、正上方与正左侧一个都没有」，
## 只是那圈环带厚了一倍。上 / 左两条的采样范围一并放宽到盖住整条环带 ——
## 范围只到 right + 1 的话，多出来的第二列即使被画到矩形正上方也量不到。
func _assert_readout_shadow(image: Image, left: int, top: int, right: int, bottom: int,
		label: String) -> void:
	var width: int = right - left + 1
	var height: int = bottom - top + 1
	_h.check(_h.count_col(image, right + 1, top, bottom + SHADOW_PX + 1, _shadow) == height + SHADOW_PX,
		"%s：读数区右边应外扩 %dpx NAVY_900，共 %d 个" % [label, SHADOW_PX, height + SHADOW_PX])
	_h.check(_h.count_row(image, bottom + 1, left, right + SHADOW_PX + 1, _shadow) == width + SHADOW_PX,
		"%s：读数区下边应外扩 %dpx NAVY_900，共 %d 个" % [label, SHADOW_PX, width + SHADOW_PX])
	_h.check(_h.count_row(image, top - 1, left, right + SHADOW_PX + 1, _shadow) == 0,
		"%s：读数区上边不得有阴影" % label)
	_h.check(_h.count_col(image, left - 1, top, bottom + SHADOW_PX + 1, _shadow) == 0,
		"%s：读数区左边不得有阴影" % label)


## 把 result.tscn 挂上画布、按给定画布尺寸落一次布局，再取像素。
## 显式调 apply_layout_for 而不是依赖画布尺寸推断 —— 探针要证的是「布局画在哪」，
## 折叠与否这件事已由 test_result.gd 与 result_smoke.gd 覆盖。
func _open_scene(canvas: Vector2i) -> Image:
	var packed: PackedScene = load(SCENE_PATH)
	if not _h.check(packed != null, "result.tscn 应能加载"):
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


## 一行里判据色的**首末命中**（没有命中时返回空数组）。
## 按钮底色上压着按钮文字，连续段长会被墨迹打断，而「铺到两条描边内侧」这个契约
## 恰恰只能由首末命中来证 —— 用段长会随字体变化随机报红。
func _span_row(image: Image, y: int, from_x: int, to_x: int, wanted: Color) -> Array[int]:
	var hits: Array[int] = _row_hits(image, y, from_x, to_x, wanted)
	return [] if hits.is_empty() else [hits[0], hits[hits.size() - 1]]


func _span_col(image: Image, x: int, from_y: int, to_y: int, wanted: Color) -> Array[int]:
	var hits: Array[int] = _col_hits(image, x, from_y, to_y, wanted)
	return [] if hits.is_empty() else [hits[0], hits[hits.size() - 1]]


func _col_hits(image: Image, x: int, from_y: int, to_y: int, wanted: Color) -> Array[int]:
	var hits: Array[int] = []
	for y: int in range(from_y, to_y):
		if _h.near(image.get_pixel(x, y), wanted):
			hits.append(y)
	return hits


## 全图扫一遍判据色，同时给出计数与包围盒 —— 两者一起才能说清「是不是一块实心矩形」。
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
