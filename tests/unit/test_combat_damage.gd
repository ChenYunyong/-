## test_combat_damage.gd
## 职责：COMBAT 真实化的**纯逻辑**用例（FIRST PLAYABLE 3/4）—— 敌人数值、敌人状态规则、
##       生成节奏与推进、三种打击范围的伤害结算、死亡与退场、本波清空与本局失败、
##       以及 MachineDriver 两种驱动对象的互斥。
## 所属系统：tests（09 §1 单元层 L1）
## 依赖：test_context, scripts/data/{enemy_data,weapon_data,node_data,connection_data,blueprint_data}.gd,
##       scripts/gameplay/{enemy_state,combat_simulation,machine_runtime,machine_driver}.gd
## 禁止：不得引用 Autoload 标识符（EventBus / GameFlow / DataRegistry / RunState / Settings）——
##       本文件由 run_tests.gd 在运行期 load()，但保持与既有用例同一条纪律，
##       于是一份用例可以被单独 --script 起来查问题时也不会先炸在编译期；
##       不得写任何字面色值；不得落盘任何文件（09 §4：测试数据不污染正式 data/）。
##
## 期望值一律在**本文件里独立复写一遍**（下面的常量），不转抄被测实现的常量 ——
## 期望值若与被测实现同源，实现改错时两边一起错，用例就成了同义反复（09 §4）。
##
## 判据是**节拍号**不是真实耗时（03 §6）：本文件手工调 tick()，一帧都不跑，
## 于是结论与帧率、机器快慢完全无关。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   负对照一 —— 把 CombatSimulation._on_weapon_fired 的 Reach.MELEE 分支改成不过滤进度，
##               「还在远处的敌人不掉血」必须转红。
##   负对照二 —— 把 take_damage 的 `hp > 0.0` 改成 `hp >= 0.0`，击杀判定与死亡拍号必须转红。
##   负对照三 —— 把 _spawn_due 的间隔换成 1，生成节奏那几条必须转红。

extends RefCounted

## 被测数据（02 §5）——本文件里独立复写一遍。
const SLIME_HP: float = 40.0
const SLIME_ADVANCE: float = 0.008
const RUNNER_HP: float = 15.0
const RUNNER_ADVANCE: float = 0.02
const NEEDLE_DAMAGE: float = 10.0
const BOMB_DAMAGE: float = 25.0
const SAW_DAMAGE: float = 4.0
const MELEE_FROM: float = 0.7

## 时间模型（03 §2 的固定节拍）。
const CORE_PERIOD: int = 10
const TRAVEL: int = 4
const DELAY_TICKS: int = 12

## 本波的生成节奏与 CORE 血量。
const SPAWN_FIRST: int = 10
const SPAWN_EVERY: int = 20
const CORE_MAX: float = 100.0
const LEAK_DAMAGE: float = 25.0
const VANISH_TICKS: int = 4

## 由上面几项推出来的几个拍号。首发拍号 = CORE 节拍 + 途经的每条边各 TRAVEL 拍。
const FIRE_DIRECT: int = CORE_PERIOD + TRAVEL
const FIRE_SPLIT: int = CORE_PERIOD + TRAVEL * 2
const FIRE_DELAY: int = CORE_PERIOD + TRAVEL + DELAY_TICKS + TRAVEL

## 占位敌人的出场顺序（EnemyData.Kind 的整数值：0 = Slime / 1 = Runner）。
const WAVE_ORDER: Array[int] = [0, 1, 0, 1]

var _cleared_count: int = 0
var _failed_count: int = 0


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_enemy_data_checks(ctx)
	_run_weapon_data_checks(ctx)
	_run_enemy_state_checks(ctx)
	_run_spawn_checks(ctx)
	_run_needle_checks(ctx)
	_run_bomb_checks(ctx)
	_run_saw_checks(ctx)
	_run_clear_checks(ctx)
	_run_failure_checks(ctx)
	_run_driver_checks(ctx)


