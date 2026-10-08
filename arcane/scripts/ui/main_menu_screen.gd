## main_menu_screen.gd
## 职责：主菜单屏 —— Logo + 纸背上的四个入口（开始新一局 / 继续 / 设置 / 退出）+ 同屏的设置浮层。
## 所属系统：ui
## 依赖：MenuLayout, MenuTheme, ButtonMarks, UiKit, ContractTheme, ContractScreenTheme,
##       RunState, GameFlow, Settings
## 禁止：本文件不得自己换场景（R3）；不得出现裸色值（纸背 / 浮层 / 字 / 按钮一律走 Theme 变体，
##       自己画的两笔状态装饰走 MenuTheme 角色表）；不得判断「现在是哪种语言」——
##       语言判断只在 Settings.toggle_locale() 里（06 §11），本文件不得出现 "en" / "zh_CN"
##       这类字面语言名；不得读任何存档（还没有存档）。
##
## PET-93 屏④（docs/14 §2.4）：入口 312×56、间距按表；纸背与屏①②③ 统一走
## ContractTheme.TYPE_PAGE_BAND（§3「羊皮纸面 GOLD_200 四处统一」）；设置从「屏底那条常驻板」
## 改成同屏浮层（SETTINGS_PANEL），打开时**隐藏后方四个入口**（N04「后方入口命中 0」）。
##
## 「继续」为什么会在启动时是灰的：本工程**没有存档**，RunState 的「这一局」只活在内存里，
## 而启动时没有任何一局在内存里 —— `is_active()` 为 false。灰不是「功能没做」，
## 而是此刻的真实状态，所以那行字如实说「没有进行中的一局」。它**常驻在纸内**
## （§2.4「无局时原因永远可见，有局时该行留空且按钮位置不跳」）—— 有局时清空文案而不是收起控件，
## 四个入口的纵向位置因此在两种状态下完全一致。
##
## 设置浮层里只有语言一项，且**只有一颗按钮**：语言判断是 toggle_locale() 的事，本屏只转发一次点击。

extends Control

var _continue_button: Button = null
var _reason_label: Label = null
var _settings_panel: Control = null
var _language_button: Button = null
## 浮层关闭键。**不进 _texts**：它屏上不显示文字，走 _texts 那条会把字画到键面上。
var _close_button: Button = null
## 浮层打开时要藏起来的后方入口（§2.4「打开时隐藏后方入口」）。
var _entries: Array[Button] = []
## 随语言变化的文字：{node, key}。切语言时按 key 重刷 —— UiKit 建控件时给的是**当时那种语言的
## 成品**，翻译入口再也找不到 key（06 §11：中文原文即 key），只赋一次的话切完还是旧语言。
var _texts: Array[Dictionary] = []


func _ready() -> void:
	# 全屏底与屏①②③ 同一支变体：不铺满这一层，纸外露的就是引擎默认灰（G06）。
	add_child(UiKit.panel(ContractTheme.TYPE_BACKDROP, Rect2(Vector2.ZERO, MenuLayout.SCREEN)))
	_build_logo()
	add_child(UiKit.panel(ContractTheme.TYPE_PAGE_BAND, MenuLayout.PAPER_RECT))
	_build_entries()
	_build_settings()
	Settings.setting_changed.connect(_on_setting_changed)
	_apply_locale()
	# 启动时给一个确定的焦点起点：没有焦点时方向键什么也不做（N04 的键盘那一条）。
	_focus_entry(MenuLayout.DEFAULT_ENTRY)


# ------------------------------------------------------------------ 装配

## Logo：整屏唯一一处比屏标题还大的字号（§2.4 的 36/48）。
func _build_logo() -> void:
	var label: Label = _add_pinned_label(self, tr(MenuLayout.KEY_LOGO), MenuLayout.LOGO_RECT,
		ContractScreenTheme.TYPE_LABEL_LOGO)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texts.append({"node": label, "key": MenuLayout.KEY_LOGO})


## 按 §2.4 的表挂一行字。**rect 说了算**，而且必须**先进树再定量**。
##
## 控件的高度下限是它那一档字体的行盒，而主题要等控件进树才解析得到：建的时候量到的是引擎
## 默认那档（16px，行盒 23），挂上去之后主题才换成 12px（行盒 17）。Godot 只把尺寸往**大**顶、
## 从不自己缩回来，于是 (324,280,312,20) 那一格会停在 23 高 —— 声明 20、实际 23，
## 正是 G02 拦的「宽高不能由字体撑开」，也是 N02 那条「声明 48 实际 57」的同一种病。
## 进树后重量一次，值就是主题解析之后的行盒（标题那一档 24px 的行盒是 33，比表里的 32 多 1，
## 落在 G02 的 ≤1 里；剩下四行都严丝合缝）。
func _add_pinned_label(parent: Node, text: String, rect: Rect2, variation: StringName) -> Label:
	var label: Label = UiKit.label(text, rect, variation)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
	label.size = rect.size
	return label


