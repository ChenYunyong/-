## test_text_metrics.gd
## 职责：PET-97 的**字体度量**收口验收 —— §1 的实际行高、英文文案的 shaping 宽度、
##       以及「折行放得下、不截断」（G10）。
## 所属系统：tests
## 依赖：ContractFont, Fonts, ContractTheme, EditorLayout, CombatLayout, MenuLayout, MapLayout,
##       CardCatalog, UiKit
## 禁止：本文件不得写入字体 / 布局数字，只断言；断言**必须按实际度量**（get_height /
##       get_string_size / Label 的真实尺寸），不许拿「配置里写了 24」当行高通过。
##
## 为什么单独立一条：G02 的 rect 容差**不豁免 §1 的行高**，G10 又要双语都放得下。
## 这两条原来都没按实际字体量过 —— 系统 CJK 字体在 24 / 36 号上多出的 1px、
## 英文卡名与战斗标题多出的 7 / 3px，都是「配置看起来对」看不出来的。

extends RefCounted

const THEME_PATH: String = "res://assets/ui/theme_main.tres"
## 详情名右缘到收起键左缘的间隔，§2.1 给的是 4（892 → 896）。
const DETAIL_NAME_GAP: float = 4.0


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_text_metrics")
	var original: String = TranslationServer.get_locale()
	await _check_line_heights(ctx, tree)
	await _check_title_rects(ctx, tree)
	await _check_detail_name(ctx, tree)
	await _check_combat_title(ctx, tree)
	await _check_settings_help(ctx, tree)
	await _check_cold_entry(ctx, tree)
	TranslationServer.set_locale(original)
	ctx.equal(TranslationServer.get_locale(), original, "测试结束后语言恢复原样")


# ---------------------------------------------------------------- 行高（#10 / #4）

## §1 的五档字号：实际 ascent+descent 必须 ≤ 表列行高。量的是主题**解析之后**那支字体。
func _check_line_heights(ctx: RefCounted, tree: SceneTree) -> void:
	var font: Font = await _role_font(tree, &"")
	if not ctx.check(font != null, "主题的默认字体解析得到（否则下面全是空断言）"):
		return
	for size: int in ContractFont.LINE_HEIGHT:
		var limit: float = ContractFont.line_height_of(size)
		var height: float = font.get_height(size)
		ctx.check(height <= limit,
			"§1 字号 %d 的实际行高 %.0f ≤ 表列 %s" % [size, height, limit])
	# 反向对照：没经 ContractFont 收行距的原始字体在同字号上只会更高 —— 度量是**实测**的，
	# 所以把 LINE_TIGHTEN 改回 0，上面那条 24 号（33 > 32）与 36 号（49 > 48）立刻变红。
	var raw: Font = Fonts.ui_font()
	ctx.check(raw.get_height(24) > font.get_height(24),
		"反向对照：原始字体 24 号行高 %.0f > 收口后的 %.0f（这一步不是白收的）"
			% [raw.get_height(24), font.get_height(24)])
	ctx.check(not ContractFont.fits_line_height(raw, 24),
		"反向对照：未收行距的字体被判为**不满足** §1 行高（判据不是恒真）")
	ctx.check(ContractFont.fits_line_height(font, 24), "收过行距的字体满足 §1 行高")


## 每一档标题所在的 rect 都装得下它那一行 —— 判据是**真 Label 的尺寸**：字体撑不动它。
func _check_title_rects(ctx: RefCounted, tree: SceneTree) -> void:
	var rows: Array = [
		["地图标题", &"", MapLayout.TITLE_RECT, 24],
		["书页标题", &"", EditorLayout.TITLE_RECT, 24],
		["战斗标题", ContractScreenTheme.TYPE_LABEL_SCREEN_TITLE, CombatLayout.TITLE_RECT, 24],
		["浮层标题", &"", MenuLayout.SETTINGS_TITLE_RECT, 24],
		["菜单说明", ContractTheme.TYPE_LABEL_BODY_MUTED, MenuLayout.SETTINGS_HELP_RECT, 16],
	]
	for row: Array in rows:
		var rect: Rect2 = row[2]
		var label: Label = await _label(tree, row[1], "Sample", rect.size)
		ctx.equal(label.size, rect.size,
			"%s 实际尺寸 = 表列 rect %s（字体没把它撑开）" % [row[0], rect.size])
		var font: Font = label.get_theme_font(&"font")
		ctx.check(font.get_height(row[3]) <= rect.size.y,
			"%s 行高 %.0f ≤ rect 高 %s（PET-95 量到的 33 vs 32 就是这一条）"
				% [row[0], font.get_height(row[3]), rect.size.y])
		label.queue_free()
	ctx.check(MapLayout.TITLE_RECT.size.y == 32.0, "MAP_TITLE 高仍按 §2.2 的 32，不改契约数字")


# ---------------------------------------------------------------- 英文宽度（#2 / #6）

