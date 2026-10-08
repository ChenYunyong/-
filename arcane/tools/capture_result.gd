## capture_result.gd
## 职责：结算屏的**像素证据**采集 —— 真机把两条收场各走一遍：打输（核心被摧毁）与通关，
##       各截一张，并打印屏上真实读到的字与这一局真实发生的数字。
## 所属系统：tools
## 依赖：tests/tree_probe.gd（子树查找）、tests/integration/run_driver.gd（按钮 / 等待 / 路线图原语）、
##       CardCatalog、Battle 与结算相关的场景
## 禁止：本文件不得改动任何产品代码；不得被游戏运行时引用（tools/* 已排除导出）。
##
## 为什么用 run_driver 而不是自己点按钮：端到端用例已经把那套「按译文找按钮 → 等状态换屏」
## 磨过一遍了，这里再抄一份的话，界面一改就有两份要跟着改。
##
## 09 §8 要求证据附「窗口是否可见 + 验证方式 + 实测数字」，三者都在打印里给出。
##
## 运行方式（**不要**加 --headless，截图需要真实渲染窗口）：
##   godot --path . --script res://tools/capture_result.gd

extends SceneTree

const Driver = preload("res://tests/integration/run_driver.gd")
const TreeProbe = preload("res://tests/tree_probe.gd")

const OUTPUT_DIR: String = "res://tests/output"
const KEY_NEW_RUN: String = "开始新一局"
## 通关那条要钉住种子：按键开局走的是 SEED_AUTO，而**运气会决定输赢**（实测 20 个种子里
## 11 个通关 —— 领到的功能卡也吃魔力，火力被挤掉就可能在某一波打不完）。
## 这张截图要的是「通关结算」那一屏，所以种子的选法与 full_run_smoke 一致。
const PINNED_SEED: int = 20261008
## 战斗按真实计时器走（20Hz）：一场三波约 40 秒真实时间。压 time_scale 而不是去戳战斗屏的
## 内部方法 —— 戳内部就绕开了「计时器真的在跑」，而那正是这些画面要证明的。用完还原。
const FIGHT_TIME_SCALE: float = 50.0
const FIGHT_FRAMES: int = 8000

var _d: RefCounted = null
var _lines: Array[String] = []


func _initialize() -> void:
	# 与 run_tests 同一个理由：--script 入口在 _initialize() 时 Autoload 还没 _ready()。
	await process_frame
	await process_frame
	_d = Driver.new()
	if not _d.setup(self):
		_say("致命：%s" % _d.last_error())
		quit(1)
		return
	# 强制中文再截（同 capture_map）：这一屏的字全走 i18n，系统语言不是中文时截出来是英文。
	# 入口脚本是 --script 方式编译的，**写不出 Autoload 标识符**，只能从 /root 取。
	var settings: Node = root.get_node_or_null(^"Settings")
	if settings != null:
		settings.set_locale("zh_CN", false)

	var groups: Array = []
	if not await _defeat_run():
		quit(1)
		return
	groups.append(_report_defeat())
	if not await _victory_run():
		quit(1)
		return
	groups.append(_report_victory())

	_say("窗口：%s，窗口尺寸 %s，视口 %s，倍率 %.2f" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(root.get_visible_rect().size), _window_scale()])
	for group: Dictionary in groups:
		for line: String in group["lines"]:
			_say(line)
	for line: String in _lines:
		print(line)
	quit(0)


# ------------------------------------------------------------------ 第一条：打输

## 起手只摆核心、一条丝线都不连 —— 这一场必然超时（30 秒打不完 60 点血）= 一波失败。
func _defeat_run() -> bool:
	if not await _boot_to_menu():
		return false
	if not await _press(KEY_NEW_RUN, _d.flow().GameState.EDITOR, "开始新一局"):
		return false
	var core: BoardModel.PlacedCard = _d.place_card(&"core_arcane")
	if core == null:
		_say("致命：摆不上核心（%s）" % _d.last_error())
		return false

	Engine.time_scale = FIGHT_TIME_SCALE
	var entered: bool = await _press(Driver.KEY_START_BATTLE, _d.flow().GameState.COMBAT, "开始战斗")
	var destroyed: bool = false
	if entered:
		destroyed = await _d.fight_until_settle()
	Engine.time_scale = 1.0
	if not destroyed:
		_say("致命：核心没有被摧毁（%s）" % _d.last_error())
		return false
	_say("打输那场：丝线 %d 条，波次 %d，超时后停在战斗屏（等玩家按「结算」）" % [
		_d.run_state().board().links().size(), _d.run_state().current_wave()])
	if not await _press(Driver.KEY_SETTLE, _d.flow().GameState.RESULT, "结算"):
		return false
	return await _capture("result_defeat.png")


