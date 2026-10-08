## test_menu_layout.gd
## 职责：主菜单屏版面的验收 —— docs/14 §2.4 的几何表逐条对照，外加 §4 的 N01–N04 与 G03/G05/G09 的账。
## 所属系统：tests
## 依赖：MenuLayout, MenuTheme, ButtonMarks, BoardStatePainter, ContractTheme, ContractScreenTheme, UiKit
## 禁止：本文件不得写入布局常量，只断言 —— 数字的唯一来源是 MenuLayout / docs/14。
##
## 布局错位在 headless 下**不会报错**，只会让真机上两个控件叠在一起；而 §2.4 的「rect @960」
## 列把每个数字都给死了，所以这里是**逐字对照** —— 常量抄错一个数，test 立刻红。
##
## 版式在 MenuLayout，画法（两笔状态装饰）在 ButtonMarks 的真值表，装配之后的真 rect 在
## integration/main_menu_smoke。之所以把「悬停 / 焦点该画哪几笔」放在这一层量：真机上 hover
## 在 headless 下按不出来，真值表是这两个状态唯一被验到的机会。

extends RefCounted

## 窗口 / 画布 = 2，来自 project.godot。触控下限 44 **设备像素**换算成 22 逻辑像素（§1）。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## §1 的最小互动矩形。
const MIN_INTERACTIVE: float = 24.0
## §4 N01：Logo 占整屏的上限；两条面积比是契约给的实测值。
const N01_LOGO_RATIO_MAX: float = 0.05
const N01_LOGO_RATIO: float = 0.04938
const N01_PAPER_RATIO: float = 0.25327
## §1.1：Focus 与 Selected 两个语义色的 RGB 欧氏距离（**0..255 刻度**，§1.1 的 158.392）。
const G09_MIN_DISTANCE: float = 150.0
const G09_DISTANCE: float = 158.392
## §4 G04：正文对比下限。
const G04_BODY_CONTRAST: float = 4.5
## §1 的间距档位。
const SPACING_SCALE: Array[float] = [4.0, 8.0, 12.0, 16.0, 24.0]
const LOCALES: PackedStringArray = ["zh_CN", "en"]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_menu_layout")
	_check_screen_matches_project(ctx)
	_check_logo_and_paper(ctx)
	_check_stacking(ctx)
	_check_entries(ctx)
	_check_settings_panel(ctx)
	_check_roles(ctx)
	_check_marks(ctx)
	_check_focus_vs_selected(ctx)
	_check_font_levels(ctx)
	_check_touch_targets(ctx)
	_check_spacing_system(ctx)
	_check_both_locales(ctx)


func _check_screen_matches_project(ctx: RefCounted) -> void:
	ctx.equal(MenuLayout.SCREEN.x, float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		"布局基准宽 = project.godot 的画布宽")
	ctx.equal(MenuLayout.SCREEN.y, float(ProjectSettings.get_setting("display/window/size/viewport_height")),
		"布局基准高 = project.godot 的画布高")
	ctx.check(Rect2(Vector2.ZERO, MenuLayout.SCREEN).encloses(MenuLayout.SAFE_AREA), "安全区落在画布内")


