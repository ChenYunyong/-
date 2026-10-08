## test_combat_paint.gd
## 职责：战斗屏**画法**的验收 —— 角色表逐条落在 §3 指定的 Token 上、暗底上的读数与标记读得出、
##       §3.2 的对比度数字逐条对得上、线一律经 StrokePainter 落笔、战场里没有卡牌连接大图（C01）。
## 所属系统：tests
## 依赖：CombatTheme, CombatView, Palette
## 禁止：本文件不得写入配色常量，只断言 —— 数字的唯一来源是 CombatTheme / Palette / docs/14。
##
## 为什么「取色」要逐条对而不是看一眼：色值一旦在某个落笔处被就地改掉（换成另一个近似的蓝），
## 屏幕上看不出区别，而 §3 的语义分工已经断了 —— 那时没有任何东西会响。这里把每个角色
## 钉在它该取的那一格 Token 上，改坏了就是一条红的算术。
##
## 版式在 test_combat_layout，装配之后的真 rect 在 combat_screen_smoke。

extends RefCounted

## 06 §11 的正文对比度下限；关键边 / 图标 >= 3:1（§4 G04）。
const MIN_CONTRAST: float = 4.5
const MIN_EDGE_CONTRAST: float = 3.0
## §3.2 那张表是算出来的，容差只留给浮点尾巴。
const CONTRAST_TOLERANCE: float = 0.01
## 本工程判「两个颜色已经读不出区别」的 RGB 欧氏距离（与 test_map_paint 同一个口径）。
const COLLAPSE_DISTANCE: float = 96.0

const UI_DIR: String = "res://scripts/ui"
## 屏③ 的两支画笔。它们只许把几何交给 StrokePainter，也不许把编辑器的连线搬进来。
const PAINTERS: PackedStringArray = ["combat_view.gd", "combat_chain.gd"]

## §3 的「视觉角色 → 既有 Token」，逐字抄成一张待查表（17 行里的这一屏那几行）。
const ROLE_TOKENS: Dictionary = {
	CombatTheme.Role.FIELD_INK: Palette.Key.BLUE_100,
	CombatTheme.Role.CARD_FILL: Palette.Key.NAVY_800,
	CombatTheme.Role.CARD_INK: Palette.Key.BLUE_100,
	CombatTheme.Role.CORE_BODY: Palette.Key.NAVY_800,
	CombatTheme.Role.CORE_FRAME: Palette.Key.GOLD_600,
	CombatTheme.Role.CORE_INK: Palette.Key.BLUE_100,
	CombatTheme.Role.ENEMY_BODY: Palette.Key.BROWN_400,
	CombatTheme.Role.ENEMY_OUTLINE: Palette.Key.GREY_300,
	CombatTheme.Role.ENEMY_DANGER: Palette.Key.RED_400,
	CombatTheme.Role.BOLT_BASE: Palette.Key.NAVY_600,
	CombatTheme.Role.BOLT_CORE: Palette.Key.BLUE_400,
	CombatTheme.Role.EMPHASIS: Palette.Key.GOLD_500,
	CombatTheme.Role.CHAIN_MORE: Palette.Key.GREY_300,
	CombatTheme.Role.HP_FILL: Palette.Key.RED_500,
	CombatTheme.Role.MANA_FILL: Palette.Key.BLUE_500,
}


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_combat_paint")
	_check_role_tokens(ctx)
	_check_contrast(ctx)
	_check_bar_fills(ctx)
	_check_bolt_layers(ctx)
	_check_unified_pen(ctx)
	_check_no_links(ctx)


## 每一个角色都登记过，而且登记的就是 §3 那一格。
func _check_role_tokens(ctx: RefCounted) -> void:
	var roles: Array = CombatTheme.Role.values()
	ctx.equal(CombatTheme.role_count(), roles.size(), "角色表的登记数与枚举数一致（%d）" % roles.size())
	ctx.equal(ROLE_TOKENS.size(), roles.size(), "§3 抄下来的表覆盖了全部 %d 个角色" % roles.size())
	for role: int in roles:
		if not ctx.check(ROLE_TOKENS.has(role), "角色 %d 在 §3 表里有对应" % role):
			continue
		ctx.equal(CombatTheme.token_of(role), ROLE_TOKENS[role],
			"角色 %d 取 %s" % [role, ROLE_TOKENS[role]])
	# 反向对照：没登记的角色会落到兜底色（灰），而不是悄悄取一个近似的颜色。
	ctx.equal(CombatTheme.FALLBACK_TOKEN, Palette.Key.GREY_500, "漏配的兜底色是 GREY_500 而不是某一档色阶")


