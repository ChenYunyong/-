## test_catalog.gd
## 职责：卡牌总表的验收 —— 1 核心 + 9 能力 + 8 功能，以及「类型 → 颜色」的唯一映射。
## 所属系统：tests
## 依赖：CardCatalog, CardData, Palette
## 禁止：本文件不得写入卡表，只断言。

extends RefCounted

## PET-85 用户裁定：核心卡 1 张、能力卡九系（金木水火土雷风毒冰）、功能卡八类。
const EXPECTED_CORE: int = 1
const EXPECTED_ABILITY: int = 9
const EXPECTED_FUNCTION: int = 8
const EXPECTED_TOTAL: int = EXPECTED_CORE + EXPECTED_ABILITY + EXPECTED_FUNCTION


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_catalog")
	_check_counts(ctx)
	_check_identity(ctx)
	_check_numbers(ctx)
	_check_type_colors(ctx)
	_check_gameplay_keys(ctx)


func _check_counts(ctx: RefCounted) -> void:
	ctx.equal(CardCatalog.all().size(), EXPECTED_TOTAL, "总卡数 %d" % EXPECTED_TOTAL)
	ctx.equal(CardCatalog.by_kind(CardData.Kind.CORE).size(), EXPECTED_CORE, "核心卡 1 张")
	ctx.equal(CardCatalog.by_kind(CardData.Kind.ABILITY).size(), EXPECTED_ABILITY, "能力卡 9 系")
	ctx.equal(CardCatalog.by_kind(CardData.Kind.FUNCTION).size(), EXPECTED_FUNCTION, "功能卡 8 类")
	ctx.equal(CardCatalog.by_kind(CardData.Kind.CORE).size()
		+ CardCatalog.by_kind(CardData.Kind.ABILITY).size()
		+ CardCatalog.by_kind(CardData.Kind.FUNCTION).size(), CardCatalog.all().size(),
		"三类之和 = 总数（没有归属不明的卡）")


## id 是存档与连线引用的稳定键：必须唯一、非空，且 find() 能原样取回。
func _check_identity(ctx: RefCounted) -> void:
	var seen: Dictionary = {}
	var duplicated: PackedStringArray = PackedStringArray()
	for card: CardData in CardCatalog.all():
		ctx.check(card.id != &"", "卡牌 id 非空")
		if seen.has(card.id):
			duplicated.append(String(card.id))
		seen[card.id] = true
		ctx.check(CardCatalog.find(card.id) == card, "find(%s) 取回同一张卡" % card.id)
		ctx.check(card.name_key != "", "%s 有名字" % card.id)
		ctx.check(card.effect_key != "", "%s 有效果说明" % card.id)
	ctx.equal(duplicated.size(), 0,
		"卡牌 id 唯一" if duplicated.is_empty() else "重复 id：%s" % ", ".join(duplicated))
	ctx.check(CardCatalog.find(&"nope_not_here") == null, "查不到的 id 返回 null（不崩、不返回假卡）")


## 数值刻意简单，但必须自洽：核心产魔力、能力卡有伤害、功能卡是纯效果。
func _check_numbers(ctx: RefCounted) -> void:
	for card: CardData in CardCatalog.by_kind(CardData.Kind.CORE):
		ctx.check(card.mana_output > 0, "核心卡 %s 产出魔力" % card.id)
		ctx.check(card.mana_cost == 0, "核心卡 %s 自己不耗魔力" % card.id)
	for card: CardData in CardCatalog.by_kind(CardData.Kind.ABILITY):
		ctx.check(card.damage > 0, "能力卡 %s 有伤害" % card.id)
		ctx.check(card.mana_cost > 0, "能力卡 %s 要花魔力" % card.id)
	for card: CardData in CardCatalog.by_kind(CardData.Kind.FUNCTION):
		ctx.check(card.damage == 0, "功能卡 %s 不直接造成伤害" % card.id)
		ctx.check(card.mana_cost > 0, "功能卡 %s 要花魔力" % card.id)
	# 只有一张核心卡：它同时是「电源」和「起点」，多了会让连线拓扑失去唯一源头。
	ctx.equal(CardCatalog.by_kind(CardData.Kind.CORE).size(), 1, "核心卡只有一张（唯一电源）")
	# 九系元素各不相同 —— 两个系共用一个色就失去了「颜色即类型」的意义。
	var elements: Dictionary = {}
	for card: CardData in CardCatalog.by_kind(CardData.Kind.ABILITY):
		ctx.check(not elements.has(card.element), "元素 %s 只出现一次" % card.element)
		elements[card.element] = card.id
	ctx.equal(elements.size(), EXPECTED_ABILITY, "九个元素各一张")
	var functions: Dictionary = {}
	for card: CardData in CardCatalog.by_kind(CardData.Kind.FUNCTION):
		ctx.check(not functions.has(card.function_kind), "功能 %s 只出现一次" % card.function_kind)
		functions[card.function_kind] = card.id
	ctx.equal(functions.size(), EXPECTED_FUNCTION, "八个功能各一张")


## 04 §7「颜色即类型」的唯一落点：类型色必须查得到、不许缺失、不许用 FX 专用色。
func _check_type_colors(ctx: RefCounted) -> void:
	var missing: PackedStringArray = PackedStringArray()
	for card: CardData in CardCatalog.all():
		var token: Palette.Key = CardCatalog.accent_token(card)
		if not Palette.get_palette().has_token(token):
			missing.append(String(card.id))
			continue
		var color: Color = CardCatalog.accent_color(card)
		if color == Palette.MISSING_COLOR:
			missing.append(String(card.id))
			continue
		# 04 §3.10：BLUE_FX_600 是特效专用，UI 与图标一律禁用。
		ctx.check(token != Palette.Key.BLUE_FX_600, "卡牌 %s 没用 FX 专用色" % card.id)
	ctx.equal(missing.size(), 0,
		"每张卡都有查得到的类型色" if missing.is_empty() else "类型色缺失：%s" % ", ".join(missing))
	# 反向对照：空卡不得被当成合法卡蒙混过关。
	ctx.equal(CardCatalog.accent_token(null), Palette.Key.GREY_500, "反向对照：空卡给出醒目的兜底色")
	ctx.equal(CardCatalog.accent_color(null), Palette.get_color(Palette.Key.GREY_500),
		"反向对照：空卡兜底色来自 Palette，不是硬编码值")


## 卡面短标记与详情标签都必须有出处 —— 卡面上唯一能「一眼认牌」的东西就是它。
func _check_gameplay_keys(ctx: RefCounted) -> void:
	var empty_mark: PackedStringArray = PackedStringArray()
	var empty_label: PackedStringArray = PackedStringArray()
	for card: CardData in CardCatalog.all():
		if CardCatalog.mark_key(card) == "":
			empty_mark.append(String(card.id))
		if CardCatalog.type_label_key(card) == "":
			empty_label.append(String(card.id))
	ctx.equal(empty_mark.size(), 0,
		"每张卡都有卡面标记" if empty_mark.is_empty() else "缺标记：%s" % ", ".join(empty_mark))
	ctx.equal(empty_label.size(), 0,
		"每张卡都有类型标签" if empty_label.is_empty() else "缺类型标签：%s" % ", ".join(empty_label))
	ctx.equal(CardCatalog.mark_key(null), "", "反向对照：空卡的标记是空串")
	ctx.equal(CardCatalog.type_label_key(null), "", "反向对照：空卡的类型标签是空串")
