## test_game_flow.gd
## 职责：顶层状态机的验收 —— 迁移表的硬规则 R1（只有玩家动作能进战斗）、R4（发信号）、R5（不许重入）。
## 所属系统：tests
## 依赖：GameFlow（经 /root 取）
## 禁止：本文件不得改动单例的真实状态 —— 所有断言都在临时副本上跑。
##
## 为什么用副本：GameFlow 是 Autoload 单例，在它上面跑来跑去会真的把游戏切到别的场景。
## 这里 new 出独立实例跑状态机，并确认副本**不会**触发场景路由（owns_scene_routing）。

extends RefCounted

## 从 BOOT 出发，一条走得通的完整回路。
const HAPPY_PATH: PackedInt32Array = [1, 4, 2, 3, 1]  # BOOT→EDITOR→MAP→COMBAT→REWARD→EDITOR


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_game_flow")
	var live: Node = tree.root.get_node_or_null(^"GameFlow")
	if not ctx.check(live != null, "GameFlow 单例存在"):
		return
	_check_transition_table(ctx, live)
	_check_happy_path(ctx, live)
	_check_combat_entry_is_guarded(ctx, live)
	_check_reentry_gate(ctx, live)
	_check_signals(ctx, live)
	_check_copies_do_not_route(ctx, live)
	_check_state_names(ctx, live)


func _check_transition_table(ctx: RefCounted, live: Node) -> void:
	var states: Array = [1, 2, 3, 4]
	for from: int in states:
		for to: int in states:
			if from == to:
				ctx.check(not live.is_transition_allowed(from, to),
					"%s 不能切到自己" % live.state_name(from))
	ctx.check(live.is_transition_allowed(1, 4), "编辑器 → 路线图 合法")
	ctx.check(live.is_transition_allowed(4, 1), "路线图 → 编辑器 合法")
	ctx.check(not live.is_transition_allowed(1, 2), "编辑器 → 战斗 **不合法**（必须走玩家动作，R1）")
	ctx.check(not live.is_transition_allowed(3, 2), "奖励 → 战斗 不合法（必须先回编辑器）")
	ctx.check(not live.is_transition_allowed(1, 3), "编辑器 → 奖励 不合法")
	ctx.check(not live.is_transition_allowed(0, 2), "启动 → 战斗 不合法")
	# 每个状态都要有出路，否则切进去就出不来了。
	for from: int in states:
		var targets: Array = live.ALLOWED_TRANSITIONS[from]
		ctx.check(targets.size() > 0, "%s 有出路" % live.state_name(from))


func _check_happy_path(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	ctx.equal(flow.get_state(), 0, "副本从 BOOT 开始")
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
	ctx.equal(flow.get_state(), 0, "被拒绝的请求没有改动状态")
	flow.change_state(1)
	ctx.check(flow.request_start_combat(), "编辑器里可以开始战斗")
	ctx.equal(flow.get_state(), 2, "开始战斗后进入 COMBAT")
	# 反向对照：COMBAT 里再按一次不该有任何效果。
	ctx.check(not flow.request_start_combat(), "战斗进行中不能再次开始战斗")
	ctx.equal(flow.get_state(), 2, "第二次请求没有改动状态")

	# MAP 是另一条合法入口（从路线图上选一个战斗节点）。
	var from_map: Node = _fresh(live)
	from_map.change_state(1)
	from_map.change_state(4)
	ctx.check(from_map.request_start_combat(), "路线图里也可以开始战斗")

	# REWARD 里不行 —— 奖励屏不能直接跳回战斗。
	var from_reward: Node = _fresh(live)
	from_reward.change_state(1)
	from_reward.change_state(4)
	from_reward.request_start_combat()
	from_reward.change_state(3)
	ctx.check(not from_reward.request_start_combat(), "奖励屏里不能开始战斗")
	ctx.equal(from_reward.get_state(), 3, "被拒绝后仍停在奖励屏")


## R5：切换期间（信号回调里）再次请求切换必须被拒绝。
func _check_reentry_gate(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	var outcome: Array = [null]
	flow.state_changed.connect(func(_from: int, _to: int) -> void:
		outcome[0] = flow.change_state(3))
	ctx.check(flow.change_state(1), "第一次切换成功")
	ctx.check(outcome[0] != null and not outcome[0], "信号回调里的重入请求被拒绝（R5）")
	ctx.equal(flow.get_state(), 1, "重入被拒后状态仍是第一次切到的那个")
	# 闸门在切换结束后必须落回 —— 否则状态机会永久卡死。
	ctx.check(flow.change_state(4), "重入闸门已落闸，下一次切换正常")


## R4：一次切换只发一次信号，且 from / to 正确。
func _check_signals(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	var seen: Array = []
	flow.state_changed.connect(func(from: int, to: int) -> void: seen.append([from, to]))
	flow.change_state(1)
	flow.change_state(4)
	ctx.equal(seen.size(), 2, "两次切换发两次信号")
	ctx.equal(seen[0], [0, 1], "第一次信号 from=BOOT to=EDITOR")
	ctx.equal(seen[1], [1, 4], "第二次信号 from=EDITOR to=MAP")
	# 唯一一处刻意触发的非法迁移（会记一条 ERROR 日志，属预期）：
	# 价值在于证明「被拒绝的切换**不发信号**、也不改状态」。
	ctx.check(not flow.change_state(3), "MAP → REWARD 不合法，被拒绝")
	ctx.equal(seen.size(), 2, "被拒绝的切换没有发信号")
	ctx.equal(flow.get_state(), 4, "被拒绝的切换没有改状态")


func _check_copies_do_not_route(ctx: RefCounted, live: Node) -> void:
	var flow: Node = _fresh(live)
	ctx.check(live.owns_scene_routing(), "单例本尊承担场景路由")
	ctx.check(not flow.owns_scene_routing(), "测试副本**不**承担场景路由（所以跑状态机不会把游戏切走）")
	for state: int in [1, 2, 3, 4]:
		ctx.check(ResourceLoader.exists(live.get_scene_path_for(state)),
			"%s 的场景文件存在" % live.state_name(state))
	ctx.equal(live.get_scene_path_for(0), "", "BOOT 不经路由（它是主场景，由引擎落地）")


func _check_state_names(ctx: RefCounted, live: Node) -> void:
	ctx.equal(live.state_name(0), &"BOOT", "0 = BOOT")
	ctx.equal(live.state_name(1), &"EDITOR", "1 = EDITOR")
	ctx.equal(live.state_name(2), &"COMBAT", "2 = COMBAT")
	ctx.equal(live.state_name(3), &"REWARD", "3 = REWARD")
	ctx.equal(live.state_name(4), &"MAP", "4 = MAP")
	ctx.equal(live.state_name(99), &"UNKNOWN", "反向对照：未知状态有名可查，不崩")


## 造一个游离的副本。不挂进树 —— 它没有 get_tree()，因此 owns_scene_routing() 为 false。
func _fresh(live: Node) -> Node:
	return live.get_script().new()