## 敌人只有两种，数值差异就是「慢而肉」与「快而脆」（任务卡）。
func _run_enemy_data_checks(ctx: RefCounted) -> void:
	ctx.begin_case("EnemyData · 两种敌人的数值与工厂")
	var slime := EnemyData.for_kind(EnemyData.Kind.SLIME)
	var runner := EnemyData.for_kind(EnemyData.Kind.RUNNER)
	ctx.equal(slime.id, &"slime", "Slime 的 id")
	ctx.equal(slime.display_name, "Slime", "Slime 的显示名（战场上要能认出来）")
	ctx.equal(slime.max_hp, SLIME_HP, "Slime 的血量")
	ctx.equal(slime.advance_per_tick, SLIME_ADVANCE, "Slime 每拍推进的进度")
	ctx.equal(runner.id, &"runner", "Runner 的 id")
	ctx.equal(runner.display_name, "Runner", "Runner 的显示名")
	ctx.equal(runner.max_hp, RUNNER_HP, "Runner 的血量")
	ctx.equal(runner.advance_per_tick, RUNNER_ADVANCE, "Runner 每拍推进的进度")
	ctx.check(runner.max_hp < slime.max_hp, "Runner 比 Slime 血少")
	ctx.check(runner.advance_per_tick > slime.advance_per_tick, "Runner 比 Slime 快")
	ctx.equal(slime.travel_ticks(), 125, "Slime 走完全程的拍数")
	ctx.equal(runner.travel_ticks(), 50, "Runner 走完全程的拍数")
	# 速度为 0 时不得除零 —— 那不是本卡的配置，但降级路径要么正确要么不存在。
	var still := EnemyData.new()
	still.advance_per_tick = 0.0
	ctx.equal(still.travel_ticks(), 0, "速度为 0 时走完全程的拍数为 0（不得除零）")


