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
##   反向对照二 —— 把按钮区整体右移 4px，金色块必须跟着移 4px。
##                 量不到这个位移，就说明「恰好落在这几个 x 上」那几条只是碰巧。
##   反向对照三 —— 藏掉读数区的 PanelShadow 叠层：右下那圈 NAVY_900 必须整体归零，
##                 而读数区自己的 BROWN_600 描边仍在（06 §2.2 v0.1.5 甲案：面板自身不带阴影）。
##
## 分工：本探针只量**真实渲染矩形**。布局算得对不对由 tests/unit/test_result.gd 覆盖，
## 交互（两个出口经 GameFlow、不自动推进）由 tests/integration/result_smoke.gd 覆盖。

extends RefCounted

const SCENE_PATH: String = "res://scenes/result/result.tscn"

## 画布 = 06 §1 的 320×180 基准（宽屏）与 180×320（窄屏），与布局常量同一坐标系。
const WIDE: Vector2i = Vector2i(320, 180)
const NARROW: Vector2i = Vector2i(180, 320)

## 扫描窗口：避开最外圈的面板框。外框是 PanelFrame（3px 木质描边 + BROWN_600 内带）
## 再叠 1px GOLD_200 左高光，所以 [4, 316) 里除了本界面自己的描边不该有第二种 BROWN_600。
const SCAN_LEFT: int = 4
const SCAN_RIGHT: int = 316

## PET-77：外框换成已批准切片后，窗口外那几列里也有 BROWN_600 —— 那是**框自己**的木质带。
## 逐像素读数（`ui_panel_frame_main_96x64`）：左带 4px = x0 BROWN_500 / x1..x2 BROWN_600 / x3 GOLD_200 高光；
## 右带 3px = x317..x318 BROWN_600 / x319 BROWN_500。窗口边界那两条断言据此改钉「只许这两条、且在此位置」。
const FRAME_LEFT_BAND: Array[int] = [1, 2]
const FRAME_RIGHT_BAND: Array[int] = [317, 318]
const SCAN_TOP: int = 4
const SCAN_BOTTOM: int = 316

## 06 §2.2：标题栏高 16px，底部 1px GOLD_600 分隔线。上沿在 y=8，故金线落在 y=23。
const TITLE_GOLD_ROW: int = 23
const WIDE_TITLE_GOLD: int = 304
const NARROW_TITLE_GOLD: int = 164

## 06 §1 / §2.2 下读数区（次级面板）的**实测**矩形与它那圈 1px BROWN_600。
## 刻意写死而不是由布局公式现算：探针要证的正是「公式的结果真的落在了这几个像素上」。
const WIDE_READOUT_TOP: int = 32
const WIDE_READOUT_BOTTOM: int = 119
const WIDE_READOUT_LEFT: int = 8
const WIDE_READOUT_RIGHT: int = 311
## 读数区内的扫描行：落在面板上沿之下、居中文字之上（文字块被 VBox 居中在 y≈57 起）。
const READOUT_SCAN_ROW: int = 36

## 两个出口的**实测**矩形（屏幕坐标）。按钮区在 y=128，按钮高 44。
const BUTTON_SCAN_ROW: int = 150
const WIDE_MENU_LEFT: int = 8
const WIDE_MENU_RIGHT: int = 155
const WIDE_RETRY_LEFT: int = 164
const WIDE_RETRY_RIGHT: int = 311
## 描边内缩 1px 后的实心块：x165..310（146）、y130..169（40）。
## PET-77：主按钮改用已批准切片 `ui_button_primary_*_64x20`，切片在 GOLD_500 填充之上
## 还各占 1px（上 = GOLD_600 描边之内的 GOLD_200 高光；下 = GOLD_600 描边之下的烘焙投影），
## 故填充块由 42 行收到 40 行 —— 按钮**盒子**仍是同一个 44px，见 BUTTON_CHROME。
const WIDE_RETRY_GOLD: Rect2i = Rect2i(165, 130, 146, 40)
## 描边内缩 1px 后的实心块上沿（两个出口同高）。
const BUTTON_FILL_TOP: int = 130
## 按钮盒子在填充之上额外占的行数（每侧 2：1px 描边 + 1px 高光 / 投影）。
## 总高 = 填充 40 + 2×2 = 44，正好是 06 §1 的触摸下限；这条换算就是 _probe_actions_wide() 末段的依据。
const BUTTON_CHROME: int = 2
## 出口按钮盒子的上下沿（屏幕坐标）：按钮区在 y=128、整高 44。
const BUTTON_BOX_TOP: int = 128
const BUTTON_BOX_BOTTOM: int = 171
## 两个出口之间那道 8px 空隙必须露出主面板底色。
const WIDE_GAP_LEFT: int = 156
const WIDE_GAP_RIGHT: int = 164

