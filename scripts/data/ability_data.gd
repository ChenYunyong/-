## ability_data.gd
## 职责：能力卡数值的 Resource 定义（PET-82 MAGIC-01，原 weapon_data.gd → ability_data.gd）——
##       九系元素（金 / 木 / 水 / 火 / 土 / 雷 / 风 / 毒 / 冰）的伤害与打击范围（单体 / 全部 / 近身）。
## 所属系统：data
## 依赖：NodeData
## 禁止：本文件不得触碰场景树 / 渲染 / 输入 / Palette —— 它只描述数值；
##       不得结算伤害（结算在 gameplay/combat_simulation.gd）；
##       不得使用 randi() / randf()（03 §6）。
##
## **九系目前共用三种手感**：用户 2026-10-06 给了九系的**名字**，没有给每系的数值。
## 本卡（「只做一波可玩」）不自行发明九套平衡，而是把九系按亲和分到既有的三种打击形态上
## —— 单体 / 全场 / 近身，每系仍然**真的能打、真的掉血**。每系的独立数值等用户定；
## 定下来时只改下面那张 _TABLE，结算侧一行都不用动（结算按 reach 分支，不按元素分支）。
##
## 为什么不给能力卡加冷却：任务卡只要求「伤害结算」，而九系的差异已经由 reach 与 damage 说清。
## 冷却是本卡没要求的东西，加了就要定义「冷却期间的施放算不算魔力消耗」——
## 那会把刚立起来的「一次施法一次扣魔」这条唯一规则搅浑。

class_name AbilityData
extends Resource

## 与 NodeData.Ability 逐项对应（NodeData 那边多一个 NONE 兼作缺省值与降级入口）。
## **不得重排**：理由同 NodeData.Kind —— 两边的对应关系由 tests/unit/test_combat_damage.gd 钉住。
enum Kind { METAL, WOOD, WATER, FIRE, EARTH, THUNDER, WIND, POISON, ICE }

## 打击范围。九系的差异**只在**这两个字段（reach + damage）上 ——
## 结算侧按 reach 分支，不按元素 id 分支，于是加一系元素不必改结算代码。
## 刻意不叫 `range`：那是 GDScript 的内建函数名，同名字段会把它遮住。
enum Reach { SINGLE, ALL, MELEE }

const SINGLE_DAMAGE: float = 10.0
const ALL_DAMAGE: float = 25.0
const MELEE_DAMAGE: float = 4.0

## 近身形态的打击窗口下沿：只有推进进度 ≥ MELEE_FROM 的敌人才在范围内。
## 「近身」= 已经推到战场左侧那一截，而不是整条路径都算（那就不叫近身了）。
const MELEE_FROM: float = 0.7

## 降级落点：缺字段 / 认不出的取值（旧存档）一律落到它。取**最弱**的那一系（单体 / 10），
## 而不是「随手指一系」—— 降级不该让玩家的法术书凭空变强（02 §9）。
const FALLBACK: Kind = Kind.ICE

## 九系 -> (id, 显示名, 伤害, 形态)。**唯一一处**九系数值的定义，别处一律从这里取。
## 三条注释说的是「为什么这一系落在这一形态上」，不是数值依据 —— 数值是占位（见文件头）。
const _TABLE: Dictionary = {
	Kind.METAL: {"id": &"metal", "name": "金", "damage": SINGLE_DAMAGE, "reach": Reach.SINGLE},
	Kind.WOOD: {"id": &"wood", "name": "木", "damage": MELEE_DAMAGE, "reach": Reach.MELEE},
	Kind.WATER: {"id": &"water", "name": "水", "damage": SINGLE_DAMAGE, "reach": Reach.SINGLE},
	Kind.FIRE: {"id": &"fire", "name": "火", "damage": ALL_DAMAGE, "reach": Reach.ALL},
	Kind.EARTH: {"id": &"earth", "name": "土", "damage": MELEE_DAMAGE, "reach": Reach.MELEE},
	Kind.THUNDER: {"id": &"thunder", "name": "雷", "damage": MELEE_DAMAGE, "reach": Reach.MELEE},
	Kind.WIND: {"id": &"wind", "name": "风", "damage": MELEE_DAMAGE, "reach": Reach.MELEE},
	Kind.POISON: {"id": &"poison", "name": "毒", "damage": ALL_DAMAGE, "reach": Reach.ALL},
	Kind.ICE: {"id": &"ice", "name": "冰", "damage": SINGLE_DAMAGE, "reach": Reach.SINGLE},
}

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = FALLBACK
@export var damage: float = SINGLE_DAMAGE
@export var reach: Reach = Reach.SINGLE

## 按种类造一份数值。同 EnemyData.for_kind() 的理由：调用方只认 Kind，不认常数名。
static func for_kind(wanted: Kind) -> AbilityData:
	var data := AbilityData.new()
	var row: Dictionary = _TABLE[wanted]
	data.kind = wanted
	data.id = row["id"]
	data.display_name = row["name"]
	data.damage = row["damage"]
	data.reach = row["reach"]
	return data


## 把一张能力卡节点翻译成数值。不是能力卡节点（或空节点）时返回 null ——
## 调用方据此跳过，而不是拿到一个「默认元素」去打不该打的东西。
##
## 种类取自 NodeData.weapon_kind（由法术书槽位在落节点时直接写入）。**不再按显示名反查** ——
## 显示名是给玩家看的、会随 I18N 变，拿它当键在翻译一改时就整表落空。
##
## 种类为 NONE（旧存档写于该字段存在之前 / 认不出的取值）时按 02 §9 降级：
## push_error() 说清是哪个节点，再落到 FALLBACK（冰，单体 / 10）。**不能降成 null** ——
## 那样玩家的能力卡会变成「施放但不掉血」，是最难查的一类现象；也不能崩，旧存档必须仍能载入。
## 只在建仿真时走一次，故 push_error 不会刷屏。
static func resolve(node: NodeData) -> AbilityData:
	if node == null or node.kind != NodeData.Kind.ABILITY:
		return null
	# NodeData.Ability 比本枚举多一个排在最前面的 NONE，故两边差 1。
	# 刻意不用 `int -> Kind` 的强转：GDScript 的静态检查不接受把裸整数塞进枚举变量，
	# 而这里绕开它的代价只是多比一次。
	for kind: Kind in _TABLE:
		if int(node.weapon_kind) == int(kind) + 1:
			return for_kind(kind)
	push_error("AbilityData.resolve: 节点 %s 的 weapon_kind 为 NONE 或认不出的取值（旧存档？），按 %s 降级（02 §9）。"
		% [node.id, _TABLE[FALLBACK]["name"]])
	return for_kind(FALLBACK)
