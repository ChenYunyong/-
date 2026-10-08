## test_combat_layout.gd
## 职责：战斗屏版面的验收 —— docs/14 §2.3 的几何表逐条对照，外加 §4 的 C01/C02/C03 面积与读数账。
## 所属系统：tests
## 依赖：CombatLayout, ContractTheme, ContractScreenTheme, UiKit, BoardModel
## 禁止：本文件不得写入布局常量，只断言 —— 数字的唯一来源是 CombatLayout / docs/14。
##
## 布局错位在 headless 下**不会报错**，只会让真机上两个控件叠在一起。而 §2.3 的「rect @960」
## 列把每个数字都给死了，所以这里的断言就是**逐字对照** —— 常量抄错一个数，test 立刻红。
## C03 那三个边界读数（0 / 64 / 214）是**算**出来的，不是画出来再量的。
##
## 版式在 CombatLayout，画法在 test_combat_paint，装配之后的真 rect 在 combat_screen_smoke。

extends RefCounted

## 窗口 / 画布 = 2，来自 project.godot。触控下限 44 **设备像素**换算成 22 逻辑像素。
const DEVICE_SCALE: float = 2.0
const MIN_TOUCH_DEVICE_PX: float = 44.0
## docs/14 §1 的最小互动矩形。
const MIN_INTERACTIVE: float = 24.0
## §4 C01：内战场面积占安全区的下限。C03：敌群 HP 24/80 时血条内宽。
const C01_FIELD_RATIO_MIN: float = 0.50
const C01_FIELD_RATIO: float = 0.50718
const C03_HP_INNER: float = 64.0
## §1 的间距档位。
const SPACING_SCALE: Array[float] = [4.0, 8.0, 12.0, 16.0, 24.0]

const LOCALES: PackedStringArray = ["zh_CN", "en"]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_combat_layout")
	_check_screen_matches_project(ctx)
	_check_stacking(ctx)
	_check_header(ctx)
	_check_bars(ctx)
	_check_field(ctx)
	_check_footer(ctx)
	_check_chain(ctx)
	_check_result(ctx)
	_check_window(ctx)
	_check_touch_targets(ctx)
	_check_spacing_system(ctx)
	_check_both_locales(ctx, tree)


func _check_screen_matches_project(ctx: RefCounted) -> void:
	ctx.equal(CombatLayout.SCREEN.x, ProjectSettings.get_setting("display/window/size/viewport_width"),
		"布局基准宽 = project.godot 的画布宽")
	ctx.equal(CombatLayout.SCREEN.y, ProjectSettings.get_setting("display/window/size/viewport_height"),
		"布局基准高 = project.godot 的画布高")
	ctx.check(Rect2(Vector2.ZERO, CombatLayout.SCREEN).encloses(CombatLayout.SAFE_AREA), "安全区落在画布内")


## §2.3 的三段纵向账：16 + 头栏 56 + 12 + 纸框 312 + 12 + 底栏 116 + 16 = 540。
func _check_stacking(ctx: RefCounted) -> void:
	ctx.near(CombatLayout.HEADER.position.x, 16.0, "左内容边距 16")
	ctx.near(CombatLayout.HEADER.end.x, CombatLayout.SCREEN.x - 16.0, "右内容边距 16")
	ctx.near(CombatLayout.HEADER.size.y, 56.0, "头栏高 56")
	ctx.near(CombatLayout.PAPER_FRAME.position.y, CombatLayout.HEADER.end.y + 12.0, "头栏到纸框 12")
	ctx.near(CombatLayout.FOOTER.position.y, CombatLayout.PAPER_FRAME.end.y + 12.0, "纸框到底栏 12")
	ctx.near(CombatLayout.FOOTER.end.y, CombatLayout.SCREEN.y - 16.0, "底栏下边距 16")
	ctx.near(CombatLayout.HEADER.size.y + CombatLayout.PAPER_FRAME.size.y + CombatLayout.FOOTER.size.y,
		CombatLayout.SCREEN.y - 16.0 - 12.0 - 12.0 - 16.0, "56 + 312 + 116 = 540 − 上下留白与两处净空")
	ctx.equal(CombatLayout.PAPER_FRAME.size, Vector2(928.0, 312.0), "COMBAT_PAPER_FRAME 928×312")
	ctx.check(CombatLayout.PAPER_FRAME.encloses(CombatLayout.FIELD), "战场嵌在纸框里")