## 纸背上的四个入口 + 「继续」下面那行原因。顺序与落点都由 MenuLayout 定，这里只按同一份表摆。
##
## 四颗里只有「开始新一局」拿金色整面填充（§2.4 原话），其余三颗走 20/28 的深色入口变体。
func _build_entries() -> void:
	var handlers: Array[Callable] = [_on_new_run, _on_continue, _on_settings, _on_quit]
	var rects: Array[Rect2] = MenuLayout.entry_rects()
	for index: int in MenuLayout.BUTTONS.size():
		var key: String = MenuLayout.BUTTONS[index]
		var variation: StringName = ContractScreenTheme.TYPE_BUTTON_DARK_ENTRY
		if key == MenuLayout.KEY_PRIMARY:
			variation = ContractTheme.TYPE_BUTTON_PAGE_PRIMARY
		var button: Button = _add_button(key, rects[index], variation, handlers[index])
		_entries.append(button)
		if key == MenuLayout.KEY_CONTINUE:
			_continue_button = button
	# 「继续」的状态说明。**建出来就一直挂着**，无局时写原因、有局时写空串（§2.4 原话）。
	_reason_label = _add_pinned_label(self, "", MenuLayout.REASON_RECT,
		ContractScreenTheme.TYPE_LABEL_PAGE_CAPTION)


## 一颗带文字的按钮：矩形由表给死（G02 第三条「宽高不能由字体撑开」），
## 再挂上 §2.4 的两笔状态装饰（悬停高光 / 焦点角标）。
func _add_button(key: String, rect: Rect2, variation: StringName, handler: Callable) -> Button:
	var button: Button = UiKit.button(key, variation, handler)
	button.position = rect.position
	button.size = rect.size
	add_child(button)
	_texts.append({"node": button, "key": key})
	ButtonMarks.attach(button, MenuTheme.color(MenuTheme.Role.FOCUS),
		MenuTheme.color(MenuTheme.Role.HIGHLIGHT))
	return button


## 设置浮层：一块深面板 + 标题 + 关闭键 + 语言那一行 + 开关 + 说明。
## 整组收在一个 Control 里，于是「打开设置」就是切这一个节点的 visible，不必逐个控件开关。
func _build_settings() -> void:
	_settings_panel = Control.new()
	_settings_panel.position = Vector2.ZERO
	_settings_panel.size = MenuLayout.SCREEN
	add_child(_settings_panel)

	_settings_panel.add_child(UiKit.panel(ContractScreenTheme.TYPE_PANEL_DARK_SILVER,
		MenuLayout.SETTINGS_PANEL))
	_add_panel_label(MenuLayout.KEY_SETTINGS, MenuLayout.SETTINGS_TITLE_RECT, &"")
	_add_panel_label(MenuLayout.KEY_LANGUAGE_LABEL, MenuLayout.SETTINGS_LANGUAGE_RECT,
		ContractTheme.TYPE_LABEL_BODY)
	_language_button = _add_panel_button(MenuLayout.KEY_LANGUAGE_SWITCH, MenuLayout.SETTINGS_TOGGLE_RECT,
		ContractScreenTheme.TYPE_BUTTON_DARK_ENTRY, _on_language)
	var help: Label = UiKit.wrapped_label(tr(MenuLayout.KEY_SETTINGS_HELP), MenuLayout.SETTINGS_HELP_RECT,
		ContractTheme.TYPE_LABEL_BODY_MUTED)
	help.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_settings_panel.add_child(help)
	_texts.append({"node": help, "key": MenuLayout.KEY_SETTINGS_HELP})
	# 关闭键**最后加**：同层里后加的在上，这颗才压在浮层底之上收得到点击（与详情浮层同一条）。
	_close_button = UiKit.icon_button(ContractTheme.TYPE_BUTTON_PAGE_ICON, IconPainter.Icon.CLOSE,
		MenuLayout.CLOSE_ICON_RADIUS, MenuLayout.KEY_CLOSE, _on_close_settings)
	_close_button.position = MenuLayout.SETTINGS_CLOSE_RECT.position
	_close_button.size = MenuLayout.SETTINGS_CLOSE_RECT.size
	_settings_panel.add_child(_close_button)
	ButtonMarks.attach(_close_button, MenuTheme.color(MenuTheme.Role.FOCUS),
		MenuTheme.color(MenuTheme.Role.HIGHLIGHT))
	_settings_panel.visible = false


## 浮层里的一行字。整组随语言变化，故一律进 _texts。
func _add_panel_label(key: String, rect: Rect2, variation: StringName) -> Label:
	var label: Label = _add_pinned_label(_settings_panel, tr(key), rect, variation)
	_texts.append({"node": label, "key": key})
	return label


