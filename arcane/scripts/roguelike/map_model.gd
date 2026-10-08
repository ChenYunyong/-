## map_model.gd
## 职责：杀戮尖塔式分支路线图的数据模型 —— 层、节点、节点之间的边，以及「现在能去哪」。
## 所属系统：roguelike
## 依赖：无（随机源由调用方传入种子）
## 禁止：本文件不得引用场景 / UI / Palette —— 它是纯图数据；
##       不得自己取随机数种子（03 §6：全项目随机必须来自 RunState），故 generate() 收 seed 参数。
##
## 布局：TIERS 层 × COLUMNS 列。层号越大越靠后，第 0 层是起点。
## 连通性由构造保证：先给每个节点接一条「正下方」的边（于是每个节点都有出边、也都有入边），
## 再随机加斜向边。这样不会生成走不通的图，也就不需要「生成后校验、失败重来」的兜底循环。

class_name MapModel
extends RefCounted

## 节点类型。战斗 = 打一波；工坊 = 不进战斗，直接回编辑器调整书页。
enum Kind { BATTLE, WORKSHOP }

const TIERS: int = 6
const COLUMNS: int = 3
## 工坊出现概率（百分比）。第 0 层与最后一层强制为战斗 —— 开局和收尾都该打一场。
const WORKSHOP_CHANCE: int = 25

## 路线图上的一个节点。
class MapNode:
	extends RefCounted
	var id: int = 0
	var tier: int = 0
	var column: int = 0
	var kind: Kind = Kind.BATTLE
	## 出边（指向下一层的节点 id）。
	var next: Array[int] = []

	func _init(node_id: int = 0, on_tier: int = 0, at_column: int = 0, node_kind: Kind = Kind.BATTLE) -> void:
		id = node_id
		tier = on_tier
		column = at_column
		kind = node_kind


var _nodes: Array[MapNode] = []
## 玩家当前所在的节点 id。-1 表示还没踏上第 0 层。
var _current: int = -1
var _visited: Dictionary = {}
## 走过的**顺序**（含当前节点）。_visited 只回答「来没来过」，这个回答「怎么来的」——
## 路线图上那道走过的痕迹要的是顺序，而 03 不允许从字典的键序里反推顺序。
var _order: Array[int] = []


## 按种子生成一张图。同一 seed 永远得到同一张图（03 §6：可复现）。
func generate(seed_value: int) -> void:
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = seed_value
	_nodes = []
	_current = -1
	_visited = {}
	_order = []
	for tier: int in TIERS:
		for column: int in COLUMNS:
			_nodes.append(MapNode.new(_nodes.size(), tier, column, _roll_kind(generator, tier)))
	for node: MapNode in _nodes:
		if node.tier >= TIERS - 1:
			continue
		_add_edge(node, node.column)
		if generator.randi_range(0, 99) < 50:
			var side: int = node.column + (1 if generator.randi_range(0, 1) == 0 else -1)
			if side >= 0 and side < COLUMNS:
				_add_edge(node, side)


func nodes() -> Array[MapNode]:
	return _nodes


func find(id: int) -> MapNode:
	for node: MapNode in _nodes:
		if node.id == id:
			return node
	return null


func nodes_in_tier(tier: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for node: MapNode in _nodes:
		if node.tier == tier:
			result.append(node)
	return result


func current_id() -> int:
	return _current


func current() -> MapNode:
	return find(_current)


func is_visited(id: int) -> bool:
	return _visited.has(id)


## 走过的节点序列，从起点到当前。还没出发就是空的。
## 画「走过的痕迹」用它 —— select() 是唯一会往里面加东西的地方。
func path() -> Array[int]:
	return _order.duplicate()


## 现在可以选的节点。还没出发 → 第 0 层全部；否则 → 当前节点的出边。
func selectable() -> Array[MapNode]:
	var result: Array[MapNode] = []
	if _current < 0:
		return nodes_in_tier(0)
	var here: MapNode = current()
	if here == null:
		return result
	for id: int in here.next:
		var node: MapNode = find(id)
		if node != null:
			result.append(node)
	return result


func can_select(id: int) -> bool:
	for node: MapNode in selectable():
		if node.id == id:
			return true
	return false


## 走到某个节点。不合法时返回 false，且不改变任何状态。
func select(id: int) -> bool:
	if not can_select(id):
		return false
	_current = id
	_visited[id] = true
	_order.append(id)
	return true


## 是否已走到最后一层（路线的尽头）。
func is_finished() -> bool:
	var here: MapNode = current()
	return here != null and here.tier >= TIERS - 1


## 走过的最深一层。还没出发是 -1。
## **不用 current()**：那是「现在站在哪」，而结算是按「这一局到过哪」念的 ——
## 走到头之后 current 会停在最后一层，两者恰好相同；但路线图上真正决定长度的是这个。
func deepest_tier() -> int:
	var deepest: int = -1
	for id: int in _visited:
		var node: MapNode = find(id)
		if node != null:
			deepest = maxi(deepest, node.tier)
	return deepest


func _add_edge(from: MapNode, target_column: int) -> void:
	var target: MapNode = find(_index_of(from.tier + 1, target_column))
	if target == null or from.next.has(target.id):
		return
	from.next.append(target.id)


func _index_of(tier: int, column: int) -> int:
	return tier * COLUMNS + column


func _roll_kind(generator: RandomNumberGenerator, tier: int) -> Kind:
	if tier == 0 or tier >= TIERS - 1:
		return Kind.BATTLE
	return Kind.WORKSHOP if generator.randi_range(0, 99) < WORKSHOP_CHANCE else Kind.BATTLE
