## capture_combat.gd
## 职责：战斗屏的**像素证据**采集 —— 真机走到 COMBAT，填一张固定书页，推着计时器走 100 拍，
##       截图并打印实测数字；外加一次固定局面的重放（同一书页 + 同一波次跑两遍，逐行比对）。
## 所属系统：tools
## 依赖：tests/tree_probe.gd（只借它做子树查找）、CombatLayout（落点契约）、CombatSim / CardCatalog、
##       boot.tscn 与战斗场景
## 禁止：本文件不得改动任何产品代码；不得被游戏运行时引用（tools/* 已排除导出）。
##
## 为什么推那个 Timer 的 timeout 信号、而不是等真实时间：等真实时间的话，截图里是第几拍取决于
## 这台机器这一秒画了多少帧 —— 图还是那张图，图上的数字却每次都不同，那就不算证据了。
## 推 N 次就是 N 拍；推的是**场景里那个 Timer 自己的信号**，于是顺带证明了「计时器 → 推进」
## 这根线是接上的，而不是本文件绕过屏直接去调仿真。
##
## 「固定种子」在本作里到底指什么：CombatSim 一次随机数都不吃，一局的种子只决定路线图与掉落。
## 所以同种子可重放在这里是**构造性**的 —— 结果只由书页与波次决定。
## 下面 _replay() 逐行比对的就是这一条：同书页 + 同波次 ⇒ 同流水。
##
## 运行方式（**不要**加 --headless，截图需要真实渲染窗口）：
##   godot --path . --script res://tools/capture_combat.gd

extends SceneTree

const TreeProbe = preload("res://tests/tree_probe.gd")
const OUTPUT_DIR: String = "res://tests/output"
## 强制中文再截：这一屏的字全走 i18n，系统语言不是中文时截出来是英文，
## 而这张图要说明的正是「新文案进了表」。
const LOCALE: String = "zh_CN"
## 本局种子。写死一个数：战斗本身不吃它，但「固定种子」四个字要落到实处。
const SEED: int = 20261008
## 主菜单上那颗按钮的文案 key。PET-90 起 boot 落在主菜单，编辑器要玩家按一下才去。
const KEY_NEW_RUN: String = "开始新一局"
## 截图前推进多少拍（TICK_HZ = 20，故 100 拍 = 5 秒）。取 100 是因为这个点上：
## 功能卡已经打出来过、加成攒了不止一档、能力卡也真的打进去过，
## 而这一波还没打完 —— 侧栏每一项都是「打起来之后」的读数，而不是开局的一片零。
const TICKS: int = 100
## 截图与重放看的是第几波。第 2 波：敌群比第 1 波厚，血条上留得下「打掉了一截」。
const WAVE: int = 2
## 重放跑到头。本波限时 600 拍，取一样长 —— 清空了会自己停，不必掐。
const REPLAY_TICKS: int = CombatSim.WAVE_TIME_LIMIT_TICKS

## 书页上的卡。三张核心卡是电源：一张核心每秒出 2 点魔力，而下面五张法术一轮要 9 点；
## 只给两张的话有近一半的施法付不起，那一半空过拍在图上读起来就是「卡住了」。
const CARD_IDS: Array[StringName] = [
	&"core_arcane", &"core_arcane", &"core_arcane",
	&"fn_haste", &"fn_projectile", &"fn_enchant", &"ab_fire", &"ab_wind",
]
## 分行摆成 4 列 × 2 行。列距 160、行距 150 都大于卡面 72，
## 于是整张书页正好落在 CombatView 的取景框里（跨 552 × 222，缩放 1.0）。
const CARD_POS: Array[Vector2] = [
	Vector2(40.0, 40.0), Vector2(40.0, 190.0), Vector2(520.0, 190.0),
	Vector2(200.0, 40.0), Vector2(360.0, 40.0), Vector2(200.0, 190.0),
	Vector2(520.0, 40.0), Vector2(360.0, 190.0),
]
## 连线（CARD_IDS 的下标 → 下标）：核心 → 加速 → 子弹 → 附魔 → 火球，附魔再分一条到风刃。
## 方向就是施放顺序（仿真从核心广度优先走），所以「先上功能卡、再打能力卡」是这张书页
## 自己画出来的顺序，不是仿真偏袒它。
const LINKS: Array = [[0, 3], [3, 4], [4, 5], [5, 6], [5, 7]]