## N01：Logo 400×64 占整屏 ≤5%；纸背 360×348 占安全区 25.327%；两者都居中，场景始终可见。
func _check_logo_and_paper(ctx: RefCounted) -> void:
	ctx.equal(MenuLayout.LOGO_RECT.size, Vector2(400.0, 64.0), "MENU_LOGO 400×64")
	ctx.equal(MenuLayout.PAPER_RECT.size, Vector2(360.0, 348.0), "MENU_PAPER 360×348")
	var screen_ratio: float = MenuLayout.LOGO_RECT.size.x * MenuLayout.LOGO_RECT.size.y \
		/ (MenuLayout.SCREEN.x * MenuLayout.SCREEN.y)
	ctx.near(screen_ratio, N01_LOGO_RATIO, "N01 Logo 占整屏 %.5f" % screen_ratio)
	ctx.check(screen_ratio <= N01_LOGO_RATIO_MAX, "N01 Logo ≤ 整屏 5%%（%.5f）" % screen_ratio)
	var safe: float = MenuLayout.SAFE_AREA.size.x * MenuLayout.SAFE_AREA.size.y
	var paper_ratio: float = MenuLayout.PAPER_RECT.size.x * MenuLayout.PAPER_RECT.size.y / safe
	ctx.near(paper_ratio, N01_PAPER_RATIO, "N01 纸背占安全区 %.5f" % paper_ratio)
	# 「场景始终可见」= 纸背与浮层都没盖满安全区，四周一定留得下场景那一层。
	var panel: float = MenuLayout.SETTINGS_PANEL.size.x * MenuLayout.SETTINGS_PANEL.size.y
	ctx.check(paper_ratio < 1.0 and panel < safe, "N01 纸背与浮层都没盖满安全区，场景始终可见")
	# 两件东西都横向居中：歪一格看得出来，而「居中了没有」肉眼比不出来。
	for pair: Array in [["Logo", MenuLayout.LOGO_RECT], ["纸背", MenuLayout.PAPER_RECT]]:
		ctx.near((pair[1] as Rect2).get_center().x, MenuLayout.SCREEN.x * 0.5, "%s 横向居中" % pair[0])


## §2.4 的纵向账：Logo 16 纸背；纸内 24+56+12+56+4+20+12+56+12+56 = 308，上下内缩 24/16 凑满 348。
func _check_stacking(ctx: RefCounted) -> void:
	ctx.near(MenuLayout.PAPER_RECT.position.y - MenuLayout.LOGO_RECT.end.y, MenuLayout.LOGO_GAP,
		"Logo 到纸背 16")
	ctx.check(MenuLayout.PAPER_RECT.encloses(MenuLayout.NEW_RECT), "纸背装得下入口")
	ctx.near(MenuLayout.NEW_RECT.position.x - MenuLayout.PAPER_RECT.position.x, MenuLayout.PAPER_PADDING,
		"入口左内缩 24")
	ctx.near(MenuLayout.PAPER_RECT.end.x - MenuLayout.EXIT_RECT.end.x, MenuLayout.PAPER_PADDING,
		"入口右内缩 24")
	ctx.near(MenuLayout.NEW_RECT.position.y - MenuLayout.PAPER_RECT.position.y, MenuLayout.PAPER_PADDING,
		"第一颗入口距纸背顶 24")
	ctx.near(MenuLayout.CONTINUE_RECT.position.y - MenuLayout.NEW_RECT.end.y, MenuLayout.ENTRY_GAP,
		"新局到继续 12")
	ctx.near(MenuLayout.REASON_RECT.position.y - MenuLayout.CONTINUE_RECT.end.y, MenuLayout.REASON_GAP,
		"原因行距继续 4")
	ctx.near(MenuLayout.SETTINGS_ENTRY_RECT.position.y - MenuLayout.REASON_RECT.end.y,
		MenuLayout.ENTRY_GAP, "设置距原因 12")
	ctx.near(MenuLayout.EXIT_RECT.position.y - MenuLayout.SETTINGS_ENTRY_RECT.end.y,
		MenuLayout.ENTRY_GAP, "退出距设置 12")
	ctx.check(MenuLayout.PAPER_RECT.encloses(MenuLayout.REASON_RECT), "原因行在纸内")
	ctx.check(MenuLayout.PAPER_RECT.encloses(MenuLayout.FOOTNOTE_RECT),
		"契约留给脚注的那一行仍在纸内（本屏没画，位置已登记）")
	# 纸内的账要**正好**合上，不多不少：上内缩 24 + 跨度 284（56+12+56+4+20+12+56+12+56）
	# + 脚注相隔 12 + 脚注 20 + 下沿 8 = 348。表里每个数都在这里对上一次。
	var used: float = MenuLayout.EXIT_RECT.end.y - MenuLayout.NEW_RECT.position.y
	ctx.near(used, 284.0, "四颗入口 + 原因行跨 284")
	ctx.near(MenuLayout.FOOTNOTE_RECT.position.y - MenuLayout.EXIT_RECT.end.y, 12.0,
		"退出 436 → 脚注 448，相隔 12")
	ctx.near(MenuLayout.PAPER_RECT.end.y - MenuLayout.FOOTNOTE_RECT.end.y, 8.0,
		"脚注 468 → 纸背底 476，余 8")


