## map_node_painter.gd
## 职责：路线图上节点的**四种状态**与边线的**三种样式**的画法 —— 已访问 / 当前 / 可选 / 不可达。
## 所属系统：roguelike（绘制辅助）
## 依赖：Palette（Token）、MapSymbolPainter（形状标记的几何）、StrokePainter（唯一的笔）
## 禁止：本文件不得出现裸色值；不得引用节点 / 场景 / 字体 —— 颜色、坐标、文字全由调用方传进来。
##
## 06 §11：状态不能只靠明度区分。四种状态各自由**六个维度**描述 ——
##   填充 / 是否空心 / 外圈色 / 外圈外扩 / 符号墨色 / 形状标记。
## 任意两个状态至少在其中两个维度上不同，这是算术不是目视结论，test_map_paint 会逐对量一遍。
##
## 关键的一对是「已访问 / 当前」：两者填充只差 45（0-255 的 RGB 距离，远低于本工程判「塌成一家」
## 的 96 那一档），光靠颜色根本分不开 —— 正是这一对逼出了外圈、外扩与形状标记这三个维度
## （棕底金圈 vs 暗底金圈，且当前节点是唯一的定位三角）。
##
## 六维里的取色**逐字**来自 docs/14 §3 的四行「地图未到达 / 地图可选 / 地图当前 / 地图已走」，
## 换配色就是改下面那四张表，画法里没有任何一处自己挑颜色。

class_name MapNodePainter
extends RefCounted

enum State { UNREACHABLE, SELECTABLE, VISITED, CURRENT }

## 当前圈的外扩量。§2.2 给的「外扩 4」—— 与 §1.1 的 Selected（卡身外扩 5）是同一个做法。
## 先声明它，因为下面 STATE_RING_GROW 那张表里要用。
const RING_GROW: float = 4.0

## 六个维度各一行，下标即 State。改状态外观只改这里，画法那边不再做任何判断。
##
## 不可达那一格填的是**纸色**：它根本不填，纸面直接透出来（由 STATE_HOLLOW 说了算）。
## 写纸色而不是写个哨兵，是为了让「它离纸面多远」这句话可以被直接量出来 —— 答案是 0，
## 因为它压根不靠填充说话（它说话的是那圈 BROWN_300 环与一把锁）。
const STATE_FILL: Array[Palette.Key] = [Palette.Key.GOLD_200,
	Palette.Key.GOLD_500, Palette.Key.BROWN_700, Palette.Key.NAVY_800]
## 空心 / 实心。这是**结构**差异，比换一个相近的纸色分得开得多。
const STATE_HOLLOW: Array[bool] = [true, false, false, false]
## 边。**已走那一格填的是它自己的底色** —— §2.2 与 §3 都没有给已走配边：
## 前一行的原话是「已走=棕底/勾」，§3 那一行也只点了 BROWN_700（填）与 GOLD_200（勾/墨）。
## 边色与底色相同 = 那道 1px 画上去也看不见，等于没有边，而不是「拿纸色在棕盘上箍一圈」——
## 后者会把看得见的棕盘啃掉 1px（Ø40 量成 Ø38），而 M03 要的正是「可见圆直径 40」。
const STATE_RING: Array[Palette.Key] = [Palette.Key.BROWN_300,
	Palette.Key.BROWN_700, Palette.Key.BROWN_700, Palette.Key.GOLD_500]
## §2.2 的重复元素表：普通节点外圈**宽 1**；当前圈**宽 3、外扩 4**（其下暗底宽 5）。
const STATE_RING_WIDTH: Array[float] = [1.0, 1.0, 1.0, 3.0]
const STATE_RING_GROW: Array[float] = [0.0, 0.0, 0.0, RING_GROW]
const STATE_INK: Array[Palette.Key] = [Palette.Key.BROWN_700,
	Palette.Key.BROWN_700, Palette.Key.GOLD_200, Palette.Key.BLUE_100]
## 形状标记（§2.2 四态那一行：不可达=锁 / 可选=类型符号 / 已走=勾 / 当前=定位三角）。
## 这是 M02「各态同时有形状标记与填/边区别」里**形状**那一半。
const STATE_MARK: Array[MapSymbolPainter.Mark] = [MapSymbolPainter.Mark.LOCK,
	MapSymbolPainter.Mark.KIND, MapSymbolPainter.Mark.CHECK, MapSymbolPainter.Mark.LOCATOR]

## 当前圈下面垫的那道暗底。**它存在的理由是 §3.2**：GOLD_500 贴纸面只有 1.218:1，
## 单靠那圈金色在亮纸上等于没有边界，垫一层 NAVY_600（对纸面 8.007:1）才读得出来。
const UNDER_RING: Palette.Key = Palette.Key.NAVY_600
const UNDER_RING_WIDTH: float = 5.0

## 圆用多少段折线逼近。笔只画折线（draw_arc 是另一套端点口径，不在这里混用）。
const CIRCLE_SEGMENTS: int = 32

