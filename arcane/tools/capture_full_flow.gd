## capture_full_flow.gd
## 职责：PET-94「全流程自测」的**像素证据** —— 在真实运行里把一局从主菜单走到结算、再走回主菜单，
##       每一步换屏都留一张图，并写下这一屏真实读到的字与这一局真实发生的数字。
## 所属系统：tools
## 依赖：tests/tree_probe.gd、tests/integration/run_driver.gd、CardCatalog 与各屏场景
## 禁止：本文件不得改动任何产品代码；不得被游戏运行时引用（tools/* 已排除导出）。
##
## 与 capture_result.gd 的分工：那个只管结算屏的两种收场；这个管**整条链路**：
##   主菜单 → 新开一局 → 编辑书页 → 路线图 → 战斗 → 奖励 → 推进 → … → 结算 → 回主菜单
##
## 两处刻意的取舍：
##   1. **不 await RenderingServer.frame_post_draw**。窗口由壳脚本从**外部**用 Win32 SW_HIDE 藏起来
##      （最小化那条路实测会停掉渲染，见 tools/hide_run.ps1）。隐藏态下 frame_post_draw 会不会照常
##      发没有实测过，真挂住整个取证就废了；改成「等固定帧数 → 截 → 当场数不同色数」，
##      画不出来一样看得出来，但不会挂。
##   2. 种子钉在 PINNED_SEED。按键开局走的是 SEED_AUTO，而**运气决定输赢**（capture_result 实测
##      20 个种子里 11 个通关），这条链路要走到结算屏。钉种子是测试夹具，不是产品行为，报告里写明。
##
## 运行方式（**不要**加 --headless，截图需要真实渲染；窗口由壳脚本藏起来）：
##   powershell -File tools/hide_run.ps1 -Exe <godot.exe> -Arcane <工程目录> `
##       -ScriptPath res://tools/capture_full_flow.gd -Log <日志文件>

extends SceneTree

const Driver = preload("res://tests/integration/run_driver.gd")
const TreeProbe = preload("res://tests/tree_probe.gd")

const OUTPUT_DIR: String = "res://tests/output"
const REPORT_NAME: String = "full_flow_report.txt"

const KEY_NEW_RUN: String = "开始新一局"
## 编辑书页头栏那颗「路线图」是**图标控件**（PET-87 起没有文字），按译文只能从 tooltip / 无障碍名找。
const KEY_OPEN_MAP: String = "路线图"

const PINNED_SEED: int = 20261008
const FIGHT_TIME_SCALE: float = 50.0
const WALK_ROUNDS: int = 48
## 进战斗屏后先按**常速**跑几拍再截 —— 一进去就截，截到的是一张还没开打的空场。
## 90 帧 ≈1.5 秒，远短于一场战斗（最多 30 秒），不会把仗打完。
const COMBAT_WARMUP_FRAMES: int = 90
## 截一张图前等几帧，让刚换上的那一屏真的画上去。
const PAINT_FRAMES: int = 4
## 一张图至少要有这么多种颜色才算「画出来了」；低于它就是黑屏 / 空屏。
const MIN_COLORS: int = 4

var _d: RefCounted = null
var _lines: Array[String] = []
var _reward_shot_done: bool = false
var _battles: int = 0


func _initialize() -> void:
	# 与 run_tests 同一个理由：--script 入口在 _initialize() 时 Autoload 还没 _ready()。
	await process_frame
	await process_frame
	_d = Driver.new()
	if not _d.setup(self):
		_say("致命：%s" % _d.last_error())
		_finish(1)
		return
	# 这一屏的字全走 i18n；系统语言不是中文时截出来是英文，先钉成中文。
	# 入口脚本是 --script 方式编译的，**写不出 Autoload 标识符**，只能从 /root 取。
	var settings: Node = root.get_node_or_null(^"Settings")
	if settings != null:
		settings.set_locale("zh_CN", false)
	var ok: bool = await _run()
	_finish(0 if ok else 1)


# ------------------------------------------------------------------ 整条链路

func _run() -> bool:
	if not await _boot_to_menu():
		return false
	if not await _shot("flow_01_main_menu.png", "① 主菜单"):
		return false
	if not await _press(KEY_NEW_RUN, _d.flow().GameState.EDITOR, "编辑书页"):
		return false
	# 按键开局走 SEED_AUTO —— 钉住种子，这一局才可复现（见文件头第 2 条）。
	_d.run_state().start_run(PINNED_SEED)
	if not _build_page():
		return false
	if not await _shot("flow_02_editor.png", "② 编辑书页"):
		return false
	if not await _press_icon(KEY_OPEN_MAP, _d.flow().GameState.MAP, "路线图"):
		return false
	if not await _pick_next_node():
		return false
	if not await _shot("flow_03_map.png", "③ 路线图（已点亮下一站）"):
		return false
	if not await _continue_from_map():
		return false
	if not await _walk():
		return false
	if not await _shot("flow_06_result.png", "⑥ 结算"):
		return false
	if not await _press(Driver.KEY_MENU, _d.flow().GameState.MAIN_MENU, "回主菜单"):
		return false
	return await _shot("flow_07_back_to_menu.png", "⑦ 回到主菜单（闭环）")


