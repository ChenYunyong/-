## main_menu_smoke.gd
## 职责：主菜单屏的验收 —— 四个入口真的建出来了、「继续」跟着「有没有进行中的局」走、语言开关切完
##       界面文案当场变、配色表每个角色都登记过、四个入口排得进那块板。
## 所属系统：tests
## 依赖：TreeProbe, MenuLayout, MenuTheme, Settings / RunState（经 /root 取）
## 禁止：本文件不得按「开始新一局」/「继续」—— 那两颗按钮会把**真实的** GameFlow 换掉
##       （本文件挂的是单例本尊）。它们的去向合法性由 test_game_flow 的迁移表用例负责。
##
## 放在集成层而不是单元层：本用例必须把屏幕真的挂进树（_ready() 才会跑、控件才建得出来），
## 与 map_view_smoke 同一条理由。但它**不换 GameFlow 的状态**，所以排在 scene_smoke 之前即可。
##
## 语言开关那一段**必须**按下去：验收要的是「切换后 locale 真的变了」，而这是
## toggle_locale() 唯一的调用方。按下会有一次落盘（toggle_locale 的既定行为），
## 所以用例结束时按回去 —— 一去一回，玩家偏好文件最后仍是原值。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCENE_PATH: String = "res://scenes/main_menu.tscn"
const CSV_PATH: String = "res://assets/i18n/ui.csv"
## 语言开关自己的文案 key（两个选项并列，点一下就换过去）。
const KEY_LANGUAGE_SWITCH: String = "中文 / English"
## 板上四个入口 + 设置面板里那颗语言开关。
const TOTAL_BUTTONS: int = 5
## 临时开的那一局用的种子。1 而不是 0（0 = SEED_UNSET）：这一局只为把「继续」的闸门打开，
## 不跑任何模拟，所以取什么值都行，但别取那个当哨兵用的值。
const GATE_SEED: int = 1

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
	_check_theme_table(ctx)
	_check_layout(ctx)
	# 「没有进行中的局」是启动时的真实状态（boot_screen 不再替玩家开局），不是摆出来的。
	ctx.check(not _run.is_active(), "前提：此刻内存里没有进行中的一局")
	await _mount(ctx)
	_check_controls(ctx)
	_check_continue_gate(ctx)
	_check_settings_panel(ctx)
	await _check_language_switch(ctx)
	await _unmount()


# ------------------------------------------------------------------ 静态表

## 每个角色都查得到色。反向对照：role_count() > 0 —— 表被清空时前一条会变成空真。
func _check_theme_table(ctx: RefCounted) -> void:
	ctx.check(MenuTheme.role_count() > 0, "配色表登记了 %d 个角色" % MenuTheme.role_count())
	for role: int in MenuTheme.Role.values():
		ctx.check(MenuTheme.ROLE_TOKEN.has(role), "角色 %d 在表里" % role)
		ctx.check(MenuTheme.token_of(role) != MenuTheme.FALLBACK_TOKEN,
			"角色 %d 用的是它自己的 Token，不是兜底色" % role)
	ctx.equal(MenuTheme.role_count(), MenuTheme.Role.values().size(), "角色数与枚举项数一致")


## 四个入口要排得进那块板，且不许互相压。几何全部取自 MenuLayout（真机上跑的就是这组数）。
func _check_layout(ctx: RefCounted) -> void:
	var rects: Array[Rect2] = MenuLayout.button_rects()
	ctx.equal(rects.size(), 4, "四个入口各有一个矩形")
	var plate: Rect2 = MenuLayout.PLATE_RECT
	var previous_bottom: float = -1.0
	for index: int in rects.size():
		var rect: Rect2 = rects[index]
		ctx.check(plate.encloses(rect), "第 %d 颗入口在板内" % index)
		ctx.check(rect.position.y >= previous_bottom, "第 %d 颗入口不与上一颗重叠" % index)
		previous_bottom = rect.end.y
	ctx.near(previous_bottom, plate.end.y - MenuLayout.PADDING, "最后一颗的底边正好留出内边距")
	ctx.check(MenuLayout.CONTINUE_HINT_RECT.position.x >= plate.end.x,
		"置灰原因落在板右侧、不压在按钮上")
	ctx.check(MenuLayout.CONTINUE_HINT_RECT.end.x <= MenuLayout.SCREEN.x - MenuLayout.MARGIN,
		"置灰原因没有出安全边")
	ctx.near(MenuLayout.CONTINUE_HINT_RECT.position.y, rects[1].position.y,
		"置灰原因与「继续」同一行")


