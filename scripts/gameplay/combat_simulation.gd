## combat_simulation.gd
## 职责：一场战斗的固定节拍仿真（FIRST PLAYABLE 3/4）—— 一波敌人按固定间隔生成、沿路径推进，
##       机器的武器开火时结算伤害，敌人血量归零即死亡，全部清空则本波通过、
##       有敌人抵达终点则扣 CORE 血量、扣光即本局失败。
##       它把 MachineRuntime（机器怎么跑）与敌人/伤害（这一批新增的玩法）拼成一个整体。
## 所属系统：gameplay
## 依赖：MachineRuntime / EnemyState / EnemyData / WeaponData / BlueprintData / NodeData
## 禁止：本文件不得触碰场景树 / 渲染 / 输入 / Palette / 存档 —— 它只推进数值，
##       可见反馈由 ui 层读它的只读状态与信号；
##       不得使用真实时间、Timer 或自动运行 —— 推进的唯一入口是 tick()，由 MachineDriver 按固定节拍喂
##       （03 §2：把时间来源放进仿真内部，仿真就无法在测试里被精确驱动）；
##       不得使用 randi() / randf()（03 §6）—— 同一份蓝图 + 同一波敌人必须跑出同一串结果；
##       不得处理 Heat / Overheat —— 两者全在 MachineRuntime 内部（含「过热期间不开火」），
##       本文件一个字节都不改它，只是照常接收（或收不到）weapon_fired；
##       不得自己画任何东西 —— 敌人在屏幕上的位置由 ui 层按 progress 换算。

class_name CombatSimulation
extends RefCounted

## 一局的波次表，下标 = 波次 - 1（`_init()` 的 wave_index 从 1 起）。**一次 COMBAT = 一波**：
## 03 §1.1 R2 只给了 COMBAT → REWARD 一条由「本波清空」触发的边，故「进入下一波」由
## REWARD → PREPARATION → 再进一次 COMBAT 落地，本文件只按 wave_index 挑这一波打谁。
##
## 难度靠**出怪条数**递增（4 / 6 / 8）：敌人种类只有两种，改数值会牵动 PET-65 已取证的伤害结算，
## 而条数是纯加法。三张表的条数必须等于 RunState.TOTAL_WAVES —— 一致性由
## tests/integration/full_loop_smoke.gd 钉住（本文件不得引用 RunState：gameplay 不依赖 core 单例）。
## 第 1 波**必须**保持 PET-65 取证时的那四只（combat_loop_smoke.gd 的击杀拍号与截图都按它取样）。
const WAVES: Array = [
	[EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER, EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER],
	[EnemyData.Kind.SLIME, EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER,
		EnemyData.Kind.RUNNER, EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER],
	[EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER, EnemyData.Kind.SLIME,
		EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER, EnemyData.Kind.RUNNER,
		EnemyData.Kind.SLIME, EnemyData.Kind.RUNNER],
]

## 第一只敌人的出场拍号，以及之后每只的间隔（拍）。20 拍 = 1 秒。
## 首只不排在第 0 拍：开战瞬间就蹦出一只，画面上分不清「刚进来」和「已经打了」。
const FIRST_SPAWN_TICK: int = 10
const SPAWN_INTERVAL_TICKS: int = 20

## CORE 血量。**数值上等于百分比** —— 06 §8.1 的 `CORE` 读数格只有三位（`100%`），
## 故上限取 100，界面直接把它当百分比印，不做第二次换算。
const CORE_MAX_HP: float = 100.0

## 一只敌人抵达终点对 CORE 造成的伤害。4 只全漏 = 100，恰好打空 ——
## 本卡只要「最简单的失败条件」，于是它成立且算得出来：全漏必失败，漏 3 只则还剩 25%。
const LEAK_DAMAGE: float = 25.0

## 死亡后留给占位消失动画的拍数。之后尸体彻底移除。
const VANISH_TICKS: int = 4

## 横向泳道数。两条道让同屏多只敌人不至于叠成一个方块。按出场序轮流分配。
const LANES: int = 2

## 本拍推进完毕（含伤害结算与敌人推进）。UI 用它触发一次重绘，不去轮询。
signal ticked()

## CORE 血量变化。携带的是**绝对值**不是增量 —— 增量语义在重连 / 补跑时会把读数加错
## （同 MachineRuntime.heat_changed 的理由）。
signal core_hp_changed(core_hp: float)