## 按「当前在哪一屏」反复往下走：编辑器开打 → 领奖励 → 路线图选下一站 —— 直到结算屏。
func _walk() -> bool:
	var flow: Node = _d.flow()
	for _round: int in WALK_ROUNDS:
		var state: int = flow.get_state()
		if state == flow.GameState.RESULT:
			return true
		if state == flow.GameState.EDITOR:
			if not await _press(Driver.KEY_START_BATTLE, flow.GameState.COMBAT, "开始战斗"):
				return false
		elif state == flow.GameState.COMBAT:
			if not await _fight():
				return false
		elif state == flow.GameState.REWARD:
			if not _reward_shot_done:
				if not await _shot("flow_05_reward.png", "⑤ 奖励（第 1 次）"):
					return false
				_reward_shot_done = true
			if not await _claim():
				return false
		elif state == flow.GameState.MAP:
			if not await _pick_next_node() or not await _continue_from_map():
				return false
		else:
			_say("致命：走到了意料之外的状态 %s" % flow.state_name(state))
			return false
	_say("致命：%d 轮内没能打到结算屏" % WALK_ROUNDS)
	return false


## 一场仗：第一场先常速跑几拍把「真的打起来了」截下来，再压 time_scale 打到自然收场。
func _fight() -> bool:
	_battles += 1
	if _battles == 1:
		for _i: int in COMBAT_WARMUP_FRAMES:
			await process_frame
		if not await _shot("flow_04_combat.png", "④ 战斗（第 1 场，第 %d 层）" % _tier()):
			return false
	Engine.time_scale = FIGHT_TIME_SCALE
	var done: bool = await _d.await_until(func() -> bool:
		return _d.flow().get_state() != _d.flow().GameState.COMBAT, Driver.MAX_FIGHT_FRAMES)
	Engine.time_scale = 1.0
	if not done:
		_say("致命：第 %d 场打不完（%s）" % [_battles, _d.last_error()])
		return false
	_say("第 %d 场收场 → %s（第 %d 层）" % [
		_battles, _d.flow().state_name(_d.flow().get_state()), _tier()])
	return true


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


# ------------------------------------------------------------------ 起步与按屏

func _boot_to_menu() -> bool:
	if not await _d.boot_into_menu():
		_say("致命：起不到主菜单（%s）" % _d.last_error())
		return false
	return await _d.await_until(func() -> bool:
		return _d.button_for(_d.scene(), KEY_NEW_RUN) != null, Driver.SWITCH_FRAMES)


## 书页上摆「核心 + 一张法术 + 一条丝线」：与 capture_result 通关那条同一套起手 ——
## 这一局才有得打，书页截图里也有真东西可看。
func _build_page() -> bool:
	var core: BoardModel.PlacedCard = _d.place_card(&"core_arcane")
	var spell: CardData = _first_spell()
	var placed: BoardModel.PlacedCard = null if spell == null else _d.place_card(spell.id)
	if core == null or placed == null or not _d.link(core.uid, placed.uid):
		_say("致命：起手摆不出「核心 + 法术 + 丝线」（%s）" % _d.last_error())
		return false
	_say("起手书页：%d 卡 / %d 线，法术 %s" % [
		_d.run_state().board().cards().size(), _d.run_state().board().links().size(),
		String(spell.id)])
	return true


## 按一颗**文字**按钮并等它把状态带到 expected。
func _press(text_key: String, expected: int, what: String) -> bool:
	var button: Button = _d.button_for(_d.scene(), text_key)
	if button == null:
		_say("致命：当前屏上没有「%s」（想按它去%s）" % [text_key, what])
		return false
	if not await _d.press_and_wait(button, expected):
		_say("致命：按「%s」没去到%s（%s）" % [text_key, what, _d.last_error()])
		return false
	return true


## 按一颗**图标**按钮（没有文字，只有 tooltip / 无障碍名）并等它把状态带到 expected。
func _press_icon(text_key: String, expected: int, what: String) -> bool:
	var wanted: String = TranslationServer.translate(text_key)
	var button: Button = null
	for node: Node in TreeProbe.find_all(_d.scene(), "Button"):
		var candidate: Button = node as Button
		if candidate.text.is_empty() and candidate.tooltip_text == wanted \
				and candidate.is_visible_in_tree():
			button = candidate
			break
	if button == null:
		_say("致命：当前屏上没有图标控件「%s」（想按它去%s）" % [text_key, what])
		return false
	if not await _d.press_and_wait(button, expected):
		_say("致命：按图标「%s」没去到%s（%s）" % [text_key, what, _d.last_error()])
		return false
	return true