## 纸面上的文字（节点短名 / 图例标签）用这一支墨色，与状态无关 —— 文字是给人读的，
## 不参与状态编码。10.95:1，稳稳过 06 §11 的 4.5:1。
const INK_ON_PAPER: Palette.Key = Palette.Key.BROWN_700

## 边线的三种样式：还走不到 / 可以走 / 已经走过。**靠线型分开**，不靠颜色深浅 ——
## §3 给的三支里有两支同色（可选与走过都是 BROWN_700），能分开它们的只有线型。
enum EdgeStyle { DORMANT, OPEN, WALKED }
const EDGE_TOKEN: Array[Palette.Key] = [Palette.Key.BROWN_300,
	Palette.Key.BROWN_700, Palette.Key.BROWN_700]
## §2.2：其余虚线 1（4/4）/ 可达虚线 2（8/4）/ 走过实线 2 + 8 长箭头。
const EDGE_WIDTH: Array[float] = [1.0, 2.0, 2.0]
const EDGE_DASH: Array[float] = [4.0, 8.0, 0.0]
const EDGE_GAP: Array[float] = [4.0, 4.0, 0.0]
## 走过路线的箭头：杆长 8，两撇各偏 0.5 rad。
const ARROW_LENGTH: float = 8.0
const ARROW_SPREAD: float = 0.5
## 「擦着过」的长度容差。折线避让之后线正好切在短名框的角上 —— 那一刻的交集长度是 0，
## 而 M03 判的是交集**面积** ≈ 0，擦角不算违规，所以这里也认它。
const GRAZE_EPSILON: float = 0.5

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


## 一个状态的六个可区分维度，值已经解析成**此刻真正画上去的样子**（颜色是 Color，
## 形状标记是 Mark 枚举）。测试拿它逐对比较 —— 维度里既有颜色也有结构，
## 所以「哪两个状态太像」这件事是可以被算出来的，而不是靠再看一眼。
static func dimensions(state: State) -> Dictionary:
	return {
		"fill": fill_color(state),
		"hollow": STATE_HOLLOW[state],
		"ring": ring_color(state),
		"ring_grow": STATE_RING_GROW[state],
		"ink": ink(state),
		"mark": STATE_MARK[state],
	}


## 符号画在节点里的墨色。空心状态下它落在纸面上，那时它是「还没点亮」的墨字。
static func ink(state: State) -> Color:
	return Palette.get_color(STATE_INK[state])


## 某状态的外圈色。空心 / 实心之外的第二个维度就是它。
static func ring_color(state: State) -> Color:
	return Palette.get_color(STATE_RING[state])


## 某状态的填充色。空心状态返回的是纸色 —— 调用方按 STATE_HOLLOW 决定要不要真的填。
static func fill_color(state: State) -> Color:
	return Palette.get_color(STATE_FILL[state])


## 这个状态的外圈要不要垫暗底。只有**当前**要，理由见 UNDER_RING。
static func needs_dark_backing(state: State) -> bool:
	return state == State.CURRENT


# ------------------------------------------------------------------ 画法

## 外圈画在**哪条路径**上：传进来的是外缘半径，线心要内缩半个环宽。
##
## §2.2 把「可见圆直径 40」与「环宽 1」分开写，而 M03 要的是「可见圆 = 命中圆 = Ø40」。
## 线心直接摆在外缘上的话，1 宽的环会把看得见的轮廓撑到 Ø41（再算抗锯齿就量到 42），
## 命中圆却仍然是 Ø40 —— 于是 M03 那条等式当场差 1，而契约里 52 − 40 = 12 的净空账
## 也是按 Ø40 算的。让外缘停在契约给的那个圆上，这两种量法才是同一个数。
static func ring_path(outer: float, state: State) -> float:
	return outer - STATE_RING_WIDTH[state] * 0.5


## 画一个节点：暗底轮廓（仅当前）→ 填充（空心则跳过）→ 外圈。三个元素，顺序固定。
## 形状标记不在这里 —— 它由调用方经 MapSymbolPainter.paint_mark 落笔，
## 因为「用哪个标记」是 STATE_MARK 那张表的事，与圆的画法无关。
##
## 暗底与金环**同心**（走同一条路径），所以暗底只在金环内外各露出一点边 —— 那点边就是它存在的
## 全部理由（§3.2：金环贴纸面只有 1.218:1）。它比金环宽，于是外缘多出 1px，内缘正好接到填充边。
static func paint_node(target: CanvasItem, center: Vector2, radius: float, state: State) -> void:
	var ring: float = ring_path(radius + STATE_RING_GROW[state], state)
	if needs_dark_backing(state):
		StrokePainter.stroke_path(target, circle_points(center, ring),
			Palette.get_color(UNDER_RING), UNDER_RING_WIDTH, true)
	if not STATE_HOLLOW[state]:
		target.draw_circle(center, radius, fill_color(state))
	StrokePainter.stroke_path(target, circle_points(center, ring),
		ring_color(state), STATE_RING_WIDTH[state], true)


