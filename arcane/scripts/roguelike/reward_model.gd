## reward_model.gd
## 职责：战后奖励的**数据侧唯一落点** —— 三个真选择的抽取、文案，以及「拿一张卡」落到书页上时的接线规则。
## 所属系统：roguelike
## 依赖：CardCatalog, CardData, BoardModel
## 禁止：本文件不得引用节点 / 场景 / Palette（它不画东西）；不得自己取全局随机 ——
##       种子由调用方传入（03 §6），本文件只保证「同一 (种子, 波次) 必然同一组选项」。
##
## 为什么单开一个文件而不是留在 reward_screen 里：抽什么、选中之后书页变成什么样，都是能脱离
## 场景验证的纯逻辑。留在界面文件里的话，「拿了卡下一波真的变了」这条只能靠把界面挂进树才验得了，
## 而它跟界面无关。
##
## 三个选项刻意压在三条**互不重叠**的杠杆上，于是「选项真的有区别」可以分别量出来：
##   拿卡 → 施法队列：多一张卡连到核心，下一波的施放顺序与总伤害都变了
##   强化 → 伤害：本局每次落点 +POWER_DAMAGE
##   供能 → 魔力：本局核心每次产出 +MANA_PER_TICK
##
## 选项池是**有限**的：一张卡拿过就不再出现，强化与供能也各只拿一次 —— 于是「池子被拿空」
## 是一个真实可达的局面（一局里拿满 17 张卡 + 2 个加成），界面对它有一条明确的兜底而不是空白屏。

class_name RewardModel
extends RefCounted

## 奖励的种类。三种各自压一条杠杆，见文件头。
enum Kind { CARD, POWER, MANA }

const OPTION_COUNT: int = 3
## 强化给多少伤害。
const POWER_DAMAGE: int = 2
## 供能给多少魔力。
const MANA_PER_TICK: int = 1

## 非卡牌选项在「已经拿过」那张表里的键。卡用 card_id，加成就用这两个 ——
## 同一张表管住两件事，于是「拿过就不能再拿」只有一条判定。
const KEY_POWER: String = "@power"
const KEY_MANA: String = "@mana"

## 由波次派生种子时的步长。用一个不等于 1 的质数把波次摊开：
## 写成 seed + wave 的话，相邻两波抽出来的组合会高度相关。
const WAVE_STRIDE: int = 7919


## 抽本次奖励的选项。**纯函数**：只吃 (种子, 波次, 可抽的卡, 已经拿过的)。
## 同一局的同一波每次进来都是同一组 —— 不会因为多看了一眼就换牌。
##
## 池子真的空了时返回空数组（不是「凑一个默认项」）：界面据此给兜底。
static func roll(seed_value: int, wave: int, card_ids: PackedStringArray,
		taken: Array) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if not taken.has(KEY_POWER):
		candidates.append({"kind": Kind.POWER})
	if not taken.has(KEY_MANA):
		candidates.append({"kind": Kind.MANA})
	for card_id: String in card_ids:
		if not taken.has(card_id):
			candidates.append({"kind": Kind.CARD, "card_id": StringName(card_id)})

	var picked: Array[Dictionary] = []
	if candidates.is_empty():
		return picked
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = seed_value + wave * WAVE_STRIDE
	# 抽一个删一个：抽出来的天然互不重复，循环也必然终止（不必再写一个防重试的 guard）。
	while picked.size() < OPTION_COUNT and not candidates.is_empty():
		var index: int = generator.randi_range(0, candidates.size() - 1)
		picked.append(candidates[index])
		candidates.remove_at(index)
	return picked


## 可抽的卡：全部**非核心**卡。核心是书页的起点，不该从奖励里抽出来。
static func pool_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for card: CardData in CardCatalog.all():
		if card.kind != CardData.Kind.CORE:
			ids.append(String(card.id))
	return ids


## 这个选项在「已经拿过」表里的键。认不出的选项返回空串。
static func key_of(option: Dictionary) -> String:
	match int(option.get("kind", -1)):
		Kind.CARD:
			return String(option.get("card_id", &""))
		Kind.POWER:
			return KEY_POWER
		Kind.MANA:
			return KEY_MANA
	return ""


static func is_card(option: Dictionary) -> bool:
	return int(option.get("kind", -1)) == Kind.CARD


## 选项在界面上的名字。与 MapView.kind_text 同一条做法：静态函数里没有 tr()，
## 故直接问 TranslationServer —— 与 Node.tr() 是同一条路径，test_i18n 照样扫得到这些字面量。
## 文案与选项的推断放在一起，是为了让「这个选项叫什么」只有一处定义
## —— 奖励屏与结算屏各写一份的话，两处迟早会说岔。
static func name_text(option: Dictionary) -> String:
	if is_card(option):
		var card: CardData = CardCatalog.find(option.get("card_id", &""))
		return TranslationServer.translate(card.name_key) if card != null else ""
	if int(option.get("kind", -1)) == Kind.POWER:
		return TranslationServer.translate("本局强化")
	return TranslationServer.translate("本局供能")


static func detail_text(option: Dictionary) -> String:
	if is_card(option):
		var card: CardData = CardCatalog.find(option.get("card_id", &""))
		return TranslationServer.translate(card.effect_key) if card != null else ""
	if int(option.get("kind", -1)) == Kind.POWER:
		return TranslationServer.translate("所有伤害 +%d") % POWER_DAMAGE
	return TranslationServer.translate("核心产出 +%d 魔力") % MANA_PER_TICK


## 把一张奖励卡接到书页上，并**从核心拉一条丝线到它**。
##
## 只放不连是不够的：CombatSim 的施法队列只收「从核心走得到」的卡，摆在书页上却孤立的那张
## 一次都不会被施放 —— 那样「拿了卡」对下一波毫无影响，奖励就成了摆设（这正是本轮要修的）。
## 书页上还没有核心卡时不连：没有电源，连了也不会施放，如实把卡放好即可。
static func place_card(board: BoardModel, card_id: StringName,
		view_size: Vector2) -> BoardModel.PlacedCard:
	if board == null:
		return null
	var placed: BoardModel.PlacedCard = board.add_card(card_id, board.free_position(view_size))
	var core: BoardModel.PlacedCard = _first_core(board)
	if core != null:
		board.connect_cards(core.uid, placed.uid)
	return placed


static func _first_core(board: BoardModel) -> BoardModel.PlacedCard:
	for placed: BoardModel.PlacedCard in board.cards():
		var data: CardData = placed.data()
		if data != null and data.is_core():
			return placed
	return null
