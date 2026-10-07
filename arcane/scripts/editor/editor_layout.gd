## editor_layout.gd
## 职责：模块编辑器屏的几何常量与顶栏排布算法（唯一落点）。
## 所属系统：editor
## 依赖：ArcaneTheme（边框宽度）、UiKit（按钮尺寸估算）
## 禁止：本文件不得引用节点 —— 它只有数字，供 editor_screen.gd 摆放控件、供 tests 断言。
##
## 960×540 画布上的分区（间距取自 docs/06 §1 的间距系统 4/8/12/16/24 ×3 = 12/24/36/48/72）：
##   ┌───────────────────────────────────────────────┐ 24
##   │ 顶栏 72：标题 · 状态 · 撤销/删除 · 路线图/开始战斗 │
##   ├────────────────────────────┬──────────────────┤ 24
##   │ 书页画布 672×276（木框）   │ 卡片详情 216×276 │
##   ├────────────────────────────┴──────────────────┤ 24
##   │ 卡牌仓库 912×96（72px 卡位，横向滚动）         │
##   └───────────────────────────────────────────────┘ 24
## 左右：24 + 672 + 24 + 216 + 24 = 960 ✓
## 上下：24 + 72 + 24 + 276 + 24 + 96 + 24 = 540 ✓
##
## 顶栏的横向预算（左起）：
##   24 边距 → 标题 144 → 12 → 状态 276 →（余量）→ 按钮组靠右贴 936 → 24 边距
## 中英文文案长度差得很远（「开始战斗」= 4 全角字，「BATTLE」= 6 窄字），
## 所以标题 / 状态的宽度按**较长的那个语种**留，按钮宽度则由 UiKit 按当前语言算。
## tests/unit/test_layout.gd 会在两种语言下各断言一次「按钮组不压到状态文字上」。

class_name EditorLayout
extends RefCounted

## 画布逻辑尺寸（= project.godot 的 viewport 尺寸；改这里等于改基准分辨率，须同步）。
const SCREEN: Vector2 = Vector2(960.0, 540.0)
## 安全边距。docs/06 §1 的 8px（320×180 参考系）×3 = 24。
const MARGIN: float = 24.0
## 分区之间的间距。同上 ×3 = 24。
const GAP: float = 24.0

## 顶栏高度。取值下限由按钮决定：按钮高 = 12×2 内边距 + 一行 24px 正文 + 描边 ≈ 54，
## 72 高留出上下各 9px 的呼吸位。顶栏本身不带木框（否则 9px 描边会把按钮挤到放不下）。
const TOP_BAR_HEIGHT: float = 72.0
const CANVAS_WIDTH: float = 672.0
const CANVAS_HEIGHT: float = 276.0
const DETAIL_WIDTH: float = 216.0
## 仓库高度 = 9×2 木框 + 72 卡位 + 6 呼吸位。仓库自绘横向滚动（见 EditorScreen._on_tray_input），
## 不挂 ScrollContainer：Godot 内置滚动条要用默认主题的样式，等于往像素风界面上贴一条系统灰条。
const TRAY_HEIGHT: float = 96.0
## 一格滚轮的横向滚动距离 = **一整张卡**（卡位 + 间距）。
##
## PET-87 §3：原来一步 96 而卡位节拍是 84，滚两下之后就停在第 1.14 张卡上 ——
## 仓库最右边那张「加速」因此永远只能看到一半。改成整张卡的整数倍之后，
## 停靠位置与卡位对齐，第一张与最后一张都能完整读。
const TRAY_SCROLL_STEP: float = TRAY_CHIP_SIZE + TRAY_CHIP_GAP

## 仓库两端的滚动入口宽度（逻辑像素）。24 = 间距系统档位，也是 44 设备像素 ÷ 2 的触控下限。
const TRAY_ARROW_ZONE: float = 24.0
const TRAY_ARROW_HEIGHT: float = 48.0

