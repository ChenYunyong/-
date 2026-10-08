## battle_report.gd
## 职责：一场战斗打完之后的**可查快照** —— 完整有序施法链、八通道逐条明细、施法记录。
## 所属系统：combat
## 依赖：CombatSim（只读它的公开状态）、CombatMods（通道顺序与档数）
## 禁止：本文件不得画东西、不得引用节点 / Palette / RunState；不得被 CombatSim 反向引用 ——
##       它是仿真的**产物**，不是仿真的一部分。
##
## 为什么要有它：`docs/14 §2.3` 的屏上只画得下 4 张卡链，而「完整链条 / 八通道加成保留在
## 战后详情或可访问的日志中，不丢状态」是契约字面（C02）。战斗数据活在 CombatSim 实例里，
## 战斗屏一释放就没了 —— 所以离屏前必须把它**拷出来**存进 RunState，结算屏才有东西可念。
## （PET-93 复核遗留 ①；Codex 在 PET-95 视觉终验里裁定「玩家可访问的战后日志即可」。）

class_name BattleReport
extends RefCounted

## 这一场打完时停在第几波。
var wave: int = 0
## 打完时的结局（CombatSim.Outcome 的值，原样存，不在这里解释）。
var outcome: int = 0
## **完整有序**的施法链卡 id（不是窗口里那 4 张）。
var chain_ids: Array[StringName] = []
## 八通道档数，顺序与 CombatMods.CHANNEL_FNS 一致。
var channels: PackedInt32Array = PackedInt32Array()
## 逐次施放的流水（CombatSim.settlement_log() 原样：表头 + 每段伤害一行）。
var cast_log: PackedStringArray = PackedStringArray()
## 这一场真的打出去了几次。
var casts: int = 0
## 最近一次打出去的那张卡与那一段伤害。**由战斗屏填** —— 它本来就在记这两个数（屏上
## 「当前读数」显示的就是它们），仿真里没有第二份，故不从流水里反解。
var last_card_id: StringName = &""
var last_damage: int = 0


## 从仿真里拷一份快照。**调用点必须在战斗屏释放之前**。
static func capture(sim: CombatSim) -> BattleReport:
	var report: BattleReport = BattleReport.new()
	if sim == null:
		return report
	report.wave = sim.wave()
	report.outcome = int(sim.outcome())
	for card: CardData in sim.cast_order():
		if card != null:
			report.chain_ids.append(card.id)
	report.channels = sim.mods().channel_stacks()
	report.cast_log = sim.settlement_log()
	report.casts = sim.cast_count()
	return report


## 完整链条有几张。战后详情里那串名字的条数就是它 —— UI 与测试问同一个数。
func chain_size() -> int:
	return chain_ids.size()


## 八通道有几条（恒为 8）。写成函数是为了让 UI 与测试都问它，而不是各自写死一个 8。
func channel_count() -> int:
	return channels.size()


## 逐段伤害的行数（流水去掉表头）。
func strike_count() -> int:
	return maxi(cast_log.size() - 1, 0)


## 第 index 张链上卡的 id；越界返回空 id，不编一个出来。
func chain_id_at(index: int) -> StringName:
	if index < 0 or index >= chain_ids.size():
		return &""
	return chain_ids[index]
