## capture_main_menu.gd
## 职责：主菜单屏的**像素证据**采集 —— 真机走启动路径落在主菜单，截图并打印实测数字；
##       再打开设置、按一次语言开关，证明界面文案真的当场跟着换。
## 所属系统：tools
## 依赖：tests/tree_probe.gd（只借它做子树查找）、MenuLayout（落点契约）、MenuTheme（配色角色表）、
##       boot.tscn 与主菜单场景
## 禁止：本文件不得改动任何产品代码；不得被游戏运行时引用（tools/* 已排除导出）。
##
## 为什么不是「摆好一个状态再截图」：这里走的是引擎那条路 —— 落地 boot 主场景、自检、
## 由 GameFlow 路由到主菜单。于是图上那四颗入口、那句置灰说明、那句「没有进行中的一局」，
## 是这条链真的跑出来的产物，而不是采集脚本手搓出来的画面。
##
## 三张图各证一件事：
##   main_menu_zh.png       中文常态：Logo + 四个入口，「继续」置灰并写清原因
##   main_menu_settings.png 按过「设置」：设置浮层出现，里面有语言开关（此时后方入口已藏起）
##   main_menu_en.png       按过语言开关、收起浮层：四颗入口的字当场变英文（同一屏，没有重进）
##
## 语言那一下**真的按那颗按钮**（走 Settings.toggle_locale()，与玩家无异），所以它按设计会
## 落盘 user://settings.cfg；按回来之后文件里是中文。想完全不碰这份偏好就别跑本脚本。
##
## 09 §8 要求证据附「窗口是否可见 + 验证方式 + 实测数字」，三者都在打印里给出。
##
## 运行方式（**不要**加 --headless，截图需要真实渲染窗口）：
##   godot --path . --script res://tools/capture_main_menu.gd

extends SceneTree

const TreeProbe = preload("res://tests/tree_probe.gd")
const OUTPUT_DIR: String = "res://tests/output"
## 强制中文再截：这一屏的字全走 i18n，系统语言不是中文时截出来是英文，
## 而这几张图要说明的正是「新文案进了表」（四颗入口与置灰说明全经 TranslationServer）。
const LOCALE_ZH: String = "zh_CN"
## `-- --locale en` 走**英文冷进入**那一帧（PET-97 #7 的复量路径）。
const ARG_LOCALE: String = "--locale"

var _run: Node = null
var _flow: Node = null
var _settings: Node = null
var _original_locale: String = ""
var _cold_locale: String = ""
var _lines: Array[String] = []


func _initialize() -> void:
	# 与 run_tests 同一个理由：--script 入口在 _initialize() 时 Autoload 还没 _ready()。
	await process_frame
	await process_frame
	_parse_args()
	_run = root.get_node_or_null(^"RunState")
	_flow = root.get_node_or_null(^"GameFlow")
	_settings = root.get_node_or_null(^"Settings")
	if _run == null or _flow == null or _settings == null:
		_fail("RunState / GameFlow / Settings 单例不在树里")
		return
	_original_locale = _settings.get_locale()
	# 冷进入那一帧要先设语言**再**建屏，故它单独一条路。
	if _cold_locale != "":
		await _capture_cold()
		return
	_settings.set_locale(LOCALE_ZH, false)

	if not await _boot_to_menu():
		return
	await _capture("main_menu_zh.png")
	_report_menu()
	if not _open_settings():
		return
	await _capture("main_menu_settings.png")
	_toggle_language()
	# PET-97 #7：设置说明那一格在英文下**必须折行**（单行实测 491 > 内容区 384），
	# 所以第四张图取在「已切成英文、浮层还开着」这一刻，并把那一行的排版数字打出来。
	await _capture("main_menu_settings_en.png")
	_report_help()
	if not _close_settings():
		return
	await _capture("main_menu_en.png")
	_report_language()
	_report_marks()
	_finish()


# ------------------------------------------------------------------ 启动

## 只认 `--` 之后的用户参数。
func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		if args[index] == ARG_LOCALE and index + 1 < args.size():
			_cold_locale = args[index + 1]
			index += 2
			continue
		index += 1