## 三把武器：单体高频 / 范围 / 近身。差异只在 reach + damage 上。
func _run_weapon_data_checks(ctx: RefCounted) -> void:
	ctx.begin_case("WeaponData · 三把武器的数值与打击范围")
	var needle := WeaponData.for_kind(WeaponData.Kind.NEEDLE)
	var bomb := WeaponData.for_kind(WeaponData.Kind.BOMB)
	var saw := WeaponData.for_kind(WeaponData.Kind.SAW)
	ctx.equal(needle.damage, NEEDLE_DAMAGE, "针的伤害")
	ctx.equal(needle.reach, WeaponData.Reach.SINGLE, "针是单体")
	ctx.equal(bomb.damage, BOMB_DAMAGE, "炸弹的伤害")
	ctx.equal(bomb.reach, WeaponData.Reach.ALL, "炸弹是范围")
	ctx.equal(saw.damage, SAW_DAMAGE, "锯的伤害")
	ctx.equal(saw.reach, WeaponData.Reach.MELEE, "锯是近身")
	ctx.check(saw.damage < needle.damage and needle.damage < bomb.damage,
		"三者的伤害关系：锯（持续）< 针（单体高频）< 炸弹（范围）")

	ctx.begin_case("WeaponData · 节点上的武器种类 → 武器数值")
	# 三把武器的种类，本文件独立复写一遍（不转抄 WAREHOUSE 表）。
	var node_kinds: Array[int] = [
		NodeData.WeaponKind.NEEDLE, NodeData.WeaponKind.BOMB, NodeData.WeaponKind.SAW,
	]
	var kinds: Array[int] = [WeaponData.Kind.NEEDLE, WeaponData.Kind.BOMB, WeaponData.Kind.SAW]
	for index: int in node_kinds.size():
		var resolved: WeaponData = WeaponData.resolve(
			_node(&"w", "任意名字", NodeData.Kind.WEAPON, 0, node_kinds[index]))
		if ctx.check(resolved != null, "武器种类 %d 应能解析成武器" % node_kinds[index]):
			ctx.equal(resolved.kind, kinds[index], "武器种类 %d 解析出的武器种类" % node_kinds[index])
	# 显示名**不再参与解析**：改名字（或 I18N 之后换成译文）不得影响打出去的是什么。
	# 这正是删掉按显示名反查那条桥的理由，故这里正面钉一条。
	var renamed: WeaponData = WeaponData.resolve(
		_node(&"w", "Saw（英文名）", NodeData.Kind.WEAPON, 0, NodeData.WeaponKind.SAW))
	if ctx.check(renamed != null, "换了显示名的武器节点仍应能解析"):
		ctx.equal(renamed.kind, WeaponData.Kind.SAW, "解析只看 weapon_kind，不看显示名")
	# 不是武器节点的一律返回 null —— 否则 CORE / FUNCTION 也会被当成武器去打人。
	ctx.equal(WeaponData.resolve(_node(&"c", "核心", NodeData.Kind.CORE, 0)), null,
		"CORE 节点不得被解析成武器")
	ctx.equal(WeaponData.resolve(_node(&"f", "分流", NodeData.Kind.FUNCTION, 1)), null,
		"FUNCTION 节点不得被解析成武器")
	ctx.equal(WeaponData.resolve(null), null, "空节点不得被解析成武器")

	# 旧存档（没有 weapon_kind 这一字段）载回后是 NONE，这里正面验一次降级：
	# 落到 Needle 而不是 null —— 降成 null 会让玩家的武器「开火但不掉血」，最难查的那一类。
	# 这一条会触发一条 push_error，属 09 §5 明文豁免的「被断言的负路径用例」。
	ctx.begin_case("WeaponData · 缺字段（旧存档）→ 02 §9 降级到 Needle")
	var legacy: WeaponData = WeaponData.resolve(
		_node(&"w_old", "锯", NodeData.Kind.WEAPON, 0, NodeData.WeaponKind.NONE))
	if ctx.check(legacy != null, "缺 weapon_kind 的旧节点不得解析成 null（武器会变成开火不掉血）"):
		ctx.equal(legacy.kind, WeaponData.Kind.NEEDLE, "缺字段时降级到 Needle")

	# NodeData.WeaponKind 与 WeaponData.Kind 是两份**各自写下**的枚举（不能互相引用：
	# WeaponData 依赖 NodeData，反过来引用就成了循环依赖），故这条对应关系必须由测试顶住 ——
	# 哪一边插了一个成员而另一边没跟上，这里当场转红，而不是等到玩家发现锯打出了针的伤害。
	ctx.begin_case("NodeData.WeaponKind 与 WeaponData.Kind 的对应关系")
	ctx.equal(int(NodeData.WeaponKind.NEEDLE), int(WeaponData.Kind.NEEDLE) + 1,
		"NEEDLE 在两份枚举里的相对位置")
	ctx.equal(int(NodeData.WeaponKind.BOMB), int(WeaponData.Kind.BOMB) + 1,
		"BOMB 在两份枚举里的相对位置")
	ctx.equal(int(NodeData.WeaponKind.SAW), int(WeaponData.Kind.SAW) + 1,
		"SAW 在两份枚举里的相对位置")
	ctx.equal(NodeData.WeaponKind.size(), WeaponData.Kind.size() + 1,
		"WeaponKind 应恰好比 Kind 多一个 NONE")


