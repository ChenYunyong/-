## weapon_data.gd
## 职责：武器数值的 Resource 定义（FIRST PLAYABLE 3/4）—— Needle / Bomb / Saw 三把武器的
##       伤害与打击范围（单体 / 全部 / 近身）。数值是**占位平衡**（任务卡「不做平衡」）。
## 所属系统：data
## 依赖：NodeData
## 禁止：本文件不得触碰场景树 / 渲染 / 输入 / Palette —— 它只描述数值；
##       不得结算伤害（结算在 gameplay/combat_simulation.gd）；
##       不得使用 randi() / randf()（03 §6）。
##
## 为什么不给武器加冷却：任务卡只要求「三武器伤害结算」，而三者的差异（单体高频 / 范围 /
## 近身持续）已经由 reach 与 damage 说清。冷却是本卡没要求的东西，加了就要定义
## 「冷却期间开火算不算 Heat」，那是 PET-66 的平衡工作（卡面「不做平衡」）。

class_name WeaponData
extends Resource

enum Kind { NEEDLE, BOMB, SAW }

## 打击范围。三把武器的差异**只在**这两个字段（reach + damage）上 ——
## 结算侧按 reach 分支，不按武器 id 分支，于是加一把武器不必改结算代码。
## 刻意不叫 `range`：那是 GDScript 的内建函数名，同名字段会把它遮住。
enum Reach { SINGLE, ALL, MELEE }

const NEEDLE_DAMAGE: float = 10.0
const BOMB_DAMAGE: float = 25.0
const SAW_DAMAGE: float = 4.0

## Saw 的打击窗口下沿：只有推进进度 ≥ MELEE_FROM 的敌人才在锯的范围内。
## 「近身」= 已经推到战场左侧那一截，而不是整条路径都算（那就不叫近身了）。
const MELEE_FROM: float = 0.7

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.NEEDLE
@export var damage: float = NEEDLE_DAMAGE
@export var reach: Reach = Reach.SINGLE

## 武器节点 display_name → Kind。
##
## **这是一条临时桥，必须删**：NodeData 目前没有「这是哪一把武器」的字段，而带着
## 针 / 炸弹 / 锯 三张槽位的仓库表在 scripts/ui/blueprint_workspace.gd —— 那个文件
## 不在本卡 ALLOWED FILES 内，故本卡只能按工作区落进蓝图里的显示名反查。
## 正确做法是给 NodeData 补一个 weapon_kind 字段、由仓库槽位直接写入（下一张卡）。
## 用中文显示名当键在 I18N（PET-67）时一定会坏：翻译一改，这里就全部落到降级分支。
const BY_DISPLAY_NAME: Dictionary = {
	&"针": Kind.NEEDLE,
	&"炸弹": Kind.BOMB,
	&"锯": Kind.SAW,
}


## 按种类造一份数值。同 EnemyData.for_kind() 的理由：调用方只认 Kind，不认常数名。
static func for_kind(wanted: Kind) -> WeaponData:
	var data := WeaponData.new()
	data.kind = wanted
	match wanted:
		Kind.BOMB:
			data.id = &"bomb"
			data.display_name = "炸弹"
			data.damage = BOMB_DAMAGE
			data.reach = Reach.ALL
		Kind.SAW:
			data.id = &"saw"
			data.display_name = "锯"
			data.damage = SAW_DAMAGE
			data.reach = Reach.MELEE
		_:
			data.id = &"needle"
			data.display_name = "针"
			data.damage = NEEDLE_DAMAGE
			data.reach = Reach.SINGLE
	return data


## 把一个蓝图节点翻译成武器数值。不是武器节点（或空节点）时返回 null ——
## 调用方据此跳过，而不是拿到一把「默认武器」去打不该打的东西。
##
## 显示名认不出来时按 02 §9 降级：push_error() 说清是谁认不出，再落到 Needle。
## 这里不静默返回 null —— 那样玩家的武器会变成「开火但不掉血」，是最难查的一类现象。
## 只在建仿真时走一次，故 push_error 不会刷屏。
static func resolve(node: NodeData) -> WeaponData:
	if node == null or node.kind != NodeData.Kind.WEAPON:
		return null
	if not BY_DISPLAY_NAME.has(node.display_name):
		push_error("WeaponData.resolve: 认不出武器显示名「%s」（节点 id=%s），按 Needle 降级（02 §9）。"
			% [node.display_name, node.id])
		return for_kind(Kind.NEEDLE)
	return for_kind(BY_DISPLAY_NAME[node.display_name])
