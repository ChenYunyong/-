## test_contract_closure.gd
## 职责：PET-97 逐条收口的纯函数 / 主题面验收 —— 书脊 Token（§3）、卡链窗口终点（§2.3）、
##       亮底焦点暗衬（§3）、按下态（§2.4）、端口 Ø32 命中（§1.1）。真事件那一面在
##       integration/port_hit_smoke.gd，字体度量那一面在 unit/test_text_metrics.gd。
## 所属系统：tests
## 依赖：ContractTheme, ContractScreenTheme, MenuTheme, ButtonMarks, BoardView, BoardRenderer,
##       BoardModel, CombatLayout, EditorLayout, Palette
## 禁止：本文件不得写入颜色 / 布局数字，只断言；颜色一律对着 Palette 与 §3 的角色表比。

extends RefCounted

const THEME_PATH: String = "res://assets/ui/theme_main.tres"


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_contract_closure")
	var theme: Theme = load(THEME_PATH)
	if not ctx.check(theme != null, "主题资源可加载"):
		return
	_check_spine(ctx, theme)
	_check_chain_window(ctx)
	_check_focus_under(ctx)
	_check_press_state(ctx, theme)
	_check_port_hit(ctx)


# ---------------------------------------------------------------- #3 书脊 Token

## §3 的「书脊/皮革/桌面无素材兜底 = BROWN_700 / BROWN_600」，而不是「边带」那一行的
## BROWN_400 / BROWN_300（PET-95 记作「书脊 Token 偏离契约」）。
func _check_spine(ctx: RefCounted, theme: Theme) -> void:
	var spine: StyleBoxFlat = theme.get_stylebox(&"panel", ContractTheme.TYPE_PAGE_SPINE) as StyleBoxFlat
	if not ctx.check(spine != null, "书脊样式盒取得到"):
		return
	var alpha: float = ContractTheme.DECOR_ALPHA
	ctx.check(spine.bg_color.is_equal_approx(_tinted(Palette.Key.BROWN_700, alpha)),
		"书脊底 = BROWN_700（§3「书脊/皮革」那一行），实为 %s" % spine.bg_color)
	ctx.check(spine.border_color.is_equal_approx(_tinted(Palette.Key.BROWN_600, alpha)),
		"书脊折影线 = BROWN_600，实为 %s" % spine.border_color)
	# 反向对照：改回 BROWN_400 / BROWN_300（即「边带 / 纸纹」那一行）这两条立刻红。
	ctx.check(not spine.bg_color.is_equal_approx(_tinted(Palette.Key.BROWN_400, alpha)),
		"反向对照：书脊底不再是 BROWN_400（那是「书脊受光/木框细部」）")
	ctx.check(not spine.border_color.is_equal_approx(_tinted(Palette.Key.BROWN_300, alpha)),
		"反向对照：折影线不再是 BROWN_300（那是「纸纹/地图装饰墨」）")
	ctx.equal(Palette.token_names().size(), 35, "G07：Token 仍是 35，这一条没有新增色")


# ---------------------------------------------------------------- #5 卡链窗口

## §2.3 的窗口是「以当前施法卡为**终点**的最近 4 张」。8 卡链逐次施法：
## 第 1..3 次队首还凑不满 4 张，窗口就得**少画**（1 / 2 / 3 张），而不是把末张留在第 4 张。
## PET-95 量到的「前 3 次窗口超前 3 / 2 / 1 卡」就是旧算式留下的。
func _check_chain_window(ctx: RefCounted) -> void:
	var expect: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4),
		Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
	]
	var total: int = 8
	ctx.check(total >= 8, "样本不小于 8 卡（PET-95 的样本）")
	for current: int in total:
		var band: Vector2i = CombatLayout.chain_window(current, total)
		ctx.equal(band, expect[current],
			"8 卡链第 %d 次施法：窗口 %s（终点 = 当前施法卡）" % [current + 1, expect[current]])
		ctx.equal(band.x + band.y - 1, current,
			"第 %d 次施法：窗口末张的下标就是当前那张 —— 超前 0 卡" % (current + 1))
	# 反向对照：把旧算式原样算一遍，它在**头三次**施法上分别超前 3 / 2 / 1 卡 ——
	# 谁把 chain_window 改回去，上面那两轮断言就会红（这一条只是把差值写明白）。
	for current: int in [0, 1, 2]:
		var old_band: Vector2i = _old_band(current, total)
		ctx.equal(old_band.x + old_band.y - 1 - current, 3 - current,
			"反向对照：旧算式在第 %d 次施法上超前 %d 卡" % [current + 1, 3 - current])
	ctx.equal(CombatLayout.chain_window(-1, total), Vector2i(0, 4), "还没施法时仍从队首画满 4 张")
	ctx.equal(CombatLayout.chain_window(total, total), Vector2i(4, 4), "current 越界时钳到末张")