## 主面板木框描边宽度。取自主题，不另写一份数字 —— 否则改主题时这里会静默脱节。
const FRAME_BORDER: float = ArcaneTheme.FRAME_BORDER_WIDTH
## 仓库卡位尺寸 = 画布卡片 72×72（同一张牌在仓库和画布上一样大，减少一次心理换算）。
const TRAY_CHIP_SIZE: float = 72.0
const TRAY_CHIP_GAP: float = 12.0
## 详情面板内边距。
const DETAIL_PADDING: float = 12.0
## 详情面板标题栏高度（docs/06 §2.2 的面板标题栏 16px ×3 = 48）。
const DETAIL_TITLE_HEIGHT: float = 48.0

## 详情面板的四段行高（PET-87 §3）。名字 / 类型 / 参数 / 警告依次往下排。
##
## 每段 = **该段字号 × 1.25（系统字体的行高比）× 最坏行数**，不是随手给的数：
##   名字 40（30px × 1 行）· 类型 30（24px × 1 行）· 参数 76（20px × 3 行）· 警告 50（20px × 2 行）。
## 参数之所以要三行：`_stats_text()` 每个字段独占一行，一张卡最多三个字段。
## 四段之和必须 ≤ DETAIL_CONTENT_HEIGHT（test_layout 会断言，防止以后加一段就溢出面板）。
const DETAIL_NAME_HEIGHT: float = 40.0
const DETAIL_TYPE_HEIGHT: float = 30.0
const DETAIL_STATS_HEIGHT: float = 76.0
const DETAIL_WARN_HEIGHT: float = 50.0

## 顶栏左半：标题与状态。宽度按较长的语种留（英文 "BLUEPRINT" ≈130、中文 5 字 = 120）。
const TOP_TITLE_RECT: Rect2 = Rect2(MARGIN, MARGIN, 144.0, TOP_BAR_HEIGHT)
## 顶栏中段：卡数 / 丝线数。英文 "%d CARDS · %d LINES" ≈274，比中文的 ≈212 长。
const TOP_STATUS_RECT: Rect2 = Rect2(TOP_TITLE_RECT.end.x + 12.0, MARGIN, 276.0, TOP_BAR_HEIGHT)

## 顶栏按钮的文案 key，**从右往左**（最右永远是主动作「开始战斗」）。
##
## 为什么只有 4 个：960 宽的条里还要放下标题与状态，而英文文案比中文长。
## 「撤销 / 清空 / 删除 / 路线图 / 开始战斗」五个按钮在英文下必然压到状态文字上
## （test_layout 的双语断言会当场抓住）。取舍是去掉「清空」—— 撤销 + 逐张删除
## 已经覆盖了它的用途，而「一键清空整块书页」本来就是玩家最不敢按的那个键。
const TOP_BUTTONS: PackedStringArray = ["开始战斗", "路线图", "删除", "撤销"]

## 顶栏里唯一带文字的**强主动作**。其余键一律是紧凑图标控件（PET-87 §3：
## 四个同级大按钮读不出主次，「开始战斗」必须是顶栏唯一的主按钮）。
const TOP_PRIMARY_KEY: String = "开始战斗"
## 图标控件的边长。与主动作按钮等高（48 = 24 字号 + 12×2 内边距），因此顶栏不会忽高忽低。
const TOP_ICON_BUTTON: float = 48.0

const TOP_BAR_ORIGIN: Vector2 = Vector2(MARGIN, MARGIN)
const CANVAS_ORIGIN: Vector2 = Vector2(MARGIN, MARGIN + TOP_BAR_HEIGHT + GAP)
const DETAIL_ORIGIN: Vector2 = Vector2(MARGIN + CANVAS_WIDTH + GAP, CANVAS_ORIGIN.y)
const TRAY_ORIGIN: Vector2 = Vector2(MARGIN, CANVAS_ORIGIN.y + CANVAS_HEIGHT + GAP)

