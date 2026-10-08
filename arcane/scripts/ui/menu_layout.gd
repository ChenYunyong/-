## menu_layout.gd
## 职责：主菜单屏的几何常量与两条入口 / 设置面板的落点（唯一落点）。
## 所属系统：ui
## 依赖：无（只有数字）
## 禁止：本文件不得引用节点 —— 它只有数字，供 main_menu_screen 摆放、tests 断言。
##
## PET-93 屏④：整屏按 docs/14 §2.4 的几何表重排。常量**逐个照抄表格的「rect @960」列**，
## 不做二次推导 —— 表里给的是绝对坐标，抄成算式之后与表对照就得先在脑子里算一遍，
## 而「抄错一个数」正是这个文件唯一会犯的错。关系（间距 12 / 内缩 24 / 相邻不重叠）
## 由 tests/unit/test_menu_layout.gd 逐条反推出来断言。
##
## 960×540 上的纵向账（§2.4）：
##   Logo 48..112（64）→ 16 → 纸背 128..476（348）→ 场景底
##   纸内：上内缩 24 + 56+12+56+4+20+12+56+12+56 = 284 + 脚注 12 + 20 + 下沿 8 = 348 ✓
##   （脚注那一行本轮不画，位置登记在 FOOTNOTE_RECT —— 表把它算进纸背高度，所以账要对得上）
##   设置浮层 168..400：16 + 标题 32 + 16 + 语言行 24 + 12 + 开关 56 + 12 + 帮助 48 + 16 = 232 ✓
##
## 与旧版的三处差别，都是为了 N01/N02：
##   1. 入口从 360×48 改成 **312×56**（真实高度 56，不再是「声明 48 实际 57」）；
##   2. 纸背与设置浮层不再由本屏画 —— 前者与屏①②③ 统一走 ContractTheme.TYPE_PAGE_BAND，
##      后者走 ContractScreenTheme.TYPE_PANEL_DARK_SILVER（§3「纸背四处统一」）；
##   3. 置灰原因不再挂在纸外的空带里，而是纸内「继续」正下方 4px —— 位置固定在表里，
##      有局时该行留空，按钮位置不跳（§2.4 原话）。

class_name MenuLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
## §1 的安全区。可交互包络不许出去（G03），面积账的分母也是它（§4 前言）。
const SAFE_AREA: Rect2 = Rect2(8.0, 8.0, 944.0, 524.0)

## MENU_SCENE：插画满幅。本轮**没有背景素材**（§6 P0-5「最终场景必须等背景素材」），
## 故这一层现在只铺 NAVY_900 —— 它同时是 G06 的兜底（不铺满就露引擎默认灰）。
## MENU_LOGO (280,48,400,64) 36/48，1 行。
const LOGO_RECT: Rect2 = Rect2(280.0, 48.0, 400.0, 64.0)
## MENU_PAPER (300,128,360,348)。距 logo 16（128 − 112）。
const PAPER_RECT: Rect2 = Rect2(300.0, 128.0, 360.0, 348.0)

## 四个入口（312×56，纸内缩 24 = 324 − 300）。顺序即 `entry_rects()` 的顺序。
const NEW_RECT: Rect2 = Rect2(324.0, 152.0, 312.0, 56.0)
const CONTINUE_RECT: Rect2 = Rect2(324.0, 220.0, 312.0, 56.0)
const SETTINGS_ENTRY_RECT: Rect2 = Rect2(324.0, 312.0, 312.0, 56.0)
const EXIT_RECT: Rect2 = Rect2(324.0, 380.0, 312.0, 56.0)
## MENU_DISABLED_REASON (324,280,312,20) 12/20 —— 纸面深墨，距「继续」4（280 − 276）。
const REASON_RECT: Rect2 = Rect2(324.0, 280.0, 312.0, 20.0)
## MENU_FOOTNOTE (324,448,312,20) 12/20「仅短版本号，**可无**」。
## 本轮不画：工程里没有版本号来源（project.godot 无 config/version），
## 编一个假版本号正是 C05 要拦的事。位置在此登记，将来有版本号时直接可用。
const FOOTNOTE_RECT: Rect2 = Rect2(324.0, 448.0, 312.0, 20.0)

