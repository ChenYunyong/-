## combat_layout.gd
## 职责：COMBAT 两块区域布局的数值事实来源 —— 战场主区与底部状态带取 06 §8 对 Reference C 的实测值，
##       并提供窄屏折叠下的收缩规则。
## 所属系统：ui
## 依赖：无（纯常量 + 纯函数；不碰节点、场景树、Theme、颜色）
## 禁止：本文件不得引用任何节点或场景 —— 它只回答「矩形在哪」，
##       把矩形贴到节点上是 combat_screen.gd 的事，于是这些数值可以脱离场景树单测；
##       不得写任何字面色值（06 §10.7）—— 本文件根本不碰颜色。

class_name CombatLayout
extends RefCounted

## 两块区域序号。宽窄两套布局都按这个顺序返回矩形，combat_screen.gd 靠它认领节点
## （节点顺序：Battlefield / StatusBar）。
enum Region { BATTLEFIELD, STATUS_BAR }

## 06 §8 对 Reference C（1672×941 归一到 320×180）的实测值，不是估的：
##   战场主区 y ≈ 0%–75% → y 0–135
##   底部深色条 y ≈ 75%–100% → y 135–180，高 ≈45px（占画面高约 25%），横贯全宽
## 两块都从 x=0 起、满宽 320 —— §8 明写那条带「横贯全宽」。
const BATTLEFIELD_RECT: Rect2 = Rect2(0.0, 0.0, 320.0, 135.0)
const STATUS_BAR_RECT: Rect2 = Rect2(0.0, 135.0, 320.0, 45.0)

## 06 §8 实测的状态带高度。窄屏下**不**随视口长高 —— HUD 条是固定高的一条，不是按比例拉伸的。
const STATUS_BAR_HEIGHT: float = 45.0
## 06 §8：状态带占画面高约 25%（实测 45 / 180）。窄屏下它是这个份额的**上限**，见 narrow_rects。
const STATUS_BAR_SHARE: float = 0.25

## 06 §7.1：竖屏 / 窄屏才折叠。判定用可用区的宽高比 —— 宽 < 高 即竖屏；
## 320×180 基准的 1.78 自然落在宽屏一侧。
const NARROW_ASPECT_MAX: float = 1.0


## 是否采用 06 §7.1 的折叠布局。viewport_size 为可用区尺寸（逻辑像素）。
## 尺寸非法（未入树 / 被折叠）时按宽屏处理：折叠是给窄屏的，不该在拿不到尺寸时随手触发。
static func is_narrow(viewport_size: Vector2) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	return viewport_size.x / viewport_size.y < NARROW_ASPECT_MAX


## 宽屏（06 §8）两块区域的矩形，下标即 Region。
static func wide_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	rects.append(BATTLEFIELD_RECT)
	rects.append(STATUS_BAR_RECT)
	return rects


## 窄屏（06 §7.1）两块区域的矩形。COMBAT 只有「主区域」与「底部条」两类，§7.1 对它们的要求逐条落在这里：
##   战场   → 始终保留为唯一常驻主区域，吃掉状态带以上的全部高度
##   状态带 → 保留为底部条，高度不随视口长高（§7.1 那条「改为横向滚动」说的是带**内**的读数排布，
##            由 combat_screen.gd 的 ScrollContainer 承担，不是把整条带拉高）
##
## 高度上限取 §8 实测的 25%：§7.1 末条要求折叠「不改变任何玩法规则与状态流」，
## 而状态带在比基准更矮的视口上若仍占满 45px，就会吃掉战场可读性 ——
## 那正是验收里「窄屏下状态带不得挤掉战场可读性」要防的。
static func narrow_rects(viewport_size: Vector2) -> Array[Rect2]:
	var width: float = viewport_size.x
	var bar_height: float = minf(STATUS_BAR_HEIGHT, viewport_size.y * STATUS_BAR_SHARE)
	var battlefield_height: float = maxf(viewport_size.y - bar_height, 0.0)
	var rects: Array[Rect2] = []
	rects.append(Rect2(0.0, 0.0, width, battlefield_height))
	rects.append(Rect2(0.0, battlefield_height, width, bar_height))
	return rects