## 一只敌人自己的规则：挨打、死亡、退场。
func _run_enemy_state_checks(ctx: RefCounted) -> void:
	ctx.begin_case("EnemyState · 掉血 / 击杀 / 死亡拍号")
	var slime := EnemyState.new(EnemyData.for_kind(EnemyData.Kind.SLIME), 0)
	ctx.equal(slime.hp, SLIME_HP, "出场满血")
	ctx.equal(slime.hp_ratio(), 1.0, "出场血量比例")
	ctx.equal(slime.progress, 0.0, "出场进度为 0（在战场右缘）")
	ctx.equal(slime.death_age(3), -1, "还没死时死亡年龄为 -1")
	ctx.check(not slime.take_damage(10.0, 5), "没打空时不得报「这一下打死了」")
	ctx.equal(slime.hp, SLIME_HP - 10.0, "掉血后的血量")
	ctx.check(slime.is_alive(), "掉血但没空，仍是活的")
	ctx.equal(slime.hp_ratio(), 0.75, "掉血后的血量比例")
	ctx.check(slime.take_damage(SLIME_HP, 9), "打空时该报「这一下打死了」")
	ctx.equal(slime.hp, 0.0, "血量夹到 0，不得为负")
	ctx.equal(slime.died_at_tick, 9, "死亡拍号")
	ctx.equal(slime.hp_ratio(), 0.0, "死亡后的血量比例")
	ctx.check(not slime.is_alive(), "死亡后不再是活的")
	ctx.check(not slime.take_damage(10.0, 10), "死后再挨打不得重复计一次击杀")
	ctx.equal(slime.hp, 0.0, "死后再挨打血量仍为 0")

	ctx.begin_case("EnemyState · 尸体推进与退场时序")
	var before: float = slime.progress
	slime.advance()
	ctx.equal(slime.progress, before, "死掉的敌人不再推进（尸体不会继续走向 CORE）")
	ctx.equal(slime.death_age(9), 0, "死亡当拍的死亡年龄")
	ctx.equal(slime.death_age(12), 3, "死亡 3 拍后的死亡年龄")
	ctx.check(not slime.is_gone(9 + VANISH_TICKS - 1, VANISH_TICKS),
		"第 %d 拍尸体还在（占位消失动画没播完）" % (9 + VANISH_TICKS - 1))
	ctx.check(slime.is_gone(9 + VANISH_TICKS, VANISH_TICKS),
		"第 %d 拍尸体应退场" % (9 + VANISH_TICKS))

	ctx.begin_case("EnemyState · 漏怪与进度封顶")
	var runner := EnemyState.new(EnemyData.for_kind(EnemyData.Kind.RUNNER), 1)
	ctx.equal(runner.lane, 1, "泳道序号原样带上")
	ctx.check(not runner.is_gone(0, VANISH_TICKS), "没漏没死的敌人不退场")
	runner.escaped = true
	ctx.check(not runner.is_alive(), "漏掉的敌人不再是活的")
	ctx.check(runner.is_gone(0, VANISH_TICKS), "漏掉的敌人当拍就退场（它是走掉的，不是死掉的）")
	var walker := EnemyState.new(EnemyData.for_kind(EnemyData.Kind.RUNNER), 0)
	for _step: int in 200:
		walker.advance()
	ctx.equal(walker.progress, 1.0, "推进进度封顶在 1.0，不得越过终点")
	ctx.check(walker.reached_end(), "进度到 1.0 即抵达终点")


