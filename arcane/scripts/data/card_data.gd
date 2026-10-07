## card_data.gd
## 职责：一张卡牌的数据形状（docs/02 §5：数值走 Resource，禁止写死在逻辑里）。
## 所属系统：data
## 依赖：无
## 禁止：本文件不得引用 Palette / 场景 / 战斗逻辑 —— 它只是数据。
##       颜色由 CardCatalog.accent_token() 决定（那是「类型 → Token」的映射，属配色决策）。

class_name CardData
extends Resource

## 三大类（用户 2026-10-06 裁定的新分类，取代旧工程的 CORE / FUNCTION / WEAPON）。
enum Kind { CORE, ABILITY, FUNCTION }

## 能力卡九系。
enum Element { NONE, METAL, WOOD, WATER, FIRE, EARTH, THUNDER, WIND, POISON, ICE }

## 功能卡八类。
enum Fn { NONE, HASTE, SLOW, PROJECTILE_COUNT, BURST_COUNT, ENCHANT, LOOP, COOLDOWN, ATTACK_SPEED }

## 卡面图形标记。程序化绘制（新工程不带旧美术），见 scripts/editor/glyph_painter.gd。
##
## PET-87 §1：**一张卡一个符号，18 张卡 18 个值** —— 枚举个数与卡数必须相等，
## 多一个少一个都会让某两张卡重新读成同一个图形（旧版 16 个值撑 18 张卡，
## 「风」与「加速」因此共用 CHEVRON_UP、「雷」与「附魔」共用 STAR）。
## 顺序按三类分组：核心 → 九系能力 → 八类功能，方便肉眼核对。
enum Glyph {
	RING,
	BLADE, LEAF, DROP, FLAME, MOUNTAIN, BOLT, GUST, BUBBLE, SHARD,
	CHEVRONS_UP, CHEVRONS_DOWN, PELLETS, BURST, SPARKLE, LOOP, CLOCK, GEAR,
}

@export var id: StringName = &""
@export var kind: Kind = Kind.ABILITY
@export var element: Element = Element.NONE
@export var function_kind: Fn = Fn.NONE
## 卡名。走 tr()（06 §11：文本必须走 key，不得硬编码在场景中）。
@export var name_key: String = ""
## 作用说明，同样走 tr()。
@export var effect_key: String = ""
@export var glyph: Glyph = Glyph.RING
## 核心卡的魔力产出（每 tick）。
@export var mana_output: int = 0
## 施放这张卡的魔力费用。
@export var mana_cost: int = 0
@export var damage: int = 0
## 是否是核心卡（起点）。等价于 kind == CORE，做成函数是为了让调用点读起来是意图而非比较。
func is_core() -> bool:
	return kind == Kind.CORE
