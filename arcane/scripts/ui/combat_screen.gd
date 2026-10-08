## combat_screen.gd
## 职责：自动施法战斗屏 —— 把书页交给 CombatSim 按固定步长推进，并把状态画出来：
##       书页（CombatView）/ 敌群与血量 / 魔力 / 施法队列 / 本波加成 / 本场结果。
## 所属系统：ui
## 依赖：CombatSim, CombatMods, CombatView, CombatLayout, CombatTheme, CardCatalog,
##       RunState, GameFlow, UiKit, ArcaneTheme
## 禁止：本文件不得含战斗规则（在 CombatSim / CombatMods 里）；不得自己换场景（R3）；
##       不得改写书页 —— 战斗只读它（03 §4.3）；不得出现裸色值（本屏自己画的东西一律经
##       CombatTheme 的角色表，文字与面板底走 ArcaneTheme 的类型变体）。
##
## 本屏没有玩家操作（自动施法），只有「看」和「打不下去了按一下结算」（PET-92）。
##
## 数值一律**问仿真**，不在本文件里复制一份：本波加成那一行若自己攒一套计数，
## 它和 CombatSim 里真正生效的那个迟早会对不上，而症状只是「显示得不太对」。

extends Control

const TICK_SECONDS: float = 1.0 / float(CombatSim.TICK_HZ)

var _sim: CombatSim = null
var _timer: Timer = null
var _page: CombatView = null

var _wave_label: Label = null
var _hp_fill: ColorRect = null
var _hp_text: Label = null
var _mana_label: Label = null
var _mana_fill: ColorRect = null
var _queue_label: Label = null
var _bonus_label: Label = null
var _result_label: Label = null
var _settle_button: Button = null


func _ready() -> void:
	# 每场战斗都从第 1 波打起，接着上一场停下的波次继续打是错的（见 RunState.begin_battle）。
	RunState.begin_battle()
	_build()
	_sim = CombatSim.new()
	_sim.cast_performed.connect(_on_cast_performed)
	_sim.wave_cleared.connect(_on_wave_cleared)
	_sim.core_destroyed.connect(_on_core_destroyed)
	_begin_wave()


func _build() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_TITLE_BAR, CombatLayout.TITLE_BAR_RECT))
	_label(tr("自动施法"), CombatLayout.TITLE_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	_wave_label = _label("", CombatLayout.WAVE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_page = CombatView.new()
	_page.position = CombatLayout.PAGE_RECT.position
	_page.size = CombatLayout.PAGE_RECT.size
	# 战斗屏的书页不是交互件：指针事件穿过去，免得以后加了底下的控件却被它吃掉。
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_page)

	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, CombatLayout.SIDE_RECT))
	_build_side()
	_build_bonus()
	_build_bottom()

	_timer = Timer.new()
	_timer.wait_time = TICK_SECONDS
	_timer.autostart = false
	add_child(_timer)
	_timer.timeout.connect(_on_tick)