## SETTINGS_PANEL (272,168,416,232)：同屏覆盖，打开时隐藏后方四个入口（§2.4）。
const SETTINGS_PANEL: Rect2 = Rect2(272.0, 168.0, 416.0, 232.0)
const SETTINGS_TITLE_RECT: Rect2 = Rect2(288.0, 184.0, 320.0, 32.0)
const SETTINGS_CLOSE_RECT: Rect2 = Rect2(640.0, 184.0, 32.0, 32.0)
const SETTINGS_LANGUAGE_RECT: Rect2 = Rect2(288.0, 232.0, 384.0, 24.0)
const SETTINGS_TOGGLE_RECT: Rect2 = Rect2(288.0, 268.0, 384.0, 56.0)
const SETTINGS_HELP_RECT: Rect2 = Rect2(288.0, 336.0, 384.0, 48.0)

## 四个入口的文案（06 §11：中文原文即 key）。
const KEY_NEW_RUN: String = "开始新一局"
const KEY_CONTINUE: String = "继续"
const KEY_SETTINGS: String = "设置"
const KEY_QUIT: String = "退出"
## Logo 那一行就是游戏名，沿用语言表里已有的那一格。
const KEY_LOGO: String = "奥术蓝图"
## 「继续」置灰时的原因。有局时该行清空 —— **控件不撤**，位置因此不跳（§2.4 原话）。
const KEY_NO_RUN: String = "没有进行中的一局"
## 设置浮层里的三行：标题 / 语言开关 / 说明。
const KEY_LANGUAGE_LABEL: String = "语言"
const KEY_LANGUAGE_SWITCH: String = "中文 / English"
const KEY_SETTINGS_HELP: String = "语言切换立刻生效，并保存在本机"
## 浮层关闭键的文案 key（只进 tooltip 与无障碍名，不画在键上）。
const KEY_CLOSE: String = "关闭设置"

## 四个入口，自上而下。
const BUTTONS: PackedStringArray = [KEY_NEW_RUN, KEY_CONTINUE, KEY_SETTINGS, KEY_QUIT]
## 四个入口里唯一那颗金底强主动作（§2.4 原话：只有「开始新一局」使用金色整面填充）。
const KEY_PRIMARY: String = KEY_NEW_RUN
## 入口的宽高。表里给死，不由文案撑开（G02 第三条）。
const ENTRY_SIZE: Vector2 = Vector2(312.0, 56.0)
## 纸内缩 24、入口间距 12、原因距「继续」4、Logo 距纸背 16、浮层内缩 16。
const PAPER_PADDING: float = 24.0
const ENTRY_GAP: float = 12.0
const REASON_GAP: float = 4.0
const LOGO_GAP: float = 16.0
const PANEL_PADDING: float = 16.0
## 浮层关闭键的图标半径。§2.4 给的是「32×32 的键、图标 24」——
## 与编辑器的收起键同一条口径（24×24 的键放 16 的叉）：图标名义尺寸 + 8 = 控件边长。
const CLOSE_ICON_RADIUS: float = 12.0
## 默认聚焦的控件。设置浮层收起后焦点回这里（N04）；启动时它也是键盘导航的入口。
const DEFAULT_ENTRY: String = KEY_NEW_RUN


# ------------------------------------------------------------------ 取位

## 四个入口的矩形，顺序与 BUTTONS 一致。
## 这是入口几何的**唯一算法**：main_menu_screen 用它摆放，tests 用它断言。
static func entry_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for index: int in BUTTONS.size():
		rects.append(entry_rect(index))
	return rects


## 第 index 颗入口的矩形。index 越界时钳到最后一颗 —— 引用的是一份常量表，
## 越界说明调用方写错了行号，钳制比返回零矩形更容易在画面上看出问题（一个贴左上角的按钮）。
##
## **不是**「首项 + index × 节拍」：表里四个入口的纵向间距并不均匀（原因行那一处只隔 4），
## 用节拍算会从第三颗起一路错下去。
static func entry_rect(index: int) -> Rect2:
	match clampi(index, 0, BUTTONS.size() - 1):
		0:
			return NEW_RECT
		1:
			return CONTINUE_RECT
		2:
			return SETTINGS_ENTRY_RECT
	return EXIT_RECT
