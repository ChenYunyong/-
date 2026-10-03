## result_layout.gd
## 职责：RESULT 界面（03 §1 状态图、06 §10）的布局常量与纯函数 —— 标题栏、本局读数区、
##       以及两个出口按钮各画在哪。
## 所属系统：ui
## 依赖：无
## 禁止：不得出现任何玩法统计（波次计分 / 掉落结算 / 局外成长属 Stage 4 的 S4-08）；
##       不得写任何字面色值；不得持节点、不得读 GameFlow / RunState —— 这是纯几何，
##       要能脱离场景树单测。
##
## 与 PreparationLayout / CombatLayout / RewardLayout 同构：常量 + static 纯函数，没有实例状态。
##
## 每个数字的来源（06 只规定了全局 §1 / §2 面板 / §3 按钮 / §10 交互硬规则，**没有 RESULT 版面**，
## 故下列取值全部由已经冻结的规范值推导，不发明新色值、不发明新尺寸档）：
##   · 安全边距 8   —— 06 §1 的屏幕安全边距（与 PreparationLayout.SAFE_INSET 同值）
##   · 元素间距 8   —— 06 §1 的间距刻度
##   · 标题栏高 16  —— 06 §2.2 的面板标题栏高度（= PaletteTheme.TITLE_BAR_HEIGHT）
##   · 按钮高 44    —— 06 §1 的触摸下限（设备像素 ≥44）；同时满足 03 §8 的「44×44 逻辑像素」
##                     读法，故取 44 而不是别的档位，两种读法下都不失守
##   · 两个出口     —— 本批验收：返回主菜单 / 再来一局
## 版面本身（分区比重、色量分布、图标）属**观感判断**，随交付回报 DSH 转 Codex 裁定；
## 若与 Codex 的判断冲突，以 Codex 为准。

class_name ResultLayout
extends RefCounted

## 06 §1 的基准分辨率。布局以它为坐标系，于是「第几个像素」可以直接读。
const DESIGN_WIDTH: float = 320.0
const DESIGN_HEIGHT: float = 180.0

## 06 §1：屏幕安全边距与元素间距。
const SAFE_INSET: float = 8.0
const GAP: float = 8.0

## 06 §2.2：面板标题栏高度。此处独立复写而非引用 PaletteTheme ——
## 布局层不依赖 Theme 脚本，两边对不上时由测试打红（同 preparation_layout.gd 的做法）。
const TITLE_HEIGHT: float = 16.0

## 06 §1：可点击区域下限。两个出口按钮在任何档位下都不得低于此值。
const MIN_TOUCH_SIZE: float = 44.0

## 06 §1 的触摸下限是按**设备像素**写的，最小缩放 2×。
## 布局用的是逻辑像素，故二者只在 2× 这一档相等 —— 这是本文件把按钮取到 44 逻辑像素的原因。
const MIN_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PIXELS: float = 44.0

## 出口按钮个数（验收：返回主菜单 / 再来一局）。
const ACTION_COUNT: int = 2

## 06 §7.1：宽 < 高（aspect < 1.0）判为窄屏。
const NARROW_ASPECT_MAX: float = 1.0


## 06 §7.1 的折叠判据。退化尺寸（0×0）**不得**被判成窄屏 ——
## headless 首帧的可用区就是 0×0，误判会让冒烟量到一套错误的矩形。
static func is_narrow(viewport_size: Vector2) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	return viewport_size.x / viewport_size.y < NARROW_ASPECT_MAX


## 读数区上沿：安全边距 + 标题栏 + 一个间距。宽窄两档共用 ——
## 折叠改的是「按钮横排还是竖排」，标题栏与它下方的间距不变。
static func readout_top() -> float:
	return SAFE_INSET + TITLE_HEIGHT + GAP


## 宽屏标题栏：横贯安全区。
static func wide_title_rect() -> Rect2:
	return Rect2(SAFE_INSET, SAFE_INSET, DESIGN_WIDTH - SAFE_INSET * 2.0, TITLE_HEIGHT)


## 宽屏出口按钮宽：二等分安全区，扣掉一条间距。320 → (320-16-8)/2 = 148。
static func wide_action_width() -> float:
	return (DESIGN_WIDTH - SAFE_INSET * 2.0 - GAP * float(ACTION_COUNT - 1)) / float(ACTION_COUNT)


## 宽屏读数区：从读数区上沿铺到出口按钮之上，隔一个间距。180 → 128-8-32 = 88。
static func wide_readout_rect() -> Rect2:
	return Rect2(SAFE_INSET, readout_top(), DESIGN_WIDTH - SAFE_INSET * 2.0,
		DESIGN_HEIGHT - SAFE_INSET - MIN_TOUCH_SIZE - GAP - readout_top())