## 生成节奏与推进：出场的拍号、种类、泳道，以及「刚出场那一拍不动」。
func _run_spawn_checks(ctx: RefCounted) -> void:
	ctx.begin_case("CombatSimulation · 开战前的初始态")
	var sim := CombatSimulation.new(_blueprint([["core", "核心", NodeData.Kind.CORE, 0]], []))
	ctx.check(sim.machine() != null, "仿真应持有机器")
	ctx.check(bool(sim.machine().has_core()), "这张图有 CORE")
	ctx.equal(sim.tick_index(), 0, "刚建出来停在 0 拍")
	ctx.equal(sim.core_hp(), CORE_MAX, "开战 CORE 满血")
	ctx.equal(sim.enemies().size(), 0, "开战场上没有敌人")
	ctx.check(not sim.is_cleared() and not sim.is_failed(), "开战既没清空也没失败")

	ctx.begin_case("CombatSimulation · 敌人按固定间隔出场")
	_step(sim, SPAWN_FIRST - 1)
	ctx.equal(sim.enemies().size(), 0, "第 %d 拍之前场上不该有敌人" % (SPAWN_FIRST - 1))
	_step(sim, 1)
	ctx.equal(sim.enemies().size(), 1, "第 %d 拍应出场第 1 只" % SPAWN_FIRST)
	var first: EnemyState = sim.enemies()[0]
	ctx.equal(first.data.kind, WAVE_ORDER[0], "第 1 只的种类")
	ctx.equal(first.lane, 0, "第 1 只的泳道")
	ctx.equal(first.progress, 0.0, "刚出场的那一拍不推进（推进在生成之前）")
	_step(sim, 1)
	ctx.equal(first.progress, SLIME_ADVANCE, "第 1 只推进了一拍")
	_step(sim, SPAWN_EVERY - 1)
	ctx.equal(sim.enemies().size(), 2, "再过 %d 拍应出场第 2 只" % SPAWN_EVERY)
	ctx.equal(sim.enemies()[1].data.kind, WAVE_ORDER[1], "第 2 只的种类")
	ctx.equal(sim.enemies()[1].lane, 1, "第 2 只的泳道（与第 1 只错开）")
	ctx.check(first.progress > SLIME_ADVANCE, "第 1 只一直在往前走")
	# 无武器的机器：敌人只会一路走到终点，CORE 在它们抵达时掉血。
	ctx.begin_case("CombatSimulation · 没有武器时敌人一路推进到终点")
	_step(sim, 1)
	ctx.check(first.progress > 0.0, "活着的敌人每拍都在推进")
	ctx.equal(sim.core_hp(), CORE_MAX, "还没有敌人抵达终点，CORE 不掉血")


## 针：单体、高频，打的是离 CORE 最近的那一只。
func _run_needle_checks(ctx: RefCounted) -> void:
	ctx.begin_case("CombatSimulation · 针（单体高频）")
	var sim := CombatSimulation.new(_blueprint(
		[
			["core", "核心", NodeData.Kind.CORE, 0],
			["w", "针", NodeData.Kind.WEAPON, 0, NodeData.WeaponKind.NEEDLE],
		],
		[["core", "w"]]))
	_step(sim, FIRE_DIRECT - 1)
	ctx.equal(sim.enemies().size(), 1, "首发前一拍场上应恰好 1 只")
	ctx.equal(sim.enemies()[0].hp, SLIME_HP, "开火前满血")
	_step(sim, 1)
	ctx.equal(sim.enemies()[0].hp, SLIME_HP - NEEDLE_DAMAGE, "第 %d 拍首发命中" % FIRE_DIRECT)

	# 再挨两发：第 24、第 34 拍各一发。第 30 拍出场第 2 只，于是在第 34 拍时场上有两只 ——
	# 这正是「单体只打一只」需要的场面。
	_step(sim, 34 - FIRE_DIRECT)
	ctx.equal(sim.enemies().size(), 2, "第 34 拍场上应有 2 只（第 30 拍出场的 Runner 还没走完）")
	var front: EnemyState = sim.enemies()[0]
	var back: EnemyState = sim.enemies()[1]
	ctx.equal(front.hp, SLIME_HP - 3 * NEEDLE_DAMAGE, "第 34 拍时前排挨了 3 发")
	ctx.equal(back.hp, RUNNER_HP, "单体武器只打最靠前的一只，后排一发都没挨")
	ctx.check(front.progress > back.progress, "挨打的那只确实是离 CORE 最近的一只")
	_step(sim, 10)
	ctx.equal(front.died_at_tick, 44, "Slime（%d 血）挨 4 发针（每发 %d）应在第 44 拍死亡"
		% [int(SLIME_HP), int(NEEDLE_DAMAGE)])
	ctx.check(not front.is_alive(), "血量归零即死亡")


