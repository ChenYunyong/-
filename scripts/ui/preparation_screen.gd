## preparation_screen.gd
## 职责：PREPARATION 场景 —— 06 §7 的五分区占位布局、06 §7.1 的窄屏折叠，
##       以及右下角「开始战斗」这个进入 COMBAT 的唯一入口。
##       **本批只做骨架与布局，不含任何蓝图玩法。**
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、RunState、PreparationLayout、MessagePanel、InputScreen、
##       InputNormalizer、BlueprintWorkspace
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得出现任何会自动推进的构造（Timer / create_timer / _process / _physics_process，
##       见 03 §2 与 06 §10.1 R1）—— 进入 PREPARATION 后永远等玩家，
##       停留任意时长都不会自行进入 COMBAT；
##       本文件不得自己实现节点放置 / 连线 / 存档 —— 那些在 blueprint_workspace.gd 里，
##       这里只负责把两个工作区节点摆到 06 §7 的分区矩形上；信号传播 / 校验 / 删除 / 撤销仍属 Stage 3。

extends InputScreen

## 工作区内容与分区那圈 1px 描边之间留的间距。像素探针逐像素断言四条边都在，
## 内容一旦压上去那圈描边就断了 —— 故画布与仓库都按此内缩后再落位。
const WORKSPACE_INSET: float = 2.0

## 提示面板文案。COMBAT 与 RESULT 均已由 S1-08 / S1-10 落地，这里的提示只在**路由故障**时出现
## （场景文件缺失 / 路径写错），措辞与 main_menu.gd 的同名提示对齐。
const NOTICE_TITLE: String = "尚未实现"
const NOTICE_DISMISS: String = "点击任意处关闭"
const NOTICE_COMBAT: String = "战斗场景（COMBAT）的路由未就绪，本次留在整备场景。"
const NOTICE_RESULT: String = "结算场景（RESULT）的路由未就绪，本次留在整备场景。"

@onready var _backdrop: ColorRect = %Backdrop
@onready var _region_left: Control = %RegionLeft
@onready var _region_center: Control = %RegionCenter
@onready var _region_right: Control = %RegionRight
@onready var _region_bottom: Control = %RegionBottom
@onready var _region_action: Control = %RegionAction
@onready var _button_start_combat: Button = %ButtonStartCombat
@onready var _notice_panel: MessagePanel = %NoticePanel
@onready var _blueprint_canvas: Control = %BlueprintCanvas
@onready var _node_warehouse: Control = %NodeWarehouse

## 五个分区容器，下标即 PreparationLayout.Region。顺序必须与场景里的节点顺序一致。
var _regions: Array[Control] = []
var _viewport_size: Vector2 = Vector2.ZERO
var _is_narrow: bool = false
var _info_expanded: bool = false


func _ready() -> void:
	# 全屏底色取自 Palette —— 场景里那个 ColorRect 不带 color 字面量（06 §10.7）。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	_regions = [_region_left, _region_center, _region_right, _region_bottom, _region_action]
	# 06 §7：「开始战斗」是右下角唯一的主动作按钮，也是 PREPARATION → COMBAT 的唯一入口。
	_button_start_combat.pressed.connect(_on_start_combat_pressed)
	# 06 §7.1：窄屏下左栏收起成信息条，点它展开为覆盖层。
	_region_left.gui_input.connect(_on_info_bar_gui_input)
	# 06 §1：命中区补齐。CTA 实机尺寸 64×20（06 §7.2 ①，且被像素探针逐值断言），
	# 差 2 逻辑像素；窄屏信息条高 16（PreparationLayout.INFO_BAR_HEIGHT）—— 两个都不达标，
	# 两个都不能靠改 size 补（前者会打红像素基线，后者是布局常量、不归本卡改）。
	install_hit_minimum(_button_start_combat)
	install_hit_minimum(_region_left)
	# 提示面板可点任意处关闭；键盘导航从 CTA 起步（本场景唯一的可用按钮）。
	register_dismissible_notice(_notice_panel)
	register_focus_root(_button_start_combat)
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)
	# 必须排在 apply_layout_for 之后：落格要按画布**已经拿到手**的尺寸算。
	_apply_pending_reward()


