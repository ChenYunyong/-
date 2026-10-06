## test_combat.gd
## 职责：COMBAT 场景的**布局数值**与**静态装配**是否落在 06 §8 的规格上 ——
##       路由登记、战场 / 状态带两块矩形、状态带的只读性质、窄屏折叠、无字面色值、无玩法构造。
## 所属系统：tests
## 依赖：test_context, scripts/ui/combat_layout.gd, scripts/core/game_flow.gd
## 禁止：本文件不得硬编码色值；不得依赖执行顺序。
##
## 分工：本用例只查「布局算出了什么、场景装配成了什么」，**不查交互** ——
## 经 GameFlow 路由进入、两块区域的真实矩形、REWARD / RESULT 两个入口的提示路径，
## 都归 tests/integration/combat_smoke.gd 独立进程。
## 这里 instantiate() 但**不入树**：不入树就不触发 _ready()，也就不会惊动 GameFlow。

extends RefCounted

const SCENE_PATH: String = "res://scenes/combat/combat.tscn"
const SCREEN_SCRIPT_PATH: String = "res://scripts/ui/combat_screen.gd"
const LAYOUT_SCRIPT_PATH: String = "res://scripts/ui/combat_layout.gd"
const GAME_FLOW_SCRIPT_PATH: String = "res://scripts/core/game_flow.gd"
## 战场里那张只读机器视图。PET-76 的「三把武器的开火反馈两两可分」要问它取尺寸 ——
## 开火反馈画在卡片上，是 VIEWER 角色专属的（整备界面里的同一份脚本是编辑器，节点不会开火），
## 而 VIEWER 是本场景装配出来的，故那条断言落在本文件而不是工作区自己的用例里。
const WORKSPACE_SCRIPT_PATH: String = "res://scripts/ui/blueprint_workspace.gd"
## 次级文字色变体的**定义处**。用例取的是变体常量本身而不是字面量 `&"LabelSecondary"`：
## 变体改名时这里跟着断，而不是静默地永远不成立。
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"

## 06 §8 对 Reference C 的实测值，在本文件**独立复写一遍**（同 test_preparation.gd 的理由：
## 期望值若与被测实现同源，实现里把 135 写成 153 时两边一起错，断言就永远是绿的）。
## 下标即 CombatLayout.Region。两条都**全宽**——§8 明确写「横贯全宽的深色条」。
const REGION_NAMES: PackedStringArray = ["Battlefield", "StatusBar"]
const EXPECTED_WIDE: Array[Rect2] = [
	Rect2(0.0, 0.0, 320.0, 135.0),
	Rect2(0.0, 135.0, 320.0, 45.0),
]

## 06 §1 基准。
const REFERENCE_VIEWPORT: Vector2 = Vector2(320.0, 180.0)
## 06 §8：「该带占画面高约 25%」——实测 45 / 180。
const STATUS_BAR_SHARE: float = 0.25

## 06 §7.1 的窄屏取样（竖屏）。
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)
## 「另一个窄屏」取样，与 test_reward.gd / test_result.gd / combat_smoke.gd **共享** ——
## 它们还把它喂给触摸下限检查，故本文件不得改它的值。
## ⚠ 它高 180，与基准同高：min(45, 180 × 0.25) = 45 —— 状态带的 25% 上限**咬不住**（见下面的 TIGHT）。
const SHORT_NARROW_VIEWPORT: Vector2 = Vector2(120.0, 180.0)
const EXPECTED_NARROW: Array[Rect2] = [
	Rect2(0.0, 0.0, 180.0, 275.0),
	Rect2(0.0, 275.0, 180.0, 45.0),
]
const EXPECTED_SHORT_NARROW: Array[Rect2] = [
	Rect2(0.0, 0.0, 120.0, 135.0),
	Rect2(0.0, 135.0, 120.0, 45.0),
]
## 只给 COMBAT 用的专用取样：**比基准更矮**的窄屏，专门让状态带的 25% 上限真的咬住。
## §7.1 只给了「窄屏」这个条件，没给「多矮」—— 上限只有在视口比基准（320×180）矮时才生效。
## 120 / 160 = 0.75 < 1 → 窄屏；160 < 180 → 比基准矮；min(45, 160 × 0.25 = 40) = 40 < 45 → 上限咬住。
## REWARD / RESULT 不掺这个更小的视口，以免牵连它们的触摸下限断言。
const TIGHT_NARROW_VIEWPORT: Vector2 = Vector2(120.0, 160.0)
const EXPECTED_TIGHT_NARROW: Array[Rect2] = [
	Rect2(0.0, 0.0, 120.0, 120.0),
	Rect2(0.0, 120.0, 120.0, 40.0),
]

