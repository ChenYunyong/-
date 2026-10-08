## combat_layout.gd
## 职责：战斗屏的几何常量（唯一落点）—— docs/14 §2.3 的几何表抄成常量，外加条 / 卡链 / 结果行的派生量。
## 所属系统：ui
## 依赖：BoardModel（卡尺寸 72 —— 卡链用的就是编辑器那一张卡）
## 禁止：本文件不得引用节点 / 绘制；不得写入 §2.3 以外的数字 —— 供 combat_screen 摆放、
##       combat_view 与 combat_chain 绘制、tests 断言。
##
## 960×540 上的三段（绝对坐标，间距一律取 §1 的 16 / 12 / 8 / 4）：
##   纵向：16 + 头栏 56 + 12 + 纸框 312 + 12 + 底栏 116 + 16 = 540 ✓
##   横向：16 + 928 + 16 = 960 ✓；纸框内缩 16 得战场 896×280（C01：占安全区 50.718%）。
##   ┌───────────────────────────────────────────────┐
##   │ 头栏「深芯金框」：自动施法 24/32 · 魔力 · 波次 · 敌群 │
##   ├───────────────────────────────────────────────┤ 12
##   │ 纸框（亮纸 16）：战场 896×280 —— 装置 / 敌群 / 一次施法反馈 │
##   ├───────────────────────────────────────────────┤ 12
##   │ 底栏「纸背 / 暗芯」：当前读数 · 卡链 4 张 · 队列加成 · 结果行 │
##   └───────────────────────────────────────────────┘
##
## 这一屏**没有**卡牌连接大图（C01 的「卡牌连接大图占比 = 0」）：书页那一套连线是编辑器的交互件，
## 战斗屏只在底栏用 4 张 72 方卡表达「施法链」，链条更长时给一个「还有更多」的状态标记。
##
## 两个读数条的内缩 1 / 内高 10 是 §2.3 给死的数：填充宽 = floor((216 − 2) × clamp(hp/max, 0, 1))，
## 30% 时 64、0% 时 0、100% 时 214；法力条同式、内宽 190。写成常量而不是算式，
## 是为了让 C03 的三个边界读数能逐点对照，而不是「差不多」。

class_name CombatLayout
extends RefCounted

const SCREEN: Vector2 = Vector2(960.0, 540.0)
## 安全区（G03：可交互包络不得越出它）。分母一律是它的面积 944×524 = 494656。
const SAFE_AREA: Rect2 = Rect2(8.0, 8.0, 944.0, 524.0)
const SPACING_4: float = 4.0
const SPACING_8: float = 8.0
const SPACING_12: float = 12.0
const SPACING_16: float = 16.0

# ------------------------------------------------------------------ 头栏 56
## 深芯金框（NAVY_800 + GOLD_600 1px）。四组读数各占一栏，字号与行高逐条来自 §2.3。
const HEADER: Rect2 = Rect2(16.0, 16.0, 928.0, 56.0)
const TITLE_RECT: Rect2 = Rect2(28.0, 28.0, 176.0, 32.0)
## 魔力：上一行「标签 + 真实数值」（同一 rect，一左一右），下一行条。
const MANA_LABEL_RECT: Rect2 = Rect2(220.0, 20.0, 192.0, 24.0)
const MANA_TRACK: Rect2 = Rect2(220.0, 48.0, 192.0, 12.0)
## 波次是一级元素（§2.3 原文），故与屏标题同档 24/32。
const WAVE_RECT: Rect2 = Rect2(436.0, 28.0, 256.0, 32.0)
## 敌群：写「敌群」，不写玩家 HP —— 本波模型里没有玩家生命值这一项。
const ENEMY_LABEL_RECT: Rect2 = Rect2(716.0, 20.0, 216.0, 24.0)
const ENEMY_HP_TRACK: Rect2 = Rect2(716.0, 48.0, 216.0, 12.0)

# ------------------------------------------------------------------ 纸框与战场
const PAPER_FRAME: Rect2 = Rect2(16.0, 84.0, 928.0, 312.0)
## 战场：全屏最大的单一信息区（C01）。夜景 / 敌人 / 弹道都画在这一块里。
const FIELD: Rect2 = Rect2(32.0, 100.0, 896.0, 280.0)
## 玩家核心：§2.3 明说是**装置**（美术包络，不可点击，也不画成新主角）。
const CORE_DEVICE: Rect2 = Rect2(96.0, 228.0, 72.0, 96.0)
## 敌群：本波模型只有「敌群 HP」一项，故这一个包络只表达敌群，轮廓不随血量变化。
const ENEMY_PRESENTATION: Rect2 = Rect2(608.0, 188.0, 288.0, 156.0)