var _run: Node = null
var _flow: Node = null
var _lines: Array[String] = []


func _initialize() -> void:
	# 与 run_tests 同一个理由：--script 入口在 _initialize() 时 Autoload 还没 _ready()。
	await process_frame
	await process_frame
	_run = root.get_node_or_null(^"RunState")
	_flow = root.get_node_or_null(^"GameFlow")
	if _run == null or _flow == null:
		_say("致命：RunState / GameFlow 单例不在树里")
		quit(1)
		return
	var settings: Node = root.get_node_or_null(^"Settings")
	if settings != null:
		settings.set_locale(LOCALE, false)

	if not await _boot_to_editor():
		quit(1)
		return
	_stage()
	if not await _open_combat():
		quit(1)
		return
	if not await _push_ticks(TICKS):
		quit(1)
		return
	await _capture("combat_wave.png")
	_report()
	_replay()
	for line: String in _lines:
		print(line)
	quit(0)


# ------------------------------------------------------------------ 启动

## 走引擎那条路：落地 boot 主场景 → 自检 → 主菜单 →（按「开始新一局」）→ 编辑器。
func _boot_to_editor() -> bool:
	var packed: PackedScene = load("res://scenes/boot.tscn")
	if packed == null:
		_say("致命：boot.tscn 加载不了")
		return false
	var boot: Node = packed.instantiate()
	root.add_child(boot)
	# 不补这一步的话 change_scene_to_file() 不会回收 boot（它只回收 current_scene）。
	current_scene = boot
	_say("窗口：%s，窗口尺寸 %s，视口 %s，倍率 %.2f" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(root.get_visible_rect().size), _window_scale()])
	if not await _press_new_run():
		return false
	for _frame: int in 20:
		await process_frame
		if current_scene != null and TreeProbe.count_of(current_scene, "BoardView") == 1:
			break
	if current_scene == null or TreeProbe.count_of(current_scene, "BoardView") != 1:
		_say("致命：按了「开始新一局」也没走到编辑器")
		return false
	return true


## 等主菜单落地，然后按那颗按钮。**必须走按钮**：启动时不再有别人替玩家开局
## （PET-90 去掉了 boot 里的 start_run），主菜单那一颗就是唯一入口。
func _press_new_run() -> bool:
	for _frame: int in 20:
		await process_frame
		var start: Button = _new_run_button()
		if start != null:
			start.pressed.emit()
			return true
	_say("致命：没有从 boot 走到主菜单（当前场景 %s）" % str(current_scene))
	return false


## 当前场景里那颗「开始新一局」。按**译文**找 —— 按钮上的字是 UiKit 翻好的。
func _new_run_button() -> Button:
	if current_scene == null:
		return null
	var wanted: String = TranslationServer.translate(KEY_NEW_RUN)
	for node: Node in TreeProbe.find_all(current_scene, "Button"):
		var button: Button = node
		if button.text == wanted:
			return button
	return null


## 摆局面：重开一局（钉死种子）→ 推到第 WAVE 波 → 填书页。
## **必须赶在进战斗屏之前填** —— 战斗只读书页（03 §4.3），进去了就改不动了。
func _stage() -> void:
	_run.start_run(SEED)
	for _index: int in WAVE - 1:
		_run.advance_wave()
	var run_board: BoardModel = _run.board()
	var board: BoardModel = _fill(run_board)
	var probe: CombatSim = CombatSim.new()
	probe.begin(board, WAVE)
	var names: PackedStringArray = PackedStringArray()
	for card: CardData in probe.cast_order():
		names.append(tr(card.name_key))
	_say("局面：种子 %d，第 %d 波 / 共 %d 波，书页 %d 张卡 / %d 条连线 —— 施放队列 %s" % [
		SEED, _run.current_wave(), _run.total_waves(),
		board.cards().size(), board.links().size(), " → ".join(names)])


