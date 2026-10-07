## map_node_painter.gd
## 职责：路线图上节点的**四种状态**与边线的**三种样式**的画法 —— 已访问 / 当前 / 可选 / 不可达。
## 所属系统：roguelike（绘制辅助）
## 依赖：Palette（Token）、StrokePainter（唯一的笔）
## 禁止：本文件不得出现裸色值；不得引用节点 / 场景 / 字体 —— 颜色、坐标、文字全由调用方传进来。
##
## 06 §11：状态不能只靠明度区分。四种状态各自由**六个维度**描述 ——
##   填充 / 是否空心 / 外圈色 / 外圈外扩 / 符号墨色 / 内环标记。
## 任意两个状态至少在其中两个维度上不同，这是算术不是目视结论，test_map_paint 会逐对量一遍。
##
## 关键的一对是「已访问 / 当前」：两者填充只差 39（0-255 的 RGB 距离，远低于本工程判「塌成一家」
## 的 96 那一档），光靠颜色根本分不开 —— 正是这一对逼出了外圈、外扩与内环这三个维度
## （棕圈 vs 金圈，且当前节点多一圈内环）。

class_name MapNodePainter
extends RefCounted

enum State { UNREACHABLE, SELECTABLE, VISITED, CURRENT }

## 六个维度各一行，下标即 State。改状态外观只改这里，画法那边不再做任何判断。
##
## 不可达那一格填的是**纸色**：它根本不填，纸面直接透出来（由 STATE_HOLLOW 说了算）。
## 写纸色而不是写个哨兵，是为了让「它离纸面多远」这句话可以被直接量出来 —— 答案是 0，
## 因为它压根不靠填充说话。
const STATE_FILL: Array[Palette.Key] = [Palette.Key.WARM_300,
	Palette.Key.GOLD_500, Palette.Key.BROWN_500, Palette.Key.BROWN_700]
## 空心 / 实心。这是**结构**差异，比换一个相近的纸色分得开得多。
const STATE_HOLLOW: Array[bool] = [true, false, false, false]
const STATE_RING: Array[Palette.Key] = [Palette.Key.BROWN_500,
	Palette.Key.BROWN_700, Palette.Key.BROWN_700, Palette.Key.GOLD_500]
const STATE_RING_WIDTH: Array[float] = [2.0, 3.0, 3.0, 3.0]
const STATE_RING_GROW: Array[float] = [0.0, 4.0, 0.0, 4.0]
const STATE_INK: Array[Palette.Key] = [Palette.Key.BROWN_500,
	Palette.Key.BROWN_700, Palette.Key.WARM_300, Palette.Key.WARM_300]
## 当前节点额外多一圈内环（金色，画在**填充之上**）。
const STATE_MARK: Array[bool] = [false, false, false, true]

## 内环的内缩量与线宽。
const MARK_INSET: float = 5.0
const MARK_WIDTH: float = 3.0
## 圆用多少段折线逼近。笔只画折线（draw_arc 是另一套端点口径，不在这里混用）。
const CIRCLE_SEGMENTS: int = 32

## 纸面上的文字（节点短名 / 图例标签）用这一支墨色，与状态无关 —— 文字是给人读的，
## 不参与状态编码。9.23:1，稳稳过 06 §11 的 4.5:1。
const INK_ON_PAPER: Palette.Key = Palette.Key.BROWN_700

## 边线的三种样式：还走不到 / 可以走 / 已经走过。只用墨色与线宽区分，不另开颜色家族。
enum EdgeStyle { DORMANT, OPEN, WALKED }
const EDGE_TOKEN: Array[Palette.Key] = [Palette.Key.BROWN_500,
	Palette.Key.BROWN_700, Palette.Key.BROWN_700]
const EDGE_WIDTH: Array[float] = [2.0, 3.0, 5.0]

## 走不了时套在节点上的红圈与外扩量，以及那道斜杠。
const REJECT_GROW: float = 6.0
const REJECT_WIDTH: float = 3.0
const REJECT_SLASH: float = 0.62


# ------------------------------------------------------------------ 状态判定

