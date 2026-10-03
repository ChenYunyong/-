## preparation_screen.gd
## 职责：PREPARATION 场景 —— 06 §7 的五分区占位布局、06 §7.1 的窄屏折叠，
##       以及右下角「开始战斗」这个进入 COMBAT 的唯一入口。
##       **本批只做骨架与布局，不含任何蓝图玩法。**
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、PreparationLayout、MessagePanel
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得出现任何会自动推进的构造（Timer / create_timer / _process / _physics_process，
##       见 03 §2 与 06 §10.1 R1）—— 进入 PREPARATION 后永远等玩家，
##       停留任意时长都不会自行进入 COMBAT；
##       不得实现节点放置 / 连线 / 删除 / 撤销 / 信号传播 / 存档（全部属 Stage 2/3）。

extends Control

## 提示面板文案。COMBAT 已由 S1-08 落地，这里的提示只在**路由故障**时出现
## （场景文件缺失 / 路径写错），措辞与 main_menu.gd 的同名提示对齐。
const NOTICE_TITLE: String = "尚未实现"
const NOTICE_DISMISS: String = "点击任意处关闭"
const NOTICE_COMBAT: String = "战斗场景（COMBAT）的路由未就绪，本次留在整备场景。"

@onready var _backdrop: ColorRect = %Backdrop
@onready var _region_left: Control = %RegionLeft
@onready var _region_center: Control = %RegionCenter
@onready var _region_right: Control = %RegionRight
@onready var _region_bottom: Control = %RegionBottom
@onready var _region_action: Control = %RegionAction
@onready var _button_start_combat: Button = %ButtonStartCombat
@onready var _notice_panel: MessagePanel = %NoticePanel

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
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)


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


func _on_resized() -> void:
	apply_layout_for(size)


## 06 §7.1：窄屏下左栏收起为 16px 信息条，**点击展开为覆盖层**。
## 只认左键按下；触摸端由引擎合成鼠标事件，故鼠标与触摸走同一条路径（06 §10.6）。
func _on_info_bar_gui_input(event: InputEvent) -> void:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
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


## 点击任意处关闭提示。MessagePanel 自己不会消失（BOOT 的失败面板是一去不回的终态），
## 而这里的提示会盖住整个整备界面 —— 关不掉的话，按过一次「开始战斗」之后界面就再也点不动了。
##
## 用 _input 而不是 _unhandled_input：按钮会消费落在自己身上的事件，
## 而「点按钮时也能关掉上一次的提示」正是想要的。只认按下不认抬起，
## 否则「按 开始战斗 → 提示出现 → 同一次点击抬起」会把刚出现的提示立刻关掉。
func _input(event: InputEvent) -> void:
	if not _notice_panel.visible:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.pressed:
		_notice_panel.visible = false


## 把分区贴到矩形上。分区都是场景根下的普通 Control（非容器），故直接给位置与尺寸。
func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
