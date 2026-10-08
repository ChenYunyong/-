## defeat_smoke.gd
## 职责：打输了这一局怎么收场 —— 核心被摧毁 → 停在战斗屏让玩家看见 → 按「结算」→
##       结算屏说清「到过几层 / 拿了什么」→ 回主菜单。
## 所属系统：tests
## 依赖：RunDriver（tests/integration/run_driver.gd）, CombatSim, MenuLayout
## 禁止：本文件不得自己调 GameFlow / RunState 推进流程 —— 一律经真实按钮，
##       否则「界面接对了线」这件事没被证明。收尾要把世界摆回原样（run_driver.teardown）。
##
## 与 full_run_smoke 的分工：这条管**输**（PET-92 §3 的前半句 + §4 的「回主菜单」），
## 那条管**赢**（§2 的路线推进 + §3 的通关 + §4 的「开新一局」）。

extends RefCounted

const Driver = preload("res://tests/integration/run_driver.gd")


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("defeat_smoke")
	var d: RefCounted = Driver.new()
	if not ctx.check(d.setup(tree), "GameFlow / RunState 两个单例都在：%s" % d.last_error()):
		return
	d.reset_to_boot()
	if not ctx.check(await d.boot_into_menu(), "启动后落在主菜单：%s" % d.last_error()):
		return
	if not ctx.check(await d.start_new_run(), "按「开始新一局」后进入编辑器：%s" % d.last_error()):
		return
	_check_hopeless_board(ctx, d)
	if not await _lose(ctx, d):
		return
	if not await _open_results(ctx, d):
		return
	await _back_to_menu(ctx, d)
	await d.teardown()


## 只摆核心、一条丝线都不连：这一场必然超时（30 秒打不完 60 点血）—— 这就是「一波失败」。
func _check_hopeless_board(ctx: RefCounted, d: RefCounted) -> void:
	ctx.check(d.place_card(&"core_arcane") != null, "把核心摆上书页：%s" % d.last_error())
	ctx.equal(d.run_state().board().links().size(), 0, "一条丝线都没连（没有法术会被施放）")
	var probe: CombatSim = CombatSim.new()
	probe.begin(d.run_state().board(), 1)
	ctx.check(probe.cast_order().is_empty(), "施法队列是空的 —— 这一波注定打不完")


func _lose(ctx: RefCounted, d: RefCounted) -> bool:
	var start: Button = d.button_for(d.scene(), Driver.KEY_START_BATTLE)
	if not ctx.check(start != null, "编辑器顶栏有「%s」" % Driver.KEY_START_BATTLE):
		return false
	if not ctx.check(await d.press_and_wait(start, d.flow().GameState.COMBAT),
			"按「开始战斗」进入战斗屏：%s" % d.last_error()):
		return false
	if not ctx.check(await d.fight_until_settle(), "这一波以核心被摧毁收场：%s" % d.last_error()):
		return false
	# 输了**不当场切屏**：那句「核心被摧毁」得先让玩家看见（PET-92 §3 的「本局结束」）。
	ctx.equal(d.flow().get_state(), d.flow().GameState.COMBAT, "打输了先停在战斗屏，不自动跳走")
	ctx.equal(d.run_state().current_wave(), 1, "输在第 1 波（连一波都没打完）")
	ctx.check(d.run_state().is_active(), "此刻这一局还没收尾 —— 收尾是玩家按「结算」那一刻的事")
	return true


## 「结算」→ 结算屏。屏上的每个字都要对得上本局真实发生的事。
func _open_results(ctx: RefCounted, d: RefCounted) -> bool:
	var settle: Button = d.visible_button(Driver.KEY_SETTLE)
	if not ctx.check(settle != null,
			"核心被摧毁之后「%s」才出现：%s" % [Driver.KEY_SETTLE, d.last_error()]):
		return false
	if not ctx.check(await d.press_and_wait(settle, d.flow().GameState.RESULT),
			"按「%s」进入结算屏：%s" % [Driver.KEY_SETTLE, d.last_error()]):
		return false
	ctx.equal(d.run_state().result(), d.run_state().Result.DEFEAT, "结算记的是「本局结束」")
	ctx.check(not d.run_state().is_active(), "结算之后这一局不再进行中")
	var screen: Node = d.scene()
	ctx.check(d.has_label(screen, "本局结束"), "结算屏写着「本局结束」（不是通关）")
	ctx.check(d.has_label(screen, "还没出发"), "到过几层如实说「还没出发」（一层都没走到）")
	ctx.check(d.has_label(screen, "什么都没拿"), "本局所得如实说「什么都没拿」")
	ctx.equal(d.run_state().tiers_seen(), 0, "数据侧同样是 0 层")
	_check_battle_report(ctx, d, screen)
	return true


## PET-94 复核 C02：这场战斗的账是**战斗屏自己**在离场前交进 RunState 的（不是测试塞的），
## 结算屏必须把它念出来 —— 这一路是真实按钮走出来的，接没接上线由它证明。
func _check_battle_report(ctx: RefCounted, d: RefCounted, screen: Node) -> void:
	var report: BattleReport = d.run_state().last_battle_report()
	if not ctx.check(report != null, "战斗屏离场前把战后详情交给了 RunState"):
		return
	ctx.check(d.has_label(screen, "战后详情"), "结算屏有「战后详情」那一块")
	var channels: String = d.label_containing(screen, TranslationServer.translate("八通道明细"))
	ctx.check(not channels.is_empty(), "八条通道逐条写出来了")
	ctx.check(channels.contains("%s 0" % TranslationServer.translate("附魔")),
		"通道的档数也写出来了（附魔 0）")
	ctx.equal(report.channel_count(), 8, "通道恰好 8 条（数到 %d）" % report.channel_count())
	ctx.equal(report.chain_size(), 0, "书页上一条法术都没连，链如实为空")
	ctx.check(d.has_label(screen, "链条为空"), "链空时屏上说的是「链条为空」，不是空白")


## §4：结算之后回得到主菜单，而且回去之后不能还留着一个「可以继续」的局。
func _back_to_menu(ctx: RefCounted, d: RefCounted) -> bool:
	var back: Button = d.button_for(d.scene(), Driver.KEY_MENU)
	if not ctx.check(back != null, "结算屏有「%s」" % Driver.KEY_MENU):
		return false
	if not ctx.check(await d.press_and_wait(back, d.flow().GameState.MAIN_MENU),
			"按「%s」回到主菜单：%s" % [Driver.KEY_MENU, d.last_error()]):
		return false
	var resume: Button = d.button_for(d.scene(), MenuLayout.KEY_CONTINUE)
	if ctx.check(resume != null, "主菜单上找得到「%s」" % MenuLayout.KEY_CONTINUE):
		ctx.check(resume.disabled, "「继续」是灰的 —— 这一局已经收掉了")
		ctx.check(d.has_label(d.scene(), "没有进行中的一局"), "并且写明了为什么是灰的")
	return true
