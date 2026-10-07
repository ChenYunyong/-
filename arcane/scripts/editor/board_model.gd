## board_model.gd
## 职责：书页的数据模型 —— 摆上去的卡牌（**自由坐标**）与它们之间的奥术丝线（有向边）。
## 所属系统：editor
## 依赖：CardCatalog, CardData
## 禁止：本文件不得引用任何节点 / 绘制 / Palette —— 它是纯数据 + 图算法；
##       不得对坐标做任何量化：**本工程没有网格**，坐标原样保存（用户 2026-10-06：「不要搞格子」）。

class_name BoardModel
extends RefCounted

## 书页结构发生任何变化时触发。战斗仿真只监听，不回写（docs/03 §4.3）。
signal changed()

## 一张卡在书页上占的尺寸（逻辑像素）。= docs/06 §4 的节点卡 24×24（320×180 参考系）×3。
## 这是**模型**事实 —— 重叠判定与吸附参照都以它为准，绘制层必须用它，不得另立一个尺寸。
const CARD_SIZE: Vector2 = Vector2(72.0, 72.0)

## 试放落点的步长。取自 06 §5 的间距系统（4/8/12/16/24），**不是网格** ——
## 它只决定「候选落点从哪里开始试」，不参与任何坐标量化。
const PLACE_STEP: float = 24.0

## 画布上一张卡牌的实例。
class PlacedCard:
	extends RefCounted
	var uid: int = 0
	var card_id: StringName = &""
	## **自由坐标**，浮点，不吸附到任何网格。
	var position: Vector2 = Vector2.ZERO

	func _init(card_uid: int = 0, id: StringName = &"", at: Vector2 = Vector2.ZERO) -> void:
		uid = card_uid
		card_id = id
		position = at

	## 数据侧的卡牌定义。卡表是静态的，故不缓存副本。
	func data() -> CardData:
		return CardCatalog.find(card_id)


## 一条有向丝线：从 from_uid 的输出接口到 to_uid 的输入接口。
class Link:
	extends RefCounted
	var uid: int = 0
	var from_uid: int = 0
	var to_uid: int = 0

	func _init(link_uid: int = 0, source: int = 0, target: int = 0) -> void:
		uid = link_uid
		from_uid = source
		to_uid = target


var _cards: Array[PlacedCard] = []
var _links: Array[Link] = []
var _next_card_uid: int = 1
var _next_link_uid: int = 1


## 摆上一张卡。position 原样保存 —— 调用方给什么坐标就是什么坐标。
func add_card(card_id: StringName, position: Vector2) -> PlacedCard:
	var placed: PlacedCard = PlacedCard.new(_next_card_uid, card_id, position)
	_next_card_uid += 1
	_cards.append(placed)
	changed.emit()
	return placed


## 移除一张卡，并**一并清掉挂在它身上的所有丝线**（09 §3.2：删除被引用的节点，连线一并清理）。
func remove_card(uid: int) -> bool:
	var index: int = _index_of_card(uid)
	if index < 0:
		return false
	_cards.remove_at(index)
	var kept: Array[Link] = []
	for link: Link in _links:
		if link.from_uid != uid and link.to_uid != uid:
			kept.append(link)
	_links = kept
	changed.emit()
	return true


## 移动一张卡。**不做任何吸附 / 量化** —— 吸附是交互层（Snap）在拖动时算好的结果，
## 模型只负责存下来。两件事分开，才能让「自由摆放」这条规则可被单测单独钉住。
func move_card(uid: int, position: Vector2) -> bool:
	var placed: PlacedCard = find_card(uid)
	if placed == null:
		return false
	placed.position = position
	changed.emit()
	return true


## 连一条丝线。拒绝自连、重复、以及会成环的连接（03 §4.2 要求显式处理环路而非死循环）。
func connect_cards(from_uid: int, to_uid: int) -> int:
	if from_uid == to_uid:
		return -1
	if find_card(from_uid) == null or find_card(to_uid) == null:
		return -1
	if has_link(from_uid, to_uid):
		return -1
	if would_create_cycle(from_uid, to_uid):
		return -1
	var link: Link = Link.new(_next_link_uid, from_uid, to_uid)
	_next_link_uid += 1
	_links.append(link)
	changed.emit()
	return link.uid


## 断开一条丝线。**不叫 disconnect()** —— Object 上已有同名的内置方法（断开信号），
## 同名会把内置的那个遮掉并让整个脚本编译失败（已在 --check-only 里撞到过）。
func remove_link(link_uid: int) -> bool:
	for index: int in _links.size():
		if _links[index].uid == link_uid:
			_links.remove_at(index)
			changed.emit()
			return true
	return false