## 头栏 56 里四组读数：屏标题 / 魔力（标签 + 数值，**不画条**）/ 波次 / 敌群（标签 + 数值 + 条）。
func _check_header(ctx: RefCounted) -> void:
	var head: Rect2 = CombatLayout.HEADER
	for pair: Array in [["标题", CombatLayout.TITLE_RECT], ["魔力标签", CombatLayout.MANA_LABEL_RECT],
			["波次", CombatLayout.WAVE_RECT], ["敌群标签", CombatLayout.ENEMY_LABEL_RECT],
			["魔力槽位（保留空位）", CombatLayout.MANA_TRACK], ["敌群条", CombatLayout.ENEMY_HP_TRACK]]:
		ctx.check(head.encloses(pair[1]), "%s 在头栏内" % pair[0])
	ctx.equal(CombatLayout.TITLE_RECT.size, Vector2(176.0, 32.0), "COMBAT_TITLE 176×32")
	ctx.near(CombatLayout.TITLE_RECT.position.x - head.position.x, 12.0, "标题左内缩 12")
	ctx.equal(CombatLayout.WAVE_RECT.size, Vector2(256.0, 32.0), "COMBAT_WAVE 256×32（一级元素，与标题同档）")
	ctx.equal(CombatLayout.ENEMY_LABEL_RECT.size, Vector2(216.0, 24.0), "ENEMY_HP_LABEL 216×24")
	ctx.equal(CombatLayout.ENEMY_HP_TRACK.size, Vector2(216.0, 12.0), "ENEMY_HP_TRACK 216×12")
	ctx.equal(CombatLayout.MANA_LABEL_RECT.size, Vector2(192.0, 24.0), "MANA_LABEL 192×24")
	ctx.equal(CombatLayout.MANA_TRACK.size, Vector2(192.0, 12.0), "MANA_TRACK 192×12（槽位保留，不画）")
	ctx.near(CombatLayout.MANA_TRACK.position.y - CombatLayout.MANA_LABEL_RECT.end.y,
		CombatLayout.SPACING_4, "魔力标签到槽位 4")
	ctx.near(CombatLayout.ENEMY_HP_TRACK.position.y - CombatLayout.ENEMY_LABEL_RECT.end.y,
		CombatLayout.SPACING_4, "敌群标签到条 4")
	# 四组读数各占一栏，谁也不压谁。
	var columns: Array[Rect2] = [CombatLayout.TITLE_RECT, CombatLayout.MANA_LABEL_RECT,
		CombatLayout.WAVE_RECT, CombatLayout.ENEMY_LABEL_RECT]
	for index: int in columns.size():
		for other: int in range(index + 1, columns.size()):
			ctx.check(not _overlaps(columns[index], columns[other]),
				"头栏第 %d 栏与第 %d 栏不重叠" % [index, other])
	ctx.check(CombatLayout.MANA_TRACK.position.x >= CombatLayout.TITLE_RECT.end.x, "魔力那一栏排在标题右边")


