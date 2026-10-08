## reward_screen.gd
## 职责：战斗后的奖励屏 —— 三个**真选择**（拿一张卡 / 本局强化 / 本局供能），选完去路线图。
## 所属系统：ui
## 依赖：RewardModel, CardCatalog, CardChip, RunState, GameFlow, EditorLayout, UiKit, ArcaneTheme
## 禁止：本文件不得自己换场景（R3）；不得直接写 RunState 的账本或书页 —— 一律经 RunState.take_reward()。
##
## 选项本身由 RewardModel 定（纯函数，按本局种子 + 波次推出来）：同一局的同一波每次进来都是
## 同一组，不会因为多看了一眼就换牌。本文件只负责把选项画出来、把选中的那个递回去。
##
## 选项池被拿空时**不画空白屏**：给一句说明 + 一颗继续按钮。池子空了是真实可达的局面
## （一局里拿满 17 张卡 + 2 个加成），不是防御性代码。
##
## 版式沿用现有中性实现 —— 视觉契约是 PET-91 的事，本轮不碰配色与版式。

extends Control

const OPTION_WIDTH: float = 272.0
const OPTION_HEIGHT: float = 272.0
const OPTION_GAP: float = 48.0
const OPTION_TOP: float = 140.0
const CHIP_SIZE: float = 72.0
## 选项内左右留白。名称与说明共用同一条左边界。
const INNER_PAD: float = 21.0

const TITLE_RECT: Rect2 = Rect2(24.0, 24.0, 912.0, 48.0)
const SUBTITLE_RECT: Rect2 = Rect2(24.0, 80.0, 912.0, 30.0)
## 池子空时那句说明就住在这里 —— 与选项同一块区域，于是「这里本该有东西」是看得见的。
const EMPTY_RECT: Rect2 = Rect2(24.0, OPTION_TOP, 912.0, OPTION_HEIGHT)
const SKIP_ANCHOR: Rect2 = Rect2(24.0, 444.0, 912.0, 72.0)

## 「跳过」与「继续」两颗按钮的文案 key。池子空时没有可跳过的奖励，只有下一步。
const KEY_SKIP: String = "跳过"
const KEY_CONTINUE: String = "继续"

var _options: Array[Dictionary] = []


func _ready() -> void:
	_options = RunState.roll_rewards()
	var empty: bool = _options.is_empty()

	add_child(UiKit.label(tr("选择奖励"), TITLE_RECT, ArcaneTheme.TYPE_LABEL_ACCENT))
	add_child(UiKit.label(tr("没有可拿的奖励") if empty else tr("三选一"),
		SUBTITLE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY))

	if empty:
		_build_empty_fallback()
	else:
		for index: int in _options.size():
			_build_option(index, _options[index])

	var next_button: Button = UiKit.button(KEY_CONTINUE if empty else KEY_SKIP,
		ArcaneTheme.TYPE_BUTTON_SECONDARY, _on_leave)
	add_child(next_button)
	UiKit.place_right(next_button, SKIP_ANCHOR, SKIP_ANCHOR.end.x)


## 池子空时的兜底：说明为什么没得选，并明确「下一步是去哪」。
func _build_empty_fallback() -> void:
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY, EMPTY_RECT))
	add_child(UiKit.wrapped_label(tr("本局的卡与加成都已拿满"), EMPTY_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY))


func _build_option(index: int, option: Dictionary) -> void:
	var origin: Vector2 = Vector2(EditorLayout.MARGIN + float(index) * (OPTION_WIDTH + OPTION_GAP),
		OPTION_TOP)
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_FRAME, Rect2(origin, Vector2(OPTION_WIDTH, OPTION_HEIGHT))))
	add_child(UiKit.panel(ArcaneTheme.TYPE_PANEL_SECONDARY,
		Rect2(origin + Vector2(9.0, 9.0), Vector2(OPTION_WIDTH - 18.0, OPTION_HEIGHT - 18.0))))

	# 三块选项占同样大的位置、同样的行高：顶上那一块是「脸」（拿卡是卡面，两条加成是强调文字），
	# 名字与说明各自固定在 108 / 144 两行上。玩家扫一眼就知道有三条路，而不是三样不同的东西。
	var text_x: float = origin.x + INNER_PAD
	var inner_width: float = OPTION_WIDTH - 18.0 - INNER_PAD * 2.0
	if RewardModel.is_card(option):
		_build_card_face(origin, option)
		add_child(UiKit.label(RewardModel.name_text(option),
			Rect2(Vector2(text_x, origin.y + 108.0), Vector2(inner_width, 30.0))))
	else:
		add_child(UiKit.label(RewardModel.name_text(option),
			Rect2(Vector2(text_x, origin.y + 60.0), Vector2(inner_width, 36.0)),
			ArcaneTheme.TYPE_LABEL_ACCENT))
	add_child(UiKit.wrapped_label(RewardModel.detail_text(option),
		Rect2(Vector2(text_x, origin.y + 144.0), Vector2(inner_width, 60.0)),
		ArcaneTheme.TYPE_LABEL_SECONDARY))

	var button: Button = UiKit.button("选择", ArcaneTheme.TYPE_BUTTON_PRIMARY, _on_choose.bind(index))
	add_child(button)
	button.position = Vector2(origin.x + (OPTION_WIDTH - button.size.x) * 0.5, origin.y + 212.0)


func _build_card_face(origin: Vector2, option: Dictionary) -> void:
	var card: CardData = CardCatalog.find(option.get("card_id", &""))
	if card == null:
		return
	var chip: CardChip = CardChip.new()
	chip.position = origin + Vector2((OPTION_WIDTH - CHIP_SIZE) * 0.5, 24.0)
	add_child(chip)
	chip.setup(card)


## 选中第 index 个选项。**落地全在 RunState.take_reward() 里**（记账 + 改书页 / 改加成），
## 这里只负责递进去、并在它说「不受理」时留在原地 —— 不做「以为拿了其实没拿」的切换。
func _on_choose(index: int) -> void:
	if not RunState.take_reward(_options[index], EditorLayout.CANVAS_VIEW_SIZE):
		push_warning("RewardScreen: 第 %d 个奖励未被受理，停在奖励屏。" % index)
		return
	# 拿到奖励就去路线图：下一站打哪一层由玩家在图上点（PET-92 §2）。
	GameFlow.change_state(GameFlow.GameState.MAP)


func _on_leave() -> void:
	GameFlow.change_state(GameFlow.GameState.MAP)