## 四颗入口：都是 312×56、顺序与 BUTTONS 一致、互不重叠、都嵌在纸内。
func _check_entries(ctx: RefCounted) -> void:
	var rects: Array[Rect2] = MenuLayout.entry_rects()
	ctx.equal(rects.size(), 4, "四个入口各有一个矩形")
	ctx.equal(MenuLayout.BUTTONS.size(), 4, "四个入口各有一个文案 key")
	ctx.equal(MenuLayout.entry_rect(0), MenuLayout.NEW_RECT, "第 1 颗是新局")
	ctx.equal(MenuLayout.entry_rect(3), MenuLayout.EXIT_RECT, "第 4 颗是退出")
	ctx.equal(MenuLayout.entry_rect(9), MenuLayout.EXIT_RECT, "越界的行号钳到最后一颗（不返回零矩形）")
	for index: int in rects.size():
		ctx.equal(rects[index].size, MenuLayout.ENTRY_SIZE, "第 %d 颗入口 312×56（N02）" % (index + 1))
		ctx.check(MenuLayout.PAPER_RECT.encloses(rects[index]), "第 %d 颗入口在纸内" % (index + 1))
	for index: int in rects.size() - 1:
		var gap: float = rects[index + 1].position.y - rects[index].end.y
		ctx.check(gap >= MenuLayout.REASON_GAP, "第 %d 与第 %d 颗不相接（隔 %.0f）"
			% [index + 1, index + 2, gap])


## §2.4 的 SETTINGS_* 五条：浮层 416×232、内缩 16、开关 384×56、标题 32 高、说明 48 高（≤2 行）。
func _check_settings_panel(ctx: RefCounted) -> void:
	ctx.equal(MenuLayout.SETTINGS_PANEL.size, Vector2(416.0, 232.0), "SETTINGS_PANEL 416×232")
	ctx.equal(MenuLayout.SETTINGS_TOGGLE_RECT.size, Vector2(384.0, 56.0), "N04 语言开关 384×56")
	ctx.equal(MenuLayout.SETTINGS_TITLE_RECT.size, Vector2(320.0, 32.0), "SETTINGS_TITLE 320×32（24/32）")
	ctx.equal(MenuLayout.SETTINGS_CLOSE_RECT.size, Vector2(32.0, 32.0), "SETTINGS_CLOSE 32×32")
	ctx.equal(MenuLayout.SETTINGS_LANGUAGE_RECT.size, Vector2(384.0, 24.0), "SETTINGS_LANGUAGE 384×24")
	ctx.equal(MenuLayout.SETTINGS_HELP_RECT.size, Vector2(384.0, 48.0), "SETTINGS_HELP 384×48（≤2 行）")
	for pair: Array in [["标题", MenuLayout.SETTINGS_TITLE_RECT], ["关闭键", MenuLayout.SETTINGS_CLOSE_RECT],
			["语言行", MenuLayout.SETTINGS_LANGUAGE_RECT], ["开关", MenuLayout.SETTINGS_TOGGLE_RECT],
			["说明", MenuLayout.SETTINGS_HELP_RECT]]:
		ctx.check(MenuLayout.SETTINGS_PANEL.encloses(pair[1]), "%s 在浮层内" % pair[0])
	ctx.near(MenuLayout.SETTINGS_TITLE_RECT.position.x - MenuLayout.SETTINGS_PANEL.position.x,
		MenuLayout.PANEL_PADDING, "浮层左内缩 16")
	ctx.near(MenuLayout.SETTINGS_PANEL.end.x - MenuLayout.SETTINGS_CLOSE_RECT.end.x,
		MenuLayout.PANEL_PADDING, "关闭键右内缩 16")
	ctx.near(MenuLayout.SETTINGS_TITLE_RECT.position.y - MenuLayout.SETTINGS_PANEL.position.y,
		MenuLayout.PANEL_PADDING, "标题距浮层顶 16")
	ctx.near(MenuLayout.SETTINGS_LANGUAGE_RECT.position.y - MenuLayout.SETTINGS_TITLE_RECT.end.y,
		MenuLayout.PANEL_PADDING, "语言行距标题 16")
	ctx.near(MenuLayout.SETTINGS_TOGGLE_RECT.position.y - MenuLayout.SETTINGS_LANGUAGE_RECT.end.y,
		MenuLayout.ENTRY_GAP, "开关距语言行 12")
	ctx.near(MenuLayout.SETTINGS_HELP_RECT.position.y - MenuLayout.SETTINGS_TOGGLE_RECT.end.y,
		MenuLayout.ENTRY_GAP, "说明距开关 12")
	ctx.near(MenuLayout.SETTINGS_PANEL.end.y - MenuLayout.SETTINGS_HELP_RECT.end.y,
		MenuLayout.PANEL_PADDING, "浮层底还余 16（16+32+16+24+12+56+12+48+16 = 232）")


