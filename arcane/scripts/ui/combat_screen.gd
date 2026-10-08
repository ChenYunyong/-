## combat_screen.gd
## 职责：自动施法战斗屏 —— 把书页交给 CombatSim 按固定步长推进，并把状态画出来：
##       战场（CombatView）/ 头栏四条读数 / 施法链（CombatChain）/ 当前读数 / 本波加成 / 本场结果。
## 所属系统：ui
## 依赖：CombatSim, CombatMods, BattleReport, CombatView, CombatChain, CombatLayout, CombatTheme,
##       ContractTheme, ContractScreenTheme, CardCatalog, RunState, GameFlow, UiKit
## 禁止：本文件不得含战斗规则（在 CombatSim / CombatMods 里）；不得自己换场景（R3）；
##       不得改写书页 —— 战斗只读它（03 §4.3）；不得出现裸色值（本屏自己画的东西一律经
##       CombatTheme 的角色表，文字与面板底走 Theme 的类型变体）。
##
## PET-93 屏③（docs/14 §2.3）：头栏 56 / 纸框 312 / 底栏 116，卡链下移到尾栏（C01）。
## PET-94 复核：法力**不画比例条**（仿真没有容量字段，§2.3 不许杜撰上限）；离屏前把 BattleReport
## 交进 RunState，「完整链 / 八通道 / 施法记录」换屏后仍可查（C02）。数值一律**问仿真**。

extends Control

const TICK_SECONDS: float = 1.0 / float(CombatSim.TICK_HZ)

var _sim: CombatSim = null
var _timer: Timer = null
var _field: CombatView = null
var _chain: CombatChain = null

var _wave_label: Label = null
var _hp_fill: ColorRect = null
var _hp_text: Label = null
var _mana_text: Label = null
var _name_label: Label = null
var _value_label: Label = null
var _chain_title: Label = null
var _bonus_label: Label = null
var _result_label: Label = null
var _done_button: Button = null
## 最近一次施法的那张卡与那一段伤害；「当前序号」也只能由它推（CombatSim 的游标不公开）。
var _last_card: CardData = null
var _last_damage: int = 0
## 这一场是否已经把快照交进 RunState。一场只交一次 —— 每波都交的话，结算屏念到的
## 会是「第 1 波还打着」的中途状态。
var _recorded: bool = false

func _ready() -> void:
	# 每场战斗都从第 1 波打起，接着上一场停下的波次继续打是错的（见 RunState.begin_battle）。
	RunState.begin_battle()
	_recorded = false
	_build()
	_sim = CombatSim.new()
	_sim.cast_performed.connect(_on_cast_performed)
	_sim.wave_cleared.connect(_on_wave_cleared)
	_sim.core_destroyed.connect(_on_core_destroyed)
	_begin_wave()


## 装配顺序就是图层顺序（后加的画在上面）；面板的底色与边一律走 Theme 变体（06 §7）。
func _build() -> void:
	add_child(UiKit.panel(ContractTheme.TYPE_BACKDROP, Rect2(Vector2.ZERO, CombatLayout.SCREEN)))
	_build_header()
	# 纸框是「亮纸 16」那一层，战场嵌在它里面，故它先入树。
	add_child(UiKit.panel(ContractTheme.TYPE_PAGE_BAND, CombatLayout.PAPER_FRAME))
	add_child(UiKit.panel(ContractScreenTheme.TYPE_PANEL_SUNK, CombatLayout.FIELD))
	_field = CombatView.new()
	_field.position = CombatLayout.FIELD.position
	_field.size = CombatLayout.FIELD.size
	# 战场不是交互件：指针事件穿过去，免得以后加了底下的控件却被它吃掉。
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	_build_footer()

	_timer = Timer.new()
	_timer.wait_time = TICK_SECONDS
	_timer.autostart = false
	add_child(_timer)
	_timer.timeout.connect(_on_tick)


