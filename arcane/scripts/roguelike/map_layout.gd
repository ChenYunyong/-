## map_layout.gd
## 职责：路线图屏的几何常量与节点排布算法（唯一落点）。
## 所属系统：roguelike（表现部分）
## 依赖：MapModel（层数 / 列数）、ArcaneTheme（短名字号 —— 基线偏移要按字号算）
## 禁止：本文件不得引用节点 —— 它只有数字，供 map_screen 摆放、map_view 绘制、tests 断言。
##
## 960×540 上的分区（间距取 docs/06 §1 的间距系统 4/8/12/16/24 ×3 = 12/24/36/48/72）：
##   ┌───────────────────────────────────────────────┐ 24
##   │ 羊皮卷 912×420：小标题 · 当前位置 / 路线图 / 图例 │
##   ├───────────────────────────────────────────────┤ 24
##   │ 底部动作条 48：提示文字 · 继续 / 返回编辑器      │
##   └───────────────────────────────────────────────┘ 24
## 上下：24 + 420 + 24 + 48 + 24 = 540 ✓
##
## 羊皮卷**内部**用另一套局部坐标（左上角为原点），下面的 *_RECT 常量都是局部的：
##   12 内边距 → 标题 40 → 12 → 路线图区 316 → 折痕 → 图例 28 → 12 内边距
##   12 + 40 + 12 + 316 + 28 + 12 = 420 ✓
## map_view 与羊皮卷同尺寸同位置，于是它 _draw() 里的坐标就是这套局部坐标 ——
## 测试断言的也就是真机上跑的那组数，而不是照抄一遍公式算出来的「应该」。

class_name MapLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
## 安全边距与分区间距。docs/06 §1 的 8px / 8px（320×180 参考系）×3 = 24。
const MARGIN: float = 24.0
const GAP: float = 24.0
## 羊皮卷的内边距。12 = 间距系统里最小的那一档 4 ×3。
const PADDING: float = 12.0

const PARCHMENT_ORIGIN: Vector2 = Vector2(MARGIN, MARGIN)
const PARCHMENT_SIZE: Vector2 = Vector2(912.0, 420.0)

const TITLE_RECT: Rect2 = Rect2(PADDING, PADDING, 560.0, 40.0)
const STATUS_RECT: Rect2 = Rect2(584.0, PADDING, 316.0, 40.0)
## 路线图区：三层 × 六列排在这里面。
const MAP_RECT: Rect2 = Rect2(PADDING, 64.0, 888.0, 316.0)
## 折痕（羊皮卷的接缝暗示），同时是路线图区与图例的分界。
const LEGEND_SEAM_Y: float = 380.0
const LEGEND_RECT: Rect2 = Rect2(PADDING, LEGEND_SEAM_Y, 888.0, 28.0)

const BOTTOM_ORIGIN: Vector2 = Vector2(MARGIN, 468.0)
const BOTTOM_SIZE: Vector2 = Vector2(912.0, 48.0)
const BOTTOM_HINT_RECT: Rect2 = Rect2(MARGIN, BOTTOM_ORIGIN.y, 648.0, BOTTOM_SIZE.y)

## 节点半径。画出来的圆与**命中区**是同一个圆 —— 看得见多大就点得中多大。
## 40 逻辑像素的直径在 2× 窗口下是 80 设备像素，是 06 §1 那条 44 下限的 1.8 倍，
## 所以不需要再套一圈更大的隐形命中区（那只会让「看着没中却中了」）。
const NODE_RADIUS: float = 20.0
## 节点里的符号半径，以及节点右边短名的位置。
const SYMBOL_RADIUS: float = 11.0
const NODE_LABEL_GAP: float = 8.0
## 文字基线相对行中心的偏移。与 CardFace / 旧 map_view 里那一处一致（字号 × 0.35）。
const LABEL_BASELINE_RATIO: float = 0.35

## 路线图区四周的留白：节点不该贴着羊皮卷的边。
const MAP_PADDING: float = 8.0
## 图例：一项一格，格内先一个小节点再一行状态名。
const LEGEND_NODE_RADIUS: float = 7.0
const LEGEND_ITEM_WIDTH: float = 222.0
const LEGEND_NODE_X: float = 10.0
const LEGEND_LABEL_X: float = 24.0


# ------------------------------------------------------------------ 屏上分区

static func parchment() -> Rect2:
	return Rect2(PARCHMENT_ORIGIN, PARCHMENT_SIZE)


static func bottom_bar() -> Rect2:
	return Rect2(BOTTOM_ORIGIN, BOTTOM_SIZE)


## 羊皮卷上的标题（屏坐标）。之所以不直接摆局部矩形：Label 要挂在屏上，不是挂在卷上。
static func title_rect() -> Rect2:
	return Rect2(PARCHMENT_ORIGIN + TITLE_RECT.position, TITLE_RECT.size)


static func status_rect() -> Rect2:
	return Rect2(PARCHMENT_ORIGIN + STATUS_RECT.position, STATUS_RECT.size)


static func bottom_hint_rect() -> Rect2:
	return BOTTOM_HINT_RECT


# ------------------------------------------------------------------ 节点排布

## 相邻两层的纵向节拍。由「路线图区高度 − 上下留白 − 一个节点直径」除以层间隔数得出 ——
## 于是最上面一层与最下面一层恰好各留出 MAP_PADDING 的余量，不用另写两行来对齐。
static func tier_pitch() -> float:
	return (MAP_RECT.size.y - MAP_PADDING * 2.0 - NODE_RADIUS * 2.0) / float(MapModel.TIERS - 1)


## 相邻两列的横向节拍。
static func column_pitch() -> float:
	return MAP_RECT.size.x / float(MapModel.COLUMNS)


## 第 tier 层第 column 列节点的中心。**第 0 层在最下面**（从下往上走）。
static func node_position(tier: int, column: int) -> Vector2:
	return Vector2(
		MAP_RECT.position.x + (float(column) + 0.5) * column_pitch(),
		MAP_RECT.end.y - MAP_PADDING - NODE_RADIUS - float(tier) * tier_pitch()
	)


## 节点右边那行短名的基线起点。文字画在纸面上，故纵向按行中心对齐而非按节点中心。
static func node_label_baseline(tier: int, column: int) -> Vector2:
	var center: Vector2 = node_position(tier, column)
	return Vector2(center.x + NODE_RADIUS + NODE_LABEL_GAP,
		center.y + float(ArcaneTheme.PARAM_FONT_SIZE) * LABEL_BASELINE_RATIO)


## 图例第 index 项的小节点中心。
static func legend_node_position(index: int) -> Vector2:
	return Vector2(LEGEND_RECT.position.x + float(index) * LEGEND_ITEM_WIDTH + LEGEND_NODE_X,
		LEGEND_RECT.position.y + LEGEND_RECT.size.y * 0.5)


static func legend_label_baseline(index: int) -> Vector2:
	var center: Vector2 = legend_node_position(index)
	return Vector2(LEGEND_RECT.position.x + float(index) * LEGEND_ITEM_WIDTH + LEGEND_LABEL_X,
		center.y + float(ArcaneTheme.PARAM_FONT_SIZE) * LABEL_BASELINE_RATIO)
