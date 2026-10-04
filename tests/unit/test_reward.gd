## test_reward.gd
## 职责：REWARD 场景的**布局数值**与**静态装配**是否落在 06 §9 / §7.1 的规格上
##       （路由登记、标题栏与三张卡片的矩形、五个展示位齐备、触摸下限、
##       PanelShadow 叠层及其与内容 Layout 的先后次序、
##       无字面色值、无计时器构造、无奖励数值逻辑）。
## 所属系统：tests
## 依赖：test_context, scripts/ui/reward_layout.gd, scripts/ui/reward_option.gd, scripts/core/game_flow.gd
## 禁止：本文件不得硬编码色值；不得依赖执行顺序。
##
## 分工：本用例只查「布局算出了什么、场景装配成了什么」，**不查交互** ——
## 经 GameFlow 路由进入、选中后回 PREPARATION、停留不自动推进，都要真实状态机，
## 归 tests/integration/reward_smoke.gd 独立进程；真实渲染矩形归 tests/unit/reward_probe.gd。
## 这里 instantiate() 但**不入树**：不入树就不触发 _ready()，也就不会惊动 GameFlow。

extends RefCounted

const SCENE_PATH: String = "res://scenes/reward/reward.tscn"
const CARD_SCENE_PATH: String = "res://scenes/reward/reward_card.tscn"
const SCREEN_SCRIPT_PATH: String = "res://scripts/ui/reward_screen.gd"
const CARD_SCRIPT_PATH: String = "res://scripts/ui/reward_card.gd"
const LAYOUT_SCRIPT_PATH: String = "res://scripts/ui/reward_layout.gd"
const OPTION_SCRIPT_PATH: String = "res://scripts/ui/reward_option.gd"
const FLOW_SCRIPT_PATH: String = "res://scripts/core/game_flow.gd"
const PALETTE_SCRIPT_PATH: String = "res://scripts/data/palette.gd"
const WORKSPACE_SCRIPT_PATH: String = "res://scripts/ui/blueprint_workspace.gd"
const NODE_DATA_PATH: String = "res://scripts/data/node_data.gd"

## 06 §1 基准与 §7.1 的窄屏取样。
const REFERENCE_VIEWPORT: Vector2 = Vector2(320.0, 180.0)
const NARROW_VIEWPORT: Vector2 = Vector2(180.0, 320.0)
const SHORT_NARROW_VIEWPORT: Vector2 = Vector2(120.0, 180.0)

## 06 §9 只规定了「3 个选项 + 不足时以跳过补齐」，未给实测矩形；下面是本文件**独立复写**的
## 期望值，刻意不从 RewardLayout 取 —— 测试若与被测实现同源，实现里把 96 写成 86 时
## 两边一起错，断言就永远是绿的。推导依据见 reward_layout.gd 的文件头。
const TITLE_RECT: Rect2 = Rect2(8.0, 8.0, 304.0, 16.0)
const CARDS_RECT: Rect2 = Rect2(8.0, 32.0, 304.0, 140.0)
## 三张卡片的矩形**相对卡片区原点**（卡片是卡片区的子节点）。
const CARD_RECTS: Array[Rect2] = [
	Rect2(0.0, 0.0, 96.0, 140.0),
	Rect2(104.0, 0.0, 96.0, 140.0),
	Rect2(208.0, 0.0, 96.0, 140.0),
]
const NARROW_TITLE_RECT: Rect2 = Rect2(8.0, 8.0, 164.0, 16.0)
const NARROW_CARDS_RECT: Rect2 = Rect2(8.0, 32.0, 164.0, 280.0)
const NARROW_CARD_RECTS: Array[Rect2] = [
	Rect2(0.0, 0.0, 164.0, 88.0),
	Rect2(0.0, 96.0, 164.0, 88.0),
	Rect2(0.0, 192.0, 164.0, 88.0),
]

## 06 §1：可点击区域下限（设备像素）。
const MIN_TOUCH_SIZE: float = 44.0

