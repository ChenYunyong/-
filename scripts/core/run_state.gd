## run_state.gd
## 职责：当前这一局的进度与随机源（03_ARCHITECTURE.md §3、§6）。
##       进度 = 波次：一局固定打 TOTAL_WAVES 波，每清空一波推进一次（FIRST PLAYABLE 4/4）。
## 所属系统：core
## 依赖：无
## 禁止：本文件不得含表现逻辑，也不得结算任何战斗 —— 它只记「打到第几波」这一个进度；
##       敌人配置属 gameplay，故本文件不引用 CombatSimulation（core 不得反向依赖上层）。

extends Node

## 新的一局开始时触发。run_seed 为本局随机种子，必须记录以便复现（03 §6）。
signal run_started(run_seed: int)

## 本局终止时触发。
signal run_ended()

## 本局推进到新的一波时触发。携带的是**推进后**的波次（从 1 起）。
signal wave_changed(wave: int)

## 未显式给种子时，用这个值表示「由 RunState 自行生成」。
const SEED_AUTO: int = -1

## RNG 状态初值。Godot 要求显式 seed 才能保证可复现。
const SEED_UNSET: int = 0

## 一局几波。**这是「一局有多长」的唯一来源**：COMBAT 的 `波次` 读数按它拼 `n/N`，
## 末波清空即本局结束（→ RESULT）。敌人配置表在 gameplay/combat_simulation.gd 的 WAVES，
## 两张表的条数必须一致 —— 一致性由 tests/integration/full_loop_smoke.gd 钉住。
const TOTAL_WAVES: int = 3

## 首波序号。波次从 1 起（读数写成人读的 `1/3`，不是下标）。
const FIRST_WAVE: int = 1

## 本局随机源。03 §6：全项目随机必须且只能来自这里。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _run_seed: int = SEED_UNSET
var _is_active: bool = false

## 当前波次（从 FIRST_WAVE 起）。
var _wave: int = FIRST_WAVE


## 开始新的一局。seed_value 传 SEED_AUTO 时随机生成一个种子并记录下来。
##
## **波次在这里回到第 1 波** —— 「再来一局」与「返回主菜单后再开」都要真的重开，
## 否则新的一局会从上一局的波次接着打，一进 COMBAT 就立刻结算。
func start_run(seed_value: int = SEED_AUTO) -> void:
	_run_seed = _resolve_seed(seed_value)
	_rng.seed = _run_seed
	_is_active = true
	_wave = FIRST_WAVE
	run_started.emit(_run_seed)


## 结束本局。回到 MAIN_MENU / 再开一局前必须调用，避免上一局的种子被沿用。
##
## **刻意不清波次**：RESULT 要显示「坚持到第 N 波」，而本局是在 COMBAT 里结束、
## RESULT 场景在其后才 _ready() —— 这里若把波次抹回 1，那个读数就永远是 1。
## 波次的复位归 start_run()。
func end_run() -> void:
	if not _is_active:
		push_warning("RunState: 当前没有进行中的一局，end_run() 已忽略。")
		return
	_is_active = false
	run_ended.emit()


## 当前波次（1..TOTAL_WAVES）。本局结束后仍返回结束时的波次，供 RESULT 展示。
func current_wave() -> int:
	return _wave


## 当前波次是否是最后一波。清空它即本局打完（COMBAT → RESULT，而不是 → REWARD）。
func is_final_wave() -> bool:
	return _wave >= TOTAL_WAVES


## 推进到下一波。已经打完最后一波时**不动**（越界会让读数拼出 `4/3`，
## 而那时本就该结束了）—— 返回是否真的推进了。
func advance_wave() -> bool:
	if is_final_wave():
		return false
	_wave += 1
	wave_changed.emit(_wave)
	return true


## 本局随机种子。RESULT 界面可展示以便复现（03 §6）。
func get_run_seed() -> int:
	return _run_seed


## 本局随机源。调用方不得替换其 seed。
func get_rng() -> RandomNumberGenerator:
	return _rng


## 当前是否有进行中的一局。
func is_active() -> bool:
	return _is_active


func _resolve_seed(seed_value: int) -> int:
	if seed_value != SEED_AUTO:
		return seed_value
	# 仅在「生成种子」这一处允许使用非 RunState 的随机源，否则无从产生初值。
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	return int(generator.randi())
