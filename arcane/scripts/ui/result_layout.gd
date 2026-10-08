## result_layout.gd
## 职责：结算屏的几何常量与两颗按钮的文案（唯一落点）。
## 所属系统：ui
## 依赖：UiKit（按钮高）、ArcaneTheme（字号 —— 由 UiKit 转手）
## 禁止：本文件不得引用节点 —— 它只有数字，供 result_screen 摆放、tests 断言。
##
## 960×540 上的分区（间距取 docs/06 §1 的间距系统 4/8/12/16/24）：
##   ┌───────────────────────────────────────────────┐ 24
##   │ 标题 912×72：通关 / 本局结束                     │
##   ├───────────────────────────────────────────────┤ 12
##   │ 账目板 912×132：到过几层 + 本局所得              │
##   ├───────────────────────────────────────────────┤ 12
##   │ 战后详情 912×180：完整施法链 + 八通道 + 施法记录  │
##   ├───────────────────────────────────────────────┤ 12
##   │ 动作条 912×72：回到主菜单 / 再来一局             │
##   └───────────────────────────────────────────────┘ 24
## 上下：24 + 72 + 12 + 132 + 12 + 180 + 12 + 72 + 24 = 540 ✓
##
## 「战后详情」那块是 PET-94 复核加的：`docs/14 §2.3` 的 C02 要求「完整链条 / 八通道加成
## 保留在战后详情或可访问的日志中，不丢状态」，而战斗屏只画得下 4 张卡链 —— 屏一换，
## 那点数据也随 CombatSim 没了。故结算屏必须留出能念完整账的位置（PET-95 Codex 裁定）。
##
## 和主菜单同一套骨架（标题 / 一块板 / 底部动作条），于是「这是一屏结局」读起来与其它屏同族。

class_name ResultLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
const MARGIN: float = 24.0
const GAP: float = 12.0
## 面板内边距。12 = 间距系统里最小的那一档 4 ×3。
const PADDING: float = 12.0
## 板内内容的左右边界与宽度。写法只有一处，摆放与断言都从这里取。
const CONTENT_X: float = MARGIN + PADDING
const CONTENT_W: float = 912.0 - PADDING * 2.0

const TITLE_RECT: Rect2 = Rect2(MARGIN, 24.0, 912.0, 72.0)
const SUMMARY_RECT: Rect2 = Rect2(MARGIN, 108.0, 912.0, 132.0)
const DETAIL_RECT: Rect2 = Rect2(MARGIN, 252.0, 912.0, 180.0)
const BAR_RECT: Rect2 = Rect2(MARGIN, 444.0, 912.0, 72.0)

## 账目板里的三行：进度 / 「本局所得」小标题 / 清单（清单给 2 行折行的高度）。
## 行位置是**倒推**的：板内上边距 12，进度占 36，隔 12，「本局所得」占 24，清单占 40，
## 下边距 8 —— 12 + 36 + 12 + 24 + 40 + 8 = 132 ✓
const PROGRESS_RECT: Rect2 = Rect2(CONTENT_X, 120.0, CONTENT_W, 36.0)
const LEDGER_TITLE_RECT: Rect2 = Rect2(CONTENT_X, 168.0, CONTENT_W, 24.0)
const LEDGER_RECT: Rect2 = Rect2(CONTENT_X, 192.0, CONTENT_W, 40.0)

## 战后详情板里的四行：标题 / 完整链（最多 3 行）/ 八通道（最多 2 行）/ 施法记录 1 行。
## 12 + 24 + 4 + 60 + 4 + 40 + 4 + 20 + 12 = 180 ✓
const DETAIL_TITLE_RECT: Rect2 = Rect2(CONTENT_X, 264.0, CONTENT_W, 24.0)
const DETAIL_CHAIN_RECT: Rect2 = Rect2(CONTENT_X, 292.0, CONTENT_W, 60.0)
const DETAIL_CHANNEL_RECT: Rect2 = Rect2(CONTENT_X, 356.0, CONTENT_W, 40.0)
const DETAIL_CAST_RECT: Rect2 = Rect2(CONTENT_X, 400.0, CONTENT_W, 20.0)

## 两颗出口。两颗都通到「新的一局」，区别只在经不经过主菜单 —— 所以文案必须把这件事说清楚，
## 否则两颗按钮读起来是同一件事（PET-87 §3 的同一类毛病）。
const KEY_MENU: String = "回到主菜单"
const KEY_AGAIN: String = "再来一局"
## 动作条上唯一那颗强主动作（一屏只留一个主按钮）。
const KEY_PRIMARY: String = KEY_MENU


## 动作条里两颗按钮的矩形，顺序 [回到主菜单, 再来一局]，右起排列 ——
## 主动作在最右（与地图屏「继续 / 返回编辑器」同一条排法）。
## 这是按钮几何的**唯一算法**：result_screen 用它摆放，tests 用它断言。
static func button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var cursor: float = BAR_RECT.end.x - PADDING
	for key: String in [KEY_MENU, KEY_AGAIN]:
		var width: float = UiKit.button_width(TranslationServer.translate(key))
		rects.append(Rect2(cursor - width, BAR_RECT.position.y + (BAR_RECT.size.y - button_height()) * 0.5,
			width, button_height()))
		cursor -= width + GAP
	return rects


static func button_height() -> float:
	return UiKit.button_height()