## §3.2 的对比度逐条对：暗底上的字与边读得出，敌人**体色本身**读不出（靠 2px 轮廓）。
func _check_contrast(ctx: RefCounted) -> void:
	var field: Color = Palette.get_color(Palette.Key.NAVY_900)
	var panel: Color = Palette.get_color(Palette.Key.NAVY_800)
	var rows: Array = [
		["战场读数墨", CombatTheme.Role.FIELD_INK, field, MIN_CONTRAST, 13.604],
		["卡墨", CombatTheme.Role.CARD_INK, panel, MIN_CONTRAST, 11.754],
		["装置核墨", CombatTheme.Role.CORE_INK, panel, MIN_CONTRAST, 11.754],
		["装置金框", CombatTheme.Role.CORE_FRAME, panel, MIN_EDGE_CONTRAST, 5.749],
		["链尾标记", CombatTheme.Role.CHAIN_MORE, panel, MIN_CONTRAST, 9.368],
		["当前施法强调", CombatTheme.Role.EMPHASIS, panel, MIN_EDGE_CONTRAST, 9.396],
		["敌群轮廓", CombatTheme.Role.ENEMY_OUTLINE, field, MIN_EDGE_CONTRAST, 10.842],
	]
	for row: Array in rows:
		var value: float = _contrast(CombatTheme.color(row[1]), row[2])
		ctx.near(value, row[4], "%s 的对比度 = §3.2 的 %.3f" % [row[0], row[4]], CONTRAST_TOLERANCE)
		ctx.check(value >= float(row[3]), "%s 读得出（%.3f ≥ %.1f）" % [row[0], value, row[3]])
	# 反向对照：敌群体色**单独**读不出（BROWN_400 对 NAVY_900 只有 2.068）——
	# §3 让它配一条 2px 的 GREY_300 轮廓，可读性是那条轮廓赚来的，不是体色。
	var body: float = _contrast(CombatTheme.color(CombatTheme.Role.ENEMY_BODY), field)
	ctx.near(body, 2.068, "敌群体色的对比度 = §3.2 的 2.068", CONTRAST_TOLERANCE)
	ctx.check(body < MIN_EDGE_CONTRAST, "体色本身读不出（%.3f < %.1f），故轮廓那一笔不能省" % [body, MIN_EDGE_CONTRAST])


## 两条读数条**含义不同**，不能取同一个颜色；各自与条槽（NAVY_900）也得分得开。
func _check_bar_fills(ctx: RefCounted) -> void:
	var track: Color = Palette.get_color(Palette.Key.NAVY_900)
	var hp: Color = CombatTheme.color(CombatTheme.Role.HP_FILL)
	var mana: Color = CombatTheme.color(CombatTheme.Role.MANA_FILL)
	ctx.near(_contrast(hp, track), 3.713, "血条填充对条槽 = §3.2 的 3.713", CONTRAST_TOLERANCE)
	ctx.near(_contrast(mana, track), 8.083, "法力填充对条槽 = §3.2 的 8.083", CONTRAST_TOLERANCE)
	ctx.check(_contrast(hp, track) >= MIN_EDGE_CONTRAST, "血条填充在槽里看得见（≥3:1）")
	ctx.check(_rgb_distance(hp, mana) >= COLLAPSE_DISTANCE,
		"血条与法力条不是一家的颜色（距离 %.1f）" % _rgb_distance(hp, mana))
	# 危险标记取 RED_400（暗底上的小字那一档），不是只用来画条的 RED_500（§3）。
	ctx.check(CombatTheme.color(CombatTheme.Role.ENEMY_DANGER)
		!= CombatTheme.color(CombatTheme.Role.HP_FILL), "危险标记与血条填充不是同一个 Token")