## 06 §8.1（v0.1.10，Codex 裁定）的 5 个只读读数块，按带内从左到右的顺序。
## 这条带**不是**动作栏，里面只许有这些只读读数。
const READOUT_CAPTIONS: PackedStringArray = ["波次", "CORE", "热量", "能量", "队列"]
## 06 §8.1 表里的占位值。CORE 用可比较读数，不用自然语言状态词。
const READOUT_VALUES: PackedStringArray = ["1/1", "100%", "0%", "0%", "0项"]
## 06 §8.1 硬规则 1：热量与能量必须**分格**（Heat 归橙 / Energy 归蓝，语义不同，
## 合并后告警读不出是哪个系统）。这里按节点名钉住它们各自独立。
const SPLIT_READOUTS: PackedStringArray = ["Heat", "Energy"]

## 13 §5 的 HUD 分层，落在 §8.1 冻结的这五格上：
## 一级 = §5 点名的 `WAVE` · `CORE / HP` · `HEAT`（本带里就是 波次 / CORE / 热量）；
## 二级 = 剩下两格。§5 的二级 `GOLD` / `NEXT` **不在** §8.1 的五格里，故不在此表 ——
## 它们要不要进来属 §8.1 的格数问题，已按任务卡要求上报 DSH，不自行改规范。
const PRIMARY_READOUTS: PackedStringArray = ["Wave", "Core", "Heat"]
const SECONDARY_READOUTS: PackedStringArray = ["Energy", "Queue"]
## 06 §1 的正文字号。二级读数就是它，一级读数必须**严格大于**它 ——
## 只断言「两者不同」的话，五格一起调小也会绿。
const BODY_FONT_SIZE: int = 8

## 本批禁令（任务卡 FORBIDDEN：禁止实现任何战斗玩法）。
## COMBAT 在 Stage 4 会**合法地**引入固定 tick（03 §2 的 TICK_RATE / _physics_process），
## 届时本表必须由那次改动一并删掉 —— 它守的是「这一批没有提前实现玩法」，
## 不是「COMBAT 永远不许有时间」。
const BATCH_BANNED_TOKENS: PackedStringArray = [
	"Timer", "create_timer", "_process", "_physics_process", "timeout", "wait_time",
	"autostart", "TICK_RATE", "randi", "randf",
]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_route_checks(ctx)
	_run_source_checks(ctx)
	_run_layout_checks(ctx)
	_run_narrow_layout_checks(ctx)

	var resource: Resource = ResourceLoader.load(SCENE_PATH)
	if not ctx.check(resource is PackedScene, "combat.tscn 应能加载为 PackedScene"):
		return
	_run_structure_checks(ctx, resource)


## 场景必须由 GameFlow 的路由表指到，否则 03 §1.1 R3 的唯一路由来源就断在这条边上。
func _run_route_checks(ctx: RefCounted) -> void:
	ctx.begin_case("COMBAT · 路由登记（03 §1.1 R3）")
	var flow_script: GDScript = load(GAME_FLOW_SCRIPT_PATH)
	if not ctx.check(flow_script != null, "game_flow.gd 应能加载"):
		return
	var route: Variant = flow_script.SCENE_ROUTES.get(flow_script.GameState.COMBAT, null)
	if not ctx.check(route != null, "GameFlow 应登记 COMBAT 的路由"):
		return
	ctx.equal(String(route["path"]), SCENE_PATH, "COMBAT 路由路径")
	ctx.equal(String(route["task"]), "S1-08", "COMBAT 路由归属任务")
	ctx.check(ResourceLoader.exists(SCENE_PATH), "路由指向的场景文件必须真实存在")


