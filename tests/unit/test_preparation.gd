## test_preparation.gd
## 职责：PREPARATION 场景的**布局数值**与**静态装配**是否落在 06 §7 / §7.1 的规格上
##       （路由登记、五分区矩形、CTA 唯一性、窄屏折叠、无字面色值、无计时器构造）。
## 所属系统：tests
## 依赖：test_context, scripts/ui/preparation_layout.gd, scripts/core/game_flow.gd
## 禁止：本文件不得硬编码色值；不得依赖执行顺序。
##
## 分工：本用例只查「布局算出了什么、场景装配成了什么」，**不查交互** ——
## 经 GameFlow 路由进入、点击后的提示路径、停留 10 分钟不自动推进，都要真实状态机，
## 归 tests/integration/preparation_smoke.gd 独立进程。
## 这里 instantiate() 但**不入树**：不入树就不触发 _ready()，也就不会惊动 GameFlow。

extends RefCounted

const SCENE_PATH: String = "res://scenes/preparation/preparation.tscn"
const SCREEN_SCRIPT_PATH: String = "res://scripts/ui/preparation_screen.gd"
const LAYOUT_SCRIPT_PATH: String = "res://scripts/ui/preparation_layout.gd"
const GAME_FLOW_SCRIPT_PATH: String = "res://scripts/core/game_flow.gd"

## 06 §7 对 Reference B 的实测值，在本文件**独立复写一遍**。刻意不从 PreparationLayout 取：
## 测试若与被测实现同源，实现里把 88 写成 98 时两边一起错，断言就永远是绿的。
## 规范 / 常量 / .tscn 字面量三处必须同时对得上 —— 这正是 06 §2.2 裁定③要的联动。
## PET-80：基准画布 320×180 → 640×360，§7 的实测读数**逐项 ×2**。
## 改动前的原始读数（就是下面这些数 ÷2）：(15,8,73,124) / (98,8,128,124) / (226,8,83,124)
## / (15,132,294,48) / (246,148,64,14)。
const EXPECTED_WIDE: Array[Rect2] = [
	Rect2(30.0, 16.0, 146.0, 248.0),
	Rect2(196.0, 16.0, 256.0, 248.0),
	Rect2(452.0, 16.0, 166.0, 248.0),
	Rect2(30.0, 264.0, 588.0, 96.0),
	Rect2(492.0, 296.0, 128.0, 28.0),
]

## 分区节点名，下标即 PreparationLayout.Region。枚举顺序与场景节点顺序一旦错位，
## preparation_screen.gd 的 _regions[index] 就会把矩形贴到别的分区上 —— 且不会报错。
const REGION_NAMES: PackedStringArray = [
	"RegionLeft", "RegionCenter", "RegionRight", "RegionBottom", "RegionAction",
]

## 03 §2 / 06 §10.1 R1：PREPARATION 不得存在任何会自动推进的构造。
const BANNED_TIMING_TOKENS: PackedStringArray = [
	"Timer", "create_timer", "_process", "_physics_process", "timeout", "wait_time", "autostart",
]

## 窄屏取样的可用区尺寸（360×640 竖屏）与 §7.1 折叠后的期望矩形。
##
## PET-80：取样尺寸随基准画布 ×2（180×320 → 360×640）。**必须一起改** ——
## §7.1 的折叠矩形每一处都乘了可用区尺寸（宽度直接取 viewport.x、弹层高取 height/3），
## 只翻常量不翻取样尺寸，量到的就是「旧尺寸的框装新尺寸的常量」，两边对不上。
const NARROW_VIEWPORT: Vector2 = Vector2(360.0, 640.0)
const EXPECTED_NARROW: Array[Rect2] = [
	Rect2(0.0, 0.0, 360.0, 32.0),
	Rect2(16.0, 32.0, 328.0, 298.66666),
	Rect2(0.0, 330.66666, 360.0, 213.33333),
	Rect2(0.0, 544.0, 360.0, 96.0),
	Rect2(256.0, 536.0, 88.0, 88.0),
]

## CTA 按钮的实测最小尺寸。06 §7 的 CTA 区块只有 28px 高（PET-80 前 14px），装不下它 —— 见
## PreparationLayout.action_button_rect 的说明；冒烟用例会在真实树上重量一次。
## PET-80：(40,20) → (80,40)。高 40 已在 `CTA 上缘` 那条上实测到（324 − 284 = 40）。
const CTA_MEASURED_MINIMUM: Vector2 = Vector2(80.0, 40.0)


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_route_checks(ctx)
	_run_source_checks(ctx)
	_run_layout_checks(ctx)
	_run_narrow_layout_checks(ctx)
	_run_cta_geometry_check(ctx)

	var resource: Resource = ResourceLoader.load(SCENE_PATH)
	if not ctx.check(resource is PackedScene, "preparation.tscn 应能加载为 PackedScene"):
		return
	_run_structure_checks(ctx, resource)


