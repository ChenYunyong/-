## main_menu_smoke.gd
## 职责：主菜单屏**装配之后**的验收 —— 表里的 rect 真的落到控件上、只有一颗金底、每颗按钮都挂了状态装饰、
##       「继续」跟着「有没有进行中的局」走、设置浮层开合与焦点去向、切语言不推动版面。
## 所属系统：tests
## 依赖：TreeProbe, MenuLayout, MenuTheme, ButtonMarks, ContractTheme, UiKit,
##       Settings / RunState（经 /root 取）
## 禁止：本文件不得按「开始新一局」/「继续」—— 那两颗按钮会把**真实的** GameFlow 换掉
##       （本文件挂的是单例本尊）。它们的去向合法性由 test_game_flow 的迁移表用例负责。
##
## 单元层的 test_menu_layout 量**表**（常量抄对没有），这里量**装配**（表有没有落到控件上）：
## UiKit.button 先按文案算尺寸、摆放时再改成表里的数，所以 G02 的「真实 rect 误差 ≤1、宽高不由
## 字体撑开」只有这一层验得到。语言开关一段必须真按下去（toggle_locale 唯一的调用方），按完按回去。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCENE_PATH: String = "res://scenes/main_menu.tscn"
const CSV_PATH: String = "res://assets/i18n/ui.csv"
## 屏上的按钮总数：四个入口 + 浮层里的语言开关 + 浮层关闭键。
const TOTAL_BUTTONS: int = 6
## 临时开的那一局用的种子。1 而不是 0（0 = SEED_UNSET）：这一局只为把「继续」的闸门打开，不跑任何模拟。
const GATE_SEED: int = 1
## G02：控件真实 rect 与 §2.4 的表之间的允许误差（逻辑 px）。
const RECT_TOLERANCE: float = 1.0

var _tree: SceneTree = null
var _settings: Node = null
var _run: Node = null
var _menu: Node = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("main_menu_smoke")
	_tree = tree
	_settings = tree.root.get_node_or_null(^"Settings")
	_run = tree.root.get_node_or_null(^"RunState")
	if not ctx.check(_settings != null and _run != null, "Settings / RunState 两个单例都在"):
		return
	# 「没有进行中的局」是启动时的真实状态（boot_screen 不再替玩家开局），不是摆出来的。
	ctx.check(not _run.is_active(), "前提：此刻内存里没有进行中的一局")
	await _mount(ctx)
	_check_controls(ctx)
	_check_rects(ctx)
	_check_continue_gate(ctx)
	_check_settings_panel(ctx)
	await _check_language_switch(ctx)
	await _unmount()


func _mount(ctx: RefCounted) -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if not ctx.check(packed != null, "主菜单场景可加载"):
		return
	_menu = packed.instantiate()
	if not ctx.check(_menu != null, "主菜单场景可实例化"):
		return
	ctx.check(_menu is Control, "根节点是 Control")
	ctx.check(_menu.theme != null and _menu.theme.default_font != null, "挂了带字体的主题")
	ctx.equal(_menu.get_child_count(), 0, "控件全靠代码建（场景文件里是空的）")
	_tree.root.add_child(_menu)
	ctx.check(_menu.get_child_count() > 0, "_ready() 建出了 %d 个控件" % _menu.get_child_count())


## 收尾摘屏并等一帧 —— 后面 scene_smoke 数 root 子节点数，只 queue_free() 不等的话数到的还是「Autoload + 这一屏」。
func _unmount() -> void:
	if _menu == null:
		return
	_menu.queue_free()
	await _tree.process_frame
	_menu = null


