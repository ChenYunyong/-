## game_flow.gd
## 职责：顶层六状态机，以及状态切换的唯一入口（03_ARCHITECTURE.md §1）。
## 所属系统：core
## 依赖：EventBus
## 禁止：本文件不得持有任何玩法数值（波次 / Heat / HP / 奖励），
##       不得出现任何计时器 —— R1 要求「停留在 PREPARATION」不会自行推进。

extends Node

## 顶层游戏状态。顺序与 03_ARCHITECTURE.md §1 的状态图一致。
enum GameState { BOOT, MAIN_MENU, PREPARATION, COMBAT, REWARD, RESULT }

## 一次状态切换完成时触发。from / to 为 GameState。
signal state_changed(from: GameState, to: GameState)

## 合法状态迁移表，取自 03_ARCHITECTURE.md §1 的状态图。
## PREPARATION 的目标列表刻意**不含** COMBAT —— 硬规则 R1 要求它只能经由
## request_start_combat() 进入，走不通 change_state() 这条通用路径。
const ALLOWED_TRANSITIONS: Dictionary = {
	GameState.BOOT: [GameState.MAIN_MENU],
	GameState.MAIN_MENU: [GameState.PREPARATION],
	GameState.PREPARATION: [GameState.RESULT],
	GameState.COMBAT: [GameState.REWARD, GameState.RESULT],
	GameState.REWARD: [GameState.PREPARATION],
	GameState.RESULT: [GameState.MAIN_MENU, GameState.PREPARATION],
}

## 当前顶层状态。初值即 BOOT —— 它是启动态而非一次「切换」，故不发信号。
var _state: GameState = GameState.BOOT
## R5 重入闸门：切换期间为 true，期间抵达的切换请求一律拒绝。
var _is_transitioning: bool = false


## 当前顶层状态。
func get_state() -> GameState:
	return _state


## 当前是否处于指定状态。
func is_state(state: GameState) -> bool:
	return _state == state


## 判定 from → to 是否属于 03 §1 状态图允许的迁移。
## PG-CODE §2：表中的内层数组是常量字面量，无法标注元素类型，故此处为无类型 Array。
func is_transition_allowed(from: GameState, to: GameState) -> bool:
	if not ALLOWED_TRANSITIONS.has(from):
		return false
	var targets: Array = ALLOWED_TRANSITIONS[from]
	return targets.has(to)


## 切换顶层状态的唯一入口（03 §1.1 R3）。
## 返回 true 表示本次切换已生效；false 表示被拒绝：非法迁移 / 重入 / 重复切到当前态。
func change_state(to: GameState) -> bool:
	if _is_transitioning:
		push_warning("GameFlow: 切换进行中，忽略对 %s 的重复请求（R5）。" % state_name(to))
		return false
	if to == _state:
		push_warning("GameFlow: 已处于 %s，忽略重复切换。" % state_name(to))
		return false
	if not is_transition_allowed(_state, to):
		push_error("GameFlow: 非法状态迁移 %s → %s。" % [state_name(_state), state_name(to)])
		return false
	return _commit_transition(to)


## 玩家显式动作：点击「开始战斗」。
## 这是 PREPARATION → COMBAT 的**唯一**入口，硬规则 R1 与 06 §10.2 均要求如此。
func request_start_combat() -> bool:
	if _state != GameState.PREPARATION:
		push_warning("GameFlow: 当前为 %s，无法开始战斗。" % state_name(_state))
		return false
	return _commit_transition(GameState.COMBAT)


## 玩家显式动作：结束本局（CORE 被摧毁 / 达到终局条件）。
## 这是 PREPARATION / COMBAT → RESULT 的语义化入口，玩法触发条件属 Stage 2-4。
func request_end_run() -> bool:
	if _state != GameState.PREPARATION and _state != GameState.COMBAT:
		push_warning("GameFlow: 当前为 %s，无法结束本局。" % state_name(_state))
		return false
	return _commit_transition(GameState.RESULT)


## GameState 的可读名，用于日志与断言。
static func state_name(state: GameState) -> StringName:
	var found: Variant = GameState.find_key(state)
	if found == null:
		return &"UNKNOWN"
	return StringName(found)


## 真正落库的一次切换：置重入闸门 → 改状态 → 发信号 → 落闸。
## 闸门在 emit 期间保持为 true，因此监听者在回调里再次请求切换会被拒绝（R5）。
func _commit_transition(to: GameState) -> bool:
	_is_transitioning = true
	var from: GameState = _state
	_state = to
	state_changed.emit(from, to)
	EventBus.state_changed.emit(int(from), int(to))
	_is_transitioning = false
	return true
