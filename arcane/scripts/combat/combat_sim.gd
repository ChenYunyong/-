## combat_sim.gd
## 职责：自动施法战斗的确定性仿真 —— 按书页上的连线决定施放顺序，逐 tick 推进。
## 所属系统：combat
## 依赖：BoardModel, CardData, CardCatalog
## 禁止：本文件不得引用任何节点 / 绘制 / Palette（它不画东西，只出状态）；
##       不得使用随机数 —— docs/03 §4.2 要求可复现：同一书页 + 同一波次必须得到同一结果；
##       不得回写 BoardModel（03 §4.3：战斗只读书页）。
##
## 规则（FIRST PLAYABLE 的全部战斗规则，刻意只有三条）：
##   1. 每 20 tick（1 秒）核心卡产出一次魔力；
##   2. 每 10 tick（0.5 秒）轮到队列里的**下一张**卡施放一次；轮到谁就是谁，
##      付不起就空过一轮 —— 所以「把便宜卡放在前面」是有意义的取舍，
##      而不会出现一张廉价卡永远霸占队列、后面的大招一辈子轮不到；
##   3. 波次限时 30 秒，超时即核心被摧毁。

class_name CombatSim
extends RefCounted

## 施放了一张卡。
signal cast_performed(card_id: StringName, damage: int, mana_left: int)
## 本波敌人清空。
signal wave_cleared()
## 超时，核心被摧毁。
signal core_destroyed()

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
var _mana: int = 0
var _enemy_hp: int = 0
var _enemy_hp_max: int = 0
var _ticks: int = 0
var _cast_timer: int = 0
var _cursor: int = 0
var _wave: int = 1
var _active: bool = false


## 开始一波。书页只读，仿真不持有它的引用做写操作。
func begin(board: BoardModel, wave: int) -> void:
	_board = board
	_wave = wave
	_collect(board)
	_mana = 0
	_enemy_hp_max = ENEMY_HP_BASE + ENEMY_HP_PER_WAVE * maxi(wave - 1, 0)
	_enemy_hp = _enemy_hp_max
	_ticks = 0
	_cast_timer = 0
	_cursor = 0
	_active = true


func is_active() -> bool:
	return _active


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


func time_limit_ticks() -> int:
	return WAVE_TIME_LIMIT_TICKS


## 本波会按什么顺序施放（只有法术卡，不含核心）。空数组 = 书页上没有任何「连到核心」的卡。
func cast_order() -> Array[CardData]:
	return _order


## 推进一 tick。结算完就停（_active 转 false），重复调用无副作用。
func tick() -> void:
	if not _active:
		return
	_ticks += 1
	if _ticks % MANA_INTERVAL_TICKS == 0:
		_mana += _core_output()
	_cast_timer += 1
	if _cast_timer >= CAST_INTERVAL_TICKS:
		_cast_timer = 0
		_try_cast()
	if not _active:
		return
	if _ticks >= WAVE_TIME_LIMIT_TICKS:
		_active = false
		core_destroyed.emit()


## 推进 n tick。测试与「快进」用。
func advance(ticks: int) -> void:
	for _index: int in maxi(ticks, 0):
		if not _active:
			return
		tick()


## 轮到队列里的下一张卡。游标**无条件**前进：付不起就空过这一轮。
## 空过不报错 —— 魔力不够是正常局面，玩家要自己把队列排顺。
func _try_cast() -> void:
	if _order.is_empty():
		return
	var card: CardData = _order[_cursor]
	_cursor = (_cursor + 1) % _order.size()
	if card.mana_cost > _mana:
		return
	_mana -= card.mana_cost
	_enemy_hp = maxi(0, _enemy_hp - card.damage)
	cast_performed.emit(card.id, card.damage, _mana)
	if _enemy_hp <= 0:
		_active = false
		wave_cleared.emit()


func _core_output() -> int:
	var total: int = 0
	for card: CardData in _sources:
		total += card.mana_output
	return total


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
