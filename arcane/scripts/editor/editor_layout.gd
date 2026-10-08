## editor_layout.gd
## 职责：模块编辑器屏的几何常量与排布算法（唯一落点）—— docs/14 §2.1 的逐条落地。
## 所属系统：editor
## 依赖：CanvasItem 无关，只有数字；供 editor_screen.gd 摆放控件、供 tests 断言。
## 禁止：本文件不得引用节点、不得出现裸色值 —— 颜色归 Palette / Theme。
##
## 960×540 上的分区（**逐条照抄 docs/14 §2.1 的「rect @960」列**，不另行换算）：
##   ┌───────────────────────────────────────────────┐ 16
##   │ 头栏 40：标题 · 计数 · 撤销/删除/路线图(40×32) │
##   ├───────────────────────────────────────────────┤  8
##   │ 书本 928×360：8px 暖色边带 + 净纸 896×328     │
##   ├───────────────────────────────────────────────┤ 12
##   │ 书槽 928×88：箭头 · 卡位 672×72 · 唯一金底 CTA │
##   └───────────────────────────────────────────────┘ 16
## 上下：16 + 40 + 8 + 360 + 12 + 88 + 16 = 540 ✓
## 左右：16 + 928 + 16 = 960 ✓
##
## 契约把顶栏压到 40 高（旧版 72）、书本撑到整宽 928×360（旧版 672×276）、详情从常驻侧栏
## 改成**按需浮层**。三条改动合起来才够着 §4 的 E01：书本 67.538%、净纸 59.413%；
## E03：内容顶端 16 + 头栏 40 + 书顶 64，书本上方总预算正好 64。

class_name EditorLayout
extends RefCounted

## 画布逻辑尺寸（= project.godot 的 viewport 尺寸；改这里等于改基准分辨率，须同步）。
const SCREEN: Vector2 = Vector2(960.0, 540.0)
## 下面的 rect 一律**逐字**照抄 docs/14 §2.1 的「rect @960」列（含 16 的默认内容边距），
## 不做二次推导 —— 复核的人拿这张表逐行对数字，比追一串算式快得多。
##
## **兼容用**：reward_screen.gd 仍借这一支的 MARGIN 摆它的选项。奖励屏不在契约的四屏之内
## （它不在 PET-93 的顺序里），所以这一个常量维持旧值 24 不动它 —— 编辑器自己一个都不用，
## 它的每个 rect 都直接写死在上面的表里。
const MARGIN: float = 24.0
## §1 的最小安全区。所有可交互包络都不得出这个矩形（G03）。
const SAFE_AREA: Rect2 = Rect2(8.0, 8.0, 944.0, 524.0)
## §1 的间距档位（不再乘旧倍率）。
const SPACING_4: float = 4.0
const SPACING_8: float = 8.0
const SPACING_12: float = 12.0
const SPACING_16: float = 16.0
const SPACING_24: float = 24.0

# ------------------------------------------------------------------ 头栏

## EDITOR_HEADER (16,16,928,40)：无额外面板，R0/S0。
const HEADER: Rect2 = Rect2(16.0, 16.0, 928.0, 40.0)
## EDITOR_TITLE (24,20,232,32) 24/32 —— 屏标题走主题默认字号 24。
const TITLE_RECT: Rect2 = Rect2(24.0, 20.0, 232.0, 32.0)
## EDITOR_COUNTS (272,24,400,24) 16/24 —— 卡数 / 丝线数。
const COUNTS_RECT: Rect2 = Rect2(272.0, 24.0, 400.0, 24.0)
## 头栏图标控件的固定尺寸与图标直径。§2.1 三颗都是 40×32、24 图标、R4/S1、间距 8。
const HEADER_BUTTON_SIZE: Vector2 = Vector2(40.0, 32.0)
const HEADER_ICON_SIZE: float = 24.0
## 最后一颗按钮的右缘到屏幕右边距还差 8（944 − 8 = 936 = 896 + 40）。
const HEADER_BUTTONS_RIGHT: float = 936.0
## 头栏按钮的文案 key，**从右往左**：index 0 最靠右（UNDO 800 / DELETE 848 / OPEN_MAP 896）。
const TOP_BUTTONS: PackedStringArray = ["路线图", "删除", "撤销"]

