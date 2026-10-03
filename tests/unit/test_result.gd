## test_result.gd
## 职责：RESULT 场景的**布局数值**与**静态装配**是否落在 03 §1 状态图 / 06 §1·§2·§3 / 04 §5.1 上
##       （路由登记、标题栏与读数区与按钮区的矩形、两个读数的落点、触摸下限、
##       无字面色值、无计时器构造、无玩法统计）。
## 所属系统：tests
## 依赖：test_context, scripts/ui/result_layout.gd, scripts/core/game_flow.gd
## 禁止：本文件不得硬编码色值；不得依赖执行顺序。
##
## 分工：本用例只查「布局算出了什么、场景装配成了什么」，**不查交互** ——
## 经 GameFlow 路由进入、两个出口是否真的走得掉、停留不自动推进，都要真实状态机，
## 归 tests/integration/result_smoke.gd 独立进程；真实渲染矩形归 tests/unit/result_probe.gd。
## 这里 instantiate() 但**不入树**：不入树就不触发 _ready()，也就不会惊动 GameFlow / RunState。

extends RefCounted

const SCENE_PATH: String = "res://scenes/result/result.tscn"
const SCREEN_SCRIPT_PATH: String = "res://scripts/ui/result_screen.gd"
const LAYOUT_SCRIPT_PATH: String = "res://scripts/ui/result_layout.gd"
const FLOW_SCRIPT_PATH: String = "res://scripts/core/game_flow.gd"
const PALETTE_SCRIPT_PATH: String = "res://scripts/data/palette.gd"
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"
const THEME_PATH: String = "res://assets/ui/theme_main.tres"

## 06 §1 基准与 §7.1 的窄屏取样。
const REFERENCE_VIEWPORT: Vector2 = Vector2(320.0, 180.0)
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)
const SHORT_NARROW_VIEWPORT: Vector2 = Vector2(120.0, 180.0)

## 06 没有 RESULT 版面，未给实测矩形；下面是本文件**独立复写**的期望值，
## 刻意不从 ResultLayout 取 —— 测试若与被测实现同源，实现里把 148 写成 138 时
## 两边一起错，断言就永远是绿的。推导依据见 result_layout.gd 的文件头。
const TITLE_RECT: Rect2 = Rect2(8.0, 8.0, 304.0, 16.0)
const READOUT_RECT: Rect2 = Rect2(8.0, 32.0, 304.0, 88.0)
const ACTIONS_RECT: Rect2 = Rect2(8.0, 128.0, 304.0, 44.0)
## 两个出口的矩形**相对按钮区原点**（按钮是按钮区的子节点）。顺序即场景节点顺序。
const ACTION_RECTS: Array[Rect2] = [
	Rect2(0.0, 0.0, 148.0, 44.0),
	Rect2(156.0, 0.0, 148.0, 44.0),
]
const NARROW_TITLE_RECT: Rect2 = Rect2(8.0, 8.0, 164.0, 16.0)
const NARROW_READOUT_RECT: Rect2 = Rect2(8.0, 32.0, 164.0, 176.0)
const NARROW_ACTIONS_RECT: Rect2 = Rect2(8.0, 216.0, 164.0, 96.0)
const NARROW_ACTION_RECTS: Array[Rect2] = [
	Rect2(0.0, 0.0, 164.0, 44.0),
	Rect2(0.0, 52.0, 164.0, 44.0),
]

## 06 §1：可点击区域下限。两个出口按钮在两种读法下都不得低于该值。
const MIN_TOUCH_SIZE: float = 44.0

## 节点名。顺序即 ResultLayout.action_rects() 的顺序：0 = 返回主菜单，1 = 再来一局。
const ACTION_NAMES: PackedStringArray = ["ButtonMenu", "ButtonRetry"]
## 两个出口的 tr() key（06 §11）。逐字对验收里的措辞。
const ACTION_TEXTS: PackedStringArray = ["返回主菜单", "再来一局"]

## 03 §2 / 06 §10.1：RESULT 不得存在任何会自动推进的构造。
const BANNED_TIMING_TOKENS: PackedStringArray = [
	"Timer", "create_timer", "_process", "_physics_process", "timeout", "wait_time", "autostart",
]

