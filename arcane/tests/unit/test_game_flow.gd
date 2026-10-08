## test_game_flow.gd
## 职责：顶层状态机的验收 —— 迁移表的硬规则 R1（只有玩家动作能进战斗）、R4（发信号）、R5（不许重入）。
## 所属系统：tests
## 依赖：GameFlow（经 /root 取）
## 禁止：本文件不得改动单例的真实状态 —— 所有断言都在临时副本上跑。
##
## 为什么用副本：GameFlow 是 Autoload 单例，在它上面跑来跑去会真的把游戏切到别的场景。
## 这里 new 出独立实例跑状态机，并确认副本**不会**触发场景路由（owns_scene_routing）。
##
## PET-90：加了 MAIN_MENU 之后，下面的状态序号整体后移。序号只在 *_INDEX 常量里写一次，
## 用例正文一律按名字读 —— 否则下次再插一个状态，满篇的数字都要重新数一遍。
## 「序号没被谁悄悄改过」这件事由 _check_state_names 单独钉死。
##
## PET-92：加了 RESULT（本局的结局）。同样只在常量里写一次序号。

extends RefCounted

const BOOT: int = 0
const MAIN_MENU: int = 1
const EDITOR: int = 2
const COMBAT: int = 3
const REWARD: int = 4
const MAP: int = 5
const RESULT: int = 6

## 全部状态，供「两两互查合法性」之类的遍历用。
const ALL_STATES: PackedInt32Array = [BOOT, MAIN_MENU, EDITOR, COMBAT, REWARD, MAP, RESULT]
## 需要场景路由的状态（BOOT 除外：它是主场景，由引擎落地）。
const ROUTED_STATES: PackedInt32Array = [MAIN_MENU, EDITOR, COMBAT, REWARD, MAP, RESULT]

## 从 BOOT 出发，一条走得通的完整回路（装的是**每一次切换的目标状态**）。
## 第二圈刻意走「打穿最后一层 → RESULT → 再来一局」，于是新加的那几条边都在回路里被真的走一遍。
const HAPPY_PATH: PackedInt32Array = [MAIN_MENU, EDITOR, MAP, COMBAT, REWARD, MAP, COMBAT, RESULT, EDITOR]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_game_flow")
	var live: Node = tree.root.get_node_or_null(^"GameFlow")
	if not ctx.check(live != null, "GameFlow 单例存在"):
		return
	_check_transition_table(ctx, live)
	_check_happy_path(ctx, live)
	_check_combat_entry_is_guarded(ctx, live)
	_check_result_entry_is_guarded(ctx, live)
	_check_reentry_gate(ctx, live)
	_check_signals(ctx, live)
	_check_copies_do_not_route(ctx, live)
	_check_state_names(ctx, live)


func _check_transition_table(ctx: RefCounted, live: Node) -> void:
	for from: int in ALL_STATES:
		for to: int in ALL_STATES:
			if from == to:
				ctx.check(not live.is_transition_allowed(from, to),
					"%s 不能切到自己" % live.state_name(from))
	# PET-90：启动的落点。旧工程有这一步，新工程此前漏了 —— 于是启动直接落进编辑器。
	ctx.check(live.is_transition_allowed(BOOT, MAIN_MENU), "启动 → 主菜单 合法")
	ctx.check(not live.is_transition_allowed(BOOT, EDITOR), "启动 → 编辑器 **不合法**（必须经主菜单）")
	ctx.check(not live.is_transition_allowed(BOOT, COMBAT), "启动 → 战斗 不合法")
	# 主菜单的两条去向：新开一局走编辑器，继续一局走路线图。
	ctx.check(live.is_transition_allowed(MAIN_MENU, EDITOR), "主菜单 → 编辑器 合法（开始新一局）")
	ctx.check(live.is_transition_allowed(MAIN_MENU, MAP), "主菜单 → 路线图 合法（继续一局）")
	ctx.check(not live.is_transition_allowed(MAIN_MENU, COMBAT), "主菜单 → 战斗 不合法（R1）")
	ctx.check(not live.is_transition_allowed(MAIN_MENU, REWARD), "主菜单 → 奖励 不合法")
	ctx.check(not live.is_transition_allowed(EDITOR, MAIN_MENU), "编辑器 → 主菜单 不合法（回主菜单要经结算屏）")
	ctx.check(live.is_transition_allowed(EDITOR, MAP), "编辑器 → 路线图 合法")
	ctx.check(live.is_transition_allowed(MAP, EDITOR), "路线图 → 编辑器 合法")
	ctx.check(not live.is_transition_allowed(EDITOR, COMBAT), "编辑器 → 战斗 **不合法**（必须走玩家动作，R1）")
	ctx.check(not live.is_transition_allowed(REWARD, COMBAT), "奖励 → 战斗 不合法（必须先回编辑器）")
	ctx.check(not live.is_transition_allowed(EDITOR, REWARD), "编辑器 → 奖励 不合法")
	# PET-92：奖励之后去路线图选下一站（不是回编辑器）——「一局」的推进由路线图管。
	ctx.check(live.is_transition_allowed(REWARD, MAP), "奖励 → 路线图 合法（选下一站）")
	ctx.check(live.is_transition_allowed(REWARD, EDITOR), "奖励 → 编辑器 合法（回书页调整）")
	# 结局：只有战斗打得完（打赢最后一层 / 核心没了）。
	ctx.check(live.is_transition_allowed(COMBAT, RESULT), "战斗 → 结算 合法（R2）")
	ctx.check(not live.is_transition_allowed(COMBAT, MAP), "战斗 → 路线图 **不再合法**（输了是结算，不是接着走）")
	ctx.check(not live.is_transition_allowed(REWARD, RESULT), "奖励 → 结算 不合法（本局还没结束）")
	ctx.check(not live.is_transition_allowed(MAP, RESULT), "路线图 → 结算 不合法")
	ctx.check(not live.is_transition_allowed(MAIN_MENU, RESULT), "主菜单 → 结算 不合法")
	# 结算之后的两条出口：回主菜单（再开一局）/ 直接再来一局。
	ctx.check(live.is_transition_allowed(RESULT, MAIN_MENU), "结算 → 主菜单 合法（PET-92 §4）")
	ctx.check(live.is_transition_allowed(RESULT, EDITOR), "结算 → 编辑器 合法（再来一局）")
	ctx.check(not live.is_transition_allowed(RESULT, COMBAT), "结算 → 战斗 不合法（新一局要先经编辑器/路线图）")
	# 每个状态都要有出路，否则切进去就出不来了。
	for from: int in ALL_STATES:
		var targets: Array = live.ALLOWED_TRANSITIONS[from]
		ctx.check(targets.size() > 0, "%s 有出路" % live.state_name(from))
	# 每个状态也都要**进得去**：没有任何一条边指向它 = 死状态（主菜单正是靠这一条盯着的）。
	for state: int in ALL_STATES:
		if state == BOOT:
			continue
		var inbound: int = 0
		for from: int in ALL_STATES:
			if live.is_transition_allowed(from, state):
				inbound += 1
		ctx.check(inbound > 0, "%s 进得去（有 %d 条入边）" % [live.state_name(state), inbound])


