## menu_closure_smoke.gd
## 职责：PET-97 主菜单那两条的**真屏**验收 —— 英文设置说明折行放得下（#7）、
##       金底主按钮的焦点角标带 NAVY_600 暗衬而深色入口不带（#8）。
## 所属系统：tests
## 依赖：TreeProbe, MenuLayout, MenuTheme, ContractTheme, ButtonMarks, UiKit
## 禁止：本文件不得按四颗入口里的任何一颗触发换屏（「继续」到不了是因为它是灰的，
##       其余三颗都会真的动状态）；不得开局，主菜单的 N03 前提不能被他处破坏。
##
## 为什么单独立一条：unit/test_text_metrics.gd 量的是「一段文案在某个变体下多宽」，
## 而这里要的是**屏幕上那一条真控件**的排版与那一颗真按钮的装饰层 —— 前者证明得了口径，
## 证明不了「这一屏真的照着口径接线了」（把 autowrap 关掉、把暗衬不给主按钮，它都不会红）。
## 主菜单冒烟的源码已顶到 300 行上限，故另开一支。
##
## **两条路径都要走**（PET-95 第 7 项第二轮）：`英文冷进入`（locale 在建屏之前就是 en）与
## `中文冷进入 + 当场切英文`。只看后者会漏 —— 热切换时折行早就生效、控件顶不动 384，
## 而冷进入时 Label 的最小宽还是「整段一行」的 490。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")
const SCENE_PATH: String = "res://scenes/main_menu.tscn"
const LOCALE_EN: String = "en"
const LOCALE_ZH: String = "zh_CN"

var _tree: SceneTree = null
var _menu: Node = null
var _settings: Node = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("menu_closure_smoke")
	_tree = tree
	_settings = tree.root.get_node_or_null(^"Settings")
	if not ctx.check(_settings != null, "Settings 单例在（语言开关归它）"):
		return
	var original: String = _settings.get_locale()
	# 第一条路径是**英文冷进入**：locale 在**建屏之前**就是 en。PET-95 第 7 项第二轮量到的
	# 「490×48」只在路径上出现 —— 先建屏再切语言时，折行早就生效了，控件顶不动 384。
	_settings.set_locale(LOCALE_EN, false)
	await _mount(ctx)
	_open_settings()
	_check_help_wraps(ctx, "英文冷进入")
	_check_focus_under(ctx)
	await _unmount()
	# 第二条路径是**中文冷进入 + 当场切英文**（N04 的热切换那一半）：两条路都要落在 384×48。
	_settings.set_locale(LOCALE_ZH, false)
	await _mount(ctx)
	_open_settings()
	await _check_help_wraps(ctx, "中文冷进入 → 热切英文", true)
	await _unmount()
	_settings.set_locale(original, false)
	ctx.equal(_settings.get_locale(), original, "测试结束后语言恢复原样")


func _mount(ctx: RefCounted) -> void:
	var packed: PackedScene = load(SCENE_PATH)
	if not ctx.check(packed != null, "主菜单场景可加载"):
		return
	_menu = packed.instantiate()
	_tree.root.add_child(_menu)
	await _tree.process_frame


## 摘屏并等一帧 —— 下一条路径要重新实例化，旧的留着会撞上 `_menu` 这个名字。
func _unmount() -> void:
	if _menu == null:
		return
	_menu.queue_free()
	await _tree.process_frame
	_menu = null


## 打开设置浮层：按「设置」那颗入口（它只切 visible，不换屏）。
func _open_settings() -> void:
	var entry: Button = _button_with(MenuLayout.KEY_SETTINGS)
	if entry != null:
		entry.pressed.emit()