## Stage 4 的 S4-08 才允许出现的词。本批只做骨架，实现里出现任何一个都说明越界了。
const STAGE4_TOKENS: PackedStringArray = [
	"score", "SCORE", "drop_pool", "DROP_POOL", "rarity", "RARITY", "meta_progression",
]

## 两个读数各自的格式串（06 §11 的 tr() key）。这里的期望值是**逐字复写**的。
const WAVE_FORMAT_KEY: String = "坚持到第 %d 波"
const SEED_FORMAT_KEY: String = "随机种子 %d"


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_route_checks(ctx)
	_run_source_checks(ctx)
	_run_layout_checks(ctx)
	_run_narrow_layout_checks(ctx)
	_run_touch_size_checks(ctx)
	_run_readout_checks(ctx)
	_run_button_theme_checks(ctx)

	var resource: Resource = ResourceLoader.load(SCENE_PATH)
	if not ctx.check(resource is PackedScene, "result.tscn 应能加载为 PackedScene"):
		return
	_run_structure_checks(ctx, resource)


## 场景必须由 GameFlow 的路由表指到，否则 03 §1.1 R3 的唯一路由来源就断在这条边上。
func _run_route_checks(ctx: RefCounted) -> void:
	ctx.begin_case("RESULT · 路由登记（03 §1.1 R3）")
	var flow_script: GDScript = load(FLOW_SCRIPT_PATH)
	if not ctx.check(flow_script != null, "game_flow.gd 应能加载"):
		return
	var route: Variant = flow_script.SCENE_ROUTES.get(flow_script.GameState.RESULT, null)
	if not ctx.check(route != null, "GameFlow 应登记 RESULT 的路由"):
		return
	ctx.equal(String(route["path"]), SCENE_PATH, "RESULT 路由路径")
	ctx.equal(String(route["task"]), "S1-10", "RESULT 路由归属任务")
	ctx.check(ResourceLoader.exists(SCENE_PATH), "路由指向的场景文件必须真实存在")
	# 03 §1 状态图：RESULT 的两个出口是 MAIN_MENU 与 PREPARATION，且 **RESULT 不是起点** ——
	# 它只能被 COMBAT（核心被摧毁）或 PREPARATION（主动结束本局）推进来。
	ctx.equal(flow_script.ALLOWED_TRANSITIONS[flow_script.GameState.RESULT],
		[flow_script.GameState.MAIN_MENU, flow_script.GameState.PREPARATION],
		"RESULT 只允许走向 MAIN_MENU 与 PREPARATION")
	ctx.check(flow_script.ALLOWED_TRANSITIONS[flow_script.GameState.COMBAT].has(flow_script.GameState.RESULT),
		"03 §1.1 R2：COMBAT 应能走向 RESULT（核心被摧毁 / 本局结束）")
	ctx.check(not flow_script.ALLOWED_TRANSITIONS[flow_script.GameState.MAIN_MENU].has(
		flow_script.GameState.RESULT), "03 §1 状态图：MAIN_MENU 不得直接跳到 RESULT")


## 04 §6 / 06 §10.7：色值只能来自 Palette；03 §2：不得有任何自动推进的构造。
##
## 顺带钉一条编译检查：脚本编译失败时 .tscn 仍能实例化出节点，下面那些结构断言会**一片全绿**
## 而游戏里跑的是空脚本（S1-06 与 S1-07 各踩过一次）。
func _run_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("RESULT · 无字面色值（06 §10.7）")
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH, SCENE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		if not ctx.check(not source.is_empty(), "%s 应能读取" % path):
			continue
		ctx.check(not source.contains("Color("), "%s 不得出现 Color(...) 字面量" % path)
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH]:
		var script: GDScript = load(path)
		ctx.check(script != null and script.can_instantiate(), "%s 应能编译" % path)

	ctx.begin_case("RESULT · 不得自动推进：无任何计时器（03 §2 / 00 §5）")
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH]:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token: String in BANNED_TIMING_TOKENS:
			ctx.check(not code.contains(token), "%s 的代码中不得出现 `%s`" % [path.get_file(), token])

	ctx.begin_case("RESULT · 不得越界到 Stage 4 的玩法统计（S4-08）")
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH]:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token: String in STAGE4_TOKENS:
			ctx.check(not code.contains(token), "%s 的代码中不得出现 `%s`" % [path.get_file(), token])

	ctx.begin_case("RESULT · 场景路由的唯一落点（03 §1.1 R3）")
	ctx.check(not _strip_comments(FileAccess.get_file_as_string(SCREEN_SCRIPT_PATH))
		.contains("change_scene_to_file"), "result_screen.gd 不得自行换场景")
	# 03 §6：种子由 RunState 逐局记录，结算界面**读**它 —— 不另建第二份来源。
	ctx.check(_strip_comments(FileAccess.get_file_as_string(SCREEN_SCRIPT_PATH))
		.contains("RunState.get_run_seed()"), "result_screen.gd 的种子读数应取自 RunState（03 §6）")


