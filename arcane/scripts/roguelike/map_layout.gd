## map_layout.gd
## 职责：路线图屏的几何常量与节点排布算法（唯一落点）—— docs/14 §2.2 的逐条落地。
## 所属系统：roguelike（表现部分）
## 依赖：MapModel（层数 / 列数）。只有数字：供 map_screen 摆放控件、map_view 绘制、tests 断言。
## 禁止：本文件不得引用节点 / 场景 / 颜色 —— 颜色归 Palette / Theme。
##
## 960×540 上的分区（**逐字**照抄 docs/14 §2.2 的「rect @960」列，不做二次推导）：
##   ┌───────────────────────────────────────────────┐ 16
##   │ 头栏 40：标题 · 当前位置（右对齐）              │
##   ├───────────────────────────────────────────────┤  8
##   │ 羊皮卷 928×392：8px 暖色边带 + 内容内缩 16      │
##   │   路线图区 896×316 → 12 → 图例 896×24          │
##   ├───────────────────────────────────────────────┤ 12
##   │ 动作条 56：提示 · 返回编辑器 · 继续             │
##   └───────────────────────────────────────────────┘ 16
## 上下：16 + 40 + 8 + 392 + 12 + 56 + 16 = 540 ✓
## 左右：16 + 928 + 16 = 960 ✓
##
## 纸内的纵向账（契约给的是绝对坐标，这里把它们的来路写清楚，复核时逐行对得上）：
##   纸顶 64 →（上留 24）→ 图区 88..404 →（间距 12）→ 图例 416..440 →（下留 16）→ 纸底 456
##   24 + 316 + 12 + 24 + 16 = 392 ✓
##
## **坐标系**：下面的 rect 常量一律是**屏坐标**（左上原点、右下半开区间，与契约表一致）。
## 只有节点与图例的落点是**纸内局部坐标** —— MapView 与羊皮卷同位置同尺寸，于是它 _draw() 里
## 直接可用；要换回屏坐标走 to_screen()。这样测试断言的与真机画的仍是同一组数。

class_name MapLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
## §1 的最小安全区。所有可交互包络都不得出这个矩形（G03）。
const SAFE_AREA: Rect2 = Rect2(8.0, 8.0, 944.0, 524.0)
## §1 的间距档位（不再乘旧倍率）。本屏用到的只有 8 / 12 / 16，另一处 24 是纸内上留白。
const SPACING_8: float = 8.0
const SPACING_12: float = 12.0
const SPACING_16: float = 16.0

# ------------------------------------------------------------------ 屏上分区

## MAP_HEADER (16,16,928,40) R0/S0。
const HEADER: Rect2 = Rect2(16.0, 16.0, 928.0, 40.0)
## MAP_TITLE (24,20,400,32) 24/32 —— 屏标题走契约的 24 档墨字。
const TITLE_RECT: Rect2 = Rect2(24.0, 20.0, 400.0, 32.0)
## MAP_STATUS (520,24,408,24) 16/24，右对齐。
const STATUS_RECT: Rect2 = Rect2(520.0, 24.0, 408.0, 24.0)
## MAP_PAPER (16,64,928,392) R4/S1；边带 8，内部留白 16。M01 量的就是它。
const PAPER: Rect2 = Rect2(16.0, 64.0, 928.0, 392.0)
## MAP_GRAPH (32,88,896,316) —— 3 列 6 层排在这里面。
const GRAPH: Rect2 = Rect2(32.0, 88.0, 896.0, 316.0)
## MAP_LEGEND (32,416,896,24) 12/20；距 graph 12。
const LEGEND: Rect2 = Rect2(32.0, 416.0, 896.0, 24.0)
## MAP_ACTIONS (16,468,928,56)；距纸 12。
const ACTIONS: Rect2 = Rect2(16.0, 468.0, 928.0, 56.0)
## MAP_HINT (24,480,596,24) 16/24。它落在暗背景上，故走暗底副墨那一支。
const HINT_RECT: Rect2 = Rect2(24.0, 480.0, 596.0, 24.0)
## MAP_BACK (644,472,140,48) 16/24 R4/S1；中文 / 英文都要一行放得下。
const BACK_RECT: Rect2 = Rect2(644.0, 472.0, 140.0, 48.0)
## MAP_PRIMARY (800,472,144,48) 20/28 R4/S1；与 BACK 间距 16（644 + 140 + 16 = 800）。
const PRIMARY_RECT: Rect2 = Rect2(800.0, 472.0, 144.0, 48.0)

## §1：纸框材质边带 / 内容内缩。边带由 Theme 的 PageBand 画，内容内缩由下面的 rect 保证。
const PAPER_BAND: float = 8.0
const PAPER_INSET: float = 16.0

# ------------------------------------------------------------------ 节点