# ------------------------------------------------------------------ 装配

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


## 收尾把屏幕摘下来，并等一帧 —— 后面 scene_smoke 会数 root 的子节点数，
## 只 queue_free() 不等的话它数到的还是「Autoload + 这一屏」（与 map_view_smoke 同一条）。
func _unmount() -> void:
	if _menu == null:
		return
	_menu.queue_free()
	await _tree.process_frame
	_menu = null


## 四颗入口按文案找得到，且「开始新一局」是板上唯一那颗强主动作。
func _check_controls(ctx: RefCounted) -> void:
	ctx.check(TreeProbe.count_of(_menu, "ColorRect") >= 2, "整屏底与入口板都画出来了")
	var labels: Array[Node] = TreeProbe.find_all(_menu, "Label")
	ctx.check(_label_with(labels, tr_key("奥术蓝图")) != null, "标题在屏上")
	ctx.equal(TreeProbe.count_of(_menu, "Button"), TOTAL_BUTTONS,
		"四个入口 + 一颗语言开关（设置面板里的那颗也在树里）")
	var primary: int = 0
	for key: String in MenuLayout.BUTTONS:
		var button: Button = _button_with(key)
		if not ctx.check(button != null, "入口「%s」在屏上" % key):
			continue
		ctx.check(not button.pressed.get_connections().is_empty(), "入口「%s」接了处理器" % key)
		if button.theme_type_variation == ArcaneTheme.TYPE_BUTTON_PRIMARY:
			primary += 1
	ctx.equal(primary, 1, "板上只有一个强主动作（数到 %d 个）" % primary)


# ------------------------------------------------------------------ 「继续」的闸门

## 没有进行中的局 → 置灰 + 说明原因；有 → 亮起 + 说明收走。
## 后半段临时开一局再把状态还原，全程不碰 GameFlow（按下去才会换场景）。
func _check_continue_gate(ctx: RefCounted) -> void:
	var button: Button = _button_with(MenuLayout.KEY_CONTINUE)
	var hint: Label = _hint_label()
	if not ctx.check(button != null and hint != null, "「继续」与它的说明都在屏上"):
		return
	ctx.check(button.disabled, "没有进行中的局时「继续」是灰的")
	ctx.check(hint.visible and not hint.text.strip_edges().is_empty(),
		"灰着的时候说清了原因：「%s」" % hint.text)

	_run.start_run(GATE_SEED)
	ctx.check(_run.is_active(), "临时开了一局（这一小段结束时还原）")
	_menu.call(&"_refresh_continue")
	ctx.check(not button.disabled, "有进行中的局时「继续」亮起")
	ctx.check(not hint.visible, "亮着的时候把原因收走")

	_run.end_run()
	_menu.call(&"_refresh_continue")
	ctx.check(button.disabled, "这一局结束后「继续」又灰回去")


# ------------------------------------------------------------------ 设置面板

## 面板按一下才出现 —— 面板里那几个控件一直都在树里，切的是 visible。
## 收尾时把它盖回去，后面的语言用例自己再打开一次。
func _check_settings_panel(ctx: RefCounted) -> void:
	var panel: Control = _find_control("_settings_panel")
	var language: Button = _button_with(KEY_LANGUAGE_SWITCH)
	if not ctx.check(panel != null and language != null, "设置面板与语言开关都在屏上"):
		return
	ctx.check(not panel.visible, "设置面板起初是收着的")
	ctx.check(not language.is_visible_in_tree(), "收着的时候语言开关也看不见")
	var settings_button: Button = _button_with(MenuLayout.KEY_SETTINGS)
	if not ctx.check(settings_button != null, "「设置」入口在屏上"):
		return
	settings_button.pressed.emit()
	ctx.check(panel.visible and language.is_visible_in_tree(), "按「设置」后面板与语言开关都出现")
	settings_button.pressed.emit()
	ctx.check(not panel.visible, "再按一下又收回去")


