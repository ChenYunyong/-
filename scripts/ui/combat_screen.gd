## combat_screen.gd
## 职责：COMBAT 场景 —— 06 §8 的战场（机器示意区）+ 底部状态带（状态 / 预览的只读展示），
##       以及通往 REWARD / RESULT 的两个触发入口。
##       本批（FIRST PLAYABLE 2/4）把蓝图机器**真的跑起来**：载入蓝图 → 建 MachineRuntime →
##       交给 MachineDriver 按固定节拍推进 → 把 Heat 写进状态带读数。
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、CombatLayout、InputScreen、MachineRuntime、MachineDriver、BlueprintWorkspace
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得自己持有节拍 / 累加器 / 计时构造 —— 时间模型属玩法（03 §2），归 MachineDriver；
##       本文件只负责「把谁交给它」与「把结果写到哪个 Label 上」；
##       不得出现任何需要玩家长按 / 连点的动作控件（00 §5 第 3 条交互硬规则、06 §8）——
##       这条带是状态与预览，COMBAT 阶段玩家不直接操控任何单位；
##       不得结算伤害 / 生成敌人 / 判死亡 / 处理 Overheat（PET-65 / PET-66）。

extends InputScreen

## 可读提示文案。两个出口的目标场景尚未实现（REWARD 属 S1-09、RESULT 属 S1-10）。
const NOTICE_WAVE_CLEARED: String = "本波清空后将进入奖励场景（REWARD），该场景属 S1-09、尚未实现，本次留在战斗场景。"
const NOTICE_CORE_DESTROYED: String = "CORE 被摧毁后将进入结算场景（RESULT），该场景属 S1-10、尚未实现，本次留在战斗场景。"
## Escape 出口的路由故障提示。与上一条分开：那条讲的是「CORE 被摧毁」，
## 而这里玩家按的是 Escape，提示说成 CORE 被摧毁会把人引到错误的方向。
const NOTICE_ESCAPE: String = "结算场景（RESULT）的路由未就绪，本次留在战斗场景。"
## 还没有机器可跑。这是**首次进游戏的正常情况**（玩家没拖过节点），不是错误，故只提示不报错。
const NOTICE_NO_MACHINE: String = "本局还没有机器：先在整备界面拖出 CORE 与武器并连好线，再开始战斗。"
## 有图但没有信号源。给一句可读的解释，免得玩家对着不动的机器猜是卡了还是没接线。
const NOTICE_NO_CORE: String = "这台机器里没有 CORE（信号源），不会有信号流动 —— 补一个 CORE 再开战。"

## 机器示意区的高度：24px 网格上的 2 行，贴战场下沿。上方的空档留给占位弹丸上升，
## 也留给后续卡片（PET-65）的敌人生成区。
const MACHINE_VIEW_HEIGHT: float = 48.0

@onready var _backdrop: ColorRect = %Backdrop
@onready var _battlefield: Control = %Battlefield
@onready var _machine_view: BlueprintWorkspace = %MachineView
@onready var _driver: MachineDriver = %MachineDriver
@onready var _status_bar: Control = %StatusBar
@onready var _status_fill: ColorRect = %StatusFill
@onready var _status_edge: ColorRect = %StatusEdge
@onready var _notice_label: Label = %NoticeLabel

## 06 §8.1 的 `热量` 读数格。取的是读数块里那个叫 `Value` 的 Label。
## **不能**给这个 Label 挂 unique_name：5 个读数块的 Value 同名，`%Value` 只会命中其中一个，
## 而各用例正是按名字 `Value` 逐块找它的。故唯一名挂在读数块（`Heat`）上，再往下走一级。
@onready var _heat_value: Label = %Heat.get_node(^"Value") as Label

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
	# 布局先落定（示意区要先有尺寸才能给节点落格），再建机器。
	reload_machine()


## 载入工作区落盘的蓝图，重建机器并交给 MachineDriver。_ready() 与「换蓝图后重进战斗」都走这一个入口。
##
## 没有机器不是异常：玩家可能一次都没进过整备界面。三种情况各给一句可读提示，
## 而不是让画面沉默 —— 沉默在验收时和「跑起来了但没画出来」完全分不开。
func reload_machine() -> void:
	_machine_view.reload()
	_driver.bind(null)
	_notice_label.visible = false
	_show_heat(0.0)
	var blueprint: BlueprintData = _machine_view.blueprint()
	if blueprint == null or blueprint.nodes.is_empty():
		_show_notice(NOTICE_NO_MACHINE)
		return
	# 图由工作区持有并绘制（06 §8 / 03 §4.3：蓝图在 COMBAT 是只读的），运行时只借用它建索引。
	var machine := MachineRuntime.new(blueprint)
	_machine_view.runtime = machine
	machine.heat_changed.connect(_show_heat)
	# 重绘挂在本拍推进之后，而不是每帧无条件重画：机器不动时画面就一个像素都不重画。
	machine.ticked.connect(_machine_view.queue_redraw)
	_driver.bind(machine)
	if not machine.has_core():
		_show_notice(NOTICE_NO_CORE)


## 06 §8.1 的 `热量` 读数。取整数百分比 —— 读数格只有三位宽（`100%`），小数会被挤掉。
func _show_heat(heat: float) -> void:
	_heat_value.text = "%d%%" % roundi(heat)


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
	_place_machine_view(rects[CombatLayout.Region.BATTLEFIELD])


## 机器示意区贴战场**下沿**（06 §8：CORE 运行、武器执行全部可见、可读）。
## 贴下沿而不是铺满：上方的空档正是占位弹丸上升的地方，也是后续卡片敌人生成区的位置。
func _place_machine_view(battlefield: Rect2) -> void:
	var height: float = minf(MACHINE_VIEW_HEIGHT, battlefield.size.y)
	_place(_machine_view, Rect2(battlefield.position.x, battlefield.end.y - height,
		battlefield.size.x, height))


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