## C03：条的外高 12、内高 10、内缩 1；填充宽 = floor((外宽 − 2) × 比例)；0/30/100% = 0/64/214。
## 法力**没有条**（仿真无容量字段，PET-95 裁定整条不画）：MANA_TRACK 只是保留的布局空位，
## 「屏上真的没画」由 combat_screen_smoke 的实机断言量 —— 本文件只有数字，量不了有没有控件。
func _check_bars(ctx: RefCounted) -> void:
	ctx.equal(CombatLayout.BAR_INSET, 1.0, "填充内缩 1（§2.3）")
	ctx.equal(CombatLayout.BAR_INNER_HEIGHT, 10.0, "内高 10（§2.3）")
	var track: Rect2 = CombatLayout.ENEMY_HP_TRACK
	ctx.equal(CombatLayout.bar_fill_rect(track, 0.0).size.x, 0.0, "C03：0% 时内宽 0")
	ctx.equal(CombatLayout.bar_fill_rect(track, 24.0 / 80.0).size.x, C03_HP_INNER, "C03：敌群 HP 24/80 时内宽 64")
	ctx.equal(CombatLayout.bar_fill_rect(track, 1.0).size.x, 214.0, "C03：100% 时内宽 214")
	ctx.near(CombatLayout.MANA_TRACK.position.x, CombatLayout.MANA_LABEL_RECT.position.x, "法力槽位与标签同列（不挪数字）")
	for ratio: float in [0.0, 0.3, 1.0]:
		var fill: Rect2 = CombatLayout.bar_fill_rect(track, ratio)
		ctx.equal(fill.size.y, CombatLayout.BAR_INNER_HEIGHT, "填充内高就是 10")
		ctx.check(track.encloses(fill) or fill.size.x <= track.size.x - 2.0,
			"比例 %.1f 的填充不越出条槽" % ratio)
	# 越界的比例不许画出条外（clamp，而不是让它溢出）。
	ctx.equal(CombatLayout.bar_fill_rect(track, 2.0).size.x, 214.0, "比例 >1 被夹住")
	ctx.equal(CombatLayout.bar_fill_rect(track, -1.0).size.x, 0.0, "比例 <0 被夹住")


## C01：内战场 896×280 ≥ 安全区的 50%，而且必须装得下装置与敌群两个美术包络。
func _check_field(ctx: RefCounted) -> void:
	ctx.equal(CombatLayout.FIELD.size, Vector2(896.0, 280.0), "COMBAT_FIELD 896×280")
	ctx.near(CombatLayout.FIELD.position.x - CombatLayout.PAPER_FRAME.position.x, 16.0, "战场左内缩 16")
	ctx.near(CombatLayout.FIELD.end.x, CombatLayout.PAPER_FRAME.end.x - 16.0, "战场右内缩 16")
	ctx.near(CombatLayout.FIELD.position.y - CombatLayout.PAPER_FRAME.position.y, 16.0, "战场顶内缩 16")
	ctx.near(CombatLayout.PAPER_FRAME.end.y - CombatLayout.FIELD.end.y, 16.0, "战场底内缩 16")
	var safe: float = CombatLayout.SAFE_AREA.size.x * CombatLayout.SAFE_AREA.size.y
	var ratio: float = CombatLayout.FIELD.size.x * CombatLayout.FIELD.size.y / safe
	ctx.near(ratio, C01_FIELD_RATIO, "C01 战场占安全区 %.5f" % ratio)
	ctx.check(ratio >= C01_FIELD_RATIO_MIN, "C01 战场 ≥ 50%%（%.5f）" % ratio)
	ctx.check(CombatLayout.FIELD.encloses(CombatLayout.CORE_DEVICE), "装置包络在战场里")
	ctx.check(CombatLayout.FIELD.encloses(CombatLayout.ENEMY_PRESENTATION), "敌群包络在战场里")
	ctx.equal(CombatLayout.CORE_DEVICE.size, Vector2(72.0, 96.0), "CORE_DEVICE 72×96（美术包络）")
	ctx.equal(CombatLayout.ENEMY_PRESENTATION.size, Vector2(288.0, 156.0), "ENEMY_PRESENTATION 288×156")
	ctx.check(not _overlaps(CombatLayout.CORE_DEVICE, CombatLayout.ENEMY_PRESENTATION), "装置与敌群不叠在一起")
	# C01：战场是**最大单一信息区** —— 比头栏和底栏都大。
	var field_area: float = CombatLayout.FIELD.size.x * CombatLayout.FIELD.size.y
	ctx.check(field_area > CombatLayout.FOOTER.size.x * CombatLayout.FOOTER.size.y, "战场比底栏大")
	ctx.check(field_area > CombatLayout.HEADER.size.x * CombatLayout.HEADER.size.y, "战场比头栏大")


