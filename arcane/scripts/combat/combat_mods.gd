## combat_mods.gd
## 职责：功能卡八类在本波内累积的修正 —— 八个互不重叠的通道，以及由它们派生出的节拍 / 费用 / 段数。
## 所属系统：combat
## 依赖：CardData（只读它的 kind 与 function_kind）
## 禁止：本文件不得引用任何节点 / 绘制 / Palette；不得持有书页或波次 —— 它只记「这一波上了什么」；
##       不得自己推进时间：节拍是被问出来的（mana_period_ticks 等），推进由 CombatSim 负责。
##
## 为什么单独一个文件：CombatSim 已经顶到 test_source_rules 的 300 行上限，而这两件事的
## 分界线很清楚 —— CombatSim 管「什么时候轮到谁、打完没有」，本文件管「轮到之后打出去是什么样」。
## 加一条功能卡规则时只动这里，加一条推进规则时只动那边。
##
## 八个通道**刻意互不重叠**，于是「八张卡各自生效」是八件可分别量出来的事，
## 而不是八张卡抢同一个数字（抢同一个数字的话，任意一张坏了都要靠排除法才知道是哪张）：
##   附魔      → 伤害倍率   每次施法伤害 ×(1 + 0.5n)
##   子弹数量  → 单拍段数   能力卡一次结算 (1+n) 段，每段各付一次费用
##   连发数量  → 跨拍段数   之后 n 次能力卡施放各多打一段（同样各付一次费用）
##   加速      → 能量供给   核心产出节拍 −5 tick/档（下限 5）
##   攻速      → 出手频率   施法节拍 −1 tick/档（下限 1）
##   减速      → 时限       敌群被拖住，本波限时 +3 秒/档
##   冷却      → 费用       每次施法每段费用 −1/档（下限 0）
##   循环      → 顺序       成功施放后游标回到队首
##
## 修正是**本波**的：换一波就清零，要把功能卡重新打出来一次才再有。

class_name CombatMods
extends RefCounted

## 附魔每档给多少倍率。0.5 而不是旧工程的 ENCHANT_FACTOR = 2.0：
## 那个数是在「附魔是连接形状、一辈子只加一次」的模型下定的；这里功能卡可以在队列里
## 反复打出来，×2 叠三次就是 ×8，两波之内数值就飞了。
const ENCHANT_PER_STACK: float = 0.5
## 加速每档缩短多少拍，以及下限。下限 5 = 每秒产出 4 次 ——
## 再快下去，「一秒」这个玩家数得出来的单位就失去意义了。
const HASTE_TICKS_PER_STACK: int = 5
const MIN_MANA_INTERVAL_TICKS: int = 5
## 攻速每档缩短多少拍。下限 1 = 每拍都打，再短就不是 tick 能表达的了。
const ATTACK_SPEED_TICKS_PER_STACK: int = 1
const MIN_CAST_INTERVAL_TICKS: int = 1
## 减速每档给本波加多少拍（60 = 3 秒 × 20 拍/秒）。它是**敌群被拖慢**，不是「自己变慢」——
## 后者是一张纯惩罚卡，玩家没有理由把它放上书页。
## 写成拍而不是秒：本文件不许引用 CombatSim（那会绕成循环依赖），
## 而把 20 拍/秒在这里再抄一遍，症状只会是「时限悄悄短了一点」，没人查得出来。
const SLOW_TICKS_PER_STACK: int = 60
## 冷却每档减免多少费用。
const COOLDOWN_DISCOUNT_PER_STACK: int = 1
## 连发每档给几次「额外再打一段」的余额。
const BURST_SHOTS_PER_STACK: int = 1

var enchant_stacks: int = 0
var projectile_stacks: int = 0
var haste_stacks: int = 0
var slow_stacks: int = 0
var attack_speed_stacks: int = 0
var cooldown_stacks: int = 0
## 连发余额：还剩几次「额外再打一段」。用一次少一次。
var burst_left: int = 0
var looping: bool = false


## 回到「什么都没上」。每波开头调一次。
func reset() -> void:
	enchant_stacks = 0
	projectile_stacks = 0
	haste_stacks = 0
	slow_stacks = 0
	attack_speed_stacks = 0
	cooldown_stacks = 0
	burst_left = 0
	looping = false


