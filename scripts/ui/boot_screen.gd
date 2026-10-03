## boot_screen.gd
## 职责：BOOT 场景的根脚本 —— 跑启动自检；通过则把控制权交给 GameFlow，失败则显示玩家可读的提示并停住。
## 所属系统：ui
## 依赖：BootCheck, MessagePanel, Palette, GameFlow（Autoload）, InputScreen
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得读写 GameFlow 的内部字段，只能走它的公开入口；
##       不得写任何字面色值 —— 颜色只经 Palette / Theme（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）。
##
## 本场景在输入层是**空实现**，且刻意如此：
##   · 不覆盖 _on_back_requested() —— BOOT 在 ALLOWED_TRANSITIONS 里没有入边（03 §1.1 R1），
##     没有「上一态」可退；按 Escape 什么都不该发生。继承 InputScreen 是为了让六个场景
##     根脚本同源（03 §8「统一输入层」），不是为了在这里也塞一条行为。
##   · 不登记 focus root —— 06 §5 的 BOOT 只有自检提示，没有可交互元素。
##   · 不登记提示面板 —— %ErrorPanel 是一去不回的终态（自检未通过就该停住），
##     点一下关掉它等于把启动故障藏起来。

extends InputScreen

## 自检范围。默认校验正式资产；测试把它指向损坏资产以驱动失败路径（09 §4）。
## 做成 @export 是因为「BOOT 校验哪些资产」本身就是这个场景的配置，不是被写死的常量。
@export var palette_path: String = BootCheck.PALETTE_PATH
@export var theme_path: String = BootCheck.THEME_PATH

@onready var _backdrop: ColorRect = %Backdrop
@onready var _error_panel: MessagePanel = %ErrorPanel


func _ready() -> void:
	# 全屏底色取 Palette 的 NAVY_900 —— 04 §3.1 登记的用途正是「全屏最底背景、遮罩」。
	# 场景文件里刻意不写 color：色值只允许来自 Palette（04 §9 / 06 §10.7）。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	apply_check_result(BootCheck.collect_problems(palette_path, theme_path))


## 自检结果的唯一分岔点：空 = 通过 → 交棒；非空 = 停住并显示提示。
## 公开是为了让失败分支可被直接驱动 —— 正式资产本不该坏，否则这条分支永远拿不到实测证据（09 §4）。
func apply_check_result(problems: PackedStringArray) -> void:
	if problems.is_empty():
		_hand_off_to_game_flow()
		return
	print("BootScreen: 启动自检未通过（%d 项），停在 BOOT。" % problems.size())
	_error_panel.show_message(BootCheck.MSG_TITLE, problems)


## 交棒给顶层状态机。BOOT 只负责「请求推进」，场景怎么换是 GameFlow 的事（03 §1.1 R3）。
## 不处于 BOOT 时直接返回：BOOT 的职责只是把启动态推出去，重复实例化不该再推一次。
func _hand_off_to_game_flow() -> void:
	if not GameFlow.is_state(GameFlow.GameState.BOOT):
		print("BootScreen: GameFlow 当前为 %s（非 BOOT），本次不推进。" % GameFlow.state_name(GameFlow.get_state()))
		return
	GameFlow.change_state(GameFlow.GameState.MAIN_MENU)