## 底栏 116：当前读数 / 卡链 / 队列加成 / 结果行。
func _check_footer(ctx: RefCounted) -> void:
	var foot: Rect2 = CombatLayout.FOOTER
	ctx.equal(foot.size, Vector2(928.0, 116.0), "COMBAT_FOOTER 928×116")
	for pair: Array in [["当前读数", CombatLayout.ACTIVE_READOUT], ["卡链", CombatLayout.ACTIVE_CHAIN],
			["队列加成", CombatLayout.QUEUE_BONUS], ["结算键", CombatLayout.DONE_BUTTON]]:
		ctx.check(foot.encloses(pair[1]), "%s 在底栏内" % pair[0])
	ctx.near(CombatLayout.ACTIVE_READOUT.position.x - foot.position.x, 16.0, "当前读数左内缩 16")
	ctx.near(CombatLayout.ACTIVE_CHAIN.position.x - CombatLayout.ACTIVE_READOUT.end.x, 16.0, "读数与卡链间距 16")
	ctx.near(CombatLayout.QUEUE_BONUS.position.x - CombatLayout.ACTIVE_CHAIN.end.x, 16.0, "卡链与队列加成间距 16")
	ctx.near(CombatLayout.QUEUE_BONUS.end.x, foot.end.x - 16.0, "队列加成右内缩 16")
	ctx.equal(CombatLayout.ACTIVE_READOUT.size, Vector2(200.0, 72.0), "ACTIVE_READOUT 200×72")
	ctx.equal(CombatLayout.QUEUE_BONUS.size, Vector2(312.0, 72.0), "QUEUE_BONUS 312×72")
	# 当前读数内缩 8：名 20/28 在上、数值 16/24 在下，两行接续。
	ctx.near(CombatLayout.ACTIVE_NAME_RECT.position.x - CombatLayout.ACTIVE_READOUT.position.x, 8.0, "读数内缩 8")
	ctx.near(CombatLayout.ACTIVE_NAME_RECT.size.y, 28.0, "当前施法名行高 28（20/28）")
	ctx.near(CombatLayout.ACTIVE_VALUE_RECT.size.y, 24.0, "当前施法数值行高 24（16/24）")
	ctx.near(CombatLayout.ACTIVE_VALUE_RECT.position.y, CombatLayout.ACTIVE_NAME_RECT.end.y, "两行接续")
	ctx.check(CombatLayout.ACTIVE_READOUT.encloses(CombatLayout.ACTIVE_NAME_RECT)
		and CombatLayout.ACTIVE_READOUT.encloses(CombatLayout.ACTIVE_VALUE_RECT), "两行都在读数位里")
	# 队列加成：标题 1 行 24 + 摘要 2 行 40 = 64 ≤ 72 − 8（底部余量）。
	ctx.near(CombatLayout.QUEUE_TITLE_RECT.position.x - CombatLayout.QUEUE_BONUS.position.x, 8.0, "加成内缩 8")
	ctx.equal(CombatLayout.QUEUE_TITLE_RECT.size.y, 24.0, "标题 1 行 24（16/24）")
	ctx.equal(CombatLayout.QUEUE_SUMMARY_RECT.size.y, 40.0, "摘要 2 行 40（12/20）")
	ctx.near(CombatLayout.QUEUE_SUMMARY_RECT.position.y, CombatLayout.QUEUE_TITLE_RECT.end.y, "摘要紧接标题")
	ctx.check(CombatLayout.QUEUE_BONUS.encloses(CombatLayout.QUEUE_SUMMARY_RECT), "摘要不越出面板")
	ctx.near(CombatLayout.QUEUE_BONUS.end.y - CombatLayout.QUEUE_SUMMARY_RECT.end.y, 8.0,
		"面板底还余 8（24 + 40 = 64 ≤ 72 − 8）")
	ctx.check(not _overlaps(CombatLayout.ACTIVE_READOUT, CombatLayout.ACTIVE_CHAIN)
		and not _overlaps(CombatLayout.ACTIVE_CHAIN, CombatLayout.QUEUE_BONUS), "底栏三块互不重叠")