## 把上面那张书页填进给定模型，返回它。截图与重放**共用这一份** ——
## 各摆各的话，那张图就证明不了这份流水。
func _fill(board: BoardModel) -> BoardModel:
	var uids: Array[int] = []
	for index: int in CARD_IDS.size():
		uids.append(board.add_card(CARD_IDS[index], CARD_POS[index]).uid)
	for pair: Array in LINKS:
		board.connect_cards(uids[int(pair[0])], uids[int(pair[1])])
	return board


## EDITOR → COMBAT，走玩家那条入口（硬规则 R1：request_start_combat 是唯一入口）。
func _open_combat() -> bool:
	if not bool(_flow.request_start_combat()):
		_say("致命：EDITOR → COMBAT 被拒（当前 %s）" % _flow.state_name(_flow.get_state()))
		return false
	for _frame: int in 20:
		await process_frame
		if current_scene != null and TreeProbe.count_of(current_scene, "CombatView") == 1:
			break
	if current_scene == null or TreeProbe.count_of(current_scene, "CombatView") != 1:
		_say("致命：没有从编辑器走到战斗屏")
		return false
	_say("启动：boot 自检 → 开一局 → 编辑器 → request_start_combat() → COMBAT")
	return true


# ------------------------------------------------------------------ 推拍

## 推 count 拍，返回是否推成。
## **先把计时器停掉再推**：屏上的 Timer 是 0.05 秒一个真时间周期，等着它走的话，
## 期间多跑了几拍取决于这台机器画帧的快慢，截图里的拍数就不是个定数了。
## 停掉之后屏上的状态正好停在我推到的这一拍，报出来的数就是图上那个数。
func _push_ticks(count: int) -> bool:
	var timers: Array[Node] = TreeProbe.find_all(current_scene, "Timer")
	if timers.size() != 1:
		_say("致命：战斗屏里有 %d 个 Timer（应当恰好 1 个），推不动" % timers.size())
		return false
	var timer: Timer = timers[0]
	timer.stop()
	for _index: int in count:
		timer.timeout.emit()
	await process_frame
	# 计时器停了 = 推进权全在本文件手里，图上就正好是 _sim().elapsed_ticks() 那一拍。
	_say("推进：停掉屏上计时器后手工推了 %d 次 timeout 信号，屏上现在是第 %d 拍" % [
		count, _sim().elapsed_ticks()])
	return true


# ------------------------------------------------------------------ 数字

## 场景里那个仿真。读私有字段是**只为报数**：本文件不写它、不绕开屏改它。
func _sim() -> CombatSim:
	var screen: Node = TreeProbe.find_all(current_scene, "CombatView")[0].get_parent()
	return screen.get(&"_sim")


func _report() -> void:
	var sim: CombatSim = _sim()
	_say("画面（一律按 CombatLayout 的落点取字，不按文案前缀）：")
	_say("    标题「%s」/ 波次「%s」/ 本场结果「%s」" % [
		_at(CombatLayout.TITLE_RECT), _at(CombatLayout.WAVE_RECT), _at(CombatLayout.RESULT_RECT)])
	_say("    敌群血量「%s」/ 魔力「%s」" % [_at(CombatLayout.HP_TEXT_RECT), _at(CombatLayout.MANA_RECT)])
	_say("    施法队列「%s」" % _at(CombatLayout.QUEUE_RECT))
	_say("    本波加成「%s」" % _at(CombatLayout.BONUS_TEXT_RECT))
	_say("实测：打了 %d 拍（%.1f 秒 / 限时 %.1f 秒），敌群 %d/%d，魔力 %d，结局 %s" % [
		sim.elapsed_ticks(), float(sim.elapsed_ticks()) / float(CombatSim.TICK_HZ),
		float(sim.time_limit_ticks()) / float(CombatSim.TICK_HZ),
		sim.enemy_hp(), sim.enemy_hp_max(), sim.mana(),
		CombatSim.Outcome.keys()[sim.outcome()]])
	_say("节拍：核心每 %d 拍产 %d 点，施法每 %d 拍一次；本波 %d 档加成效力中，队列 %d 张" % [
		sim.mana_period_ticks(), _core_output(), sim.cast_interval_ticks(),
		sim.mods().total_stacks(), sim.cast_order().size()])
	_say("计件：%d 个 Label / %d 个 ColorRect / %d 个 Panel / %d 个 Timer" % [
		TreeProbe.count_of(current_scene, "Label"), TreeProbe.count_of(current_scene, "ColorRect"),
		TreeProbe.count_of(current_scene, "Panel"), TreeProbe.count_of(current_scene, "Timer")])


