## preparation_screen.gd
## 职责：PREPARATION 场景 —— 06 §7 的五分区占位布局、06 §7.1 的窄屏折叠，
##       右下角「开始战斗」这个进入 COMBAT 的唯一入口，
##       以及编辑蓝图的三件事的**界面侧**（S2-05 补课）：删除 / 撤销 / 清空。
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、RunState、PreparationLayout、MessagePanel、InputScreen、
##       InputNormalizer、BlueprintWorkspace
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；三个动作按钮的**键盘**键位也不在本文件判 ——
##       它落在 .tscn 的 Button.shortcut 上（Delete / Backspace / Ctrl+Z），
##       于是本文件连键码都不出现；
##       不得出现任何会自动推进的构造（Timer / create_timer / _process / _physics_process，
##       见 03 §2 与 06 §10.1 R1）—— 进入 PREPARATION 后永远等玩家，
##       停留任意时长都不会自行进入 COMBAT；
##       本文件不得自己实现节点放置 / 连线 / 存档 / 删除 / 撤销 —— 那些在 blueprint_workspace.gd 里，
##       这里只做两件事：把两个工作区节点摆到 06 §7 的分区矩形上，
##       再把三个动作按钮按「当前选中了什么」置灰 / 点亮（判据全在画布，本文件不自算）；
##       信号传播 / 类型校验 / 环路检测属 S2-06 及以后，本卡明确不做。

extends InputScreen

## 工作区内容与分区那圈 1px 描边之间留的间距。像素探针逐像素断言四条边都在，
## 内容一旦压上去那圈描边就断了 —— 故画布与仓库都按此内缩后再落位。
const WORKSPACE_INSET: float = 4.0

## 提示面板文案。COMBAT 与 RESULT 均已由 S1-08 / S1-10 落地，这里的提示只在**路由故障**时出现
## （场景文件缺失 / 路径写错），措辞与 main_menu.gd 的同名提示对齐。
const NOTICE_TITLE: String = "尚未实现"
const NOTICE_DISMISS: String = "点击任意处关闭"
const NOTICE_COMBAT: String = "战斗场景（COMBAT）的路由未就绪，本次留在整备场景。"
const NOTICE_RESULT: String = "结算场景（RESULT）的路由未就绪，本次留在整备场景。"

## 三个动作按钮的文案。清空是**二次确认**（06 §10.4）：第一下只把文案换成问句，
## 第二下才真的清 —— 于是「误触一次」最多让人多看一眼，而不是把整张图删掉。
const LABEL_DELETE: String = "删除"
const LABEL_UNDO: String = "撤销"
const LABEL_CLEAR: String = "清空法术书"
const LABEL_CLEAR_ARMED: String = "确认清空？"

## 动作列每行的高度与行间距（逻辑像素）。24 是 06 §1 的触摸下限（2× 下 48 设备像素），
## 间距 2 让相邻两行不至于看成一整块。
const ACTION_ROW_HEIGHT: float = 48.0
const ACTION_ROW_GAP: float = 4.0

@onready var _backdrop: ColorRect = %Backdrop
@onready var _region_left: Control = %RegionLeft
@onready var _region_center: Control = %RegionCenter
@onready var _region_right: Control = %RegionRight
@onready var _region_bottom: Control = %RegionBottom
@onready var _region_action: Control = %RegionAction
@onready var _button_start_combat: Button = %ButtonStartCombat
@onready var _notice_panel: MessagePanel = %NoticePanel
@onready var _blueprint_canvas: BlueprintWorkspace = %BlueprintCanvas
@onready var _node_warehouse: Control = %NodeWarehouse
@onready var _button_delete: Button = %ButtonDelete
@onready var _button_undo: Button = %ButtonUndo
@onready var _button_clear: Button = %ButtonClear

## 五个分区容器，下标即 PreparationLayout.Region。顺序必须与场景里的节点顺序一致。
var _regions: Array[Control] = []
var _viewport_size: Vector2 = Vector2.ZERO
var _is_narrow: bool = false
var _info_expanded: bool = false
## 「清空」的二次确认是否已经举起来（见 _on_clear_pressed）。
var _clear_armed: bool = false


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
	# 三个动作按钮。判据全在画布（选中了什么 / 还剩什么 / 能不能撤），本文件只做转交 ——
	# 于是「选中之后删除才可用」这条规则只有一处实现，不会界面一份、画布一份地走偏。
	_button_delete.pressed.connect(_on_delete_pressed)
	_button_undo.pressed.connect(_on_undo_pressed)
	_button_clear.pressed.connect(_on_clear_pressed)
	# 画布改了图或改了选中就重算可用性。不订阅的话，玩家选中一个节点后删除按钮仍是灰的 ——
	# 而画布不可能自己知道按钮长什么样。
	_blueprint_canvas.blueprint_changed.connect(_on_blueprint_changed)
	# 提示面板可点任意处关闭；键盘导航从 CTA 起步（本场景唯一的主动作按钮）。
	register_dismissible_notice(_notice_panel)
	register_focus_root(_button_start_combat)
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)
	_refresh_actions()
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
	if _blueprint_canvas == null or _blueprint_canvas.add_reward_node(reward) == null:
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
	_place_actions()
	# 三个动作按钮在窄屏**收起时**跟着左栏一起藏起来：那时左栏只剩 16px 高，
	# 按 24px 的行高摆进去会被裁掉一半，只剩一条看得见点不着的边 —— 那不是「不可用」，是坏的。
	# 展开后左栏变成覆盖层，位置够了，它们就回来。宽屏则一直在。
	var actions_visible: bool = not _is_narrow or _info_expanded
	for button: Button in [_button_delete, _button_undo, _button_clear]:
		button.visible = actions_visible


