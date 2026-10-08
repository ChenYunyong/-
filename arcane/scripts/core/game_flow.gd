## game_flow.gd
## 职责：顶层状态机（BOOT / MAIN_MENU / EDITOR / COMBAT / REWARD / MAP / RESULT）、
##       状态切换的唯一入口，以及场景路由的唯一落地点（docs/03 §1）。
## 所属系统：core
## 依赖：EventBus
## 禁止：本文件不得持有任何玩法数值（波次 / 魔力 / 伤害）；
##       不得出现任何计时器 —— R1 要求「停在编辑器」不会自行推进；
##       本文件是全项目**唯一**允许调用 change_scene_to_file() 的地方（03 §1.1 R3）。
##
## PET-85：状态集合按新工程的界面重排 —— 旧工程的 PREPARATION/MAIN_MENU/RESULT
## 换成 EDITOR（模块编辑器，招牌屏）/ MAP（杀戮尖塔式路线图）。旧状态机骨架照搬。
##
## PET-90：把 MAIN_MENU 补回来 —— 旧工程有、新工程漏了，于是启动直接落进编辑器。
## 枚举顺序仍按流程排（BOOT 在最前、MAIN_MENU 紧随其后），序号由 test_game_flow 钉死。
##
## PET-92：把 RESULT 补回来（03 §1 的状态图里一直有它，工程里一直没实现）。
## 于是「一波失败 ⇒ 本局结束」「最后一层胜利 ⇒ 通关结算」终于有地方可去，
## 结算屏也终于有了回到主菜单、开新一局的那一步。

extends Node

## 顶层游戏状态。
enum GameState { BOOT, MAIN_MENU, EDITOR, COMBAT, REWARD, MAP, RESULT }

## 一次状态切换完成时触发。from / to 为 GameState。
signal state_changed(from: GameState, to: GameState)

## 合法状态迁移表。EDITOR / MAP 的目标列表刻意**不含** COMBAT ——
## 硬规则 R1 要求它只能经由 request_start_combat() 进入。
##
## MAIN_MENU 有两条去向（PET-90）：「开始新一局」→ EDITOR，「继续」→ MAP。
## 只有 RESULT **回到** MAIN_MENU（PET-92）：「结算之后开新一局」必须真的回到菜单再开一局，
## 而不是在半路上就地重开 —— 否则「新一局是新种子」这件事无处可证。
## RESULT 也留了一条直达 EDITOR 的边（「再来一局」），两条都从结算屏出发。
##
## COMBAT 原先还有一条 → MAP（打输了从战斗屏直接回路线图）。那条边已被结算取代：
## 输掉不是「回路线图继续」，而是本局结束（PET-92 §3），所以它不再合法。
const ALLOWED_TRANSITIONS: Dictionary = {
	GameState.BOOT: [GameState.MAIN_MENU],
	GameState.MAIN_MENU: [GameState.EDITOR, GameState.MAP],
	GameState.EDITOR: [GameState.MAP],
	GameState.MAP: [GameState.EDITOR, GameState.COMBAT],
	GameState.COMBAT: [GameState.REWARD, GameState.RESULT],
	GameState.REWARD: [GameState.EDITOR, GameState.MAP],
	GameState.RESULT: [GameState.MAIN_MENU, GameState.EDITOR],
}

## 状态 → 正式场景路径。BOOT 不在表内：它是 project.godot 的主场景，由引擎落地，不经路由。
const SCENE_ROUTES: Dictionary = {
	GameState.MAIN_MENU: "res://scenes/main_menu.tscn",
	GameState.EDITOR: "res://scenes/editor.tscn",
	GameState.COMBAT: "res://scenes/combat.tscn",
	GameState.REWARD: "res://scenes/reward.tscn",
	GameState.MAP: "res://scenes/map.tscn",
	GameState.RESULT: "res://scenes/result.tscn",
}

## 承担场景路由的 Autoload 节点名。
const AUTOLOAD_NAME: String = "GameFlow"

var _state: GameState = GameState.BOOT
## R5 重入闸门：切换期间为 true，期间抵达的切换请求一律拒绝。
var _is_transitioning: bool = false


func get_state() -> GameState:
	return _state


func is_state(state: GameState) -> bool:
	return _state == state


## 判定 from → to 是否属于状态图允许的迁移。
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


## 玩家显式动作：点击「开始战斗」。这是进入 COMBAT 的**唯一**入口（硬规则 R1）。
func request_start_combat() -> bool:
	if _state != GameState.EDITOR and _state != GameState.MAP:
		push_warning("GameFlow: 当前为 %s，无法开始战斗。" % state_name(_state))
		return false
	return _commit_transition(GameState.COMBAT)


## 玩家显式动作：本局到此为止（核心被摧毁 / 打穿最后一层）。这是进入 RESULT 的**唯一**入口
## （硬规则 R2 + R3）。与 request_start_combat 对称：语义入口一个，落地仍走同一个提交点。
func request_end_run() -> bool:
	if _state != GameState.COMBAT:
		push_warning("GameFlow: 当前为 %s，无法结算。" % state_name(_state))
		return false
	return _commit_transition(GameState.RESULT)


## 本实例是否就是承担场景路由的那个 Autoload 单例。
## 测试会临时 new 出额外实例来跑状态机，那些副本绝不能把整个游戏的当前场景换掉。
func owns_scene_routing() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	return tree.root.get_node_or_null(AUTOLOAD_NAME) == self


## 某状态对应的正式场景路径。不经路由（BOOT）或未登记时返回空串。
func get_scene_path_for(state: GameState) -> String:
	return String(SCENE_ROUTES.get(state, ""))


## GameState 的可读名，用于日志与断言。
static func state_name(state: GameState) -> StringName:
	var found: Variant = GameState.find_key(state)
	if found == null:
		return &"UNKNOWN"
	return StringName(found)


## 真正落地的一次切换：置重入闸门 → 改状态 → 发信号 → 落闸。
## 闸门在 emit 期间保持为 true，因此监听者在回调里再次请求切换会被拒绝（R5）。
func _commit_transition(to: GameState) -> bool:
	_is_transitioning = true
	var from: GameState = _state
	_state = to
	state_changed.emit(from, to)
	EventBus.state_changed.emit(int(from), int(to))
	_is_transitioning = false
	_route_to_scene(to)
	return true


## 场景路由的唯一落地点。目标场景缺失时明确记一条日志并停在当前场景 —— 不静默失败。
func _route_to_scene(state: GameState) -> void:
	if not owns_scene_routing():
		return
	var path: String = get_scene_path_for(state)
	if path.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_error("GameFlow: 状态 %s 的场景 '%s' 不存在，本次停在当前场景。" % [state_name(state), path])
		return
	_apply_scene_change.call_deferred(path)


## 真正执行换场景。**必须**经 deferred 抵达：本函数会被 `_ready()` 里的同步调用链触发
## （BOOT 的 `_ready` → change_state → _commit_transition → 本文件），而那一刻 root 正在
## `add_child()` 内部，`change_scene_to_file()` 里的 `remove_child()` 会被引擎挡下并抛
## 「Parent node is busy adding/removing children」。延后一帧后 root 已空闲。
func _apply_scene_change(path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("GameFlow: 切换到 '%s' 失败（错误码 %d）。" % [path, error])