const CARD_NAMES: PackedStringArray = ["Card0", "Card1", "Card2"]
## 06 §9 点名的五项，逐项都要有落点。
const FIELD_NAMES: PackedStringArray = ["Icon", "Name", "Type", "Value", "Rule"]

## 03 §2 / 06 §10.1：REWARD 不得存在任何会自动推进的构造。
const BANNED_TIMING_TOKENS: PackedStringArray = [
	"Timer", "create_timer", "_process", "_physics_process", "timeout", "wait_time", "autostart",
]

## Stage 4 的 S4-07 才允许出现的词。本批只做骨架，实现里出现任何一个都说明越界了。
const STAGE4_TOKENS: PackedStringArray = ["drop_pool", "DROP_POOL", "rarity", "RARITY", "weight"]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_route_checks(ctx)
	_run_source_checks(ctx)
	_run_layout_checks(ctx)
	_run_narrow_layout_checks(ctx)
	_run_touch_size_checks(ctx)
	_run_option_checks(ctx)
	_run_payload_checks(ctx)
	_run_icon_color_checks(ctx)

	var resource: Resource = ResourceLoader.load(SCENE_PATH)
	if not ctx.check(resource is PackedScene, "reward.tscn 应能加载为 PackedScene"):
		return
	_run_structure_checks(ctx, resource)


## 场景必须由 GameFlow 的路由表指到，否则 03 §1.1 R3 的唯一路由来源就断在这条边上。
func _run_route_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 路由登记（03 §1.1 R3）")
	var flow_script: GDScript = load(FLOW_SCRIPT_PATH)
	if not ctx.check(flow_script != null, "game_flow.gd 应能加载"):
		return
	var route: Variant = flow_script.SCENE_ROUTES.get(flow_script.GameState.REWARD, null)
	if not ctx.check(route != null, "GameFlow 应登记 REWARD 的路由"):
		return
	ctx.equal(String(route["path"]), SCENE_PATH, "REWARD 路由路径")
	ctx.equal(String(route["task"]), "S1-09", "REWARD 路由归属任务")
	ctx.check(ResourceLoader.exists(SCENE_PATH), "路由指向的场景文件必须真实存在")
	# 03 §1 状态图：REWARD 的唯一出口是 PREPARATION。
	ctx.equal(flow_script.ALLOWED_TRANSITIONS[flow_script.GameState.REWARD],
		[flow_script.GameState.PREPARATION], "REWARD 只允许走向 PREPARATION")