# ------------------------------------------------------------------ 语言开关

## 验收要的那一条：按下去 locale 真的变了，而且**界面上的字当场跟着变**。
func _check_language_switch(ctx: RefCounted) -> void:
	var settings_button: Button = _button_with(MenuLayout.KEY_SETTINGS)
	var button: Button = _button_with(KEY_LANGUAGE_SWITCH)
	var title: Label = _label_with(TreeProbe.find_all(_menu, "Label"), tr_key("奥术蓝图"))
	if not ctx.check(settings_button != null and button != null and title != null,
			"「设置」、语言开关与标题都在屏上"):
		return
	# 玩家是先在设置面板里看到语言开关才按得着它 —— 这一段就在面板打开的状态下走。
	settings_button.pressed.emit()
	ctx.check(button.is_visible_in_tree(), "语言开关在打开的面板里看得见")

	var original: String = _settings.get_locale()
	ctx.check(not original.is_empty(), "切换前记下了当前语言：「%s」" % original)

	button.pressed.emit()
	var toggled: String = _settings.get_locale()
	ctx.check(toggled != original, "按下语言开关，locale 真的变了：%s → %s" % [original, toggled])
	ctx.check(_csv_column(toggled) > 0, "切到的是语言表里有列的语言：%s" % toggled)
	ctx.equal(TranslationServer.get_locale(), toggled, "TranslationServer 跟着换")
	# 「立刻生效」：标题上的字必须等于语言表里那一格，而不是「看起来像英文」。
	ctx.equal(title.text, _csv_row("奥术蓝图", toggled), "[%s] 标题当场变成语言表里的那一格" % toggled)
	ctx.equal(button.text, _csv_row(KEY_LANGUAGE_SWITCH, toggled), "语言开关自己的文案也跟着刷")

	# 还原：再按一次转回原语言（toggle 只在两个受支持语言之间来回；首次运行时原语言
	# 可能就是其中之一）。转不回来时用 set_locale(persist=false) 直接设回去 —— 用例
	# 不该把语言留在别人身上，也不该再往玩家偏好里写第二笔。
	button.pressed.emit()
	if _settings.get_locale() != original:
		_settings.set_locale(original, false)
	ctx.equal(_settings.get_locale(), original, "用例收尾时语言已还原为 %s" % original)
	settings_button.pressed.emit()
	ctx.check(not _find_control("_settings_panel").visible, "设置面板盖回去")


# ------------------------------------------------------------------ 工具

func _button_with(text_key: String) -> Button:
	var wanted: String = tr_key(text_key)
	for node: Node in TreeProbe.find_all(_menu, "Button"):
		var button: Button = node
		if button.text == wanted:
			return button
	return null


## 「继续」旁边那行说明。按**落点**找：它是空文案的 Label，按文字找会在置灰时先撞上别的。
func _hint_label() -> Label:
	for node: Node in TreeProbe.find_all(_menu, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(MenuLayout.CONTINUE_HINT_RECT.position):
			return label
	return null


func _label_with(labels: Array[Node], text: String) -> Label:
	for node: Node in labels:
		var label: Label = node
		if label.text == text:
			return label
	return null


## 按**变量名**取屏上的私有控件。用 get() 而不是加一个公开 getter：
## 那几个控件是这一屏的内部装配，为了测试在产品代码上开一串 getter 更贵。
func _find_control(variable: String) -> Control:
	return _menu.get(variable) as Control


## 按 key 取译文 —— 与 Node.tr() 同一条路径（本文件是 RefCounted，没有 tr()）。
func tr_key(key: String) -> String:
	return TranslationServer.translate(key)


## 语言表里某个语言的列号（0 = keys 那列）。没有这一列就返回 -1。
## 从表头**现读**而不是在这里再抄一份语言清单 —— 抄一份就等于把「支持哪些语言」
## 写了两遍，而这里的断言恰恰是拿界面上的字跟表里那一格对。
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
