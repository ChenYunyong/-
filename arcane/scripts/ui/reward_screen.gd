## reward_screen.gd
## 职责：战斗后的三选一奖励屏 —— 选一张牌加进书页，或跳过。
## 所属系统：ui
## 依赖：CardCatalog, CardChip, RunState, GameFlow, EditorLayout, UiKit, ArcaneTheme
## 禁止：本文件不得自己换场景（R3）；不得直接改书页以外的东西。
##
## 三个选项从本局种子 + 波次推出来，不用全局 rng：这样「同一局的同一波奖励」
## 每次进来都是同一组，不会因为多看了一眼就换牌。

extends Control

const OPTION_COUNT: int = 3
const OPTION_WIDTH: float = 272.0
const OPTION_HEIGHT: float = 272.0
const OPTION_GAP: float = 48.0
const OPTION_TOP: float = 140.0
const CHIP_SIZE: float = 72.0

const TITLE_RECT: Rect2 = Rect2(24.0, 24.0, 912.0, 48.0)
const SUBTITLE_RECT: Rect2 = Rect2(24.0, 80.0, 912.0, 30.0)
const SKIP_ANCHOR: Rect2 = Rect2(24.0, 444.0, 912.0, 72.0)

var _skip_button: Button = null


func _ready() -> void:
	var title: Label = UiKit.label(tr("选择奖励"), TITLE_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	add_child(title)
	add_child(UiKit.label(tr("三选一"), SUBTITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY))

	var options: Array[CardData] = _roll_options()
	for index: int in options.size():
		_build_option(index, options[index])

	_skip_button = UiKit.button("跳过", ArcaneTheme.TYPE_BUTTON_SECONDARY, _on_skip)
	add_child(_skip_button)
	UiKit.place_right(_skip_button, SKIP_ANCHOR, SKIP_ANCHOR.end.x)


## 从「能力卡 + 功能卡」里抽三张不重复的。核心卡不进奖励池 —— 起点不该是抽出来的。
func _roll_options() -> Array[CardData]:
	var pool: Array[CardData] = CardCatalog.by_kind(CardData.Kind.ABILITY)
	pool.append_array(CardCatalog.by_kind(CardData.Kind.FUNCTION))
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.seed = RunState.get_run_seed() + RunState.current_wave()
	var picked: Array[CardData] = []
	var guard: int = 0
	while picked.size() < OPTION_COUNT and not pool.is_empty() and guard < pool.size() * 4:
		guard += 1
		var candidate: CardData = pool[generator.randi_range(0, pool.size() - 1)]
		if not picked.has(candidate):
			picked.append(candidate)
	return picked


func _build_option(index: int, card: CardData) -> void:
	var origin: Vector2 = Vector2(EditorLayout.MARGIN + float(index) * (OPTION_WIDTH + OPTION_GAP),
		OPTION_TOP)
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_FRAME, Rect2(origin, Vector2(OPTION_WIDTH, OPTION_HEIGHT))))
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY,
		Rect2(origin + Vector2(9.0, 9.0), Vector2(OPTION_WIDTH - 18.0, OPTION_HEIGHT - 18.0))))

	var chip: CardChip = CardChip.new()
	chip.position = origin + Vector2((OPTION_WIDTH - CHIP_SIZE) * 0.5, 24.0)
	add_child(chip)
	chip.setup(card)
	chip.chosen.connect(_on_choose)

	var inner_width: float = OPTION_WIDTH - 18.0 - 24.0
	var text_x: float = origin.x + 21.0
	add_child(UiKit.label(tr(card.name_key), Rect2(Vector2(text_x, origin.y + 108.0),
		Vector2(inner_width, 30.0))))
	add_child(UiKit.wrapped_label(tr(card.effect_key), Rect2(Vector2(text_x, origin.y + 144.0),
		Vector2(inner_width, 60.0)), ArcaneTheme.TYPE_LABEL_SECONDARY))

	var button: Button = UiKit.button("选择", ArcaneTheme.TYPE_BUTTON_PRIMARY, _on_choose.bind(card.id))
	add_child(button)
	button.position = Vector2(origin.x + (OPTION_WIDTH - button.size.x) * 0.5, origin.y + 212.0)


func _on_choose(card_id: StringName) -> void:
	# 奖励直接落到书页上（本批没有卡组 / 收藏系统）。落点用和编辑器同一条规则。
	RunState.board().add_card(card_id, RunState.board().free_position(EditorLayout.CANVAS_VIEW_SIZE))
	GameFlow.change_state(GameFlow.GameState.EDITOR)


func _on_skip() -> void:
	GameFlow.change_state(GameFlow.GameState.EDITOR)