## 侧栏的读数：敌群血量、魔力、施法队列。
func _build_side() -> void:
	_label(tr("敌群血量"), CombatLayout.ENEMY_TITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	_hp_fill = _add_bar(CombatLayout.HP_BAR_RECT, CombatTheme.Role.HP_TRACK, CombatTheme.Role.HP_FILL)
	_hp_text = _label("", CombatLayout.HP_TEXT_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)

	_mana_label = _label("", CombatLayout.MANA_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	_mana_fill = _add_bar(CombatLayout.MANA_BAR_RECT, CombatTheme.Role.MANA_TRACK,
		CombatTheme.Role.MANA_FILL)

	_label(tr("施法队列"), CombatLayout.QUEUE_TITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	_queue_label = _label("", CombatLayout.QUEUE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	_queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## 加成带：一句「本波上了什么」，横贯整屏。左字右值，与标题栏同一套排版。
func _build_bonus() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, CombatLayout.BONUS_BAR_RECT))
	_label(tr("本波加成"), CombatLayout.BONUS_TITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	_bonus_label = _label("", CombatLayout.BONUS_TEXT_RECT, ArcaneTheme.TYPE_LABEL_PARAM)
	_bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## 底部动作条：左边一句本场结果，右边一颗按钮（**只有输了才出现** ——
## 打赢了是自动进下一波 / 打穿最后一层，那颗键只服务「核心没了，本局到此为止」这一种处境）。
func _build_bottom() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, CombatLayout.BOTTOM_RECT))
	_result_label = _label("", CombatLayout.RESULT_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	_settle_button = UiKit.button("结算", ArcaneTheme.TYPE_BUTTON_PRIMARY, _on_settle)
	_settle_button.visible = false
	add_child(_settle_button)
	UiKit.place_right(_settle_button, CombatLayout.BOTTOM_RECT, CombatLayout.BOTTOM_RECT.end.x)


## 建一个 Label 挂在屏上。行矩形整块就是它的矩形，文字在块里纵向居中 ——
## 本屏的行高是按「这一行占多高」定的，不是按一行字多高定的（同 EditorScreen 的顶栏）。
func _label(text: String, rect: Rect2, variation: StringName = &"") -> Label:
	var node: Label = UiKit.label(text, rect, variation)
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(node)
	return node


## 一条读数条：底槽 + 填充块，两块都是 ColorRect、颜色都来自 CombatTheme。
## 不用 Panel 是因为面板底色来自主题变体 —— 那样这条的颜色就绕过了角色表，
## 将来整体切换基调时会漏掉它。返回填充块，刷新时只改它。
func _add_bar(track: Rect2, track_role: CombatTheme.Role, fill_role: CombatTheme.Role) -> ColorRect:
	var back: ColorRect = ColorRect.new()
	back.color = CombatTheme.color(track_role)
	back.position = track.position
	back.size = track.size
	add_child(back)
	var fill: ColorRect = ColorRect.new()
	fill.color = CombatTheme.color(fill_role)
	add_child(fill)
	return fill


func _begin_wave() -> void:
	_settle_button.visible = false
	_result_label.theme_type_variation = ArcaneTheme.TYPE_LABEL_ACCENT
	_result_label.text = ""
	# 本局的常驻加成随书页一起交给仿真（它是这一局的一部分，不是这一波的修正 ——
	# 后者在 CombatMods 里，每波开头重置）。
	_sim.begin(RunState.board(), RunState.current_wave(),
		RunState.damage_bonus(), RunState.mana_bonus())
	_page.setup(_sim, RunState.board())
	_timer.start()
	_refresh()


func _on_tick() -> void:
	_sim.tick()
	_refresh()


func _on_cast_performed(card_id: StringName, damage: int, _mana_left: int) -> void:
	var card: CardData = CardCatalog.find(card_id)
	if card == null:
		return
	# 一次施放可能发多段（子弹数量 / 连发数量），这一行显示的是**最后落下的那一段**。
	_result_label.text = "%s · %s %d" % [tr(card.name_key), tr("伤害"), damage]
	_page.note_cast(card_id)


## 本波清空。还有下一波就接着打；打完这一场就分两种：站在最后一层 = **通关**，
## 否则回路线图选下一站。
## 延后一帧再开下一波：本回调是在 CombatSim.tick() 内部发出来的，
## 就地重开会让「刚重置的状态」继续被这一 tick 的后续代码改写。
func _on_wave_cleared() -> void:
	_timer.stop()
	_result_label.text = tr("本波已清空")
	if RunState.advance_wave():
		_begin_wave.call_deferred()
	elif RunState.map().is_finished():
		_finish_run(RunState.Result.VICTORY)
	else:
		GameFlow.change_state(GameFlow.GameState.REWARD)


## 核心被摧毁 = 这一波没打完。本局到此为止，但**不当场切屏** ——
## 屏幕上那句「核心被摧毁」得先让玩家看见，再由「结算」把这一局收尾。
func _on_core_destroyed() -> void:
	_timer.stop()
	_result_label.text = tr("核心被摧毁")
	_result_label.theme_type_variation = ArcaneTheme.TYPE_LABEL_DANGER
	_settle_button.visible = true
	_refresh()


func _on_settle() -> void:
	_finish_run(RunState.Result.DEFEAT)


## 收官：先把结局落进 RunState（结算屏读的就是它），再走语义入口切到 RESULT（R2 + R3）。
func _finish_run(result: int) -> void:
	RunState.finish_run(result)
	if not GameFlow.request_end_run():
		push_warning("CombatScreen: 结算请求被拒绝（当前状态 %s）。" % GameFlow.state_name(GameFlow.get_state()))


# ------------------------------------------------------------------ 刷新

func _refresh() -> void:
	_wave_label.text = tr("第 %d 波 / 共 %d 波") % [_sim.wave(), RunState.total_waves()]
	_fill_bar(_hp_fill, CombatLayout.HP_BAR_RECT, float(_sim.enemy_hp()),
		float(maxi(_sim.enemy_hp_max(), 1)))
	_hp_text.text = "%d / %d" % [_sim.enemy_hp(), _sim.enemy_hp_max()]
	_mana_label.text = "%s %d" % [tr("魔力"), _sim.mana()]
	_fill_bar(_mana_fill, CombatLayout.MANA_BAR_RECT, float(_sim.mana()), float(_mana_scale()))
	_queue_label.text = _queue_text()
	_bonus_label.text = _bonus_text()
	_page.queue_redraw()


func _fill_bar(fill: ColorRect, track: Rect2, value: float, maximum: float) -> void:
	var rect: Rect2 = CombatLayout.bar_fill_rect(track, value / maxf(maximum, 1.0))
	fill.position = rect.position
	fill.size = rect.size


## 魔力条的满格。仿真里魔力**没有上限**，所以必须挑一个有意义的参照 ——
## 不能拿「当前魔力」当分母，那样它永远满格，等于没画。
## 取「本波最贵的一次施法」的**两倍**：刚好付得起最贵那张时条在半满，
## 满格留给「还能再打一次」—— 这正是玩家看着这条时要回答的那个问题。
func _mana_scale() -> int:
	var top: int = 1
	for card: CardData in _sim.cast_order():
		top = maxi(top, _sim.mods().price(card, 1))
	return top * 2


## 施法队列：本波会按什么顺序放法术。空 = 书页上没有连到核心的卡 ——
## 玩家据此知道要回编辑器连线，而不是对着一个不动的画面猜哪里坏了。
func _queue_text() -> String:
	var names: PackedStringArray = PackedStringArray()
	for card: CardData in _sim.cast_order():
		names.append(tr(card.name_key))
	if names.is_empty():
		return tr("未连接核心，不会被施放")
	return " → ".join(names)


## 本波加成：本局的常驻加成（奖励里拿的）+ 八条通道里真的上了档的那几条。
## 一条都没有时给一句「无加成」而不是空串 —— 空串会让玩家分不清「没加成」和「这一行坏了」。
##
## 常驻那两条必须显示出来：它们是奖励屏的选项，玩家选了之后**只有在这里**能看见它生效了；
## 不显示的话，「拿了强化」在下一场里就是一次没有回音的操作。
func _bonus_text() -> String:
	var mods: CombatMods = _sim.mods()
	var parts: PackedStringArray = PackedStringArray()
	if _sim.damage_bonus() > 0:
		parts.append(tr("伤害 +%d") % _sim.damage_bonus())
	if _sim.mana_bonus() > 0:
		parts.append(tr("魔力 +%d") % _sim.mana_bonus())
	if mods.enchant_stacks > 0:
		parts.append(tr("附魔 ×%.1f") % mods.damage_multiplier())
	if mods.projectile_stacks > 0:
		parts.append(tr("子弹 +%d") % mods.projectile_stacks)
	if mods.burst_left > 0:
		parts.append(tr("连发 %d") % mods.burst_left)
	if mods.haste_stacks > 0:
		parts.append(tr("加速 -%d 拍") % (CombatSim.MANA_INTERVAL_TICKS - _sim.mana_period_ticks()))
	if mods.attack_speed_stacks > 0:
		parts.append(tr("攻速 -%d 拍") % (CombatSim.CAST_INTERVAL_TICKS - _sim.cast_interval_ticks()))
	if mods.slow_stacks > 0:
		parts.append(tr("减速 +%d 秒")
			% (mods.slow_stacks * CombatMods.SLOW_TICKS_PER_STACK / CombatSim.TICK_HZ))
	if mods.cooldown_stacks > 0:
		parts.append(tr("冷却 -%d") % (mods.cooldown_stacks * CombatMods.COOLDOWN_DISCOUNT_PER_STACK))
	if mods.looping:
		parts.append(tr("循环"))
	return tr("无加成") if parts.is_empty() else " · ".join(parts)
