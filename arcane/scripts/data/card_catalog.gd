## card_catalog.gd
## 职责：卡牌总表（1 核心 + 9 能力 + 8 功能），以及「类型 → 颜色 Token」的唯一映射。
## 所属系统：data
## 依赖：CardData, Palette
## 禁止：本文件不得引用场景 / UI / 战斗逻辑 —— 它是纯查表。
##
## PET-85：卡牌分类与命名取自用户 2026-10-06 的裁定
## （核心卡 / 能力卡 9 系「金木水火土雷风毒冰」/ 功能卡 8 类）。
##
## ⚠ 已知取舍（PET-87 §1 的口径，未改动任何 Token）：能力卡 9 系**各配一个色**；
## 功能卡 8 类**共用同一类型色**，靠**图形标记**区分。理由：现有 35 个 Token 里 UI 可用的
## 可区分色支撑不到 9+8 个互不混淆的类别，而 `04 §4.4`（同用途不得近似色）与
## `13 §10.1`（类型色只做小面积、不得把界面做成彩虹色）都是硬约束。扩色板属 GATE。
##
## 由此带来的两条实测事实（PET-87 交付说明里逐项报过，此处留档以免后人重新发现一次）：
##   1. 水/雷/风/冰 四系的 Token 挤在同一个蓝色族里（风 BLUE_300 与功能卡兜底色**同值**），
##      所以「颜色即类型」在这一族里**不成立** —— 辨识必须靠符号，颜色只是辅助。
##      这正是 PET-87 把卡面识别手段从「一圈彩边」换成「独立符号 + 小面积徽记」的原因。
##   2. 九系里 BROWN_400（土）对 NAVY_800 的对比度只有 1.79:1、ORANGE_600（毒）2.96:1 ——
##      小面积徽记上这两个色偏弱。**不改**（改色要动 palette.tres，属 DSH 专属 / GATE）。

class_name CardCatalog
extends RefCounted

## 「类型 → 颜色」的唯一落点。任何地方要画类型色都必须经这里（04 §7：不得零散覆盖颜色）。
## CORE 用 GOLD_400、ABILITY 以其九系色、FUNCTION 统一 BLUE_300。
const KIND_ACCENT: Dictionary = {
	CardData.Kind.CORE: Palette.Key.GOLD_400,
	CardData.Kind.ABILITY: Palette.Key.BLUE_500,
	CardData.Kind.FUNCTION: Palette.Key.BLUE_300,
}

## 能力卡九系 → Token。九个色都在 04 §3 已登记且 UI 可用域为 ✅，
## 刻意避开 BLUE_FX_600（04 §3.10：FX 专用，禁止用于 UI / 图标）。
const ELEMENT_ACCENT: Dictionary = {
	CardData.Element.METAL: Palette.Key.GOLD_500,
	CardData.Element.WOOD: Palette.Key.BROWN_200,
	CardData.Element.WATER: Palette.Key.BLUE_500,
	CardData.Element.FIRE: Palette.Key.ORANGE_500,
	CardData.Element.EARTH: Palette.Key.BROWN_400,
	CardData.Element.THUNDER: Palette.Key.BLUE_050,
	CardData.Element.WIND: Palette.Key.BLUE_300,
	CardData.Element.POISON: Palette.Key.ORANGE_600,
	CardData.Element.ICE: Palette.Key.BLUE_400,
}

## 元素 / 功能 的显示名 key（走 tr()）。
const ELEMENT_NAME_KEY: Dictionary = {
	CardData.Element.METAL: "金", CardData.Element.WOOD: "木",
	CardData.Element.WATER: "水", CardData.Element.FIRE: "火",
	CardData.Element.EARTH: "土", CardData.Element.THUNDER: "雷",
	CardData.Element.WIND: "风", CardData.Element.POISON: "毒",
	CardData.Element.ICE: "冰",
}

const FUNCTION_NAME_KEY: Dictionary = {
	CardData.Fn.HASTE: "加速", CardData.Fn.SLOW: "减速",
	CardData.Fn.PROJECTILE_COUNT: "子弹数量", CardData.Fn.BURST_COUNT: "连发数量",
	CardData.Fn.ENCHANT: "附魔", CardData.Fn.LOOP: "循环",
	CardData.Fn.COOLDOWN: "冷却", CardData.Fn.ATTACK_SPEED: "攻速",
}