## 04 §6 / 06 §10.7：色值只能来自 Palette；03 §2：不得有任何自动推进的构造。
##
## 顺带钉一条编译检查：脚本编译失败时 .tscn 仍能实例化出节点，下面那些结构断言会**一片全绿**
## 而游戏里跑的是空脚本（S1-06 与 S1-07 各踩过一次）。
func _run_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 无字面色值（06 §10.7）")
	for path: String in [SCREEN_SCRIPT_PATH, CARD_SCRIPT_PATH, LAYOUT_SCRIPT_PATH, OPTION_SCRIPT_PATH,
			SCENE_PATH, CARD_SCENE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		if not ctx.check(not source.is_empty(), "%s 应能读取" % path):
			continue
		ctx.check(not source.contains("Color("), "%s 不得出现 Color(...) 字面量" % path)
	for path: String in [SCREEN_SCRIPT_PATH, CARD_SCRIPT_PATH, LAYOUT_SCRIPT_PATH, OPTION_SCRIPT_PATH]:
		var script: GDScript = load(path)
		ctx.check(script != null and script.can_instantiate(), "%s 应能编译" % path)

	ctx.begin_case("REWARD · 不得自动推进：无任何计时器（03 §2 / 00 §5）")
	for path: String in [SCREEN_SCRIPT_PATH, CARD_SCRIPT_PATH, LAYOUT_SCRIPT_PATH, OPTION_SCRIPT_PATH]:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token: String in BANNED_TIMING_TOKENS:
			ctx.check(not code.contains(token), "%s 的代码中不得出现 `%s`" % [path.get_file(), token])

	ctx.begin_case("REWARD · 不得越界到 Stage 4 的奖励数值（S4-07）")
	for path: String in [SCREEN_SCRIPT_PATH, CARD_SCRIPT_PATH, LAYOUT_SCRIPT_PATH, OPTION_SCRIPT_PATH]:
		var code: String = _strip_comments(FileAccess.get_file_as_string(path))
		for token: String in STAGE4_TOKENS:
			ctx.check(not code.contains(token), "%s 的代码中不得出现 `%s`" % [path.get_file(), token])

	ctx.begin_case("REWARD · 场景路由的唯一落点（03 §1.1 R3）")
	ctx.check(not _strip_comments(FileAccess.get_file_as_string(SCREEN_SCRIPT_PATH))
		.contains("change_scene_to_file"), "reward_screen.gd 不得自行换场景")
	ctx.check(not _strip_comments(FileAccess.get_file_as_string(CARD_SCRIPT_PATH))
		.contains("GameFlow"), "reward_card.gd 不得碰状态机（路由归 reward_screen.gd）")


## 06 §9 的宽屏数值：标题栏横贯安全区，三张卡片等宽等高三列。
func _run_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 标题栏与三列卡片矩形（06 §9）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "reward_layout.gd 应能加载"):
		return
	ctx.check(not layout.is_narrow(REFERENCE_VIEWPORT), "320×180 基准应判定为宽屏")

	ctx.equal(layout.title_rect(REFERENCE_VIEWPORT), TITLE_RECT, "标题栏矩形")
	ctx.equal(layout.cards_rect(REFERENCE_VIEWPORT), CARDS_RECT, "卡片区矩形")

	var rects: Array[Rect2] = layout.card_rects(REFERENCE_VIEWPORT)
	if not ctx.check(rects.size() == CARD_RECTS.size(), "06 §9：应给出 3 个选项位"):
		return
	for index: int in CARD_RECTS.size():
		ctx.equal(rects[index], CARD_RECTS[index], "%s 的矩形" % CARD_NAMES[index])

	# 枚举顺序 = 场景节点顺序。错位不会报错，只会把矩形贴到别的节点上。
	ctx.equal(layout.Region.TITLE, 0, "Region.TITLE 的序号")
	ctx.equal(layout.Region.CARDS, 1, "Region.CARDS 的序号")

	# 几何关系（由规范推出，不是抄来的魔数）：三列等宽等高、间距 8、两端各留 8 安全边距。
	# 卡片矩形以**卡片区原点**为基准，故安全边距要加回卡片区自己的位置才是屏幕坐标。
	var gap: float = rects[1].position.x - rects[0].end.x
	ctx.equal(gap, 8.0, "相邻卡片间距（06 §1 间距刻度）")
	ctx.equal(CARDS_RECT.position.x + rects[0].position.x, 8.0, "首张卡片的左安全边距（06 §1）")
	ctx.equal(CARDS_RECT.position.x + rects[2].end.x, REFERENCE_VIEWPORT.x - 8.0,
		"末张卡片的右安全边距（06 §1）")
	ctx.equal(rects[0].size.x, rects[1].size.x, "三列必须等宽")
	ctx.equal(rects[1].size.x, rects[2].size.x, "三列必须等宽")
	ctx.equal(rects[0].position.y, rects[1].position.y, "三列必须同高同起点")
	ctx.equal(rects[0].position.y, rects[2].position.y, "三列必须同高同起点")
	ctx.equal(layout.cards_rect(REFERENCE_VIEWPORT).end.y, REFERENCE_VIEWPORT.y - 8.0,
		"卡片区应铺到底部安全线")
	# 标题栏在卡片区之上，两者不重叠 —— 否则第一行卡片会被标题栏压住。
	ctx.equal(TITLE_RECT.end.y + gap, CARDS_RECT.position.y, "标题栏与卡片区之间隔一个间距")


