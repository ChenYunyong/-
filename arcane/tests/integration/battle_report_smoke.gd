## battle_report_smoke.gd
## 职责：战后详情（`docs/14 §2.3` 的 C02）的验收 —— 战斗屏释放后完整链 / 八通道 / 施法记录仍在，
##       而且**换屏之后**结算屏上真的把这些念了出来。
## 所属系统：tests
## 依赖：CombatSim, BattleReport, RunState, CardCatalog, TreeProbe
## 禁止：本文件不得按任何按钮，也不得换 GameFlow 的状态 —— 它只往 RunState 里记一份快照，
##       把结算屏装进树里数一遍，然后自己把那一屏撤掉。
##
## 为什么是集成层而不是纯数据测试：「其余链信息**仍可查**」的判据在屏上 —— 只在数据层量到
## 「快照里还有」等于什么都没证明。PET-95 视觉终验给的复验口径是：≥5 卡、8 通道样本，
## UI 项数 N/8、顺序和值与快照一致、遗漏 0；控制台打印不算玩家可访问。
##
## 收尾沿用 scene_smoke 的约定：这一局留下的记录不清，后面的用例都会先 start_run()
## 把它清掉（RunState.start_run 会清空战后详情）。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCREEN_PATH: String = "res://scenes/result.tscn"
## Codex 定的样本下限：链至少 5 张；通道恰好 8 条（八条一条都不能漏）。
const MIN_CHAIN: int = 5
## 书页上连成一条链的卡：两张法术卡在前（先打出去，流水里才有真的施法记录），
## 八张功能卡在后（八条通道逐个点亮）。链长 10，远超 C02 屏上那个 4 张窗口。
const CHAIN_CARDS: PackedStringArray = [
	"ab_fire", "ab_ice",
	"fn_enchant", "fn_projectile", "fn_burst", "fn_haste",
	"fn_attack_speed", "fn_slow", "fn_cooldown", "fn_loop",
]
## 推多少拍再取快照：够让队列真的转过几轮（有施法、有伤害），又远没到波次收场。
const SAMPLE_TICKS: int = 80


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("battle_report_smoke")
	var report: BattleReport = _capture_sample(ctx)
	if report == null:
		return
	ctx.check(report.chain_size() >= MIN_CHAIN,
		"样本链有 %d 张（≥%d）" % [report.chain_size(), MIN_CHAIN])
	ctx.equal(report.channel_count(), 8, "八条通道一条不少（数到 %d）" % report.channel_count())
	ctx.check(report.casts > 0, "这一场真的打出去了 %d 次" % report.casts)
	ctx.check(report.strike_count() > 0, "施法流水有 %d 段伤害" % report.strike_count())
	# 换屏：快照交给 RunState，战斗对象就此丢掉引用 —— 结算屏只能从快照念。
	RunState.record_battle(report)
	ctx.check(RunState.last_battle_report() == report, "快照进了 RunState（换屏后还查得到）")
	await _check_result_screen(ctx, tree, report)


## 造一份「≥5 卡 / 8 通道」的样本快照，并当场核「快照 == 仿真此刻的状态」。
## 功能卡要**真的轮到**才生效，推几十拍未必八张都上过，故最后把八张补 apply 一次 ——
## 复验要的是「八条都在、值对得上」，不是「运气好八张都放过」。
func _capture_sample(ctx: RefCounted) -> BattleReport:
	var board: BoardModel = _sample_board(ctx)
	if board == null:
		return null
	var sim: CombatSim = CombatSim.new()
	sim.begin(board, 1)
	sim.advance(SAMPLE_TICKS)
	for index: int in CHAIN_CARDS.size():
		var card: CardData = CardCatalog.find(StringName(CHAIN_CARDS[index]))
		if card != null:
			sim.mods().apply(card)
	var expected_ids: Array[StringName] = []
	for card: CardData in sim.cast_order():
		expected_ids.append(card.id)
	var expected_channels: PackedInt32Array = sim.mods().channel_stacks()
	var report: BattleReport = BattleReport.capture(sim)
	_check_matches(ctx, report, expected_ids, expected_channels)
	# 快照是**拷贝**：仿真继续往前走，已经交出去的那一份不许跟着变（上面那组对照值就是锚）。
	sim.advance(CombatSim.CAST_INTERVAL_TICKS)
	_check_matches(ctx, report, expected_ids, expected_channels)
	return report