## 180×320 竖屏下读数区与两个出口的**实测**坐标。
const NARROW_SCAN_COL: int = 100
const NARROW_READOUT_TOP: int = 32
const NARROW_READOUT_BOTTOM: int = 207
const NARROW_READOUT_RIGHT: int = 171
const NARROW_MENU_TOP: int = 216
const NARROW_RETRY_TOP: int = 268
const NARROW_RETRY_GOLD: Rect2i = Rect2i(9, 270, 162, 40)
const NARROW_MENU_SCAN_ROW: int = 240

## 06 §1：可点击区域下限（设备像素）。实测填充块加两侧 BUTTON_CHROME 即按钮整高。
const MIN_TOUCH_SIZE: int = 44

## 反向对照的位移量。
const SHIFT: float = 4.0

var _h: RefCounted = null
var _tree: SceneTree = null
var _theme: Theme = null
var _scene: Control = null
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


## 组 11a：320×180 下读数区是一块 304×88 的次级面板（1px BROWN_600 描边、NAVY_800 内芯），
## 右下各外扩 1px NAVY_900 硬阴影（06 §2.2 阴影行 / v0.1.5 甲案），标题栏分隔线横贯 304px。
func _probe_readout_wide() -> void:
	var image: Image = await _open_scene(WIDE)
	if image == null:
		return

	var hits: Array[int] = _row_hits(image, READOUT_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _border)
	_h.check(hits == [WIDE_READOUT_LEFT, WIDE_READOUT_RIGHT],
		"第 %d 行应恰好在这 2 个 x 上是 BROWN_600：%s（实际 %s）" % [
			READOUT_SCAN_ROW, [WIDE_READOUT_LEFT, WIDE_READOUT_RIGHT], hits])
	_h.check(WIDE_READOUT_RIGHT - WIDE_READOUT_LEFT + 1 == 304, "读数区的内宽应为 304px")
	_h.check(WIDE_READOUT_BOTTOM - WIDE_READOUT_TOP + 1 == 88, "读数区的高应为 88px")
	_h.check(_h.count_row(image, WIDE_READOUT_TOP, SCAN_LEFT, SCAN_RIGHT, _border) == 304,
		"读数区上沿 y=%d 应整行是描边" % WIDE_READOUT_TOP)
	_h.check(_h.count_row(image, WIDE_READOUT_BOTTOM, SCAN_LEFT, SCAN_RIGHT, _border) == 304,
		"读数区下沿 y=%d 应整行是描边" % WIDE_READOUT_BOTTOM)
	_h.check(_h.count_col(image, WIDE_READOUT_LEFT, WIDE_READOUT_TOP, WIDE_READOUT_BOTTOM + 1, _border) == 88,
		"读数区左缘 x=%d 应整列是描边" % WIDE_READOUT_LEFT)
	_h.check(_h.count_col(image, WIDE_READOUT_RIGHT, WIDE_READOUT_TOP, WIDE_READOUT_BOTTOM + 1, _border) == 88,
		"读数区右缘 x=%d 应整列是描边" % WIDE_READOUT_RIGHT)

	# 硬阴影：右边是**列**（沿 y 走），下边是**行**（沿 x 走）。两者在方盒上数值相同，
	# 这里 304×88 宽高不等，参数写反了会当场红。
	_assert_readout_shadow(image, WIDE_READOUT_LEFT, WIDE_READOUT_TOP, WIDE_READOUT_RIGHT,
		WIDE_READOUT_BOTTOM, "320×180")

	_h.check(_h.count_row(image, TITLE_GOLD_ROW, 0, WIDE.x, _gold_edge) == WIDE_TITLE_GOLD,
		"标题栏分隔线应是第 %d 行上的整条 %dpx" % [TITLE_GOLD_ROW, WIDE_TITLE_GOLD])
	_h.check(_h.count_row(image, TITLE_GOLD_ROW - 1, 0, WIDE.x, _gold_edge) == 0
			and _h.count_row(image, TITLE_GOLD_ROW + 1, 0, WIDE.x, _gold_edge) == 0,
		"分隔线上下各一行都不许有金像素（厚 1px）")
	# 钉住扫描窗口的两条边界：窗口外（最外圈面板框那一带）只许出现**外框切片自己**那两条
	# BROWN_600 木质带，且必须落在固定列上 —— 否则上面那条「恰好 2 个」随时可能被外框顶掉。
	#
	# 原来钉：窗口外命中 0（旧外框是 StyleBoxFlat：3px 描边 + BROWN_500 填充，
	#         而窗口外那几列恰好落在填充上，所以当时确实是 0）。
	# 现在钉：命中数 == 2，且命中列 == 外框自带的那两条（左 x1/x2、右 x317/x318）。
	# 为什么是同一件事：这条要证的是「窗口外那几列只属于外框，不掺本界面自己的任何描边」。
	#   外框改用已批准切片后，切片在描边内侧多了一条 BROWN_600（旧 StyleBoxFlat 那里是填充），
	#   于是「0」这个数字不再成立；改钉「恰好 2 且位置固定」把同一件事证得更死 ——
	#   数量或位置任一变化（多一条、挪一列、本界面有描边漏出窗口）都会转红。
	var left_out: Array[int] = _row_hits(image, READOUT_SCAN_ROW, 0, SCAN_LEFT, _border)
	_h.check(left_out == FRAME_LEFT_BAND,
		"扫描窗口左侧（x< %d）应恰好是外框自带的那两条木质带 %s（实际 %s）" % [
			SCAN_LEFT, FRAME_LEFT_BAND, left_out])
	var right_out: Array[int] = _row_hits(image, READOUT_SCAN_ROW, SCAN_RIGHT, WIDE.x, _border)
	_h.check(right_out == FRAME_RIGHT_BAND,
		"扫描窗口右侧（x>= %d）应恰好是外框自带的那两条木质带 %s（实际 %s）" % [
			SCAN_RIGHT, FRAME_RIGHT_BAND, right_out])


