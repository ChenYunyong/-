## test_reward.gd
## 职责：战后奖励与本局账本的验收 —— 选项真的可复现、真的有限、**真的改变下一波**，
##       以及「本局结束」这件事在数据侧记得住。
## 所属系统：tests
## 依赖：RewardModel, RunState（经 /root 取）, BoardModel, CombatSim, CardCatalog, MapModel
## 禁止：本文件不得留下副作用 —— 结束时按快照还原书页、把这一局收掉、把地图重掷成没走过的那张
##       （后面的 map_view_smoke 会按 `selectable()[0]` 往下走，一张走到死的图会让它越界）。
##
## 「拿了卡」这一项断的不是「书页上多了一张卡」，而是**同一波从打不过变成打得过**：
## 奖励只要不接进施法队列，就是一块摆设。加成那两条同理，量的是**打穿同一波要多少 tick**
## —— 数值调了而 tick 数不变，说明那个加成根本没进仿真。

extends RefCounted

const FIXED_SEED: int = 20261008
## 一局的种子取两个不同的值，用来验「同种子同地图 / 换种子换地图」。
const SEED_A: int = 4242
const SEED_B: int = 777001
## 快进到波次自然收场所需的上限（一波最长 30 秒）。
const MAX_TICKS: int = CombatSim.TICK_HZ * 31
## 画布尺寸只影响奖励卡的落点，取编辑器的真实值。
const VIEW_SIZE: Vector2 = Vector2(816.0, 360.0)

var _run: Node = null
var _board: BoardModel = null
## 进来时书页长什么样。结束时按它还原 —— 本用例往书页上加过卡与丝线。
var _before_board: Dictionary = {}


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_reward")
	_run = tree.root.get_node_or_null(^"RunState")
	if not ctx.check(_run != null, "RunState 单例存在"):
		return
	_board = _run.board()
	_before_board = _board.snapshot()
	_run.start_run(FIXED_SEED)
	_check_pool(ctx)
	_check_roll_is_reproducible(ctx)
	_check_roll_shrinks_and_empties(ctx)
	_check_card_reward_changes_next_wave(ctx)
	_check_bonus_rewards_change_next_wave(ctx)
	_check_ledger(ctx)
	_check_run_lifecycle(ctx)
	_teardown()


# ------------------------------------------------------------------ 卡池与抽取

## 池子 = 全部非核心卡。核心是书页的起点，不该从奖励里抽出来。
func _check_pool(ctx: RefCounted) -> void:
	var ids: PackedStringArray = RewardModel.pool_ids()
	ctx.equal(ids.size(), CardCatalog.all().size() - CardCatalog.by_kind(CardData.Kind.CORE).size(),
		"池子是「总表减去核心卡」")
	var cores: PackedStringArray = PackedStringArray()
	for card: CardData in CardCatalog.by_kind(CardData.Kind.CORE):
		if ids.has(String(card.id)):
			cores.append(String(card.id))
	ctx.equal(cores.size(), 0, "池子里一张核心卡都没有" if cores.is_empty() else "混进了：%s" % cores)
	for id: String in ids:
		ctx.check(CardCatalog.find(StringName(id)) != null, "池子里的 %s 在卡表里查得到" % id)


