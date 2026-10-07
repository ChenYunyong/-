## test_combat_cards.gd
## 职责：卡牌效果接线的验收 —— 八类功能卡各自生效、能力卡的段数、能量与费用边界、一波的胜负、可重放。
## 所属系统：tests
## 依赖：CombatSim, CombatMods, BoardModel, CardCatalog
## 禁止：本文件不得引用任何节点 —— 战斗规则必须能脱离场景单独验证。
##
## 「功能卡各自生效」按**两条**来量：读数变了一位（生效），且八张卡的读数两两不同
## （各自独立，没有哪两张抢同一个数字 —— 八张都改同一个数的话，坏一张要靠排除法才认得出）。

extends RefCounted

## 试验台默认摆几张核心卡。**三张**不是随手加的：一张核心每秒只出 2 点魔力，
## 而功能卡与能力卡各要 2 费，于是功能卡每一轮都排在「刚花完钱」的那一拍、永远打不出来 ——
## 测试会把它误报成「这张卡没效果」，而真相只是「它一次都没轮到」。
const CORES: int = 3


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_combat_cards")
	_check_channels(ctx)
	_check_enchant(ctx)
	_check_segments(ctx)
	_check_pacing(ctx)
	_check_mana_boundary(ctx)
	_check_loop(ctx)
	_check_outcome(ctx)
	_check_replay(ctx)


## 试验台：若干核心卡（电源，不进队列）+ 一串首尾相接的法术卡，第一个挂在第一张核心上。
func _rig(ids: Array[StringName], cores: int = CORES) -> BoardModel:
	var board: BoardModel = BoardModel.new()
	for index: int in cores:
		board.add_card(&"core_arcane", Vector2(30.0, 30.0 + float(index) * 120.0))
	var head: int = board.cards()[0].uid
	for index: int in ids.size():
		var placed: BoardModel.PlacedCard = board.add_card(ids[index],
			Vector2(240.0 + float(index) * 120.0, 30.0))
		board.connect_cards(head, placed.uid)
		head = placed.uid
	return board


## 跑一段，连同每一次落下的段（卡 id / 伤害 / 当时的 tick）一起交回来。
func _run(board: BoardModel, ticks: int, wave: int = 1) -> Dictionary:
	var sim: CombatSim = CombatSim.new()
	sim.begin(board, wave)
	var casts: Array = []
	sim.cast_performed.connect(func(card_id: StringName, damage: int, _mana: int) -> void:
		casts.append({"id": card_id, "damage": damage, "tick": sim.elapsed_ticks()}))
	sim.advance(ticks)
	return {"sim": sim, "casts": casts}


## 某张卡在这段里落下的各段伤害。
func _damages(casts: Array, card_id: StringName) -> Array:
	var found: Array = []
	for row: Dictionary in casts:
		if row["id"] == card_id:
			found.append(row["damage"])
	return found


## 某个 tick 上某张卡落了几段 —— 子弹数量 / 连发数量看的正是这个数。
func _segments_at(casts: Array, card_id: StringName, tick: int) -> int:
	var total: int = 0
	for row: Dictionary in casts:
		if row["id"] == card_id and row["tick"] == tick:
			total += 1
	return total


## 一个 CombatMods 算出来的八个派生数。八条通道各留一位，于是「哪一位动了」就是「哪张卡生效了」。
func _reading(mods: CombatMods) -> Array:
	var ability: CardData = CardCatalog.find(&"ab_metal")
	return [
		mods.damage_multiplier(),
		mods.salvo(ability),
		mods.mana_period_ticks(CombatSim.MANA_INTERVAL_TICKS),
		mods.cast_interval_ticks(CombatSim.CAST_INTERVAL_TICKS),
		mods.time_limit_ticks(CombatSim.WAVE_TIME_LIMIT_TICKS),
		mods.price(ability, 1),
		mods.looping,
		mods.burst_left,
	]