## 本波清空（全部敌人被击杀，且尸体都已退场）。03 §1.1 R2 的 COMBAT → REWARD 只此一条来路。
signal wave_cleared()

## 本局失败（CORE 血量归零）。03 §1.1 R2 的 COMBAT → RESULT。
signal run_failed()

## 机器本体。UI 仍要向它取信号火花 / 弹丸 / Heat 读数，故原样交出去。
var _machine: MachineRuntime = null

## 场上敌人（含尚未消失的尸体），按出场顺序。**数组顺序即同拍内的结算顺序**，
## 与蓝图节点顺序决定机器行为是同一个道理（03 §6）。
var _enemies: Array[EnemyState] = []

## node_id -> WeaponData。开火时按 id 反查，没查到的（FUNCTION / CORE / 未识别）不结算伤害。
var _weapons: Dictionary = {}

var _core_hp: float = CORE_MAX_HP
var _tick_index: int = 0
var _spawned: int = 0
var _cleared: bool = false
var _failed: bool = false

## 本场打第几波（从 1 起）与它对应的敌人序列。越界一律夹进表内 ——
## 夹取而不是报错，是因为「蓝图 / 波次」都可能来自落盘数据，一个越界值不该让整局崩掉。
var _wave_index: int = 1
var _wave: Array = []


## wave_index 缺省为 1：本卡之前的所有调用方（含 PET-65 的取证用例）只传蓝图，
## 语义上就是「打第 1 波」，于是它们的取证数值一条都不用改。
func _init(blueprint: BlueprintData, wave_index: int = 1) -> void:
	_wave_index = clampi(wave_index, 1, WAVES.size())
	_wave = WAVES[_wave_index - 1]
	if blueprint != null:
		_build_weapons(blueprint)
	_machine = MachineRuntime.new(blueprint)
	# 开火与伤害在同一条调用链上：weapon_fired 是即时信号，_machine.tick() 返回时
	# 本拍的开火已经全部结算完。这样「哪把武器先开火」就完全由蓝图节点顺序决定（03 §6）。
	_machine.weapon_fired.connect(_on_weapon_fired)


## 推进一拍。**本仿真的唯一时间入口** —— 调用它的节拍由 MachineDriver 按固定步长给出。
##
## 顺序是有意的：
##   1. 机器先跑 —— 武器打的是敌人**本拍开始时的**位置。反过来（先推进再开火）会让
##      本波最后一只敌人在走到终点的那一拍仍然挨打，而画面上它已经贴到 CORE 上了。
##   2. 再推进敌人 —— 活着的才推进；抵达终点的当拍就扣 CORE 血量。
##   3. 再生成 —— 新生成的敌人本拍不推进（它的 progress 是 0，本来也没得推）。
##   4. 再收尸 —— 消失动画放完的移除掉。
##   5. 最后判定胜负 —— 判据用「场上连尸体都不剩了」，于是死亡动画有机会播完，
##      而不是最后一只一死就立刻切场景。
func tick() -> void:
	if is_over():
		return
	_tick_index += 1
	_machine.tick()
	_advance_enemies()
	_spawn_due()
	_retire_gone()
	_check_outcome()
	ticked.emit()


## 机器本体（只读用途：UI 画火花 / 弹丸 / Heat，测试读节拍号）。
func machine() -> MachineRuntime:
	return _machine


## 场上敌人的**只读副本**（含尚未消失的尸体）。直接交出内部数组，
## 调用方一次误改就能改到仿真状态，而那种错误在画面上只表现为「敌人偶尔凭空消失」。
func enemies() -> Array[EnemyState]:
	var copy: Array[EnemyState] = []
	copy.assign(_enemies)
	return copy


## 当前 CORE 血量绝对值（0..CORE_MAX_HP）。06 §8.1 的 `CORE` 读数取它，数值即百分比。
func core_hp() -> float:
	return _core_hp


## 已推进的拍数。UI 与测试用它算「最近 N 拍内发生过什么」，不必自己数帧。
func tick_index() -> int:
	return _tick_index


## 本场打第几波（从 1 起）。UI 与用例据此核对「进来的确实是这一波」。
func wave_index() -> int:
	return _wave_index


## 本场要出的敌人总数。用例据此做「全漏会不会正好打空 CORE」这类算术。
func wave_size() -> int:
	return _wave.size()


## 本波是否已清空。清空之后 tick() 不再推进（终局态不该继续跑）。
func is_cleared() -> bool:
	return _cleared