## 炸弹：范围。一次开火同时打中场上**全部**活着的敌人。
## 挂一个 Delay 是为了让首发落在第 30 拍 —— 那时场上正好有两只（第 10 拍与第 30 拍出场的各一只）。
func _run_bomb_checks(ctx: RefCounted) -> void:
	ctx.begin_case("CombatSimulation · 炸弹（范围）")
	var sim := CombatSimulation.new(_blueprint(
		[
			["core", "核心", NodeData.Kind.CORE, 0],
			["d", "延迟", NodeData.Kind.FUNCTION, NodeData.Function.DELAY],
			["w", "炸弹", NodeData.Kind.WEAPON, 0, NodeData.WeaponKind.BOMB],
		],
		[["core", "d"], ["d", "w"]]))
	_step(sim, FIRE_DELAY - 1)
	ctx.equal(sim.enemies().size(), 1, "首发前一拍场上应恰好 1 只")
	ctx.equal(sim.enemies()[0].hp, SLIME_HP, "开火前满血")
	_step(sim, 1)
	ctx.equal(sim.enemies()[0].hp, SLIME_HP - BOMB_DAMAGE, "第 %d 拍首发命中" % FIRE_DELAY)

	# 第 30 拍出场第 2 只；第 40 拍炸弹再开一次火，此时场上两只都在。
	_step(sim, 40 - FIRE_DELAY - 1)
	ctx.equal(sim.enemies().size(), 2, "第 39 拍场上应有 2 只")
	var front: EnemyState = sim.enemies()[0]
	var back: EnemyState = sim.enemies()[1]
	ctx.equal(front.hp, SLIME_HP - BOMB_DAMAGE, "前排只挨过第 %d 拍那一发" % FIRE_DELAY)
	ctx.equal(back.hp, RUNNER_HP, "后排还是满血")
	_step(sim, 1)
	ctx.equal(front.died_at_tick, 40, "范围武器一次开火应同时打中前排")
	ctx.equal(back.died_at_tick, 40, "范围武器一次开火应同时打中后排")
	ctx.equal(sim.core_hp(), CORE_MAX, "两只都是被打死的，CORE 不该掉血")


## 锯：近身。只有走进 [MELEE_FROM, 1.0] 的敌人才在范围内 ——
## 「还在远处的不掉血」是这条打击范围的定义，不是优化。
func _run_saw_checks(ctx: RefCounted) -> void:
	ctx.begin_case("CombatSimulation · 锯（近身持续）")
	var sim := CombatSimulation.new(_blueprint(
		[
			["core", "核心", NodeData.Kind.CORE, 0],
			["w", "锯", NodeData.Kind.WEAPON, 0, NodeData.WeaponKind.SAW],
		],
		[["core", "w"]]))
	# 第 94 拍：锯已经开了 9 次火（14…94），但**一只都没进窗** ——
	# 场上三只的进度是 0.672 / 0.352 / 0.480（第 2 只已在第 80 拍抵达终点退场）。
	_step(sim, 94)
	ctx.equal(sim.enemies().size(), 3, "第 94 拍场上应有 3 只（第 2 只已在第 80 拍抵达终点）")
	var slime: EnemyState = sim.enemies()[0]
	ctx.check(slime.progress < MELEE_FROM, "第 94 拍时最靠前那只还没进入近身窗口（进度 %.3f）" % slime.progress)
	ctx.equal(sim.enemies()[0].hp, SLIME_HP, "最靠前那只挨了 9 次开火仍是满血")
	ctx.equal(sim.enemies()[1].hp, SLIME_HP, "中间那只挨了 9 次开火仍是满血")
	ctx.equal(sim.enemies()[2].hp, RUNNER_HP, "最后那只挨了 9 次开火仍是满血")
	ctx.equal(sim.core_hp(), CORE_MAX - LEAK_DAMAGE, "第 2 只已在第 80 拍抵达终点，CORE 恰好掉一份血")
	_step(sim, 10)
	ctx.check(slime.progress >= MELEE_FROM, "第 104 拍时它已进入近身窗口（进度 %.3f）" % slime.progress)
	ctx.equal(slime.hp, SLIME_HP - SAW_DAMAGE, "进窗后一开火就掉血")
	ctx.equal(sim.enemies()[1].hp, SLIME_HP, "同一发开火里，还在窗口外的那只一点血都没掉")