## 把 REWARD 里玩家选中的那一项落到蓝图上（S4-07 最小版：奖励真的生效）。
##
## 载荷经 RunState 这个**既有**载体跨场景带过来（不新造全局单例、不新开存档服务），
## 落成即清 —— 一次选择只落一次，重复进入 PREPARATION 不会重复发奖。
##
## 类型判定不在本文件：载荷里的 kind / function_kind / weapon_kind 是仓库槽位那三列，
## 落地由 blueprint_workspace.add_reward_node() 负责 —— 本文件只把载荷转交给它，
## 于是「谁的类型对」只有一处可查。
##
## 画布取不到（角色不对 / 结构被改坏）或格子已满时不落，载荷留在 RunState 里不清：
## 前者是结构问题、后者玩家清一个格子后重进就能拿到，都比「悄悄吃掉玩家的奖励」强。
func _apply_pending_reward() -> void:
	var reward: Dictionary = RunState.pending_reward()
	if reward.is_empty():
		return
	var canvas: BlueprintWorkspace = _blueprint_canvas as BlueprintWorkspace
	if canvas == null or canvas.add_reward_node(reward) == null:
		return
	RunState.clear_pending_reward()


## 当前是否处于 06 §7.1 的折叠布局。
func is_narrow_layout() -> bool:
	return _is_narrow


## 按给定可用区尺寸落一次布局。宽屏走 06 §7 的实测值，窄屏走 §7.1 的折叠规则。
##
## 折叠只改变**布局**：不碰 GameFlow、不发信号、不改任何状态
## （06 §7.1 末条「折叠只改变布局，不改变任何玩法规则与状态流」）。
## 因此本函数可以在测试里被显式调用，不必真去改窗口尺寸。
func apply_layout_for(viewport_size: Vector2) -> void:
	_viewport_size = viewport_size
	_is_narrow = PreparationLayout.is_narrow(viewport_size)
	if not _is_narrow:
		# 回到宽屏时左栏不再是可折叠的信息条，展开态一并收回，
		# 免得下次进窄屏时它带着上次的展开态出现。
		_info_expanded = false
	var rects: Array[Rect2] = PreparationLayout.narrow_rects(viewport_size) if _is_narrow \
		else PreparationLayout.wide_rects()
	for index: int in _regions.size():
		_place(_regions[index], rects[index])
	if _is_narrow:
		_place(_region_left, PreparationLayout.narrow_info_rect(viewport_size, _info_expanded))
	# §7.1：右栏窄屏改底部弹层，「选中节点时弹出」。选中节点属 S2-03，本批没有选中，
	# 故弹层默认收起 —— 它是不是弹层由矩形位置证明，不由可见性证明。
	_region_right.visible = not _is_narrow
	# §7.1 只说信息条「点击展开」，宽屏那块左栏是纯占位，不该吃掉落在它上面的点击。
	_region_left.mouse_filter = Control.MOUSE_FILTER_STOP if _is_narrow \
		else Control.MOUSE_FILTER_IGNORE
	# CTA 的落位见 PreparationLayout.action_button_rect 的说明（§7 的 14px 区块装不下按钮）。
	_place(_button_start_combat, PreparationLayout.action_button_rect(
		rects[PreparationLayout.Region.ACTION], _button_start_combat.get_combined_minimum_size()))
	# 蓝图工作区：画布占中栏，节点仓库占底条。两者都从分区矩形内缩，让开那圈 1px 描边。
	# 放在 CTA 之后：仓库要让开 CTA，得先知道 CTA 落在哪。
	_place(_blueprint_canvas, _inset(rects[PreparationLayout.Region.CENTER]))
	_place(_node_warehouse, _warehouse_rect(rects[PreparationLayout.Region.WAREHOUSE]))


func _on_resized() -> void:
	apply_layout_for(size)


## 06 §7.1：窄屏下左栏收起为 16px 信息条，**点击展开为覆盖层**。
## 事件先经输入层归一，这里只看语义：触摸按下与鼠标左键按下在 InputNormalizer 里
## 已经合流成同一条 POINTER_PRESS，不再需要「触摸端由引擎合成鼠标事件」那条间接路径（03 §8）。
func _on_info_bar_gui_input(event: InputEvent) -> void:
	var semantic: SemanticInput = InputNormalizer.from_event(event)
	if semantic == null or semantic.action != SemanticInput.Action.POINTER_PRESS:
		return
	_info_expanded = not _info_expanded
	apply_layout_for(_viewport_size)
	accept_event()


