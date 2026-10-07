## test_board_model.gd
## 职责：书页数据模型的验收 —— 自由坐标、增删改、连线的校验（自连 / 重复 / 成环）、快照回滚。
## 所属系统：tests
## 依赖：BoardModel, CardCatalog
## 禁止：本文件不得引用任何节点 —— 模型层必须能脱离场景单独验证。

extends RefCounted


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_board_model")
	_check_empty(ctx)
	_check_free_coordinates(ctx)
	_check_remove_cleans_links(ctx)
	_check_link_validation(ctx)
	_check_snapshot(ctx)
	_check_free_position(ctx)


func _check_empty(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	ctx.equal(board.cards().size(), 0, "空书页没有卡")
	ctx.equal(board.links().size(), 0, "空书页没有丝线")
	ctx.check(board.find_card(1) == null, "空书页查不到卡")
	ctx.check(not board.remove_card(1), "移除不存在的卡返回 false")
	ctx.check(board.is_start_of_chain(999), "孤立 uid 视为链首")


## 坐标是**自由浮点**：进去什么样，出来就得什么样，一位小数都不许被抹平。
func _check_free_coordinates(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var placed: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(101.37, 202.11))
	ctx.near(placed.position.x, 101.37, "落点 X 原样保存")
	ctx.near(placed.position.y, 202.11, "落点 Y 原样保存")
	ctx.check(board.move_card(placed.uid, Vector2(33.03, 47.79)), "移动成功")
	ctx.near(board.find_card(placed.uid).position.x, 33.03, "移动后 X 原样保存")
	ctx.near(board.find_card(placed.uid).position.y, 47.79, "移动后 Y 原样保存")
	ctx.check(not board.move_card(999, Vector2.ZERO), "移动不存在的卡返回 false")
	ctx.check(placed.data() != null, "卡牌定义可查")
	ctx.equal(placed.data().id, &"core_arcane", "查到的定义就是那张卡")


## 09 §3.2：删掉被引用的卡，挂在它身上的丝线必须一并清掉，不能留下悬空边。
func _check_remove_cleans_links(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var core: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var fire: BoardModel.PlacedCard = board.add_card(&"ab_fire", Vector2(200.0, 30.0))
	var haste: BoardModel.PlacedCard = board.add_card(&"fn_haste", Vector2(380.0, 30.0))
	ctx.check(board.connect_cards(core.uid, fire.uid) > 0, "核心 → 火球 连线成功")
	ctx.check(board.connect_cards(fire.uid, haste.uid) > 0, "火球 → 加速 连线成功")
	ctx.equal(board.links().size(), 2, "两条丝线都在")
	ctx.check(board.remove_card(fire.uid), "删除火球成功")
	ctx.equal(board.links().size(), 0, "挂在火球上的两条丝线被一并清掉")
	ctx.equal(board.cards().size(), 2, "另外两张卡还在")
	ctx.check(not board.has_link(core.uid, fire.uid), "指向已删除卡片的丝线不存在")


func _check_link_validation(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var a: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(30.0, 30.0))
	var b: BoardModel.PlacedCard = board.add_card(&"ab_fire", Vector2(150.0, 30.0))
	var c: BoardModel.PlacedCard = board.add_card(&"fn_haste", Vector2(270.0, 30.0))

	ctx.equal(board.connect_cards(a.uid, a.uid), -1, "拒绝自连")
	ctx.equal(board.connect_cards(a.uid, 999), -1, "拒绝连到不存在的卡")
	ctx.check(board.connect_cards(a.uid, b.uid) > 0, "a → b 成功")
	ctx.equal(board.connect_cards(a.uid, b.uid), -1, "拒绝重复连线")
	ctx.check(board.connect_cards(b.uid, c.uid) > 0, "b → c 成功")
	ctx.equal(board.connect_cards(c.uid, a.uid), -1, "拒绝成环（c → a 会绕回起点）")
	ctx.equal(board.connect_cards(c.uid, b.uid), -1, "拒绝成环（c → b 也是环）")
	ctx.check(board.would_create_cycle(c.uid, a.uid), "环检测：c → a 判定为成环")
	ctx.check(not board.would_create_cycle(a.uid, c.uid), "环检测：a → c 不是环")

	ctx.check(board.is_start_of_chain(a.uid), "起点卡没有入边")
	ctx.check(not board.is_start_of_chain(b.uid), "b 有入边，不是链首")
	ctx.equal(board.links_of(b.uid).size(), 2, "b 有一进一出两条丝线")

	var link_id: int = board.links()[0].uid
	ctx.check(board.remove_link(link_id), "断开丝线成功")
	ctx.check(not board.remove_link(link_id), "重复断开返回 false")


## 撤销依赖快照：回滚之后必须**一模一样**，包括 uid 计数器（否则撤销后重做会换 uid）。
func _check_snapshot(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var a: BoardModel.PlacedCard = board.add_card(&"core_arcane", Vector2(11.5, 22.25))
	var b: BoardModel.PlacedCard = board.add_card(&"ab_ice", Vector2(140.75, 22.25))
	board.connect_cards(a.uid, b.uid)
	var saved: Dictionary = board.snapshot()

	board.move_card(a.uid, Vector2(500.0, 500.0))
	board.remove_card(b.uid)
	ctx.equal(board.cards().size(), 1, "改动后只剩一张卡")

	board.restore(saved)
	ctx.equal(board.cards().size(), 2, "回滚后卡数还原")
	ctx.equal(board.links().size(), 1, "回滚后丝线还原")
	ctx.near(board.find_card(a.uid).position.x, 11.5, "回滚后坐标还原")
	ctx.check(board.has_link(a.uid, b.uid), "回滚后连线关系还原")

	var fresh: BoardModel.PlacedCard = board.add_card(&"fn_loop", Vector2(0.0, 0.0))
	ctx.equal(fresh.uid, b.uid + 1, "回滚后新建卡的 uid 接着原来的序号")


## 新卡的落点不得压到已有卡，且必须留在画布范围内。
func _check_free_position(ctx: RefCounted) -> void:
	var board: BoardModel = BoardModel.new()
	var view: Vector2 = Vector2(600.0, 300.0)
	var first: Vector2 = board.free_position(view)
	ctx.check(first.x >= 0.0 and first.y >= 0.0, "空书页落点在画布内")
	board.add_card(&"core_arcane", first)
	var second: Vector2 = board.free_position(view)
	ctx.check(not Rect2(first, BoardModel.CARD_SIZE).intersects(Rect2(second, BoardModel.CARD_SIZE)),
		"第二张卡不会压在第一章卡上")
	board.add_card(&"ab_fire", second)
	var third: Vector2 = board.free_position(view)
	ctx.check(third.y + BoardModel.CARD_SIZE.y <= view.y, "第三张卡仍在画布内")