## 卡链：4 张 72 方卡、间距 12，右端留 28 给「后面还有」的标记（C02：最多 4 张同时可见）。
func _check_chain(ctx: RefCounted) -> void:
	ctx.equal(CombatLayout.CHAIN_SLOTS, 4, "卡链最多 4 张（C02）")
	ctx.equal(CombatLayout.ACTIVE_CHAIN.size, Vector2(352.0, 72.0), "ACTIVE_CHAIN 352×72")
	ctx.equal(BoardModel.CARD_SIZE, Vector2(72.0, 72.0), "卡是编辑器那一张 72 方卡")
	var last: Rect2 = CombatLayout.chain_card_rect(CombatLayout.CHAIN_SLOTS - 1, CombatLayout.CHAIN_SLOTS)
	ctx.near(last.position.x - CombatLayout.ACTIVE_CHAIN.position.x,
		float(CombatLayout.CHAIN_SLOTS - 1) * (BoardModel.CARD_SIZE.x + CombatLayout.CHAIN_GAP),
		"第 4 张的落点 = 3 × (72 + 12)")
	ctx.near(last.end.x, CombatLayout.chain_mark_rect().position.x, "标记紧接在第 4 张右边")
	ctx.near(CombatLayout.chain_mark_rect().end.x, CombatLayout.ACTIVE_CHAIN.end.x, "标记贴住右缘")
	ctx.equal(CombatLayout.chain_mark_rect().size.x, 28.0, "标记带宽 28")
	ctx.near(float(CombatLayout.CHAIN_SLOTS) * BoardModel.CARD_SIZE.x
		+ float(CombatLayout.CHAIN_SLOTS - 1) * CombatLayout.CHAIN_GAP, 324.0, "4 张卡加 3 道 12 的间距 = 324")
	ctx.near(324.0 + 28.0, CombatLayout.ACTIVE_CHAIN.size.x, "324 + 28 = 352")
	ctx.check(CombatLayout.chain_card_rect(CombatLayout.CHAIN_SLOTS, CombatLayout.CHAIN_SLOTS).size == Vector2.ZERO,
		"第 5 张没有落点（窗口只有 4 格）")
	ctx.check(CombatLayout.ACTIVE_CHAIN.encloses(last), "第 4 张在卡链里")
	# 当前施法那张的外扩：82 的包络塞得进 84 的间距（§1.1 的 Selected 外扩 5 + 轮廓 4）。
	ctx.near(BoardModel.CARD_SIZE.x + 10.0, 82.0, "强调包络 82")
	ctx.check(BoardModel.CARD_SIZE.x + 10.0 <= BoardModel.CARD_SIZE.x + CombatLayout.CHAIN_GAP,
		"外扩后的包络不越进下一格")