## 四颗入口按文案找得到、都接了处理器、都挂了状态装饰，且只有一颗金底强主动作。
func _check_controls(ctx: RefCounted) -> void:
	var primary: int = 0
	for key: String in MenuLayout.BUTTONS:
		var button: Button = _button_with(key)
		if not ctx.check(button != null, "入口「%s」在屏上" % key):
			continue
		ctx.check(not button.pressed.get_connections().is_empty(), "入口「%s」接了处理器" % key)
		ctx.check(_marks_of(button) != null, "入口「%s」挂了状态装饰层（悬停高光 / 焦点角标）" % key)
		if button.theme_type_variation == ContractTheme.TYPE_BUTTON_PAGE_PRIMARY:
			primary += 1
	ctx.equal(primary, 1, "四颗入口里只有一颗金底强主动作（数到 %d 颗）" % primary)
	ctx.check(TreeProbe.count_of(_menu, "ColorRect") == 0,
		"整屏底与纸背都是 Theme 面板，不再是自己填的 ColorRect（§3 四屏同一张纸）")
	ctx.equal(TreeProbe.count_of(_menu, "Button"), TOTAL_BUTTONS,
		"四个入口 + 浮层里的语言开关 + 浮层关闭键")


## §2.4 的表有没有真的落到控件上。G02 的两条：误差 ≤1，且宽高不由文案撑开。
func _check_rects(ctx: RefCounted) -> void:
	var rects: Array[Rect2] = MenuLayout.entry_rects()
	for index: int in MenuLayout.BUTTONS.size():
		_check_rect(ctx, _button_with(MenuLayout.BUTTONS[index]), rects[index],
			"入口「%s」" % MenuLayout.BUTTONS[index])
	_check_rect(ctx, _reason_label(), MenuLayout.REASON_RECT, "置灰原因行")
	_check_rect(ctx, _label_with(TreeProbe.find_all(_menu, "Label"), tr_key(MenuLayout.KEY_LOGO)),
		MenuLayout.LOGO_RECT, "Logo")
	# 「宽高不由字体撑开」：UiKit.button 先按文案算过一个尺寸（那是「声明」），摆上去时被表里的数
	# 覆盖 —— 两者不同才算真的过闸。N02 的「声明 48 实际 57」就是这一条的反面。
	var first: Button = _button_with(MenuLayout.KEY_NEW_RUN)
	if first != null:
		ctx.not_equal(first.size, Vector2(UiKit.button_width(first.text), UiKit.button_height()),
			"入口尺寸来自表，不是按文案算出来的")


## 一个控件的真实 rect 与 §2.4 的表逐个对。四个数分开报，错在哪一边一眼看得出。
func _check_rect(ctx: RefCounted, node: Control, rect: Rect2, what: String) -> void:
	if not ctx.check(node != null, "%s 在屏上（可量 rect）" % what):
		return
	ctx.near(node.position.x, rect.position.x, "%s 左 %.0f" % [what, rect.position.x], RECT_TOLERANCE)
	ctx.near(node.position.y, rect.position.y, "%s 顶 %.0f" % [what, rect.position.y], RECT_TOLERANCE)
	ctx.near(node.size.x, rect.size.x, "%s 宽 %.0f" % [what, rect.size.x], RECT_TOLERANCE)
	ctx.near(node.size.y, rect.size.y, "%s 高 %.0f" % [what, rect.size.y], RECT_TOLERANCE)


## 没有局 → 置灰 + 说清原因；有局 → 亮起 + 原因行清空（控件不撤，位置因此不跳）。后半段临时开一局再还原，全程不碰 GameFlow。
func _check_continue_gate(ctx: RefCounted) -> void:
	var button: Button = _button_with(MenuLayout.KEY_CONTINUE)
	var reason: Label = _reason_label()
	if not ctx.check(button != null and reason != null, "「继续」与它的原因行都在屏上"):
		return
	ctx.check(button.disabled, "没有进行中的局时「继续」是灰的")
	ctx.check(reason.visible and not reason.text.strip_edges().is_empty(),
		"灰着的时候说清了原因：「%s」" % reason.text)

	_run.start_run(GATE_SEED)
	ctx.check(_run.is_active(), "临时开了一局（这一小段结束时还原）")
	var spot: Vector2 = button.position
	_menu.call(&"_refresh_continue")
	ctx.check(not button.disabled, "有进行中的局时「继续」亮起")
	ctx.check(reason.text.strip_edges().is_empty(), "亮着的时候把原因写成空串")
	ctx.check(reason.visible, "清空 ≠ 收起控件：那一行还在（§2.4「该行留空且按钮位置不跳」）")
	ctx.check(button.position.is_equal_approx(spot), "有局 / 无局两种状态下「继续」不动")

	_run.end_run()
	_menu.call(&"_refresh_continue")
	ctx.check(button.disabled, "这一局结束后「继续」又灰回去")