## 组 11b：两个出口按钮的实心块 —— 主按钮 GOLD_500、次按钮 NAVY_700，各 148×44，
## 中间留 8px、两端各留 8px 安全边距；实测整高不得低于 06 §1 的 44 触摸下限。
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
	_h.check(_span_row(image, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _secondary)
			== [WIDE_MENU_LEFT + 1, WIDE_MENU_RIGHT - 1],
		"次按钮的实心块应恰好铺满 x%d..%d（实际 %s）" % [WIDE_MENU_LEFT + 1, WIDE_MENU_RIGHT - 1,
			_span_row(image, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _secondary)])
	var navy_hits: Array[int] = _row_hits(image, BUTTON_SCAN_ROW, SCAN_LEFT, SCAN_RIGHT, _secondary_edge)
	_h.check(navy_hits == [WIDE_MENU_LEFT, WIDE_MENU_RIGHT],
		"第 %d 行应恰好在这 2 个 x 上是次按钮描边 NAVY_600：%s（实际 %s）" % [
			BUTTON_SCAN_ROW, [WIDE_MENU_LEFT, WIDE_MENU_RIGHT], navy_hits])

	# 两个出口之间的空隙：8px，且必须是主面板底色 —— 露不出底色就说明两块连成了一片。
	_h.check(_h.count_row(image, BUTTON_SCAN_ROW, WIDE_GAP_LEFT, WIDE_GAP_RIGHT, _core)
			== WIDE_GAP_RIGHT - WIDE_GAP_LEFT,
		"两个出口之间应留 %dpx 主面板底色" % (WIDE_GAP_RIGHT - WIDE_GAP_LEFT))
	# 两端的安全边距由上面那两组描边坐标本身推出，不是另抄一份尺寸。
	_h.check(WIDE_MENU_LEFT == 8, "首个出口的左安全边距应为 8px（06 §1）")
	_h.check(WIDE.x - 1 - WIDE_RETRY_RIGHT == 8, "末个出口的右安全边距应为 8px（06 §1）")

	# 触摸下限：实测填充块高 40，加上下各 2px（描边 + 高光 / 投影）即按钮整高，必须 ≥ 44。
	# 原来用 `+ BUTTON_BORDER * 2`；PET-77 主按钮换成切片后非填充部分由 2px 变 4px，
	# 判据仍是「盒子整高 ≥ 44」，算式跟着换成 BUTTON_CHROME。
	var button_height: int = WIDE_RETRY_GOLD.size.y + BUTTON_CHROME * 2
	_h.check(button_height >= MIN_TOUCH_SIZE,
		"出口按钮实测整高 %dpx 不得低于 06 §1 的 %d 触摸下限" % [button_height, MIN_TOUCH_SIZE])
	# 原来钉：次按钮的 NAVY_700 填充块高 == 主按钮 GOLD_500 填充块高（两者都是 StyleBoxFlat，各 1px 描边）。
	# 现在钉：次按钮填充纵向**恰好比主按钮各多一行**（[129,170] vs [130,169]）—— 用首末命中表达。
	# 为什么是同一件事：这条要证的是「两个出口是同一个尺寸的盒子，没有一高一矮」。
	#   主按钮切片自带上下各 1px 的高光 / 投影，填充自然比次按钮矮 2px；盒子本身仍是同一个 44px。
	#   若两个盒子真的不等高，这个「各多一行」的关系会当场破裂，比原来的「相等」判别力更强。
	var menu_fill: Array = _span_col(image, WIDE_MENU_LEFT + 1, BUTTON_BOX_TOP,
		BUTTON_BOX_BOTTOM + 1, _secondary)
	_h.check(menu_fill == [WIDE_RETRY_GOLD.position.y - 1, WIDE_RETRY_GOLD.end.y],
		"次按钮的填充块应恰好比主按钮上下各多一行（期望 %s，实际 %s）" % [
			[WIDE_RETRY_GOLD.position.y - 1, WIDE_RETRY_GOLD.end.y], menu_fill])