## 结果行与结算键：进行中只有结果行（距卡 4），结算后结果行收窄到 736 给按钮让位。
func _check_result(ctx: RefCounted) -> void:
	ctx.equal(CombatLayout.RESULT_RECT.size, Vector2(896.0, 20.0), "COMBAT_RESULT 896×20")
	ctx.near(CombatLayout.RESULT_RECT.position.y, CombatLayout.ACTIVE_READOUT.end.y + 4.0, "结果行距读数 4")
	ctx.near(CombatLayout.RESULT_RECT.position.x, CombatLayout.FOOTER.position.x + 16.0, "结果行左内缩 16")
	ctx.equal(CombatLayout.result_rect(false), CombatLayout.RESULT_RECT, "进行中用整行 896")
	ctx.equal(CombatLayout.result_rect(true).size.x, 736.0, "结算后收窄到 736")
	ctx.check(CombatLayout.queue_summary_visible(false), "进行中摘要可见")
	ctx.check(not CombatLayout.queue_summary_visible(true), "结算后摘要让位（只留标题那一行）")
	ctx.equal(CombatLayout.DONE_BUTTON.size, Vector2(144.0, 48.0), "COMBAT_DONE_BUTTON 144×48")
	# 让位的那 16：结果行右缘 768、按钮左缘 784。
	var settled: Rect2 = CombatLayout.result_rect(true)
	ctx.near(CombatLayout.DONE_BUTTON.position.x - settled.end.x, 16.0, "结果行与按钮间距 16")
	ctx.check(not _overlaps(settled, CombatLayout.DONE_BUTTON), "结果行不叠住按钮")
	ctx.near(CombatLayout.DONE_BUTTON.end.x, CombatLayout.FOOTER.end.x - 16.0, "按钮右内缩 16")


## C02：链条超过 4 张时，窗口是以当前施法卡为**终点**的最近 4 张，且永远含当前那张。
func _check_window(ctx: RefCounted) -> void:
	ctx.equal(CombatLayout.chain_window(-1, 0), Vector2i(0, 0), "空链条不画卡")
	ctx.equal(CombatLayout.chain_window(-1, 2), Vector2i(0, 2), "还没施法时从队首起，几张画几张")
	ctx.equal(CombatLayout.chain_window(3, 8), Vector2i(0, 4), "第 4 张时窗口还贴在队首")
	ctx.equal(CombatLayout.chain_window(4, 8), Vector2i(1, 4), "第 5 张起窗口开始跟着走")
	ctx.equal(CombatLayout.chain_window(7, 8), Vector2i(4, 4), "最后一张时窗口落在队尾")
	ctx.equal(CombatLayout.chain_window(6, 6), Vector2i(2, 4), "链条只有 6 张时窗口不越界")
	for total: int in range(1, 10):
		for current: int in total:
			var band: Vector2i = CombatLayout.chain_window(current, total)
			ctx.check(band.y == mini(total, CombatLayout.CHAIN_SLOTS),
				"链条 %d 张时窗口恒为 %d 张" % [total, mini(total, CombatLayout.CHAIN_SLOTS)])
			ctx.check(current >= band.x and current < band.x + band.y,
				"第 %d/%d 张落在窗口 [%d, %d) 里" % [current + 1, total, band.x, band.x + band.y])
			ctx.check(band.x >= 0 and band.x + band.y <= total, "窗口不越出链条")


## 触控目标：结算键 48 高 ≥ 44 设备像素；§1 的最小互动矩形 24。
func _check_touch_targets(ctx: RefCounted) -> void:
	var minimum: float = MIN_TOUCH_DEVICE_PX / DEVICE_SCALE
	var button: Rect2 = CombatLayout.DONE_BUTTON
	ctx.check(button.size.y >= minimum, "结算键高 %.0f ≥ 触控下限 %.0f" % [button.size.y, minimum])
	ctx.check(button.size.x >= MIN_INTERACTIVE and button.size.y >= MIN_INTERACTIVE,
		"结算键不小于 §1 的最小互动矩形 %s" % MIN_INTERACTIVE)
	ctx.check(CombatLayout.SAFE_AREA.encloses(button), "结算键的可交互包络不出安全区（G03）")