## 一波敌人全灭 → 本波清空。用「CORE → 分流 → 两把针」把伤害翻倍，
## 好让四只在漏掉之前全部被打死（单把针的输出不足以在本卡的推进速度下清空 —— 那是平衡问题，不是缺陷）。
func _run_clear_checks(ctx: RefCounted) -> void:
	ctx.begin_case("CombatSimulation · 一波全灭 → 本波清空（03 §1.1 R2）")
	var sim := CombatSimulation.new(_blueprint(
		[
			["core", "核心", NodeData.Kind.CORE, 0],
			["s", "分流", NodeData.Kind.FUNCTION, NodeData.Function.SPLIT],
			["wa", "针", NodeData.Kind.WEAPON, 0, NodeData.WeaponKind.NEEDLE],
			["wb", "针", NodeData.Kind.WEAPON, 0, NodeData.WeaponKind.NEEDLE],
		],
		[["core", "s"], ["s", "wa"], ["s", "wb"]]))
	_cleared_count = 0
	sim.wave_cleared.connect(_on_wave_cleared)
	# 第 58 拍：第 3 只（Slime）出场后挨的第一发 —— 分流的两把针同拍各来一发。
	_step(sim, 58)
	ctx.equal(sim.enemies().size(), 1, "第 58 拍场上应只剩第 3 只")
	ctx.equal(sim.enemies()[0].hp, SLIME_HP - 2 * NEEDLE_DAMAGE,
		"分流的两把针同拍各打一发（共 %d）" % int(2 * NEEDLE_DAMAGE))
	ctx.check(not sim.is_cleared(), "还没打完就不算清空")
	ctx.equal(_cleared_count, 0, "还没打完不该报清空")
	_step(sim, 24)
	ctx.check(sim.is_cleared(), "四只全部击杀后本波应清空")
	ctx.equal(sim.tick_index(), 82, "清空的拍号（最后一只死后 %d 拍、尸体退场的那一拍）" % VANISH_TICKS)
	ctx.equal(_cleared_count, 1, "本波清空只报一次")
	ctx.equal(sim.core_hp(), CORE_MAX, "四只全被打死，CORE 一滴血都没掉")
	ctx.equal(sim.enemies().size(), 0, "清空时场上连尸体都不该剩")
	ctx.check(not sim.is_failed(), "清空的那一局不得同时算失败")
	_step(sim, 40)
	ctx.equal(sim.tick_index(), 82, "终局之后 tick() 不再推进")
	ctx.equal(_cleared_count, 1, "终局之后再 tick 也不得重复报清空")


## 全部漏光 → CORE 归零 → 本局失败。四只各扣 25，恰好打空 100 ——
## 「最简单的失败条件」在本卡的数值下成立，且算得出来。
func _run_failure_checks(ctx: RefCounted) -> void:
	ctx.begin_case("CombatSimulation · 敌人到终点 → 本局失败（03 §1.1 R2）")
	var sim := CombatSimulation.new(_blueprint([["core", "核心", NodeData.Kind.CORE, 0]], []))
	_failed_count = 0
	sim.run_failed.connect(_on_run_failed)
	_step(sim, 79)
	ctx.equal(sim.core_hp(), CORE_MAX, "第 79 拍还没有敌人抵达终点")
	ctx.check(not sim.is_failed(), "还没漏就不算失败")
	_step(sim, 1)
	ctx.equal(sim.core_hp(), CORE_MAX - LEAK_DAMAGE, "Runner 在第 80 拍抵达终点，CORE 掉一份血")
	_step(sim, 175 - 80)
	ctx.check(sim.is_failed(), "四只全部抵达终点后本局应失败")
	ctx.equal(sim.core_hp(), 0.0, "四只各扣 %d，CORE 恰好打空" % int(LEAK_DAMAGE))
	ctx.equal(_failed_count, 1, "本局失败只报一次")
	ctx.check(not sim.is_cleared(), "失败的那一局不得同时算清空")
	_step(sim, 40)
	ctx.equal(sim.tick_index(), 175, "终局之后 tick() 不再推进")
	ctx.equal(_failed_count, 1, "终局之后再 tick 也不得重复报失败")