func has_link(from_uid: int, to_uid: int) -> bool:
	for link: Link in _links:
		if link.from_uid == from_uid and link.to_uid == to_uid:
			return true
	return false


## 新增 from → to 是否会让图出现环。从 to 出发沿出边走，能走回 from 就是环。
func would_create_cycle(from_uid: int, to_uid: int) -> bool:
	var stack: Array[int] = [to_uid]
	var seen: Dictionary = {}
	while not stack.is_empty():
		var current: int = stack.pop_back()
		if current == from_uid:
			return true
		if seen.has(current):
			continue
		seen[current] = true
		for link: Link in _links:
			if link.from_uid == current:
				stack.append(link.to_uid)
	return false


func find_card(uid: int) -> PlacedCard:
	var index: int = _index_of_card(uid)
	return null if index < 0 else _cards[index]


## 连接到 uid 的所有丝线（进 + 出）。
func links_of(uid: int) -> Array[Link]:
	var result: Array[Link] = []
	for link: Link in _links:
		if link.from_uid == uid or link.to_uid == uid:
			result.append(link)
	return result


func cards() -> Array[PlacedCard]:
	return _cards


func links() -> Array[Link]:
	return _links


## 这张卡是不是「起点」：它没有入边。孤立的核心卡也是起点。
func is_start_of_chain(uid: int) -> bool:
	for link: Link in _links:
		if link.to_uid == uid:
			return false
	return true


## 给新卡找一个不与任何已有卡重叠的落点：离画布中心最近的那个空位。
## 这是「放置」而不是「吸附」—— 只求落点不叠在一起，落下去之后玩家可以拖到任何位置。
##
## 规则放在模型里而不是画布里：抽卡奖励（REWARD 屏）没有画布可问，但需要同一条规则。
##
## 落点**必须落在画布内**：画布外的卡会被裁掉，玩家看不见也拖不回来。
## （旧实现沿对角线一路往右下挪，撞到底边就停 —— 会返回一个已经出界的坐标。）
func free_position(view_size: Vector2) -> Vector2:
	var limit: Vector2 = (view_size - CARD_SIZE).max(Vector2.ZERO)
	var centre: Vector2 = limit * 0.5
	var candidates: Array[Vector2] = []
	var y: float = 0.0
	while y <= limit.y:
		var x: float = 0.0
		while x <= limit.x:
			candidates.append(Vector2(x, y))
			x += PLACE_STEP
		y += PLACE_STEP
	# 离中心近的先试 —— 新卡落在视线中央，而不是贴着画布角。
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		return a.distance_squared_to(centre) < b.distance_squared_to(centre))
	for candidate: Vector2 in candidates:
		if not _overlaps_any(candidate):
			return candidate
	# 整块画布都占满了：退回中心。宁可叠着，也不能把卡放到看不见的地方去。
	return centre


func _overlaps_any(top_left: Vector2) -> bool:
	var probe: Rect2 = Rect2(top_left, CARD_SIZE)
	for placed: PlacedCard in _cards:
		if Rect2(placed.position, CARD_SIZE).intersects(probe):
			return true
	return false


## 导出快照。撤销用 —— 快照是值拷贝，之后的改动不会穿回去。
func snapshot() -> Dictionary:
	var cards: Array[Dictionary] = []
	for placed: PlacedCard in _cards:
		cards.append({"uid": placed.uid, "id": placed.card_id, "pos": placed.position})
	var links: Array[Dictionary] = []
	for link: Link in _links:
		links.append({"uid": link.uid, "from": link.from_uid, "to": link.to_uid})
	return {"cards": cards, "links": links, "next_card": _next_card_uid, "next_link": _next_link_uid}


## 从快照恢复。uid 计数器一并回滚，否则「撤销后重做同一步」会拿到不同的 uid。
func restore(state: Dictionary) -> void:
	_cards = []
	for row: Dictionary in state.get("cards", []):
		_cards.append(PlacedCard.new(int(row["uid"]), row["id"], row["pos"]))
	_links = []
	for row: Dictionary in state.get("links", []):
		_links.append(Link.new(int(row["uid"]), int(row["from"]), int(row["to"])))
	_next_card_uid = int(state.get("next_card", 1))
	_next_link_uid = int(state.get("next_link", 1))
	changed.emit()


func _index_of_card(uid: int) -> int:
	for index: int in _cards.size():
		if _cards[index].uid == uid:
			return index
	return -1
