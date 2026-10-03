## input_normalizer.gd
## 职责：把 Godot 的原始输入事件翻译成**唯一一条语义事件**（SemanticInput）—— 03 §8、本卡交付物 1。
## 所属系统：input
## 依赖：SemanticInput
## 禁止：本文件是**全工程唯一**允许出现 InputEventMouseButton / InputEventScreenTouch /
##       InputEventKey 的地方。场景与其它输入层文件一律不得再引用这些原始事件类 ——
##       「不得各自判断触摸 / 鼠标来决定行为」这条要求，就是靠这个唯一出口来兑现的。

class_name InputNormalizer
extends RefCounted

## 键位表。**故意直接写键码而不是走 InputMap**：
## 本层的产物是语义动作，不是可重绑定的键位方案；Stage 1 的 Settings 只管音量
## （03 §3 把输入重绑定排在后面）。若这里也去查 InputMap，键位就有了两个真相源，
## 而 project.godot 的 [input] 段落是 DSH 的地盘。故：键码在本文件一处集中，改键只改这里。
const KEY_TO_ACTION: Dictionary = {
	KEY_UP: SemanticInput.Action.NAV_UP,
	KEY_DOWN: SemanticInput.Action.NAV_DOWN,
	KEY_LEFT: SemanticInput.Action.NAV_LEFT,
	KEY_RIGHT: SemanticInput.Action.NAV_RIGHT,
	KEY_ENTER: SemanticInput.Action.NAV_CONFIRM,
	KEY_KP_ENTER: SemanticInput.Action.NAV_CONFIRM,
	KEY_SPACE: SemanticInput.Action.NAV_CONFIRM,
	KEY_ESCAPE: SemanticInput.Action.NAV_BACK,
}


## 原始事件 → 语义事件。不属于本层的事件（鼠标移动、滚轮、右键、按住重复……）返回 null。
##
## 触摸与鼠标在这里合流：两者都产出 POINTER_PRESS / POINTER_RELEASE，
## 只在 Source 上留一个「这一下是手指还是鼠标」的标注 —— 场景看不到、也不该看到这个差别。
static func from_event(event: InputEvent) -> SemanticInput:
	var pointer: SemanticInput = _pointer_from(event)
	if pointer != null:
		return pointer
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return _from_key(key)
	return null


## 本层认作「主指针」的鼠标键。
##
## 为什么连 MOUSE_BUTTON_NONE(0) 一起收：这是**为合成事件留的兼容口**，不是把右键当左键。
## tests/integration/main_menu_smoke.gd 的 _dismiss() 直接构造事件并只设 pressed，
## button_index 停在默认值 0；S1-06 起「点任意处关提示」那条路径只看 pressed、不看按键，
## 收窄成「只认左键」会当场打红 MAIN_MENU 67/67 基线，而那个文件不在本卡的允许文件里。
## 真实的按键事件一定带 button_index（引擎不会产生 0），故这一条在实际运行中不会放行任何东西；
## 中键 / 右键仍然返回 null，不会被当成主指针。
## PG-CODE §2：内层是枚举字面量，无法标注元素类型，故此处与 game_flow.gd 的
## ALLOWED_TRANSITIONS 一样用无类型 Array。
const PRIMARY_MOUSE_BUTTONS: Array = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_NONE]


## 指针类：触摸与鼠标主键。
static func _pointer_from(event: InputEvent) -> SemanticInput:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		return SemanticInput.pointer(_press_action(touch.pressed), touch.position, SemanticInput.Source.TOUCH)
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and PRIMARY_MOUSE_BUTTONS.has(mouse.button_index):
		return SemanticInput.pointer(_press_action(mouse.pressed), mouse.position, SemanticInput.Source.MOUSE)
	return null


## 键盘类。**只认按下，不认抬起，也不认 echo**：
## echo 是「按住不放」的自动重复，拿它当一次新按键会让方向键在长按中乱窜；
## 抬起（pressed=false）对本层没有语义 —— 场景要的是「按了哪个键」，不是「松了哪个键」。
static func _from_key(key: InputEventKey) -> SemanticInput:
	if not key.pressed or key.echo:
		return null
	var action: Variant = KEY_TO_ACTION.get(key.keycode, null)
	if action == null:
		return null
	return SemanticInput.navigation(action as SemanticInput.Action)


## 按下 → PRESS，抬起 → RELEASE。触摸与鼠标共用这一处换算，两条路径不可能再走偏。
static func _press_action(pressed: bool) -> SemanticInput.Action:
	return SemanticInput.Action.POINTER_PRESS if pressed else SemanticInput.Action.POINTER_RELEASE
