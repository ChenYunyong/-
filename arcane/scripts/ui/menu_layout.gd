## menu_layout.gd
## 职责：主菜单屏的几何常量与入口按钮排布（唯一落点）。
## 所属系统：ui
## 依赖：UiKit（按钮高）、ArcaneTheme（字号 —— 由 UiKit 转手）
## 禁止：本文件不得引用节点 —— 它只有数字，供 main_menu_screen 摆放、tests 断言。
##
## 960×540 上的分区（间距取 docs/06 §1 的间距系统 4/8/12/16/24 ×3 = 12/24/36/48/72）：
##   ┌───────────────────────────────────────────────┐ 24
##   │ 标题 912×84                                     │
##   ├───────────────────────────────────────────────┤ 24
##   │ 入口板 384×288：开始新一局 / 继续 / 设置 / 退出  │
##   ├───────────────────────────────────────────────┤ 24
##   │ 设置面板 912×72：语言 + 中英开关                 │
##   └───────────────────────────────────────────────┘ 24
## 上下：24 + 84 + 24 + 288 + 24 + 72 + 24 = 540 ✓
##
## 入口板的高度是**倒推出来的**，不是随手挑的：四个入口各 48 高（UiKit.button_height()）、
## 之间隔 24，再加板内上下各 12 的内边距 —— 4×48 + 3×24 + 2×12 = 288。
## 于是「四个入口排得下」这件事在常量层面就成立，tests 断言的也就是真机上跑的那组数。
##
## 「继续」被置灰时要在**旁边**说明原因。说明文字因此不占板内的高度（板已经排满了），
## 而是落在板右侧那条 240 宽的空带里 —— 板右边 672 到安全边 936 之间。

class_name MenuLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
## 安全边距与分区间距。docs/06 §1 的 8px（320×180 参考系）×3 = 24。
const MARGIN: float = 24.0
const GAP: float = 24.0
## 面板内边距。12 = 间距系统里最小的那一档 4 ×3。
const PADDING: float = 12.0

const TITLE_RECT: Rect2 = Rect2(MARGIN, MARGIN, 912.0, 84.0)
const PLATE_RECT: Rect2 = Rect2(288.0, 132.0, 384.0, 288.0)
const SETTINGS_RECT: Rect2 = Rect2(MARGIN, 444.0, 912.0, 72.0)

## 四个入口的文案（06 §11：中文原文即 key）。
const KEY_NEW_RUN: String = "开始新一局"
const KEY_CONTINUE: String = "继续"
const KEY_SETTINGS: String = "设置"
const KEY_QUIT: String = "退出"

## 四个入口，自上而下。顺序即 `button_rects()` 的顺序 ——
## 与 EditorLayout.TOP_BUTTONS 同一条做法。
const BUTTONS: PackedStringArray = [KEY_NEW_RUN, KEY_CONTINUE, KEY_SETTINGS, KEY_QUIT]
## 板上唯一那颗强主动作。其余三颗是次级（PET-87 §3 的同一件事：一屏只留一个主按钮）。
const KEY_PRIMARY: String = KEY_NEW_RUN
## 入口按钮的宽。**固定宽**而不是按文案算：这是一列菜单，四颗不等宽会像四块拼图。
## 宽 = 板内宽（384 − 12×2）；英文文案最长为 "SETTINGS" ≈ 8×0.6×24 + 24 = 140 < 360，装得下。
const BUTTON_WIDTH: float = 360.0
## 相邻两颗入口的纵向节拍 = 按钮高 + 间距。
const BUTTON_PITCH: float = 72.0

## 「继续」的置灰原因。板右侧那条空带，与「继续」那颗按钮**同一行** ——
## 说明要贴着它解释，跑到屏幕别处就成了另一条无关的提示。
const CONTINUE_HINT_RECT: Rect2 = Rect2(696.0, 216.0, 240.0, 48.0)

## 设置面板左边那行标题的位置（面板内）。纵向占满整块面板，文字居中。
const SETTINGS_LABEL_RECT: Rect2 = Rect2(36.0, 444.0, 432.0, 72.0)


# ------------------------------------------------------------------ 取位

## 四个入口的矩形，顺序与 BUTTONS 一致。
## 这是入口按钮几何的**唯一算法**：main_menu_screen 用它摆放，tests 用它断言。
static func button_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for index: int in BUTTONS.size():
		rects.append(button_rect(index))
	return rects


## 第 index 颗入口按钮的矩形。index 越界时钳到最后一颗 —— 引用的是一份常量表，
## 越界说明调用方写错了行号，钳制比返回零矩形更容易在画面上看出问题（一个贴左上角的按钮）。
static func button_rect(index: int) -> Rect2:
	var row: int = clampi(index, 0, BUTTONS.size() - 1)
	var y: float = PLATE_RECT.position.y + PADDING + float(row) * BUTTON_PITCH
	return Rect2(PLATE_RECT.position.x + PADDING, y, BUTTON_WIDTH, button_height())


## 入口按钮的高度。取自 UiKit 的那一条算式，不另立一个数 ——
## 板上四颗按钮的高度与顶栏 / 底栏的按钮必须是同一个值，否则「按钮排得下」的账要算两遍。
static func button_height() -> float:
	return UiKit.button_height()