## #2：DETAIL_NAME 那一格在**英文最长的一张卡名**下不侵入收起键。量一条真 Label：
## 它的实际宽度必须还是表列的 176，且 176 的右缘（892）加 4 的间隔正好落在收起键左缘。
func _check_detail_name(ctx: RefCounted, tree: SceneTree) -> void:
	var text: String = await _longest_english_card_name(tree)
	TranslationServer.set_locale("en")
	ctx.equal(text, "Projectile Count", "英文最长的卡名就是 PET-95 点出的那个（%s）" % text)
	var rect: Rect2 = EditorLayout.DETAIL_NAME_RECT
	var tight: float = await _shaped_width(tree, ContractTheme.TYPE_LABEL_DETAIL_NAME, text)
	var loose: float = await _shaped_width(tree, &"", text)
	ctx.near(loose - rect.size.x, 7.0,
		"未收字距时超宽 +7 —— PET-95 量到的那个数（当前字体：Microsoft YaHei 家族）", 0.01)
	ctx.check(tight <= rect.size.x,
		"详情名「%s」实宽 %.0f ≤ %s（表列宽，不许截断）" % [text, tight, rect.size.x])
	ctx.check(loose > tight,
		"反向对照：不收字距时 %.0f > 收过之后的 %.0f（GLYPH_TIGHTEN 改回 0 即变红）"
			% [loose, tight])
	ctx.check(rect.end.x + DETAIL_NAME_GAP <= EditorLayout.DETAIL_CLOSE_RECT.position.x,
		"表列本身留得住间隔：名字右缘 %.0f + %s ≤ 收起键左缘 %.0f"
			% [rect.end.x, DETAIL_NAME_GAP, EditorLayout.DETAIL_CLOSE_RECT.position.x])
	ctx.check(tight <= EditorLayout.DETAIL_CLOSE_RECT.position.x - rect.position.x - DETAIL_NAME_GAP,
		"实测宽度 %.0f 落在名字框内，不与收起键框重叠 %s"
			% [tight, EditorLayout.DETAIL_CLOSE_RECT])
	var label: Label = await _label(tree, ContractTheme.TYPE_LABEL_DETAIL_NAME, text, rect.size)
	ctx.equal(label.size.x, rect.size.x, "详情名 Label 的实际宽 = 176（字体撑不宽它）")
	label.queue_free()
	TranslationServer.set_locale("zh_CN")


## #6：战斗屏标题 `AUTO CASTING` 实测 179 > 表列 176 —— 同 #2 的口径（收字距，不缩字号）。
func _check_combat_title(ctx: RefCounted, tree: SceneTree) -> void:
	TranslationServer.set_locale("en")
	var text: String = TranslationServer.translate("自动施法")
	var rect: Rect2 = CombatLayout.TITLE_RECT
	var tight: float = await _shaped_width(tree, ContractScreenTheme.TYPE_LABEL_SCREEN_TITLE, text)
	var loose: float = await _shaped_width(tree, &"", text)
	ctx.equal(text, "AUTO CASTING", "英文标题就是 PET-95 量的那一串（%s）" % text)
	ctx.near(loose - rect.size.x, 3.0, "未收字距时超宽 +3 —— PET-95 量到的那个数", 0.01)
	ctx.check(tight <= rect.size.x, "战斗标题「%s」实宽 %.0f ≤ %s" % [text, tight, rect.size.x])
	ctx.check(loose > tight,
		"反向对照：不收字距时 %.0f > 收过之后的 %.0f" % [loose, tight])
	TranslationServer.set_locale("zh_CN")


# ---------------------------------------------------------------- 折行（#7）

## #7：英文设置说明单行 491 > 384。§2.4 给这一格的是「16/24，最多 2 行」——
## 要的是**折行**，不是截断。量的是一条真 Label 的换行结果。
func _check_settings_help(ctx: RefCounted, tree: SceneTree) -> void:
	TranslationServer.set_locale("en")
	var text: String = TranslationServer.translate(MenuLayout.KEY_SETTINGS_HELP)
	var rect: Rect2 = MenuLayout.SETTINGS_HELP_RECT
	var single: float = await _shaped_width(tree, ContractTheme.TYPE_LABEL_BODY_MUTED, text)
	ctx.check(single >= 490.0,
		"单行实宽 %.0f ≥ PET-95 量到的 490，且 > 内容区 %.0f —— 这一格**必须**折行"
			% [single, rect.size.x])
	var wrapped: Label = await _label(tree, ContractTheme.TYPE_LABEL_BODY_MUTED, text, rect.size)
	wrapped.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	await tree.process_frame
	var lines: int = wrapped.get_line_count()
	ctx.check(lines <= 2, "§2.4「最多 2 行」：实际 %d 行" % lines)
	ctx.equal(wrapped.get_visible_line_count(), lines, "可见行数 = 排出的行数（**没有截断**）")
	ctx.check(float(lines) * wrapped.get_line_height() <= rect.size.y,
		"%d 行 × 行高 %.0f ≤ 说明框高 %.0f" % [lines, wrapped.get_line_height(), rect.size.y])
	ctx.check(wrapped.get_combined_minimum_size().x <= rect.size.x,
		"折行后控件最小宽 %.0f 不越出内容区" % wrapped.get_combined_minimum_size().x)
	# 反向对照：**不折行**的同一段文案，最小宽就是单行 491 > 384 —— 控件当场被字体撑宽，
	# 正是 G02 拦的「宽高不能由字体撑开」。把 autowrap 关掉，这一条会换成上面那条一起红。
	var plain: Label = await _label(tree, ContractTheme.TYPE_LABEL_BODY_MUTED, text, rect.size)
	ctx.check(plain.get_combined_minimum_size().x > rect.size.x,
		"反向对照：不折行时最小宽 %.0f > %.0f（控件撑不住，只能靠折行）"
			% [plain.get_combined_minimum_size().x, rect.size.x])
	wrapped.queue_free()
	plain.queue_free()
	TranslationServer.set_locale("zh_CN")


