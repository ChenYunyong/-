## combat_screen.gd
## 职责：自动施法战斗屏 —— 把书页交给 CombatSim，按固定步长推进并把状态画出来。
## 所属系统：ui
## 依赖：CombatSim, RunState, GameFlow, UiKit, ArcaneTheme, Palette
## 禁止：本文件不得含战斗规则（在 CombatSim 里）；不得自己换场景（R3）；
##       不得改写书页 —— 战斗只读它（03 §4.3）。
##
## 本屏没有玩家操作（自动施法），只有「看」和「万一输了按一下继续」。

extends Control

const TICK_SECONDS: float = 1.0 / float(CombatSim.TICK_HZ)

const TITLE_RECT: Rect2 = Rect2(24.0, 24.0, 480.0, 48.0)
const WAVE_RECT: Rect2 = Rect2(24.0, 84.0, 480.0, 30.0)
const HP_LABEL_RECT: Rect2 = Rect2(24.0, 132.0, 480.0, 30.0)
const HP_BAR_RECT: Rect2 = Rect2(24.0, 168.0, 480.0, 24.0)
const HP_TEXT_RECT: Rect2 = Rect2(24.0, 198.0, 480.0, 30.0)
const MANA_RECT: Rect2 = Rect2(24.0, 246.0, 480.0, 30.0)
const QUEUE_TITLE_RECT: Rect2 = Rect2(24.0, 294.0, 480.0, 30.0)
const QUEUE_RECT: Rect2 = Rect2(24.0, 330.0, 480.0, 120.0)
const STATUS_RECT: Rect2 = Rect2(552.0, 24.0, 384.0, 120.0)

var _sim: CombatSim = null
var _timer: Timer = null

var _wave_label: Label = null
var _hp_fill: ColorRect = null
var _hp_text: Label = null
var _mana_label: Label = null
var _queue_label: Label = null
var _status_label: Label = null
var _exit_button: Button = null
var _failed: bool = false


func _ready() -> void:
	_build()
	_sim = CombatSim.new()
	_sim.cast_performed.connect(_on_cast_performed)
	_sim.wave_cleared.connect(_on_wave_cleared)
	_sim.core_destroyed.connect(_on_core_destroyed)
	_begin_wave()


func _build() -> void:
	var title: Label = UiKit.label(tr("自动施法"), TITLE_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	add_child(title)

	_wave_label = UiKit.label("", WAVE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	add_child(_wave_label)
	add_child(UiKit.label(tr("敌群血量"), HP_LABEL_RECT))

	# 血条：深色内芯 + 一段色块。色块宽度按比例算，颜色来自 Palette（04 §7）。
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_CANVAS, HP_BAR_RECT))
	_hp_fill = ColorRect.new()
	_hp_fill.color = Palette.get_color(Palette.Key.ORANGE_500)
	_hp_fill.position = HP_BAR_RECT.position + Vector2(9.0, 9.0)
	_hp_fill.size = Vector2(0.0, HP_BAR_RECT.size.y - 18.0)
	add_child(_hp_fill)

	_hp_text = UiKit.label("", HP_TEXT_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	add_child(_hp_text)
	_mana_label = UiKit.label("", MANA_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	add_child(_mana_label)
	add_child(UiKit.label(tr("施法队列"), QUEUE_TITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY))
	_queue_label = UiKit.wrapped_label("", QUEUE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	add_child(_queue_label)

	_status_label = UiKit.wrapped_label("", STATUS_RECT)
	add_child(_status_label)

	_exit_button = UiKit.button("路线图", ArcaneTheme.TYPE_BUTTON_PRIMARY, _on_exit)
	_exit_button.visible = false
	add_child(_exit_button)
	UiKit.place_right(_exit_button, Rect2(Vector2(24.0, 444.0), Vector2(912.0, 72.0)), 936.0)

	_timer = Timer.new()
	_timer.wait_time = TICK_SECONDS
	_timer.autostart = false
	add_child(_timer)
	_timer.timeout.connect(_on_tick)


func _begin_wave() -> void:
	_failed = false
	_exit_button.visible = false
	_status_label.text = ""
	_sim.begin(RunState.board(), RunState.current_wave())
	_timer.start()
	_refresh()


func _on_tick() -> void:
	_sim.tick()
	_refresh()


func _on_cast_performed(card_id: StringName, damage: int, _mana_left: int) -> void:
	var card: CardData = CardCatalog.find(card_id)
	if card == null:
		return
	_status_label.text = "%s · %s %d" % [tr(card.name_key), tr("伤害"), damage]


## 本波清空。还有下一波就接着打；打完了就进奖励屏。
## 延后一帧再开下一波：本回调是在 CombatSim.tick() 内部发出来的，
## 就地重开会让「刚重置的状态」继续被这一 tick 的后续代码改写。
func _on_wave_cleared() -> void:
	_timer.stop()
	_status_label.text = tr("本波已清空")
	if RunState.advance_wave():
		_begin_wave.call_deferred()
	else:
		GameFlow.change_state(GameFlow.GameState.REWARD)


func _on_core_destroyed() -> void:
	_timer.stop()
	_failed = true
	_status_label.text = tr("核心被摧毁")
	_status_label.theme_type_variation = ArcaneTheme.TYPE_LABEL_DANGER
	_exit_button.visible = true
	_refresh()


func _on_exit() -> void:
	GameFlow.change_state(GameFlow.GameState.MAP)


func _refresh() -> void:
	_wave_label.text = tr("第 %d 波 / 共 %d 波") % [_sim.wave(), RunState.total_waves()]
	var maximum: int = maxi(_sim.enemy_hp_max(), 1)
	var ratio: float = float(_sim.enemy_hp()) / float(maximum)
	_hp_fill.size.x = maxf(0.0, (HP_BAR_RECT.size.x - 18.0) * ratio)
	_hp_text.text = "%d / %d" % [_sim.enemy_hp(), _sim.enemy_hp_max()]
	_mana_label.text = "%s %d" % [tr("魔力"), _sim.mana()]
	_queue_label.text = _queue_text()
	if not _failed and _status_label.text.is_empty():
		_status_label.text = tr("等待核心产出魔力") if _sim.cast_order().is_empty() else ""


## 施法队列：本波会按什么顺序放法术。空 = 书页上没有连到核心的卡，玩家据此知道要回去连线。
func _queue_text() -> String:
	var names: PackedStringArray = PackedStringArray()
	for card: CardData in _sim.cast_order():
		names.append(tr(card.name_key))
	return "\n".join(names)