func _report_defeat() -> Dictionary:
	return {"lines": _screen_lines("打输的结算屏", [
		"本局结束", "还没出发", "什么都没拿",
	], "tiers=%d taken=%d result=%d" % [
		_d.run_state().tiers_seen(), _d.run_state().taken_rewards().size(),
		_d.run_state().result()])}


# ------------------------------------------------------------------ 第二条：通关

## 回主菜单 → 开新的一局 → 摆上一张要付费的法术并连起来 → 一路打到通关。
func _victory_run() -> bool:
	if not await _press(Driver.KEY_MENU, _d.flow().GameState.MAIN_MENU, "回到主菜单"):
		return false
	if not await _press(KEY_NEW_RUN, _d.flow().GameState.EDITOR, "开始新一局"):
		return false
	_d.run_state().start_run(PINNED_SEED)
	var spell: CardData = _first_spell()
	# 核心是上一局就摆好的（重开一局**不清空书页**，见 run_state.gd）。
	var core: BoardModel.PlacedCard = _d.placed_of(&"core_arcane")
	var placed: BoardModel.PlacedCard = _d.place_card(spell.id)
	if core == null or placed == null or not _d.link(core.uid, placed.uid):
		_say("致命：起手摆不出「核心 + 法术 + 丝线」（%s）" % _d.last_error())
		return false
	_say("通关那条：种子钉在 %d，起手书页 %d 卡 / %d 线（%s）" % [
		_d.run_state().get_run_seed(), _d.run_state().board().cards().size(),
		_d.run_state().board().links().size(), _walk_note()])
	if not await _walk():
		return false
	return await _capture("result_victory.png")


## 按「当前在哪一屏」反复往下走：编辑器开打 → 领奖励 → 路线图选下一站 —— 直到结算屏。
func _walk() -> bool:
	for _round: int in 48:
		var state: int = _d.flow().get_state()
		var flow: Node = _d.flow()
		if state == flow.GameState.RESULT:
			return true
		if state == flow.GameState.EDITOR:
			if not await _press(Driver.KEY_START_BATTLE, flow.GameState.COMBAT, "开始战斗"):
				return false
		elif state == flow.GameState.COMBAT:
			if not await _fight():
				return false
		elif state == flow.GameState.REWARD:
			if not await _claim():
				return false
		elif state == flow.GameState.MAP:
			if not await _advance():
				return false
		else:
			_say("致命：走到了意料之外的状态 %s" % flow.state_name(state))
			return false
	_say("致命：48 轮内没能打穿最后一层")
	return false


func _fight() -> bool:
	Engine.time_scale = FIGHT_TIME_SCALE
	var done: bool = await _d.await_until(func() -> bool:
		return _d.flow().get_state() != _d.flow().GameState.COMBAT, FIGHT_FRAMES)
	Engine.time_scale = 1.0
	if not done:
		_say("致命：这一场打不完（%s）" % _d.last_error())
	return done


## 领奖励：拿选项里第一张**卡**（界面按选项顺序建按钮，故第 index 颗就是它）。
func _claim() -> bool:
	var options: Array[Dictionary] = _d.run_state().roll_rewards()
	var index: int = _first_card_index(options)
	if index < 0:
		_say("致命：这一次没有可拿的卡")
		return false
	var buttons: Array[Node] = _d.buttons_of(_d.scene(), Driver.KEY_CHOOSE)
	if buttons.size() != options.size():
		_say("致命：奖励屏的「选择」有 %d 颗，选项有 %d 个" % [buttons.size(), options.size()])
		return false
	return await _d.press_and_wait(buttons[index], _d.flow().GameState.MAP)


## 路线图：点亮下一站再按「继续」。press() 是 MapView 的公开入口 ——
## 鼠标手势那条链由 map_view_smoke 与 capture_map 负责，这里要的是把这一局带过去。
func _advance() -> bool:
	var picked: int = _d.select_next_node()
	if picked < 0:
		_say("致命：路线图上没有可走的一站（%s）" % _d.last_error())
		return false
	return await _d.press_and_leave(_d.button_for(_d.scene(), Driver.KEY_CONTINUE))


