## test_combat_sim.gd
## 职责：自动施法仿真的验收 —— 施放顺序、魔力产出、清波、超时，以及**可复现**。
## 所属系统：tests
## 依赖：CombatSim, BoardModel
## 禁止：本文件不得引用任何节点 —— 仿真层必须能脱离场景单独验证。

extends RefCounted


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_combat_sim")
	_check_empty_board(ctx)
	_check_cast_order(ctx)
	_check_mana_and_cast(ctx)
	_check_no_starvation(ctx)
	_check_wave_clear(ctx)
	_check_timeout(ctx)
	_check_determinism(ctx)


## 空书页：不会施放，只会在限时结束时判核心被摧毁 —— 不能崩，也不能假装打完了。
func _check_empty_board(ctx: RefCounted) -> void:
	var sim: CombatSim = CombatSim.new()
	sim.begin(BoardModel.new(), 1)
	ctx.equal(sim.cast_order().size(), 0, "空书页没有可施放的卡")
	ctx.check(sim.is_active(), "开局是进行中")
	sim.advance(CombatSim.WAVE_TIME_LIMIT_TICKS)
	ctx.check(not sim.is_active(), "限时到点后结束")
	ctx.equal(sim.enemy_hp(), sim.enemy_hp_max(), "没有卡就一点伤害都打不出")