## 浮层按「设置」打开、按关闭键收起 —— N04 三条：后方入口命中 0、关闭后焦点回设置、开关 384×56。
func _check_settings_panel(ctx: RefCounted) -> void:
	var panel: Control = _find_control("_settings_panel")
	var language: Button = _button_with(MenuLayout.KEY_LANGUAGE_SWITCH)
	var close: Button = _close_button()
	var entry: Button = _button_with(MenuLayout.KEY_SETTINGS)
	if not ctx.check(panel != null and language != null and close != null and entry != null,
			"浮层、语言开关、关闭键与「设置」入口都在屏上"):
		return
	ctx.check(not panel.visible, "浮层起初是收着的")
	entry.pressed.emit()
	ctx.check(panel.visible and language.is_visible_in_tree(), "按「设置」后浮层与语言开关都出现")
	_check_rect(ctx, language, MenuLayout.SETTINGS_TOGGLE_RECT, "语言开关")
	_check_rect(ctx, close, MenuLayout.SETTINGS_CLOSE_RECT, "浮层关闭键")
	for key: String in MenuLayout.BUTTONS:
		var button: Button = _button_with(key)
		ctx.check(button != null and not button.is_visible_in_tree(),
			"浮层打开时入口「%s」不可见 —— 后方命中 0（N04）" % key)
	ctx.check(language.has_focus(), "打开浮层时焦点交给语言开关（否则键盘无处可去）")
	close.pressed.emit()
	ctx.check(not panel.visible and not language.is_visible_in_tree(), "按关闭键后浮层收起")
	ctx.check(entry.has_focus(), "关闭后焦点回到「设置」（N04）")
	for key: String in MenuLayout.BUTTONS:
		var button: Button = _button_with(key)
		ctx.check(button != null and button.is_visible_in_tree(), "收起后入口「%s」回到屏上" % key)


## 验收要的那一条：按下去 locale 真的变了、界面上的字当场跟着变，而且**版面一个像素都不动**。
func _check_language_switch(ctx: RefCounted) -> void:
	var entry: Button = _button_with(MenuLayout.KEY_SETTINGS)
	var toggle: Button = _button_with(MenuLayout.KEY_LANGUAGE_SWITCH)
	var logo: Label = _label_with(TreeProbe.find_all(_menu, "Label"), tr_key(MenuLayout.KEY_LOGO))
	if not ctx.check(entry != null and toggle != null and logo != null,
			"「设置」、语言开关与 Logo 都在屏上"):
		return
	# 玩家是先在浮层里看到语言开关才按得着它 —— 这一段就在浮层打开的状态下走。
	entry.pressed.emit()
	ctx.check(toggle.is_visible_in_tree(), "语言开关在打开的浮层里看得见")

	var original: String = _settings.get_locale()
	ctx.check(not original.is_empty(), "切换前记下了当前语言：「%s」" % original)
	var before: Array[Rect2] = _all_rects()

	toggle.pressed.emit()
	var toggled: String = _settings.get_locale()
	ctx.check(toggled != original, "按下语言开关，locale 真的变了：%s → %s" % [original, toggled])
	ctx.check(_csv_column(toggled) > 0, "切到的是语言表里有列的语言：%s" % toggled)
	ctx.equal(TranslationServer.get_locale(), toggled, "TranslationServer 跟着换")
	# 「立刻生效」：界面上的字必须等于语言表里那一格，而不是「看起来像英文」。
	ctx.equal(logo.text, _csv_row(MenuLayout.KEY_LOGO, toggled),
		"[%s] Logo 当场变成语言表里的那一格" % toggled)
	ctx.equal(toggle.text, _csv_row(MenuLayout.KEY_LANGUAGE_SWITCH, toggled), "语言开关自己的文案也跟着刷")
	# 关闭键的文案只在 tooltip 上（IconButton 不显示文字），第一版采集切成英文后它仍是中文、浮层关不掉。
	ctx.equal(_close_button().tooltip_text, _csv_row(MenuLayout.KEY_CLOSE, toggled),
		"关闭键的 tooltip 也跟着刷")
	# N04「中英文切换无布局跳动」：每个控件的 rect 逐个不变。默认 rect 由表给死，
	# 若哪一处又按文案算宽度（旧版那颗语言开关就是），这一条会当场红。
	ctx.equal(_all_rects(), before, "N04 切语言不推动任何控件（rect 逐个不变）")

	# 还原：再按一次转回原语言（toggle 只在两个受支持语言之间来回；首次运行时原语言
	# 可能就是其中之一）。转不回来时用 set_locale(persist=false) 直接设回去 —— 用例
	# 不该把语言留在别人身上，也不该再往玩家偏好里写第二笔。
	toggle.pressed.emit()
	if _settings.get_locale() != original:
		_settings.set_locale(original, false)
	ctx.equal(_settings.get_locale(), original, "用例收尾时语言已还原为 %s" % original)
	_close_button().pressed.emit()
	ctx.check(not _find_control("_settings_panel").visible, "设置浮层盖回去")