## 本局是否已失败。同上。
func is_failed() -> bool:
	return _failed


## 是否已分出结果。两个终局态互斥：先到者胜，之后的 tick() 一律空转。
func is_over() -> bool:
	return _cleared or _failed


## 建武器表。只认得出「是武器」的节点；FUNCTION / CORE 与未识别的武器名都不进表，
## 于是开火回调里一次 get() 就够，不必每发都重新判定节点类型。
func _build_weapons(blueprint: BlueprintData) -> void:
	for node: NodeData in blueprint.nodes:
		var weapon: WeaponData = WeaponData.resolve(node)
		if weapon != null:
			_weapons[node.id] = weapon


## 武器开火 → 结算伤害。按**打击范围**分支，不按武器 id 分支：
## 加一把武器只要给它一个 reach 与 damage，本函数一行都不用改。
func _on_weapon_fired(weapon_id: StringName) -> void:
	var weapon: WeaponData = _weapons.get(weapon_id) as WeaponData
	if weapon == null:
		# 机器里有一把本仿真认不出的武器（或压根不是武器）。开火照旧、Heat 照旧累加，
		# 只是不掉血 —— 这是「蓝图里出现了未识别的武器名」的可见症状，不是崩溃点。
		return
	match weapon.reach:
		WeaponData.Reach.ALL:
			for enemy: EnemyState in _enemies:
				_strike(enemy, weapon.damage)
		WeaponData.Reach.MELEE:
			for enemy: EnemyState in _enemies:
				if enemy.progress >= WeaponData.MELEE_FROM:
					_strike(enemy, weapon.damage)
		_:
			var target: EnemyState = _front_enemy()
			if target != null:
				_strike(target, weapon.damage)


func _strike(enemy: EnemyState, damage: float) -> void:
	if enemy.is_alive():
		enemy.take_damage(damage, _tick_index)


## 最靠前（离 CORE 最近）的活敌人 —— 单体武器打它。
## 平手时取**先出场**的那只（比较用严格大于），于是同拍内的选择是确定的：数组顺序即出场顺序。
func _front_enemy() -> EnemyState:
	var best: EnemyState = null
	for enemy: EnemyState in _enemies:
		if not enemy.is_alive():
			continue
		if best == null or enemy.progress > best.progress:
			best = enemy
	return best


func _advance_enemies() -> void:
	for enemy: EnemyState in _enemies:
		if not enemy.is_alive():
			continue
		enemy.advance()
		if enemy.reached_end():
			_leak(enemy)


## 漏怪：这只敌人走掉了，CORE 掉血。它**不**算被击杀，故本波清空的判定不会把它数进去。
func _leak(enemy: EnemyState) -> void:
	enemy.escaped = true
	_core_hp = maxf(_core_hp - LEAK_DAMAGE, 0.0)
	core_hp_changed.emit(_core_hp)


## 按固定间隔放下一只敌人。每拍最多放一只 —— 间隔远大于 1 拍，故这条断言本来就成立，
## 写出来是为了让「一帧里蹦出两只」在间隔被改小到 1 拍时也不会发生。
func _spawn_due() -> void:
	if _spawned >= _wave.size():
		return
	if _tick_index < FIRST_SPAWN_TICK + _spawned * SPAWN_INTERVAL_TICKS:
		return
	_enemies.append(EnemyState.new(EnemyData.for_kind(_wave[_spawned]), _spawned % LANES))
	_spawned += 1


## 收尸：消失动画放完的、以及漏掉的，从场上移除。
func _retire_gone() -> void:
	var kept: Array[EnemyState] = []
	for enemy: EnemyState in _enemies:
		if not enemy.is_gone(_tick_index, VANISH_TICKS):
			kept.append(enemy)
	_enemies = kept


## 判定终局。失败优先于清空：CORE 归零那一拍若恰好最后一只敌人也死了，
## 玩家该看到的是「本局失败」，而不是「清空 → 进奖励」。
func _check_outcome() -> void:
	if _core_hp <= 0.0:
		_failed = true
		run_failed.emit()
		return
	# `_spawned >= _wave.size()` 挡住「还没出怪就判清空」；
	# `_enemies.is_empty()` 要求连尸体都退场，于是最后一只的死亡动画有机会播完。
	if _spawned >= _wave.size() and _enemies.is_empty():
		_cleared = true
		wave_cleared.emit()
