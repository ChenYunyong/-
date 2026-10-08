## main_menu_screen.gd
## 职责：主菜单屏 —— 标题 + 四个入口（开始新一局 / 继续 / 设置 / 退出），设置面板里放语言开关。
## 所属系统：ui
## 依赖：MenuLayout, MenuTheme, UiKit, ArcaneTheme, RunState, GameFlow, Settings
## 禁止：本文件不得自己换场景（R3）；不得出现裸色值（整屏底与两块板经 MenuTheme 角色表）；
##       不得判断「现在是哪种语言」—— 语言判断只在 Settings.toggle_locale() 里（06 §11），
##       本文件不得出现 "en" / "zh_CN" 这类字面语言名；不得读任何存档（还没有存档）。
##
## PET-90：这是四屏里最后补上的一块（主菜单）。启动落点从编辑器改到本屏，见 boot_screen.gd。
##
## 「继续」为什么会在启动时是灰的：本工程**没有存档**，RunState 的「这一局」只活在内存里，
## 而启动时没有任何一局在内存里 —— `is_active()` 为 false。灰不是「功能没做」，
## 而是此刻的真实状态，所以旁边那行字要如实说「没有进行中的一局」，
## 而不是像旧工程那样用一格提示面板宣称「尚未实现」。
##
## 设置面板按一下才出现（不新开屏 —— 屏间转场本轮不做）。面板里只有语言一项，
## 且**只有一颗按钮**：语言判断是 toggle_locale() 的事，本屏只转发一次点击。

extends Control

## 标题文案的 key。写成常量是为了切语言时能按 key 重刷（见 _apply_locale()）。
const KEY_TITLE: String = "奥术蓝图"
## 设置面板里那一行：说明右边那颗按钮是干什么的。
const KEY_LANGUAGE_LABEL: String = "语言"
## 语言开关自己的文案 = 两个选项并列，点一下就换过去（本屏不显示「当前是哪个」，那不是本屏该判断的）。
const KEY_LANGUAGE_SWITCH: String = "中文 / English"
## 「继续」置灰时旁边那行字。
const KEY_NO_RUN: String = "没有进行中的一局"

var _continue_button: Button = null
var _continue_hint: Label = null
var _settings_panel: Control = null
var _language_button: Button = null
## 随语言变化的文字：{node, key}。切语言时按 key 重刷 —— UiKit 建控件时给的是**当时那种语言的
## 成品**，翻译入口再也找不到 key（06 §11：中文原文即 key），只赋一次的话切完还是旧语言。
var _texts: Array[Dictionary] = []


func _ready() -> void:
	_add_plate(MenuTheme.Role.BACKDROP, Rect2(Vector2.ZERO, MenuLayout.SCREEN))
	_add_label(KEY_TITLE, MenuLayout.TITLE_RECT, ArcaneTheme.TYPE_LABEL_TITLE, true)
	_add_plate(MenuTheme.Role.MENU_PLATE, MenuLayout.PLATE_RECT)
	_build_buttons()
	_build_settings()
	Settings.setting_changed.connect(_on_setting_changed)
	_apply_locale()


# ------------------------------------------------------------------ 装配

## 一块**这一屏自己画**的板（整屏底 / 入口板 / 设置板）。颜色只能经 MenuTheme 角色表取（PET-90 §4）。
func _add_plate(role: MenuTheme.Role, rect: Rect2) -> ColorRect:
	var plate: ColorRect = ColorRect.new()
	plate.color = MenuTheme.color(role)
	plate.position = rect.position
	plate.size = rect.size
	add_child(plate)
	return plate


## 一个随语言变化的 Label。centered = true 时文字在矩形里居中（标题要居中，说明文字左对齐）。
func _add_label(key: String, rect: Rect2, variation: StringName, centered: bool = false) -> Label:
	var node: Label = UiKit.label(tr(key), rect, variation)
	if centered:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(node)
	_texts.append({"node": node, "key": key})
	return node


## 四个入口。顺序与文案都由 MenuLayout.BUTTONS 定，这里只按同一份表摆。
func _build_buttons() -> void:
	var handlers: Array[Callable] = [_on_new_run, _on_continue, _on_settings, _on_quit]
	var rects: Array[Rect2] = MenuLayout.button_rects()
	for index: int in MenuLayout.BUTTONS.size():
		var key: String = MenuLayout.BUTTONS[index]
		var variation: StringName = ArcaneTheme.TYPE_BUTTON_SECONDARY
		if key == MenuLayout.KEY_PRIMARY:
			variation = ArcaneTheme.TYPE_BUTTON_PRIMARY
		var button: Button = UiKit.button(key, variation, handlers[index])
		button.position = rects[index].position
		button.size = rects[index].size
		add_child(button)
		_texts.append({"node": button, "key": key})
		if key == MenuLayout.KEY_CONTINUE:
			_continue_button = button
	_continue_hint = UiKit.wrapped_label("", MenuLayout.CONTINUE_HINT_RECT,
		ArcaneTheme.TYPE_LABEL_SECONDARY)
	_continue_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_continue_hint)