## 一张功能卡生效，对应通道加一档。核心卡与能力卡到这里什么都不做。
func apply(card: CardData) -> void:
	if card == null or card.kind != CardData.Kind.FUNCTION:
		return
	match card.function_kind:
		CardData.Fn.ENCHANT:
			enchant_stacks += 1
		CardData.Fn.PROJECTILE_COUNT:
			projectile_stacks += 1
		CardData.Fn.BURST_COUNT:
			burst_left += BURST_SHOTS_PER_STACK
		CardData.Fn.HASTE:
			haste_stacks += 1
		CardData.Fn.SLOW:
			slow_stacks += 1
		CardData.Fn.ATTACK_SPEED:
			attack_speed_stacks += 1
		CardData.Fn.COOLDOWN:
			cooldown_stacks += 1
		CardData.Fn.LOOP:
			looping = true
		_:
			# 缺省（NONE）不猜一种运算：老存档里的功能卡载回来就是它，行为与改版前一致（直通）。
			pass


## 这一拍打几段。**只有能力卡**吃子弹数量与连发数量 ——
## 功能卡本身只打一段，否则「连发数量」会把自己再连发一次，余额就永远用不完。
func salvo(card: CardData) -> int:
	if card == null or card.kind != CardData.Kind.ABILITY:
		return 1
	return 1 + projectile_stacks + (1 if burst_left > 0 else 0)


## 这一拍的总价 =（卡面费用 − 冷却减免）× 段数，下限 0。
## 减免按**段**算而不是按次算：冷却说的是「这次施法便宜一点」，三段施法就是三次施法。
func price(card: CardData, hits: int) -> int:
	if card == null:
		return 0
	return maxi(card.mana_cost - cooldown_stacks, 0) * maxi(hits, 0)


## 一次能力卡施放真的打出去了，扣掉一次连发余额。
## **必须在付款成功之后调** —— 付不起的那一拍并没有打出去，扣余额等于白扣。
func consume_burst(card: CardData) -> void:
	if card != null and card.kind == CardData.Kind.ABILITY and burst_left > 0:
		burst_left -= 1


## 每次施法的伤害倍率。
func damage_multiplier() -> float:
	return 1.0 + ENCHANT_PER_STACK * float(enchant_stacks)


## 核心产出的节拍。
func mana_period_ticks(base_ticks: int) -> int:
	return maxi(base_ticks - haste_stacks * HASTE_TICKS_PER_STACK, MIN_MANA_INTERVAL_TICKS)


## 施法节拍。
func cast_interval_ticks(base_ticks: int) -> int:
	return maxi(base_ticks - attack_speed_stacks * ATTACK_SPEED_TICKS_PER_STACK,
		MIN_CAST_INTERVAL_TICKS)


## 本波限时。减速把它推长。
func time_limit_ticks(base_ticks: int) -> int:
	return base_ticks + slow_stacks * SLOW_TICKS_PER_STACK


## 八个通道的**固定顺序**（与文件头那张表同序）。战后详情（BattleReport）与测试都按这一份来 ——
## 各自再排一次，迟早会排成两个样子，而症状只是「某两栏对调了」，肉眼很难发现。
const CHANNEL_FNS: PackedInt32Array = [
	CardData.Fn.ENCHANT,
	CardData.Fn.PROJECTILE_COUNT,
	CardData.Fn.BURST_COUNT,
	CardData.Fn.HASTE,
	CardData.Fn.ATTACK_SPEED,
	CardData.Fn.SLOW,
	CardData.Fn.COOLDOWN,
	CardData.Fn.LOOP,
]


## 每个通道当前的档数，顺序与 CHANNEL_FNS 一致。连发看**余额**、循环看**有没有**（0 / 1）——
## 这两条通道没有「档数」可数，但它们在战后详情里必须各占一格，否则八格只剩六格。
func channel_stacks() -> PackedInt32Array:
	return PackedInt32Array([enchant_stacks, projectile_stacks, burst_left, haste_stacks,
		attack_speed_stacks, slow_stacks, cooldown_stacks, 1 if looping else 0])


## 本波一共上了几档修正。全为 0 = 「什么都没上」。
##
## 八条通道**一条都不能漏**：漏掉的那一条会让「上了连发 / 上了循环」在汇总里读成 0，
## 于是界面说「无加成」而战斗里明明已经生效 —— 数字对不上的那种最难查的毛病。
## 求和走 channel_stacks()，于是汇总与逐条明细读的是同一批字段，不会各说各的。
func total_stacks() -> int:
	var total: int = 0
	for stacks: int in channel_stacks():
		total += stacks
	return total