## 四个入口的角色分工：只有新局是强主动作，其余三颗是深色次入口（§2.4「只有新局金底」）。
func _check_roles(ctx: RefCounted) -> void:
	ctx.equal(MenuLayout.KEY_PRIMARY, MenuLayout.KEY_NEW_RUN, "强主动作就是「开始新一局」")
	var gold: int = 0
	for key: String in MenuLayout.BUTTONS:
		if key == MenuLayout.KEY_PRIMARY:
			gold += 1
	ctx.equal(MenuLayout.BUTTONS[0], MenuLayout.KEY_PRIMARY, "强主动作排在第一位（自上而下的第一颗）")
	ctx.equal(gold, 1, "四颗入口里只有一颗拿金底（N02）")
	ctx.equal(MenuLayout.KEY_CLOSE, "关闭设置", "浮层关闭键的文案 key")
	ctx.check(not MenuLayout.BUTTONS.has(MenuLayout.KEY_CLOSE), "关闭键不是第五个入口")


## §2.4 的两笔状态装饰：真值表 + 四角 L 的尺寸就是 §1.1 那一行（不另立一份）。
func _check_marks(ctx: RefCounted) -> void:
	ctx.equal(ButtonMarks.marks_for(false, false, false), ButtonMarks.MARK_NONE, "没悬停没焦点：不画")
	ctx.equal(ButtonMarks.marks_for(true, false, false), ButtonMarks.MARK_HIGHLIGHT, "悬停：上/左 1px 高光")
	ctx.equal(ButtonMarks.marks_for(false, true, false), ButtonMarks.MARK_FOCUS, "焦点：四角 L")
	ctx.equal(ButtonMarks.marks_for(true, true, false),
		ButtonMarks.MARK_HIGHLIGHT | ButtonMarks.MARK_FOCUS, "悬停 + 焦点：两笔都画")
	ctx.equal(ButtonMarks.marks_for(true, true, true), ButtonMarks.MARK_FOCUS,
		"按下时不叠高光 —— 否则「按下」被画成「抬起」（§2.4 把两个状态分开列）")
	ctx.equal(ButtonMarks.HIGHLIGHT_WIDTH, 1.0, "高光是 1px（§2.4）")
	ctx.equal(ButtonMarks.HIGHLIGHT_INSET, 1.0, "高光内缩 1，常态边框因此保留（§2.4「保留边框并加上」）")
	ctx.equal(BoardStatePainter.FOCUS_INSET, 1.0, "焦点角标内缩 1（§1.1）")
	ctx.equal(BoardStatePainter.FOCUS_ARM, 12.0, "焦点角标臂长 12（§1.1）")
	ctx.equal(BoardStatePainter.FOCUS_WIDTH, 2.0, "焦点角标线宽 2（§1.1）")
	ctx.check(BoardStatePainter.FOCUS_ARM < MenuLayout.ENTRY_SIZE.y * 0.5,
		"臂长不到按钮半高，四角 L 不会连成一整圈")