## 06 §7.1 的移动端折叠：三列横排改三行竖排。折叠只改变布局，不改变任何玩法规则与状态流。
func _run_narrow_layout_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 窄屏折叠（06 §7.1）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "reward_layout.gd 应能加载"):
		return

	ctx.check(layout.is_narrow(NARROW_VIEWPORT), "180×320 竖屏应判定为窄屏")
	ctx.check(not layout.is_narrow(REFERENCE_VIEWPORT), "320×180 基准应判定为宽屏")
	ctx.check(not layout.is_narrow(Vector2(320.0, 320.0)), "1:1 应判定为宽屏（判定是 < 而非 <=）")
	ctx.check(not layout.is_narrow(Vector2.ZERO), "拿不到尺寸时应按宽屏处理，不得随手折叠")

	_check_rect_approx(ctx, layout.title_rect(NARROW_VIEWPORT), NARROW_TITLE_RECT, "窄屏标题栏矩形")
	_check_rect_approx(ctx, layout.cards_rect(NARROW_VIEWPORT), NARROW_CARDS_RECT, "窄屏卡片区矩形")

	var rects: Array[Rect2] = layout.card_rects(NARROW_VIEWPORT)
	if not ctx.check(rects.size() == NARROW_CARD_RECTS.size(), "窄屏同样应给出 3 个选项位"):
		return
	for index: int in NARROW_CARD_RECTS.size():
		_check_rect_approx(ctx, rects[index], NARROW_CARD_RECTS[index], "%s 的折叠矩形" % CARD_NAMES[index])

	# 折叠的形态由「同 x、递增 y」证明，而不是由某个宽高数字证明。
	ctx.equal(rects[0].position.x, rects[1].position.x, "折叠后三张卡片应同处一列")
	ctx.equal(rects[1].position.x, rects[2].position.x, "折叠后三张卡片应同处一列")
	ctx.check(rects[0].end.y <= rects[1].position.y and rects[1].end.y <= rects[2].position.y,
		"折叠后三张卡片应自上而下依次排列且不重叠")
	ctx.equal(rects[1].position.y - rects[0].end.y, 8.0, "折叠后的行间距（06 §1）")


## 06 §1：可点击区域 —— 卡片本身就是可点击区域，两个档位下都不得低于 44。
func _run_touch_size_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 卡片可点击区域 ≥ 44（06 §1）")
	var layout: GDScript = load(LAYOUT_SCRIPT_PATH)
	if not ctx.check(layout != null, "reward_layout.gd 应能加载"):
		return
	for viewport: Vector2 in [REFERENCE_VIEWPORT, NARROW_VIEWPORT, SHORT_NARROW_VIEWPORT]:
		var rects: Array[Rect2] = layout.card_rects(viewport)
		var bad: int = 0
		for rect: Rect2 in rects:
			if rect.size.x < MIN_TOUCH_SIZE or rect.size.y < MIN_TOUCH_SIZE:
				bad += 1
		ctx.check(bad == 0, "%s 下三张卡片都不得低于 %d×%d（违例 %d 张，实得 %s）" % [
			viewport, int(MIN_TOUCH_SIZE), int(MIN_TOUCH_SIZE), bad, str(rects[0].size)])