## 浮层里的一颗按钮。与入口同一条：矩形由表给死。
func _add_panel_button(key: String, rect: Rect2, variation: StringName, handler: Callable) -> Button:
	var button: Button = UiKit.button(key, variation, handler)
	button.position = rect.position
	button.size = rect.size
	_settings_panel.add_child(button)
	_texts.append({"node": button, "key": key})
	ButtonMarks.attach(button, MenuTheme.color(MenuTheme.Role.FOCUS),
		MenuTheme.color(MenuTheme.Role.HIGHLIGHT))
	return button


# ------------------------------------------------------------------ 四个入口

## 开始新一局：**先开局再换屏** —— 换到编辑器时那一局必须已经存在，否则编辑器读的是空气。
func _on_new_run() -> void:
	RunState.start_run()
	GameFlow.change_state(GameFlow.GameState.EDITOR)


## 继续：回到这一局的路线图（不是编辑器 —— 「继续」要接着上次走到的地方走）。
## 按钮在 is_active() 为 false 时是 disabled 的，这一行到不了。
func _on_continue() -> void:
	GameFlow.change_state(GameFlow.GameState.MAP)


## 设置：开浮层。开的时候把后方四个入口藏起来（N04「后方入口命中 0」），
## 并把焦点交给浮层里那颗开关 —— 藏起来的控件是拿不住焦点的，让它留在后面等于焦点凭空消失。
func _on_settings() -> void:
	_set_settings_open(true)


## 关闭键：收起浮层，焦点交回「设置」入口（N04「关闭后焦点回设置」）。
func _on_close_settings() -> void:
	_set_settings_open(false)


## 退出：直接关掉本进程。不走 GameFlow —— 它不是一次状态迁移（状态机没有 EXIT 态）。
func _on_quit() -> void:
	get_tree().quit()


## 语言开关：只转发给 Settings。切换后 setting_changed 回来把文字重刷一遍（见 _on_setting_changed）。
func _on_language() -> void:
	Settings.toggle_locale()


## 开 / 收浮层。收起时后方入口要还原成**它们原本的可用性**，故逐个按 RunState 重刷一次，
## 而不是一律 visible = true（那会把置灰的「继续」点亮）。
func _set_settings_open(open: bool) -> void:
	_settings_panel.visible = open
	for entry: Button in _entries:
		entry.visible = not open
	if open:
		_language_button.grab_focus()
	else:
		_focus_entry(MenuLayout.KEY_SETTINGS)
	_refresh_continue()


## 把焦点交给某一颗入口。按**文案 key** 找 —— 入口的落点是变量，key 才是它的身份。
func _focus_entry(key: String) -> void:
	for entry: Button in _entries:
		if entry.text == TranslationServer.translate(key) and not entry.disabled:
			entry.grab_focus()
			return


# ------------------------------------------------------------------ 刷新

## 设置变化 → 与文案有关的是语言。判的是**设置项的 key**，不是「现在是哪种语言」：
## 分辨率 / 音量改了不碰文案，语言改了才重刷。
func _on_setting_changed(key: StringName) -> void:
	if key == Settings.KEY_LOCALE:
		_apply_locale()


## 把随语言变化的文字重新按 key 查表落到控件上。
## _ready() 与语言切换各跑一次；「切换后立刻生效」就是靠这一条。
##
## 这里**不再重摆任何控件**：§2.4 的每个 rect 都由表给死，文案长短变化因此不会推动版面
## （N04「中英文切换无布局跳动」）。旧版那颗按文案算宽的语言开关正是跳动的来源。
func _apply_locale() -> void:
	for entry: Dictionary in _texts:
		var node: Control = entry["node"]
		var text: String = TranslationServer.translate(String(entry["key"]))
		if node is Button:
			(node as Button).text = text
		else:
			(node as Label).text = text
	# 关闭键不在 _texts 里（见 _close_button 那条），但它的 tooltip 与无障碍名同样是**给人看的文案**，
	# 一样要跟着语言走 —— 漏掉它，切成英文之后悬停在叉上弹出来的还是中文。
	if _close_button != null:
		var close_text: String = TranslationServer.translate(MenuLayout.KEY_CLOSE)
		_close_button.tooltip_text = close_text
		_close_button.accessibility_name = close_text
	_refresh_continue()


## 「继续」的可用性 = 内存里真的有这一局。灰掉的同时必须在**同一行**说明原因 ——
## 一颗灰按钮不解释，读起来就是「坏了」。有局时那是空串，不是收起控件（位置不跳）。
func _refresh_continue() -> void:
	var runnable: bool = RunState.is_active()
	_continue_button.disabled = not runnable
	_reason_label.text = "" if runnable else tr(MenuLayout.KEY_NO_RUN)