## PET-97 之前的算式，原样抄来只用于反向对照（不参与任何摆放）。
static func _old_band(current: int, total: int) -> Vector2i:
	var count: int = mini(total, CombatLayout.CHAIN_SLOTS)
	if count <= 0:
		return Vector2i(0, 0)
	if current >= 0:
		return Vector2i(clampi(current - count + 1, 0, total - count), count)
	return Vector2i(0, count)


# ---------------------------------------------------------------- #8 焦点暗衬

## §3「Focus | BLUE_300 | 暗卡内侧四角 2px；亮纸上的控件加 NAVY_600 暗底」。
## 新局那颗是整面金底（GOLD_500），BLUE_300 直接压上去只有 1.057:1（PET-95 的数）。
func _check_focus_under(ctx: RefCounted) -> void:
	ctx.equal(MenuTheme.token_of(MenuTheme.Role.FOCUS_UNDER), Palette.Key.NAVY_600,
		"焦点暗底取 NAVY_600（§3 的「亮纸上的控件加 NAVY_600 暗底」）")
	ctx.equal(MenuTheme.role_count(), 3, "角色表三笔：焦点 / 悬停 / 焦点暗底")
	var focus: Color = MenuTheme.color(MenuTheme.Role.FOCUS)
	var under: Color = MenuTheme.color(MenuTheme.Role.FOCUS_UNDER)
	for fill: Palette.Key in [Palette.Key.GOLD_500, Palette.Key.GOLD_200, Palette.Key.GOLD_600]:
		var base: Color = Palette.get_color(fill)
		ctx.check(_contrast(focus, base) < 3.0,
			"裸角标压在 %s 上 %.3f < 3（必须有暗衬）" % [fill, _contrast(focus, base)])
		ctx.near(MenuTheme.focus_under(true).a, 1.0, "亮底上垫暗底（%s）" % fill)
	ctx.near(_contrast(focus, Palette.get_color(Palette.Key.GOLD_500)), 1.057,
		"PET-95 量到的 1.057:1（BLUE_300 / GOLD_500）", 0.01)
	ctx.check(_contrast(focus, under) >= 3.0, "角标对暗底 %.3f ≥ 3" % _contrast(focus, under))
	ctx.check(_contrast(under, Palette.get_color(Palette.Key.GOLD_500)) >= 3.0,
		"暗底对金底 %.3f ≥ 3" % _contrast(under, Palette.get_color(Palette.Key.GOLD_500)))
	# 亮底垫、深色入口不垫；不垫的那份仍是同一个 Token 的色相，只是 alpha=0。
	ctx.check(MenuTheme.focus_under(true).is_equal_approx(under), "亮底那份就是 NAVY_600 原色")
	var off: Color = MenuTheme.focus_under(false)
	ctx.near(off.a, 0.0, "深色入口那份 alpha=0（不画这层）")
	ctx.check(not off.is_equal_approx(under) and off.r == under.r and off.g == under.g,
		"不垫的那份色相仍来自同一个 Token，只差 alpha")
	# 装饰层真的按这个开关画。
	var light: Button = Button.new()
	var dark: Button = Button.new()
	var light_marks: ButtonMarks = ButtonMarks.attach(light, focus,
		MenuTheme.color(MenuTheme.Role.HIGHLIGHT), MenuTheme.focus_under(true))
	var dark_marks: ButtonMarks = ButtonMarks.attach(dark, focus,
		MenuTheme.color(MenuTheme.Role.HIGHLIGHT), MenuTheme.focus_under(false))
	ctx.check(light_marks.paints_focus_under(), "金底那颗的装饰层会画暗底")
	ctx.check(not dark_marks.paints_focus_under(), "深色入口那颗不画暗底")
	light.free()
	dark.free()


