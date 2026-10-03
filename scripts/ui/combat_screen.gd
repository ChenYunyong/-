## combat_screen.gd
## 职责：COMBAT 场景 —— 06 §8 的占位战场 + 底部状态带（状态 / 预览的只读展示），
##       以及通往 REWARD / RESULT 的两个触发入口。
##       **本批只做骨架与布局，不含任何战斗玩法。**
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、CombatLayout、InputScreen
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得出现任何会自动推进的构造（Timer / create_timer / _process / _physics_process，
##       见 03 §2）—— 敌人生成与推进、CORE 运行、武器执行、伤害结算、Heat / Energy 计算
##       全部属 Stage 4，本批一条都不实现；
##       不得出现任何需要玩家长按 / 连点的动作控件（00 §5 第 3 条交互硬规则、06 §8）——
##       这条带是状态与预览，COMBAT 阶段玩家不直接操控任何单位。

extends InputScreen

## 可读提示文案。两个出口的目标场景尚未实现（REWARD 属 S1-09、RESULT 属 S1-10）。
const NOTICE_WAVE_CLEARED: String = "本波清空后将进入奖励场景（REWARD），该场景属 S1-09、尚未实现，本次留在战斗场景。"
const NOTICE_CORE_DESTROYED: String = "CORE 被摧毁后将进入结算场景（RESULT），该场景属 S1-10、尚未实现，本次留在战斗场景。"
## Escape 出口的路由故障提示。与上一条分开：那条讲的是「CORE 被摧毁」，
## 而这里玩家按的是 Escape，提示说成 CORE 被摧毁会把人引到错误的方向。
const NOTICE_ESCAPE: String = "结算场景（RESULT）的路由未就绪，本次留在战斗场景。"

@onready var _backdrop: ColorRect = %Backdrop
@onready var _battlefield: Control = %Battlefield
@onready var _status_bar: Control = %StatusBar
@onready var _status_fill: ColorRect = %StatusFill
@onready var _status_edge: ColorRect = %StatusEdge
@onready var _notice_label: Label = %NoticeLabel

## 两块区域容器，下标即 CombatLayout.Region。顺序必须与场景里的节点顺序一致。
var _regions: Array[Control] = []
var _is_narrow: bool = false


func _ready() -> void:
	# 底色全部取自 Palette —— 场景里那几个 ColorRect 不带 color 字面量（06 §10.7）。
	# 06 §8：状态带底色 NAVY_800、上沿 1px NAVY_600 分隔。用两块纯色 ColorRect 而不是 Panel 变体，
	# 是因为 §8 只给这一条上沿；主题里最接近的 PanelCore 是**四边**各 1px NAVY_600，
	# 套上去会在带的下沿与左右两侧多出三条 §8 没规定的描边。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	_status_fill.color = Palette.get_color(Palette.Key.NAVY_800)
	_status_edge.color = Palette.get_color(Palette.Key.NAVY_600)
	_regions = [_battlefield, _status_bar]
	_notice_label.visible = false
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)


## 当前是否处于 06 §7.1 的折叠布局。
func is_narrow_layout() -> bool:
	return _is_narrow


## 按给定可用区尺寸落一次布局。宽屏走 06 §8 的实测值，窄屏走 §7.1 的折叠规则。
##
## 折叠只改变**布局**：不碰 GameFlow、不发信号、不改任何状态
## （06 §7.1 末条「折叠只改变布局，不改变任何玩法规则与状态流」）。
## 因此本函数可以在测试里被显式调用，不必真去改窗口尺寸。
func apply_layout_for(viewport_size: Vector2) -> void:
	_is_narrow = CombatLayout.is_narrow(viewport_size)
	var rects: Array[Rect2] = CombatLayout.narrow_rects(viewport_size) if _is_narrow \
		else CombatLayout.wide_rects()
	for index: int in _regions.size():
		_place(_regions[index], rects[index])


func _on_resized() -> void:
	apply_layout_for(size)


## 本波清空 → REWARD（03 §1.1 R2：这条边**只能**由「本波清空」触发）。
## 「清空」怎么判定属 Stage 4，本批只留这个入口。
func on_wave_cleared() -> void:
	if not _is_route_ready(GameFlow.GameState.REWARD):
		_show_notice(NOTICE_WAVE_CLEARED)
		return
	GameFlow.change_state(GameFlow.GameState.REWARD)


## CORE 被摧毁 → RESULT（03 §1.1 R2）。走 request_end_run() 这个语义入口 ——
## R3 把它定为「→ RESULT」的**唯一**合法通道，故这里不绕道 change_state()。
func on_core_destroyed() -> void:
	if not _is_route_ready(GameFlow.GameState.RESULT):
		_show_notice(NOTICE_CORE_DESTROYED)
		return
	GameFlow.request_end_run()


## Escape：从 COMBAT 退出本局 → RESULT（03 §1 状态图 COMBAT → RESULT）。
##
## 与 on_core_destroyed() 同一个出口、同一个语义入口 request_end_run()（R3 定的唯一通道）。
## COMBAT 在状态图里只有 REWARD / RESULT 两条出边，而 REWARD 的入边被 R2 锁死为「本波清空」
## 这一件事 —— 玩家按 Escape 时并没有清空本波，故「返回」在这里只能是「结束本局」。
## Stage 1 的 COMBAT 没有真实战斗（Stage 1 禁令），也就不存在「误按 Escape 丢掉一整局」的代价。
##
## 留给 Stage 2+：那时 COMBAT 会有暂停菜单，Escape 应先开暂停而不是直接结束本局 ——
## 届时应把这里改成「打开暂停」，并由暂停菜单里的显式按钮走 request_end_run()。
##
## 本场景**不登记 focus root**：06 §8 规定状态带全部为只读 Label、不得新增按钮，
## 没有可导航的控件，方向键在这里本来就无事可做（也不该有事可做）。
func _on_back_requested() -> bool:
	if not _is_route_ready(GameFlow.GameState.RESULT):
		_show_notice(NOTICE_ESCAPE)
		return true
	GameFlow.request_end_run()
	return true


## 目标场景是否已就绪。查的是 GameFlow 自己登记的 SCENE_ROUTES（唯一路由来源），
## 不在这里另抄一份路径；待 S1-09 / S1-10 落地、场景文件存在后，本判断自动放行，无需回头改这里。
## 直接请求也不会崩，但 GameFlow 的提交点先落状态再路由、对缺失的场景只打印一行 ——
## 玩家那边看到的是「发生了又没发生」，那正是验收不接受的静默无效。
func _is_route_ready(state: int) -> bool:
	var target_path: String = GameFlow.get_scene_path_for(state)
	return not target_path.is_empty() and ResourceLoader.exists(target_path)


## 显示可读提示。**刻意不用 MessagePanel 模态面板**：06 §10.3 禁止 COMBAT 期间弹出需要
## 玩家即时反应的模态窗口，而这条提示只是告知「出口还没做好」，不该打断对战场运行结果的观察。
## key 为 tr() 的原文 key（暂无翻译表，06 §11）。
func _show_notice(message_key: String) -> void:
	_notice_label.text = tr(message_key)
	_notice_label.visible = true


## 把区域贴到矩形上。区域都是场景根下的普通 Control（非容器），故直接给位置与尺寸。
func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
