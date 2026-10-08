## full_run_smoke.gd
## 职责：一局从头打到尾的端到端冒烟 —— 开新局 → 摆卡连线 → 反复「开打 → 领奖励 →
##       在路线图上点亮下一站 → 继续」直到打穿最后一层 → 通关结算 → 再来一局
##       （新种子 ⇒ 新地图、新卡表）。
## 所属系统：tests
## 依赖：RunDriver（tests/integration/run_driver.gd）, CardCatalog, CombatSim, MapModel, RewardModel
## 禁止：本文件不得自己调 GameFlow / RunState 推进流程 —— 一律经真实按钮，
##       否则「这些屏真的接对了线」这件事没被证明。收尾要把世界摆回原样（run_driver.teardown）。
##       **唯一的例外**是 pin_seed 那一下（见下面的常量）：它不动流程，只把随机源钉死。
##
## 与 defeat_smoke 的分工：这条管**赢**（§2 的路线推进 + §3 的通关 + §4 的「开新一局」），
## 那条管**输**。两条合起来才是「一局闭环」。
##
## 这条是唯一能抓住「各屏单测都绿、拼起来走不完一局」的用例：路线推进、奖励落地、
## 通关判定、开新一局，任何一环断开它都红。

extends RefCounted

const Driver = preload("res://tests/integration/run_driver.gd")

## 一局要走七八场，每场要经过「开打 / 领奖励 / 选下一站」几轮。给足余量 —— 超了就是真的卡住了。
const ROUND_LIMIT: int = 48

## 钉住的种子。**按键开局走的是 SEED_AUTO，掷出什么全看运气，而运气会决定输赢**：
## 领到的功能卡也吃魔力、也占施法队列的一拍，火力被挤掉就可能在某一波打不完
## （实测同一套操作，不同种子有的通关有的输在半路）。§3 说「输」是合法结局、由
## defeat_smoke 负责；这条要断的是**通关**那条路，所以把随机源钉死，顺带让整局可复现（§5）。
## 这个种子的余量是量过的：全程最慢的一波 350/600 tick，而且它一路领到 3 张功能卡也没被挤垮
## —— 于是「拿了奖励 → 下一波真的变了」这条在这条用例里被反复走到。
const PINNED_SEED: int = 20261008


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("full_run_smoke")
	var d: RefCounted = Driver.new()
	if not ctx.check(d.setup(tree), "GameFlow / RunState 两个单例都在：%s" % d.last_error()):
		return
	d.reset_to_boot()
	if not ctx.check(await d.boot_into_menu(), "启动后落在主菜单：%s" % d.last_error()):
		return
	if not ctx.check(await d.start_new_run(), "按「开始新一局」后进入编辑器：%s" % d.last_error()):
		return
	# 把随机源钉死（理由见 PINNED_SEED）。按键那一下已经证明了「主菜单接对了线」；
	# 这里只是把刚开出来的这一局重掷成固定种子 —— 书页不受影响（start_run 不清空书页）。
	d.run_state().start_run(PINNED_SEED)
	var played_seed: int = d.run_state().get_run_seed()
	if not ctx.equal(played_seed, PINNED_SEED, "这一局用的是钉住的种子 %d" % PINNED_SEED):
		return
	if not _build_board(ctx, d):
		return
	if not await _walk(ctx, d):
		return
	if not _check_victory(ctx, d):
		return
	await _restart(ctx, d, played_seed)
	await d.teardown()


# ------------------------------------------------------------ 起手：最小可用的蓝图

## 一张核心 + 一张要付费的法术 + 一条丝线。
##
## 这一套够打穿每一波：所有法术都是「每点魔力 3 点伤害」，核心的产出率固定，于是伤害率
## 约 0.3 /tick；一波最长 600 tick，最厚的一波 100 点血 ≈ 334 tick —— 留了一倍余量。
## 而奖励每场再加一张卡，只会更快。
func _build_board(ctx: RefCounted, d: RefCounted) -> bool:
	var core: BoardModel.PlacedCard = d.place_card(&"core_arcane")
	ctx.check(core != null, "把核心摆上书页：%s" % d.last_error())
	var spell: CardData = _first_spell()
	if not ctx.check(spell != null, "卡表里有要付费的法术卡"):
		return false
	var placed: BoardModel.PlacedCard = d.place_card(spell.id)
	if not ctx.check(core != null and placed != null, "两张卡都在书页上"):
		return false
	ctx.check(d.link(core.uid, placed.uid), "从核心拉一条丝线接到法术上：%s" % d.last_error())
	var probe: CombatSim = CombatSim.new()
	probe.begin(d.run_state().board(), 1)
	ctx.check(not probe.cast_order().is_empty(), "战斗队列里排到了法术")
	return true