## 04 §6 / 06 §10.7：色值只能来自 Palette；任务卡：本批不得出现任何玩法构造。
##
## 顺带钉一条编译检查：脚本编译失败时 .tscn 仍能实例化出节点，下面那些结构断言会**一片全绿**
## 而游戏里跑的是空脚本（S1-06 / S1-07 各实测到一次）。用例脚本自身用 load() 取实现，
## 不经全局类表，正是为了在这种时候还能把红报出来。
func _run_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("COMBAT · 无字面色值（06 §10.7）")
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH, SCENE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		if not ctx.check(not source.is_empty(), "%s 应能读取" % path):
			continue
		ctx.check(not source.contains("Color("), "%s 不得出现 Color(...) 字面量" % path)
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH]:
		var script: GDScript = load(path)
		ctx.check(script != null and script.can_instantiate(), "%s 应能编译" % path)

	ctx.begin_case("COMBAT · 本批禁令：不得存在任何玩法构造（任务卡 FORBIDDEN）")
	for path: String in [SCREEN_SCRIPT_PATH, LAYOUT_SCRIPT_PATH]:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token: String in BATCH_BANNED_TOKENS:
			ctx.check(not code.contains(token), "%s 的代码中不得出现 `%s`" % [path.get_file(), token])


## 06 §8 的宽屏数值：规范、常量、场景字面量三处对齐。
func _run_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("COMBAT · 战场与状态带两块矩形（06 §8 实测值）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "combat_layout.gd 应能加载"):
		return

	var rects: Array[Rect2] = layout.wide_rects()
	if not ctx.check(rects.size() == EXPECTED_WIDE.size(), "宽屏应给出 2 个区域矩形"):
		return
	for index: int in EXPECTED_WIDE.size():
		ctx.equal(rects[index], EXPECTED_WIDE[index], "%s 的矩形" % REGION_NAMES[index])

	# 枚举顺序 = 场景节点顺序 = REGION_NAMES 下标。错位不会报错，只会把矩形贴错区域。
	ctx.equal(layout.Region.BATTLEFIELD, 0, "Region.BATTLEFIELD 的序号")
	ctx.equal(layout.Region.STATUS_BAR, 1, "Region.STATUS_BAR 的序号")

	var battlefield: Rect2 = rects[layout.Region.BATTLEFIELD]
	var bar: Rect2 = rects[layout.Region.STATUS_BAR]
	ctx.equal(battlefield.end.y, bar.position.y, "战场下缘应与状态带上沿重合（§8 实测 y≈135）")
	ctx.equal(bar.end.y, REFERENCE_VIEWPORT.y, "状态带下缘应贴到画面底（§8 实测 y=180）")
	ctx.equal(battlefield.position, Vector2.ZERO, "战场应从画面左上角起（§8：战斗画面占据整个主区域）")
	ctx.equal(battlefield.position.x, bar.position.x, "两块区域左缘对齐")
	ctx.equal(battlefield.end.x, bar.end.x, "两块区域右缘对齐（§8：状态带横贯全宽）")
	ctx.equal(battlefield.end.x, REFERENCE_VIEWPORT.x, "两块区域都应满宽 320")
	ctx.check(not battlefield.intersects(bar), "战场与状态带不得重叠（§8：HUD 贴边、不遮挡战场）")

	# §8：战场占画面高约 75%，状态带约 25%。
	ctx.equal(battlefield.size.y / REFERENCE_VIEWPORT.y, 1.0 - STATUS_BAR_SHARE, "战场应占画面高 75%")
	ctx.equal(bar.size.y / REFERENCE_VIEWPORT.y, STATUS_BAR_SHARE, "状态带应占画面高 25%")
	ctx.check(battlefield.size.y > bar.size.y, "战场必须是主区（比状态带高）")


## 06 §7.1 的移动端折叠：主区域始终保留，底部条保留但**不得挤掉主区域的可读性**。
func _run_narrow_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("COMBAT · 窄屏折叠（06 §7.1）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "combat_layout.gd 应能加载"):
		return

	ctx.check(layout.is_narrow(NARROW_VIEWPORT), "180×320 竖屏应判定为窄屏")
	ctx.check(not layout.is_narrow(REFERENCE_VIEWPORT), "320×180 基准应判定为宽屏")
	ctx.check(not layout.is_narrow(Vector2(320.0, 320.0)), "1:1 应判定为宽屏（判定是 < 而非 <=）")
	ctx.check(not layout.is_narrow(Vector2.ZERO), "拿不到尺寸时应按宽屏处理，不得随手折叠")

	var rects: Array[Rect2] = layout.narrow_rects(NARROW_VIEWPORT)
	if not ctx.check(rects.size() == EXPECTED_NARROW.size(), "窄屏应给出 2 个区域矩形"):
		return
	for index: int in EXPECTED_NARROW.size():
		ctx.equal(rects[index], EXPECTED_NARROW[index], "%s 的折叠矩形" % REGION_NAMES[index])

	# 共享取样 120×180：与基准**同高**的窄屏。状态带是固定高的 HUD 条，不随视口长高 ——
	# 这里钉的正是「不随视口长高」：高仍是 §8 实测的 45（min(45, 180 × 0.25) = 45，上限没生效）。
	var short: Array[Rect2] = layout.narrow_rects(SHORT_NARROW_VIEWPORT)
	for index: int in EXPECTED_SHORT_NARROW.size():
		ctx.equal(short[index], EXPECTED_SHORT_NARROW[index],
			"%s 在 %s 下的矩形" % [REGION_NAMES[index], SHORT_NARROW_VIEWPORT])

	# COMBAT 专用取样 120×160：比基准**更矮**，于是 §8 实测的 25% 份额反过来成为上限并真的咬住。
	# 这一案是 120×180 测不到的 —— 那一个高与基准相同，上限恒不生效（这正是当年被掩盖的问题）。
	var tight: Array[Rect2] = layout.narrow_rects(TIGHT_NARROW_VIEWPORT)
	for index: int in EXPECTED_TIGHT_NARROW.size():
		ctx.equal(tight[index], EXPECTED_TIGHT_NARROW[index],
			"%s 在 %s 下的矩形" % [REGION_NAMES[index], TIGHT_NARROW_VIEWPORT])

	# 光钉矩形还不够 —— 把「上限真的咬住了」这条**性质**单独钉一次：矩形一旦被改坏，
	# 失败信息里能直接读出是上限没生效，而不是只看到一个 40 ≠ 45。
	var cap: float = REFERENCE_VIEWPORT.y * STATUS_BAR_SHARE
	var tight_bar: Rect2 = tight[layout.Region.STATUS_BAR]
	ctx.check(tight_bar.size.y < cap,
		"收缩窄屏 %s：状态带高应严格小于基准下的 %.0f（25%% 上限真的咬住；实得 %.1f）" % [
			TIGHT_NARROW_VIEWPORT, cap, tight_bar.size.y])
	ctx.equal(tight_bar.size.y, TIGHT_NARROW_VIEWPORT.y * STATUS_BAR_SHARE,
		"收缩窄屏 %s：状态带高应恰为画面高的 25%%（上限的取值点）" % TIGHT_NARROW_VIEWPORT)

	for sample: Vector2 in [NARROW_VIEWPORT, SHORT_NARROW_VIEWPORT]:
		var sample_rects: Array[Rect2] = layout.narrow_rects(sample)
		var sample_bar: Rect2 = sample_rects[layout.Region.STATUS_BAR]
		var sample_field: Rect2 = sample_rects[layout.Region.BATTLEFIELD]
		ctx.check(sample_bar.size.y <= sample.y * STATUS_BAR_SHARE + 0.001,
			"窄屏 %s：状态带不得超过画面高的 25%%（实际 %.1f%%，§7.1「不得挤掉战场可读性」）" % [
				sample, sample_bar.size.y / sample.y * 100.0])
		ctx.check(sample_field.end.y == sample_bar.position.y and sample_bar.end.y == sample.y,
			"窄屏 %s：两块区域应首尾相接并铺满整个视口高" % sample)
		ctx.check(sample_field.size.x == sample.x and sample_bar.size.x == sample.x,
			"窄屏 %s：两块区域仍应满宽" % sample)
		ctx.check(not sample_field.intersects(sample_bar), "窄屏 %s：两块区域不得重叠" % sample)


func _run_structure_checks(ctx: RefCounted, packed: PackedScene) -> void:
	ctx.begin_case("COMBAT · 场景装配与场景字面量")
	var scene: Node = packed.instantiate()
	if not ctx.check(scene != null, "combat.tscn 应能实例化"):
		return

	var battlefield: Control = _find(scene, "Battlefield") as Control
	var bar: Control = _find(scene, "StatusBar") as Control
	if ctx.check(battlefield != null, "应有 Battlefield 区域容器") \
			and ctx.check(bar != null, "应有 StatusBar 区域容器"):
		_check_region_literals(ctx, battlefield, "Battlefield", EXPECTED_WIDE[0])
		_check_region_literals(ctx, bar, "StatusBar", EXPECTED_WIDE[1])

	ctx.check(_find(scene, "Backdrop") != null, "应有全屏底色层（色值在 _ready() 里取自 Palette）")
	_check_status_bar_read_only(ctx, scene, bar)
	_check_readout_blocks(ctx, scene)
	_check_readout_hierarchy(ctx, scene)
	_check_overheat_cue(ctx)
	_check_readable_feedback(ctx)
	scene.free()


## .tscn 里的 offset 只能是字面量，这里拿规范值与常量核对它 —— 两边一旦漂开就不再是「一处定义」。
## 这正是 06 §2.2 裁定③：字面量允许，但必须由测试顶住。
func _check_region_literals(ctx: RefCounted, region: Control, label: String, expected: Rect2) -> void:
	ctx.equal(region.offset_left, expected.position.x, "%s 的 offset_left" % label)
	ctx.equal(region.offset_top, expected.position.y, "%s 的 offset_top" % label)
	ctx.equal(region.offset_right, expected.end.x, "%s 的 offset_right" % label)
	ctx.equal(region.offset_bottom, expected.end.y, "%s 的 offset_bottom" % label)


## 验收核心：这条带的性质是「状态 / 预览」，**不是**实时动作栏。
## 这里量的是装配出来的节点类型 —— 整幕 COMBAT 里不许有任何按钮，理由见
## 00_PROJECT_CHARTER.md §5 第 3 条：COMBAT 阶段玩家的一切影响都必须在进入战斗前写进蓝图。
func _check_status_bar_read_only(ctx: RefCounted, scene: Node, bar: Control) -> void:
	ctx.begin_case("COMBAT · 状态带是只读展示，不是动作栏（06 §8 / 00 §5.3）")
	if bar == null:
		return

	var interactive: Array[Node] = []
	_collect_interactive(scene, interactive)
	var names: PackedStringArray = []
	for node: Node in interactive:
		names.append(node.name)
	ctx.check(interactive.is_empty(),
		"整幕 COMBAT 不得存在任何可交互控件（按钮 / 输入框 / 滑条），实际 %d 个：%s" % [
			interactive.size(), ", ".join(names)])

	var in_bar: Array[Node] = []
	_collect_interactive(bar, in_bar)
	ctx.check(in_bar.is_empty(), "状态带内尤其不得出现动作按钮（实际 %d 个）" % in_bar.size())

	# 只读性还要正面证明一次：带内除填充 / 描边 / 容器外，可显示的控件只能是 Label。
	var labels: Array[Label] = []
	_collect_labels(bar, labels)
	ctx.equal(labels.size(), READOUT_CAPTIONS.size() * 2,
		"状态带内应恰好有 %d 个 Label（%d 组「标题 + 读数」）" % [
			READOUT_CAPTIONS.size() * 2, READOUT_CAPTIONS.size()])
	var texts: PackedStringArray = []
	for label: Label in labels:
		texts.append(label.text)
	for caption: String in READOUT_CAPTIONS:
		ctx.check(texts.has(caption), "状态带应展示「%s」这一项（06 §8 点名的状态 / 预览）" % caption)

	# 填充与上沿：06 §8「底色 NAVY_800，上沿 1px NAVY_600 分隔」——
	# 色值在 _ready() 里取自 Palette，这里只钉几何（是否真的画出来归像素探针）。
	var edge: Control = _find(bar, "StatusEdge") as Control
	var fill: Control = _find(bar, "StatusFill") as Control
	if not ctx.check(edge != null, "状态带应有上沿分隔条 StatusEdge"):
		return
	if not ctx.check(fill != null, "状态带应有底色层 StatusFill"):
		return
	ctx.check(edge is ColorRect and fill is ColorRect, "底色与上沿应是纯色块（无描边 / 无圆角）")
	ctx.equal(edge.offset_left, 0.0, "上沿应从状态带左缘起")
	ctx.equal(edge.offset_right, 0.0, "上沿应铺到状态带右缘（全宽）")
	ctx.equal(edge.offset_top, 0.0, "上沿应贴状态带上沿")
	ctx.equal(edge.offset_bottom - edge.offset_top, 1.0, "上沿厚度应为 1px（06 §8）")
	ctx.equal(fill.offset_left, 0.0, "底色应铺满状态带")
	ctx.equal(fill.offset_top, 0.0, "底色应铺满状态带")
	ctx.equal(fill.offset_right, 0.0, "底色应铺满状态带")
	ctx.equal(fill.offset_bottom, 0.0, "底色应铺满状态带")
	# 上沿必须画在底色**之上**：同为全矩形时，兄弟顺序决定谁盖住谁。
	ctx.check(edge.get_index() > fill.get_index(), "上沿应排在底色之后（否则会被底色盖掉）")


## 06 §8.1（v0.1.10，Codex 裁定）：读数区恰好 5 个只读读数块，热量与能量各自独立成块，
## CORE 用百分比读数。这里量的是装配出来的节点结构与文案；
## 「这 5 格真的被画到屏幕上」归 tests/unit/combat_probe.gd 的像素取证（09 §4）。
func _check_readout_blocks(ctx: RefCounted, scene: Node) -> void:
	ctx.begin_case("COMBAT · 读数区 5 个只读读数块（06 §8.1）")
	var row: Node = _find(scene, "ReadoutsRow")
	if not ctx.check(row != null, "状态带应有读数行的容器 ReadoutsRow"):
		return

	var blocks: Array[Node] = row.get_children()
	if not ctx.equal(blocks.size(), READOUT_CAPTIONS.size(),
			"读数区应恰好 %d 个读数块" % READOUT_CAPTIONS.size()):
		return
	for index: int in READOUT_CAPTIONS.size():
		_check_one_readout(ctx, blocks[index], index)

	# 硬规则 1：热量与能量**必须分格**，不得再合并成一格 `0% / 0%`。
	var heat: Node = _find(row, SPLIT_READOUTS[0])
	var energy: Node = _find(row, SPLIT_READOUTS[1])
	if ctx.check(heat != null and energy != null, "热量与能量应各自有独立的读数块"):
		ctx.check(heat != energy, "热量与能量必须是两个不同的节点，不得是同一格的两种说法")
		ctx.equal(heat.get_index() + 1, energy.get_index(), "热量与能量应是相邻的两块")
		for block: Node in [heat, energy]:
			var value: Label = _find(block, "Value") as Label
			ctx.check(value != null and not value.text.contains("/"),
				"%s 的读数不得写成合并形式（读数里不得出现 `/`）" % block.name)

	# 硬规则 2：CORE 用可比较的百分比读数，不用 `完好` 这类自然语言状态词。
	var core: Node = _find(row, "Core")
	if ctx.check(core != null, "应有 CORE 读数块（节点名 Core）"):
		var core_value: Label = _find(core, "Value") as Label
		if ctx.check(core_value != null, "CORE 读数块应有 Value"):
			ctx.check(core_value.text.ends_with("%"), "CORE 应是百分比读数（实际：%s）" % core_value.text)
			ctx.check(core_value.text.trim_suffix("%").is_valid_int(),
				"CORE 的百分号前应是可比较的整数（实际：%s）" % core_value.text)


## 13 §5：五块 HUD 不得像五个同等级的菜单按钮。判据取两条**可量的差**：
##   ① 一级读数的字号严格大于正文字号，二级就是正文字号；
##   ② 一级标题不带次级文字色变体（走更亮的正文色），二级带。
## 两条都只钉「层级存在且方向正确」，不钉具体字号 / 具体变体名 ——
## 后者归 test_theme.gd（变体本身）与 .tscn 字面量（由本用例顶住）。
func _check_readout_hierarchy(ctx: RefCounted, scene: Node) -> void:
	ctx.begin_case("COMBAT · HUD 一级 / 二级 权重分层（13 §5）")
	var row: Node = _find(scene, "ReadoutsRow")
	if not ctx.check(row != null, "状态带应有读数行的容器 ReadoutsRow"):
		return
	var theme_script: GDScript = load(THEME_SCRIPT_PATH)
	if not ctx.check(theme_script != null, "palette_theme.gd 应能加载"):
		return
	var secondary: StringName = theme_script.TYPE_LABEL_SECONDARY

	var primary_size: int = 0
	for block_name: String in PRIMARY_READOUTS:
		var block: Node = _find(row, block_name)
		if not ctx.check(block != null, "应有读数块 %s" % block_name):
			continue
		var size: int = _value_font_size(block)
		primary_size = maxi(primary_size, size)
		ctx.check(size > BODY_FONT_SIZE,
			"一级读数块 %s 的字号应大于正文字号 %d（实际 %d）" % [block_name, BODY_FONT_SIZE, size])
		var caption: Label = _find(block, "Caption") as Label
		if ctx.check(caption != null, "%s 应有 Caption" % block_name):
			ctx.check(caption.theme_type_variation != secondary,
				"一级标题 %s 不得用次级文字色（否则与二级同暗，层级就没了）" % block_name)

	for block_name: String in SECONDARY_READOUTS:
		var block: Node = _find(row, block_name)
		if not ctx.check(block != null, "应有读数块 %s" % block_name):
			continue
		ctx.equal(_value_font_size(block), BODY_FONT_SIZE,
			"二级读数块 %s 的字号应就是正文字号" % block_name)
		var caption: Label = _find(block, "Caption") as Label
		if ctx.check(caption != null, "%s 应有 Caption" % block_name):
			ctx.equal(caption.theme_type_variation, secondary,
				"二级标题 %s 应取次级文字色（视觉权重低一档）" % block_name)

	# 方向性单独钉一条：五格一起调小、或两级调成同一个值时，上面那些「等于/不等于」仍可能绿。
	ctx.check(primary_size > BODY_FONT_SIZE,
		"一级与二级必须真的差一档（一级 %d > 正文 %d）" % [primary_size, BODY_FONT_SIZE])


## 读数格的**字号**：场景给了覆写就用覆写，没给就是 06 §1 的正文字号。
##
## 读的是 `theme_override_font_sizes/font_size` 这个节点属性本身，而不是 `get_theme_font_size()`：
## 后者要沿 Theme 链解析，而本用例的节点**不入树**，解析结果取决于 Theme 有没有被继承到，
## 量到的就不是「场景里写了什么」而是「此刻解析成了什么」。属性读法两处都确定。
func _value_font_size(block: Node) -> int:
	var value: Label = _find(block, "Value") as Label
	if value == null:
		return -1
	var override_size: Variant = value.get(&"theme_override_font_sizes/font_size")
	return int(override_size) if override_size != null else BODY_FONT_SIZE


## 过热提示（PET-66 遗留项）：本卡评估后落地的形式是**只给 `热量` 那一格换色**，
## 因为 06 §8.1 把这条带冻结成 5 个只读读数块 —— 加格子 / 加控件 / 改几何都属于
## 「改动 §8.1 的结构」，按任务卡要求不得自行进行。于是这里钉两件事：
##   ① 取色映射本身（常态 / 过热各取到 Palette 里的哪一个 Token，且两者不同）；
##   ② 换色的触发来自 MachineRuntime 的过热信号，而不是每拍比对 heat() 自己判定过热。
## 「换色真的画到了屏幕上」属像素取证，本用例（不入树）不冒充。
func _check_overheat_cue(ctx: RefCounted) -> void:
	ctx.begin_case("COMBAT · 过热提示只换色、不动五格（06 §8.1 冻结）")
	var screen: GDScript = load(SCREEN_SCRIPT_PATH)
	if not ctx.check(screen != null, "combat_screen.gd 应能加载"):
		return

	var normal: Color = screen.heat_readout_color(false)
	var overheated: Color = screen.heat_readout_color(true)
	ctx.equal(normal, Palette.get_color(Palette.Key.ORANGE_500),
		"常态的 `热量` 读数色（04 §3.8：Heat 条 / 高温）")
	ctx.equal(overheated, Palette.get_color(Palette.Key.ORANGE_300),
		"过热中的 `热量` 读数色（04 §3.8：过热高光）")
	ctx.check(normal != overheated, "两种状态必须取到不同的颜色，否则这个提示并不存在")

	var code: String = _strip_comments(FileAccess.get_file_as_string(SCREEN_SCRIPT_PATH))
	for signal_name: String in ["overheat_started", "overheat_ended"]:
		ctx.check(code.contains(signal_name),
			"应接上 MachineRuntime.%s（否则换色永不发生）" % signal_name)
	ctx.check(not code.contains("is_overheated("),
		"不得自己判定过热（06 §8.1 / 03 §2：阈值与停火都在 MachineRuntime）")


## PET-76 的可读反馈：三把武器开火时的反馈**形态**必须两两不同，且整条链路的接点在代码里真实存在。
##
## 为什么钉形态而不是钉颜色：04 §3.10 只给了**一套** FX 三层色（描边 NAVY_900 / 体 BLUE_FX_600 /
## 芯 BLUE_050）。拿色相去分针 / 炸弹 / 锯，等于在冻结的语义色之外另立第二套色语言 ——
## 于是区分只能落在**形状**上，而形状恰好是静止一帧里就读得出来的东西。
##
## 本用例只量纯函数与代码接点；「画到屏幕上时到底是什么颜色、真的看得见吗」归像素取证
## （tests/integration/combat_loop_smoke.gd）—— 09 §4：视觉结果不能只断言配置项。
func _check_readable_feedback(ctx: RefCounted) -> void:
	ctx.begin_case("COMBAT · 三把武器的开火反馈两两可分（PET-76 / 13 §5）")
	var workspace: GDScript = load(WORKSPACE_SCRIPT_PATH)
	if not ctx.check(workspace != null and workspace.can_instantiate(),
			"blueprint_workspace.gd 应能编译"):
		return

	var kinds: Array[int] = [NodeData.WeaponKind.NEEDLE, NodeData.WeaponKind.BOMB,
		NodeData.WeaponKind.SAW]
	var ratios: Array[float] = []
	for kind: int in kinds:
		var cue: Vector2 = workspace.fire_cue_size(kind)
		if not ctx.check(cue.x > 0.0 and cue.y > 0.0,
				"武器种类 %d 的开火反馈应有正的尺寸（实际 %s）" % [kind, cue]):
			continue
		ratios.append(cue.x / cue.y)
	# 比的是**长宽比**而不是尺寸：三把都缩成同样形状、只差几个像素时，「两个尺寸不相等」
	# 照样会绿，而画面上三把看起来一模一样。长宽比不同，才意味着静止一帧里读得出是哪把。
	for i: int in ratios.size():
		for j: int in range(i + 1, ratios.size()):
			ctx.check(absf(ratios[i] - ratios[j]) > 0.15,
				"武器 %d 与 %d 的开火反馈长宽比应明显不同（%.2f 与 %.2f）—— 静止一帧里也分得出是哪把"
					% [kinds[i], kinds[j], ratios[i], ratios[j]])
	# 认不出的武器种类要退到**一种确定的**形态，而不是给出一个零尺寸的空框
	# （零矩形在画面上等于「这把武器开火了，但什么都没发生」）。
	var fallback: Vector2 = workspace.fire_cue_size(NodeData.WeaponKind.NONE)
	ctx.check(fallback.x > 0.0 and fallback.y > 0.0,
		"没有武器种类（NONE）时也应给出一种可画的形态（实际 %s）" % fallback)

	# 「哪把武器发动 → 打到谁」这条链路上的四个接点。缺任何一个，画面上都会安静地少一样东西：
	#   没有 weapon_fired → 不知道是哪把武器发动；
	#   没有 card_rect     → 弹道没有起点（起点只能是那张卡，不能是 (0,0)）；
	#   没有 draw_line     → 弹道不存在；没有 draw_rect → 命中闪光不存在。
	var code: String = _strip_comments(FileAccess.get_file_as_string(SCREEN_SCRIPT_PATH))
	for token: String in ["weapon_fired", "card_rect", "draw_line", "draw_rect"]:
		ctx.check(code.contains(token), "combat_screen.gd 的代码中应出现 `%s`（PET-76 链路接点）" % token)


func _check_one_readout(ctx: RefCounted, block: Node, index: int) -> void:
	var label: String = "第 %d 块（%s）" % [index + 1, READOUT_CAPTIONS[index]]
	ctx.check(block is VBoxContainer, "%s 应是「标题 + 读数」的纵向容器" % label)
	var caption: Label = _find(block, "Caption") as Label
	var value: Label = _find(block, "Value") as Label
	if not ctx.check(caption != null and value != null, "%s 应有 Caption 与 Value 两个 Label" % label):
		return
	# 只读：读数块里除了这两个 Label 不许再有别的控件（按钮 / 输入框 / 滑条）。
	var extra: Array[Node] = []
	for child: Node in block.get_children():
		if child != caption and child != value:
			extra.append(child)
	ctx.check(extra.is_empty(), "%s 内除 Caption / Value 外不得再有控件" % label)
	ctx.equal(caption.text, READOUT_CAPTIONS[index], "%s 的 Caption" % label)
	ctx.equal(value.text, READOUT_VALUES[index], "%s 的读数" % label)


## 可交互控件：按钮、滑条、输入框。ScrollContainer 不算 —— 它只是被动滚动一个只读列表，
## 既不产生动作也不改变任何状态（06 §8 要的是「不得需要玩家长按 / 连点」）。
func _collect_interactive(node: Node, found: Array[Node]) -> void:
	if node is BaseButton or node is Range or node is LineEdit or node is TextEdit:
		found.append(node)
	for child: Node in node.get_children():
		_collect_interactive(child, found)


func _collect_labels(node: Node, found: Array[Label]) -> void:
	var label: Label = node as Label
	if label != null:
		found.append(label)
	for child: Node in node.get_children():
		_collect_labels(child, found)


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


func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false)