# ------------------------------------------------------------------ 底栏 116
const FOOTER: Rect2 = Rect2(16.0, 408.0, 928.0, 116.0)
## 当前读数：名 20/28 + 数值 16/24，内缩 8（§2.3）。
const ACTIVE_READOUT: Rect2 = Rect2(32.0, 424.0, 200.0, 72.0)
const ACTIVE_NAME_RECT: Rect2 = Rect2(40.0, 432.0, 184.0, 28.0)
const ACTIVE_VALUE_RECT: Rect2 = Rect2(40.0, 460.0, 184.0, 24.0)
## 施法链：R0/S0（它自己没有底，卡与标记直接落在底栏上）。
const ACTIVE_CHAIN: Rect2 = Rect2(248.0, 424.0, 352.0, 72.0)
## 队列加成：标题一行 16/24 + 摘要两行 12/20，内缩 8。
##
## 标题**贴着面板上缘**（y 424..448）而不是内缩 8 —— §2.3 的结算态原话是「右侧摘要仅保留
## y424..448 标题」，标题那一行的绝对位置就是这两条数的交集。摘要于是从 448 起，两行 40 高，
## 到 488 收住，面板底还余 8。照内缩 8 起排的话，24 + 40 = 64 塞不进 72 − 16 = 56，
## 两行摘要会被截断，而 G10 明令「所有按钮 1 行无截断」。
const QUEUE_BONUS: Rect2 = Rect2(616.0, 424.0, 312.0, 72.0)
const QUEUE_TITLE_RECT: Rect2 = Rect2(624.0, 424.0, 296.0, 24.0)
const QUEUE_SUMMARY_RECT: Rect2 = Rect2(624.0, 448.0, 296.0, 40.0)
## 结果行：距卡 4（496 + 4 = 500）。R0/S0。
const RESULT_RECT: Rect2 = Rect2(32.0, 500.0, 896.0, 20.0)
## 结算后同一行的收窄版：给「结算」那颗按钮让位，不能叠住文案（§2.3）。
const RESULT_RECT_DONE: Rect2 = Rect2(32.0, 500.0, 736.0, 20.0)
## 「结算」按钮：**仅结算后出现**，出现时替换右侧摘要的下半部分。
const DONE_BUTTON: Rect2 = Rect2(784.0, 464.0, 144.0, 48.0)

## 卡链：4 张 72 方卡、间距 12，右端余 28 给「链条还有更多」的状态标记（C02：其余链信息仍可查）。
const CHAIN_SLOTS: int = 4
const CHAIN_GAP: float = 12.0
const CHAIN_MARK: float = 28.0

## 条的内缩与内高（§2.3：「填充内缩 1，内高 10」）。
const BAR_INSET: float = 1.0
const BAR_INNER_HEIGHT: float = 10.0


# ------------------------------------------------------------------ 派生量

## 一条读数条的填充块矩形。内宽 = 条宽 − 2，再按比例取**整**（floor）——
## C03 的三个边界读数（0 / 64 / 214）是这一行算出来的，不是画上去再量的。
static func bar_fill_rect(track: Rect2, ratio: float) -> Rect2:
	var inner: Rect2 = Rect2(track.position + Vector2(BAR_INSET, BAR_INSET),
		Vector2(track.size.x - BAR_INSET * 2.0, BAR_INNER_HEIGHT))
	return Rect2(inner.position,
		Vector2(floorf(inner.size.x * clampf(ratio, 0.0, 1.0)), inner.size.y))


## 卡链里第 index 张卡（0 起，左对齐）的 rect。count 是这一帧真的有几张要画（≤ CHAIN_SLOTS）。
static func chain_card_rect(index: int, count: int) -> Rect2:
	if index < 0 or index >= clampi(count, 0, CHAIN_SLOTS):
		return Rect2()
	return Rect2(ACTIVE_CHAIN.position
		+ Vector2(float(index) * (BoardModel.CARD_SIZE.x + CHAIN_GAP), 0.0), BoardModel.CARD_SIZE)


## 链条右端那 28px 的状态标记位。链条超过 4 张时在这里画「还有更多」。
static func chain_mark_rect() -> Rect2:
	return Rect2(ACTIVE_CHAIN.position + Vector2(
		float(CHAIN_SLOTS) * (BoardModel.CARD_SIZE.x + CHAIN_GAP) - CHAIN_GAP, 0.0),
		Vector2(CHAIN_MARK, ACTIVE_CHAIN.size.y))


## 结果行的矩形。结算后收窄到 736，把右端让给按钮。
static func result_rect(settled: bool) -> Rect2:
	return RESULT_RECT_DONE if settled else RESULT_RECT


## 卡链这一帧要画的那一段：(起点下标, 张数)。以当前施法卡为**终点**取最近 4 张（§2.3 原话）；
## current < 0（本波还没施法）时从队首起 —— 一进战斗就让玩家看见这一波会按什么顺序放。
## 抽成布局上的纯函数而不是画布里的字段运算：C02 的「最多 4 张同时可见、以当前施法卡为终点」
## 是可算的，算在布局层就不必为了量它去建一个控件。
static func chain_window(current: int, total: int) -> Vector2i:
	var count: int = mini(total, CHAIN_SLOTS)
	if count <= 0:
		return Vector2i(0, 0)
	if current >= 0:
		return Vector2i(clampi(current - count + 1, 0, total - count), count)
	return Vector2i(0, count)


## 屏坐标 → **战场局部坐标**。版式表给的一律是屏坐标，而战场是屏内自己的一层
## （CombatView 的 (0,0) 落在 FIELD 的左上角），里面落笔的都得先过这一下。
static func to_local(point: Vector2) -> Vector2:
	return point - FIELD.position


## 结算后右侧摘要让位：只保留标题那一行，摘要隐掉。
static func queue_summary_visible(settled: bool) -> bool:
	return not settled