const KIND_NAME_KEY: Dictionary = {
	CardData.Kind.CORE: "核心卡",
	CardData.Kind.ABILITY: "能力卡",
	CardData.Kind.FUNCTION: "功能卡",
}

## 卡面上那一个短标记（tr() key）。72×72 的画布卡片塞不下全名，标记是「一眼认牌」的唯一手段。
const MARK_CORE: String = "核心"

## 功能卡的标记例外表。绝大多数功能卡的全名本身就是 2 字（加速 / 减速 / 连发 / 附魔 /
## 循环 / 冷却 / 攻速），直接当标记用；只有「子弹数量」4 字放不下，缩成「子弹」。
## 之所以是一条规则 + 一张例外表，而不是 18 行的全表：能力卡与核心卡的标记本就有推导规则
## （元素名 / 固定词），照抄一遍只会多一处要同步维护的地方。
const FUNCTION_MARK_OVERRIDE: Dictionary = {
	CardData.Fn.PROJECTILE_COUNT: "子弹",
}

## 卡牌总表的唯一事实来源。id 是存档与连线引用的稳定键，改名不得改 id。
## 数值刻意简单：FIRST PLAYABLE 的玩法重心在「自由摆放 + 连线」，不在数值平衡。
const TABLE: Array[Dictionary] = [
	{"id": &"core_arcane", "kind": CardData.Kind.CORE, "name": "奥术核心", "effect": "魔力产出",
		"glyph": CardData.Glyph.RING, "mana_output": 2},
	{"id": &"ab_metal", "kind": CardData.Kind.ABILITY, "element": CardData.Element.METAL,
		"name": "锐金弹", "effect": "伤害", "glyph": CardData.Glyph.BLADE, "mana_cost": 2, "damage": 6},
	{"id": &"ab_wood", "kind": CardData.Kind.ABILITY, "element": CardData.Element.WOOD,
		"name": "藤蔓缚", "effect": "伤害", "glyph": CardData.Glyph.LEAF, "mana_cost": 2, "damage": 4},
	{"id": &"ab_water", "kind": CardData.Kind.ABILITY, "element": CardData.Element.WATER,
		"name": "寒水矢", "effect": "伤害", "glyph": CardData.Glyph.DROP, "mana_cost": 2, "damage": 5},
	{"id": &"ab_fire", "kind": CardData.Kind.ABILITY, "element": CardData.Element.FIRE,
		"name": "烈焰球", "effect": "伤害", "glyph": CardData.Glyph.FLAME, "mana_cost": 3, "damage": 9},
	{"id": &"ab_earth", "kind": CardData.Kind.ABILITY, "element": CardData.Element.EARTH,
		"name": "磐石击", "effect": "伤害", "glyph": CardData.Glyph.MOUNTAIN, "mana_cost": 3, "damage": 8},
	{"id": &"ab_thunder", "kind": CardData.Kind.ABILITY, "element": CardData.Element.THUNDER,
		"name": "紫电链", "effect": "伤害", "glyph": CardData.Glyph.BOLT, "mana_cost": 3, "damage": 7},
	{"id": &"ab_wind", "kind": CardData.Kind.ABILITY, "element": CardData.Element.WIND,
		"name": "疾风刃", "effect": "伤害", "glyph": CardData.Glyph.GUST, "mana_cost": 1, "damage": 3},
	{"id": &"ab_poison", "kind": CardData.Kind.ABILITY, "element": CardData.Element.POISON,
		"name": "腐毒云", "effect": "伤害", "glyph": CardData.Glyph.BUBBLE, "mana_cost": 2, "damage": 4},
	{"id": &"ab_ice", "kind": CardData.Kind.ABILITY, "element": CardData.Element.ICE,
		"name": "霜棱刺", "effect": "伤害", "glyph": CardData.Glyph.SHARD, "mana_cost": 2, "damage": 5},
	{"id": &"fn_haste", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.HASTE,
		"name": "加速", "effect": "效果", "glyph": CardData.Glyph.CHEVRONS_UP, "mana_cost": 1},
	{"id": &"fn_slow", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.SLOW,
		"name": "减速", "effect": "效果", "glyph": CardData.Glyph.CHEVRONS_DOWN, "mana_cost": 1},
	{"id": &"fn_projectile", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.PROJECTILE_COUNT,
		"name": "子弹数量", "effect": "效果", "glyph": CardData.Glyph.PELLETS, "mana_cost": 2},
	{"id": &"fn_burst", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.BURST_COUNT,
		"name": "连发数量", "effect": "效果", "glyph": CardData.Glyph.BURST, "mana_cost": 2},
	{"id": &"fn_enchant", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.ENCHANT,
		"name": "附魔", "effect": "效果", "glyph": CardData.Glyph.SPARKLE, "mana_cost": 2},
	{"id": &"fn_loop", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.LOOP,
		"name": "循环", "effect": "效果", "glyph": CardData.Glyph.LOOP, "mana_cost": 2},
	{"id": &"fn_cooldown", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.COOLDOWN,
		"name": "冷却", "effect": "效果", "glyph": CardData.Glyph.CLOCK, "mana_cost": 1},
	{"id": &"fn_attack_speed", "kind": CardData.Kind.FUNCTION, "fn": CardData.Fn.ATTACK_SPEED,
		"name": "攻速", "effect": "效果", "glyph": CardData.Glyph.GEAR, "mana_cost": 1},
]