## 场景必须由 GameFlow 的路由表指到，否则 03 §1.1 R3 的唯一路由来源就断在这条边上。
func _run_route_checks(ctx: RefCounted) -> void:
	ctx.begin_case("PREPARATION · 路由登记（03 §1.1 R3）")
	var flow_script: GDScript = load(GAME_FLOW_SCRIPT_PATH)
	if not ctx.check(flow_script != null, "game_flow.gd 应能加载"):
		return
	var route: Variant = flow_script.SCENE_ROUTES.get(flow_script.GameState.PREPARATION, null)
	if not ctx.check(route != null, "GameFlow 应登记 PREPARATION 的路由"):
		return
	ctx.equal(String(route["path"]), SCENE_PATH, "PREPARATION 路由路径")
	ctx.equal(String(route["task"]), "S1-07", "PREPARATION 路由归属任务")
	ctx.check(ResourceLoader.exists(SCENE_PATH), "路由指向的场景文件必须真实存在")


## 04 §6 / 06 §10.7：色值只能来自 Palette；03 §2：不得有任何自动推进的构造。
##
## 顺带钉一条编译检查：脚本编译失败时 .tscn 仍能实例化出节点，下面那些结构断言会**一片全绿**
## 而游戏里跑的是空脚本（S1-06 实测：全局类表缺 PanelTitleBar 时 main_menu.gd 编译不过，
## 该用例 497 条断言一声不响；S1-07 建 preparation_layout.gd 后又踩了一次同款）。
func _run_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("PREPARATION · 无字面色值（06 §10.7）")
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH, SCENE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		if not ctx.check(not source.is_empty(), "%s 应能读取" % path):
			continue
		ctx.check(not source.contains("Color("), "%s 不得出现 Color(...) 字面量" % path)
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH]:
		var script: GDScript = load(path)
		ctx.check(script != null and script.can_instantiate(), "%s 应能编译" % path)

	ctx.begin_case("PREPARATION · R1 结构侧：不得存在任何计时器（03 §2）")
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH]:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token: String in BANNED_TIMING_TOKENS:
			ctx.check(not code.contains(token), "%s 的代码中不得出现 `%s`" % [path.get_file(), token])