## PET-97 #7 的复量帧：**英文冷进入** —— locale 在 `_boot_to_menu()` **之前**就是 en，
## 于是设置说明那条 Label 是在「最小宽 = 整段排成一行」的时刻被定量的。
## 默认流程（先中文建屏、再切英文）量不到这条路径：热切换时折行早就生效，控件顶不动 384。
## 两张图各证一条路，不能互相顶替。
func _capture_cold() -> void:
	_settings.set_locale(_cold_locale, false)
	if not await _boot_to_menu():
		return
	_say("冷进入：建屏**之前** locale 就是 %s（不是建完再切）" % _settings.get_locale())
	if not _open_settings():
		return
	await _capture("main_menu_settings_%s_cold.png" % _cold_locale)
	_report_help()
	_report_marks()
	_settings.set_locale(_original_locale, false)
	_finish()

## 走引擎那条路：落地 boot 主场景 → 自检 → 主菜单。boot 自己**不开局**（PET-90）。
func _boot_to_menu() -> bool:
	var packed: PackedScene = load("res://scenes/boot.tscn")
	if packed == null:
		_fail("boot.tscn 加载不了")
		return false
	var boot: Node = packed.instantiate()
	root.add_child(boot)
	# 不补这一步的话 change_scene_to_file() 不会回收 boot（它只回收 current_scene）。
	current_scene = boot
	_say("窗口：%s，窗口尺寸 %s，视口 %s，倍率 %.2f" % [
		DisplayServer.get_name(), str(DisplayServer.window_get_size()),
		str(root.get_visible_rect().size), _window_scale()])
	# 等主菜单落地。**找的是 current_scene**：这一刻屏幕上是什么由引擎决定，
	# 不是本脚本挑的（先记一个 _menu 再拿它去找，第一帧就永远找不到）。
	for _frame: int in 20:
		await process_frame
		if _button(MenuLayout.KEY_NEW_RUN) != null:
			break
	if _button(MenuLayout.KEY_NEW_RUN) == null:
		_fail("没有从 boot 走到主菜单（当前场景 %s）" % str(current_scene))
		return false
	_say("启动：boot 自检 → 主菜单（状态 %s，%d 颗按钮），启动时这一局是**没有**的 = %s" % [
		_flow.state_name(_flow.get_state()), TreeProbe.count_of(current_scene, "Button"),
		str(_run.is_active())])
	return true


# ------------------------------------------------------------------ 实测数字

## 四颗入口的字与落点，外加「继续」此刻的可用性 —— 都在**跑起来的界面**上读，不读常量表。
## 落点旁边同时打出 §2.4 表里的数：两者不等就是装配没跟上契约（G02 的误差 ≤1）。
func _report_menu() -> void:
	var rects: Array[Rect2] = MenuLayout.entry_rects()
	for index: int in MenuLayout.BUTTONS.size():
		var key: String = MenuLayout.BUTTONS[index]
		var button: Button = _button(key)
		if button == null:
			_say("致命：入口「%s」不在屏上" % key)
			continue
		_say("入口「%s」→ 屏上写着「%s」，真实 rect %s ／ 表里 %s，置灰 = %s，装饰层 %d 层" % [
			key, button.text, str(button.get_global_rect()), str(rects[index]),
			str(button.disabled), TreeProbe.count_of(button, "ButtonMarks")])
	_say("「继续」下面那行原因：「%s」（没有进行中的局时才写上去，控件一直在，按钮位置因此不跳）"
		% _hint_text())
	var first: Button = _button(MenuLayout.KEY_NEW_RUN)
	if first != null:
		# 触控下限 44 设备像素（06 §1）。高度早在 §2.4 的表里给死，这里换成设备像素读数。
		_say("触控目标：入口高 %.0f 逻辑像素 → %.0f 设备像素（06 §1 下限 44）" % [
			first.size.y, first.size.y * _window_scale()])


