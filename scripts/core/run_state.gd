## run_state.gd
## 职责：当前这一局的进度与随机源（03_ARCHITECTURE.md §3、§6）。
## 所属系统：core
## 依赖：无
## 禁止：本文件不得含表现逻辑；玩法进度字段（波次 / 奖励）随其所属系统在后续阶段加入。

extends Node

## 新的一局开始时触发。run_seed 为本局随机种子，必须记录以便复现（03 §6）。
signal run_started(run_seed: int)

## 本局终止时触发。
signal run_ended()

## 未显式给种子时，用这个值表示「由 RunState 自行生成」。
const SEED_AUTO: int = -1

## RNG 状态初值。Godot 要求显式 seed 才能保证可复现。
const SEED_UNSET: int = 0

## 本局随机源。03 §6：全项目随机必须且只能来自这里。
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _run_seed: int = SEED_UNSET
var _is_active: bool = false


## 开始新的一局。seed_value 传 SEED_AUTO 时随机生成一个种子并记录下来。
func start_run(seed_value: int = SEED_AUTO) -> void:
	_run_seed = _resolve_seed(seed_value)
	_rng.seed = _run_seed
	_is_active = true
	run_started.emit(_run_seed)


## 结束本局。回到 MAIN_MENU / 再开一局前必须调用，避免上一局的种子被沿用。
func end_run() -> void:
	if not _is_active:
		push_warning("RunState: 当前没有进行中的一局，end_run() 已忽略。")
		return
	_is_active = false
	run_ended.emit()


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
