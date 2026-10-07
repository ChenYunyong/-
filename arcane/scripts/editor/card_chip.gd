## card_chip.gd
## 职责：卡牌仓库里的一个卡位 —— 点一下就放到书页上。
## 所属系统：editor
## 依赖：CardData, CardFace, Palette
## 禁止：本文件不得出现裸色值；不得自己拼卡面（画法与画布共用 CardFace）。
##
## 交互为什么是「点」而不是「从仓库拖到画布」：仓库是一排横向滚动的卡位，
## 从 ScrollContainer 里往外拖会和滚动抢手势，第一版不做这种歧义。
## 自由摆放这条要求由**画布上的拖动**承担（BoardView），那才是招牌交互。

class_name CardChip
extends Control

## 玩家点了这个卡位。editor 负责把它放到画布上（放在哪由 BoardView.free_position() 决定）。
signal chosen(card_id: StringName)

var card_id: StringName = &""

var _card: CardData = null
var _col_fill: Color = Palette.MISSING_COLOR
var _col_fill_hover: Color = Palette.MISSING_COLOR
var _col_text: Color = Palette.MISSING_COLOR


func _ready() -> void:
	_col_fill = Palette.get_color(Palette.Key.NAVY_800)
	_col_fill_hover = Palette.get_color(Palette.Key.NAVY_700)
	_col_text = Palette.get_color(Palette.Key.BLUE_100)
	custom_minimum_size = CardFace.SIZE
	size = CardFace.SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)


## 绑定一张卡牌。tooltip 走 tr()（06 §11：文本必须走 key）。
func setup(card: CardData) -> void:
	_card = card
	card_id = card.id
	tooltip_text = tr(card.name_key)
	queue_redraw()


func _draw() -> void:
	if _card == null:
		return
	var hovered: bool = get_rect().has_point(get_local_mouse_position())
	CardFace.paint(self, _card, Vector2.ZERO, _col_fill_hover if hovered else _col_fill, _col_text)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		chosen.emit(card_id)
		accept_event()