## 06 §9：选项 3 个，**不足时以「跳过」补齐**。补齐是纯数据行为，故脱离场景树单测。
func _run_option_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 「跳过」补齐（06 §9）")
	var option_script: GDScript = load(OPTION_SCRIPT_PATH)
	if not ctx.check(option_script != null, "reward_option.gd 应能加载"):
		return

	var skip: RewardOption = option_script.skip()
	ctx.check(skip.is_skip(), "「跳过」应被 is_skip() 认出")
	ctx.equal(skip.name_key, option_script.SKIP_NAME_KEY, "「跳过」项的名称取自 SKIP_NAME_KEY")
	ctx.equal(skip.name_key, "跳过", "06 §9 的补齐项名称逐字是「跳过」")
	ctx.check(skip.type_key.is_empty() and skip.value_key.is_empty() and skip.rule_key.is_empty(),
		"「跳过」不得编造类型 / 数值 / 特殊规则（这三个展示位在它身上整行隐藏）")

	var core: RewardOption = option_script.new(option_script.Kind.CORE, "甲", "CORE", "1", "规则")
	ctx.check(not core.is_skip(), "普通选项不得被当成「跳过」")
	ctx.equal(core.name_key, "甲", "普通选项的名称")

	# pad() 的形参是强类型 Array[RewardOption]，这里就得按强类型数组喂它 ——
	# 拿裸数组字面量去调会当场报「元素类型不符」，那正是静态类型该有的样子。
	var one: Array[RewardOption] = []
	one.append(core)
	var padded: Array[RewardOption] = option_script.pad(one, 3)
	ctx.equal(padded.size(), 3, "不足 3 个时应补齐到 3 个")
	ctx.equal(padded[0], core, "补齐不得打乱已有顺序")
	ctx.check(padded[1].is_skip() and padded[2].is_skip(), "缺的位置应由「跳过」补上")

	var none: Array[RewardOption] = []
	ctx.equal(option_script.pad(none, 3).size(), 3, "一项都没有时也应得到 3 个「跳过」")
	var four: Array[RewardOption] = [core, core, core, core]
	ctx.equal(option_script.pad(four, 3).size(), 3, "超过 3 个时应截断回 3 个")

	ctx.begin_case("REWARD · 占位选项（本批无奖励数据源）")
	var screen_script: GDScript = load(SCREEN_SCRIPT_PATH)
	var defaults: Array[RewardOption] = screen_script.default_options()
	ctx.equal(defaults.size(), 3, "占位选项应恰好 3 个")
	for index: int in defaults.size():
		var option: RewardOption = defaults[index]
		ctx.check(not option.is_skip(), "第 %d 个占位选项不该是「跳过」" % (index + 1))
		ctx.check(not option.name_key.is_empty() and not option.type_key.is_empty()
			and not option.value_key.is_empty() and not option.rule_key.is_empty(),
			"第 %d 个占位选项的四个文字展示位都要有落点" % (index + 1))