## 组 11c：180×320 竖屏下两个出口改竖排 —— 同处一列、自上而下、仍贴底部安全线。
func _probe_narrow() -> void:
	var image: Image = await _open_scene(NARROW)
	if image == null:
		return

	var hits: Array[int] = _col_hits(image, NARROW_SCAN_COL, SCAN_TOP, SCAN_BOTTOM, _border)
	_h.check(hits == [NARROW_READOUT_TOP, NARROW_READOUT_BOTTOM],
		"第 %d 列应恰好在这 2 个 y 上是读数区描边：%s（实际 %s）" % [
			NARROW_SCAN_COL, [NARROW_READOUT_TOP, NARROW_READOUT_BOTTOM], hits])
	_h.check(_h.count_row(image, NARROW_READOUT_TOP, SCAN_LEFT, 176, _border) == 164
			and _h.count_row(image, NARROW_READOUT_BOTTOM, SCAN_LEFT, 176, _border) == 164,
		"折叠后读数区应铺满可用宽（164px）")
	_assert_readout_shadow(image, 8, NARROW_READOUT_TOP, NARROW_READOUT_RIGHT,
		NARROW_READOUT_BOTTOM, "180×320")
	_h.check(_h.count_row(image, TITLE_GOLD_ROW, 0, NARROW.x, _gold_edge) == NARROW_TITLE_GOLD,
		"标题栏分隔线应随可用宽收窄到 %dpx" % NARROW_TITLE_GOLD)

	# 折叠的形态由「同 x、递增 y」证明，而不是由某个宽高数字证明。
	_h.check(_span_col(image, NARROW_SCAN_COL, NARROW_MENU_TOP, NARROW_MENU_TOP + 44, _secondary)
			== [NARROW_MENU_TOP + 1, NARROW_MENU_TOP + 42],
		"次按钮应落在 y%d 起的那一段（实际 %s）" % [NARROW_MENU_TOP,
			_span_col(image, NARROW_SCAN_COL, NARROW_MENU_TOP, NARROW_MENU_TOP + 44, _secondary)])
	var gold: Dictionary = _measure(image, _gold)
	_h.check(gold["box"] == NARROW_RETRY_GOLD,
		"主按钮的实心块应落在 %s（实际 %s）" % [NARROW_RETRY_GOLD, gold["box"]])
	_h.check(NARROW_MENU_TOP - (NARROW_READOUT_BOTTOM + 1) == 8,
		"读数区与按钮区之间应隔 8px（%d → %d）" % [NARROW_READOUT_BOTTOM, NARROW_MENU_TOP])
	_h.check(NARROW_RETRY_TOP - (NARROW_MENU_TOP + 44) == 8, "两个出口之间应隔 8px")
	_h.check(NARROW.y - 1 - (NARROW_RETRY_TOP + 43) == 8, "末个出口应贴底部安全线")
	_h.check(_span_row(image, NARROW_MENU_SCAN_ROW, SCAN_LEFT, 176, _secondary) == [9, 170],
		"折叠后次按钮的实心块宽应铺满可用宽（x9..170，实际 %s）" % [
			_span_row(image, NARROW_MENU_SCAN_ROW, SCAN_LEFT, 176, _secondary)])


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

	# 反向对照二：整体右移 4px，实心块必须整体跟着走。
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
	_h.check(_h.count_col(no_shadow, WIDE_READOUT_RIGHT + 1, WIDE_READOUT_TOP,
			WIDE_READOUT_BOTTOM + 2, _shadow) == 0
			and _h.count_row(no_shadow, WIDE_READOUT_BOTTOM + 1, WIDE_READOUT_LEFT,
				WIDE_READOUT_RIGHT + 2, _shadow) == 0,
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


## 读数区的硬阴影契约：右边一列、下边一行各外扩 1px，上 / 左没有。
## 总阴影数由几何推出（w + h + 1，右下角点只画一次），不是抄来的魔数。
func _assert_readout_shadow(image: Image, left: int, top: int, right: int, bottom: int,
		label: String) -> void:
	var width: int = right - left + 1
	var height: int = bottom - top + 1
	_h.check(_h.count_col(image, right + 1, top, bottom + 2, _shadow) == height + 1,
		"%s：读数区右边应外扩 1px NAVY_900，共 %d 个" % [label, height + 1])
	_h.check(_h.count_row(image, bottom + 1, left, right + 2, _shadow) == width + 1,
		"%s：读数区下边应外扩 1px NAVY_900，共 %d 个" % [label, width + 1])
	_h.check(_h.count_row(image, top - 1, left, right + 1, _shadow) == 0,
		"%s：读数区上边不得有阴影" % label)
	_h.check(_h.count_col(image, left - 1, top, bottom + 1, _shadow) == 0,
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