## 样本书页：核心 → 十张卡首尾相连（见 CHAIN_CARDS），没有外挂的孤立卡。
func _sample_board(ctx: RefCounted) -> BoardModel:
	var board: BoardModel = BoardModel.new()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(20.0, 20.0))
	var previous: int = core.uid
	for index: int in CHAIN_CARDS.size():
		var placed: BoardModel.PlacedCard = board.add_card(
			StringName(CHAIN_CARDS[index]), Vector2(120.0 + 60.0 * float(index), 20.0))
		if placed == null:
			ctx.check(false, "样本里的 %s 加不进书页" % CHAIN_CARDS[index])
			return null
		board.connect_cards(previous, placed.uid)
		previous = placed.uid
	return board


## 快照 vs 期望值：链的**顺序**与八通道的**逐条值**都要一致，一条都不能漏。
func _check_matches(ctx: RefCounted, report: BattleReport, ids: Array[StringName],
		channels: PackedInt32Array) -> void:
	ctx.equal(report.chain_size(), ids.size(), "快照链与仿真队列同长（%d）" % ids.size())
	for index: int in ids.size():
		if index < report.chain_size():
			ctx.equal(report.chain_id_at(index), ids[index], "第 %d 张链上卡与队列同序" % (index + 1))
	ctx.equal(report.channels, channels, "八通道逐条值与 CombatMods 一致")


## 换屏：把结算屏装进树里，数它念出来的链 / 通道 / 施法记录。
func _check_result_screen(ctx: RefCounted, tree: SceneTree, report: BattleReport) -> void:
	var packed: PackedScene = load(SCREEN_PATH)
	if not ctx.check(packed != null, "%s 可加载" % SCREEN_PATH):
		return
	var screen: Control = packed.instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	var texts: PackedStringArray = _label_texts(screen)
	ctx.check(texts.size() > 0, "结算屏上有 %d 行字" % texts.size())
	_check_chain_line(ctx, texts, report)
	_check_channel_line(ctx, texts, report)
	_check_cast_line(ctx, texts, report)
	screen.queue_free()
	await tree.process_frame


## 完整链：屏上那一行必须按**快照的顺序**写全 N 张（顺序变了就等于换屏后换了队列）。
func _check_chain_line(ctx: RefCounted, texts: PackedStringArray, report: BattleReport) -> void:
	var head: String = TranslationServer.translate("完整施法链 %d 张") % report.chain_size()
	var line: String = _find(texts, head)
	if not ctx.check(not line.is_empty(), "结算屏写了「%s」" % head):
		return
	var cursor: int = -1
	var ordered: bool = true
	for index: int in report.chain_size():
		var card: CardData = CardCatalog.find(report.chain_id_at(index))
		var shown: String = TranslationServer.translate(card.name_key) if card != null else ""
		var at: int = line.find(shown)
		if shown.is_empty() or at <= cursor:
			ordered = false
		cursor = at
	ctx.check(ordered, "链上 %d 张按快照顺序写在同一行里" % report.chain_size())


## 八通道：屏上必须八条都在、名字与值逐条对上快照（漏一条就不是「其余链信息仍可查」）。
func _check_channel_line(ctx: RefCounted, texts: PackedStringArray, report: BattleReport) -> void:
	var line: String = _find(texts, TranslationServer.translate("八通道明细"))
	if not ctx.check(not line.is_empty(), "结算屏写了「八通道明细」"):
		return
	var fns: PackedInt32Array = CombatMods.CHANNEL_FNS
	var missing: PackedStringArray = PackedStringArray()
	for index: int in mini(report.channel_count(), fns.size()):
		var label: String = String(CardCatalog.FUNCTION_NAME_KEY.get(int(fns[index]), ""))
		var entry: String = "%s %d" % [TranslationServer.translate(label), report.channels[index]]
		if not line.contains(entry):
			missing.append(entry)
	ctx.equal(missing.size(), 0, "八条通道逐条对得上（漏：%s）" % ", ".join(missing))


## 施法记录：打的次数必须与快照一致。
func _check_cast_line(ctx: RefCounted, texts: PackedStringArray, report: BattleReport) -> void:
	var want: String = TranslationServer.translate("施法记录 %d 次") % report.casts
	ctx.check(not _find(texts, want).is_empty(), "结算屏写了「%s」" % want)


func _label_texts(root: Node) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for node: Node in TreeProbe.find_all(root, "Label"):
		texts.append((node as Label).text)
	return texts


func _find(texts: PackedStringArray, needle: String) -> String:
	for text: String in texts:
		if text.contains(needle):
			return text
	return ""