## S4-07 最小版：三选一**真的落到蓝图**。这一条查的是「选项 -> 落地载荷」这段映射。
##
## 它是本卡唯一一处「玩家点的那一项」与「画布上长出什么」之间的接缝，而接缝错了在画面上
## 完全看不出来：卡面照样是三张、画布照样多一个节点，只有类型悄悄换了。
## 故这里逐项对死：载荷的三列必须**逐字等于**仓库那一行，且卡面的名字与落地的名字一致。
func _run_payload_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 选项与落地载荷（S4-07 最小版）")
	var screen_script: GDScript = load(SCREEN_SCRIPT_PATH)
	var workspace_script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	var kinds: GDScript = load(NODE_DATA_PATH)
	var option_script: GDScript = load(OPTION_SCRIPT_PATH)
	if not ctx.check(screen_script != null and workspace_script != null and kinds != null
			and option_script != null, "reward_screen / blueprint_workspace / node_data 应能加载"):
		return

	var slots: Array = screen_script.OPTION_SLOTS
	var warehouse: Array = workspace_script.WAREHOUSE
	if not ctx.check(slots.size() == 3, "三个选项应各对应一个仓库槽位（实得 %d）" % slots.size()):
		return

	var defaults: Array[RewardOption] = screen_script.default_options()
	ctx.equal(defaults.size(), slots.size(), "选项数与槽位数应一致")
	for index: int in slots.size():
		var slot: int = int(slots[index])
		if not ctx.check(slot >= 0 and slot < warehouse.size(),
				"第 %d 个选项对应的槽位应存在（实际 %d）" % [index + 1, slot]):
			continue
		var entry: Dictionary = warehouse[slot]
		var payload: Dictionary = screen_script.reward_payload(slot)
		# 三列类型逐字对照：载荷是仓库那一行的**转写**，不是重新算出来的一份。
		ctx.equal(int(payload["kind"]), int(entry["kind"]), "第 %d 项落地的节点类型" % (index + 1))
		ctx.equal(int(payload["function_kind"]), int(entry["function_kind"]),
			"第 %d 项落地的 function_kind" % (index + 1))
		ctx.equal(int(payload["weapon_kind"]), int(entry["weapon_kind"]),
			"第 %d 项落地的 weapon_kind" % (index + 1))
		ctx.equal(String(payload["name"]), String(entry["name"]), "第 %d 项落地的显示名" % (index + 1))
		# 卡面上的名字与落地后的名字必须逐字相同：玩家照着卡面做决定，两处漂开就是「说一套做一套」。
		ctx.equal(defaults[index].name_key, String(payload["name"]),
			"第 %d 项的卡面名字与落地名字" % (index + 1))

	# 三个选项的类型各不相同，且与卡面的 Kind 一一对应 —— 仓库表重排时这里当场转红。
	var expected: Array[int] = [option_script.Kind.CORE, option_script.Kind.FUNCTION,
		option_script.Kind.WEAPON]
	for index: int in expected.size():
		ctx.equal(int(defaults[index].kind), expected[index], "第 %d 项的卡面类型" % (index + 1))

	# 真正会走的那一段：玩家点下去时，屏幕按**选项本身**问它落什么。
	# 上面对的是「槽位号 -> 载荷」这张表；表全绿而这条线断掉的写法有的是 ——
	# 本卡就踩过一次：当时按「选项对象的身份」去一张临时重建的池里找，永远找不到，
	# 于是卡面照常、点击照常、**什么都不落**。故这里逐个选项走真实入口。
	for index: int in defaults.size():
		var payload: Dictionary = screen_script.payload_for(defaults[index])
		if not ctx.check(not payload.is_empty(),
				"第 %d 项点下去应落下东西（空 = 点了没反应）" % (index + 1)):
			continue
		ctx.equal(String(payload["name"]), defaults[index].name_key,
			"第 %d 项落下的应与卡面写的是同一件东西" % (index + 1))
		var slot: int = int(slots[int(defaults[index].kind)])
		ctx.equal(int(payload["weapon_kind"]), int(warehouse[slot]["weapon_kind"]),
			"第 %d 项落下的 weapon_kind" % (index + 1))
	# 反向对照：「跳过」是补齐位，点它必须什么都不落（落一个空节点就是凭空多出来的东西）。
	var skip: RewardOption = option_script.skip()
	ctx.check(screen_script.payload_for(skip).is_empty(),
		"「跳过」不得落下任何东西（Kind.SKIP 不在 OPTION_SLOTS 之内）")
	ctx.check(screen_script.payload_for(null).is_empty(), "空选项不得落下任何东西")

	# 验收点名的三项，逐个反向对照：炸弹必须真的带 BOMB（它一旦落成针，验收的
	# 「伤害 25 / 打全场」就整条落空）；核心 / 增幅 的 weapon_kind 必须留 NONE。
	var third: int = 2
	ctx.equal(defaults[third].name_key, "炸弹", "第 3 项应是炸弹")
	ctx.equal(int(screen_script.reward_payload(int(slots[third]))["weapon_kind"]),
		kinds.WeaponKind.BOMB, "炸弹落地后的 weapon_kind")
	ctx.equal(int(screen_script.reward_payload(int(slots[0]))["weapon_kind"]),
		kinds.WeaponKind.NONE, "核心不是武器，weapon_kind 必须留 NONE")
	ctx.equal(int(screen_script.reward_payload(int(slots[1]))["function_kind"]),
		kinds.Function.AMPLIFY, "增幅落地后的 function_kind 应是 AMPLIFY")
	ctx.equal(int(screen_script.reward_payload(int(slots[0]))["function_kind"]),
		kinds.Function.NONE, "核心不是功能节点，function_kind 必须留 NONE")

	# 类型来源纪律：载荷只能来自仓库表，且跨场景只能走 RunState 这个既有 Autoload
	# （不新造全局单例 / 不新开存档服务）。两条都是「怎么做到的」层面的钉子，
	# 光看行为断言不出来 —— 行得通但来源错了的写法有一堆。
	var code: String = _strip_comments(FileAccess.get_file_as_string(SCREEN_SCRIPT_PATH))
	ctx.check(code.contains("BlueprintWorkspace.WAREHOUSE"),
		"落地载荷应取自 blueprint_workspace 的仓库表（类型的唯一来源）")
	ctx.check(code.contains("RunState.set_pending_reward"),
		"选中项应经 RunState 这个既有载体跨场景传递")
	ctx.check(not code.contains("BY_DISPLAY_NAME"),
		"不得按显示名反查类型 —— PET-70 已删掉那条路，这里不得接回来")