## §3：设置入口。按下去浮层才出现 —— 语言开关就住在里面，而后方四个入口同时藏起来（N04）。
func _open_settings() -> bool:
	var entry: Button = _button(MenuLayout.KEY_SETTINGS)
	if entry == null:
		_fail("主菜单上没有「设置」入口")
		return false
	entry.pressed.emit()
	var switch: Button = _button(MenuLayout.KEY_LANGUAGE_SWITCH)
	if switch == null or not switch.is_visible_in_tree():
		_fail("按了「设置」也没看到语言开关")
		return false
	_say("设置：按「%s」→ 浮层出现（表里 %s），里面有语言开关「%s」，落点 %s" % [
		entry.text, str(MenuLayout.SETTINGS_PANEL), switch.text, str(switch.get_global_rect())])
	var visible_entries: int = 0
	for key: String in MenuLayout.BUTTONS:
		if _button(key) != null and _button(key).is_visible_in_tree():
			visible_entries += 1
	_say("      浮层打开时后方可见入口 = %d 个（N04 要求 0 —— 藏着的控件收不到点击）" % visible_entries)
	return true


## 收起浮层 —— 第三张图要在**收起之后**截：浮层开着时后方四个入口是藏着的，
## 而那张图要证的恰恰是「四颗入口的字当场变英文」，不收起就什么也拍不到。
##
## 关不掉时必须**中止**（返回 false 让调用方收手）：放它过去的话，第三张图拍的是
## 「英文 + 浮层还开着」，而打印里只有一行「致命」，看图的人无从分辨 —— 这张图就废了。
func _close_settings() -> bool:
	var close: Button = _close_button()
	if close == null:
		_fail("浮层上没有关闭键（tooltip 没跟上当前语言？）")
		return false
	close.pressed.emit()
	var entry: Button = _button(MenuLayout.KEY_NEW_RUN)
	var back: bool = entry != null and entry.is_visible_in_tree()
	_say("收起浮层：按关闭键 → 四个入口回来了 = %s" % str(back))
	if not back:
		_fail("按了关闭键浮层也没收起来")
		return false
	return true


## §3：语言开关按下去 —— locale 变了，屏上的字**当场**跟着变（没有重进这一屏）。
## 按完再按回来，免得把玩家的语言偏好留在英文上。
##
## 这里**不等帧**：setting_changed 是同步发出去的，所以「按完立刻读」读到的就是新文案。
## 中间插一帧的话，「立刻生效」这句话就退化成「一帧之后生效」了。
func _toggle_language() -> void:
	var switch: Button = _button(MenuLayout.KEY_LANGUAGE_SWITCH)
	if switch == null:
		return
	var title_before: String = _title_text()
	var entry_before: String = _entry_text(MenuLayout.KEY_NEW_RUN)
	switch.pressed.emit()
	_say("语言开关：按下去 → locale 变 %s，Logo「%s」→「%s」，入口「%s」→「%s」（同一帧，没有重进这一屏）" % [
		_settings.get_locale(), title_before, _title_text(),
		entry_before, _entry_text(MenuLayout.KEY_NEW_RUN)])


## 某颗入口此刻在屏上写的字。
func _entry_text(text_key: String) -> String:
	var button: Button = _button(text_key)
	return button.text if button != null else "（不在屏上）"


func _report_language() -> void:
	var switch: Button = _button(MenuLayout.KEY_LANGUAGE_SWITCH)
	if switch != null:
		switch.pressed.emit()
	_say("语言还原：再按一次 → locale %s；采集开始前的语言是 %s" % [
		_settings.get_locale(), _original_locale])
	if _settings.get_locale() != _original_locale:
		_settings.set_locale(_original_locale, false)


## PET-97 #7：设置说明那一格。量的是**跑起来的那条 Label** —— 单行要多少宽、实际排了几行、
## 可见几行（截断的话可见行数会小于排出行数），以及控件有没有被字体撑出 §2.4 的 rect。
func _report_help() -> void:
	for node: Node in TreeProbe.find_all(current_scene, "Label"):
		var label: Label = node
		if not label.position.is_equal_approx(MenuLayout.SETTINGS_HELP_RECT.position):
			continue
		var font: Font = label.get_theme_font(&"font")
		var font_size: int = label.get_theme_font_size(&"font_size")
		var single: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x
		_say("设置说明「%s」：rect %s（表列 %s），单行实宽 %.0f vs 内容区 %.0f → %d 行 / 可见 %d 行，行高 %.0f"
			% [label.text, str(label.size), str(MenuLayout.SETTINGS_HELP_RECT.size), single,
				MenuLayout.SETTINGS_HELP_RECT.size.x, label.get_line_count(),
				label.get_visible_line_count(), label.get_line_height()])
		return
	_say("致命：找不到设置说明那一条 Label（按 SETTINGS_HELP_RECT 的落点找）")


