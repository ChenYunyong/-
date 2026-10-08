## combat_sim.gd
## 职责：自动施法战斗的确定性仿真 —— 书页连线的施放顺序、逐 tick 推进、胜负判定与结算流水。
## 所属系统：combat
## 依赖：BoardModel, CardData, CardCatalog, CombatMods（功能卡八类的本波修正）
## 禁止：本文件不得引用任何节点 / 绘制 / Palette（它不画东西，只出状态）；
##       不得使用随机数 —— docs/03 §4.2 要求可复现：同一书页 + 同一波次必须得到同一结果；
##       不得回写 BoardModel（03 §4.3：战斗只读书页）。
##
## 基础规则（FIRST PLAYABLE 的三条，刻意只有三条）：
##   1. 每 20 tick（1 秒）核心卡产出一次魔力；
##   2. 每 10 tick（0.5 秒）轮到队列里的**下一张**卡施放一次；轮到谁就是谁，
##      付不起就空过一轮 —— 所以「把便宜卡放在前面」是有意义的取舍，
##      而不会出现一张廉价卡永远霸占队列、后面的大招一辈子轮不到；
##   3. 波次限时 30 秒（减速会推长它），超时即核心被摧毁。
##
## 功能卡八类（PET-89 §1）的修正规则在 CombatMods 里，本文件只负责在轮到它的那一拍
## 把它应用上去。它们本来就在施放队列里、也照付费用（见 test_combat_sim 的
## _check_cast_order / _check_no_starvation），所以修正是「打出来了才生效、并在本波内累积」，
## 而不是「摆在书页上就一直有效」—— 后者会让功能卡一次都不用打出来，
## 与「队列里真的有它」这件事自相矛盾。

class_name CombatSim
extends RefCounted

## 施放了一张卡。一次施放可能发多枚（子弹数量 / 连发数量），故同拍可能收到多条。
signal cast_performed(card_id: StringName, damage: int, mana_left: int)
## 本波敌人清空。
signal wave_cleared()
## 超时，核心被摧毁。
signal core_destroyed()

## 本波的结局。**三态**而不是两个各自为政的 bool —— 界面与测试都只读这一个字段，
## 于是「同时既清空又摧毁」这种没人定义过的局面在结构上就不可能出现。
enum Outcome { ONGOING, CLEARED, DESTROYED }

## docs/03 §4.2 的固定步长。
const TICK_HZ: int = 20
const CAST_INTERVAL_TICKS: int = 10
const MANA_INTERVAL_TICKS: int = TICK_HZ
const WAVE_TIME_LIMIT_TICKS: int = TICK_HZ * 30
const ENEMY_HP_BASE: int = 60
const ENEMY_HP_PER_WAVE: int = 20

var _board: BoardModel = null
## 魔力来源：书页上的核心卡。它们**不进施法队列**（核心是电源，不是法术）。
var _sources: Array[CardData] = []
## 施放队列：从核心出发按出边广度优先，只收「连得到核心」的**非核心**卡。
var _order: Array[CardData] = []
## 本波累计的功能卡修正。规则在它自己那个文件里。
var _mods: CombatMods = CombatMods.new()
var _mana: int = 0
## 距下一次核心产出的拍数。**倒数**而不是 `_ticks % 周期`：加速会在波次中途改周期，
## 取模下改周期会让下一次产出忽早忽晚（取决于当时 _ticks 落在哪），而倒数只影响下一轮。
var _mana_timer: int = 0
var _enemy_hp: int = 0
var _enemy_hp_max: int = 0
var _ticks: int = 0
var _cast_timer: int = 0
var _cursor: int = 0
var _wave: int = 1
var _outcome: Outcome = Outcome.ONGOING
## 本局的常驻加成（PET-92：奖励里「强化」与「供能」两条杠杆）。**由调用方传进来**，
## 仿真不自己去问 RunState —— 否则「同一书页 + 同一波次 + 同一加成 → 同一结果」这条
## 就不再是入参决定的，测试也没法构造一个「只差加成」的对照。
var _damage_bonus: int = 0
var _mana_bonus: int = 0
## 本次战斗的结算流水。**逐行可比对**才算证明了可复现 ——
## 只比一个最终血量的话，两场顺序完全不同、总伤害恰好相同的战斗会被判成一致。
var _log: PackedStringArray = PackedStringArray()