## 宽屏出口按钮区：横贯安全区，贴底部安全线。
static func wide_actions_rect() -> Rect2:
	return Rect2(SAFE_INSET, DESIGN_HEIGHT - SAFE_INSET - MIN_TOUCH_SIZE,
		DESIGN_WIDTH - SAFE_INSET * 2.0, MIN_TOUCH_SIZE)


## 宽屏两个按钮的矩形，**相对按钮区原点**（按钮是按钮区的子节点）。
static func wide_action_rects() -> Array[Rect2]:
	var width: float = wide_action_width()
	var rects: Array[Rect2] = []
	for index: int in ACTION_COUNT:
		rects.append(Rect2((width + GAP) * float(index), 0.0, width, MIN_TOUCH_SIZE))
	return rects


## 窄屏标题栏：横贯可用区。
static func narrow_title_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(SAFE_INSET, SAFE_INSET, maxf(viewport_size.x - SAFE_INSET * 2.0, 0.0), TITLE_HEIGHT)


## 窄屏按钮宽：整条可用宽。按钮改竖排后不再分列。
static func narrow_action_width(viewport_size: Vector2) -> float:
	return maxf(viewport_size.x - SAFE_INSET * 2.0, 0.0)


## 窄屏按钮区高：两个 44 的按钮加一条间距，固定 96 —— 竖排的份额不再随屏高变化，
## 于是触摸下限在极矮的竖屏上也守得住（宁可按钮区上移压到底部安全线以内，
## 也不把按钮缩到点不准；这一点与 RewardLayout.narrow_card_height 的取舍同款）。
static func narrow_actions_height() -> float:
	return MIN_TOUCH_SIZE * float(ACTION_COUNT) + GAP * float(ACTION_COUNT - 1)


## 窄屏出口按钮区：贴底部安全线，两个按钮自下而上占满 96px。
static func narrow_actions_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(SAFE_INSET, viewport_size.y - SAFE_INSET - narrow_actions_height(),
		narrow_action_width(viewport_size), narrow_actions_height())


## 窄屏读数区：填满标题栏与按钮区之间余下的空间。
## 屏幕矮到按钮区顶到标题栏下方时余量转负，夹到 0 —— 读数区消失也比画出负矩形好。
## 阈值在**高 144**：上沿 32（8+16+8）+ 按钮区 96（44×2+8）+ 贴底 8 + 间距 8。120×180 还剩
## 36px，故正案例测不到这条分支；真正走到它的取样与断言见 tests/unit/test_result.gd 的 CLAMP_VIEWPORT。
static func narrow_readout_rect(viewport_size: Vector2) -> Rect2:
	var bottom: float = narrow_actions_rect(viewport_size).position.y - GAP
	return Rect2(SAFE_INSET, readout_top(), narrow_action_width(viewport_size),
		maxf(bottom - readout_top(), 0.0))


## 窄屏两个按钮的矩形，**相对按钮区原点**。竖排，同处一列。
static func narrow_action_rects(viewport_size: Vector2) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for index: int in ACTION_COUNT:
		rects.append(Rect2(0.0, (MIN_TOUCH_SIZE + GAP) * float(index),
			narrow_action_width(viewport_size), MIN_TOUCH_SIZE))
	return rects


## 标题栏矩形（按当前档位）。
static func title_rect(viewport_size: Vector2) -> Rect2:
	return narrow_title_rect(viewport_size) if is_narrow(viewport_size) else wide_title_rect()


## 读数区矩形（按当前档位）。
static func readout_rect(viewport_size: Vector2) -> Rect2:
	return narrow_readout_rect(viewport_size) if is_narrow(viewport_size) else wide_readout_rect()


## 出口按钮区矩形（按当前档位）。
static func actions_rect(viewport_size: Vector2) -> Rect2:
	return narrow_actions_rect(viewport_size) if is_narrow(viewport_size) else wide_actions_rect()


## 两个出口按钮的矩形，相对按钮区原点（按当前档位）。
## 顺序即场景节点顺序：0 = 返回主菜单（次要），1 = 再来一局（主要）——
## 宽屏是从左到右，窄屏是从上到下，两种排布下「主要出口都在末位」这一点不变。
static func action_rects(viewport_size: Vector2) -> Array[Rect2]:
	return narrow_action_rects(viewport_size) if is_narrow(viewport_size) else wide_action_rects()
