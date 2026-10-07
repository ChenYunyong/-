## combat_layout.gd
## 职责：战斗屏的几何常量（唯一落点）—— 标题栏 / 书页 / 侧栏 / 加成带 / 底部动作条，以及栏内每一行的落点。
## 所属系统：ui
## 依赖：无（只有数字）
## 禁止：本文件不得引用节点 / 绘制 —— 它供 combat_screen 摆放、combat_view 绘制、tests 断言。
##
## 960×540 上的分区（间距全部取 docs/06 §1 的间距系统 4/8/12/16/24 ×3 = 12/24/36/48/72）：
##   ┌───────────────────────────────────────────────┐ 24
##   │ 标题栏 912×48：自动施法 · 波次                  │
##   ├──────────────────────┬────────────────────────┤ 24
##   │ 书页 600×272          │ 侧栏 288×272            │
##   ├──────────────────────┴────────────────────────┤ 24
##   │ 本波加成带 912×52                               │
##   ├───────────────────────────────────────────────┤ 24
##   │ 底部动作条 912×48：本场结果 · 路线图            │
##   └───────────────────────────────────────────────┘ 24
## 上下：24 + 48 + 24 + 272 + 24 + 52 + 24 + 48 + 24 = 540 ✓
## 左右：24 + 600 + 24 + 288 + 24 = 960 ✓
##
## 「本波加成」为什么是**横贯整屏的一条两行**、而不是侧栏里的一段：八条通道全上档时那句话
## 约 65 个全角字宽，侧栏 264px 要折成五行（125px），而侧栏连四行都给不出。
## 摊成一条 912px 的宽带、用 20px 的参数组字号，两行正好装得下 ——
## 塞进侧栏只会变成「平时好看、加满就截断」的那一类毛病。
##
## 侧栏内部（x 从 SIDE_X 起，宽 264 = 288 − 12 ×2；上下各留 12 / 8 的呼吸位）：
##   敌群名 26 → 血条 24 → 血量数字 28 → 魔力 28 → 魔力条 24 → 队列标题 28 → 队列正文 90
##   108 → 360 共 252，加 12 + 8 的内边距 = 272 ✓
##
## 血量条与魔力条是**两条含义不同的读数**，故一橙一蓝、各有自己的底槽 ——
## 同色的话玩家得先读标签才知道哪条是哪条。

class_name CombatLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
## 安全边距与分区间距 = 间距系统里最大的两档（24）。
const MARGIN: float = 24.0
const GAP: float = 24.0
## 面板内边距 = 间距系统里最小的那一档 4 ×3。
const PADDING: float = 12.0

# ------------------------------------------------------------------ 屏上分区

const TITLE_BAR_RECT: Rect2 = Rect2(MARGIN, MARGIN, 912.0, 48.0)
const PAGE_RECT: Rect2 = Rect2(MARGIN, 96.0, 600.0, 272.0)
const SIDE_RECT: Rect2 = Rect2(648.0, 96.0, 288.0, 272.0)
const BONUS_BAR_RECT: Rect2 = Rect2(MARGIN, 392.0, 912.0, 52.0)
const BOTTOM_RECT: Rect2 = Rect2(MARGIN, 468.0, 912.0, 48.0)

## 标题栏里的两行。行矩形整块就是 Label 的矩形，文字在块里纵向居中
## （与 EditorLayout.TOP_TITLE_RECT 同一条做法：行高给足，靠对齐居中，不靠字号凑）。
const TITLE_RECT: Rect2 = Rect2(36.0, 24.0, 600.0, 48.0)
const WAVE_RECT: Rect2 = Rect2(648.0, 24.0, 264.0, 48.0)

## 加成带里的两段：左边「本波加成」四个字，右边这一波的实得加成（占满剩下的宽度，可折两行）。
const BONUS_TITLE_RECT: Rect2 = Rect2(36.0, 392.0, 132.0, 52.0)
const BONUS_TEXT_RECT: Rect2 = Rect2(180.0, 392.0, 756.0, 52.0)

## 底部那句本场结果。它占左边，右边留给「路线图」那颗按钮。
const RESULT_RECT: Rect2 = Rect2(36.0, 468.0, 620.0, 48.0)

# ------------------------------------------------------------------ 侧栏内部

const SIDE_X: float = 660.0
const SIDE_W: float = 264.0

const ENEMY_TITLE_RECT: Rect2 = Rect2(SIDE_X, 108.0, SIDE_W, 26.0)
const HP_BAR_RECT: Rect2 = Rect2(SIDE_X, 134.0, SIDE_W, 24.0)
const HP_TEXT_RECT: Rect2 = Rect2(SIDE_X, 158.0, SIDE_W, 28.0)
const MANA_RECT: Rect2 = Rect2(SIDE_X, 186.0, SIDE_W, 28.0)
const MANA_BAR_RECT: Rect2 = Rect2(SIDE_X, 214.0, SIDE_W, 24.0)
const QUEUE_TITLE_RECT: Rect2 = Rect2(SIDE_X, 242.0, SIDE_W, 28.0)
const QUEUE_RECT: Rect2 = Rect2(SIDE_X, 270.0, SIDE_W, 90.0)

## 两个读数条的填充块相对底槽的内缩量。底槽是一块纯色，填充块缩进一圈才读得出「嵌在里面」，
## 而不是一块色压在另一块色上 —— 两块同高时边界只剩一条颜色接缝。
const BAR_INSET: float = 9.0


## 某个读数条的填充块矩形（在给定条内缩一圈，宽度按比例）。
static func bar_fill_rect(track: Rect2, ratio: float) -> Rect2:
	var inner: Rect2 = Rect2(
		track.position + Vector2(BAR_INSET, BAR_INSET),
		(track.size - Vector2(BAR_INSET, BAR_INSET) * 2.0).max(Vector2.ZERO))
	return Rect2(inner.position, Vector2(inner.size.x * clampf(ratio, 0.0, 1.0), inner.size.y))