const TOP_BAR_SIZE: Vector2 = Vector2(SCREEN.x - MARGIN * 2.0, TOP_BAR_HEIGHT)
const CANVAS_SIZE: Vector2 = Vector2(CANVAS_WIDTH, CANVAS_HEIGHT)
const DETAIL_SIZE: Vector2 = Vector2(DETAIL_WIDTH, CANVAS_HEIGHT)
const TRAY_SIZE: Vector2 = Vector2(SCREEN.x - MARGIN * 2.0, TRAY_HEIGHT)

## 画布控件在木框内的实际矩形：木框描边要让出来，否则卡片会被框线压住。
const CANVAS_VIEW_ORIGIN: Vector2 = Vector2(CANVAS_ORIGIN.x + FRAME_BORDER, CANVAS_ORIGIN.y + FRAME_BORDER)
const CANVAS_VIEW_SIZE: Vector2 = Vector2(
	SCREEN.x - MARGIN * 2.0 - FRAME_BORDER * 2.0 - GAP - DETAIL_WIDTH,
	CANVAS_HEIGHT - FRAME_BORDER * 2.0
)

## 详情面板内容区（标题栏之下、木框之内）。
const DETAIL_CONTENT_ORIGIN: Vector2 = Vector2(
	DETAIL_ORIGIN.x + FRAME_BORDER + DETAIL_PADDING,
	DETAIL_ORIGIN.y + FRAME_BORDER + DETAIL_TITLE_HEIGHT + DETAIL_PADDING
)
const DETAIL_CONTENT_WIDTH: float = DETAIL_WIDTH - FRAME_BORDER * 2.0 - DETAIL_PADDING * 2.0
## 详情内容区可用高度：内芯高度 − 标题栏 − 下内边距。
const DETAIL_CONTENT_HEIGHT: float = CANVAS_HEIGHT - FRAME_BORDER * 2.0 - DETAIL_TITLE_HEIGHT - DETAIL_PADDING

## 仓库滚动区（木框之内）。
const TRAY_VIEW_ORIGIN: Vector2 = Vector2(TRAY_ORIGIN.x + FRAME_BORDER, TRAY_ORIGIN.y + FRAME_BORDER)
const TRAY_VIEW_SIZE: Vector2 = Vector2(
	SCREEN.x - MARGIN * 2.0 - FRAME_BORDER * 2.0,
	TRAY_HEIGHT - FRAME_BORDER * 2.0
)


static func top_bar() -> Rect2:
	return Rect2(TOP_BAR_ORIGIN, TOP_BAR_SIZE)


## 顶栏按钮的矩形，顺序与 TOP_BUTTONS 一致。
##
## 这是顶栏按钮几何的**唯一算法**：editor_screen 用它摆放，test_layout 用它断言。
## 测试因此断言的正是真机上跑的那组坐标，而不是照抄一遍公式算出来的「应该」。
static func top_button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var cursor: float = top_bar().end.x
	for key: String in TOP_BUTTONS:
		var size: Vector2 = top_button_size(key)
		var top: float = TOP_BAR_ORIGIN.y + (TOP_BAR_HEIGHT - size.y) * 0.5
		rects.append(Rect2(cursor - size.x, top, size.x, size.y))
		cursor -= size.x + GAP
	return rects


## 单个顶栏控件的尺寸。主动作用**文字宽度**（按当前语言算，切英文不会把字挤出去），
## 其余三个是固定边长的方形图标控件 —— 图标没有文字宽度可言。
static func top_button_size(key: String) -> Vector2:
	if key == TOP_PRIMARY_KEY:
		return Vector2(UiKit.button_width(TranslationServer.translate(key)), UiKit.button_height())
	return Vector2(TOP_ICON_BUTTON, TOP_ICON_BUTTON)


static func canvas_frame() -> Rect2:
	return Rect2(CANVAS_ORIGIN, CANVAS_SIZE)


static func canvas_view() -> Rect2:
	return Rect2(CANVAS_VIEW_ORIGIN, CANVAS_VIEW_SIZE)


static func detail_panel() -> Rect2:
	return Rect2(DETAIL_ORIGIN, DETAIL_SIZE)


