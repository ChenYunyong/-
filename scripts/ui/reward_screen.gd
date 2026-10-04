## reward_screen.gd
## 职责：REWARD 场景（06 §9）—— 三个选项卡，不足时以「跳过」补齐；
##       玩家**选定**其中一项后经 GameFlow 回到 PREPARATION（循环由此闭合：回去继续改造机器打下一波）。
##       本批（FIRST PLAYABLE 4/4）给三个选项接上**真实数据**：一张固定的三选项池（见 default_options）。
## 所属系统：ui
## 依赖：GameFlow、RewardLayout、RewardCard、RewardOption、MessagePanel、Palette、InputScreen、
##       MachineRuntime、WeaponData
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得出现任何会自动推进的构造（Timer / create_timer / timeout / _process /
##       _physics_process，见 03 §2 与 00 §5 交互硬规则第 1 条）—— 进入 REWARD 后永远等玩家，
##       不倒计时、不自动选中、不自动离开；
##       不得实现奖励的**效果**（拿到手就多一个节点 / 改数值）—— 那需要掉落池与稀有度权重，
##       属 Stage 4 的 S4-07；本文件只把选项**显示**出来并交出玩家选中的那一项
##       （get_chosen_option()），选中的东西怎么落地由那张卡决定；
##       也不得实现 RESULT 场景（属 S1-10）。

extends InputScreen

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
	# 本批用一张固定池填满三个选项位（见 default_options）。掉落池属 Stage 4 的 S4-07，
	# 届时改由那一侧通过 set_options() 注入即可 —— 本场景不关心选项从哪来。
	set_options(default_options())
	# 提示面板可点任意处关闭。
	register_dismissible_notice(_notice_panel)
	# 刻意**不登记 focus root**：本场景的三个可点面是 RewardCard（Panel + gui_input），
	# 不是 Button。Control 虽然都有 focus_mode，但 Godot 只替 Button 一类把「确认键」
	# 接到 pressed 上；要让卡片吃键盘，得自己实现一套「焦点 → 确认 → 选项」的映射，
	# 成本明显超出本卡（交付物 3 允许 Escape + 点击，但要求把取舍写进 CONSTRAINT CHECK）。
	# 故本场景的键盘路径是 Escape 返回，方向键 + Enter 留在后续批次（卡片键盘化）。
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)


## 本批（FIRST PLAYABLE 4/4）的三选项池：一波清空后摆出来的**固定三项**，玩家挑一个。
##
## 卡面允许「选项可以是固定池」，故这里没有随机、没有掉率、没有稀有度权重 ——
## 那三样连同「选中之后真的把东西给到玩家手里」都属 Stage 4 的 S4-07。
## 本批只把选项**显示**出来，并把玩家选中的那一项经 get_chosen_option() 交出去。
##
## 三项都是玩家在整备界面**真能拖出来**的东西：名字逐字取 06 §4 的仓库槽位名（核心 / 增幅 / 炸弹），
## 数值则从它们的定义处现取，不在这里抄第二份。卡片上的「伤害 25」与结算里真正生效的那个 25
## 一旦漂开，玩家会照着卡面做决定 —— 而这种错在画面上完全看不出来。
static func default_options() -> Array[RewardOption]:
	var period_seconds: float = float(MachineRuntime.CORE_PERIOD_TICKS) / float(MachineRuntime.TICK_RATE)
	var bomb: WeaponData = WeaponData.for_kind(WeaponData.Kind.BOMB)
	return [
		RewardOption.new(RewardOption.Kind.CORE, "核心", "CORE",
			"每 %.1f 秒一次脉冲" % period_seconds, "自己就是信号源，不需要上游连线"),
		RewardOption.new(RewardOption.Kind.FUNCTION, "增幅", "FUNCTION",
			"脉冲 ×%d" % roundi(MachineRuntime.AMPLIFY_FACTOR), "进一枚，出去一枚更强的"),
		RewardOption.new(RewardOption.Kind.WEAPON, bomb.display_name, "WEAPON",
			"伤害 %d" % roundi(bomb.damage), "打全场，不分先后"),
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


## Escape：放弃本次奖励，回 PREPARATION（03 §1 状态图 REWARD → PREPARATION）。
##
## 这是 06 §9「跳过」语义的键盘等价物：三个选项卡本来就是「可选其一，也可以不选」，
## 玩家按 Escape 时**没有选定任何一项**，故 _chosen_option 保持 null ——
## 它记录的正是「离开本场景的原因」，而「没选」与「选了跳过」是两件事，不能混为一谈。
##
## 与 _on_option_chosen() 同款先查路由：静默无效是验收不接受的。
## 提示面板的关闭由 InputScreen._handle_notice() 统一处理，本场景不必再写 _input。
func _on_back_requested() -> bool:
	var target_path: String = GameFlow.get_scene_path_for(GameFlow.GameState.PREPARATION)
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		_show_notice(NOTICE_PREPARATION)
		return true
	GameFlow.change_state(GameFlow.GameState.PREPARATION)
	return true


## 把控件贴到矩形上。都是场景根或卡片区下的普通 Control（非容器），故直接给位置与尺寸。
func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