## 同一局的同一波，抽出来的必须是同一组 —— 否则「看一眼再进来」就能刷新选项。
func _check_roll_is_reproducible(ctx: RefCounted) -> void:
	var pool: PackedStringArray = RewardModel.pool_ids()
	var first: Array[Dictionary] = RewardModel.roll(FIXED_SEED, 1, pool, [])
	var again: Array[Dictionary] = RewardModel.roll(FIXED_SEED, 1, pool, [])
	ctx.equal(first.size(), RewardModel.OPTION_COUNT, "一次给 %d 个选项" % RewardModel.OPTION_COUNT)
	ctx.equal(_fingerprint(first), _fingerprint(again), "同一 (种子, 波次) 抽两次是同一组")

	var keys: PackedStringArray = PackedStringArray()
	for option: Dictionary in first:
		keys.append(RewardModel.key_of(option))
	ctx.equal(_distinct(keys).size(), first.size(), "选项之间互不重复")

	# 波次真的参与了派生：连着几波不该抽出同一组。
	var seen: Dictionary = {}
	for wave: int in range(1, 7):
		seen[_fingerprint(RewardModel.roll(FIXED_SEED, wave, pool, []))] = true
	ctx.check(seen.size() > 1, "1~6 波抽出来不是同一组（换波真的换牌）")

	# 已经拿过的不再出现。
	var taken: Array = [RewardModel.key_of(first[0])]
	for option: Dictionary in RewardModel.roll(FIXED_SEED, 1, pool, taken):
		ctx.check(RewardModel.key_of(option) != String(taken[0]),
			"拿过的「%s」不会再次出现" % taken[0])


## 池子是有限的：拿光了返回空数组（界面据此给兜底），不是「凑一个默认项」。
func _check_roll_shrinks_and_empties(ctx: RefCounted) -> void:
	var pool: PackedStringArray = RewardModel.pool_ids()
	var all_taken: Array = [RewardModel.KEY_POWER, RewardModel.KEY_MANA]
	for id: String in pool:
		all_taken.append(id)
	ctx.equal(RewardModel.roll(FIXED_SEED, 1, pool, all_taken).size(), 0,
		"全部拿过之后没有可选项（池子空 → 空数组）")

	# 反向对照：只剩一个可拿时只给一个，而不是硬凑满三个。
	var one_left: Array = all_taken.duplicate()
	one_left.erase(RewardModel.KEY_POWER)
	var left: Array[Dictionary] = RewardModel.roll(FIXED_SEED, 1, pool, one_left)
	ctx.equal(left.size(), 1, "只剩一个可拿时只给一个")
	ctx.equal(RewardModel.key_of(left[0]), RewardModel.KEY_POWER, "剩下的那个就是它")


# ------------------------------------------------------------------ §1：选择真的改变下一波

## 拿卡：书页上多一张卡**并且被连到核心上**，于是同一波从打不过变成打得过。
func _check_card_reward_changes_next_wave(ctx: RefCounted) -> void:
	_rig_core_only()
	var before: PackedStringArray = _settle_run(1, 0, 0)
	ctx.check(_outcome_of(before) == CombatSim.Outcome.DESTROYED,
		"只有核心、没有法术时这一波打不过（超时）")

	ctx.check(_run.take_reward({"kind": RewardModel.Kind.CARD, "card_id": &"ab_wind"}, VIEW_SIZE),
		"拿一张法术卡被受理")
	var placed: BoardModel.PlacedCard = _placed_of(&"ab_wind")
	if not ctx.check(placed != null, "卡真的落到了书页上"):
		return
	var probe: CombatSim = CombatSim.new()
	probe.begin(_board, 1)
	ctx.equal(probe.cast_order().size(), 1,
		"这张卡进了施法队列（只放不连的话它一次都不会被施放）")
	ctx.check(_linked_from_core(placed.uid), "丝线是从核心拉过来的")

	var after: PackedStringArray = _settle_run(1, 0, 0)
	ctx.check(_outcome_of(after) == CombatSim.Outcome.CLEARED, "拿了这张卡之后同一波打得过了")
	ctx.check(after != before, "同一波的结算流水逐行不同（选择真的改变了下一波）")


