## input_screen.gd
## 职责：六个场景根脚本的共同基类 —— 场景层与输入层之间的**唯一接口**（03 §8、本卡交付物 1）。
##       场景不再自己看原始事件：_input 在这里被归一成 SemanticInput，再分发给三件共同的事
##       （关提示 / Escape 返回 / 键盘导航起步），以及子类覆盖的 _on_back_requested()。
## 所属系统：input
## 依赖：SemanticInput、InputNormalizer、HitButton、HitControl
## 禁止：本文件不得出现 InputEventMouseButton / InputEventScreenTouch / InputEventKey ——
##       原始事件的翻译只在 input_normalizer.gd 一处；
##       不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）。

class_name InputScreen
extends Control

const HIT_BUTTON_SCRIPT: String = "res://scripts/input/hit_button.gd"
const HIT_CONTROL_SCRIPT: String = "res://scripts/input/hit_control.gd"

## 可点任意处关闭的提示面板。未登记的场景（COMBAT）不做关闭处理。
##
## 名字带 base_ 前缀：子类各自持有同名的 @onready var _notice_panel（类型更具体，
## 如 MessagePanel），GDScript 不允许子类重复声明父类已有的成员名。语义上两者是同一块面板，
## 但一个是「输入层眼里的可关闭控件」、一个是「场景眼里的具体组件」，分开命名也说得通。
var base_notice_panel: Control = null
## 键盘导航的起步控件。未登记表示本场景没有可导航的控件（COMBAT 按 06 §8 只有只读 Label）。
var base_focus_entry: Control = null
## 是否已经把焦点交出去过。见 _bootstrap_focus()。
var base_focus_started: bool = false


## 场景在 _ready() 里登记自己的提示面板。
func register_dismissible_notice(panel: Control) -> void:
	base_notice_panel = panel


## 场景在 _ready() 里登记键盘导航的起步控件。
func register_focus_root(control: Control) -> void:
	base_focus_entry = control


## 给一个可交互控件装上 06 §1 的命中下限适配器 —— 只改拾取，不改视觉。
##
## 为什么是运行期 set_script 而不是在 .tscn 上挂：六个场景文件都不在本卡的允许文件清单里
## （本卡只动 scripts/ui/*.gd），而命中下限是输入层的事，不该散进六个 .tscn 各挂一份。
## set_script 只换脚本实例，节点上已有的 text / offset / size_flags / 主题覆盖全部保留：
## 视觉矩形一个像素都不动，这正是该适配器存在的意义（见 hit_button.gd 的说明）。
func install_hit_minimum(control: Control) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control is HitButton or control is HitControl:
		return
	if control.get_script() != null:
		# 已经挂了别的脚本。覆盖别人的行为比命中区差 2px 更糟，故不装，
		# 并留下一行可查的痕迹 —— 静默不装会让人以为装上了。
		push_warning("InputScreen: %s 已有脚本，跳过命中下限适配。" % control.name)
		return
	control.set_script(load(HIT_BUTTON_SCRIPT if control is Button else HIT_CONTROL_SCRIPT))


## 输入总入口。原始事件在这里变成语义事件，之后本层只认语义。
func _input(event: InputEvent) -> void:
	var semantic: SemanticInput = InputNormalizer.from_event(event)
	if semantic == null:
		return
	if _handle_notice(semantic):
		accept_event()
		return
	if semantic.action == SemanticInput.Action.NAV_BACK:
		if _on_back_requested():
			accept_event()
		return
	if SemanticInput.is_directional(semantic.action) and _bootstrap_focus():
		accept_event()


## 子类覆盖：Escape（「返回」）在本场景里去哪。返回 true 表示已处理。
##
## 默认不处理 —— 这正是 BOOT 想要的：它在 ALLOWED_TRANSITIONS 里没有入边，
## 没有「上一态」可回（03 §1.1 R1），按 Escape 什么都不该发生。
func _on_back_requested() -> bool:
	return false


## 提示面板的关闭处理。返回 true 表示事件已被吃掉。
##
## 指针按下**关提示但不消费**：落在按钮 / 卡片上的那一次点击，既该关掉上一次的提示，
## 也该正常触发那个控件 —— 这是既有行为（原 main_menu.gd 的 _input 注释），不能改。
## 只认按下不认抬起：否则「按 设置 → 提示出现 → 同一次点击抬起」会把刚出现的提示立刻关掉。
##
## Escape **关提示且消费**：不消费的话，同一次 Escape 会紧接着触发场景的返回，玩家按一下退两步。
func _handle_notice(semantic: SemanticInput) -> bool:
	if base_notice_panel == null or not is_instance_valid(base_notice_panel) or not base_notice_panel.visible:
		return false
	if semantic.action == SemanticInput.Action.POINTER_PRESS:
		base_notice_panel.visible = false
		return false
	if semantic.action == SemanticInput.Action.NAV_BACK:
		base_notice_panel.visible = false
		return true
	return false


## 首次方向键才把焦点交给起步控件 —— 由本层接管这一次按键。
##
## 为什么不能 _ready() 就给焦点：MAIN_MENU 与 RESULT 的默认渲染（06 §3 的 Normal 态）
## 已被像素探针逐像素断言（241/241 基线），抢焦点会立刻把按钮画成 Selected 态（06 §3），
## 那条基线当场归零。而键盘玩家第一次按方向键时本来就要看见选中态 —— 那时再给，两边都成立。
##
## 给过之后不再消费事件：焦点已在时，方向键交给 Godot 内建的焦点导航
## （ui_up / ui_down / ui_left / ui_right，读的正是同一个 focus 邻居表）。
## 本层不重复实现一套导航，也就不会跟引擎抢方向键 —— 那是「统一输入层」最容易被做歪的地方。
func _bootstrap_focus() -> bool:
	if base_focus_started or base_focus_entry == null or not is_instance_valid(base_focus_entry):
		return false
	base_focus_started = true
	base_focus_entry.grab_focus()
	return true