## G09：焦点色 BLUE_300 与选中色 GOLD_500 必须分得开；本屏自己画的两笔都从角色表取。
func _check_focus_vs_selected(ctx: RefCounted) -> void:
	ctx.equal(MenuTheme.token_of(MenuTheme.Role.FOCUS), Palette.Key.BLUE_300,
		"焦点角标取 BLUE_300（§1.1「不能画完整金圈」）")
	ctx.equal(MenuTheme.token_of(MenuTheme.Role.HIGHLIGHT), Palette.Key.GOLD_200,
		"悬停高光取 GOLD_200（§3「材质上/左高光」）")
	ctx.equal(MenuTheme.role_count(), 2, "角色表就是这两个，没有多余的色")
	var focus: Color = MenuTheme.color(MenuTheme.Role.FOCUS)
	var selected: Color = Palette.get_color(Palette.Key.GOLD_500)
	# §1.1 的 158.392 是 **0..255 刻度**上的欧氏距离，不是 0..1 刻度（0..1 上同一个值是 0.621）。
	var delta: Vector3 = Vector3((focus.r - selected.r) * 255.0, (focus.g - selected.g) * 255.0,
		(focus.b - selected.b) * 255.0)
	var distance: float = delta.length()
	ctx.near(distance, G09_DISTANCE, "G09 焦点色与选中色的 RGB 距离 %.3f" % distance, 0.01)
	ctx.check(distance >= G09_MIN_DISTANCE, "G09 距离 ≥150（%.3f）" % distance)
	# N03：置灰原因写在亮纸上，是纸面深墨 —— 那里必须读得出。
	var contrast: float = _contrast(Palette.get_color(Palette.Key.BROWN_700),
		Palette.get_color(Palette.Key.GOLD_200))
	ctx.near(contrast, 10.947, "N03 原因行的对比 %.3f" % contrast, 0.01)
	ctx.check(contrast >= G04_BODY_CONTRAST, "N03 原因行 ≥4.5（%.3f）" % contrast)


## G05：主标题 24 − 正文 16 = 8；Logo 是 §2.4 单独那一档 36，每档 rect 都装得下它那一行。
func _check_font_levels(ctx: RefCounted) -> void:
	ctx.equal(ContractTheme.FONT_TITLE - ContractTheme.FONT_BODY, 8, "G05 主标题 24 − 正文 16 = 8")
	ctx.equal(ContractTheme.FONT_TITLE, ArcaneTheme.BODY_FONT_SIZE,
		"屏标题档就是主题默认字号（浮层标题因此不另开变体）")
	ctx.equal(ContractScreenTheme.FONT_LOGO, 36, "Logo 36（§2.4 MENU_LOGO 36/48）")
	ctx.check(ContractScreenTheme.FONT_LOGO > ContractTheme.FONT_TITLE, "Logo 比屏标题还大（全工程唯一一处）")
	for pair: Array in [["Logo 64 ≥ 48", MenuLayout.LOGO_RECT.size.y, 48.0],
			["标题 32 ≥ 32", MenuLayout.SETTINGS_TITLE_RECT.size.y, 32.0],
			["原因 20 ≥ 20", MenuLayout.REASON_RECT.size.y, 20.0],
			["开关 56 ≥ 28", MenuLayout.SETTINGS_TOGGLE_RECT.size.y, 28.0],
			["语言行 24 ≥ 24", MenuLayout.SETTINGS_LANGUAGE_RECT.size.y, 24.0],
			["说明 48 ≥ 20×2", MenuLayout.SETTINGS_HELP_RECT.size.y, 40.0]]:
		ctx.check(pair[1] >= pair[2], "%s" % pair[0])


## G03：可交互包络不出安全区、不小于 §1 的最小互动矩形。
func _check_touch_targets(ctx: RefCounted) -> void:
	var minimum: float = MIN_TOUCH_DEVICE_PX / DEVICE_SCALE
	var rects: Array[Rect2] = MenuLayout.entry_rects()
	rects.append(MenuLayout.SETTINGS_CLOSE_RECT)
	rects.append(MenuLayout.SETTINGS_TOGGLE_RECT)
	for index: int in rects.size():
		ctx.check(MenuLayout.SAFE_AREA.encloses(rects[index]),
			"第 %d 个可交互件不出安全区（G03）%s" % [index + 1, rects[index]])
		ctx.check(rects[index].size.x >= MIN_INTERACTIVE and rects[index].size.y >= MIN_INTERACTIVE,
			"第 %d 个可交互件不小于 24×24" % (index + 1))
		ctx.check(rects[index].size.y >= minimum,
			"第 %d 个可交互件高 %.0f ≥ 触控下限 %.0f" % [index + 1, rects[index].size.y, minimum])
	ctx.check(MenuLayout.ENTRY_SIZE.y >= 56.0, "入口高 56 —— 不是旧版那个「声明 48 实际 57」（N02）")


