## result_screen.gd
## 职责：结算屏 —— 说清这一局是怎么结束的（通关 / 本局结束）、到过几层、拿了什么，
##       并给出两条出口：回到主菜单、再来一局。
## 所属系统：ui
## 依赖：ResultLayout, RewardModel, RunState, GameFlow, UiKit, ArcaneTheme, ContractScreenTheme,
##       CardCatalog, BattleReport
## 禁止：本文件不得自己换场景（R3）；不得自己算「到过几层」「拿了什么」（在 RunState 里）；
##       不得出现裸色值；不得在这里开始新的一局时**跳过** RunState.start_run() ——
##       那样「再来一局」出来的会是上一局的残余（同一个种子、同一张图）。
##
## 屏幕上每个字都从 RunState 读，不接任何参数：结算是**这一局**的结算，
## 而「这一局」只存在于 RunState 里。传参进来会让「界面显示的」与「真实发生的」分成两份。
##
## 「到过几层」与「本局所得」是这一屏存在的理由：只说一句「你输了」等于什么都没说 ——
## 玩家要能知道自己走到了哪、把什么带到了这一步。
##
## PET-94 复核：又多了一块「战后详情」板（`docs/14 §2.3` 的 C02）—— 战斗屏只画得下 4 张卡链，
## 完整链 / 八通道逐条 / 施法记录由战斗屏在释放前交进 RunState（BattleReport），本屏只负责念。

extends Control