## 三张核心卡合计每秒出多少点。按**卡面**取，不重新推一遍仿真。
func _core_output() -> int:
	var board: BoardModel = _run.board()
	var total: int = 0
	for placed: BoardModel.PlacedCard in board.cards():
		var data: CardData = placed.data()
		if data != null and data.is_core():
			total += data.mana_output
	return total


## 某个落点上的 Label 文本。落点是版式契约（CombatLayout），文案不是。
func _at(rect: Rect2) -> String:
	for node: Node in TreeProbe.find_all(current_scene, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(rect.position):
			return label.text
	return "（没找到）"


# ------------------------------------------------------------------ 重放

## 同一张书页、同一波次跑两遍，**逐行**比对结算流水。
## 逐行而不是比最终血量：两场顺序完全不同、总伤害恰好相同的战斗不该被判成一致。
## 顺带把两张书页各建一次（而不是复用同一个对象）：这样证明的是「同一份摆法结果相同」，
## 而不是「同一个对象被跑了两遍」。
func _replay() -> void:
	var board: BoardModel = _fill(BoardModel.new())
	var first: PackedStringArray = _ledger(board)
	var second: PackedStringArray = _ledger(_fill(BoardModel.new()))
	_say("重放：同一书页 + 第 %d 波，各跑 %d 拍 —— 两次各 %d 行，逐行%s" % [
		WAVE, REPLAY_TICKS, first.size(), "一致" if first == second else "**不一致**"])
	_say("流水指纹（整份流水的 hash）：%d / %d" % [_fingerprint(first), _fingerprint(second)])
	_say("重放流水（第一遍，逐行）：")
	for line: String in first:
		_say("    " + line)


## 把这张书页跑到底，交回结算流水。第一行是收官状态，之后每行一次施法。
func _ledger(board: BoardModel) -> PackedStringArray:
	var sim: CombatSim = CombatSim.new()
	sim.begin(board, WAVE)
	sim.advance(REPLAY_TICKS)
	return sim.settlement_log()


## 流水指纹。逐行比对之外再给一个数 —— 复核的人一眼看得出「这两份不是碰巧同长」。
func _fingerprint(log: PackedStringArray) -> int:
	return "\n".join(log).hash()


# ------------------------------------------------------------------ 截图

func _capture(file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# 等这一帧真的画完再取纹理，否则拿到的是上一帧（刚推的那 100 拍还没画上去）。
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		_say("致命：拿不到窗口纹理，%s 未生成" % file_name)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, file_name]
	var error: Error = image.save_png(path)
	if error != OK:
		_say("致命：%s 写入失败（错误码 %d）" % [path, error])
		return
	# 截图取的是**逻辑渲染目标**（960×540），不是窗口帧缓冲：stretch/mode=viewport 下引擎先按
	# 960×540 画，再整块放大贴到窗口上。所以「2×」只能靠 窗口 ÷ 视口 + scale_mode=integer 证明。
	_say("截图：%s %d×%d（逻辑渲染目标；scale_mode=%s）" % [
		path, image.get_width(), image.get_height(),
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode"))])


## 窗口 ÷ 视口的整数倍率（960×540 → 1920×1080 即 2）。
func _window_scale() -> float:
	return float(DisplayServer.window_get_size().x) / root.get_visible_rect().size.x


func _say(line: String) -> void:
	_lines.append("[capture] " + line)
