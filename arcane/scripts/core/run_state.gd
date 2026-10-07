## run_state.gd
## 职责：当前这一局的进度与随机源（docs/03 §3、§6），以及这一局的书页（卡牌 + 丝线）。
## 所属系统：core
## 依赖：BoardModel（纯数据结构，不含表现）
## 禁止：本文件不得含表现逻辑，也不得结算任何战斗 —— 它只记「打到第几波」与「书页长什么样」。

extends Node

## 新的一局开始时触发。run_seed 为本局随机种子，必须记录以便复现（03 §6）。
signal run_started(run_seed: int)

## 本局推进到新的一波时触发。携带的是**推进后**的波次（从 1 起）。
signal wave_changed(wave: int)

## 本局结束时触发。
signal run_ended()

const SEED_AUTO: int = -1
const SEED_UNSET: int = 0
## 一局几波。「一局有多长」的唯一来源。
const TOTAL_WAVES: int = 3
const FIRST_WAVE: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _run_seed: int = SEED_UNSET
var _is_active: bool = false
var _wave: int = FIRST_WAVE
## 这一局的书页。整局带着走 —— 战斗只读它，编辑器改它（03 §4.3）。
var _board = null
## 这一局的路线图。按本局种子生成一次，之后整局复用（重进地图看到的是同一张图）。
var _map = null


func _ready() -> void:
	_board = load("res://scripts/editor/board_model.gd").new()


## 本局随机源。03 §6：全项目随机必须且只能来自这里。
func rng() -> RandomNumberGenerator:
	return _rng


func get_run_seed() -> int:
	return _run_seed


func is_active() -> bool:
	return _is_active


func current_wave() -> int:
	return _wave


func total_waves() -> int:
	return TOTAL_WAVES


## 这一局的书页。BOOT 期间 Autoload 的 _ready 可能还没跑到，故做一次懒初始化。
func board():
	if _board == null:
		_board = load("res://scripts/editor/board_model.gd").new()
	return _board


## 这一局的路线图。第一次访问时按本局种子生成 —— 同一局里反复进出地图看到的是同一张图，
## 而不是每次重掷（那会让「记住了下一步去哪」这件事失去意义）。
func map():
	if _map == null:
		_map = load("res://scripts/roguelike/map_model.gd").new()
		_map.generate(_run_seed)
	return _map


## 开始新的一局。seed_value 传 SEED_AUTO 时自行生成并记录。
## **波次在这里回到第 1 波** —— 「重新开始」必须真的重开。
## 书页**不清空**：它是玩家在编辑器里搭出来的成果，重开一局不该罚玩家重搭。
func start_run(seed_value: int = SEED_AUTO) -> void:
	_run_seed = _resolve_seed(seed_value)
	_rng.seed = _run_seed
	_is_active = true
	_wave = FIRST_WAVE
	# 新的一局 = 新的一张图。旧的留着只会让下一局走进上一局的路线。
	_map = null
	run_started.emit(_run_seed)
	EventBus.run_progress_changed.emit()


## 本波清空 → 推进到下一波。已是最后一波时返回 false（调用方据此去 REWARD / 结算）。
func advance_wave() -> bool:
	if _wave >= TOTAL_WAVES:
		return false
	_wave += 1
	wave_changed.emit(_wave)
	EventBus.run_progress_changed.emit()
	return true


## 结束本局。
func end_run() -> void:
	if not _is_active:
		return
	_is_active = false
	run_ended.emit()
	EventBus.run_progress_changed.emit()


func _resolve_seed(seed_value: int) -> int:
	if seed_value != SEED_AUTO:
		return seed_value
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	return int(generator.randi())