## #7 的第二半 —— **英文冷进入**（PET-95 第 7 项第二轮量到的那条路径）。
##
## 差别只在**建 Label 那一刻 locale 是什么**：中文那句短，`set_size(384)` 顶不动它；
## 英文那句在 AUTOWRAP_OFF 下的最小宽是整段一行的 490，`set_size` 当场被顶到 490 ——
## 而引擎只往大顶、从不缩回来，之后再开折行也回不去。`UiKit.wrapped_label` 因此在**进树之后**
## 把表列尺寸再钉一次。把那一手去掉（或把 locale 改成建屏之后再切），这一条就红。
func _check_cold_entry(ctx: RefCounted, tree: SceneTree) -> void:
	TranslationServer.set_locale("en")
	var text: String = TranslationServer.translate(MenuLayout.KEY_SETTINGS_HELP)
	var rect: Rect2 = MenuLayout.SETTINGS_HELP_RECT
	var holder: Control = Control.new()
	holder.theme = load(THEME_PATH)
	holder.size = MenuLayout.SCREEN
	tree.root.add_child(holder)
	var cold: Label = UiKit.wrapped_label(text, rect, ContractTheme.TYPE_LABEL_BODY_MUTED)
	ctx.check(not cold.is_inside_tree(), "冷进入的前提：Label 是先建好、再进树的")
	holder.add_child(cold)
	await tree.process_frame
	ctx.equal(cold.size, rect.size,
		"英文冷进入：UiKit.wrapped_label 的尺寸仍 = 表列 %s（实为 %s）" % [rect.size, cold.size])
	ctx.check(cold.get_line_count() <= 2 and cold.get_visible_line_count() == cold.get_line_count(),
		"英文冷进入：%d 行 / 可见 %d 行（折行生效且没截断）"
			% [cold.get_line_count(), cold.get_visible_line_count()])
	holder.queue_free()
	TranslationServer.set_locale("zh_CN")


# ---------------------------------------------------------------- 工具

## 在树里起一条真 Label，按 Theme 变体解析字体，再把尺寸设成 rect ——
## 于是量到的就是真机上那一条控件（而不是一张配置表）。
func _label(tree: SceneTree, variation: StringName, text: String, size: Vector2) -> Label:
	var label: Label = Label.new()
	label.theme = load(THEME_PATH)
	if variation != &"":
		label.theme_type_variation = variation
	label.text = text
	tree.root.add_child(label)
	label.size = size
	await tree.process_frame
	return label


## 一个 Theme 变体在真控件上解析出来的字体。
func _role_font(tree: SceneTree, variation: StringName) -> Font:
	var label: Label = await _label(tree, variation, "", Vector2(64.0, 32.0))
	var font: Font = label.get_theme_font(&"font")
	label.queue_free()
	return font


## 一段文案在某个变体下的**实际** shaping 宽度（同一支字体、同一个字号）。
func _shaped_width(tree: SceneTree, variation: StringName, text: String) -> float:
	var label: Label = await _label(tree, variation, text, Vector2(64.0, 32.0))
	var font: Font = label.get_theme_font(&"font")
	var font_size: int = label.get_theme_font_size(&"font_size")
	label.queue_free()
	if font == null:
		return -1.0
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## 卡表里英文名最长的那一张（按**实际 shaping 宽度**，不是按字符数）。
func _longest_english_card_name(tree: SceneTree) -> String:
	var original: String = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var best: String = ""
	var best_width: float = -1.0
	for card: CardData in CardCatalog.all():
		var text: String = TranslationServer.translate(card.name_key)
		var width: float = await _shaped_width(tree, ContractTheme.TYPE_LABEL_DETAIL_NAME, text)
		if width > best_width:
			best_width = width
			best = text
	TranslationServer.set_locale(original)
	return best