## 某节点此刻处于哪种状态。**先判当前** —— 当前节点同时也是「已访问」的。
static func state_of(model: MapModel, id: int) -> State:
	if id == model.current_id():
		return State.CURRENT
	if model.is_visited(id):
		return State.VISITED
	if model.can_select(id):
		return State.SELECTABLE
	return State.UNREACHABLE


## 一个状态的六个可区分维度，值已经解析成**此刻真正画上去的样子**（颜色是 Color）。
## 测试拿它逐对比较 —— 维度里既有颜色也有结构，所以「哪两个状态太像」这件事
## 是可以被算出来的，而不是靠再看一眼。
static func dimensions(state: State) -> Dictionary:
	return {
		"fill": fill_color(state),
		"hollow": STATE_HOLLOW[state],
		"ring": ring_color(state),
		"ring_grow": STATE_RING_GROW[state],
		"ink": ink(state),
		"mark": STATE_MARK[state],
	}


## 符号画在节点里的墨色。空心状态下它落在纸面上，那时它是「还没点亮」的淡墨。
static func ink(state: State) -> Color:
	return Palette.get_color(STATE_INK[state])


## 某状态的外圈色。空心 / 实心之外的第二个维度就是它。
static func ring_color(state: State) -> Color:
	return Palette.get_color(STATE_RING[state])


## 某状态的填充色。空心状态返回的是纸色 —— 调用方按 STATE_HOLLOW 决定要不要真的填。
static func fill_color(state: State) -> Color:
	return Palette.get_color(STATE_FILL[state])


# ------------------------------------------------------------------ 画法

## 画一个节点：填充（空心则跳过）→ 外圈 → 内环标记。三个元素，顺序固定。
static func paint_node(target: CanvasItem, center: Vector2, radius: float, state: State) -> void:
	if not STATE_HOLLOW[state]:
		target.draw_circle(center, radius, fill_color(state))
	StrokePainter.stroke_path(target, circle_points(center, radius + STATE_RING_GROW[state]),
		ring_color(state), STATE_RING_WIDTH[state], true)
	if STATE_MARK[state]:
		StrokePainter.stroke_path(target, circle_points(center, radius - MARK_INSET),
			Palette.get_color(Palette.Key.GOLD_500), MARK_WIDTH, true)


## 一条边的样式。path 是走过的节点序列（MapModel.path()），current 是当前节点 id。
static func edge_style(source_id: int, target_id: int, path: Array[int], current: int) -> EdgeStyle:
	if _is_walked(source_id, target_id, path):
		return EdgeStyle.WALKED
	return EdgeStyle.OPEN if source_id == current else EdgeStyle.DORMANT


static func paint_edge(target: CanvasItem, from: Vector2, to: Vector2, style: EdgeStyle) -> void:
	var token: Palette.Key = EDGE_TOKEN[style]
	StrokePainter.stroke_path(target, PackedVector2Array([from, to]),
		Palette.get_color(token), EDGE_WIDTH[style], false)


## 「走不了」的当场反馈：一圈红 + 一道斜杠。它一直留到下一次点击 —— 界面自己不会走。
static func paint_rejected(target: CanvasItem, center: Vector2, radius: float) -> void:
	var color: Color = Palette.get_color(Palette.Key.RED_400)
	StrokePainter.stroke_path(target, circle_points(center, radius + REJECT_GROW),
		color, REJECT_WIDTH, true)
	var arm: float = radius * REJECT_SLASH
	StrokePainter.stroke_path(target,
		PackedVector2Array([center + Vector2(-arm, arm), center + Vector2(arm, -arm)]),
		color, REJECT_WIDTH, false)


## 折线逼近的圆。笔只画折线，因此圆也必须是一条折线 —— 这样圆与其它笔画同宽同圆角。
static func circle_points(center: Vector2, radius: float,
		segments: int = CIRCLE_SEGMENTS) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in segments:
		var angle: float = TAU * float(index) / float(segments)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _is_walked(source_id: int, target_id: int, path: Array[int]) -> bool:
	for index: int in maxi(path.size() - 1, 0):
		if path[index] == source_id and path[index + 1] == target_id:
			return true
	return false