func _report_victory() -> Dictionary:
	var taken: Array[Dictionary] = _d.run_state().taken_rewards()
	var names: PackedStringArray = PackedStringArray()
	for option: Dictionary in taken:
		names.append(RewardModel.name_text(option))
	return {"lines": _screen_lines("通关的结算屏", [
		"通关", "到过 %d 层" % MapModel.TIERS,
	], "tiers=%d taken=%d（%s）result=%d 地图 %s" % [
		_d.run_state().tiers_seen(), taken.size(), ", ".join(names),
		_d.run_state().result(), _d.map_fingerprint().sha256_text().substr(0, 12)])}


# ------------------------------------------------------------------ 启动与按屏

func _boot_to_menu() -> bool:
	var packed: PackedScene = load(Driver.BOOT_SCENE)
	if packed == null:
		_say("致命：boot.tscn 加载不了")
		return false
	var boot: Node = packed.instantiate()
	root.add_child(boot)
	# 不补这一步的话 change_scene_to_file() 不会回收 boot（它只回收 current_scene）。
	current_scene = boot
	return await _d.await_until(func() -> bool:
		return _d.button_for(_d.scene(), KEY_NEW_RUN) != null, Driver.SWITCH_FRAMES)


## 按一颗按钮并等它把状态带到 expected。
func _press(text_key: String, expected: int, what: String) -> bool:
	var button: Button = _d.button_for(_d.scene(), text_key)
	if button == null:
		_say("致命：当前屏上没有「%s」（想按它去%s）" % [text_key, what])
		return false
	var ok: bool = await _d.press_and_wait(button, expected)
	if not ok:
		_say("致命：按「%s」没去到 %s（%s）" % [text_key, what, _d.last_error()])
	return ok


## 这一屏上真实读到的字：屏上有的逐条确认，账目那种拼出来的一行整串念出来。
func _screen_lines(title: String, wanted: PackedStringArray, numbers: String) -> Array:
	var screen: Node = _d.scene()
	var found: PackedStringArray = PackedStringArray()
	for key: String in wanted:
		found.append("%s %s" % [key, "有" if _d.has_label(screen, key) else "**没有**"])
	var labels: int = 0
	var texts: PackedStringArray = PackedStringArray()
	for node: Node in TreeProbe.find_all(screen, "Label"):
		var text: String = (node as Label).text
		if text.strip_edges().is_empty():
			continue
		labels += 1
		if texts.size() < 8:
			texts.append(text)
	return [
		"%s：%s" % [title, "，".join(found)],
		"%s：%d 行文字 / %d 颗按钮 —— %s" % [title, labels,
			TreeProbe.count_of(screen, "Button"), numbers],
		"%s：屏上逐行 = %s" % [title, " ｜ ".join(texts)],
	]


func _first_spell() -> CardData:
	for card: CardData in CardCatalog.all():
		if not card.is_core() and card.mana_cost > 0:
			return card
	return null


func _first_card_index(options: Array[Dictionary]) -> int:
	for index: int in options.size():
		if RewardModel.is_card(options[index]):
			return index
	return -1


func _walk_note() -> String:
	var spell: CardData = _first_spell()
	return "法术 %s" % ("（没有）" if spell == null else String(spell.id))


# ------------------------------------------------------------------ 截图与数字

func _capture(file_name: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# 等这一帧真的画完再取纹理，否则拿到的是上一帧（刚换的那一屏还没画上去）。
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null:
		_say("致命：拿不到窗口纹理，%s 未生成" % file_name)
		return false
	var path: String = "%s/%s" % [OUTPUT_DIR, file_name]
	var error: Error = image.save_png(path)
	if error != OK:
		_say("致命：%s 写入失败（错误码 %d）" % [path, error])
		return false
	# 截图取的是**逻辑渲染目标**（960×540），不是窗口帧缓冲：stretch/mode=viewport 下引擎先按
	# 960×540 画，再整块放大贴到窗口上（与 capture_map 同一条）。
	_say("截图：%s %d×%d（逻辑渲染目标；scale_mode=%s）" % [
		path, image.get_width(), image.get_height(),
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode"))])
	return true


## 窗口 ÷ 视口的整数倍率（960×540 → 1920×1080 即 2）。
func _window_scale() -> float:
	return float(DisplayServer.window_get_size().x) / root.get_visible_rect().size.x


func _say(line: String) -> void:
	_lines.append("[capture] " + line)