## 施放队列 = 从核心出发走得到的**非核心**卡，顺序即拓扑序；
## 没连到核心的卡不进队列，核心卡自己也不进（它是电源，不是法术）。
func _check_cast_order(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var fire: BoardModel.PlacedCard = board.add_card(&"ab_fire", Vector2(200.0, 30.0))
	var haste: BoardModel.PlacedCard = board.add_card(&"fn_haste", Vector2(380.0, 30.0))
	var orphan: BoardModel.PlacedCard = board.add_card(&"ab_ice", Vector2(30.0, 200.0))
	board.connect_cards(core.uid, haste.uid)
	board.connect_cards(haste.uid, fire.uid)

	var sim: CombatSim = CombatSim.new()
	sim.begin(board, 1)
	var order: Array[CardData] = sim.cast_order()
	ctx.equal(order.size(), 2, "队列只有两张可达的法术卡")
	ctx.equal(order[0].id, &"fn_haste", "离核心近的先施放")
	ctx.equal(order[1].id, &"ab_fire", "再往下才是火球")
	for card: CardData in order:
		ctx.check(not card.is_core(), "核心卡不进施法队列：%s" % card.id)
	var ids: Array[StringName] = []
	for card: CardData in order:
		ids.append(card.id)
	ctx.check(not ids.has(orphan.card_id), "没连到核心的卡不进队列")


## 魔力按秒产出；付得起就施放，施放后魔力扣除、敌人掉血。
## 火球费用 3，整整一秒才攒到 2 点 —— 第一轮必然空过，这本身就是规则的一部分。
func _check_mana_and_cast(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var fire: BoardModel.PlacedCard = board.add_card(&"ab_fire", Vector2(200.0, 30.0))
	board.connect_cards(core.uid, fire.uid)

	var sim: CombatSim = CombatSim.new()
	sim.begin(board, 1)
	ctx.equal(sim.mana(), 0, "开局没有魔力")
	sim.advance(CombatSim.MANA_INTERVAL_TICKS)
	ctx.equal(sim.mana(), 2, "一秒后核心产出 2 点魔力")

	var hp_before: int = sim.enemy_hp()
	sim.advance(CombatSim.MANA_INTERVAL_TICKS)
	ctx.check(sim.enemy_hp() < hp_before, "攒够费用后开始施放")
	ctx.check(sim.mana() < 4, "施放后魔力被扣掉")


## 队列是**严格轮转**：轮到谁就是谁。加速（1 费）排在火球（3 费）前面时，
## 火球不能因为「总有一张更便宜的付得起」而被永久饿死 —— 这正是游标无条件前进的理由。
func _check_no_starvation(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var haste: BoardModel.PlacedCard = board.add_card(&"fn_haste", Vector2(200.0, 30.0))
	var fire: BoardModel.PlacedCard = board.add_card(&"ab_fire", Vector2(380.0, 30.0))
	board.connect_cards(core.uid, haste.uid)
	board.connect_cards(haste.uid, fire.uid)

	var sim: CombatSim = CombatSim.new()
	sim.begin(board, 1)
	var cast_ids: Array[StringName] = []
	sim.cast_performed.connect(
		func(card_id: StringName, _damage: int, _mana_left: int) -> void: cast_ids.append(card_id))
	sim.advance(CombatSim.CAST_INTERVAL_TICKS * 7)
	ctx.check(cast_ids.has(&"fn_haste"), "便宜卡轮到就施放")
	ctx.check(cast_ids.has(&"ab_fire"), "贵卡也轮得到 —— 不会被便宜卡饿死")
	ctx.check(sim.enemy_hp() < sim.enemy_hp_max(), "敌人实打实掉血")


## 敌人血量归零 → 本波清空，且状态机停在这一波（不再继续计时）。
func _check_wave_clear(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var wind: BoardModel.PlacedCard = board.add_card(&"ab_wind", Vector2(200.0, 30.0))
	board.connect_cards(core.uid, wind.uid)

	var sim: CombatSim = CombatSim.new()
	sim.begin(board, 1)
	var cleared: Array[bool] = [false]
	sim.wave_cleared.connect(func() -> void: cleared[0] = true)
	# 疾风刃费用 1 伤害 3，敌人 60 血：跑够久必然清空。
	sim.advance(CombatSim.WAVE_TIME_LIMIT_TICKS)
	ctx.check(cleared[0], "敌人血量归零时发出清波信号")
	ctx.equal(sim.enemy_hp(), 0, "敌人血量归零")
	ctx.check(not sim.is_active(), "清波后仿真停下")


## 打不完就超时判负 —— 这是本题材唯一的失败条件。
func _check_timeout(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var sim: CombatSim = CombatSim.new()
	sim.begin(board, 1)
	var lost: Array[bool] = [false]
	sim.core_destroyed.connect(func() -> void: lost[0] = true)
	sim.advance(CombatSim.WAVE_TIME_LIMIT_TICKS - 1)
	ctx.check(not lost[0], "还没到点不算输")
	sim.advance(1)
	ctx.check(lost[0], "到点判核心被摧毁")
	ctx.check(not sim.is_active(), "判负后仿真停下")


## 同一书页 + 同一波次必须得到同一结果（03 §4.2）。
func _check_determinism(ctx: RefCounted) -> void:
	var first: CombatSim = CombatSim.new()
	first.begin(_sample_board(), 2)
	first.advance(CombatSim.WAVE_TIME_LIMIT_TICKS)
	var second: CombatSim = CombatSim.new()
	second.begin(_sample_board(), 2)
	second.advance(CombatSim.WAVE_TIME_LIMIT_TICKS)
	ctx.equal(first.enemy_hp(), second.enemy_hp(), "两次跑完敌人血量一致")
	ctx.equal(first.mana(), second.mana(), "两次跑完魔力一致")
	ctx.equal(first.elapsed_ticks(), second.elapsed_ticks(), "两次跑完 tick 数一致")
	ctx.equal(first.is_active(), second.is_active(), "两次跑完进行状态一致")


func _sample_board() -> BoardModel:
	var board: BoardModel = BoardModel.new()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var fire: BoardModel.PlacedCard = board.add_card(&"ab_fire", Vector2(200.0, 30.0))
	var haste: BoardModel.PlacedCard = board.add_card(&"fn_haste", Vector2(380.0, 30.0))
	board.connect_cards(core.uid, haste.uid)
	board.connect_cards(haste.uid, fire.uid)
	return board