# ---------------------------------------------------------------- #9 按下态

## §2.4「Pressed 内容下移 2，内嵌暗边 1」。
##
## 「下移 2」与「样式盒上内边距」不是同一个数：Button 把文字在「尺寸 − 内容边距」里居中，
## 上内边距只有一半变成向下的位移。**真渲染实测**（tools/press_probe.gd，960×540）：
##   上内边距 0 → 位移 0 · 1 → 0 · 2 → 1 · 4 → 2。
## 故实现取 2 × PRESS_SHIFT，本文件同时钉住「机制」与「可见位移」两个数。
func _check_press_state(ctx: RefCounted, theme: Theme) -> void:
	ctx.near(ContractTheme.PRESS_SHIFT, 2.0, "§2.4：按下内容下移 2px（可见位移）")
	ctx.near(ContractTheme.PRESS_CONTENT_MARGIN, ContractTheme.PRESS_SHIFT * 2.0,
		"样式盒上内边距 = 2 × 下移量（居中排版只兑现一半）")
	for variation: StringName in [ContractTheme.TYPE_BUTTON_PAGE_PRIMARY,
			ContractScreenTheme.TYPE_BUTTON_DARK_ENTRY]:
		var normal: StyleBoxFlat = theme.get_stylebox(&"normal", variation) as StyleBoxFlat
		var pressed: StyleBoxFlat = theme.get_stylebox(&"pressed", variation) as StyleBoxFlat
		if not ctx.check(normal != null and pressed != null, "%s 的两态样式盒都在" % variation):
			continue
		ctx.near(normal.get_margin(SIDE_TOP), 0.0, "%s 常态没有位移" % variation)
		ctx.near(pressed.get_margin(SIDE_TOP) - normal.get_margin(SIDE_TOP),
			ContractTheme.PRESS_CONTENT_MARGIN,
			"%s 按下态的上内边距比常态多 %s ⇒ 内容下移 %.0fpx"
				% [variation, ContractTheme.PRESS_CONTENT_MARGIN, ContractTheme.PRESS_SHIFT])
		ctx.near(pressed.get_margin(SIDE_TOP) * 0.5, ContractTheme.PRESS_SHIFT,
			"%s 折半之后就是那个 2px（实测表）" % variation, 0.01)
		ctx.near(pressed.get_margin(SIDE_BOTTOM), normal.get_margin(SIDE_BOTTOM),
			"%s 下内边距不动（内容区高度不变，按钮不挪）" % variation)
		ctx.near(pressed.get_margin(SIDE_LEFT), normal.get_margin(SIDE_LEFT),
			"%s 左内边距不动" % variation)
		ctx.check(pressed.border_color.is_equal_approx(Palette.get_color(Palette.Key.NAVY_600)),
			"%s 按下态的内嵌暗边取 NAVY_600（实为 %s）" % [variation, pressed.border_color])
		ctx.equal(pressed.border_width_top, ContractTheme.HAIRLINE, "%s 内嵌暗边宽 1" % variation)
	# 反向对照：金底主按钮的常态边是金 —— 两态的边色与内边距都不同，这两笔不是「本来就有」。
	var gold_normal: StyleBoxFlat = theme.get_stylebox(&"normal",
		ContractTheme.TYPE_BUTTON_PAGE_PRIMARY) as StyleBoxFlat
	var gold_pressed: StyleBoxFlat = theme.get_stylebox(&"pressed",
		ContractTheme.TYPE_BUTTON_PAGE_PRIMARY) as StyleBoxFlat
	ctx.check(gold_normal.border_color.is_equal_approx(Palette.get_color(Palette.Key.GOLD_600)),
		"反向对照：常态边仍是 §3 的 GOLD_600")
	ctx.check(not gold_normal.border_color.is_equal_approx(gold_pressed.border_color),
		"反向对照：两态的边色不同")
	ctx.check(gold_pressed.get_margin(SIDE_TOP) > gold_normal.get_margin(SIDE_TOP),
		"反向对照：常态上内边距没有这个位移")


