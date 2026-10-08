## combat_chain.gd
## 职责：底栏那条「施法链」的画法 —— 最多 4 张 72 方卡（与编辑器同一张脸）、当前施法那张的强调、
##       以及链条窗外「后面还有」的状态标记。
## 所属系统：ui
## 依赖：CombatLayout（卡位与标记位的落点）、CombatTheme（角色表）、CardFace（与编辑器同一张卡面）、
##       StrokePainter（唯一的笔）、CardData
## 禁止：本文件不得出现裸色值；不得直接 draw_line / draw_polyline —— 线一律经 StrokePainter；
##       不得画卡与卡之间的连线（C01：卡牌连接大图占比 = 0，那是编辑器的活儿）；
##       不得改模型、不得处理输入、不得持有波次状态 —— 顺序由 CombatScreen 灌进来，这里只画。
##
## §2.3 原话：「自动链条超过 4 卡时显示以当前施法卡为终点的最近 4 卡；右侧明确 当前序号/总数，
## 完整链条/八通道加成保留在战后详情或可访问的日志中，不丢状态」。
## 于是这一条只负责窗口里那 4 张，「外面还有」这一事实分给两处：卡链右端 28px 的三点标记（后面还有）、
## 以及队列加成面板上那行「施法链 3/8」（第几张 / 共几张）。
## 窗口**前面**还有卡这件事没有第二个标记位（版式表只给了右端那 28px），它靠序号行读出来。
##
## 「当前施法那张」只由公开数据推出来：最后一次 cast_performed 的卡 id 在 cast_order() 里的下标。
## 不数「本波放了几次」—— 付不起的那一拍游标照样前进却**不发信号**（CombatSim._try_cast），
## 数信号会把序号数少，而症状只是「高亮的那张不是正在放的那张」。

class_name CombatChain
extends Control

## 当前施法那张卡的强调外圈：§1.1 的 Selected = 卡身外扩 5 + 完整金轮廓 4px。
## 底栏是暗底，故**不垫** §3 要求的那道 NAVY_600 暗轮廓（那是给亮纸用的）；
## 外扩后的包络 82 也落在 84 的卡距里，不碰邻卡。
const EMPHASIS_GROW: float = 5.0
const EMPHASIS_WIDTH: float = 4.0
## 尾端 28px 里那三个点：直径 6、间距 4，合计 26 ≤ 28。
const MORE_DOTS: int = 3
const MORE_DOT_RADIUS: float = 3.0
const MORE_DOT_GAP: float = 4.0

## 本波的施法链（只有法术卡，与 CombatSim.cast_order() 同一份顺序）。
var _order: Array[CardData] = []
## 当前施法那张在 _order 里的下标。-1 = 本波还没放过。
var _current: int = -1


# ------------------------------------------------------------------ 状态

## 换波时灌一份新顺序并清掉当前位 —— 上一波的高亮不该留在新一波的链条上。
func setup(order: Array[CardData]) -> void:
	_order = order
	_current = -1
	queue_redraw()


## 记下刚打出去的那张卡。id 不在链上时**保持原位**而不是退回队首：
## 退回队首会让高亮突然跳到第一张，而真实情况是「这一拍没有对应的窗口变化」。
func note_cast(card_id: StringName) -> void:
	for index: int in _order.size():
		if _order[index] != null and _order[index].id == card_id:
			_current = index
			queue_redraw()
			return


## 本帧要画的那一段：(起点下标, 张数)。窗口的算法在 CombatLayout.chain_window ——
## 它是版面上的事（§2.3 的「以当前施法卡为终点取最近 4 张」），也就能在布局层被量。
func window() -> Vector2i:
	return CombatLayout.chain_window(_current, _order.size())


# ------------------------------------------------------------------ 落笔

func _draw() -> void:
	var band: Vector2i = window()
	if band.y <= 0:
		return
	var fill: Color = CombatTheme.color(CombatTheme.Role.CARD_FILL)
	var ink: Color = CombatTheme.color(CombatTheme.Role.CARD_INK)
	for slot: int in band.y:
		var index: int = band.x + slot
		var card: CardData = _order[index]
		if card == null:
			continue
		var rect: Rect2 = _slot_rect(slot, band.y)
		CardFace.paint(self, card, rect.position, fill, ink)
		if index == _current:
			StrokePainter.stroke_path(self, StrokePainter.rect_path(rect.grow(EMPHASIS_GROW)),
				CombatTheme.color(CombatTheme.Role.EMPHASIS), EMPHASIS_WIDTH, true)
	if band.x + band.y < _order.size():
		_paint_more()


## 尾端三点：这条链比这里看到的长。它是**状态标记**不是按钮，故取中性副墨（§3 的角色表）；
## 具体还差几张不在这里编数字 —— 那行「施法链 3/8」才是权威。
func _paint_more() -> void:
	var band: Rect2 = _local(CombatLayout.chain_mark_rect())
	var pitch: float = MORE_DOT_RADIUS * 2.0 + MORE_DOT_GAP
	var span: float = float(MORE_DOTS) * MORE_DOT_RADIUS * 2.0 \
		+ float(MORE_DOTS - 1) * MORE_DOT_GAP
	var at: Vector2 = Vector2(band.position.x + (band.size.x - span) * 0.5 + MORE_DOT_RADIUS,
		band.get_center().y)
	var ink: Color = CombatTheme.color(CombatTheme.Role.CHAIN_MORE)
	for dot: int in MORE_DOTS:
		draw_circle(at + Vector2(float(dot) * pitch, 0.0), MORE_DOT_RADIUS, ink)


# ------------------------------------------------------------------ 几何

## 第 slot 个卡位在**本控件局部坐标**里的 rect。版式表给的是屏坐标，
## 这一层挂在 ACTIVE_CHAIN 上，故要减掉那个原点一次。
static func _slot_rect(slot: int, count: int) -> Rect2:
	return _local(CombatLayout.chain_card_rect(slot, count))


static func _local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - CombatLayout.ACTIVE_CHAIN.position, rect.size)