func _check_happy_path(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	ctx.equal(flow.get_state(), BOOT, "副本从 BOOT 开始")
	# HAPPY_PATH 装的是**每一次切换的目标状态**，所以从第 0 项就开始切（从第 1 项开始会漏掉第一步）。
	for index: int in HAPPY_PATH.size():
		var to: int = HAPPY_PATH[index]
		ctx.check(flow.change_state(to), "第 %d 步切到 %s" % [index + 1, live.state_name(to)])
		ctx.equal(flow.get_state(), to, "状态真的改了")
	# 重复切到当前态要被拒绝，而不是当成成功。
	ctx.check(not flow.change_state(flow.get_state()), "重复切到当前态返回 false")


## R1：进入 COMBAT 只有 request_start_combat() 一条路，且只在 EDITOR / MAP 下可用。
func _check_combat_entry_is_guarded(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	ctx.check(not flow.request_start_combat(), "BOOT 下不能开始战斗")
	ctx.equal(flow.get_state(), BOOT, "被拒绝的请求没有改动状态")
	flow.change_state(MAIN_MENU)
	ctx.check(not flow.request_start_combat(), "主菜单里也不能开始战斗（要先开一局）")
	ctx.equal(flow.get_state(), MAIN_MENU, "主菜单里被拒绝的请求没有改动状态")
	flow.change_state(EDITOR)
	ctx.check(flow.request_start_combat(), "编辑器里可以开始战斗")
	ctx.equal(flow.get_state(), COMBAT, "开始战斗后进入 COMBAT")
	# 反向对照：COMBAT 里再按一次不该有任何效果。
	ctx.check(not flow.request_start_combat(), "战斗进行中不能再次开始战斗")
	ctx.equal(flow.get_state(), COMBAT, "第二次请求没有改动状态")

	# MAP 是另一条合法入口（从路线图上选一个战斗节点）。
	var from_map: Node = _fresh(live)
	from_map.change_state(MAIN_MENU)
	from_map.change_state(MAP)
	ctx.check(from_map.request_start_combat(), "路线图里也可以开始战斗")

	# REWARD 里不行 —— 奖励屏不能直接跳回战斗。
	var from_reward: Node = _fresh(live)
	from_reward.change_state(MAIN_MENU)
	from_reward.change_state(MAP)
	from_reward.request_start_combat()
	from_reward.change_state(REWARD)
	ctx.check(not from_reward.request_start_combat(), "奖励屏里不能开始战斗")
	ctx.equal(from_reward.get_state(), REWARD, "被拒绝后仍停在奖励屏")


## R2 + R3：进入 RESULT 只有 request_end_run() 一条路，且只在 COMBAT 下可用。
## 与 request_start_combat 对称 —— 「结算」和「开打」一样是玩家动作，不是任何模块能顺手做的事。
func _check_result_entry_is_guarded(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	ctx.check(not flow.request_end_run(), "BOOT 下不能结算")
	ctx.equal(flow.get_state(), BOOT, "被拒绝的请求没有改动状态")
	flow.change_state(MAIN_MENU)
	flow.change_state(EDITOR)
	ctx.check(not flow.request_end_run(), "编辑器里不能结算（本局还没打）")
	ctx.equal(flow.get_state(), EDITOR, "编辑器里被拒绝的请求没有改动状态")
	ctx.check(flow.request_start_combat(), "先开打")
	ctx.check(flow.request_end_run(), "战斗里可以结算")
	ctx.equal(flow.get_state(), RESULT, "结算后进入 RESULT")
	# 反向对照：结算屏里再按一次不该有任何效果（否则结算屏会被反复重进）。
	ctx.check(not flow.request_end_run(), "结算屏里不能再次结算")
	ctx.equal(flow.get_state(), RESULT, "第二次请求没有改动状态")
	# 结算之后必须真的能出去 —— 只有 RESULT → MAIN_MENU 这一条回得到主菜单。
	ctx.check(flow.change_state(MAIN_MENU), "结算屏能回主菜单")
	ctx.equal(flow.get_state(), MAIN_MENU, "回到的是主菜单")


## R5：切换期间（信号回调里）再次请求切换必须被拒绝。
func _check_reentry_gate(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	var outcome: Array = [null]
	flow.state_changed.connect(func(_from: int, _to: int) -> void:
		outcome[0] = flow.change_state(REWARD))
	ctx.check(flow.change_state(MAIN_MENU), "第一次切换成功")
	ctx.check(outcome[0] != null and not outcome[0], "信号回调里的重入请求被拒绝（R5）")
	ctx.equal(flow.get_state(), MAIN_MENU, "重入被拒后状态仍是第一次切到的那个")
	# 闸门在切换结束后必须落回 —— 否则状态机会永久卡死。
	ctx.check(flow.change_state(EDITOR), "重入闸门已落闸，下一次切换正常")


## R4：一次切换只发一次信号，且 from / to 正确。
func _check_signals(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	var seen: Array = []
	flow.state_changed.connect(func(from: int, to: int) -> void: seen.append([from, to]))
	flow.change_state(MAIN_MENU)
	flow.change_state(EDITOR)
	ctx.equal(seen.size(), 2, "两次切换发两次信号")
	ctx.equal(seen[0], [BOOT, MAIN_MENU], "第一次信号 from=BOOT to=MAIN_MENU")
	ctx.equal(seen[1], [MAIN_MENU, EDITOR], "第二次信号 from=MAIN_MENU to=EDITOR")
	ctx.check(flow.change_state(MAP), "编辑器 → 路线图 合法")
	# 唯一一处刻意触发的非法迁移（会记一条 ERROR 日志，属预期）：
	# 价值在于证明「被拒绝的切换**不发信号**、也不改状态」。
	ctx.check(not flow.change_state(REWARD), "路线图 → 奖励 不合法，被拒绝")
	ctx.equal(seen.size(), 3, "被拒绝的切换没有发信号")
	ctx.equal(flow.get_state(), MAP, "被拒绝的切换没有改状态")


func _check_copies_do_not_route(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	ctx.check(live.owns_scene_routing(), "单例本尊承担场景路由")
	ctx.check(not flow.owns_scene_routing(), "测试副本**不**承担场景路由（所以跑状态机不会把游戏切走）")
	for state: int in ROUTED_STATES:
		ctx.check(ResourceLoader.exists(live.get_scene_path_for(state)),
			"%s 的场景文件存在" % live.state_name(state))
	ctx.equal(live.get_scene_path_for(BOOT), "", "BOOT 不经路由（它是主场景，由引擎落地）")


## 序号本身也要钉死：别的用例（含 --script 工具）按名气取，这里按序号核对 —— 两边对不上就红。
func _check_state_names(ctx: RefCounted, live: Node) -> void:
	ctx.equal(live.state_name(BOOT), &"BOOT", "0 = BOOT")
	ctx.equal(live.state_name(MAIN_MENU), &"MAIN_MENU", "1 = MAIN_MENU")
	ctx.equal(live.state_name(EDITOR), &"EDITOR", "2 = EDITOR")
	ctx.equal(live.state_name(COMBAT), &"COMBAT", "3 = COMBAT")
	ctx.equal(live.state_name(REWARD), &"REWARD", "4 = REWARD")
	ctx.equal(live.state_name(MAP), &"MAP", "5 = MAP")
	ctx.equal(live.state_name(RESULT), &"RESULT", "6 = RESULT")
	ctx.equal(live.state_name(99), &"UNKNOWN", "反向对照：未知状态有名可查，不崩")


## 造一个游离的副本。不挂进树 —— 它没有 get_tree()，因此 owns_scene_routing() 为 false。
func _fresh(live: Node) -> Node:
	return live.get_script().new()
