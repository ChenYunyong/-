## result_screen.gd
## 职责：RESULT 场景（03 §1 状态图、06 §10）—— 本局结算的**展示落点**与两个出口。
##       展示落点：本局坚持到第几波、本局随机种子（03 §6「种子可展示在结算界面」）。
##       出口：「再来一局」经 GameFlow 回 PREPARATION，「返回主菜单」经 GameFlow 回 MAIN_MENU。
##       **本批只做骨架与布局，不含任何玩法统计。**
## 所属系统：ui
## 依赖：GameFlow、RunState、ResultLayout、PanelTitleBar、MessagePanel、Palette、InputScreen
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得出现任何会自动推进的构造（Timer / create_timer / timeout / _process /
##       _physics_process，见 03 §2 与 00 §5 交互硬规则第 1 条）—— 进入 RESULT 后永远等玩家，
##       不倒计时、不自动回主菜单；
##       不得实现任何玩法统计（波次计分 / 掉落结算 / 局外成长属 Stage 4 的 S4-08）——
##       本文件只把 set_result() 递进来的两个读数摆到界面上，一个数都不算。

extends InputScreen

## 06 §2.2 的面板标题栏文案。06 §11：文本走 tr() key；本阶段没有翻译表，中文原文即 key。
const TITLE_KEY: String = "战斗结算"
## 两个读数的格式串。同样先经 tr()（06 §11），再代入数值。
const WAVE_FORMAT_KEY: String = "坚持到第 %d 波"
const SEED_FORMAT_KEY: String = "随机种子 %d"

## 提示面板文案。两个出口的去处都已由 S1-07 / S1-05 落地，这里的提示只在
## **路由故障**时出现（场景文件缺失 / 路径写错），措辞与 reward_screen.gd 的同名提示对齐。
const NOTICE_TITLE: String = "路由未就绪"
const NOTICE_DISMISS: String = "点击任意处关闭"
const NOTICE_MAIN_MENU: String = "主菜单（MAIN_MENU）的路由未就绪，本次留在结算界面。"
const NOTICE_PREPARATION: String = "整备场景（PREPARATION）的路由未就绪，本次留在结算界面。"

## Stage 4 的 S4-08 才有真实波次数据（RunState 目前不记录波次，03 §6 也不要求它记）。
## 本批给一个占位读数，保证「坚持到第几波」这个落点现在就在；接入时由 set_result() 传入真值。
const WAVE_PLACEHOLDER: int = 1

@onready var _backdrop: ColorRect = %Backdrop
@onready var _title_bar: PanelTitleBar = %TitleBar
@onready var _readout_panel: Panel = %ReadoutPanel
@onready var _wave_value: Label = %WaveValue
@onready var _seed_value: Label = %SeedValue
@onready var _actions: Control = %Actions
@onready var _button_menu: Button = %ButtonMenu
@onready var _button_retry: Button = %ButtonRetry
@onready var _notice_panel: MessagePanel = %NoticePanel

## 本局读数。默认值就是**占位值**，与 set_result() 的注入口径保持一致。
var _wave_reached: int = WAVE_PLACEHOLDER
var _run_seed: int = RunState.SEED_UNSET
## apply_layout_for() 落过的档位。存下来而不是现算 size：折叠与否只由**给进来的那个尺寸**
## 决定，测试可以在不改窗口的前提下显式落一次布局（同 reward_screen.gd 的 _is_narrow）。
var _is_narrow: bool = false


func _ready() -> void:
	# 全屏底色取自 Palette —— 场景里那个 ColorRect 不带 color 字面量（06 §10.7）。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	_title_bar.set_title_key(TITLE_KEY)
	_button_menu.pressed.connect(_on_menu_pressed)
	_button_retry.pressed.connect(_on_retry_pressed)
	# 03 §6：随机种子由 RunState 逐局记录，结算界面展示它是**规范点名**的用途。
	# 这里读的正是那一份，不另建第二份来源 —— 界面只读不回写。
	set_result(WAVE_PLACEHOLDER, RunState.get_run_seed())
	# 提示面板可点任意处关闭；键盘导航从「再来一局」起步 —— 它是本屏的主动作（06 §3 的
	# 主按钮变体），也是玩家在结算界面最可能想按的那一个。焦点本身由 InputScreen
	# 在第一次方向键时才交出去，默认渲染（Normal 态）不受影响。
	register_dismissible_notice(_notice_panel)
	register_focus_root(_button_retry)
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)