func _first_spell() -> CardData:
	for card: CardData in CardCatalog.all():
		if not card.is_core() and card.mana_cost > 0:
			return card
	return null


# ------------------------------------------------------------ 一局的推进

## 按「当前在哪一屏」反复往下走，直到打穿最后一层落到结算屏。
## 每一环都是**真实的按钮**，所以这条同时也证明了「这些屏真的接对了线」。
func _walk(ctx: RefCounted, d: RefCounted) -> bool:
	var rounds: int = 0
	while rounds < ROUND_LIMIT:
		rounds += 1
		var state: int = d.flow().get_state()
		if state == d.flow().GameState.RESULT:
			return ctx.check(d.run_state().result() == d.run_state().Result.VICTORY,
				"打到结算屏是**通关**，不是中途输掉")
		if state == d.flow().GameState.EDITOR:
			if not await _launch(ctx, d):
				return false
		elif state == d.flow().GameState.COMBAT:
			if not await _fight(ctx, d):
				return false
		elif state == d.flow().GameState.REWARD:
			if not await _claim(ctx, d):
				return false
		elif state == d.flow().GameState.MAP:
			if not await _advance(ctx, d):
				return false
		else:
			return ctx.check(false, "走到了意料之外的状态 %s" % d.flow().state_name(state))
	return ctx.check(false, "在 %d 轮内没能打穿最后一层" % ROUND_LIMIT)


## 编辑器（开局第一场 / 从工坊出来）→ 战斗。
func _launch(ctx: RefCounted, d: RefCounted) -> bool:
	var start: Button = d.button_for(d.scene(), Driver.KEY_START_BATTLE)
	if not ctx.check(start != null, "编辑器顶栏有「%s」" % Driver.KEY_START_BATTLE):
		return false
	return ctx.check(await d.press_and_wait(start, d.flow().GameState.COMBAT),
		"按「开始战斗」进入战斗屏：%s" % d.last_error())


## 打一场。收场只有两种：打穿最后一层 → 结算；否则 → 奖励屏。
func _fight(ctx: RefCounted, d: RefCounted) -> bool:
	if not ctx.check(await d.fight_to_end(), "这一场打完了（离开了战斗屏）：%s" % d.last_error()):
		return false
	var state: int = d.flow().get_state()
	if state == d.flow().GameState.RESULT:
		return true
	if not ctx.check(state == d.flow().GameState.REWARD, "打完一场去奖励屏，不是别的屏"):
		return false
	ctx.equal(d.run_state().current_wave(), d.run_state().TOTAL_WAVES, "打的是这一场的最后一波")
	return true


## 领奖励：拿一张卡。**这张卡必须真的改变下一波** —— 所以这里不只数「多了一张卡」，
## 还把它放进下一场的施法队列里看一眼（PET-92 §1 的核心）。
func _claim(ctx: RefCounted, d: RefCounted) -> bool:
	var options: Array[Dictionary] = d.run_state().roll_rewards()
	var index: int = _first_card_index(options)
	if not ctx.check(index >= 0, "这一次的奖励里有可拿的卡（池子只剩两个加成时才没有）"):
		return false
	var buttons: Array[Node] = d.buttons_of(d.scene(), Driver.KEY_CHOOSE)
	if not ctx.check(buttons.size() == options.size(),
			"每个选项一颗「选择」（%d / %d）" % [buttons.size(), options.size()]):
		return false
	var card_id: StringName = options[index]["card_id"]
	if not ctx.check(await d.press_and_wait(buttons[index], d.flow().GameState.MAP),
			"选「%s」之后去路线图：%s" % [card_id, d.last_error()]):
		return false
	ctx.check(d.placed_of(card_id) != null, "选中的卡落到了书页上")
	ctx.check(_in_cast_order(d, card_id), "它进了下一场的施法队列（拿了真的会变强）")
	return true


func _first_card_index(options: Array[Dictionary]) -> int:
	for index: int in options.size():
		if RewardModel.is_card(options[index]):
			return index
	return -1


## 下一场会按什么顺序施法。拿完奖励、离开界面之后再问一次 —— 问的是书页上真实的样子。
func _in_cast_order(d: RefCounted, card_id: StringName) -> bool:
	var probe: CombatSim = CombatSim.new()
	probe.begin(d.run_state().board(), d.run_state().current_wave(),
		d.run_state().damage_bonus(), d.run_state().mana_bonus())
	for card: CardData in probe.cast_order():
		if card.id == card_id:
			return true
	return false