static var _cache: Array[CardData] = []


## 全部卡牌。首次调用时建表，之后复用（表是常量，不会变）。
static func all() -> Array[CardData]:
	if _cache.is_empty():
		_build()
	return _cache


static func by_kind(kind: CardData.Kind) -> Array[CardData]:
	var result: Array[CardData] = []
	for card: CardData in all():
		if card.kind == kind:
			result.append(card)
	return result


## 按 id 取卡。找不到返回 null —— 调用方必须处理（02 §9：资源缺失不得静默崩溃）。
static func find(id: StringName) -> CardData:
	for card: CardData in all():
		if card.id == id:
			return card
	return null


## 这张卡的类型色 Token。**颜色即类型**的唯一落点（04 §7）。
static func accent_token(card: CardData) -> Palette.Key:
	if card == null:
		return Palette.Key.GREY_500
	if card.kind == CardData.Kind.ABILITY and ELEMENT_ACCENT.has(card.element):
		return ELEMENT_ACCENT[card.element]
	return KIND_ACCENT.get(card.kind, Palette.Key.GREY_500)


## 这张卡的类型色。
static func accent_color(card: CardData) -> Color:
	return Palette.get_color(accent_token(card))


## 类别标签的 tr() key（详情面板用）。
static func type_label_key(card: CardData) -> String:
	if card == null:
		return ""
	if card.kind == CardData.Kind.ABILITY:
		return String(ELEMENT_NAME_KEY.get(card.element, "能力"))
	if card.kind == CardData.Kind.FUNCTION:
		return String(FUNCTION_NAME_KEY.get(card.function_kind, "功能"))
	return String(KIND_NAME_KEY.get(card.kind, ""))


## 卡面短标记的 tr() key。三类各有出处：核心 = 固定词，能力 = 元素名，功能 = 全名（可覆盖）。
static func mark_key(card: CardData) -> String:
	if card == null:
		return ""
	if card.kind == CardData.Kind.CORE:
		return MARK_CORE
	if card.kind == CardData.Kind.ABILITY:
		return String(ELEMENT_NAME_KEY.get(card.element, ""))
	if FUNCTION_MARK_OVERRIDE.has(card.function_kind):
		return String(FUNCTION_MARK_OVERRIDE[card.function_kind])
	return String(FUNCTION_NAME_KEY.get(card.function_kind, ""))


## 大类标签的 tr() key。
static func kind_label_key(card: CardData) -> String:
	if card == null:
		return ""
	return String(KIND_NAME_KEY.get(card.kind, ""))


static func _build() -> void:
	_cache = []
	for row: Dictionary in TABLE:
		var card: CardData = CardData.new()
		card.id = row["id"]
		card.kind = row["kind"]
		card.element = row.get("element", CardData.Element.NONE)
		card.function_kind = row.get("fn", CardData.Fn.NONE)
		card.name_key = row["name"]
		card.effect_key = row["effect"]
		card.glyph = row["glyph"]
		card.mana_output = int(row.get("mana_output", 0))
		card.mana_cost = int(row.get("mana_cost", 0))
		card.damage = int(row.get("damage", 0))
		_cache.append(card)
