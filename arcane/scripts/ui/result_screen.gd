## result_screen.gd
## 职责：结算屏 —— 说清这一局是怎么结束的（通关 / 本局结束）、到过几层、拿了什么，
##       并给出两条出口：回到主菜单、再来一局。
## 所属系统：ui
## 依赖：ResultLayout, RewardModel, RunState, GameFlow, UiKit, ArcaneTheme
## 禁止：本文件不得自己换场景（R3）；不得自己算「到过几层」「拿了什么」（在 RunState 里）；
##       不得出现裸色值；不得在这里开始新的一局时**跳过** RunState.start_run() ——
##       那样「再来一局」出来的会是上一局的残余（同一个种子、同一张图）。
##
## 屏幕上每个字都从 RunState 读，不接任何参数：结算是**这一局**的结算，
## 而「这一局」只存在于 RunState 里。传参进来会让「界面显示的」与「真实发生的」分成两份。
##
## 「到过几层」与「本局所得」是这一屏存在的理由：只说一句「你输了」等于什么都没说 ——
## 玩家要能知道自己走到了哪、把什么带到了这一步。

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