## 在路线图上点亮下一站，再按「继续」把这一局带过去。
## 走到的是战斗节点还是工坊由模型定（工坊回编辑器）—— 两条路 `_walk` 都接得住。
func _advance(ctx: RefCounted, d: RefCounted) -> bool:
	var map: MapModel = d.run_state().map()
	var from_tier: int = map.deepest_tier()
	var picked: int = d.select_next_node()
	if not ctx.check(picked >= 0, "在路线图上点亮了下一站（节点 %d）：%s" % [picked, d.last_error()]):
		return false
	ctx.equal(map.current_id(), picked, "模型真的走过去了（路线前进由 MapModel 记）")
	ctx.check(map.deepest_tier() > from_tier,
		"路线往前推进了一层（%d → %d）" % [from_tier, map.deepest_tier()])
	var go: Button = d.button_for(d.scene(), Driver.KEY_CONTINUE)
	if not ctx.check(go != null and not go.disabled,
			"选好之后「%s」不再是灰的" % Driver.KEY_CONTINUE):
		return false
	return ctx.check(await d.press_and_leave(go), "「继续」把这一局带到了下一屏：%s" % d.last_error())


# ------------------------------------------------------------ 结局与开新一局

## 通关结算：这一屏要说得清「到过几层、拿了什么」。
func _check_victory(ctx: RefCounted, d: RefCounted) -> bool:
	ctx.equal(d.flow().get_state(), d.flow().GameState.RESULT, "打穿最后一层之后停在结算屏")
	ctx.equal(d.run_state().result(), d.run_state().Result.VICTORY, "记的是通关")
	var map: MapModel = d.run_state().map()
	ctx.check(map.is_finished(), "路线确实走到了最后一层")
	ctx.equal(d.run_state().tiers_seen(), MapModel.TIERS, "到过 %d 层 —— 与走完的路线一致" % MapModel.TIERS)
	ctx.check(d.has_label(d.scene(), "通关"), "结算屏写着「通关」")
	ctx.check(d.has_label(d.scene(), "到过 %d 层" % MapModel.TIERS), "结算屏报的层数与数据一致")

	var taken: Array[Dictionary] = d.run_state().taken_rewards()
	if not ctx.check(taken.size() >= MapModel.TIERS, "这一局拿过 %d 笔奖励（账目非空）" % taken.size()):
		return false
	var first: String = RewardModel.name_text(taken[0])
	var ledger: String = d.label_containing(d.scene(), first)
	if not ctx.check(not ledger.is_empty(), "结算屏的账目里有「%s」" % first):
		return false
	for option: Dictionary in taken:
		var name: String = RewardModel.name_text(option)
		ctx.check(ledger.contains(name), "账目里每一笔都在：%s" % name)
	return true


## §4：结算之后能开新的一局，而且是**新种子 ⇒ 新地图、新卡表**。
func _restart(ctx: RefCounted, d: RefCounted, played_seed: int) -> bool:
	var before: String = d.map_fingerprint()
	var again: Button = d.button_for(d.scene(), Driver.KEY_AGAIN)
	if not ctx.check(again != null, "结算屏有「%s」" % Driver.KEY_AGAIN):
		return false
	if not ctx.check(await d.press_and_wait(again, d.flow().GameState.EDITOR),
			"按「%s」直接进入编辑器：%s" % [Driver.KEY_AGAIN, d.last_error()]):
		return false
	ctx.check(d.run_state().is_active(), "新的一局真的开起来了")
	var fresh: int = d.run_state().get_run_seed()
	ctx.check(fresh != played_seed, "新的一局换了种子（%d → %d）" % [played_seed, fresh])
	ctx.equal(d.run_state().taken_rewards().size(), 0, "账本清空 = 新卡表（拿过的又能再拿）")
	ctx.equal(d.run_state().result(), d.run_state().Result.NONE, "新的一局没有结局")
	ctx.equal(d.run_state().current_wave(), 1, "新的一局从第 1 波开始")
	ctx.check(d.map_fingerprint() != before, "新的一局是另一张地图")
	var map: MapModel = d.run_state().map()
	ctx.equal(map.current_id(), -1, "新地图还没出发")
	ctx.equal(d.run_state().tiers_seen(), 0, "到过 0 层")
	return true
