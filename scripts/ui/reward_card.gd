## reward_card.gd
## 职责：REWARD 界面上**一张选项卡**（06 §9）—— 把一项 RewardOption 的五个展示位画出来，
##       并在被点击时把那一项抛给上层。**它自己不做任何路由、不改任何状态。**
## 所属系统：ui
## 依赖：RewardOption, Palette, palette_theme.gd（内容边距）, InputNormalizer
## 禁止：不得调用 GameFlow / change_scene_to_file（路由唯一落点是 reward_screen.gd）；
##       不得写任何字面色值（图标色取自 Palette，见 icon_color()）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经
##       InputNormalizer 归一后的语义事件（03 §8）；
##       不得出现任何奖励数值逻辑（属 Stage 4 的 S4-07）。
##
## 为什么是 Panel + gui_input 而不是 Button：卡片要显示的是 5 行结构化内容，不是一行文案，
## Button 的 text 装不下；而 Theme 里没有「卡片按钮」变体，新建变体又要改
## scripts/data/palette_theme.gd（不在本批的允许文件内）。
## 于是卡片用已有的 PanelSecondary 变体（规范原话就是「次级面板（面板内卡片）」）自绘，
## 点击走 gui_input —— 与 preparation_screen.gd 窄屏信息条同一套做法。
##
## 已知观感取舍（已回报 DSH，最终由 Codex 定）：PanelSecondary 的填充是 NAVY_800，
## 与身后的 PanelCore 同色，卡片目前**只靠 1px BROWN_600 描边**与背景区分。

class_name RewardCard
extends Panel

## 玩家选中了本卡片承载的那一项。参数即该选项，上层据此决定去哪。
signal option_chosen(option: RewardOption)

@onready var _layout: VBoxContainer = %Layout
@onready var _icon: ColorRect = %Icon
@onready var _name: Label = %Name
@onready var _type: Label = %Type
@onready var _value: Label = %Value
@onready var _rule: Label = %Rule

var _option: RewardOption = null


func _ready() -> void:
	# 卡片的呼吸空间取自 PaletteTheme.PANEL_SECONDARY_CONTENT_MARGIN，与 PanelSecondary
	# 自身的 content_margin 同一个来源 —— 两处若将来分头改，肉眼一眼能看出来。
	# 注意 Panel 不像 PanelContainer 那样替子节点应用 content_margin，必须自己让。
	var margin: float = float(PaletteTheme.PANEL_SECONDARY_CONTENT_MARGIN)
	_layout.offset_left = margin
	_layout.offset_top = margin
	_layout.offset_right = -margin
	_layout.offset_bottom = -margin
	gui_input.connect(_on_gui_input)
	_option = RewardOption.skip()
	apply_option(_option)


## 06 §9 的五个展示位。空字段**整行隐藏**（不显示 "N/A"）：
## 「跳过」这类补齐项只有名称，其余三项理当不占版面。
func apply_option(option: RewardOption) -> void:
	_option = option
	_icon.color = icon_color(option.kind)
	_apply_field(_name, option.name_key)
	_apply_field(_type, option.type_key)
	_apply_field(_value, option.value_key)
	_apply_field(_rule, option.rule_key)


func get_option() -> RewardOption:
	return _option


## 类型标识色。前三种逐字取自 06 §4 的类型 -> 颜色对照（全项目唯一一处该对照），
## 复用在奖励卡的图标上，免得同一个「类型」在整备界面和奖励界面是两个颜色。
##
## 「跳过」不是一种节点类型，06 §4 没有它，06 §9 也没规定它的色 —— 取中性 GREY_500。
## 这是判断，不是规范（已回报 DSH，最终由 Codex 定）。
static func icon_color(kind: RewardOption.Kind) -> Color:
	match kind:
		RewardOption.Kind.CORE:
			return Palette.get_color(Palette.Key.GOLD_400)
		RewardOption.Kind.FUNCTION:
			return Palette.get_color(Palette.Key.BLUE_400)
		RewardOption.Kind.WEAPON:
			return Palette.get_color(Palette.Key.ORANGE_500)
		_:
			return Palette.get_color(Palette.Key.GREY_500)


## 只认「按下」。事件先经输入层归一：触摸按下与鼠标左键按下在这里已经是同一条
## POINTER_PRESS（03 §8），不再依赖「触摸被引擎合成为鼠标」那条间接路径 ——
## 直接推入的 InputEventScreenTouch 也走这条同样的分支。
## 抬起不响应，免得一次点击算两下。
func _on_gui_input(event: InputEvent) -> void:
	var semantic: SemanticInput = InputNormalizer.from_event(event)
	if semantic == null or semantic.action != SemanticInput.Action.POINTER_PRESS:
		return
	option_chosen.emit(_option)
	accept_event()


func _apply_field(label: Label, text_key: String) -> void:
	label.text = tr(text_key)
	label.visible = not text_key.is_empty()