## 开始一波。书页只读，仿真不持有它的引用做写操作。
## damage_bonus / mana_bonus 是本局的常驻加成，缺省为 0 —— 只打一场「素」战斗的调用方不用管它们。
func begin(board: BoardModel, wave: int, damage_bonus: int = 0, mana_bonus: int = 0) -> void:
	_board = board
	_wave = wave
	_damage_bonus = maxi(damage_bonus, 0)
	_mana_bonus = maxi(mana_bonus, 0)
	_collect(board)
	_mana = 0
	_enemy_hp_max = ENEMY_HP_BASE + ENEMY_HP_PER_WAVE * maxi(wave - 1, 0)
	_enemy_hp = _enemy_hp_max
	_ticks = 0
	_cast_timer = 0
	_cursor = 0
	_outcome = Outcome.ONGOING
	_mods.reset()
	_mana_timer = _mods.mana_period_ticks(MANA_INTERVAL_TICKS)
	_log = PackedStringArray()


# ------------------------------------------------------------------ 只读状态

func is_active() -> bool:
	return _outcome == Outcome.ONGOING


func outcome() -> Outcome:
	return _outcome


func wave() -> int:
	return _wave


func mana() -> int:
	return _mana


func enemy_hp() -> int:
	return _enemy_hp


func enemy_hp_max() -> int:
	return _enemy_hp_max


func elapsed_ticks() -> int:
	return _ticks


## 本波限时。减速会把它推长，故界面与判定都取它，不再各自去读那个常数。
func time_limit_ticks() -> int:
	return _mods.time_limit_ticks(WAVE_TIME_LIMIT_TICKS)


## 核心产出的节拍（加速会缩短它）。
func mana_period_ticks() -> int:
	return _mods.mana_period_ticks(MANA_INTERVAL_TICKS)


## 施法节拍（攻速会缩短它）。
func cast_interval_ticks() -> int:
	return _mods.cast_interval_ticks(CAST_INTERVAL_TICKS)


## 本波的修正表。界面用它显示「本波加成」，测试用它逐条量八个通道。
func mods() -> CombatMods:
	return _mods


## 本场的常驻伤害加成（本局奖励带进来的）。
func damage_bonus() -> int:
	return _damage_bonus


## 本场的常驻魔力加成。
func mana_bonus() -> int:
	return _mana_bonus


## 本波会按什么顺序施放（只有法术卡，不含核心）。空数组 = 书页上没有任何「连到核心」的卡。
func cast_order() -> Array[CardData]:
	return _order


## 本场的结算流水。第一行是收官状态，之后每行一次施放 —— 固定种子重放两次必须逐行相同。
func settlement_log() -> PackedStringArray:
	# 加成写进表头：「这一波与上一波差在哪」必须一眼看得出来，不能只体现在逐段伤害里。
	var head: PackedStringArray = PackedStringArray([
		"wave=%d ticks=%d hp=%d/%d mana=%d outcome=%d dmg_bonus=%d mana_bonus=%d"
			% [_wave, _ticks, _enemy_hp, _enemy_hp_max, _mana, _outcome, _damage_bonus, _mana_bonus]])
	head.append_array(_log)
	return head


# ------------------------------------------------------------------ 推进

## 推进一 tick。结算完就停（Outcome 不再 ONGOING），重复调用无副作用。
func tick() -> void:
	if not is_active():
		return
	_ticks += 1
	_mana_timer -= 1
	if _mana_timer <= 0:
		_mana_timer = mana_period_ticks()
		_mana += _core_output()
	_cast_timer += 1
	if _cast_timer >= cast_interval_ticks():
		_cast_timer = 0
		_try_cast()
	if not is_active():
		return
	if _ticks >= time_limit_ticks():
		_finish(Outcome.DESTROYED)
		core_destroyed.emit()