## 强化 / 供能：量「打穿同一波要多少 tick」。数值调了而 tick 数不变 = 加成没进仿真。
func _check_bonus_rewards_change_next_wave(ctx: RefCounted) -> void:
	_rig_core_only()
	ctx.check(_run.take_reward({"kind": RewardModel.Kind.CARD, "card_id": &"ab_fire"}, VIEW_SIZE),
		"换成一张贵而重的火球卡")

	var plain: int = _ticks_of(_settle_run(3, 0, 0))
	var powered: int = _ticks_of(_settle_run(3, RewardModel.POWER_DAMAGE, 0))
	ctx.check(powered < plain, "本局强化 +%d 伤害后打穿第 3 波更快（%d → %d tick）"
		% [RewardModel.POWER_DAMAGE, plain, powered])

	ctx.check(_run.take_reward({"kind": RewardModel.Kind.POWER}, VIEW_SIZE), "拿走「本局强化」")
	ctx.equal(_run.damage_bonus(), RewardModel.POWER_DAMAGE, "伤害加成记在本局账上")
	ctx.check(_run.take_reward({"kind": RewardModel.Kind.MANA}, VIEW_SIZE), "拿走「本局供能」")
	ctx.equal(_run.mana_bonus(), RewardModel.MANA_PER_TICK, "魔力加成记在本局账上")

	var fed: int = _ticks_of(_settle_run(3, _run.damage_bonus(), _run.mana_bonus()))
	ctx.check(fed < powered, "再加上供能之后更快（%d → %d tick）" % [powered, fed])
	# 反向对照：供能作用在「核心每次产出」上，结算表头如实记着本场上了多少。
	ctx.check(_settle_run(3, 0, RewardModel.MANA_PER_TICK)[0].contains("mana_bonus=1"),
		"结算表头如实记着本场的魔力加成")


# ------------------------------------------------------------------ 账本与结局

## 上面拿过：两张卡 + 强化 + 供能，共四笔。
func _check_ledger(ctx: RefCounted) -> void:
	var taken: Array[Dictionary] = _run.taken_rewards()
	ctx.equal(taken.size(), 4, "这一局记下了 4 笔（两张卡 + 强化 + 供能）")
	var kinds: Array = []
	for option: Dictionary in taken:
		kinds.append(int(option["kind"]))
	ctx.check(kinds.has(RewardModel.Kind.POWER) and kinds.has(RewardModel.Kind.MANA)
		and kinds.count(RewardModel.Kind.CARD) == 2, "四笔的类别都留下来了")
	for option: Dictionary in taken:
		ctx.check(not RewardModel.name_text(option).is_empty(), "账本里的每一条都念得出名字")
	# 重复拿同一个要被拒绝 —— 选项池与账本共用同一张键表。
	ctx.check(not _run.take_reward(taken[0], VIEW_SIZE), "同一个奖励拿第二次被拒绝")
	# 账本是副本：外部清空它不该动摇本局的记录。
	taken.clear()
	ctx.equal(_run.taken_rewards().size(), 4, "账本返回的是副本，外部改不动它")


## 一局的生老病死：新种子 ⇒ 新地图、同种子 ⇒ 同地图、结束记下结局、重开清空账本。
func _check_run_lifecycle(ctx: RefCounted) -> void:
	_run.start_run(SEED_A)
	ctx.equal(_run.get_run_seed(), SEED_A, "本局种子按传入的值记下（03 §6）")
	ctx.equal(_run.current_wave(), 1, "新的一局从第 1 波开始")
	ctx.equal(_run.tiers_seen(), 0, "还没出发 = 到过 0 层")
	var map_a: String = _map_fingerprint(_run.map())

	_run.start_run(SEED_A)
	ctx.equal(_map_fingerprint(_run.map()), map_a, "同一个种子重开 = 同一张图（逐行可复现）")

	_run.start_run(SEED_B)
	ctx.check(_map_fingerprint(_run.map()) != map_a, "换一个种子就是另一张图")

	# 「到过几层」随路线推进 —— 结算屏念的就是这个数。
	var walked: int = 0
	while not _run.map().is_finished() and walked < MapModel.TIERS:
		_run.map().select(_run.map().selectable()[0].id)
		walked += 1
	ctx.equal(_run.tiers_seen(), MapModel.TIERS, "一路走到最后一层 = 到过 %d 层" % MapModel.TIERS)

	# 结局：两种都记得住，而且都真的结束了这一局。
	_run.finish_run(_run.Result.VICTORY)
	ctx.equal(_run.result(), _run.Result.VICTORY, "通关被记下")
	ctx.check(not _run.is_active(), "通关之后这一局不再进行中")
	_run.start_run(SEED_A)
	ctx.equal(_run.result(), _run.Result.NONE, "新的一局没有结局")
	ctx.equal(_run.taken_rewards().size(), 0, "新的一局账本清空")
	ctx.equal(_run.damage_bonus(), 0, "新的一局伤害加成归零")
	ctx.equal(_run.mana_bonus(), 0, "新的一局魔力加成归零")
	_run.finish_run(_run.Result.DEFEAT)
	ctx.equal(_run.result(), _run.Result.DEFEAT, "落败也被记下")

	# 「新一局是新种子」：连开两局，种子不是同一个。
	var first: int = _auto_seed()
	var second: int = _auto_seed()
	ctx.check(first != second, "连着开两局的种子不同（%d vs %d）" % [first, second])