## #7：英文说明单行 491 > 384，§2.4 给这一格的是「16/24，最多 2 行」——
## 屏幕上那一条真 Label 必须**折行放得下**，而且不能靠把控件撑宽或截断来过关。
## switch_after=true 时先按「中文冷进入」量一遍，再当场切成英文重量一遍（两条路同一套判据）。
func _check_help_wraps(ctx: RefCounted, what: String, switch_after: bool = false) -> void:
	if switch_after:
		_settings.set_locale(LOCALE_EN, false)
		await _tree.process_frame
	var help: Label = _label_at(MenuLayout.SETTINGS_HELP_RECT.position)
	if not ctx.check(help != null, "[%s] 浮层里有那条说明（SETTINGS_HELP_RECT 上有一条 Label）" % what):
		return
	ctx.equal(help.text, TranslationServer.translate(MenuLayout.KEY_SETTINGS_HELP),
		"[%s] 它写的是语言表里那一格（英文）" % what)
	ctx.check(help.autowrap_mode != TextServer.AUTOWRAP_OFF,
		"[%s] 这条说明是**折行**的，不是硬排一行" % what)
	# 尺寸要**钉死在表列值**上，不是「没超过就行」：PET-95 第 7 项第二轮量到的是
	# (288,336,490,48)，右缘 778 一路捅出设置面板右缘 688 共 90px。
	ctx.equal(help.size, MenuLayout.SETTINGS_HELP_RECT.size,
		"[%s] 控件尺寸 = 表列 %s（实为 %s）" % [what, MenuLayout.SETTINGS_HELP_RECT.size, help.size])
	ctx.check(MenuLayout.SETTINGS_PANEL.encloses(Rect2(help.position, help.size)),
		"[%s] 控件整份落在设置面板 %s 里（实为 %s）"
			% [what, MenuLayout.SETTINGS_PANEL, Rect2(help.position, help.size)])
	var lines: int = help.get_line_count()
	ctx.check(lines <= 2, "[%s] §2.4「最多 2 行」：实际 %d 行" % [what, lines])
	ctx.equal(help.get_visible_line_count(), lines, "[%s] 可见行数 = 排出的行数（**没有截断**）" % what)
	ctx.check(float(lines) * help.get_line_height() <= MenuLayout.SETTINGS_HELP_RECT.size.y + 0.001,
		"[%s] %d 行 × 行高 %.0f ≤ 说明框高 %.0f"
			% [what, lines, help.get_line_height(), MenuLayout.SETTINGS_HELP_RECT.size.y])


## #8：焦点角标 BLUE_300 压在金底上只有 1.057:1（PET-95 的数），§3 要求「亮纸上的控件加
## NAVY_600 暗底」。真屏上要看到：金底那颗**带**暗衬，深色入口那颗**不带**。
func _check_focus_under(ctx: RefCounted) -> void:
	var gold: Button = _button_with(MenuLayout.KEY_PRIMARY)
	var dark: Button = _button_with(MenuLayout.KEY_SETTINGS)
	var toggle: Button = _button_with(MenuLayout.KEY_LANGUAGE_SWITCH)
	ctx.check(gold != null and dark != null and toggle != null, "三颗要对照的按钮都在屏上")
	if gold == null or dark == null or toggle == null:
		return
	ctx.equal(gold.theme_type_variation, ContractTheme.TYPE_BUTTON_PAGE_PRIMARY,
		"新局那颗就是金底主按钮（§2.4：只有它整面金）")
	var gold_marks: ButtonMarks = _marks_of(gold)
	var dark_marks: ButtonMarks = _marks_of(dark)
	var toggle_marks: ButtonMarks = _marks_of(toggle)
	if not ctx.check(gold_marks != null and dark_marks != null and toggle_marks != null,
			"三颗按钮都挂着装饰层（否则下面量不到暗衬）"):
		return
	ctx.check(gold_marks.paints_focus_under(), "金底主按钮的焦点角标带 NAVY_600 暗衬")
	ctx.check(not dark_marks.paints_focus_under(),
		"深色入口不垫暗衬（BLUE_300 / NAVY_800 = 9.930）")
	ctx.check(not toggle_marks.paints_focus_under(), "浮层里的语言开关同样不垫")
	ctx.check(gold_marks.focus_under.is_equal_approx(MenuTheme.color(MenuTheme.Role.FOCUS_UNDER)),
		"那颗暗衬的颜色仍来自角色表")


# ---------------------------------------------------------------- 工具

func _button_with(text_key: String) -> Button:
	var wanted: String = TranslationServer.translate(text_key)
	for node: Node in TreeProbe.find_all(_menu, "Button"):
		var button: Button = node
		if button.text == wanted:
			return button
	return null


func _label_at(at: Vector2) -> Label:
	for node: Node in TreeProbe.find_all(_menu, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(at):
			return label
	return null


## 一颗按钮上挂的装饰层（ButtonMarks 是宿主唯一的子节点类型）。
func _marks_of(button: Button) -> ButtonMarks:
	for node: Node in TreeProbe.find_all(button, "ButtonMarks"):
		return node as ButtonMarks
	return null