## 详情面板的木框之内的深蓝内芯（06 §2.1 的三层结构）。
static func detail_body() -> Rect2:
	return Rect2(Vector2(DETAIL_ORIGIN.x + FRAME_BORDER, DETAIL_ORIGIN.y + FRAME_BORDER),
		Vector2(DETAIL_WIDTH - FRAME_BORDER * 2.0, CANVAS_HEIGHT - FRAME_BORDER * 2.0))


static func detail_title_bar() -> Rect2:
	return Rect2(Vector2(DETAIL_ORIGIN.x + FRAME_BORDER, DETAIL_ORIGIN.y + FRAME_BORDER),
		Vector2(DETAIL_WIDTH - FRAME_BORDER * 2.0, DETAIL_TITLE_HEIGHT))


static func tray() -> Rect2:
	return Rect2(TRAY_ORIGIN, TRAY_SIZE)


static func tray_view() -> Rect2:
	return Rect2(TRAY_VIEW_ORIGIN, TRAY_VIEW_SIZE)


# ------------------------------------------------------- 详情面板的四段行

static func detail_name_rect() -> Rect2:
	return _detail_row(0.0, DETAIL_NAME_HEIGHT)


static func detail_type_rect() -> Rect2:
	return _detail_row(DETAIL_NAME_HEIGHT, DETAIL_TYPE_HEIGHT)


static func detail_stats_rect() -> Rect2:
	return _detail_row(DETAIL_NAME_HEIGHT + DETAIL_TYPE_HEIGHT, DETAIL_STATS_HEIGHT)


static func detail_warn_rect() -> Rect2:
	return _detail_row(DETAIL_NAME_HEIGHT + DETAIL_TYPE_HEIGHT + DETAIL_STATS_HEIGHT, DETAIL_WARN_HEIGHT)


## 详情内容区的第 offset 行。四段的**唯一算法** —— editor 用它摆放，test_layout 用它断言。
static func _detail_row(offset: float, height: float) -> Rect2:
	return Rect2(DETAIL_CONTENT_ORIGIN + Vector2(0.0, offset),
		Vector2(DETAIL_CONTENT_WIDTH, height))


# ------------------------------------------------------- 仓库的滚动停靠点

## 两个卡位之间的节拍（卡位 + 间距）。
static func tray_pitch() -> float:
	return TRAY_CHIP_SIZE + TRAY_CHIP_GAP


static func tray_content_width(count: int) -> float:
	if count <= 0:
		return 0.0
	return float(count) * TRAY_CHIP_SIZE + float(count - 1) * TRAY_CHIP_GAP


## 最大偏移：再往右滚内容就整个出去了。
static func tray_max_offset(count: int) -> float:
	return maxf(0.0, tray_content_width(count) - TRAY_VIEW_SIZE.x)


## 仓库的全部停靠点：0、节拍的整数倍……，最后一个是**终点**。
##
## 为什么要单独列一个终点：若只停在节拍整数倍上，最后一张卡永远差最后几像素看不到
## （PET-87 §3 报的正是「最右边的加速被切掉一半」）。终点让最后一张卡恰好贴住可视区右缘。
static func tray_stops(count: int) -> PackedFloat32Array:
	var limit: float = tray_max_offset(count)
	var stops: PackedFloat32Array = PackedFloat32Array([0.0])
	var pitch: float = tray_pitch()
	var offset: float = pitch
	while offset < limit:
		stops.append(offset)
		offset += pitch
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


## 滚动入口的矩形。side = -1 是左入口、+1 是右入口。
static func tray_arrow_rect(side: float) -> Rect2:
	var view: Rect2 = tray_view()
	var x: float = view.position.x if side < 0.0 else view.end.x - TRAY_ARROW_ZONE
	return Rect2(x, view.position.y + (view.size.y - TRAY_ARROW_HEIGHT) * 0.5,
		TRAY_ARROW_ZONE, TRAY_ARROW_HEIGHT)