## 06 §4 的类型标识色是全项目唯一一处「类型 -> 颜色」对照，奖励卡的图标复用它。
func _run_icon_color_checks(ctx: RefCounted) -> void:
	ctx.begin_case("REWARD · 图标类型色（06 §4）")
	var card_script: GDScript = load(CARD_SCRIPT_PATH)
	var option_script: GDScript = load(OPTION_SCRIPT_PATH)
	var palette_script: GDScript = load(PALETTE_SCRIPT_PATH)
	if not ctx.check(card_script != null and option_script != null and palette_script != null,
			"卡片脚本、选项脚本与 palette.gd 应能加载"):
		return
	ctx.equal(card_script.icon_color(option_script.Kind.CORE),
		palette_script.get_color(palette_script.Key.GOLD_400), "CORE 的类型色")
	ctx.equal(card_script.icon_color(option_script.Kind.FUNCTION),
		palette_script.get_color(palette_script.Key.BLUE_400), "FUNCTION 的类型色")
	ctx.equal(card_script.icon_color(option_script.Kind.WEAPON),
		palette_script.get_color(palette_script.Key.ORANGE_500), "WEAPON 的类型色")
	# 「跳过」不是一种节点类型，06 §4 没有它 —— 只要求它不与三种类型混同。
	# 具体取哪个中性色是观感判断，已回报 DSH（由 Codex 定），故这里不钉死色号。
	var skip_color: Color = card_script.icon_color(option_script.Kind.SKIP)
	for kind: int in [option_script.Kind.CORE, option_script.Kind.FUNCTION, option_script.Kind.WEAPON]:
		ctx.not_equal(skip_color, card_script.icon_color(kind), "「跳过」的图标色不得与类型色混同")


func _run_structure_checks(ctx: RefCounted, packed: PackedScene) -> void:
	ctx.begin_case("REWARD · 三张选项卡的装配（06 §9）")
	var scene: Node = packed.instantiate()
	if not ctx.check(scene != null, "reward.tscn 应能实例化"):
		return
	ctx.check(_find(scene, "Backdrop") != null, "应有全屏底色层（色值在 _ready() 里取自 Palette）")
	ctx.check(_find(scene, "NoticePanel") != null, "应有路由故障时的提示落点")

	_check_literals(ctx, scene, "TitleBar", TITLE_RECT)
	_check_literals(ctx, scene, "CardsArea", CARDS_RECT)
	var cards_area: Control = _find(scene, "CardsArea") as Control
	if not ctx.check(cards_area != null, "应有三张卡片的容器"):
		scene.free()
		return
	# 卡片区自己不吃点击：卡片之间的缝隙不该被它截住（截住也只是白点一下，但语义要清楚）。
	ctx.equal(cards_area.mouse_filter, Control.MOUSE_FILTER_IGNORE, "卡片区自身不得吃掉点击")

	var cards: Array[Node] = cards_area.get_children()
	ctx.equal(cards.size(), 3, "06 §9：恰好三个选项位")
	for index: int in cards.size():
		_check_card(ctx, cards[index], index)

	# 06 §9 的界面就是「三张卡片 + 跳过（补位）」本身，没有第四个确认按钮 ——
	# 选中即离开，不存在「先选后确认」这一步。
	var buttons: Array[Button] = []
	_collect_buttons(scene, buttons)
	ctx.equal(buttons.size(), 0, "奖励界面不得有按钮（实际 %d 个：%s）" % [buttons.size(), _names(buttons)])
	scene.free()


