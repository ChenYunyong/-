## combat_theme.gd
## 职责：战斗屏的**配色唯一落点** —— 「这个位置该是什么颜色」写成一张角色表，色值全部来自 Palette。
## 所属系统：data
## 依赖：Palette（唯一色值来源）
## 禁止：本文件不得出现字面色值；不得引用节点 / 场景 / 绘制 —— 它只是一张查表；
##       不得定义玩法语义：哪个角色叫什么由使用方决定，这里只说「它取哪个 Token」。
##
## PET-93 屏③：整张表**逐字重写**为 docs/14 §3 的「视觉角色 → 既有 Token」。
## 旧表（PET-89 那版中性配色）作废 —— 当时刻意不定基调，契约落地后不再需要那张占位表。
##
## 表里只收**这一屏自己画的东西**：战场上的落笔、卡链上那 4 张卡、装置、敌群、一次施法的丝线、
## 两条读数条的填充。文字与面板框（头栏 / 底栏 / 战场底 / 条槽）不在这里：
## 那几类由 ContractTheme / ContractScreenTheme 的类型变体定（06 §7：不在控件上零散覆盖颜色）。
##
## 两条读数条**只有填充**在这张表里：条槽（NAVY_900 + GREY_300 1px + R4）是 ContractScreenTheme
## 的 PanelSunk —— 它与战场底、当前读数位是同一块材质，另立一份必然先分叉。
##
## §3 里与这一屏有关的那几行（逐字）：
##   全屏暗背景 / 深面板 / 条槽       NAVY_900 / NAVY_800
##   玩家核心无素材兜底               NAVY_800 体 / GOLD_600 框 / BLUE_100 墨（明确为**装置**）
##   敌人无素材兜底                   BROWN_400 体 / GREY_300 轮廓 2px；危险标记 RED_400
##   丝线                             NAVY_600（底）/ BLUE_400（芯）4 + 2px
##   当前施法强调 / Selected          GOLD_500（4px 完整轮廓；亮纸处另垫 NAVY_600 暗线）
##   血条轨道 / 血条填充              NAVY_900 / RED_500（RED_500 只画条）
##   法力填充 / 数值                  BLUE_500 / BLUE_100

class_name CombatTheme
extends RefCounted

## 战斗屏上的颜色角色。**按用途命名，不按颜色命名** ——
## 叫 NAVY_800 的话，换基调时这张表会变成一份自相矛盾的说明书。
enum Role {
	## 战场上的读数与标记墨（施法反馈那一个伤害标签就用它）。
	FIELD_INK,
	## 卡链上那 4 张 72 方卡：底板与卡面上的墨（与编辑器同一张卡面）。
	CARD_FILL,
	CARD_INK,
	## 玩家核心：体 / 框 / 墨。§2.3 明说它是**装置**，不是人物。
	CORE_BODY,
	CORE_FRAME,
	CORE_INK,
	## 敌群：体 / 轮廓 / 危险标记。本案只有「敌群 HP」一项，故轮廓只表达敌群。
	ENEMY_BODY,
	ENEMY_OUTLINE,
	ENEMY_DANGER,
	## 一次施法的丝线：底与芯（4 + 2px）。
	BOLT_BASE,
	BOLT_CORE,
	## 当前施法强调：卡链里那张正在放的卡的外圈。
	EMPHASIS,
	## 卡链右端「窗外还有卡」的状态标记。它是**状态**不是强调，故取中性副墨而不是金色。
	CHAIN_MORE,
	## 两条读数条的填充。条槽在 ContractScreenTheme 那边。
	HP_FILL,
	MANA_FILL,
}

## 角色 → Token。**这是整屏唯一一处「哪个 Token 用在哪」的映射**。
##
## 取值理由（逐条对应 §3，同族内拉开以免同用途近似色 —— 04 §4.4）：
##   战场底取 NAVY_900、卡与核心取 NAVY_800：卡压在战场上才浮得起来，这条深浅关系直接沿用编辑器。
##   核心的框是 GOLD_600（§3「核心卡普通金框 1px」），墨是 BLUE_100 —— 装置，不是新主角。
##   敌群走 BROWN_400 体 + GREY_300 轮廓：它是无素材兜底里唯一的暖色实体，与装置的冷色分得开。
##   丝线 NAVY_600 底 + BLUE_400 芯，与地图上那两支同源；当前施法强调 GOLD_500。
##   血条走 RED_500、法力条走 BLUE_500：两条**含义不同**的读数，不能同色
##   （同色时玩家得先读标签才知道哪条是哪条）；数值那一侧由 BLUE_100 承担（§3）。
const ROLE_TOKEN: Dictionary = {
	Role.FIELD_INK: Palette.Key.BLUE_100,
	Role.CARD_FILL: Palette.Key.NAVY_800,
	Role.CARD_INK: Palette.Key.BLUE_100,
	Role.CORE_BODY: Palette.Key.NAVY_800,
	Role.CORE_FRAME: Palette.Key.GOLD_600,
	Role.CORE_INK: Palette.Key.BLUE_100,
	Role.ENEMY_BODY: Palette.Key.BROWN_400,
	Role.ENEMY_OUTLINE: Palette.Key.GREY_300,
	Role.ENEMY_DANGER: Palette.Key.RED_400,
	Role.BOLT_BASE: Palette.Key.NAVY_600,
	Role.BOLT_CORE: Palette.Key.BLUE_400,
	Role.EMPHASIS: Palette.Key.GOLD_500,
	Role.CHAIN_MORE: Palette.Key.GREY_300,
	Role.HP_FILL: Palette.Key.RED_500,
	Role.MANA_FILL: Palette.Key.BLUE_500,
}

## 敌群轮廓的线宽与其它画笔参数**不在这里**：本文件只管配色，粗细 / 外扩 / 段数由落笔那一处
## （combat_view / combat_chain）定 —— 一张颜色表里混进线宽，改基调的人就得同时读两份东西。

## 角色缺登记时的兜底色。灰是「这里没设计过」的颜色，不是某一档色阶 ——
## 它一眼就不像刻意选的，于是漏配当场显形（与 Palette.MISSING_COLOR 同一条思路）。
const FALLBACK_TOKEN: Palette.Key = Palette.Key.GREY_500


## 取某个角色的颜色。**这是战斗屏唯一的取色入口**。
static func color(role: Role) -> Color:
	return Palette.get_color(token_of(role))


## 某个角色对应的 Token。测试用它核对「每个角色都登记过」。
static func token_of(role: Role) -> Palette.Key:
	var token: Variant = ROLE_TOKEN.get(role)
	return token if token != null else FALLBACK_TOKEN


## 表里登记了多少个角色。反向对照用：表被清空时「每个角色都查得到」会变成空真。
static func role_count() -> int:
	return ROLE_TOKEN.size()