func _ready() -> void:
	var victory: bool = RunState.result() == RunState.Result.VICTORY

	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, ResultLayout.SUMMARY_RECT))
	# 标题居中，其余左对齐 —— 结果那一句是这一屏的招牌，账目三行是要读的。
	_add_label(tr("通关") if victory else tr("本局结束"), ResultLayout.TITLE_RECT,
		ArcaneTheme.TYPE_LABEL_TITLE, true)
	_add_label(_progress_text(), ResultLayout.PROGRESS_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	_add_label(tr("本局所得"), ResultLayout.LEDGER_TITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	_add_label(_ledger_text(), ResultLayout.LEDGER_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY, false, true)

	_build_detail()
	_build_buttons()



func _build_buttons() -> void:
	var handlers: Array[Callable] = [_on_menu, _on_again]
	var keys: PackedStringArray = [ResultLayout.KEY_MENU, ResultLayout.KEY_AGAIN]
	var rects: Array[Rect2] = ResultLayout.button_rects()
	for index: int in keys.size():
		var variation: StringName = ArcaneTheme.TYPE_BUTTON_SECONDARY
		if keys[index] == ResultLayout.KEY_PRIMARY:
			variation = ArcaneTheme.TYPE_BUTTON_PRIMARY
		var button: Button = UiKit.button(keys[index], variation, handlers[index])
		button.position = rects[index].position
		button.size = rects[index].size
		add_child(button)


## 结算屏自己建的 Label。落点由 ResultLayout 定；纵向一律居中。
## centered 只给标题用，wrap 只给那串可能很长、必须折行的清单用。
func _add_label(text: String, rect: Rect2, variation: StringName,
		centered: bool = false, wrap: bool = false) -> void:
	var node: Label = UiKit.wrapped_label(text, rect, variation) if wrap else UiKit.label(text, rect, variation)
	# 折行的清单从上往下排（居中会让第一项随着项数上下跳），单行文字在块里纵向居中。
	node.vertical_alignment = VERTICAL_ALIGNMENT_TOP if wrap else VERTICAL_ALIGNMENT_CENTER
	if centered:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(node)


# ------------------------------------------------------------------ 账目

## 「到过几层」。还没出发时如实说「还没出发」，而不是报一个「到过 0 层」。
func _progress_text() -> String:
	var tiers: int = RunState.tiers_seen()
	if tiers <= 0:
		return tr("还没出发")
	return tr("到过 %d 层") % tiers


## 「本局所得」清单。空手而归时给一句明确的话，不留空白 ——
## 空白会被读成「这一行没加载出来」。
func _ledger_text() -> String:
	var taken: Array[Dictionary] = RunState.taken_rewards()
	if taken.is_empty():
		return tr("什么都没拿")
	var names: PackedStringArray = PackedStringArray()
	for option: Dictionary in taken:
		names.append(RewardModel.name_text(option))
	return " · ".join(names)


# ------------------------------------------------------------------ 战后详情（PET-94 复核 C02）

## 最后一场战斗的完整账：完整有序链 / 八通道逐条 / 施法记录。念的是 RunState 里那份**快照**，
## 不是战斗对象 —— 战斗数据随战斗屏一起没了。没打过战斗就如实说一句，不画一块空板。
func _build_detail() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, ResultLayout.DETAIL_RECT))
	_add_label(tr("战后详情"), ResultLayout.DETAIL_TITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	var report: BattleReport = RunState.last_battle_report()
	if report == null:
		_add_label(tr("还没打过一场战斗"), ResultLayout.DETAIL_CHAIN_RECT,
			ContractScreenTheme.TYPE_LABEL_CAPTION, false, true)
		return
	_add_label(_chain_text(report), ResultLayout.DETAIL_CHAIN_RECT,
		ContractScreenTheme.TYPE_LABEL_CAPTION, false, true)
	_add_label(_channel_text(report), ResultLayout.DETAIL_CHANNEL_RECT,
		ContractScreenTheme.TYPE_LABEL_CAPTION, false, true)
	_add_label(_cast_text(report), ResultLayout.DETAIL_CAST_RECT,
		ContractScreenTheme.TYPE_LABEL_CAPTION, false, true)


## **完整**链条，一张不省：战斗屏那 4 张是窗口，这里才是全链（C02「其余链信息仍可查」）。
func _chain_text(report: BattleReport) -> String:
	if report.chain_size() <= 0:
		return tr("链条为空")
	var names: PackedStringArray = PackedStringArray()
	for index: int in report.chain_size():
		names.append(_card_name(report.chain_id_at(index)))
	return "%s %s" % [tr("完整施法链 %d 张") % report.chain_size(), " → ".join(names)]


## 八通道逐条明细。顺序取 CombatMods.CHANNEL_FNS（那八条的**单一出处**）——
## 这里再排一次的话，某天两处排成两个样子，症状只是「某两栏对调了」。
func _channel_text(report: BattleReport) -> String:
	var fns: PackedInt32Array = CombatMods.CHANNEL_FNS
	var parts: PackedStringArray = PackedStringArray()
	for index: int in mini(report.channel_count(), fns.size()):
		var label: String = CardCatalog.FUNCTION_NAME_KEY.get(int(fns[index]), "")
		parts.append("%s %d" % [tr(label), report.channels[index]])
	return "%s %s" % [tr("八通道明细"), " · ".join(parts)]


## 施法记录：打了几次、几段伤害、最近一次是谁打了多少。逐行流水**留在快照里**，不在这块板上
## 铺开 —— 它会有几十行，铺开会把这一屏变成一张日志表；屏上给的是结论与最近一次。
func _cast_text(report: BattleReport) -> String:
	var tail: String = ""
	if report.last_card_id != &"":
		tail = " · %s %s %d" % [tr("最近一次"), _card_name(report.last_card_id), report.last_damage]
	return "%s · %s%s" % [tr("施法记录 %d 次") % report.casts,
		tr("%d 段伤害") % report.strike_count(), tail]


## 卡 id → 显示名。查不到时不编一个名字（C05：缺字段不伪造）。
func _card_name(card_id: StringName) -> String:
	var card: CardData = CardCatalog.find(card_id)
	return tr(card.name_key) if card != null else tr("未知卡")


# ------------------------------------------------------------------ 两条出口

## 回主菜单：结算屏 → 主菜单是唯一一条回得去的路（PET-92 §4）。
## 这一局已经结束（RunState 那边已落账），所以主菜单上的「继续」此刻是灰的、并说明原因。
func _on_menu() -> void:
	GameFlow.change_state(GameFlow.GameState.MAIN_MENU)


## 再来一局：**先开新的一局再走**（与主菜单的「开始新一局」同一条顺序）——
## 新种子 ⇒ 新地图、新卡表；漏掉 start_run() 的话出来的是上一局的残余。
func _on_again() -> void:
	RunState.start_run()
	GameFlow.change_state(GameFlow.GameState.EDITOR)