## 节点半径。画出来的圆与**命中区**是同一个圆 —— 看得见多大就点得中多大（§2.2 直径 40）。
const NODE_RADIUS: float = 20.0
## 符号框 24×24、线宽 2（§2.2 重复元素表）—— 半径就是半个框。
const SYMBOL_RADIUS: float = 12.0
## 相邻两列 / 两层的节拍。列跨度 280 是**图布局参数**，不是 UI 间距档位（§2.2 原话）。
const COLUMN_PITCH: float = 280.0
const TIER_PITCH: float = 52.0
## 第 0 层第 0 列的中心（**屏坐标**）。契约：x = 200 + 280c、y = 384 − 52t。
const NODE_ORIGIN: Vector2 = Vector2(200.0, 384.0)
## 短名框：rect(center.x + 28, center.y − 12, 96, 24)，字 16。
const LABEL_GAP: float = 28.0
const LABEL_SIZE: Vector2 = Vector2(96.0, 24.0)
const LABEL_FONT_SIZE: int = 16
## 文字基线相对行心的偏移（字号 × 0.35 —— 与 CardFace / 旧 map_view 同一处口径）。
const LABEL_BASELINE_RATIO: float = 0.35

## 图例：4 项 × 224×24，圆直径 12、文字距圆 8（6 + 6 + 8 = 20）。
const LEGEND_ITEM_WIDTH: float = 224.0
const LEGEND_NODE_RADIUS: float = 6.0
const LEGEND_NODE_X: float = 6.0
const LEGEND_LABEL_X: float = 20.0
const LEGEND_FONT_SIZE: int = 12

## 地图装饰的保护区（§4 M04）：节点圆外扩 8、短名框外扩 4。
const DECOR_NODE_CLEARANCE: float = 8.0
const DECOR_LABEL_CLEARANCE: float = 4.0


# ------------------------------------------------------------------ 纸内坐标

## 纸内局部坐标 → 屏坐标。MapView 就摆在 PAPER 上，两者只差这一个平移。
static func to_screen(local: Vector2) -> Vector2:
	return local + PAPER.position


static func to_local(on_screen: Vector2) -> Vector2:
	return on_screen - PAPER.position


# ------------------------------------------------------------------ 节点排布

## 第 tier 层第 column 列节点的中心（**纸内局部坐标**）。第 0 层在**下**（从下往上走）。
static func node_position(tier: int, column: int) -> Vector2:
	return to_local(NODE_ORIGIN + Vector2(COLUMN_PITCH * float(column), -TIER_PITCH * float(tier)))


## 节点右边那行短名的**矩形**（纸内局部坐标）。
static func node_label_rect(tier: int, column: int) -> Rect2:
	var center: Vector2 = node_position(tier, column)
	return Rect2(center.x + LABEL_GAP, center.y - LABEL_SIZE.y * 0.5, LABEL_SIZE.x, LABEL_SIZE.y)


## 短名的基线起点。draw_string 要的是基线，不是行框左上角。
static func node_label_baseline(tier: int, column: int) -> Vector2:
	var center: Vector2 = node_position(tier, column)
	return Vector2(center.x + LABEL_GAP,
		center.y + float(LABEL_FONT_SIZE) * LABEL_BASELINE_RATIO)


## 相邻两层的纵向节拍（52）。行间净空 = 节拍 − 一个节点直径 = 12（§4 M03）。
static func tier_pitch() -> float:
	return TIER_PITCH


## 相邻两列的横向节拍（280）。
static func column_pitch() -> float:
	return COLUMN_PITCH


## 图例第 index 项的小节点中心（**纸内局部坐标**）。
static func legend_node_position(index: int) -> Vector2:
	return to_local(Vector2(LEGEND.position.x + LEGEND_ITEM_WIDTH * float(index) + LEGEND_NODE_X,
		LEGEND.position.y + LEGEND.size.y * 0.5))


static func legend_label_baseline(index: int) -> Vector2:
	return to_local(Vector2(LEGEND.position.x + LEGEND_ITEM_WIDTH * float(index) + LEGEND_LABEL_X,
		LEGEND.position.y + LEGEND.size.y * 0.5
			+ float(LEGEND_FONT_SIZE) * LABEL_BASELINE_RATIO))


## 地图装饰的保护区（纸内局部坐标）：每个节点的圆外扩 8 的**外接方框** + 每个短名框外扩 4。
##
## 用外接方框而不是圆：判据由「不进圆」收紧成「不进方框」，对装饰只会更保守 ——
## 而 M04 要的正是「装饰让路」，宁可多让一点。
static func protected_rects() -> Array[Rect2]:
	var zones: Array[Rect2] = []
	var grown: float = NODE_RADIUS + DECOR_NODE_CLEARANCE
	for tier: int in MapModel.TIERS:
		for column: int in MapModel.COLUMNS:
			var center: Vector2 = node_position(tier, column)
			zones.append(Rect2(center - Vector2(grown, grown), Vector2(grown, grown) * 2.0))
			zones.append(node_label_rect(tier, column).grow(DECOR_LABEL_CLEARANCE))
	return zones