## 头栏按钮的矩形，顺序与 TOP_BUTTONS 一致。
##
## 这是头栏按钮几何的**唯一算法**：editor_screen 用它摆放，test_layout 用它断言 ——
## 测试断言的因此正是真机上跑的那组坐标，而不是照抄一遍公式算出来的「应该」。
static func top_button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var cursor: float = HEADER_BUTTONS_RIGHT
	var y: float = HEADER.position.y + (HEADER.size.y - HEADER_BUTTON_SIZE.y) * 0.5
	for _key: String in TOP_BUTTONS:
		rects.append(Rect2(cursor - HEADER_BUTTON_SIZE.x, y,
			HEADER_BUTTON_SIZE.x, HEADER_BUTTON_SIZE.y))
		cursor -= HEADER_BUTTON_SIZE.x + SPACING_8
	return rects


static func top_bar() -> Rect2:
	return HEADER


# ------------------------------------------------------------------ 书本

## EDITOR_BOOK (16,64,928,360) R4/S1；距头栏 8；8px 暖色边带。
const BOOK: Rect2 = Rect2(16.0, 64.0, 928.0, 360.0)
## EDITOR_PAPER (32,80,896,328) R4/S0 —— 书本内缩 16。E01 量的「净纸」就是它。
const PAPER: Rect2 = Rect2(32.0, 80.0, 896.0, 328.0)
## EDITOR_SPINE (472,80,16,328) 书脊中带，纯装饰、不阻断摆牌。
const SPINE: Rect2 = Rect2(472.0, 80.0, 16.0, 328.0)

## 画布控件矩形 = 净纸。画布不留自己的内缩：E05 的「卡距裁切边 ≥16」由
## BoardView.EDGE_PADDING 保证，多扣一层会让净纸面积对不上 §2.1。
const CANVAS_VIEW_ORIGIN: Vector2 = PAPER.position
const CANVAS_VIEW_SIZE: Vector2 = PAPER.size


static func book() -> Rect2:
	return BOOK


static func paper() -> Rect2:
	return PAPER


static func spine() -> Rect2:
	return SPINE


static func canvas_frame() -> Rect2:
	return PAPER


static func canvas_view() -> Rect2:
	return PAPER


# ------------------------------------------------------------------ 详情浮层

## DETAIL_POPOVER (704,80,224,240) R4/S1 —— 选中后按需开，拖动/点空白收起。
## 它压在净纸右上角：E02 的「扣掉 224×240 后仍 ≥48%」量的是这块。
const POPOVER: Rect2 = Rect2(704.0, 80.0, 224.0, 240.0)
## DETAIL_NAME (716,92,176,32) 24/32。左内缩 12、上内缩 12。
const DETAIL_NAME_RECT: Rect2 = Rect2(716.0, 92.0, 176.0, 32.0)
## DETAIL_CLOSE (896,92,24,24) —— 与名字间隔 4（716+176=892 → 896）。
const DETAIL_CLOSE_RECT: Rect2 = Rect2(896.0, 92.0, 24.0, 24.0)
## 下面三行的左缘与宽度：内容区 196 宽，右内缩 16（716+196=912，928−912=16）。
const DETAIL_CONTENT_X: float = 716.0
const DETAIL_CONTENT_WIDTH: float = 196.0
## DETAIL_TYPE (716,132,196,24) 16/24，类型行上间距 8。
const DETAIL_TYPE_RECT: Rect2 = Rect2(716.0, 132.0, 196.0, 24.0)
## DETAIL_STATS (716,164,196,72) 16/24，最多 3 行；上间距 8。
const DETAIL_STATS_RECT: Rect2 = Rect2(716.0, 164.0, 196.0, 72.0)
## DETAIL_NOTE (716,244,196,60) 12/20，最多 3 行；上间距 8。
const DETAIL_NOTE_RECT: Rect2 = Rect2(716.0, 244.0, 196.0, 60.0)


static func popover() -> Rect2:
	return POPOVER


static func detail_name_rect() -> Rect2:
	return DETAIL_NAME_RECT


static func detail_close_rect() -> Rect2:
	return DETAIL_CLOSE_RECT


static func detail_type_rect() -> Rect2:
	return DETAIL_TYPE_RECT


static func detail_stats_rect() -> Rect2:
	return DETAIL_STATS_RECT


static func detail_note_rect() -> Rect2:
	return DETAIL_NOTE_RECT


# ------------------------------------------------------------------ 书槽

