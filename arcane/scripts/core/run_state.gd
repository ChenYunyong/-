## run_state.gd
## 职责：当前这一局的进度与随机源（docs/03 §3、§6），这一局的书页（卡牌 + 丝线），
##       以及这一局的账本（拿过哪些奖励、因此多出多少伤害与魔力）与结局。
## 所属系统：core
## 依赖：BoardModel、RewardModel（都是纯数据结构，不含表现）
## 禁止：本文件不得含表现逻辑，也不得结算任何战斗 —— 它只记「打到第几波」「书页长什么样」
##       「这一局拿了什么、怎么结束的」。

extends Node

## 新的一局开始时触发。run_seed 为本局随机种子，必须记录以便复现（03 §6）。
signal run_started(run_seed: int)

## 本局推进到新的一波时触发。携带的是**推进后**的波次（从 1 起）。
signal wave_changed(wave: int)

## 本局结束时触发。
signal run_ended()

## 这一局是怎么结束的（PET-92）。结算屏要靠它区分「通关」与「本局结束」。
enum Result { NONE, VICTORY, DEFEAT }

const SEED_AUTO: int = -1
const SEED_UNSET: int = 0
## 一局几波。**一场战斗**几波 —— 每场战斗都从这里的第一波打起，见 begin_battle()。
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
## 本局的结算结果。
var _result: Result = Result.NONE
## 本局拿过的奖励（原样存下选项字典，结算屏照着念）。
var _taken: Array[Dictionary] = []
## 上面那些选项的键。与 RewardModel.roll() 共用一张表，于是「抽的时候排除拿过的」与
## 「拿的时候拒绝重复的」不会说岔。
var _taken_keys: Array[String] = []
## 本局的常驻加成。战斗只读它们（战斗系统不得回写蓝图，03 §4.3）。
var _damage_bonus: int = 0
var _mana_bonus: int = 0


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
## **波次回到第 1 波**、「本局所得」清空、加成归零 —— 「重新开始」必须真的重开。
## 书页**不清空**：它是玩家在编辑器里搭出来的成果，重开一局不该罚玩家重搭。
func start_run(seed_value: int = SEED_AUTO) -> void:
	_run_seed = _resolve_seed(seed_value)
	_rng.seed = _run_seed
	_is_active = true
	_wave = FIRST_WAVE
	_result = Result.NONE
	_taken.clear()
	_taken_keys.clear()
	_damage_bonus = 0
	_mana_bonus = 0
	# 新的一局 = 新的一张图。旧的留着只会让下一局走进上一局的路线。
	_map = null
	run_started.emit(_run_seed)
	EventBus.run_progress_changed.emit()


## 进入一场战斗。波次回到第 1 波 —— **每场战斗都从第 1 波打起**。
##
## 没有这一步的话，「一局」与「一波」会被搅在一起：第一场打完 _wave 停在 TOTAL_WAVES，
## 之后每一场都只打一波就收场（路线图上后面几层全是残局）。一局的长度归路线图管，
## 一场战斗的长度归这里管。
func begin_battle() -> void:
	_wave = FIRST_WAVE
	wave_changed.emit(_wave)
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


# ------------------------------------------------------------------ 本局账本（PET-92）

## 本波的奖励选项。**同一局的同一波永远是同一组**：多看一眼、退出去再进来，牌不会换。
func roll_rewards() -> Array[Dictionary]:
	return RewardModel.roll(_run_seed, _wave, RewardModel.pool_ids(), _taken_keys)


## 拿走一个奖励。**这是奖励唯一的落地入口** —— 记账、改本局数值、改书页都在这里，
## 界面只负责把选中的那个选项递进来（03 §7：UI 不得直接改内部状态，走命令）。
##
## 已经拿过的不再受理（返回 false）。三个选项落在三条互不重叠的杠杆上，见 reward_model.gd。
func take_reward(option: Dictionary, view_size: Vector2) -> bool:
	var key: String = RewardModel.key_of(option)
	if key.is_empty() or _taken_keys.has(key):
		return false
	match int(option.get("kind", -1)):
		RewardModel.Kind.CARD:
			if RewardModel.place_card(board(), option["card_id"], view_size) == null:
				return false
		RewardModel.Kind.POWER:
			_damage_bonus += RewardModel.POWER_DAMAGE
		RewardModel.Kind.MANA:
			_mana_bonus += RewardModel.MANA_PER_TICK
		_:
			return false
	_taken_keys.append(key)
	_taken.append(option.duplicate())
	return true


## 本局拿过的奖励，按拿到的先后。结算屏念的就是它。返回副本，外部改不动账本。
func taken_rewards() -> Array[Dictionary]:
	return _taken.duplicate()


## 本局的常驻伤害加成。战斗读一次、用一局。
func damage_bonus() -> int:
	return _damage_bonus


## 本局的常驻魔力加成。
func mana_bonus() -> int:
	return _mana_bonus


## 这一局走到过第几层（从 1 起；还没出发是 0）。结算是按「到过几层」念的。
func tiers_seen() -> int:
	return map().deepest_tier() + 1


# ------------------------------------------------------------------ 结局（PET-92）

## 结束本局并记下是怎么结束的（通关 / 落败）。结算屏据此决定说的是哪一句。
func finish_run(result: Result) -> void:
	_result = result
	end_run()


func result() -> Result:
	return _result


func _resolve_seed(seed_value: int) -> int:
	if seed_value != SEED_AUTO:
		return seed_value
	var generator: RandomNumberGenerator = RandomNumberGenerator.new()
	generator.randomize()
	return int(generator.randi())