## 间距只能取档位（4/8/12/16/24）。28 的标记带与 1 的内缩都**不是**档位，故不该进档位表。
func _check_spacing_system(ctx: RefCounted) -> void:
	var values: Dictionary = {
		"SPACING_4": CombatLayout.SPACING_4, "SPACING_8": CombatLayout.SPACING_8,
		"SPACING_12": CombatLayout.SPACING_12, "SPACING_16": CombatLayout.SPACING_16,
		"CHAIN_GAP": CombatLayout.CHAIN_GAP,
	}
	for name: String in values:
		ctx.check(SPACING_SCALE.has(values[name]), "%s = %s 是间距系统里的档位" % [name, values[name]])
	ctx.check(not SPACING_SCALE.has(CombatLayout.CHAIN_MARK), "标记带 28 是 §2.3 给死的，不是档位")
	ctx.check(not SPACING_SCALE.has(CombatLayout.BAR_INSET), "内缩 1 不是档位")


## G10：两种语言下每一行都得放得下。英文比中文长，是最坏情况 —— 只测中文等于没测。
func _check_both_locales(ctx: RefCounted, tree: SceneTree) -> void:
	var settings: Node = tree.root.get_node_or_null(^"Settings")
	if not ctx.check(settings != null, "Settings 单例存在，可做双语断言"):
		return
	var original: String = settings.get_locale()
	for locale: String in LOCALES:
		settings.set_locale(locale, false)
		_check_text_fits(ctx, locale)
	settings.set_locale(original, false)
	ctx.equal(settings.get_locale(), original, "测试结束后语言恢复原样")


## 一行放不放得下，用的就是 UiKit 那把尺（与屏幕摆位同一处口径）。
## 摘要那一行给的是 **2 行**的预算：§2.3 的「摘要 2 行」。
func _check_text_fits(ctx: RefCounted, locale: String) -> void:
	var rows: Array = [
		["标题", _t("自动施法"), CombatLayout.TITLE_RECT, ContractTheme.FONT_TITLE],
		["波次", _t("第 %d 波 / 共 %d 波") % [1, 3], CombatLayout.WAVE_RECT, ContractTheme.FONT_TITLE],
		["魔力标签", _t("魔力"), CombatLayout.MANA_LABEL_RECT, ContractTheme.FONT_BODY],
		["敌群标签", _t("敌群"), CombatLayout.ENEMY_LABEL_RECT, ContractTheme.FONT_BODY],
		["链标题", _t("链条为空"), CombatLayout.QUEUE_TITLE_RECT, ContractTheme.FONT_BODY],
		["链序号", _t("施法链 %d/%d") % [3, 8], CombatLayout.QUEUE_TITLE_RECT, ContractTheme.FONT_BODY],
		["加成摘要", _t("无加成"), CombatLayout.QUEUE_SUMMARY_RECT, ContractTheme.FONT_CAPTION],
		["未连线提示", _t("未连接核心，不会被施放"), CombatLayout.QUEUE_SUMMARY_RECT, ContractTheme.FONT_CAPTION],
		["结算键", _t("结算"), CombatLayout.DONE_BUTTON, ContractTheme.FONT_BUTTON],
	]
	for row: Array in rows:
		var text: String = row[1]
		var width: float = UiKit.text_units(text) * float(row[3])
		# 摘要那一格是 2 行的预算，其余都是一行。
		var room: float = float(row[2].size.x)
		if row[2] == CombatLayout.QUEUE_SUMMARY_RECT:
			room = CombatLayout.QUEUE_SUMMARY_RECT.size.x * 2.0
		ctx.check(width <= room, "[%s] %s「%s」占 %.1f ≤ %.1f" % [locale, row[0], text, width, room])


## 界面上的字一律经 tr() 出来，测试这边走同一条路径取译文。
static func _t(key: String) -> String:
	return TranslationServer.translate(key)


## 严格重叠判定。Rect2.intersects() 默认把「仅相邻」也算相交，这里不要那种口径。
static func _overlaps(a: Rect2, b: Rect2) -> bool:
	return a.position.x < b.end.x and b.position.x < a.end.x \
		and a.position.y < b.end.y and b.position.y < a.end.y
