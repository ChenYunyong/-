## game_flow.gd
## 职责：顶层六状态机、状态切换的唯一入口，以及场景路由的唯一落地点（03_ARCHITECTURE.md §1）。
## 所属系统：core
## 依赖：EventBus
## 禁止：本文件不得持有任何玩法数值（波次 / Heat / HP / 奖励），
##       不得出现任何计时器 —— R1 要求「停留在 PREPARATION」不会自行推进；
##       本文件是**唯一**允许调用 change_scene_to_file() 的地方（03 §1.1 R3），
##       任何其它模块都不得自行切场景。

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

## 状态 → 该状态正式场景的路径与责任任务号（11_TASK_BOARD.md §3）。
## BOOT 刻意不在表内：它是 project.godot 的主场景，由引擎在启动时落地，不经路由。
## PG-CODE §2：内层字典是常量字面量，无法标注元素类型，故此处为无类型 Dictionary。
const SCENE_ROUTES: Dictionary = {
	GameState.MAIN_MENU: {"path": "res://scenes/menu/main_menu.tscn", "task": "S1-06"},
	GameState.PREPARATION: {"path": "res://scenes/preparation/preparation.tscn", "task": "S1-07"},
	GameState.COMBAT: {"path": "res://scenes/combat/combat.tscn", "task": "S1-08"},
	GameState.REWARD: {"path": "res://scenes/reward/reward.tscn", "task": "S1-09"},
	GameState.RESULT: {"path": "res://scenes/result/result.tscn", "task": "S1-10"},
}

## 承担场景路由的 Autoload 节点名（03 §3：GameFlow 是唯一的顶层状态机与场景路由器）。
const AUTOLOAD_NAME: String = "GameFlow"

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


## 本实例是否就是承担场景路由的那个 Autoload 单例（03 §3）。
## 路由是全局单例的职责：测试与工具会临时 new 出额外实例来跑状态机，
## 那些副本绝不能把整个游戏的当前场景换掉。
func owns_scene_routing() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return tree.root.get_node_or_null(AUTOLOAD_NAME) == self


## 某状态对应的正式场景路径。不经路由（BOOT）或未登记时返回空串。
func get_scene_path_for(state: GameState) -> String:
	if not SCENE_ROUTES.has(state):
		return ""
	var route: Dictionary = SCENE_ROUTES[state]
	return String(route["path"])


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
	# 路由放在闸门落下之后：新场景在自己的 _ready 里切换状态不算重入。
	_route_to_scene(to)
	return true


## 场景路由的**唯一**落地点（03 §1.1 R3）—— 全项目只有这里会调用 change_scene_to_file()。
##
## 目标场景尚未实现时（S1-06~S1-10 才有正式场景），明确记一条日志并停在当前场景：
## 既不静默失败，也不去调用 change_scene_to_file —— 那只会让引擎再抛一次加载错误，
## 而「场景还没做」在本阶段是已知状态，不是缺陷。
func _route_to_scene(state: GameState) -> void:
	if not owns_scene_routing():
		return
	if not SCENE_ROUTES.has(state):
		return
	var route: Dictionary = SCENE_ROUTES[state]
	var path: String = String(route["path"])
	if not ResourceLoader.exists(path):
		print("GameFlow: 状态 %s 的场景 '%s' 尚未实现（属 %s），本次停在当前场景。" % [
			state_name(state), path, String(route["task"]),
		])
		return
	_apply_scene_change.call_deferred(path)


## 真正执行换场景。**必须**经 deferred 抵达：本函数会被 `_ready()` 里的同步调用链
## 触发（BOOT 的 `_ready` → `change_state` → `_commit_transition` → 本文件 `_route_to_scene`），
## 而那一刻 root 正在 `add_child()` 内部（`blocked > 0`），`change_scene_to_file()`
## 内部的 `remove_child()` 会被引擎 ERR_FAIL 挡下并抛
## 「Parent node is busy adding/removing children」（node.cpp:1750）。
## 延后一帧后 root 已空闲，摘除 / 释放 / 挂载全部正常。
##
## 为什么不让 `_route_to_scene()` 直接 `change_scene_to_file.call_deferred()`：
## 那样会连同**返回值检查**一起丢掉，切换失败就变成静默 —— 与本文件「不静默失败」的
## 口径冲突。落成一个独立函数，deferred 之后仍能拿到 Error 并 push_error。
func _apply_scene_change(path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("GameFlow: 切换到 '%s' 失败（错误码 %d）。" % [path, error])