## 06 §7 的宽屏数值：规范、常量、场景字面量三处对齐。
func _run_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("PREPARATION · 五分区矩形（06 §7 实测值）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "preparation_layout.gd 应能加载"):
		return

	var rects: Array[Rect2] = layout.wide_rects()
	if not ctx.check(rects.size() == EXPECTED_WIDE.size(), "宽屏应给出 5 个分区矩形"):
		return
	for index: int in EXPECTED_WIDE.size():
		ctx.equal(rects[index], EXPECTED_WIDE[index], "%s 的矩形" % REGION_NAMES[index])

	# 枚举顺序 = 场景节点顺序 = REGION_NAMES 下标。错位不会报错，只会把矩形贴错分区。
	ctx.equal(layout.Region.LEFT, 0, "Region.LEFT 的序号")
	ctx.equal(layout.Region.CENTER, 1, "Region.CENTER 的序号")
	ctx.equal(layout.Region.RIGHT, 2, "Region.RIGHT 的序号")
	ctx.equal(layout.Region.WAREHOUSE, 3, "Region.WAREHOUSE 的序号")
	ctx.equal(layout.Region.ACTION, 4, "Region.ACTION 的序号")

	# 06 §7 只实测了各栏 x 区间与底条 y 区间；三栏上边缘取 §1 安全区的 16px 内缩（PET-80 前 8px）。
	# 这条钉的是「两栏之间那道缝」，是**长度**故随坐标系 ×2（10 → 20）；
	# 它同样是 06 §7 实测的一部分（左栏右缘 88 与中栏左缘 98 之间那 10 个像素）。
	ctx.equal(layout.LEFT_RECT.end.x, layout.CENTER_RECT.position.x - 20.0, "左栏右缘与中栏左缘之间留 20px")
	ctx.equal(layout.CENTER_RECT.end.x, layout.RIGHT_RECT.position.x, "中栏右缘应与右栏左缘重合")
	ctx.equal(layout.RIGHT_RECT.end.x, 618.0, "右栏右缘（06 §7 实测 309，PET-80 后 618）")
	ctx.equal(layout.WAREHOUSE_RECT.size.y, 96.0, "底条高度（06 §7 实测 48，PET-80 后 96）")
	# CTA 区块比底条右缘多出 2px（620 vs 618）—— 这是 §7 实测的结果（310 vs 309），不是笔误，故不强行对齐。
	ctx.equal(layout.ACTION_RECT.end.x, 620.0, "CTA 区块右缘（06 §7 实测 310，PET-80 后 620）")
	# CTA 区块落在底条的纵向带内（148–162 ⊂ 132–180），即 06 §7 的「右下角」。
	ctx.check(layout.WAREHOUSE_RECT.position.y <= layout.ACTION_RECT.position.y
		and layout.ACTION_RECT.end.y <= layout.WAREHOUSE_RECT.end.y,
		"CTA 区块应落在底条的纵向带内（右下角）")


## 06 §7.1 的移动端折叠。折叠只改变布局，不改变任何玩法规则与状态流。
func _run_narrow_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("PREPARATION · 窄屏折叠（06 §7.1）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "preparation_layout.gd 应能加载"):
		return

	ctx.check(layout.is_narrow(NARROW_VIEWPORT), "360×640 竖屏应判定为窄屏")
	ctx.check(not layout.is_narrow(Vector2(640.0, 360.0)), "640×360 基准应判定为宽屏")
	ctx.check(not layout.is_narrow(Vector2(640.0, 640.0)), "1:1 应判定为宽屏（判定是 < 而非 <=）")
	ctx.check(not layout.is_narrow(Vector2.ZERO), "拿不到尺寸时应按宽屏处理，不得随手折叠")

	var rects: Array[Rect2] = layout.narrow_rects(NARROW_VIEWPORT)
	if not ctx.check(rects.size() == EXPECTED_NARROW.size(), "窄屏应给出 5 个分区矩形"):
		return
	for index: int in EXPECTED_NARROW.size():
		_check_rect_approx(ctx, rects[index], EXPECTED_NARROW[index], "%s 的折叠矩形" % REGION_NAMES[index])

	# §7.1：左栏收起为 32px 信息条（PET-80 前 16px），点击展开为覆盖层。
	_check_rect_approx(ctx, layout.narrow_info_rect(NARROW_VIEWPORT, false),
		Rect2(0.0, 0.0, 360.0, 32.0), "信息条收起态")
	ctx.equal(layout.narrow_info_rect(NARROW_VIEWPORT, true), layout.LEFT_RECT,
		"信息条展开态复用 §7 实测的左栏矩形")

	# §7.1：CTA 固定在右下角安全区内，尺寸不小于 88×88。
	# PET-80：88 就是本卡第 2 条点名的「触摸命中区 ≥44 → ≥88」（06 §1），
	# 与 HitMinimum.DESIGN_MIN_LOGICAL 同值 —— 窄屏 CTA 是这条下限的第一消费者。
	var action: Rect2 = rects[layout.Region.ACTION]
	ctx.equal(action.size, Vector2(88.0, 88.0), "窄屏 CTA 尺寸应达 88×88 触摸下限")
	ctx.equal(action.end, NARROW_VIEWPORT - Vector2(16.0, 16.0), "窄屏 CTA 应落在右下角安全区内")


## CTA 的落位换算：06 §7 的 14px 区块装不下一个按钮，故取「右下角照抄、高度向上长」。
func _run_cta_geometry_check(ctx: RefCounted) -> void:
	ctx.begin_case("PREPARATION · CTA 落位换算（§7 区块 vs 按钮最小尺寸）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "preparation_layout.gd 应能加载"):
		return
	var action: Rect2 = EXPECTED_WIDE[layout.Region.ACTION]
	var placed: Rect2 = layout.action_button_rect(action, CTA_MEASURED_MINIMUM)
	ctx.equal(placed.end, action.end, "按钮右下角必须与 §7 区块的右下角重合")
	ctx.equal(placed.position.x, action.position.x, "按钮左缘与 §7 区块一致")
	ctx.equal(placed.size.x, action.size.x, "按钮宽度与 §7 区块一致")
	ctx.check(placed.size.y >= CTA_MEASURED_MINIMUM.y, "按钮高度不得低于其最小高度")
	ctx.check(placed.position.y < action.position.y, "区块装不下时应向上长，而不是被顶出右下角")
	ctx.equal(layout.action_button_rect(action, Vector2(80.0, 20.0)), action,
		"最小尺寸装得下时不得改动 §7 区块")


func _run_structure_checks(ctx: RefCounted, packed: PackedScene) -> void:
	ctx.begin_case("PREPARATION · 五分区装配与场景字面量")
	var scene: Node = packed.instantiate()
	if not ctx.check(scene != null, "preparation.tscn 应能实例化"):
		return

	for index: int in REGION_NAMES.size():
		_check_region_literals(ctx, scene, index)

	ctx.check(_find(scene, "Backdrop") != null, "应有全屏底色层（色值在 _ready() 里取自 Palette）")
	ctx.check(_find(scene, "NoticePanel") != null, "应有提示面板（COMBAT 未实现时的提示落点）")
	_check_cta(ctx, scene)
	scene.free()


## .tscn 里的 offset 只能是字面量，这里拿规范值与常量核对它 —— 两边一旦漂开就不再是「一处定义」。
## 这正是 06 §2.2 裁定③：字面量允许，但必须由测试顶住。
func _check_region_literals(ctx: RefCounted, scene: Node, index: int) -> void:
	var name: String = REGION_NAMES[index]
	var expected: Rect2 = EXPECTED_WIDE[index]
	var region: Control = _find(scene, name) as Control
	if not ctx.check(region != null, "场景应有 %s 分区容器" % name):
		return
	ctx.equal(region.offset_left, expected.position.x, "%s 的 offset_left" % name)
	ctx.equal(region.offset_top, expected.position.y, "%s 的 offset_top" % name)
	ctx.equal(region.offset_right, expected.end.x, "%s 的 offset_right" % name)
	ctx.equal(region.offset_bottom, expected.end.y, "%s 的 offset_bottom" % name)
	# 占位分区不吃点击：整备界面里唯一该收点击的是 CTA 与窄屏信息条。
	ctx.equal(region.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 不得吃掉落在它上面的点击" % name)


## 06 §7：「开始战斗」是右下角**唯一**的主动作按钮，也是 PREPARATION → COMBAT 的唯一入口。
##
## PET-75：判据收窄到**主动作**按钮（无主题变体 = 基础 Button = GOLD 填充）。
## 该卡在左栏加了「删除 / 撤销 / 清空能力卡书」三个 ButtonSecondary 辅助按钮 ——
## 它们不争夺「右下角唯一主动作」这个位置，而本函数原先按 `is Button` 全数计数，
## 会把辅助按钮一起算成主动作。收窄之后这条断言测的正是它注释里写的那件事；
## 同时把「辅助按钮必须挂变体」这条反向要求也钉上，否则它们会跟 CTA 一样是金色。
func _check_cta(ctx: RefCounted, scene: Node) -> void:
	var all: Array[Button] = []
	_collect_buttons(scene, all)
	var primary: Array[Button] = []
	for candidate: Button in all:
		if candidate.theme_type_variation == &"":
			primary.append(candidate)
	if not ctx.check(primary.size() == 1, "整备界面应只有一个主动作按钮（实际 %d 个）" % primary.size()):
		return

	var button: Button = primary[0]
	ctx.equal(button.name, "ButtonStartCombat", "那唯一的主动作按钮应是「开始战斗」")
	ctx.equal(button.text, "开始战斗", "CTA 文案")
	for candidate: Button in all:
		if candidate != button:
			ctx.equal(candidate.theme_type_variation, &"ButtonSecondary",
				"%s 是辅助按钮，必须挂 ButtonSecondary 变体（06 §3）" % candidate.name)
	ctx.check(not button.disabled, "CTA 不得为 Disabled")

	var action: Rect2 = EXPECTED_WIDE[4]
	ctx.equal(button.offset_right, action.end.x, "CTA 右缘")
	ctx.equal(button.offset_bottom, action.end.y, "CTA 下缘")
	ctx.equal(button.offset_left, action.position.x, "CTA 左缘")
	ctx.equal(button.offset_top, action.end.y - CTA_MEASURED_MINIMUM.y, "CTA 上缘（高度已长到最小尺寸）")


func _collect_buttons(node: Node, found: Array[Button]) -> void:
	var button: Button = node as Button
	if button != null:
		found.append(button)
	for child: Node in node.get_children():
		_collect_buttons(child, found)


## 去掉注释再扫描：本仓库的文档注释里大量提到被禁的构造（正是为了声明「不许用」），
## 直接全文匹配会把「写明禁令」误判成「违反禁令」。同 test_game_flow.gd 的 _strip_comments。
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