## 图例用的小色样：只画填充与外圈，**不画形状标记**。
##
## §2.2 给图例的圆是 Ø12（半径 6）—— 24×24 的标记放不进去，硬塞会糊成一团。
## 于是图例承担「填 / 边」那一半编码，另一半（形状标记）由图例右边那行**状态名**承担：
## 名字是逐字读的，比 12px 里一个小图形可靠得多。§2.2 的图例行也只规定了圆与文字。
static func paint_swatch(target: CanvasItem, center: Vector2, radius: float, state: State) -> void:
	# 色样不吃 STATE_RING_GROW：§2.2 给图例的圆是 Ø12，当前那一项也得是 Ø12，
	# 否则四个色样大小不一，图例本身就先乱了自己的编码。
	var ring: float = ring_path(radius, state)
	if not STATE_HOLLOW[state]:
		target.draw_circle(center, radius, fill_color(state))
	if needs_dark_backing(state):
		StrokePainter.stroke_path(target, circle_points(center, ring),
			Palette.get_color(UNDER_RING), UNDER_RING_WIDTH, true)
	StrokePainter.stroke_path(target, circle_points(center, ring),
		ring_color(state), STATE_RING_WIDTH[state], true)


## 一条边的样式。path 是走过的节点序列（MapModel.path()），current 是当前节点 id。
static func edge_style(source_id: int, target_id: int, path: Array[int], current: int) -> EdgeStyle:
	if _is_walked(source_id, target_id, path):
		return EdgeStyle.WALKED
	return EdgeStyle.OPEN if source_id == current else EdgeStyle.DORMANT


## 一条边的折线（**纸内局部坐标**）。§2.2：端点裁到**圆边**，且不穿过节点短名；
## 让不开时可作不超过 24px 的折线避让 —— 这里的避让偏差实测 6.69px（test_map_route 量这个数）。
##
## 只有两种情形会被短名框挡住，因为短名框一律长在节点**右边**：往右上走会穿过自己那行短名的
## 左半段，往左上走会穿过**目标**那行短名的左半段。两种都靠**切左缘的角**让开 ——
## 往右上贴着框的上沿擦过去（切左上角），往左上贴着下沿擦过去（切左下角）。
static func edge_points(source: Vector2, target: Vector2, radius: float,
		source_label: Rect2, target_label: Rect2) -> PackedVector2Array:
	var span: Vector2 = target - source
	var length: float = span.length()
	if length <= radius * 2.0:
		return PackedVector2Array()
	var direction: Vector2 = span / length
	var start: Vector2 = source + direction * radius
	var finish: Vector2 = target - direction * radius
	var rightward: bool = span.x > 0.0
	var label: Rect2 = source_label if rightward else target_label
	if _overlap_length(start, finish, label) <= GRAZE_EPSILON:
		return PackedVector2Array([start, finish])
	var corner: Vector2 = Vector2(label.position.x,
		label.position.y if rightward else label.end.y)
	return PackedVector2Array([start, corner, finish])


static func paint_edge(target: CanvasItem, points: PackedVector2Array, style: EdgeStyle) -> void:
	if points.size() < 2:
		return
	var color: Color = Palette.get_color(EDGE_TOKEN[style])
	var width: float = EDGE_WIDTH[style]
	if style == EdgeStyle.WALKED:
		StrokePainter.stroke_path(target, points, color, width, false)
		_paint_arrow(target, points[points.size() - 1], points[points.size() - 2], color, width)
		return
	for piece: PackedVector2Array in StrokePainter.dashed(points, EDGE_DASH[style], EDGE_GAP[style]):
		StrokePainter.stroke_path(target, piece, color, width, false)


## 箭头。画在**终点**那一侧，于是它指着前进方向。
static func _paint_arrow(target: CanvasItem, tip: Vector2, tail: Vector2, color: Color,
		width: float) -> void:
	var back: Vector2 = (tail - tip).normalized() * ARROW_LENGTH
	for side: float in [ARROW_SPREAD, -ARROW_SPREAD]:
		StrokePainter.stroke_path(target, PackedVector2Array([tip, tip + back.rotated(side)]),
			color, width, false)


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


## 线段落在矩形里的**长度**。Liang–Barsky 裁剪：返回的不是「碰没碰到」而是「压了多长」，
## 于是擦着角过（长度恰好 0）与真的穿过去可以被分开 —— 后者才需要避让。
static func _overlap_length(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var span: Vector2 = to - from
	var enter: float = 0.0
	var exit: float = 1.0
	for axis: int in 2:
		var origin: float = from[axis]
		var delta: float = span[axis]
		var low: float = rect.position[axis]
		var high: float = rect.end[axis]
		if is_zero_approx(delta):
			if origin < low or origin > high:
				return 0.0
			continue
		var first: float = (low - origin) / delta
		var second: float = (high - origin) / delta
		enter = maxf(enter, minf(first, second))
		exit = minf(exit, maxf(first, second))
		if enter >= exit:
			return 0.0
	return (exit - enter) * span.length()


static func _is_walked(source_id: int, target_id: int, path: Array[int]) -> bool:
	for index: int in maxi(path.size() - 1, 0):
		if path[index] == source_id and path[index + 1] == target_id:
			return true
	return false