## 头栏：屏标题 + 魔力（标签 / 真实数值 / 条）+ 波次 + 敌群（标签 / 数值 / 条）。写「敌群」
## 不写「玩家 HP」—— 本波模型里没有玩家生命值这一项（§2.3），不画虚构数值（C05）。
func _build_header() -> void:
	add_child(UiKit.panel(ContractScreenTheme.TYPE_PANEL_DARK_GOLD, CombatLayout.HEADER))
	_label(tr("自动施法"), CombatLayout.TITLE_RECT, ContractScreenTheme.TYPE_LABEL_SCREEN_TITLE)
	# 标签与真实数值分清（§2.3）：同一个 rect 里一左一右两种变体，标签退后、数值在前。
	_label(tr("魔力"), CombatLayout.MANA_LABEL_RECT, ContractTheme.TYPE_LABEL_BODY_MUTED)
	_mana_text = _label("", CombatLayout.MANA_LABEL_RECT, ContractTheme.TYPE_LABEL_BODY,
		HORIZONTAL_ALIGNMENT_RIGHT)
	# 波次是一级元素（§2.3），故与屏标题同档。
	_wave_label = _label("", CombatLayout.WAVE_RECT, ArcaneTheme.TYPE_LABEL_ACCENT,
		HORIZONTAL_ALIGNMENT_CENTER)
	_label(tr("敌群"), CombatLayout.ENEMY_LABEL_RECT, ContractTheme.TYPE_LABEL_BODY_MUTED)
	_hp_text = _label("", CombatLayout.ENEMY_LABEL_RECT, ContractTheme.TYPE_LABEL_BODY,
		HORIZONTAL_ALIGNMENT_RIGHT)
	# 法力**不画条**：仿真里 `_mana` 无界累加、没有容量字段，§2.3 不许杜撰上限（PET-95 裁定
	# 「整条比例控件不画」）。MANA_TRACK 仍作布局空位保留，数字位置不动。
	_hp_fill = _add_bar(CombatLayout.ENEMY_HP_TRACK, CombatTheme.Role.HP_FILL)


## 底栏：当前读数 / 施法链 / 队列加成 / 结果行 / 结算键。
func _build_footer() -> void:
	add_child(UiKit.panel(ContractScreenTheme.TYPE_PANEL_DARK_SILVER, CombatLayout.FOOTER))
	add_child(UiKit.panel(ContractScreenTheme.TYPE_PANEL_SUNK, CombatLayout.ACTIVE_READOUT))
	_name_label = _label("", CombatLayout.ACTIVE_NAME_RECT, ContractScreenTheme.TYPE_LABEL_ACTIVE)
	_value_label = _label("", CombatLayout.ACTIVE_VALUE_RECT, ContractTheme.TYPE_LABEL_BODY)

	_chain = CombatChain.new()
	_chain.position = CombatLayout.ACTIVE_CHAIN.position
	_chain.size = CombatLayout.ACTIVE_CHAIN.size
	_chain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chain)

	add_child(UiKit.panel(ContractScreenTheme.TYPE_PANEL_SUNK, CombatLayout.QUEUE_BONUS))
	_chain_title = _label("", CombatLayout.QUEUE_TITLE_RECT, ContractTheme.TYPE_LABEL_BODY)
	_bonus_label = _label("", CombatLayout.QUEUE_SUMMARY_RECT, ContractScreenTheme.TYPE_LABEL_CAPTION)
	_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_result_label = _label("", CombatLayout.RESULT_RECT, ContractScreenTheme.TYPE_LABEL_CAPTION)
	# 尺寸由 §2.3 的 rect 给死，不用 UiKit.button 那一份按文案算出来的默认尺寸（G02）。
	_done_button = UiKit.button("结算", ContractTheme.TYPE_BUTTON_PAGE_PRIMARY, _on_settle)
	_done_button.position = CombatLayout.DONE_BUTTON.position
	_done_button.size = CombatLayout.DONE_BUTTON.size
	_done_button.visible = false
	add_child(_done_button)