## 丝线是两层：底宽芯窄、底暗芯亮 —— 单层线在深底上会糊成一片。
func _check_bolt_layers(ctx: RefCounted) -> void:
	var base: Color = CombatTheme.color(CombatTheme.Role.BOLT_BASE)
	var core: Color = CombatTheme.color(CombatTheme.Role.BOLT_CORE)
	ctx.check(_luminance(core) > _luminance(base), "芯比底亮（%.4f > %.4f）" % [_luminance(core), _luminance(base)])
	ctx.check(_rgb_distance(base, core) >= COLLAPSE_DISTANCE,
		"底与芯分得开（距离 %.1f）" % _rgb_distance(base, core))
	ctx.equal(CombatView.BOLT_BASE_WIDTH, 4.0, "丝线底宽 4（§3）")
	ctx.equal(CombatView.BOLT_CORE_WIDTH, 2.0, "丝线芯宽 2（§3）")
	ctx.check(CombatView.BOLT_BASE_WIDTH > CombatView.BOLT_CORE_WIDTH, "底比芯宽，芯才露得出来")


## 屏③这一摊不许另起一支笔 —— 线宽 / 端点 / 圆角只有 StrokePainter 一处定义。
func _check_unified_pen(ctx: RefCounted) -> void:
	var sources: Dictionary = {}
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in _gd_files(UI_DIR):
		var code: String = _code_only(path)
		sources[path.get_file()] = code
		for call: String in ["draw_line(", "draw_polyline(", "draw_arc(", "draw_dashed_line("]:
			if code.contains(call):
				offenders.append("%s 直接调 %s" % [path.get_file(), call])
	ctx.equal(offenders.size(), 0,
		"线一律经 StrokePainter 落笔" if offenders.is_empty() else "绕过笔：%s" % "; ".join(offenders))
	for file: String in PAINTERS:
		ctx.check(String(sources.get(file, "")).contains("StrokePainter."), "%s 经 StrokePainter 落笔" % file)
	# 反向对照：扫描确实读到了文件（否则上面那些「没违规」是空扫描换来的）。
	ctx.check(sources.size() > PAINTERS.size(), "扫描读到了 %d 个文件" % sources.size())


## C01：战场里**没有**卡牌连接大图。编辑器的连线笔（ThreadPainter）不许被搬进这一屏，
## 战场那一层也不许画卡 —— 卡只出现在尾栏那条 4 格的链上。
func _check_no_links(ctx: RefCounted) -> void:
	for file: String in PAINTERS:
		var code: String = _code_only("%s/%s" % [UI_DIR, file])
		ctx.check(not code.contains("ThreadPainter"), "%s 没有搬进编辑器的连线笔（C01）" % file)
	var field_code: String = _code_only("%s/combat_view.gd" % UI_DIR)
	ctx.check(not field_code.contains("CardFace"), "战场里不画卡（C01：卡牌连接大图占比 = 0）")
	var chain_code: String = _code_only("%s/combat_chain.gd" % UI_DIR)
	ctx.check(not chain_code.contains("ThreadPainter"), "卡链也不连线 —— 它只排 4 张卡")
	ctx.check(chain_code.contains("CardFace.paint"), "卡链用的是编辑器那一张卡面（同一张脸）")


# ---------------------------------------------------------------- 工具

## 两个颜色在 0-255 的 RGB 空间里的欧氏距离。
static func _rgb_distance(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length() * 255.0


## WCAG 对比度。
static func _contrast(a: Color, b: Color) -> float:
	var one: float = _luminance(a)
	var other: float = _luminance(b)
	return (maxf(one, other) + 0.05) / (minf(one, other) + 0.05)


static func _luminance(color: Color) -> float:
	return 0.2126 * _channel(color.r) + 0.7152 * _channel(color.g) + 0.0722 * _channel(color.b)


static func _channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 else pow((value + 0.055) / 1.055, 2.4)


func _gd_files(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = "%s/%s" % [root, entry]
		if dir.current_is_dir():
			found.append_array(_gd_files(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


## 源码去掉注释与空行 —— 注释里提到 draw_line( 不算违规，真正调了才算。
func _code_only(path: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			kept.append(line)
	return "\n".join(kept)
