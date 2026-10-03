## preparation_layout.gd
## 职责：PREPARATION 五分区布局的数值事实来源 —— 宽屏取 06 §7 对 Reference B 的实测值，
##       窄屏取 06 §7.1 的移动端折叠规则；并提供折叠判定与 CTA 的落位换算。
## 所属系统：ui
## 依赖：无（纯常量 + 纯函数；不碰节点、场景树、Theme、颜色）
## 禁止：本文件不得引用任何节点或场景 —— 它只回答「矩形在哪」，
##       把矩形贴到节点上是 preparation_screen.gd 的事，于是这些数值可以脱离场景树单测；
##       不得写任何字面色值（06 §10.7）—— 本文件根本不碰颜色。

class_name PreparationLayout
extends RefCounted

## 五分区序号。宽窄两套布局都按这个顺序返回矩形，preparation_screen.gd 靠它认领节点
## （节点顺序：RegionLeft / RegionCenter / RegionRight / RegionBottom / RegionAction）。
enum Region { LEFT, CENTER, RIGHT, WAREHOUSE, ACTION }

## 06 §7 实测的五分区矩形（逻辑像素，基准 320×180，见 06 §1）。
## 出处是 Reference B（1672×941 归一到 320×180）的边界检测，不是估的：
##   左栏 x 15–88（宽 73）· 中栏 x 98–226（宽 128）· 右栏 x 226–309（宽 83）
##   底条 y 132–180（高 48）
##   CTA  x 246–310 / y 148–162（≈64×14 的亮色区块，位于右下角）
##
## §7 只实测了各栏的 **x** 区间与底条的 **y** 区间，没给三栏的上边缘（y=8）。
## 这里取 06 §1 安全区的「四周内缩 8px」—— 那是本主题里唯一已冻结的顶部内缩值，
## 比再估一个数有据。该取值已随本批报备。
const LEFT_RECT: Rect2 = Rect2(15.0, 8.0, 73.0, 124.0)
const CENTER_RECT: Rect2 = Rect2(98.0, 8.0, 128.0, 124.0)
const RIGHT_RECT: Rect2 = Rect2(226.0, 8.0, 83.0, 124.0)
const WAREHOUSE_RECT: Rect2 = Rect2(15.0, 132.0, 294.0, 48.0)
const ACTION_RECT: Rect2 = Rect2(246.0, 148.0, 64.0, 14.0)

## 06 §7.1：竖屏 / 窄屏才折叠。判定用可用区的宽高比 —— 宽 < 高 即竖屏；
## 320×180 基准的 1.78 自然落在宽屏一侧。
const NARROW_ASPECT_MAX: float = 1.0
## 06 §7.1：左栏收起为「顶部一条 16px 信息条」。
const INFO_BAR_HEIGHT: float = 16.0
## 06 §7.1：右下 CTA「固定在右下角安全区内，始终可见，尺寸不小于 44×44」。
## §1 的触摸下限是 44 **设备像素**，这里按逻辑像素给足 44 —— 任何 ≥1× 的缩放下都必然 ≥44 设备像素。
const NARROW_ACTION_SIZE: float = 44.0
## 06 §7.1 没给「右栏改成的底部弹层」的高度。取可用高度的 1/3 —— 这一项是视觉数值，
## 已随本批报备待 Codex 裁定；改的话只动这一处。
const NARROW_SHEET_RATIO: float = 1.0 / 3.0
## 06 §1 的安全区。06 §7.1 要求窄屏的 CTA 落在「右下角安全区内」，即按它内缩。
const SAFE_INSET: float = 8.0
## 06 §7.1：「下：节点仓库 | 保留为底部条」—— 窄屏下高度不变，只是改成横向滚动。
const NARROW_WAREHOUSE_HEIGHT: float = 48.0


## 是否采用 06 §7.1 的折叠布局。viewport_size 为可用区尺寸（逻辑像素）。
## 尺寸非法（未入树 / 被折叠）时按宽屏处理：折叠是给窄屏的，不该在拿不到尺寸时随手触发。
static func is_narrow(viewport_size: Vector2) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	return viewport_size.x / viewport_size.y < NARROW_ASPECT_MAX


## 宽屏（06 §7）五个分区的矩形，下标即 Region。
static func wide_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append(LEFT_RECT)
	rects.append(CENTER_RECT)
	rects.append(RIGHT_RECT)
	rects.append(WAREHOUSE_RECT)
	rects.append(ACTION_RECT)
	return rects


## 窄屏（06 §7.1）五个分区的矩形。折叠规则逐条：
##   左栏 → 顶部 16px 信息条（展开态见 narrow_info_rect）
##   中栏 → 吃掉剩下的全部高度，是唯一常驻主区域
##   右栏 → 底部弹层（默认收起，由调用方决定可见性）
##   下条 → 贴底的横向滚动条，高度不变
##   CTA  → 右下角安全区内，44×44
static func narrow_rects(viewport_size: Vector2) -> Array[Rect2]:
	var width: float = viewport_size.x
	var height: float = viewport_size.y
	var warehouse: Rect2 = Rect2(0.0, height - NARROW_WAREHOUSE_HEIGHT, width, NARROW_WAREHOUSE_HEIGHT)
	var sheet_height: float = height * NARROW_SHEET_RATIO
	var sheet: Rect2 = Rect2(0.0, warehouse.position.y - sheet_height, width, sheet_height)
	var center: Rect2 = Rect2(
		SAFE_INSET,
		INFO_BAR_HEIGHT,
		maxf(width - SAFE_INSET * 2.0, 0.0),
		maxf(sheet.position.y - INFO_BAR_HEIGHT, 0.0))
	var action: Rect2 = Rect2(
		width - SAFE_INSET - NARROW_ACTION_SIZE,
		height - SAFE_INSET - NARROW_ACTION_SIZE,
		NARROW_ACTION_SIZE,
		NARROW_ACTION_SIZE)

	var rects: Array[Rect2] = []
	rects.append(Rect2(0.0, 0.0, width, INFO_BAR_HEIGHT))
	rects.append(center)
	rects.append(sheet)
	rects.append(warehouse)
	rects.append(action)
	return rects


## 窄屏下左栏的两个形态。收起态就是 narrow_rects 给的 16px 信息条；
## 展开态是「覆盖层」—— §7.1 没给它的尺寸，这里直接复用 §7 实测的左栏矩形：
## 覆盖层本来就是「把宽屏那块左栏盖在中栏上」，不另估一组数值。
static func narrow_info_rect(viewport_size: Vector2, expanded: bool) -> Rect2:
	if expanded:
		return LEFT_RECT
	return Rect2(0.0, 0.0, viewport_size.x, INFO_BAR_HEIGHT)


## CTA 按钮的落位：宽度与右下角照抄区块，高度向上取到按钮自身的最小高度。
##
## 为什么不能直接用 ACTION_RECT：06 §7 实测的 CTA 区块高 14px，而 06 §1 规定正文字号 ≥ 8px、
## §3 规定按钮内边距 4px —— 一个写着「开始战斗」的按钮最小高度实测是 20px，14px 装不下。
## 折中取「区块的右下角 = 按钮的右下角，高度向上长」：区块右下角这一条实测约束不丢，
## 按钮也不会被引擎的最小尺寸顶出「右下角」这个位置。冲突已随本批报备。
static func action_button_rect(region: Rect2, minimum: Vector2) -> Rect2:
	var height: float = maxf(region.size.y, minimum.y)
	return Rect2(region.position.x, region.end.y - height, region.size.x, height)