## 卡片是 Panel + gui_input（Theme 里没有「卡片按钮」变体），故「可点击」= 它收鼠标事件。
func _check_card(ctx: RefCounted, card: Node, index: int) -> void:
	var control: Panel = card as Panel
	if not ctx.check(control != null, "第 %d 张卡片应实例自 reward_card.tscn 的 Panel" % (index + 1)):
		return
	ctx.equal(control.name, CARD_NAMES[index], "第 %d 张卡片的节点名" % (index + 1))
	ctx.equal(control.mouse_filter, Control.MOUSE_FILTER_STOP,
		"%s 必须收点击 —— 它的整个矩形就是 06 §1 说的可点击区域" % CARD_NAMES[index])
	ctx.equal(control.theme_type_variation, &"PanelSecondary", "%s 的底色走次级面板变体（06 §3）" % CARD_NAMES[index])
	# 06 §9.1 v0.1.12：选项卡是**浮动的次级面板**，应带 PanelShadow 叠层（与 RESULT 读数区同款），
	# 且叠层必须排在内容 Layout **之前** —— 排到后面会盖住文字（Codex 点名）。像素证据见 reward_probe.gd。
	var shadow: Panel = _find(control, "Shadow") as Panel
	if ctx.check(shadow != null, "%s 应带 PanelShadow 叠层（06 §9.1）" % CARD_NAMES[index]):
		ctx.equal(shadow.theme_type_variation, &"PanelShadow", "%s 阴影叠层的变体" % CARD_NAMES[index])
		ctx.equal(shadow.mouse_filter, Control.MOUSE_FILTER_IGNORE, "%s 阴影叠层不得吃掉点击" % CARD_NAMES[index])
		var layout: Control = _find(control, "Layout") as Control
		ctx.check(layout != null and shadow.get_index() < layout.get_index(),
			"%s 的 Shadow 必须排在内容 Layout 之前（06 §9.1）" % CARD_NAMES[index])
	_check_literals(ctx, control, "", CARD_RECTS[index], true)

	for field: String in FIELD_NAMES:
		var node: Control = _find(control, field) as Control
		if not ctx.check(node != null, "%s 应有「%s」展示位" % [CARD_NAMES[index], field]):
			continue
		# 展示位不得吃掉卡片的点击，否则卡片中间那一大块看起来能点、实际点不动。
		ctx.equal(node.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"%s 的「%s」不得吃掉点击" % [CARD_NAMES[index], field])
	# 「图标」这个展示位的落点是一块纯色矩形，颜色在运行时由 apply_option() 取自 Palette。
	ctx.check(_find(control, "Icon") is ColorRect, "%s 的图标落点应是 ColorRect" % CARD_NAMES[index])
	ctx.check((_find(control, "Icon") as ColorRect).custom_minimum_size.x > 0.0,
		"%s 的图标落点应有正的尺寸" % CARD_NAMES[index])


## .tscn 里的 offset 只能是字面量，这里拿规范值与常量核对它 —— 两边一旦漂开就不再是「一处定义」。
## local=true 时按「相对父节点」比对（卡片是卡片区的子节点）。
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
		# 子节点的 offset 以父节点左上角为原点（layout_mode = 0）。
		ctx.equal(offset, expected.position, "%s 的 offset 左上角（相对卡片区）" % label)
	ctx.equal(Vector2(control.offset_right, control.offset_bottom), expected.end, "%s 的 offset 右下角" % label)


func _collect_buttons(node: Node, found: Array[Button]) -> void:
	var button: Button = node as Button
	if button != null:
		found.append(button)
	for child: Node in node.get_children():
		_collect_buttons(child, found)


func _names(nodes: Array[Button]) -> String:
	var out: PackedStringArray = []
	for node: Button in nodes:
		out.append(String(node.name))
	return ", ".join(out) if out.size() > 0 else "无"


## 去掉注释再扫描：本仓库的文档注释里大量提到被禁的构造（正是为了声明「不许用」），
## 直接全文匹配会把「写明禁令」误判成「违反禁令」。同 test_preparation.gd 的 _strip_comments。
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
