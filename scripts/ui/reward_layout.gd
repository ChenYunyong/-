## reward_layout.gd
## 职责：REWARD 界面（06 §9）的布局常量与纯函数 —— 标题栏、卡片区、三张选项卡各画在哪。
## 所属系统：ui
## 依赖：无
## 禁止：不得出现任何玩法数值（奖励数值 / 掉落池 / 稀有度权重属 Stage 4 的 S4-07）；
##       不得写任何字面色值；不得持节点、不得读 GameFlow —— 这是纯几何，要能脱离场景树单测。
##
## 与 PreparationLayout / CombatLayout 同构：常量 + static 纯函数，没有实例状态。
## 于是「布局算得对不对」不必先起一棵场景树。
##
## 每个数字的来源（06 §9 只规定了「3 个选项 + 不足时以跳过补齐」，未给实测矩形，
## 故下列取值全部由已经冻结的规范值推导，不发明新尺寸）：
##   · 安全边距 16  —— 06 §1 的屏幕安全边距（与 PreparationLayout.SAFE_INSET 同值）
##   · 元素间距 16  —— 06 §1 的间距刻度
##   · 标题栏高 32  —— 06 §2.2 的面板标题栏高度（= PaletteTheme.TITLE_BAR_HEIGHT）
##   · 触摸下限 88  —— 06 §1 的可点击区域下限，沿用 PreparationLayout.NARROW_ACTION_SIZE 的先例
##   · 三列         —— 06 §9「3 个选项」
## 以上是 PET-80 后的值；改动前（基准 320×180）依次是 8 / 8 / 16 / 44，逐项 ×2。
## 这组推导随交付回报 DSH；若与 Codex 的观感判断冲突，以 Codex 为准。
##
## PET-80：基准画布 320×180 → 640×360，上述**几何量逐项 ×2**（320→640、8→16、16→32、44→88）。
## 三个**比值 / 计数**不随坐标系变，故保持原值：`COLUMNS` = 3、`NARROW_ASPECT_MAX` = 1.0。

class_name RewardLayout
extends RefCounted

## 分区下标。与 PreparationLayout.Region 同风格，供冒烟按名字取矩形。
enum Region { TITLE, CARDS }

## 06 §1 的基准分辨率。布局以它为坐标系，于是「第几个像素」可以直接读。
const DESIGN_WIDTH: float = 640.0
const DESIGN_HEIGHT: float = 360.0

## 06 §1：屏幕安全边距与元素间距。
const SAFE_INSET: float = 16.0
const GAP: float = 16.0

## 06 §2.2：面板标题栏高度。此处独立复写而非引用 PaletteTheme ——
## 布局层不依赖 Theme 脚本，两边对不上时由测试打红（同 preparation_layout.gd 的做法）。
const TITLE_HEIGHT: float = 32.0

## 06 §9：三个选项位。
const COLUMNS: int = 3

## 06 §1：可点击区域下限。窄屏下卡片不得低于此值 —— 宁可溢出，也不缩到点不准。
const MIN_CARD_HEIGHT: float = 88.0

## 06 §7.1：宽 < 高（aspect < 1.0）判为窄屏。
const NARROW_ASPECT_MAX: float = 1.0


## 06 §7.1 的折叠判据。退化尺寸（0×0）**不得**被判成窄屏 ——
## headless 首帧的可用区就是 0×0，误判会让冒烟量到一套错误的矩形。
static func is_narrow(viewport_size: Vector2) -> bool:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return false
	return viewport_size.x / viewport_size.y < NARROW_ASPECT_MAX


## 卡片区上沿：安全边距 + 标题栏 + 一个间距。宽窄两档共用 ——
## 折叠改的是「横排还是竖排」，标题栏与它下方的间距不变。
static func cards_top() -> float:
	return SAFE_INSET + TITLE_HEIGHT + GAP


## 宽屏标题栏：横贯安全区。
static func wide_title_rect() -> Rect2:
	return Rect2(SAFE_INSET, SAFE_INSET, DESIGN_WIDTH - SAFE_INSET * 2.0, TITLE_HEIGHT)


## 宽屏卡片宽：三等分安全区，扣掉两条间距。640 → (640-32-32)/3 = 192（PET-80 前 96）。
static func wide_card_width() -> float:
	return (DESIGN_WIDTH - SAFE_INSET * 2.0 - GAP * float(COLUMNS - 1)) / float(COLUMNS)


## 宽屏卡片高：从卡片区上沿一直铺到底部安全线。360 → 360-64-16 = 280（PET-80 前 140）。
static func wide_card_height() -> float:
	return DESIGN_HEIGHT - cards_top() - SAFE_INSET


## 宽屏卡片区：三列横排的外框。
static func wide_cards_rect() -> Rect2:
	return Rect2(SAFE_INSET, cards_top(), DESIGN_WIDTH - SAFE_INSET * 2.0, wide_card_height())


## 宽屏三张卡片的矩形，**相对卡片区原点**（卡片是卡片区的子节点）。
static func wide_card_rects() -> Array[Rect2]:
	var width: float = wide_card_width()
	var rects: Array[Rect2] = []
	for index: int in COLUMNS:
		rects.append(Rect2((width + GAP) * float(index), 0.0, width, wide_card_height()))
	return rects


## 窄屏标题栏：横贯可用区。
static func narrow_title_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(SAFE_INSET, SAFE_INSET, maxf(viewport_size.x - SAFE_INSET * 2.0, 0.0), TITLE_HEIGHT)


## 窄屏卡片宽：整条可用宽。卡片改竖排后不再分列。
static func narrow_card_width(viewport_size: Vector2) -> float:
	return maxf(viewport_size.x - SAFE_INSET * 2.0, 0.0)


## 窄屏卡片高：三等分余下的竖向空间，夹在 [88, 宽屏卡片高] 之间。
## 360×640 → (560-32)/3 = 176；288×640 这类偏窄的竖屏也能守住 88 的触摸下限。
## （PET-80 前分别是 [44, 140]、180×320 → 88、144×320。）
static func narrow_card_height(viewport_size: Vector2) -> float:
	var area: float = viewport_size.y - cards_top() - SAFE_INSET
	var share: float = (area - GAP * float(COLUMNS - 1)) / float(COLUMNS)
	return clampf(share, MIN_CARD_HEIGHT, wide_card_height())


## 窄屏卡片区：三行竖排的外框。
static func narrow_cards_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(SAFE_INSET, cards_top(), narrow_card_width(viewport_size),
		viewport_size.y - cards_top() - SAFE_INSET)


## 窄屏三张卡片的矩形，**相对卡片区原点**。
static func narrow_card_rects(viewport_size: Vector2) -> Array[Rect2]:
	var height: float = narrow_card_height(viewport_size)
	var rects: Array[Rect2] = []
	for index: int in COLUMNS:
		rects.append(Rect2(0.0, (height + GAP) * float(index), narrow_card_width(viewport_size), height))
	return rects


## 标题栏矩形（按当前档位）。
static func title_rect(viewport_size: Vector2) -> Rect2:
	return narrow_title_rect(viewport_size) if is_narrow(viewport_size) else wide_title_rect()


## 卡片区矩形（按当前档位）。
static func cards_rect(viewport_size: Vector2) -> Rect2:
	return narrow_cards_rect(viewport_size) if is_narrow(viewport_size) else wide_cards_rect()


## 三张卡片的矩形，相对卡片区原点（按当前档位）。
static func card_rects(viewport_size: Vector2) -> Array[Rect2]:
	return narrow_card_rects(viewport_size) if is_narrow(viewport_size) else wide_card_rects()