func _on_resized() -> void:
	apply_layout_for(size)


# ─────────────────── 删除 / 撤销 / 清空的界面侧（S2-05 补课）───────────────────


## 画布改了图、或改了选中。判据一律问画布，本文件不自算 ——
## 「有选中才能删」这件事只有一个答案来源，界面与画布不可能各说各话。
##
## 顺手把「清空」的二次确认收回：举着确认的时候去点别处，就是一个明确的「算了」。
## 不收回的话确认态会一直挂着，下一次无关的改动之后再点一下就整张清掉 ——
## 那正是二次确认要防的事故。而「举着的时候再点同一个按钮」不经过这里（它不发信号），
## 所以确认照样点得下去。
func _on_blueprint_changed() -> void:
	_clear_armed = false
	_refresh_actions()


## 三个按钮的可用性与文案。**不可用而不是隐藏**（06 §10.4）：隐藏会让人以为这功能不存在，
## 置灰才是「现在还不能用」。文案要经 tr()（06 §11）—— 本文件在代码里改它，静态翻译不会自动生效，
## 与 blueprint_workspace.warehouse_label() 是同一条做法。
func _refresh_actions() -> void:
	if _blueprint_canvas == null:
		return
	_button_delete.disabled = not _blueprint_canvas.has_selection()
	_button_undo.disabled = not _blueprint_canvas.can_undo()
	_button_clear.disabled = not _blueprint_canvas.has_content()
	_button_clear.text = TranslationServer.translate(LABEL_CLEAR_ARMED if _clear_armed else LABEL_CLEAR)


## 删除当前选中。删的是节点还是连线由画布决定 —— 它才知道玩家选中了什么。
func _on_delete_pressed() -> void:
	_blueprint_canvas.delete_selection()


func _on_undo_pressed() -> void:
	_blueprint_canvas.undo()


## 清空：**按两下才算**（06 §10.4 的二次确认）。第一下只把文案换成问句，
## 第二下才真清。清空进撤销栈，所以确认过也还撤得回来 ——
## 二次确认与撤销是并列的两条路，这里两条都有，因为清空是唯一一个一下能毁掉整张图的动作。
##
## 刷新交给画布的信号，这里不重复调：本函数结束时 clear_blueprint() 已经发过一轮。
func _on_clear_pressed() -> void:
	if not _clear_armed:
		_clear_armed = true
		_refresh_actions()
		return
	_clear_armed = false
	_blueprint_canvas.clear_blueprint()


## 三个动作按钮贴左栏**底部**排列，自下而上：清空 / 撤销 / 删除。
##
## 为什么是左栏（06 §7 把左栏定为「关卡信息」）：其余四块都腾不出地方 ——
## 中栏整块是画布；底条宽屏只剩约 35px 余量，窄屏还要让开 CTA；右栏在窄屏根本不显示。
## 而本卡要求触摸端也够得着，左栏是唯一**两种宽高比下都在场**的分区：宽屏是整块侧栏，
## 窄屏点一下信息条即展开成覆盖层（§7.1 既有交互，本卡没有新增任何折叠机制）。
## 这是对 13 §4 信息架构的一处偏离，已在交付报告里逐条声明。
##
## 自下而上、以底边为基准：底边不随标题长短变，于是这三个按钮的位置与标题内容无关，
## 换文案 / 换语言都不会把它们顶出面板。
##
## 这里直接给 position/size 而**不经 _place()**：_place 收的是场景根坐标、要减掉父级偏移，
## 而这几个按钮的父级就是 RegionLeft，本函数算出来的已经是 RegionLeft 局部坐标。
func _place_actions() -> void:
	var body: Rect2 = _inset(Rect2(Vector2.ZERO, _region_left.size))
	var rows: Array[Button] = [_button_clear, _button_undo, _button_delete]
	var step: float = ACTION_ROW_HEIGHT + ACTION_ROW_GAP
	for index: int in rows.size():
		var bottom: float = body.end.y - float(index) * step
		rows[index].position = Vector2(body.position.x, bottom - ACTION_ROW_HEIGHT)
		rows[index].size = Vector2(body.size.x, ACTION_ROW_HEIGHT)


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
