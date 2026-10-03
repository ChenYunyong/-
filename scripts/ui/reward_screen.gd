## reward_screen.gd
## 职责：REWARD 场景（06 §9）—— 三个选项卡，不足时以「跳过」补齐；
##       玩家**选定**其中一项后经 GameFlow 回到 PREPARATION。
##       **本批只做骨架与布局，不含任何奖励数值逻辑。**
## 所属系统：ui
## 依赖：GameFlow、RewardLayout、RewardCard、RewardOption、MessagePanel、Palette
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得出现任何会自动推进的构造（Timer / create_timer / timeout / _process /
##       _physics_process，见 03 §2 与 00 §5 交互硬规则第 1 条）—— 进入 REWARD 后永远等玩家，
##       不倒计时、不自动选中、不自动离开；
##       不得实现奖励数值 / 掉落池 / 稀有度权重（属 Stage 4 的 S4-07），
##       也不得实现 RESULT 场景（属 S1-10）。

extends Control

## 06 §9 的界面标题。
const TITLE_KEY: String = "选择奖励"

## 提示面板文案。PREPARATION 已由 S1-07 落地，这里的提示只在**路由故障**时出现
## （场景文件缺失 / 路径写错），措辞与 preparation_screen.gd 的同名提示对齐。
const NOTICE_TITLE: String = "路由未就绪"
const NOTICE_DISMISS: String = "点击任意处关闭"
const NOTICE_PREPARATION: String = "整备场景（PREPARATION）的路由未就绪，本次留在奖励界面。"

@onready var _backdrop: ColorRect = %Backdrop
@onready var _title_bar: PanelTitleBar = %TitleBar
@onready var _cards_area: Control = %CardsArea
@onready var _notice_panel: MessagePanel = %NoticePanel

## 三张选项卡，顺序必须与场景里的节点顺序一致（下标即 RewardLayout 的列 / 行序）。
var _cards: Array[RewardCard] = []
var _chosen_option: RewardOption = null
## apply_layout_for() 落过的档位。存下来而不是现算 size：折叠与否只由**给进来的那个尺寸**
## 决定，测试可以在不改窗口的前提下显式落一次布局（同 preparation_screen.gd 的 _is_narrow）。
var _is_narrow: bool = false


func _ready() -> void:
	# 全屏底色取自 Palette —— 场景里那个 ColorRect 不带 color 字面量（06 §10.7）。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	_title_bar.set_title_key(TITLE_KEY)
	_cards.assign([%Card0, %Card1, %Card2])
	for card: RewardCard in _cards:
		card.option_chosen.connect(_on_option_chosen)
	# 本批没有奖励数据源（掉落池属 Stage 4 的 S4-07），故填一组纯展示用的占位选项，
	# 保证 06 §9 的五个展示位在这一批就有落点。数据接入后改由 set_options() 传入即可。
	set_options(default_options())
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)


## 06 §9 的占位选项。三个都是**字面展示串**：没有计算、没有掉落池、没有稀有度权重，
## 只是让「图标 / 名称 / 类型 / 数值 / 特殊规则」五项各自有落点。
## 真实数据由 Stage 4 的 S4-07 通过 set_options() 注入。
static func default_options() -> Array[RewardOption]:
	return [
		RewardOption.new(RewardOption.Kind.CORE, "核心节点（占位）", "CORE", "能量 +2", "每波开始脉冲一次"),
		RewardOption.new(RewardOption.Kind.FUNCTION, "功能节点（占位）", "FUNCTION", "延时 0.5 秒", "同一拍只转发一次"),
		RewardOption.new(RewardOption.Kind.WEAPON, "武器节点（占位）", "WEAPON", "伤害 12", "每次开火热量 +3"),
	]


## 06 §9：三个选项位，不足时以「跳过」补齐。多于三个的丢弃。
func set_options(options: Array[RewardOption]) -> void:
	var filled: Array[RewardOption] = RewardOption.pad(options, _cards.size())
	for index: int in _cards.size():
		_cards[index].apply_option(filled[index])


## 玩家本次选定的那一项。未选择时为 null —— 它是「离开本场景的原因」的凭据。
func get_chosen_option() -> RewardOption:
	return _chosen_option


## 当前是否处于 06 §7.1 的折叠布局。
func is_narrow_layout() -> bool:
	return _is_narrow


## 按给定可用区尺寸落一次布局。宽屏三列横排，窄屏三行竖排（06 §7.1）。
##
## 折叠只改变**布局**：不碰 GameFlow、不发信号、不改任何状态
## （06 §7.1 末条「折叠只改变布局，不改变任何玩法规则与状态流」）。
## 因此本函数可以在测试里被显式调用，不必真去改窗口尺寸。
func apply_layout_for(viewport_size: Vector2) -> void:
	_is_narrow = RewardLayout.is_narrow(viewport_size)
	_place(_title_bar, RewardLayout.title_rect(viewport_size))
	_place(_cards_area, RewardLayout.cards_rect(viewport_size))
	# 卡片是卡片区的子节点，故拿到的矩形以卡片区原点为基准。
	var rects: Array[Rect2] = RewardLayout.card_rects(viewport_size)
	for index: int in mini(_cards.size(), rects.size()):
		_place(_cards[index], rects[index])


func _on_resized() -> void:
	apply_layout_for(size)


## 玩家选定了一项 → 回 PREPARATION（03 §1 状态图 REWARD → PREPARATION）。
##
## 这是 REWARD **唯一**的出口，且只能由玩家的显式点击触发：本场景里没有倒计时、
## 没有自动选中、没有任何会自行离开的构造（00 §5 交互硬规则第 1 条）。
## 点击之前先查路由是否就绪，而不是闭眼调用 change_state()：GameFlow 的提交点先落状态再路由，
## 对缺失的场景只打印一行、当前场景不动（见 game_flow.gd 的 _route_to_scene），
## 直接调用会让状态与场景脱钩 —— 玩家看到的是「点了没反应」，那正是验收不接受的静默无效。
## 查的是 GameFlow 自己登记的 SCENE_ROUTES（唯一路由来源），不在这里另抄一份路径。
func _on_option_chosen(option: RewardOption) -> void:
	_chosen_option = option
	var target_path: String = GameFlow.get_scene_path_for(GameFlow.GameState.PREPARATION)
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		_show_notice(NOTICE_PREPARATION)
		return
	GameFlow.change_state(GameFlow.GameState.PREPARATION)


## 显示提示。key 为 tr() 的原文 key（暂无翻译表，06 §11）。
func _show_notice(message_key: String) -> void:
	_notice_panel.show_message(NOTICE_TITLE, PackedStringArray([message_key, NOTICE_DISMISS]))


## 点击任意处关闭提示。本阶段的奖励界面是终态前的最后一屏，提示关不掉就等于卡死。
## 用 _input 而不是 _unhandled_input：卡片会消费落在自己身上的事件，
## 而「点卡片时也能关掉上一次的提示」正是想要的。只认按下不认抬起，
## 否则「按 卡片 → 提示出现 → 同一次点击抬起」会把刚出现的提示立刻关掉。
func _input(event: InputEvent) -> void:
	if not _notice_panel.visible:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed:
		_notice_panel.visible = false


## 把控件贴到矩形上。都是场景根或卡片区下的普通 Control（非容器），故直接给位置与尺寸。
func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