# ------------------------------------------------------------------ 工具

func _button_with(text_key: String) -> Button:
	var wanted: String = tr_key(text_key)
	for node: Node in TreeProbe.find_all(_menu, "Button"):
		var button: Button = node
		if button.text == wanted:
			return button
	return null


## 浮层的关闭键。它是 IconButton：控件上**不显示文字**，文案只在 tooltip 与无障碍名上 —— 按 tooltip 找。
func _close_button() -> Button:
	var wanted: String = tr_key(MenuLayout.KEY_CLOSE)
	for node: Node in TreeProbe.find_all(_menu, "Button"):
		var button: Button = node
		if button.tooltip_text == wanted:
			return button
	return null


## 「继续」下面那行原因。按**落点**找：它是空文案的 Label，按文字找会在置灰时先撞上别的。
func _reason_label() -> Label:
	for node: Node in TreeProbe.find_all(_menu, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(MenuLayout.REASON_RECT.position) \
				and label.size.is_equal_approx(MenuLayout.REASON_RECT.size):
			return label
	return null


## 宿主的装饰层（ButtonMarks 挂在按钮下）。找不到说明这颗按钮没有那两笔状态。
func _marks_of(button: Button) -> ButtonMarks:
	for child: Node in button.get_children():
		if child is ButtonMarks:
			return child
	return null


## 屏上每个控件当前的矩形。切语言前后各取一次逐个比 —— 「版面没跳」只有这么量才作数。
func _all_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for node: Node in TreeProbe.descendants(_menu):
		if node is Control:
			rects.append((node as Control).get_rect())
	return rects


func _label_with(labels: Array[Node], text: String) -> Label:
	for node: Node in labels:
		var label: Label = node
		if label.text == text:
			return label
	return null


## 按**变量名**取屏上的私有控件。用 get() 而不是加一个公开 getter：那是内部装配，为测试开 getter 更贵。
func _find_control(variable: String) -> Control:
	return _menu.get(variable) as Control


## 按 key 取译文 —— 与 Node.tr() 同一条路径（本文件是 RefCounted，没有 tr()）。
func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


## 语言表里某个语言的列号（0 = keys 那列）。从表头**现读**而不是在这里再抄一份语言清单 ——
## 抄一份就等于把「支持哪些语言」写了两遍。
func _csv_column(locale: String) -> int:
	return Array(_csv_lines()[0].strip_edges().split(",")).find(locale)


## 从语言表里读一格的正确值。用例拿它跟**界面上实际的字**比，
## 而不是跟自己刚 tr() 出来的字比 —— 后者是循环论证。
func _csv_row(key: String, locale: String) -> String:
	var column: int = _csv_column(locale)
	if column < 1:
		return ""
	for line: String in _csv_lines():
		var fields: PackedStringArray = line.split("\",\"")
		if fields.size() == 3 and fields[0].trim_prefix("\"") == key:
			return fields[column].trim_suffix("\"")
	return ""


func _csv_lines() -> PackedStringArray:
	return FileAccess.get_file_as_string(CSV_PATH).split("\n")