## 本局的两个读数落点。Stage 4 的 S4-08 拿到真实数据后经此注入。
##
## 刻意只做「赋值 + 摆到界面上」：不计算、不推断、不读别的系统。波次计分与掉落结算
## 都是 Stage 4 的事，本批一个都不碰。
func set_result(wave_reached: int, run_seed: int) -> void:
	_wave_reached = wave_reached
	_run_seed = run_seed
	_wave_value.text = tr(WAVE_FORMAT_KEY) % _wave_reached
	_seed_value.text = tr(SEED_FORMAT_KEY) % _run_seed


## 界面上此刻显示的波次读数。冒烟据此核对注入是否真的落到了界面上。
func get_wave_reached() -> int:
	return _wave_reached


## 界面上此刻显示的随机种子。来源是 RunState.get_run_seed()（03 §6）。
func get_run_seed_displayed() -> int:
	return _run_seed


## 当前是否处于 06 §7.1 的折叠布局。
func is_narrow_layout() -> bool:
	return _is_narrow


## 按给定可用区尺寸落一次布局。宽屏两个出口横排，窄屏竖排（06 §7.1）。
##
## 折叠只改变**布局**：不碰 GameFlow、不发信号、不改任何状态
## （06 §7.1 末条「折叠只改变布局，不改变任何玩法规则与状态流」）。
## 因此本函数可以在测试里被显式调用，不必真去改窗口尺寸。
func apply_layout_for(viewport_size: Vector2) -> void:
	_is_narrow = ResultLayout.is_narrow(viewport_size)
	_place(_title_bar, ResultLayout.title_rect(viewport_size))
	_place(_readout_panel, ResultLayout.readout_rect(viewport_size))
	_place(_actions, ResultLayout.actions_rect(viewport_size))
	# 按钮是按钮区的子节点，故拿到的矩形以按钮区原点为基准。
	var rects: Array[Rect2] = ResultLayout.action_rects(viewport_size)
	_place(_button_menu, rects[0])
	_place(_button_retry, rects[1])


func _on_resized() -> void:
	apply_layout_for(size)


## 「返回主菜单」→ MAIN_MENU（03 §1 状态图 RESULT → MAIN_MENU）。
func _on_menu_pressed() -> void:
	_request(GameFlow.GameState.MAIN_MENU, NOTICE_MAIN_MENU)


## 「再来一局」→ PREPARATION（03 §1 状态图 RESULT → PREPARATION）。
func _on_retry_pressed() -> void:
	_request(GameFlow.GameState.PREPARATION, NOTICE_PREPARATION)


## 两个出口共用的一条路：先查路由是否就绪，再把状态交给 GameFlow 的单一提交点。
##
## 本场景是**终态前的最后一屏**，两个出口都必须真的走得掉，所以不能闭眼调用 change_state()：
## GameFlow 的提交点先落状态再路由，对缺失的场景只打印一行、当前场景不动
## （见 game_flow.gd 的 _route_to_scene），直接调用会让状态与场景脱钩 ——
## 玩家看到的是「点了没反应」，那正是验收不接受的静默无效。
## 查的是 GameFlow 自己登记的 SCENE_ROUTES（唯一路由来源），不在这里另抄一份路径。
## 形参走 int 而不是枚举类型：与 combat_screen.gd 的 _is_route_ready 同款，
## 跨脚本引用 Autoload 的枚举类型做类型标注会牵出编译期依赖。
func _request(state: int, notice_key: String) -> void:
	var target_path: String = GameFlow.get_scene_path_for(state)
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		_show_notice(notice_key)
		return
	GameFlow.change_state(state)


## 显示提示。key 为 tr() 的原文 key（暂无翻译表，06 §11）。
func _show_notice(message_key: String) -> void:
	_notice_panel.show_message(NOTICE_TITLE, PackedStringArray([message_key, NOTICE_DISMISS]))


## Escape：与「返回主菜单」同一个出口（03 §1 状态图 RESULT → MAIN_MENU）。
##
## 两个出口里选 MAIN_MENU 而不是 PREPARATION：Escape 的语义是「退出 / 返回」，
## 而「再来一局」是**开始**一件事，不是一个「返回」动作 —— 拿 Escape 触发它会让人误开局。
## 故这里复用 _request()，与按钮走完全同一条路（同一份路由检查、同一条提示）。
##
## 提示面板的关闭由 InputScreen._handle_notice() 统一处理，本场景不必再写 _input。
func _on_back_requested() -> bool:
	_request(GameFlow.GameState.MAIN_MENU, NOTICE_MAIN_MENU)
	return true


## 把控件贴到矩形上。都是场景根或按钮区下的普通 Control（非容器），故直接给位置与尺寸。
func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