## 建一个 Label。行矩形整块就是它的矩形，文字在块里纵向居中（本屏的行高按「这一行占多高」定）。
func _label(text: String, rect: Rect2, variation: StringName = &"",
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var node: Label = UiKit.label(text, rect, variation)
	node.horizontal_alignment = align
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(node)
	return node


## 一条读数条：槽 + 填充。**只有填充是 ColorRect**（ColorRect 画不出 §2.3 要求的 R4/S1）。
func _add_bar(track: Rect2, fill_role: CombatTheme.Role) -> ColorRect:
	add_child(UiKit.panel(ContractScreenTheme.TYPE_PANEL_SUNK, track))
	var fill: ColorRect = ColorRect.new()
	fill.color = CombatTheme.color(fill_role)
	add_child(fill)
	return fill


func _begin_wave() -> void:
	_result_label.theme_type_variation = ContractScreenTheme.TYPE_LABEL_CAPTION
	_result_label.text = ""
	_settled(false)
	_last_card = null
	_last_damage = 0
	_field.reset()
	# 本局的常驻加成随书页一起交给仿真 —— 它是这一局的一部分，不是这一波的修正。
	_sim.begin(RunState.board(), RunState.current_wave(),
		RunState.damage_bonus(), RunState.mana_bonus())
	_chain.setup(_sim.cast_order())
	_timer.start()
	_refresh()


func _on_tick() -> void:
	_sim.tick()
	_refresh()


func _on_cast_performed(card_id: StringName, damage: int, _mana_left: int) -> void:
	var card: CardData = CardCatalog.find(card_id)
	if card == null:
		return
	_last_card = card
	_last_damage = damage
	# 一次施放可能发多段（子弹数量 / 连发数量），这一行显示的是**最后落下的那一段**。
	_result_label.text = "%s · %s %d" % [tr(card.name_key), tr("伤害"), damage]
	_field.note_cast(damage)
	_chain.note_cast(card_id)
	_refresh()


## 本波清空。还有下一波就接着打；打完这场就分两种：站在最后一层 = **通关**，否则回路线图。
## 延后一帧再开下一波：本回调在 CombatSim.tick() 内部发出，就地重开会继续被这一 tick 改写。
func _on_wave_cleared() -> void:
	_timer.stop()
	_result_label.text = tr("本波已清空")
	if RunState.advance_wave():
		_begin_wave.call_deferred()
	elif RunState.map().is_finished():
		_finish_run(RunState.Result.VICTORY)
	else:
		_record_battle()
		GameFlow.change_state(GameFlow.GameState.REWARD)


## 核心被摧毁 = 这一波没打完，本局到此为止；但**不当场切屏** —— 那句话先让玩家看见。
func _on_core_destroyed() -> void:
	_timer.stop()
	_result_label.text = tr("核心被摧毁")
	_result_label.theme_type_variation = ContractTheme.TYPE_LABEL_CAPTION_DANGER
	_settled(true)
	_refresh()


func _on_settle() -> void:
	_finish_run(RunState.Result.DEFEAT)


## 收官：先把结局落进 RunState（结算屏读的就是它），再走语义入口切到 RESULT（R2 + R3）。
func _finish_run(result: int) -> void:
	_record_battle()
	RunState.finish_run(result)
	if not GameFlow.request_end_run():
		push_warning("CombatScreen: 结算请求被拒绝（当前状态 %s）。" % GameFlow.state_name(GameFlow.get_state()))


## 离场前把这一场的快照交进 RunState（§2.3 C02）：战斗数据活在 _sim 里，屏一释放就没了，
## 而屏上只画得下 4 张卡链与聚合的档数 —— 完整有序链 / 八通道逐条明细 / 施法记录都得先存下来。
## 「最近一次施法」由本屏补：它本来就在记这两个数（「当前读数」显示的就是它们）。
func _record_battle() -> void:
	if _recorded or _sim == null:
		return
	_recorded = true
	var report: BattleReport = BattleReport.capture(_sim)
	if _last_card != null:
		report.last_card_id = _last_card.id
		report.last_damage = _last_damage
	RunState.record_battle(report)


## 结算态的让位（§2.3）：结果行收窄到 736、右侧摘要隐掉只留标题、按钮出现。
func _settled(settled: bool) -> void:
	var rect: Rect2 = CombatLayout.result_rect(settled)
	_result_label.position = rect.position
	_result_label.size = rect.size
	_bonus_label.visible = CombatLayout.queue_summary_visible(settled)
	_done_button.visible = settled


# ------------------------------------------------------------------ 刷新

func _refresh() -> void:
	_wave_label.text = tr("第 %d 波 / 共 %d 波") % [_sim.wave(), RunState.total_waves()]
	_hp_text.text = "%d / %d" % [_sim.enemy_hp(), _sim.enemy_hp_max()]
	_fill_bar(_hp_fill, CombatLayout.ENEMY_HP_TRACK, float(_sim.enemy_hp()),
		float(maxi(_sim.enemy_hp_max(), 1)))
	_mana_text.text = str(_sim.mana())
	_chain_title.text = _chain_text()
	_bonus_label.text = _bonus_text()
	_active_readout()
	_field.queue_redraw()


func _fill_bar(fill: ColorRect, track: Rect2, value: float, maximum: float) -> void:
	var rect: Rect2 = CombatLayout.bar_fill_rect(track, value / maxf(maximum, 1.0))
	fill.position = rect.position
	fill.size = rect.size


## 施法链标题：第几张 / 共几张（§2.3 的「当前序号/总数」）。还没施法时不写假 0（C05）。
func _chain_text() -> String:
	var total: int = _sim.cast_order().size()
	if total <= 0:
		return tr("链条为空")
	var index: int = _cast_index()
	if index <= 0:
		return tr("施法链 · 共 %d 张") % total
	return tr("施法链 %d/%d") % [index, total]


## 当前施法那张在链条里的序号（1 起）。按 **id** 对而不按实例；推不出来时返回 0，不编一个假的。
func _cast_index() -> int:
	if _last_card == null:
		return 0
	var order: Array[CardData] = _sim.cast_order()
	for index: int in order.size():
		if order[index] != null and order[index].id == _last_card.id:
			return index + 1
	return 0


## 当前读数：正在施放的那张的名字与这一段伤害。还没施法时写「尚未施法」而不是空串。
func _active_readout() -> void:
	if _last_card == null:
		_name_label.text = tr("尚未施法")
		_value_label.text = ""
		return
	_name_label.text = tr(_last_card.name_key)
	_value_label.text = "%s %d" % [tr("伤害"), _last_damage]


## 本波加成：本局的常驻加成（只有在这里能看见它生效了）+ 八条通道一共上了几档；链空时先说那句
## 要紧的（要去编辑器连线）。八通道逐条**不在这里**（§2.3 只给摘要 2 行，会顶出面板），
## 它随 BattleReport 去结算屏的战后详情（C02）。
func _bonus_text() -> String:
	if _sim.cast_order().is_empty():
		return tr("未连接核心，不会被施放")
	var mods: CombatMods = _sim.mods()
	var parts: PackedStringArray = PackedStringArray()
	if _sim.damage_bonus() > 0:
		parts.append(tr("伤害 +%d") % _sim.damage_bonus())
	if _sim.mana_bonus() > 0:
		parts.append(tr("魔力 +%d") % _sim.mana_bonus())
	if mods.total_stacks() > 0:
		parts.append(tr("八通道 %d 档") % mods.total_stacks())
	return tr("无加成") if parts.is_empty() else " · ".join(parts)