## 把八张功能卡逐张喂进去：每张只动自己那一位，且八张的读数两两不同。
func _check_channels(ctx: RefCounted) -> void:
	var cards: Array[CardData] = CardCatalog.by_kind(CardData.Kind.FUNCTION)
	ctx.equal(cards.size(), 8, "功能卡一共 8 类 —— 八条通道一张不缺")
	var baseline: Array = _reading(CombatMods.new())
	var readings: Dictionary = {}
	for card: CardData in cards:
		var mods: CombatMods = CombatMods.new()
		mods.apply(card)
		ctx.equal(mods.total_stacks(), 1, "「%s」只在自己的通道上加一档" % card.name_key)
		var reading: Array = _reading(mods)
		ctx.check(reading != baseline, "「%s」确实改变了这一波的读数" % card.name_key)
		readings[str(reading)] = true
	ctx.equal(readings.size(), 8, "八张卡的读数两两不同 —— 没有哪两张抢同一个数字")
	for card: CardData in [CardCatalog.find(&"core_arcane"), CardCatalog.find(&"ab_fire")]:
		var untouched: CombatMods = CombatMods.new()
		untouched.apply(card)
		ctx.equal(untouched.total_stacks(), 0, "「%s」不是功能卡，一档都不上" % card.name_key)
	var all: CombatMods = CombatMods.new()
	for card: CardData in cards:
		all.apply(card)
	ctx.equal(all.total_stacks(), 8, "八张全上档 = 八档")
	ctx.equal(_reading(all), [1.5, 3, 15, 9, 660, 1, true, 1], "八条通道各按各的算法叠加")


## 附魔：打在书页上是一回事，**打出来之后伤害真的变了**是另一回事。
## 6 伤的金弹，附魔一档（×1.5）之后必须是 9。
func _check_enchant(ctx: RefCounted) -> void:
	var run: Dictionary = _run(_rig([&"fn_enchant", &"ab_metal"]), 45)
	ctx.equal(_damages(run["casts"], &"ab_metal"), [6, 9], "附魔前后各一次金弹：6 → 9（×1.5）")
	ctx.equal(run["sim"].mods().enchant_stacks, 1, "附魔在本波攒了一档")


## 子弹数量（本拍多发）与连发数量（接下来几拍各多发一段）是两件事：
## 前者看**同一拍**落了几段，后者还看「用一次少一次」。
func _check_segments(ctx: RefCounted) -> void:
	var salvo: Dictionary = _run(_rig([&"fn_projectile", &"ab_wind"]), 45)
	ctx.equal(_segments_at(salvo["casts"], &"ab_wind", 40), 2, "子弹数量 +1：同一拍落下两段")
	ctx.equal(salvo["sim"].mods().projectile_stacks, 1, "子弹数量在本波攒了一档")
	var burst: Dictionary = _run(_rig([&"fn_burst", &"ab_wind"]), 45)
	ctx.equal(_segments_at(burst["casts"], &"ab_wind", 40), 2, "连发：那一拍也落下两段")
	ctx.equal(burst["sim"].mods().burst_left, 0, "连发余额用掉一次就少一次")


## 加速 / 攻速 / 减速量的是**仿真自己报出来的那个数**：打出这张卡之前是基数，之后是算过的值。
## 只比 CombatMods 的纯函数证明不了接线接对了。
func _check_pacing(ctx: RefCounted) -> void:
	var probes: Array[Dictionary] = [
		{"card": &"fn_haste", "what": "核心产出节拍", "before": 20, "after": 15,
			"read": func(sim: CombatSim) -> int: return sim.mana_period_ticks()},
		{"card": &"fn_attack_speed", "what": "施法节拍", "before": 10, "after": 9,
			"read": func(sim: CombatSim) -> int: return sim.cast_interval_ticks()},
		{"card": &"fn_slow", "what": "本波限时", "before": 600, "after": 660,
			"read": func(sim: CombatSim) -> int: return sim.time_limit_ticks()},
	]
	for probe: Dictionary in probes:
		var name_key: String = CardCatalog.find(probe["card"]).name_key
		var read: Callable = probe["read"]
		ctx.equal(read.call(_run(_rig([probe["card"]]), 19)["sim"]), probe["before"],
			"「%s」还没打出来时，%s是基数" % [name_key, probe["what"]])
		ctx.equal(read.call(_run(_rig([probe["card"]]), 21)["sim"]), probe["after"],
			"「%s」打出来之后，%s跟着变" % [name_key, probe["what"]])