## 06 §1 的基准尺寸下的三段版面：标题栏、读数区、两个出口。
func _run_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("RESULT · 标题栏 / 读数区 / 出口的矩形（06 §1）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "result_layout.gd 应能加载"):
		return
	ctx.check(not layout.is_narrow(REFERENCE_VIEWPORT), "320×180 基准应判定为宽屏")

	ctx.equal(layout.title_rect(REFERENCE_VIEWPORT), TITLE_RECT, "标题栏矩形")
	ctx.equal(layout.readout_rect(REFERENCE_VIEWPORT), READOUT_RECT, "读数区矩形")
	ctx.equal(layout.actions_rect(REFERENCE_VIEWPORT), ACTIONS_RECT, "出口按钮区矩形")

	var rects: Array[Rect2] = layout.action_rects(REFERENCE_VIEWPORT)
	if not ctx.check(rects.size() == ACTION_RECTS.size(), "验收：应给出 2 个出口"):
		return
	for index: int in ACTION_RECTS.size():
		ctx.equal(rects[index], ACTION_RECTS[index], "%s 的矩形" % ACTION_NAMES[index])

	# 几何关系（由规范推出，不是抄来的魔数）：两端各留 8 安全边距、间距 8、贴底部安全线。
	# 按钮矩形以**按钮区原点**为基准，故安全边距要加回按钮区自己的位置才是屏幕坐标。
	var gap: float = rects[1].position.x - rects[0].end.x
	ctx.equal(gap, 8.0, "两个出口之间的间距（06 §1 间距刻度）")
	ctx.equal(ACTIONS_RECT.position.x + rects[0].position.x, 8.0, "首按钮的左安全边距（06 §1）")
	ctx.equal(ACTIONS_RECT.position.x + rects[1].end.x, REFERENCE_VIEWPORT.x - 8.0,
		"末按钮的右安全边距（06 §1）")
	ctx.equal(rects[0].size.x, rects[1].size.x, "两个出口必须等宽")
	ctx.equal(rects[0].position.y, rects[1].position.y, "两个出口必须同高同起点")
	ctx.equal(ACTIONS_RECT.end.y, REFERENCE_VIEWPORT.y - 8.0, "出口按钮区应贴底部安全线")
	ctx.equal(TITLE_RECT.end.y + gap, READOUT_RECT.position.y, "标题栏与读数区之间隔一个间距")
	ctx.equal(READOUT_RECT.end.y + gap, ACTIONS_RECT.position.y, "读数区与按钮区之间隔一个间距")
	# 三个分段自上而下铺满安全区，段间不留缝 —— 中间漏一段会露出一整条主面板底色。
	ctx.equal(READOUT_RECT.position.x, TITLE_RECT.position.x, "三段应左对齐")
	ctx.equal(READOUT_RECT.end.x, TITLE_RECT.end.x, "三段应右对齐")
	ctx.equal(ACTIONS_RECT.position.x, TITLE_RECT.position.x, "三段应左对齐")


## 06 §7.1 的移动端折叠：两个出口由横排改竖排。折叠只改变布局，不改变任何玩法规则与状态流。
func _run_narrow_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("RESULT · 窄屏折叠（06 §7.1）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "result_layout.gd 应能加载"):
		return

	ctx.check(layout.is_narrow(NARROW_VIEWPORT), "180×320 竖屏应判定为窄屏")
	ctx.check(not layout.is_narrow(REFERENCE_VIEWPORT), "320×180 基准应判定为宽屏")
	ctx.check(not layout.is_narrow(Vector2(320.0, 320.0)), "1:1 应判定为宽屏（判定是 < 而非 <=）")
	ctx.check(not layout.is_narrow(Vector2.ZERO), "拿不到尺寸时应按宽屏处理，不得随手折叠")

	_check_rect_approx(ctx, layout.title_rect(NARROW_VIEWPORT), NARROW_TITLE_RECT, "窄屏标题栏矩形")
	_check_rect_approx(ctx, layout.readout_rect(NARROW_VIEWPORT), NARROW_READOUT_RECT, "窄屏读数区矩形")
	_check_rect_approx(ctx, layout.actions_rect(NARROW_VIEWPORT), NARROW_ACTIONS_RECT, "窄屏按钮区矩形")

	var rects: Array[Rect2] = layout.action_rects(NARROW_VIEWPORT)
	if not ctx.check(rects.size() == NARROW_ACTION_RECTS.size(), "窄屏同样应给出 2 个出口"):
		return
	for index: int in NARROW_ACTION_RECTS.size():
		_check_rect_approx(ctx, rects[index], NARROW_ACTION_RECTS[index],
			"%s 的折叠矩形" % ACTION_NAMES[index])

	# 折叠的形态由「同 x、递增 y」证明，而不是由某个宽高数字证明。
	ctx.equal(rects[0].position.x, rects[1].position.x, "折叠后两个出口应同处一列")
	ctx.check(rects[0].end.y <= rects[1].position.y, "折叠后两个出口应自上而下依次排列且不重叠")
	ctx.equal(rects[1].position.y - rects[0].end.y, 8.0, "折叠后的行间距（06 §1）")
	ctx.equal(rects[0].size.x, NARROW_ACTIONS_RECT.size.x, "折叠后按钮应铺满可用宽")
	ctx.equal(NARROW_ACTIONS_RECT.end.y, NARROW_VIEWPORT.y - 8.0, "折叠后按钮区仍贴底部安全线")


## 06 §1：可点击区域 —— 两个出口本身就是可点击区域，任何档位下都不得低于下限。
##
## 06 §1 的下限是按**设备像素**写的（≥44），而布局用的是逻辑像素，最小缩放 2×。
## 故这里同时钉住两件事：实现取的逻辑值 ≥44（两种读法下都达标），
## 以及「44 逻辑 × 2× ≥ 44 设备」这条推导本身成立 —— 后者一旦不成立，前者就不再是安全余量。
func _run_touch_size_checks(ctx: RefCounted) -> void:
	ctx.begin_case("RESULT · 出口可点击区域 ≥ 44（06 §1）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "result_layout.gd 应能加载"):
		return

	ctx.check(layout.MIN_TOUCH_SIZE * layout.MIN_SCALE >= layout.MIN_TOUCH_DEVICE_PIXELS,
		"触摸下限的换算应成立：%s 逻辑 × %s 倍 ≥ %s 设备像素" % [
			layout.MIN_TOUCH_SIZE, layout.MIN_SCALE, layout.MIN_TOUCH_DEVICE_PIXELS])
	for viewport: Vector2 in [REFERENCE_VIEWPORT, NARROW_VIEWPORT, SHORT_NARROW_VIEWPORT]:
		_check_touch_and_degenerate(ctx, layout, viewport)


## 一个档位下的两件事：出口不得低于触摸下限；退化尺寸下也不得算出负矩形。
##
## 两者会互相拉扯 —— 竖屏一矮，固定 96 高的按钮区就往上顶，读数区被压薄
## （SHORT_NARROW_VIEWPORT 的 120×180 下只剩 36px，宽屏是 88px）；再矮下去余量转负，
## 实现的选择是把它夹到 0（宁可压掉读数区，也不缩按钮到点不准，同 RewardLayout 的取舍）。
## 这条把该取舍钉住：按钮守住下限，读数区不出现负尺寸。
func _check_touch_and_degenerate(ctx: RefCounted, layout: GDScript, viewport: Vector2) -> void:
	var rects: Array[Rect2] = layout.action_rects(viewport)
	var bad: int = 0
	for rect: Rect2 in rects:
		if rect.size.x < MIN_TOUCH_SIZE or rect.size.y < MIN_TOUCH_SIZE:
			bad += 1
	ctx.check(bad == 0, "%s 下两个出口都不得低于 %d×%d（违例 %d 个，实得 %s）" % [
		viewport, int(MIN_TOUCH_SIZE), int(MIN_TOUCH_SIZE), bad, str(rects[0].size)])
	var actions: Rect2 = layout.actions_rect(viewport)
	ctx.check(actions.size.y > 0.0 and layout.readout_rect(viewport).size.y >= 0.0,
		"%s 下读数区与按钮区都不得是负矩形（按钮区 %s）" % [viewport, str(actions.size)])


## 验收第一条：至少要能显示「坚持到第几波」与「随机种子」两个落点。
## 格式串、占位读数与读入口都在这里钉住；「真的显示在界面上」由冒烟与像素探针分别负责。
func _run_readout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("RESULT · 两个读数落点（03 §6 / 验收第 1 条）")
	var screen_script: GDScript = load(SCREEN_SCRIPT_PATH)
	if not ctx.check(screen_script != null, "result_screen.gd 应能加载"):
		return

	ctx.equal(screen_script.WAVE_FORMAT_KEY, WAVE_FORMAT_KEY, "波次读数的 tr() key")
	ctx.equal(screen_script.SEED_FORMAT_KEY, SEED_FORMAT_KEY, "种子读数的 tr() key")
	# 本阶段没有翻译表，tr() 原样返回 key，故代入后的成品串就是这两条。
	ctx.equal(screen_script.WAVE_FORMAT_KEY % 3, "坚持到第 3 波", "波次读数代入后的成品串")
	ctx.equal(screen_script.SEED_FORMAT_KEY % 12345, "随机种子 12345", "种子读数代入后的成品串")
	# 波次数据要等 Stage 4 的 S4-08，本批只给占位 —— 但占位值必须是可显示的读数，不是 0 或 -1。
	ctx.check(int(screen_script.WAVE_PLACEHOLDER) >= 1,
		"占位波次应是可显示的读数（实际 %s）" % screen_script.WAVE_PLACEHOLDER)

	for method: String in ["set_result", "get_wave_reached", "get_run_seed_displayed",
			"apply_layout_for", "is_narrow_layout"]:
		ctx.check(_has_method(screen_script, method), "result_screen.gd 应提供 %s()" % method)


## 06 §3：主要按钮 = 默认 Button（GOLD 五态），次要按钮 = ButtonSecondary（NAVY_700 系），
## 且 Disabled 底色必须落在 NAVY_800 上 —— 04 §5.1：GREY_500 在 NAVY_700 上仅 3.84:1（不达标），
## 在 NAVY_800 上 4.80:1（达标）。验收点名的就是这一条。
##
## 这里查的是 Theme 资源本身：控件上的**解析结果**（含 ButtonSecondary 的变体回退）
## 由 tests/integration/result_smoke.gd 在真实场景树里断言，两处合起来才是完整证据链。
func _run_button_theme_checks(ctx: RefCounted) -> void:
	ctx.begin_case("RESULT · 按钮五态的取色来源（06 §3 / 04 §5.1）")
	var palette: GDScript = load(PALETTE_SCRIPT_PATH)
	var theme_script: GDScript = load(THEME_SCRIPT_PATH)
	var theme_resource: Theme = ResourceLoader.load(THEME_PATH)
	if not ctx.check(palette != null and theme_script != null and theme_resource != null,
			"palette.gd / palette_theme.gd / theme_main.tres 应能加载"):
		return

	var disabled: StyleBox = theme_resource.get_stylebox(&"disabled", &"Button")
	if not ctx.check(disabled != null, "Theme 应为 Button 定义 Disabled 态"):
		return
	ctx.equal(disabled.bg_color, palette.get_color(palette.Key.NAVY_800), "Disabled 底色（06 §3）")
	ctx.equal(theme_resource.get_stylebox(&"normal", &"Button").bg_color,
		palette.get_color(palette.Key.GOLD_500), "Normal 底色（06 §3）")
	# 次要按钮**不得**另设 Disabled 底色：一旦另设，就会绕开 06 §3 钉死的 NAVY_800。
	ctx.check(not theme_resource.has_stylebox(&"disabled", theme_script.TYPE_BUTTON_SECONDARY),
		"次要按钮不得覆盖 Disabled 态（否则会绕开 04 §5.1 的 NAVY_800 结论）")


func _run_structure_checks(ctx: RefCounted, packed: PackedScene) -> void:
	ctx.begin_case("RESULT · 结算界面的装配（验收第 1、2 条）")
	var scene: Node = packed.instantiate()
	if not ctx.check(scene != null, "result.tscn 应能实例化"):
		return
	ctx.check(_find(scene, "Backdrop") != null, "应有全屏底色层（色值在 _ready() 里取自 Palette）")
	ctx.check(_find(scene, "NoticePanel") != null, "应有路由故障时的提示落点")

	_check_literals(ctx, scene, "TitleBar", TITLE_RECT)
	_check_literals(ctx, scene, "ReadoutPanel", READOUT_RECT)
	_check_literals(ctx, scene, "Actions", ACTIONS_RECT)

	_check_readout_panel(ctx, scene)
	# 按钮区自己不吃点击：按钮之间的缝隙不该被它截住（截住也只是白点一下，但语义要清楚）。
	var actions: Control = _find(scene, "Actions") as Control
	if ctx.check(actions != null, "应有两个出口的容器"):
		ctx.equal(actions.mouse_filter, Control.MOUSE_FILTER_IGNORE, "按钮区自身不得吃掉点击")

	var buttons: Array[Button] = []
	_collect_buttons(scene, buttons)
	ctx.equal(buttons.size(), ACTION_NAMES.size(), "验收第 2 条：恰好两个出口（实际 %d 个）" % buttons.size())
	for index: int in mini(buttons.size(), ACTION_NAMES.size()):
		_check_action(ctx, actions, buttons[index], index)
	scene.free()


## 验收第 1 条的两个落点：读数区是一块次级面板（06 §2.2），里面两行文字各占一个展示位。
func _check_readout_panel(ctx: RefCounted, scene: Node) -> void:
	var panel: Panel = _find(scene, "ReadoutPanel") as Panel
	if not ctx.check(panel != null, "应有读数区面板"):
		return
	ctx.equal(panel.theme_type_variation, &"PanelSecondary", "读数区应走次级面板变体（06 §2.2）")
	ctx.equal(panel.mouse_filter, Control.MOUSE_FILTER_IGNORE, "读数区不得吃掉点击")
	# 06 §2.2 尺寸表：次级面板同样带右下一 px 硬阴影，由场景叠一层 PanelShadow 承载（v0.1.5 裁定）。
	var shadow: Panel = _find(panel, "Shadow") as Panel
	if ctx.check(shadow != null, "读数区应带 PanelShadow 叠层（06 §2.2 阴影行 / v0.1.5 甲案）"):
		ctx.equal(shadow.theme_type_variation, &"PanelShadow", "阴影叠层的变体")
		ctx.equal(shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "阴影叠层不得吃掉点击")

	# 06 §2.2：次级面板内边距 8px。内容不能贴到描边上。
	var body: Control = _find(panel, "Body") as Control
	if not ctx.check(body != null, "读数区应有内容容器"):
		return
	ctx.equal(body.offset_left, 8.0, "次级面板内边距（06 §2.2）")
	ctx.equal(body.offset_top, 8.0, "次级面板内边距（06 §2.2）")
	ctx.equal(body.offset_right, -8.0, "次级面板内边距（06 §2.2）")
	ctx.equal(body.offset_bottom, -8.0, "次级面板内边距（06 §2.2）")

	var wave: Label = _find(panel, "WaveValue") as Label
	var seed_label: Label = _find(panel, "SeedValue") as Label
	if not ctx.check(wave != null and seed_label != null, "读数区应有两个读数的落点"):
		return
	ctx.check(not wave.text.is_empty(), "「坚持到第几波」必须有文字落点")
	ctx.check(not seed_label.text.is_empty(), "「随机种子」必须有文字落点（03 §6）")
	ctx.equal(wave.get_theme_font_size(&"font_size"), 16, "主读数是标题级字号（06 §1：标题 ≥12px）")
	ctx.equal(seed_label.theme_type_variation, &"LabelSecondary", "种子是次要读数（06 §3 辅助文字）")
	# 两个读数都不吃点击 —— 读数区整块是只读的。
	ctx.equal(wave.mouse_filter, Control.MOUSE_FILTER_IGNORE, "主读数不得吃掉点击")
	ctx.equal(seed_label.mouse_filter, Control.MOUSE_FILTER_IGNORE, "次读数不得吃掉点击")


## 出口按钮：矩形、节点名、文案、鼠标过滤、触摸下限，逐项对验收第 2 条。
func _check_action(ctx: RefCounted, actions: Control, button: Button, index: int) -> void:
	ctx.equal(String(button.name), ACTION_NAMES[index], "第 %d 个出口的节点名" % (index + 1))
	ctx.equal(button.text, ACTION_TEXTS[index], "%s 的文案（验收逐字）" % ACTION_NAMES[index])
	ctx.check(not button.disabled, "%s 是出口，不得默认禁用" % ACTION_NAMES[index])
	ctx.equal(button.mouse_filter, Control.MOUSE_FILTER_STOP,
		"%s 必须收点击 —— 它的整个矩形就是 06 §1 说的可点击区域" % ACTION_NAMES[index])
	_check_literals(ctx, button, "", ACTION_RECTS[index], true)
	ctx.check(button.size.x >= MIN_TOUCH_SIZE and button.size.y >= MIN_TOUCH_SIZE,
		"%s 的可点击区域不得低于 %d×%d（实际 %s）" % [
			ACTION_NAMES[index], int(MIN_TOUCH_SIZE), int(MIN_TOUCH_SIZE), str(button.size)])
	ctx.equal(button.get_parent(), actions, "%s 应是按钮区的子节点" % ACTION_NAMES[index])

	# 06 §3：主要按钮走默认 Button（GOLD），次要按钮走 ButtonSecondary（NAVY_700）。
	var expected: StringName = &"" if index == 1 else &"ButtonSecondary"
	ctx.equal(button.theme_type_variation, expected,
		"%s 的按钮变体（06 §3：主要 = 默认 GOLD，次要 = 辅助）" % ACTION_NAMES[index])


## .tscn 里的 offset 只能是字面量，这里拿规范值与常量核对它 —— 两边一旦漂开就不再是「一处定义」。
## local=true 时按「相对父节点」比对（出口按钮是按钮区的子节点）。
func _check_literals(ctx: RefCounted, scene: Node, node_name: String, expected: Rect2,
		local: bool = false) -> void:
	var control: Control = (scene if node_name.is_empty() else _find(scene, node_name)) as Control
	if not ctx.check(control != null, "场景应有 %s 节点" % node_name):
		return
	var label: String = node_name if not node_name.is_empty() else String(control.name)
	var offset: Vector2 = Vector2(control.offset_left, control.offset_top)
	if not local:
		ctx.equal(offset, expected.position, "%s 的 offset 左上角" % label)
	else:
		ctx.equal(offset, expected.position, "%s 的 offset 左上角（相对按钮区）" % label)
	ctx.equal(Vector2(control.offset_right, control.offset_bottom), expected.end, "%s 的 offset 右下角" % label)


func _has_method(script: GDScript, method: String) -> bool:
	for info: Dictionary in script.get_script_method_list():
		if String(info["name"]) == method:
			return true
	return false


func _collect_buttons(node: Node, found: Array[Button]) -> void:
	var button: Button = node as Button
	if button != null:
		found.append(button)
	for child: Node in node.get_children():
		_collect_buttons(child, found)


## 去掉注释再扫描：本仓库的文档注释里大量提到被禁的构造（正是为了声明「不许用」），
## 直接全文匹配会把「写明禁令」误判成「违反禁令」。同 test_reward.gd 的 _strip_comments。
func _strip_comments(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		var quote: String = ""
		var cut: int = line.length()
		for index: int in line.length():
			var character: String = line[index]
			if not quote.is_empty():
				if character == quote:
					quote = ""
			elif character == "\"" or character == "'":
				quote = character
			elif character == "#":
				cut = index
				break
		kept.append(line.substr(0, cut))
	return "\n".join(kept)


## 折叠后的矩形含 1/3 这类除不尽的比值，逐分量按近似比较。
func _check_rect_approx(ctx: RefCounted, actual: Rect2, expected: Rect2, label: String) -> void:
	var ok: bool = actual.position.is_equal_approx(expected.position) \
		and actual.size.is_equal_approx(expected.size)
	ctx.check(ok, "%s（期望 %s，实际 %s）" % [label, expected, actual])


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)