## 设置面板：一块底板 + 一行说明 + 一颗语言开关。整组收在一个 Control 里，
## 于是「按一下设置」就是切这一个节点的 visible，不必逐个控件开关。
func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.position = Vector2.ZERO
	_settings_panel.size = MenuLayout.SCREEN
	add_child(_settings_panel)

	var plate: ColorRect = ColorRect.new()
	plate.color = MenuTheme.color(MenuTheme.Role.SETTINGS_PLATE)
	plate.position = MenuLayout.SETTINGS_RECT.position
	plate.size = MenuLayout.SETTINGS_RECT.size
	_settings_panel.add_child(plate)

	var label: Label = UiKit.label(tr(KEY_LANGUAGE_LABEL), MenuLayout.SETTINGS_LABEL_RECT,
		ArcaneTheme.TYPE_LABEL_SECONDARY)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settings_panel.add_child(label)
	_texts.append({"node": label, "key": KEY_LANGUAGE_LABEL})

	_language_button = UiKit.button(KEY_LANGUAGE_SWITCH, ArcaneTheme.TYPE_BUTTON_SECONDARY,
		_on_language)
	_settings_panel.add_child(_language_button)
	_texts.append({"node": _language_button, "key": KEY_LANGUAGE_SWITCH})
	_relayout()
	_settings_panel.visible = false


## 右对齐的控件要重摆：语言开关的宽度是按文案算的，文案换了宽度就变了。
## 按钮宽度由 UiKit 跟着 text 走，位置不跟着走就会左出边或右出边。
func _relayout() -> void:
	UiKit.place_right(_language_button, MenuLayout.SETTINGS_RECT,
		MenuLayout.SETTINGS_RECT.end.x - MenuLayout.PADDING)


# ------------------------------------------------------------------ 四个入口

## 开始新一局：**先开局再换屏** —— 换到编辑器时那一局必须已经存在，否则编辑器读的是空气。
func _on_new_run() -> void:
	RunState.start_run()
	GameFlow.change_state(GameFlow.GameState.EDITOR)


## 继续：回到这一局的路线图（不是编辑器 —— 「继续」要接着上次走到的地方走）。
## 按钮在 is_active() 为 false 时是 disabled 的，这一行到不了。
func _on_continue() -> void:
	GameFlow.change_state(GameFlow.GameState.MAP)


func _on_settings() -> void:
	_settings_panel.visible = not _settings_panel.visible


## 退出：直接关掉本进程。不走 GameFlow —— 它不是一次状态迁移（状态机没有 EXIT 态）。
func _on_quit() -> void:
	get_tree().quit()


## 语言开关：只转发给 Settings。切换后 setting_changed 回来把文字重刷一遍（见 _on_setting_changed）。
func _on_language() -> void:
	Settings.toggle_locale()


# ------------------------------------------------------------------ 刷新

## 设置变化 → 与文案有关的是语言。判的是**设置项的 key**，不是「现在是哪种语言」：
## 分辨率 / 音量改了不碰文案，语言改了才重刷。
func _on_setting_changed(key: StringName) -> void:
	if key == Settings.KEY_LOCALE:
		_apply_locale()


## 把随语言变化的文字重新按 key 查表落到控件上，并重摆右对齐的控件。
## _ready() 与语言切换各跑一次；「切换后立刻生效」就是靠这一条。
func _apply_locale() -> void:
	for entry: Dictionary in _texts:
		var node: Control = entry["node"]
		var text: String = TranslationServer.translate(String(entry["key"]))
		if node is Button:
			(node as Button).text = text
		else:
			(node as Label).text = text
	_relayout()
	_refresh_continue()


## 「继续」的可用性 = 内存里真的有这一局。灰掉的同时必须在旁边说明原因 ——
## 一颗灰按钮不解释，读起来就是「坏了」（旧工程为此专门开了一个提示面板）。
func _refresh_continue() -> void:
	var runnable: bool = RunState.is_active()
	_continue_button.disabled = not runnable
	_continue_hint.visible = not runnable
	_continue_hint.text = tr(KEY_NO_RUN) if not runnable else ""