## 「开始战斗」：请求进入 COMBAT（03 §1 状态图 PREPARATION → COMBAT，硬规则 R1）。
##
## S1-08 落地后这条路由已经通了，正常情况直接放行。这里仍然先查路由是否就绪，
## 而不是闭眼调用 request_start_combat()：GameFlow 的提交点先落状态再路由，
## 对缺失的场景只打印一行、当前场景不动（见 game_flow.gd 的 _route_to_scene），
## 直接调用会让状态与场景脱钩 —— 玩家看到的是「按了没反应」，那正是验收不接受的静默无效。
## 查的是 GameFlow 自己登记的 SCENE_ROUTES（唯一路由来源），不在这里另抄一份路径。
## 它现在守的是真正的路由故障（场景文件缺失 / 路径写错），而不是「尚未实现」。
func _on_start_combat_pressed() -> void:
	var target_path: String = GameFlow.get_scene_path_for(GameFlow.GameState.COMBAT)
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		_show_notice(NOTICE_COMBAT)
		return
	GameFlow.request_start_combat()


## 显示提示。key 为 tr() 的原文 key（暂无翻译表，06 §11）。
func _show_notice(message_key: String) -> void:
	_notice_panel.show_message(NOTICE_TITLE, PackedStringArray([message_key, NOTICE_DISMISS]))


## Escape：从 PREPARATION 退出本局 → RESULT（03 §1 状态图 PREPARATION → RESULT）。
##
## 走 request_end_run() 而不是 change_state()：R3 把这个语义入口定为「→ RESULT」的**唯一**
## 合法通道，与 combat_screen.gd 的 on_core_destroyed() 同一条路。本场景是「还没开打就退出」，
## 语义上正是「结束本局」。
##
## 先查路由是否就绪再调用：GameFlow 的提交点先落状态再路由，对缺失的场景只打印一行、
## 当前场景不动 —— 直接调用会让状态与场景脱钩，玩家看到的是「按了没反应」，
## 那正是验收不接受的静默无效（与 _on_start_combat_pressed 同款判断）。
##
## 提示面板的关闭由 InputScreen._handle_notice() 统一处理，本场景不必再写 _input。
func _on_back_requested() -> bool:
	var target_path: String = GameFlow.get_scene_path_for(GameFlow.GameState.RESULT)
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		_show_notice(NOTICE_RESULT)
		return true
	GameFlow.request_end_run()
	return true


## 把分区 / 内容贴到矩形上。分区都是普通 Control（非容器），故直接给位置与尺寸。
##
## 传进来的矩形一律是**视口坐标**（PreparationLayout 与 06 §7 的实测值都是视口坐标），
## 而控件的位置是**相对父级**的。分区自己就带偏移 —— RegionCenter 在 (98,8)、RegionBottom 在 (15,132) ——
## 挂在其下的画布与仓库若照抄视口坐标，就会再叠一次父级偏移，内容整体跑出屏幕
## （画布会从 x=198 一直画到 322，而基准视口只有 320 宽）。故这里统一减掉父级偏移；
## 父级是场景根时它的位置是 (0,0)，这一步是恒等变换，五个分区与 CTA 的落位不受影响。
func _place(control: Control, rect: Rect2) -> void:
	var parent: Control = control.get_parent() as Control
	var origin: Vector2 = parent.position if parent != null else Vector2.ZERO
	control.position = rect.position - origin
	control.size = rect.size


## 分区内容的内缩（见 WORKSPACE_INSET）。尺寸被内缩吃光时给 0，不给负值。
func _inset(rect: Rect2) -> Rect2:
	var margin := Vector2(WORKSPACE_INSET, WORKSPACE_INSET)
	return Rect2(rect.position + margin, (rect.size - margin * 2.0).max(Vector2.ZERO))


## 节点仓库的可用矩形：底条内缩后再让开右下角的 CTA。
## 06 §7 里 CTA 区块本就压在底条右端上，仓库不能画到按钮底下 —— 那会既看不见也点不到。
## 窄屏（§7.1）底条只有 180px 宽、CTA 独取 44px，仓库因此只剩 CTA 左侧一段；
## 那一段放得下几个槽位由 blueprint_workspace.gd 按宽度自己算，不在布局层写死。
func _warehouse_rect(rect: Rect2) -> Rect2:
	var body: Rect2 = _inset(rect)
	var limit: float = _button_start_combat.position.x - WORKSPACE_INSET
	body.size.x = maxf(body.size.x - maxf(body.end.x - limit, 0.0), 0.0)
	return body