## §4 的实测：每一层按钮装饰的两个颜色都必须能在 MenuTheme 角色表里找到。
## 有一条对不上，就说明这一屏某处绕开了角色表自己取了色。
##
## 旧版查的是 ColorRect 的填充色 —— 屏④ 之后整屏底 / 纸背 / 浮层都改由 Theme 面板供给，
## 这一屏自己画出来的只剩按钮上那两笔装饰（ButtonMarks），于是查的对象换成它们。
func _report_marks() -> void:
	var known: Array[Color] = []
	for role: int in MenuTheme.Role.values():
		known.append(MenuTheme.color(role))
	var total: int = 0
	var unknown: int = 0
	for node: Node in TreeProbe.find_all(current_scene, "ButtonMarks"):
		var marks: ButtonMarks = node
		total += 1
		if not known.has(marks.focus_color) or not known.has(marks.highlight_color):
			unknown += 1
	_say("配色：%d 层按钮装饰，两个颜色全部来自 MenuTheme 的 %d 个角色 = %s（表外的 %d 层）" % [
		total, MenuTheme.role_count(), str(unknown == 0 and total > 0), unknown])
	_say("      屏上 ColorRect %d 块 —— 整屏底 / 纸背 / 浮层都是 Theme 面板，这一屏不再自己填色" % [
		TreeProbe.count_of(current_scene, "ColorRect")])


# ------------------------------------------------------------------ 工具

## 当前场景里文案为 tr(key) 的按钮。按**译文**找 —— 按钮上的字是 UiKit 翻好的。
func _button(text_key: String) -> Button:
	if current_scene == null:
		return null
	var wanted: String = TranslationServer.translate(text_key)
	for node: Node in TreeProbe.find_all(current_scene, "Button"):
		var button: Button = node
		if button.text == wanted:
			return button
	return null


## 浮层的关闭键。它是 IconButton：控件上**不显示文字**，文案只在 tooltip 与无障碍名上 —— 按 tooltip 找。
func _close_button() -> Button:
	if current_scene == null:
		return null
	var wanted: String = TranslationServer.translate(MenuLayout.KEY_CLOSE)
	for node: Node in TreeProbe.find_all(current_scene, "Button"):
		var button: Button = node
		if button.tooltip_text == wanted:
			return button
	return null


## Logo 那一行。按**落点**找（MenuLayout.LOGO_RECT 是版式契约），不按文案 —— 文案正是变量。
func _title_text() -> String:
	return _label_at(MenuLayout.LOGO_RECT.position)


## 「继续」下面那行原因。
func _hint_text() -> String:
	return _label_at(MenuLayout.REASON_RECT.position)


func _label_at(at: Vector2) -> String:
	if current_scene == null:
		return "（没有主菜单）"
	for node: Node in TreeProbe.find_all(current_scene, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(at):
			return label.text
	return "（没找到）"


## 窗口 ÷ 视口的整数倍率（960×540 → 1920×1080 即 2）。
func _window_scale() -> float:
	return float(DisplayServer.window_get_size().x) / root.get_visible_rect().size.x


# ------------------------------------------------------------------ 截图

func _capture(file_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# 等这一帧真的画完再取纹理，否则拿到的是上一帧（刚按的那一下还没画上去）。
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


func _say(line: String) -> void:
	_lines.append("[capture] " + line)


## 正常收尾：把攒下的实测数字一次打完。
func _finish() -> void:
	for line: String in _lines:
		print(line)
	quit(0)


## 致命退出。**必须先把已经说到的话打出来** —— 采集脚本静默退出的话，
## 跑的人只看到一个非零返回码，分不清是自检没过、还是根本没走到主菜单。
func _fail(message: String) -> void:
	_say("致命：" + message)
	for line: String in _lines:
		print(line)
	quit(1)