## 能量与费用的边界：付不起的那一拍**什么都不做**（不施放、不扣钱、魔力不为负），
## 而费用有下限 —— 冷却叠过头收到 0 为止，不倒贴。
func _check_mana_boundary(ctx: RefCounted) -> void:
	var board: BoardModel = _rig([&"ab_fire"])
	var early: Dictionary = _run(board, 10)
	ctx.equal(early["sim"].mana(), 0, "开局没有魔力")
	ctx.equal(early["casts"].size(), 0, "付不起的那一拍一段都不打")
	var fired: Dictionary = _run(board, 20)
	ctx.equal(fired["sim"].mana(), 3, "一秒 6 点魔力 − 火球 3 费 = 余 3")
	ctx.equal(_damages(fired["casts"], &"ab_fire"), [9], "攒够费用就真的打出去了")

	var mods: CombatMods = CombatMods.new()
	var fire: CardData = CardCatalog.find(&"ab_fire")
	ctx.equal(mods.price(fire, 1), 3, "没上冷却时按卡面收")
	ctx.equal(mods.price(fire, 3), 9, "费用按**段**收：三段就是三次")
	for _index: int in 5:
		mods.apply(CardCatalog.find(&"fn_cooldown"))
	ctx.equal(mods.cooldown_stacks, 5, "冷却攒了五档")
	ctx.equal(mods.price(fire, 1), 0, "冷却超过卡面费用时收到 0，不倒贴")
	ctx.equal(mods.price(fire, 3), 0, "三段也还是 0")


## 循环：成功施放后游标回到队首 —— 但**付不起时照旧轮到下一张**。
## 后半句才是这条规则的难点，而这个试验台正好把两句一起量了：角子（循环）反复被打出来，
## 说明游标确实回了队首；排在他前面那张永远付不起的火球并没有把整本书锁死，
## 说明失败的那一拍游标仍在前进。去掉后半句，游标会卡在火球上，角子只会被打出一次。
func _check_loop(ctx: RefCounted) -> void:
	var run: Dictionary = _run(_rig([&"ab_fire", &"fn_loop"], 1), 61)
	ctx.check(run["sim"].mods().looping, "循环已经打出来过")
	ctx.equal(_damages(run["casts"], &"fn_loop").size(), 3, "循环生效：队首那张反复轮到自己")
	ctx.equal(_damages(run["casts"], &"ab_fire").size(), 0, "付不起的火球一次都没打出去")


## 一波的三种收场：清空 / 被摧毁 / 还在打 —— 一个三态枚举，不是两个各自为政的 bool，
## 于是「同时既清空又摧毁」在结构上就不可能出现。
func _check_outcome(ctx: RefCounted) -> void:
	var mid: Dictionary = _run(_rig([&"ab_wind"]), 100)
	ctx.check((mid["sim"] as CombatSim).is_active(), "打到一半（100 拍）还没收场")
	ctx.check(int(mid["sim"].enemy_hp()) > 0, "那时候敌群还有血")
	var empty: Dictionary = _run(BoardModel.new(), CombatSim.WAVE_TIME_LIMIT_TICKS)
	ctx.equal(empty["sim"].outcome(), CombatSim.Outcome.DESTROYED, "打不完 → 核心被摧毁")
	ctx.equal(empty["sim"].enemy_hp(), empty["sim"].enemy_hp_max(), "没卡就一点伤害都打不出")
	var win: Dictionary = _run(_rig([&"ab_wind"]), CombatSim.WAVE_TIME_LIMIT_TICKS)
	ctx.equal(win["sim"].outcome(), CombatSim.Outcome.CLEARED, "伤害够 → 本波清空")
	ctx.equal(win["sim"].enemy_hp(), 0, "敌群血量归零")
	var wave2: Dictionary = _run(_rig([&"ab_wind"]), 10, 2)
	ctx.equal(wave2["sim"].enemy_hp_max(), CombatSim.ENEMY_HP_BASE + CombatSim.ENEMY_HP_PER_WAVE,
		"第 2 波的敌群更厚")
	ctx.equal(wave2["sim"].outcome(), CombatSim.Outcome.ONGOING, "刚开局还在打")


## 同种子可重放：同一书页 + 同一波次，两次的结算流水必须**逐行**相同。
## 本仿真不吃任何随机数，所以「固定种子 ⇒ 固定结果」在这里是构造性的 ——
## 不是「碰巧两次一样」，而是结果只由书页与波次决定。换一张书页必须换一份流水，
## 否则上面那句「一致」就是空真（两条都恒为空也会通过）。
func _check_replay(ctx: RefCounted) -> void:
	var ids: Array[StringName] = [&"fn_enchant", &"fn_haste", &"ab_fire", &"ab_wind"]
	var first: PackedStringArray = _run(_rig(ids), 600, 2)["sim"].settlement_log()
	var second: PackedStringArray = _run(_rig(ids), 600, 2)["sim"].settlement_log()
	ctx.check(first.size() > 5, "流水有 %d 行，不是空重放" % first.size())
	ctx.equal(second, first, "同一书页重放两次，逐行一致")
	var other: PackedStringArray = _run(_rig([&"ab_ice"]), 600, 2)["sim"].settlement_log()
	ctx.check(other != first, "换一张书页流水就不同 —— 上面的相同不是空真")