## 推进 n tick。测试与「快进」用。
func advance(ticks: int) -> void:
	for _index: int in maxi(ticks, 0):
		if not is_active():
			return
		tick()


# ------------------------------------------------------------------ 施放

## 轮到队列里的下一张卡。游标**无条件**前进（循环除外）：付不起就空过这一轮。
## 空过不报错 —— 魔力不够是正常局面，玩家要自己把队列排顺。
##
## 循环只让**真的打出去了**的那一拍回到队首：否则一张永远付不起的贵卡会把整本书锁死，
## 而症状只是「打到某一拍之后就不动了」，几乎不可能从画面上查出来。
func _try_cast() -> void:
	if _order.is_empty():
		return
	var card: CardData = _order[_cursor]
	var did_cast: bool = _cast_card(card)
	if _mods.looping and did_cast:
		_cursor = 0
	else:
		_cursor = (_cursor + 1) % _order.size()


## 结算一次施放。付得起就打，付不起就空过（返回 false）。
## 段数与总价都由 CombatMods 定 —— 本文件只管「扣钱、打出去、记账」。
func _cast_card(card: CardData) -> bool:
	var hits: int = _mods.salvo(card)
	var price: int = _mods.price(card, hits)
	if price > _mana:
		return false
	_mana -= price
	_mods.consume_burst(card)
	for _index: int in hits:
		if not is_active():
			break
		_strike(card)
	_mods.apply(card)
	return true


## 打出一段。伤害 = 卡面伤害 ×附魔倍率 + 本局强化，四舍五入到整数（信号带的是 int）。
## 加成**加在倍率之后**：附魔是「这一波按比例放大」，强化是「本局每一段都多打这么多」，
## 先加后乘的话，一个 +2 会在附魔 1.5× 下变成 +3，账就对不上了。
func _strike(card: CardData) -> void:
	var damage: int = maxi(roundi(float(card.damage) * _mods.damage_multiplier()) + _damage_bonus, 0)
	_enemy_hp = maxi(0, _enemy_hp - damage)
	_log.append("t%04d %s dmg=%d mana=%d hp=%d" % [_ticks, card.id, damage, _mana, _enemy_hp])
	cast_performed.emit(card.id, damage, _mana)
	if _enemy_hp <= 0:
		_finish(Outcome.CLEARED)
		wave_cleared.emit()


func _finish(outcome_value: Outcome) -> void:
	_outcome = outcome_value


## 核心每次产出多少魔力。加上本局的供能加成 —— 没有来源（书页上没核心）时照样给：
## 加成是「本局的电源更足」，不是「核心产得更多」，后者在没有核心时会变成一句空话。
func _core_output() -> int:
	var total: int = 0
	for card: CardData in _sources:
		total += card.mana_output
	return total + _mana_bonus


## 分两件事：书页上的**核心卡**是电源（_sources），从它们出发广度优先能走到的
## **非核心卡**才是施法队列（_order）。核心卡自己不施放 —— 它是插座，不是法术。
##
## 用 visited 而不是「有没有环」的假设：BoardModel 已经挡住成环，这里仍然防重入，
## 免得一个意外构造出来的模型把仿真拖进死循环。
func _collect(board: BoardModel) -> void:
	_sources = []
	_order = []
	if board == null:
		return
	var visited: Dictionary = {}
	var queue: Array[int] = []
	for placed: BoardModel.PlacedCard in board.cards():
		var data: CardData = placed.data()
		if data != null and data.is_core():
			_sources.append(data)
			queue.append(placed.uid)
	while not queue.is_empty():
		var uid: int = queue.pop_front()
		if visited.has(uid):
			continue
		visited[uid] = true
		var placed: BoardModel.PlacedCard = board.find_card(uid)
		if placed == null:
			continue
		var data: CardData = placed.data()
		if data != null and not data.is_core():
			_order.append(data)
		for link: BoardModel.Link in board.links():
			if link.from_uid == uid and not visited.has(link.to_uid):
				queue.append(link.to_uid)
