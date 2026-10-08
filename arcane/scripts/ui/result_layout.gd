## result_layout.gd
## 职责：结算屏的几何常量与两颗按钮的文案（唯一落点）。
## 所属系统：ui
## 依赖：UiKit（按钮高）、ArcaneTheme（字号 —— 由 UiKit 转手）
## 禁止：本文件不得引用节点 —— 它只有数字，供 result_screen 摆放、tests 断言。
##
## 960×540 上的分区（间距取 docs/06 §1 的间距系统 4/8/12/16/24 ×3 = 12/24/36/48/72）：
##   ┌───────────────────────────────────────────────┐ 24
##   │ 标题 912×84：通关 / 本局结束                     │
##   ├───────────────────────────────────────────────┤ 24
##   │ 账目板 912×288：到过几层 + 本局所得              │
##   ├───────────────────────────────────────────────┤ 24
##   │ 动作条 912×72：回到主菜单 / 再来一局             │
##   └───────────────────────────────────────────────┘ 24
## 上下：24 + 84 + 24 + 288 + 24 + 72 + 24 = 540 ✓
##
## 和主菜单同一套骨架（标题 / 一块板 / 底部动作条），于是「这是一屏结局」读起来与其它屏同族 ——
## 本轮不新造版式（视觉契约是 PET-91 的事）。

class_name ResultLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
const MARGIN: float = 24.0
const GAP: float = 24.0
## 面板内边距。12 = 间距系统里最小的那一档 4 ×3。
const PADDING: float = 12.0

const TITLE_RECT: Rect2 = Rect2(MARGIN, MARGIN, 912.0, 84.0)
const SUMMARY_RECT: Rect2 = Rect2(MARGIN, 132.0, 912.0, 288.0)
const BAR_RECT: Rect2 = Rect2(MARGIN, 444.0, 912.0, 72.0)

## 账目板里的三行：进度 / 「本局所得」小标题 / 清单。
## 行位置是**倒推**的：板内上边距 24，进度占 36，隔 24，「本局所得」占 36，隔 12，
## 剩下 288 − 24 − 36 − 24 − 36 − 12 − 24(下边距) = 132 留给清单。
const PROGRESS_RECT: Rect2 = Rect2(SUMMARY_RECT.position.x + 24.0, 156.0, 864.0, 36.0)
const LEDGER_TITLE_RECT: Rect2 = Rect2(SUMMARY_RECT.position.x + 24.0, 216.0, 864.0, 36.0)
const LEDGER_RECT: Rect2 = Rect2(SUMMARY_RECT.position.x + 24.0, 264.0, 864.0, 132.0)

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