## 路线图：点亮下一站。press() 是 MapView 的公开入口（鼠标手势那条链由 map_view_smoke 负责）。
func _pick_next_node() -> bool:
	if _d.select_next_node() < 0:
		_say("致命：路线图上没有可走的一站（%s）" % _d.last_error())
		return false
	return true


## 路线图上按「继续」离开 —— 去 COMBAT 还是回 EDITOR（工坊站）由这一站是什么决定。
func _continue_from_map() -> bool:
	var button: Button = _d.button_for(_d.scene(), Driver.KEY_CONTINUE)
	if button == null:
		_say("致命：路线图上没有「%s」" % Driver.KEY_CONTINUE)
		return false
	if not await _d.press_and_leave(button):
		_say("致命：按「继续」没离开路线图（%s）" % _d.last_error())
		return false
	return true


# ------------------------------------------------------------------ 截图与报告

func _shot(file_name: String, what: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for _i: int in PAINT_FRAMES:
		await process_frame
	var image: Image = root.get_texture().get_image()
	if image == null:
		_say("致命：拿不到窗口纹理，%s 未生成" % file_name)
		return false
	var colors: Dictionary = {}
	for x: int in range(0, image.get_width(), 11):
		for y: int in range(0, image.get_height(), 11):
			colors[image.get_pixel(x, y).to_rgba32()] = true
	var path: String = "%s/%s" % [OUTPUT_DIR, file_name]
	var error: Error = image.save_png(path)
	if error != OK:
		_say("致命：%s 写入失败（错误码 %d）" % [path, error])
		return false
	# 截图取的是**逻辑渲染目标** 960×540，不是窗口帧缓冲：stretch/mode=viewport 下引擎先按
	# 960×540 画，再整块放大贴到窗口上（与 capture_map / capture_result 同一条）。
	_say("%s → %s %d×%d，抽样不同色数 %d%s" % [what, file_name, image.get_width(),
		image.get_height(), colors.size(),
		"（屏上文字：%s）" % _screen_note()])
	if colors.size() < MIN_COLORS:
		_say("致命：%s 只有 %d 种颜色，像是一张空屏 —— 渲染路径没通" % [file_name, colors.size()])
		return false
	return true


## 这一屏上真实读到的几行字。屏上没文字（战斗屏）就如实说「没有」。
func _screen_note() -> String:
	var texts: PackedStringArray = PackedStringArray()
	for node: Node in TreeProbe.find_all(_d.scene(), "Label"):
		var text: String = (node as Label).text.strip_edges()
		if not text.is_empty() and texts.size() < 6:
			texts.append(text)
	return "没有文字行" if texts.is_empty() else " ｜ ".join(texts)


func _tier() -> int:
	return _d.run_state().tiers_seen()


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


func _say(line: String) -> void:
	_lines.append(line)
	print("[flow] " + line)


## 报告同时落到 tests/output/ 下：进程若被外部终止，报告仍在盘上。
func _finish(code: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var outcome: String = "这一局没走起来"
	if _run_state() != null:
		outcome = "结果码 %d｜到过 %d 层｜拿过 %d 份奖励｜打了 %d 场" % [
			_run_state().result(), _run_state().tiers_seen(),
			_run_state().taken_rewards().size(), _battles]
	var header: PackedStringArray = PackedStringArray([
		"PET-94 全流程自测 —— 真机运行报告",
		"引擎：Godot %s" % Engine.get_version_info()["string"],
		"窗口：%s，窗口尺寸 %s，视口 %s，倍率 %.2f" % [
			DisplayServer.get_name(), str(DisplayServer.window_get_size()),
			str(root.get_visible_rect().size), _window_scale()],
		"种子：%d（钉住）｜%s" % [PINNED_SEED, outcome],
		"",
	])
	var file: FileAccess = FileAccess.open("%s/%s" % [OUTPUT_DIR, REPORT_NAME], FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(header) + "\n".join(_lines) + "\n")
		file.close()
	print("\n".join(header) + "\n".join(_lines))
	print("[flow] 报告 → %s/%s" % [OUTPUT_DIR, REPORT_NAME])
	quit(code)


func _run_state() -> Node:
	return null if _d == null else _d.run_state()


## 窗口 ÷ 视口的整数倍率（960×540 → 1920×1080 即 2）。
func _window_scale() -> float:
	return float(DisplayServer.window_get_size().x) / root.get_visible_rect().size.x
