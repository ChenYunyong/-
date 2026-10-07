## test_fonts.gd
## 职责：中文字形的验收 —— 界面字体必须真的画得出汉字，而不是「配置看起来对」。
## 所属系统：tests
## 依赖：Fonts, ArcaneTheme, Palette
## 禁止：本文件不得写入字体配置，只断言。
##
## 为什么单独立一条：Godot 内置默认字体**没有 CJK 字形**，配错的表现是
## 「界面全空、一个字都不显示」—— 而且**不会报错**。所以这里断言的是
## 「这个字体对象含不含『奥』这个字」，不是「font_names 列表里有没有微软雅黑」。

extends RefCounted

## 界面上真实出现过的汉字，逐个验字 —— 只验一个字等于只验了一个码位。
const PROBE_TEXTS: PackedStringArray = [
	"奥术蓝图", "模块编辑器", "核心卡", "开始战斗", "吸附",
	"魔力产出", "选择奖励", "第 %d 波 / 共 %d 波",
]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_fonts")
	_check_font_object(ctx)
	_check_glyph_coverage(ctx)
	_check_theme_wiring(ctx)
	_check_detects_missing_cjk(ctx)


func _check_font_object(ctx: RefCounted) -> void:
	var font: Font = Fonts.ui_font()
	ctx.check(font != null, "取到了界面字体")
	ctx.check(font is SystemFont, "界面字体是 SystemFont（零素材方案）")
	if font is SystemFont:
		ctx.check(font.allow_system_fallback, "允许系统回退 —— 装了什么中文字体都能兜住")
		ctx.check(font.font_names.size() > 0, "给出了中文候选字体族")
		ctx.check(font.font_names.has("sans-serif"), "候选表末位兜底到 sans-serif")


## 逐字验字形：只要有一个字画不出来，界面上就会开一个天窗。
func _check_glyph_coverage(ctx: RefCounted) -> void:
	var font: Font = Fonts.ui_font()
	ctx.check(Fonts.can_render(font, Fonts.PROBE_CHAR), "字体含『%s』字形" % Fonts.PROBE_CHAR)
	var missing: PackedStringArray = PackedStringArray()
	for text: String in PROBE_TEXTS:
		for index: int in text.length():
			var character: String = text[index]
			if character == " " or character == "%" or character == "d":
				continue
			if not font.has_char(character.unicode_at(0)):
				missing.append(character)
	ctx.equal(missing.size(), 0,
		"界面用到的汉字都有字形" if missing.is_empty() else "缺字形：%s" % "".join(missing))


## 主题必须把字体挂成 default_font —— 否则每个控件都得自己挂一遍，迟早漏掉一个。
func _check_theme_wiring(ctx: RefCounted) -> void:
	var theme: Theme = load("res://assets/ui/theme_main.tres")
	ctx.check(theme != null, "主题资源可加载")
	if theme == null:
		return
	ctx.check(theme.default_font != null, "主题挂了默认字体")
	ctx.check(theme.default_font_size > 0, "主题设了默认字号")
	if theme.default_font != null:
		ctx.check(theme.default_font.has_char(Fonts.PROBE_CHAR.unicode_at(0)),
			"主题字体含『%s』字形（默认字体能画中文）" % Fonts.PROBE_CHAR)


## 反向对照：造一个**明确没有** CJK 的字体，确认 can_render 会说「不行」。
## 没有这一段，一个永远 return true 的 can_render 也能让上面全绿。
func _check_detects_missing_cjk(ctx: RefCounted) -> void:
	var blank: SystemFont = SystemFont.new()
	blank.font_names = PackedStringArray(["__never_installed_font_family__"])
	blank.allow_system_fallback = false
	ctx.check(not Fonts.can_render(blank, Fonts.PROBE_CHAR),
		"反向对照：无 CJK 的字体被判为画不出汉字")
	ctx.check(Fonts.can_render(blank, "A"), "反向对照：该字体仍然画得出拉丁字母")
	# 第二条反向对照：私用区码位谁都没有字形，真字体也必须答「没有」——
	# 否则 can_render 只是在无脑 return true。
	ctx.check(not Fonts.can_render(Fonts.ui_font(), ""), "反向对照：私用区码位被判为无字形")