# ---------------------------------------------------------------- #1 端口 Ø32

## §1.1：端口「中心 (0,36)/(72,36)，可见直径 12 / 命中直径 32 逻辑 = 64 设备；触摸命中中心与
## 可见中心一致」。PET-95 量到「输出端口只有卡身内半圆可起手，中心 / 外侧失效」——
## 根因是命中按卡身先判，而端口中心正好落在卡身边缘上（半开区间判它在外）。
func _check_port_hit(ctx: RefCounted) -> void:
	var radius: float = BoardView.PORT_HIT_RADIUS
	ctx.near(radius * 2.0, 32.0, "命中直径 32 逻辑像素")
	ctx.near(radius * 2.0 * 2.0, 64.0, "= 64 设备像素 ≥ 44 下限（G03）")
	var center: Vector2 = Vector2(200.0, 200.0)
	ctx.check(BoardView.port_hit(center, center), "正中算命中")
	ctx.check(BoardView.port_hit(center, center + Vector2(radius, 0.0)), "圆周上算命中")
	ctx.check(not BoardView.port_hit(center, center + Vector2(radius + 1.0, 0.0)),
		"反向对照：圆周外 1px 不算")

	var board: BoardModel = BoardModel.new()
	var card: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(100.0, 100.0))
	var out_port: Vector2 = BoardView.output_port(card)
	ctx.check(not BoardView.card_rect(card).has_point(out_port),
		"反向对照：端口**正中**落在卡身之外（半开区间的 has_point 判不到它）—— 这就是旧口径的病根")
	var hits: Array = BoardRenderer.hit_at(board, out_port)
	ctx.check(hits.size() == 2 and hits[0].uid == card.uid and int(hits[1]) == BoardRenderer.PORT_OUT,
		"正中起手：命中这张卡的**输出口**")
	var outer: Vector2 = out_port + Vector2(radius - 1.0, 0.0)
	ctx.check(not BoardView.card_rect(card).has_point(outer), "外侧那一点也在卡身之外")
	var outer_hits: Array = BoardRenderer.hit_at(board, outer)
	ctx.check(outer_hits.size() == 2 and outer_hits[0].uid == card.uid,
		"外侧起手：同样命中它的输出口")
	ctx.check(BoardRenderer.drop_target(board, outer) == null,
		"反向对照：输出口不是落点（落线目标为空）")
	var in_port: Vector2 = BoardView.input_port(card)
	var in_hits: Array = BoardRenderer.hit_at(board, in_port)
	ctx.check(in_hits.size() == 2 and int(in_hits[1]) == BoardRenderer.PORT_IN,
		"输入口 Ø32 也在同一套口径里（落线时才用）")
	ctx.check(BoardRenderer.drop_target(board, in_port) == card, "落线落在输入口上算这张卡")


# ---------------------------------------------------------------- 工具

static func _tinted(key: Palette.Key, alpha: float) -> Color:
	var color: Color = Palette.get_color(key)
	color.a = alpha
	return color


## WCAG 对比度（与 §3.2 / test_menu_layout 同一套算法）。
static func _contrast(a: Color, b: Color) -> float:
	var one: float = _luminance(a)
	var other: float = _luminance(b)
	return (maxf(one, other) + 0.05) / (minf(one, other) + 0.05)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


static func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)