# ------------------------------------------------------------------ 工具

## 只留一张核心卡、法术一张不连：这一波必然打不过 —— 这正是「拿卡之前」的对照。
func _rig_core_only() -> void:
	for placed: BoardModel.PlacedCard in _board.cards():
		_board.remove_card(placed.uid)
	_board.add_card(&"core_arcane", Vector2(48.0, 48.0))


## 按给定的加成把某一波跑完，返回结算流水。加成是**入参**而不是去问 RunState ——
## 这样「只差加成」的两场才真的是同一个对照。
func _settle_run(wave: int, damage_bonus: int, mana_bonus: int) -> PackedStringArray:
	var sim: CombatSim = CombatSim.new()
	sim.begin(_board, wave, damage_bonus, mana_bonus)
	sim.advance(MAX_TICKS)
	return sim.settlement_log()


## 结算流水的表头：`wave=%d ticks=%d hp=%d/%d mana=%d outcome=%d dmg_bonus=%d mana_bonus=%d`。
static func _field(log: PackedStringArray, name: String) -> int:
	for part: String in log[0].split(" "):
		if part.begins_with(name + "="):
			return int(part.split("=")[1])
	return -1


static func _ticks_of(log: PackedStringArray) -> int:
	return _field(log, "ticks")


static func _outcome_of(log: PackedStringArray) -> int:
	return _field(log, "outcome")


func _placed_of(card_id: StringName) -> BoardModel.PlacedCard:
	for placed: BoardModel.PlacedCard in _board.cards():
		if placed.card_id == card_id:
			return placed
	return null


func _linked_from_core(uid: int) -> bool:
	for link: BoardModel.Link in _board.links():
		if link.to_uid == uid:
			var source: BoardModel.PlacedCard = _board.find_card(link.from_uid)
			return source != null and source.card_id == &"core_arcane"
	return false


static func _distinct(values: PackedStringArray) -> PackedStringArray:
	var seen: Dictionary = {}
	for value: String in values:
		seen[value] = true
	return PackedStringArray(seen.keys())


## 一组选项的指纹：只看「类别 + 键」，不看字典本身（字典的相等语义不值得依赖）。
static func _fingerprint(options: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for option: Dictionary in options:
		parts.append("%d:%s" % [int(option.get("kind", -1)), RewardModel.key_of(option)])
	return "|".join(parts)


## 一张图的指纹：每个节点的位置 + 类型 + 出边。同一颗种子必须给出同一个串。
static func _map_fingerprint(model: MapModel) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for node: MapModel.MapNode in model.nodes():
		parts.append("%d/%d:%d:%s" % [node.tier, node.column, int(node.kind), str(node.next)])
	return "|".join(parts)


## 让 RunState 自己抽一个种子（SEED_AUTO），只取不跑。
func _auto_seed() -> int:
	_run.start_run()
	return _run.get_run_seed()


## 收尾：书页还原、地图重掷成没走过的那张、这一局收掉 —— 三步缺一不可（见文件头禁止项）。
func _teardown() -> void:
	_board.restore(_before_board)
	_run.start_run(FIXED_SEED)
	_run.end_run()