## MachineDriver 的两种驱动对象互斥。每帧跑两拍的症状只是「敌人走得比设计快一倍」，
## 只能靠这条契约挡住。
func _run_driver_checks(ctx: RefCounted) -> void:
	ctx.begin_case("MachineDriver · 两种驱动对象互斥")
	var blueprint := _blueprint([["core", "核心", NodeData.Kind.CORE, 0]], [])
	var driver := MachineDriver.new()
	ctx.equal(driver.runtime, null, "新节拍器默认不持有机器")
	ctx.equal(driver.combat, null, "新节拍器默认不持有战斗")
	var runtime := MachineRuntime.new(blueprint)
	driver.bind(runtime)
	ctx.equal(driver.runtime, runtime, "bind() 应记住机器")
	ctx.equal(driver.combat, null, "bind() 不得留下上一场战斗")
	var sim := CombatSimulation.new(blueprint)
	driver.bind_combat(sim)
	ctx.equal(driver.combat, sim, "bind_combat() 应记住战斗")
	ctx.equal(driver.runtime, null, "bind_combat() 必须清掉机器 —— 否则每帧会推进两拍")
	driver.bind(runtime)
	ctx.equal(driver.runtime, runtime, "反向：bind() 应重新记住机器")
	ctx.equal(driver.combat, null, "反向：bind() 必须清掉战斗")
	driver.bind(null)
	ctx.equal(driver.runtime, null, "bind(null) 应停下车器")
	ctx.equal(driver.combat, null, "bind(null) 之后两种驱动对象都为空")
	driver.free()


## 推进 N 拍。手工调 tick()，不跑帧、不等真实时间（03 §6）。
func _step(sim: CombatSimulation, ticks: int) -> void:
	for _index: int in ticks:
		sim.tick()


func _on_wave_cleared() -> void:
	_cleared_count += 1


func _on_run_failed() -> void:
	_failed_count += 1


## 造一个蓝图节点。spec = [id, display_name, kind, function_kind, weapon_kind?]。
## weapon_kind 只对 WEAPON 节点有意义，缺省 NONE（02 §9 的降级入口，由 WeaponData.resolve 兜）。
func _node(id: StringName, display_name: String, kind: int, function_kind: int,
		weapon_kind: int = NodeData.WeaponKind.NONE) -> NodeData:
	var node := NodeData.new()
	node.id = id
	node.display_name = display_name
	node.kind = kind
	node.function_kind = function_kind
	node.weapon_kind = weapon_kind
	return node


## 造一份蓝图。nodes 与 edges 的每项都是数组，格式见 _node() 与下面这行。
func _blueprint(nodes: Array, edges: Array) -> BlueprintData:
	var blueprint := BlueprintData.new()
	for item: Array in nodes:
		var weapon_kind: int = int(item[4]) if item.size() > 4 else NodeData.WeaponKind.NONE
		blueprint.nodes.append(_node(item[0], item[1], int(item[2]), int(item[3]), weapon_kind))
	for edge: Array in edges:
		var link := ConnectionData.new()
		link.from_node_id = StringName(edge[0])
		link.from_port = &"out"
		link.to_node_id = StringName(edge[1])
		link.to_port = &"in"
		blueprint.connections.append(link)
	return blueprint
