## combat_theme.gd
## 职责：战斗屏的**配色唯一落点** —— 把「这个位置该是什么颜色」写成一张角色表，色值仍全部来自 Palette。
## 所属系统：data
## 依赖：Palette（唯一色值来源）
## 禁止：本文件不得出现字面色值（04 §4.9）；不得引用节点 / 场景 / 绘制 —— 它只是一张查表；
##       不得定义玩法语义：哪个角色叫什么由使用方决定，这里只说「它取哪个 Token」。
##
## 为什么单开一张表（PET-89 §2）：本轮**刻意不定明暗基调** —— 战斗屏的明暗要跟书页一致，
## 而书页的明暗正是用户还没裁定的那一条。于是画面做成中性的、可替换的：
## 所有颜色都经这张表取值，用户裁定之后改这张表就能整体切换，
## 不必回到 combat_view / combat_screen 里去逐个找哪一处用了哪个 Token。
##
## 表里刻意**没有**「哪个角色必须比哪个角色亮」这类断言 —— 那是裁定之后才成立的事，
## 现在写死只会让将来的整体切换变成一场考古。
##
## 表里只收**这一屏自己画的东西**（书页、卡面、丝线、两条读数条）。文字与面板框不在这里：
## 那两类由 ArcaneTheme 的类型变体定（06 §7：不在控件上零散覆盖颜色），
## 战斗屏沿用全工程那一套就对了，另立一套只会让「切基调」变成两处都要改。

class_name CombatTheme
extends RefCounted

## 战斗屏上的颜色角色。**按用途命名，不按颜色命名** ——
## 叫 NAVY_800 的话，换浅色基调时这张表会变成一份自相矛盾的说明书。
enum Role {
	## 书页底色（CombatView 的整个画布）。
	PAGE,
	## 卡面底板与卡面上的墨。
	CARD_FILL,
	CARD_INK,
	## 奥术丝线。
	THREAD,
	## 「刚打出去的那张卡」那一圈。
	CARD_FIRED,
	## 血量条：底槽 + 填充。
	HP_TRACK,
	HP_FILL,
	## 魔力条：底槽 + 填充。
	MANA_TRACK,
	MANA_FILL,
}

## 角色 → Token。**这是整屏唯一一处「哪个 Token 用在哪」的映射**。
##
## 取值理由（同族内拉开，避免同用途近似色 —— 04 §4.4）：
##   书页 NAVY_900 是画布上最深的一档，卡片 NAVY_800 压在它上面才浮得起来
##   （这套深浅关系直接沿用编辑器的书页 / 卡片，战斗屏才不像另一个游戏）。
##   血量走橙、魔力走蓝：这是两条**含义不同**的读数条，不能同色
##   （同色时玩家得先读标签才知道哪条是哪条）。
const ROLE_TOKEN: Dictionary = {
	Role.PAGE: Palette.Key.NAVY_900,
	Role.CARD_FILL: Palette.Key.NAVY_800,
	Role.CARD_INK: Palette.Key.BLUE_100,
	Role.THREAD: Palette.Key.BLUE_400,
	Role.CARD_FIRED: Palette.Key.GOLD_500,
	Role.HP_TRACK: Palette.Key.NAVY_700,
	Role.HP_FILL: Palette.Key.ORANGE_500,
	Role.MANA_TRACK: Palette.Key.NAVY_700,
	Role.MANA_FILL: Palette.Key.BLUE_300,
}

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
