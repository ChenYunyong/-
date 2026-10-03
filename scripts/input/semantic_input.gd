## semantic_input.gd
## 职责：双端输入的**语义词汇表** —— 场景消费的那一条统一事件（03 §8）。
## 所属系统：input
## 依赖：无
## 禁止：本文件不得引用任何 Godot 输入事件类（InputEventMouseButton / InputEventScreenTouch /
##       InputEventKey）—— 那些原始类型只允许出现在 input_normalizer.gd 一处。
##       本文件只是「一条已经归一好的语义事件」的数据载体。
##
## 为什么要有 Source：它是**来源标注**，不是分支依据。
## 场景一律只看 Action；Source 供测试与遥测证明「同一次触摸与同一次鼠标点出了同一条语义事件」。
## 若哪天有场景按 Source 分叉，就等于把「触摸 / 鼠标」两套行为又搬回了场景层 —— 那正是本卡要消灭的。

class_name SemanticInput
extends RefCounted

## 场景能看到的全部动作。指针类对应「指向某个位置」，导航类对应「键盘往哪走」。
enum Action {
	POINTER_PRESS,
	POINTER_RELEASE,
	NAV_UP,
	NAV_DOWN,
	NAV_LEFT,
	NAV_RIGHT,
	NAV_CONFIRM,
	NAV_BACK,
}

## 这条事件的物理来源。仅供测试 / 遥测，**不参与行为判定**。
enum Source { MOUSE, TOUCH, KEY }

## 指针类动作携带的位置（视口逻辑坐标）；导航类恒为 ZERO。
var position: Vector2 = Vector2.ZERO
var action: Action = Action.POINTER_PRESS
var source: Source = Source.MOUSE

var _init_action: Action = Action.POINTER_PRESS
var _init_source: Source = Source.MOUSE


## 指针类事件（按下 / 抬起）。position 为视口逻辑坐标。
static func pointer(pointer_action: Action, at: Vector2, from: Source) -> SemanticInput:
	var event: SemanticInput = SemanticInput.new()
	event.action = pointer_action
	event.position = at
	event.source = from
	event._init_action = pointer_action
	event._init_source = from
	return event


## 导航类事件（方向键 / 确认 / 返回），不带位置。
static func navigation(nav_action: Action, from: Source = Source.KEY) -> SemanticInput:
	var event: SemanticInput = SemanticInput.new()
	event.action = nav_action
	event.position = Vector2.ZERO
	event.source = from
	event._init_action = nav_action
	event._init_source = from
	return event


## 是不是指针类动作（带位置的那种）。
func is_pointer() -> bool:
	return action == Action.POINTER_PRESS or action == Action.POINTER_RELEASE


## 是不是「往某个方向走」的导航动作。
static func is_directional(nav_action: Action) -> bool:
	return nav_action == Action.NAV_UP or nav_action == Action.NAV_DOWN \
		or nav_action == Action.NAV_LEFT or nav_action == Action.NAV_RIGHT


## 两条事件是不是**同一个语义动作**。
##
## 刻意**不比 Source**：这正是「触摸与鼠标归一到同一条语义事件」的机器可判定形式。
## 若把 Source 也算进来，触摸与鼠标就永远不相等，本层的整个意义就不成立了。
func same_action_as(other: SemanticInput) -> bool:
	if other == null:
		return false
	return action == other.action and position.is_equal_approx(other.position)


## 可读描述，供失败信息使用（09 §4：失败要说清实际值）。
func describe() -> String:
	var names: PackedStringArray = ["POINTER_PRESS", "POINTER_RELEASE", "NAV_UP", "NAV_DOWN",
		"NAV_LEFT", "NAV_RIGHT", "NAV_CONFIRM", "NAV_BACK"]
	var sources: PackedStringArray = ["MOUSE", "TOUCH", "KEY"]
	return "%s@%s(%s)" % [names[action], str(position), sources[source]]