## 间距只能取档位（4/8/12/16/24）。高光内缩 1 是**描边**不是间距，故不该进档位表。
func _check_spacing_system(ctx: RefCounted) -> void:
	var values: Dictionary = {
		"PAPER_PADDING": MenuLayout.PAPER_PADDING, "ENTRY_GAP": MenuLayout.ENTRY_GAP,
		"REASON_GAP": MenuLayout.REASON_GAP, "LOGO_GAP": MenuLayout.LOGO_GAP,
		"PANEL_PADDING": MenuLayout.PANEL_PADDING,
	}
	for name: String in values:
		ctx.check(SPACING_SCALE.has(values[name]), "%s = %s 是间距系统里的档位" % [name, values[name]])
	ctx.check(not SPACING_SCALE.has(ButtonMarks.HIGHLIGHT_INSET), "高光内缩 1 不是间距档位")
	ctx.equal(MenuLayout.CLOSE_ICON_RADIUS, 12.0, "关闭键图标半径 12 = §2.4 的「图标 24」的一半")


## G10：两种语言下每一行都得放得下。英文比中文长，是最坏情况 —— 只测中文等于没测。
func _check_both_locales(ctx: RefCounted) -> void:
	var original: String = TranslationServer.get_locale()
	for locale: String in LOCALES:
		TranslationServer.set_locale(locale)
		_check_text_fits(ctx, locale)
	TranslationServer.set_locale(original)
	ctx.equal(TranslationServer.get_locale(), original, "测试结束后语言恢复原样")


## 一行放不放得下，用的就是 UiKit 那把尺（与屏幕摆位同一处口径）。
func _check_text_fits(ctx: RefCounted, locale: String) -> void:
	var rows: Array = [
		["Logo", MenuLayout.KEY_LOGO, MenuLayout.LOGO_RECT, ContractScreenTheme.FONT_LOGO, 1.0],
		["原因", MenuLayout.KEY_NO_RUN, MenuLayout.REASON_RECT, ContractTheme.FONT_CAPTION, 1.0],
		["浮层标题", MenuLayout.KEY_SETTINGS, MenuLayout.SETTINGS_TITLE_RECT, ContractTheme.FONT_TITLE, 1.0],
		["语言行", MenuLayout.KEY_LANGUAGE_LABEL, MenuLayout.SETTINGS_LANGUAGE_RECT,
			ContractTheme.FONT_BODY, 1.0],
		["语言开关", MenuLayout.KEY_LANGUAGE_SWITCH, MenuLayout.SETTINGS_TOGGLE_RECT,
			ContractTheme.FONT_BUTTON, 1.0],
		["说明", MenuLayout.KEY_SETTINGS_HELP, MenuLayout.SETTINGS_HELP_RECT,
			ContractTheme.FONT_BODY, 2.0],
	]
	for index: int in MenuLayout.BUTTONS.size():
		rows.append(["入口", MenuLayout.BUTTONS[index], MenuLayout.entry_rect(index),
			ContractTheme.FONT_BUTTON, 1.0])
	for row: Array in rows:
		var text: String = TranslationServer.translate(row[1])
		var width: float = UiKit.text_units(text) * float(row[3])
		# 说明那一格按 §2.4「最多 2 行」给两行预算，其余都只给一行（G10「所有按钮 1 行无截断」）。
		var room: float = (row[2] as Rect2).size.x * float(row[4])
		ctx.check(width <= room, "[%s] %s「%s」占 %.1f ≤ %.1f" % [locale, row[0], text, width, room])


## WCAG 对比度（与 §3.2 同一套算法：实测 BROWN_700/GOLD_200 = 10.947，与契约数字一致）。
static func _contrast(a: Color, b: Color) -> float:
	var one: float = _luminance(a)
	var other: float = _luminance(b)
	return (maxf(one, other) + 0.05) / (minf(one, other) + 0.05)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


static func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