## EDITOR_TRAY (16,436,928,88) R4/S1；距书本 12；卡尺寸 72。
const TRAY: Rect2 = Rect2(16.0, 436.0, 928.0, 88.0)
## TRAY_LEFT (24,456,24,48) / TRAY_RIGHT (736,456,24,48)，R4/S1。
const TRAY_ARROW_SIZE: Vector2 = Vector2(24.0, 48.0)
const TRAY_LEFT_RECT: Rect2 = Rect2(24.0, 456.0, 24.0, 48.0)
const TRAY_RIGHT_RECT: Rect2 = Rect2(736.0, 456.0, 24.0, 48.0)
## TRAY_VIEW (52,444,672,72) R0/S0；卡间距 12；滚动节拍 84。
const TRAY_VIEW_RECT: Rect2 = Rect2(52.0, 444.0, 672.0, 72.0)
const TRAY_VIEW_SIZE: Vector2 = TRAY_VIEW_RECT.size
const TRAY_CHIP_SIZE: float = 72.0
const TRAY_CHIP_GAP: float = 12.0
## 一格滚轮 = 一个卡位节拍（卡位 + 间距）。停靠点与卡位对齐，首末两张才都读得全。
const TRAY_SCROLL_STEP: float = TRAY_CHIP_SIZE + TRAY_CHIP_GAP
## 偏移小于这个数就算「到头了」，对应那一端的滚动入口自行隐藏（浮点不能用 == 0）。
const TRAY_EDGE_EPSILON: float = 0.01
## EDITOR_PRIMARY (776,456,152,48) 20/28 R4/S1 —— 全屏唯一的金底主按钮。
const PRIMARY_RECT: Rect2 = Rect2(776.0, 456.0, 152.0, 48.0)
## 唯一主按钮的文案 key。其余头栏键一律是图标控件。
const PRIMARY_KEY: String = "开始战斗"


static func tray() -> Rect2:
	return TRAY


static func tray_view() -> Rect2:
	return TRAY_VIEW_RECT


static func primary_rect() -> Rect2:
	return PRIMARY_RECT


## 滚动入口的矩形。side = -1 是左入口、+1 是右入口。两端各贴住可视区的对应一侧。
static func tray_arrow_rect(side: float) -> Rect2:
	return TRAY_LEFT_RECT if side < 0.0 else TRAY_RIGHT_RECT


# ------------------------------------------------------- 书槽的滚动停靠点

## 两个卡位之间的节拍（卡位 + 间距）。
static func tray_pitch() -> float:
	return TRAY_SCROLL_STEP


static func tray_content_width(count: int) -> float:
	if count <= 0:
		return 0.0
	return float(count) * TRAY_CHIP_SIZE + float(count - 1) * TRAY_CHIP_GAP


## 最大偏移：再往右滚内容就整个出去了。18 卡时 = 1500 − 672 = **828**（§2.1 表列值）。
static func tray_max_offset(count: int) -> float:
	return maxf(0.0, tray_content_width(count) - TRAY_VIEW_SIZE.x)


## 全部停靠点：0、节拍整数倍……，最后一个是**终点**。
##
## 单独列一个终点的理由：只停在节拍整数倍上时，最后一张卡永远差最后几像素看不到。
## 终点让最后一张卡恰好贴住可视区右缘。828 不是 84 的整数倍（84×9=756 < 828 < 840），
## 所以「必须含终点」这条在 §2.1 的 18 卡配置下真的会起作用。
static func tray_stops(count: int) -> PackedFloat32Array:
	var limit: float = tray_max_offset(count)
	var stops: PackedFloat32Array = PackedFloat32Array([0.0])
	var offset: float = tray_pitch()
	while offset < limit:
		stops.append(offset)
		offset += tray_pitch()
	if not is_equal_approx(stops[stops.size() - 1], limit):
		stops.append(limit)
	return stops


## 从当前位置朝 delta 方向走一个停靠点。
static func tray_stop_offset(current: float, delta: float, count: int) -> float:
	var stops: PackedFloat32Array = tray_stops(count)
	if delta > 0.0:
		for stop: float in stops:
			if stop > current + 0.01:
				return stop
		return stops[stops.size() - 1]
	for index: int in range(stops.size() - 1, -1, -1):
		if stops[index] < current - 0.01:
			return stops[index]
	return stops[0]
