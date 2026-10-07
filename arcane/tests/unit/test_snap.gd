## test_snap.gd
## 职责：磁性吸附几何的验收 —— 这是 PET-85 招牌交互（无网格 · 自由吸附）的核心证据。
## 所属系统：tests
## 依赖：Snap, BoardModel
## 禁止：本文件不得改动 Snap 的行为，只断言它。
##
## 三条主张，逐条钉死：
##   1. **附近没有别的卡时，坐标原样返回** —— 这一条就是「没有网格」的定义；
##   2. 附近有卡时，按边 / 中线对齐，并回报该画哪几条辅助线；
##   3. X 与 Y 各自独立 —— 「横向对齐了，纵向不该被一起拽走」。

extends RefCounted

const SIZE: Vector2 = BoardModel.CARD_SIZE
## 一个「怎么摆都不可能被吸到」的远障碍：放在画布另一头。
const FAR: Rect2 = Rect2(5000.0, 5000.0, 72.0, 72.0)


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_snap")
	_check_identity_when_alone(ctx)
	_check_identity_sweep(ctx)
	_check_snaps_to_edge(ctx)
	_check_axis_independence(ctx)
	_check_determinism(ctx)
	_check_subpixel_preserved(ctx)
	_check_nearest_point(ctx)


## 只有远处一个障碍时，任意位置都必须原样返回。
func _check_identity_when_alone(ctx: RefCounted) -> void:
	var moving: Rect2 = Rect2(Vector2(100.37, 200.11), SIZE)
	var result: Snap.Result = Snap.resolve(moving, [FAR] as Array[Rect2])
	ctx.near(result.position.x, 100.37, "孤立时 X 原样返回")
	ctx.near(result.position.y, 200.11, "孤立时 Y 原样返回")
	ctx.check(not result.snapped, "孤立时不算发生吸附")
	ctx.equal(result.guides_v.size(), 0, "孤立时不画竖直辅助线")
	ctx.equal(result.guides_h.size(), 0, "孤立时不画水平辅助线")


## 密集扫描：400 个带小数的坐标，一个都不许被挪动。
## 这一条同时证明「没有网格」—— 任何把坐标对齐到固定步长的实现都会在这里成片失败。
func _check_identity_sweep(ctx: RefCounted) -> void:
	var drifted: int = 0
	var snapped: int = 0
	for index: int in 400:
		var position: Vector2 = Vector2(float(index) * 1.37 + 0.11, 300.23 + float(index % 7) * 0.19)
		var result: Snap.Result = Snap.resolve(Rect2(position, SIZE), [FAR] as Array[Rect2])
		if not result.position.is_equal_approx(position):
			drifted += 1
		if result.snapped:
			snapped += 1
	ctx.equal(drifted, 0, "400 个任意坐标全部原样返回（无网格）")
	ctx.equal(snapped, 0, "400 个任意坐标全部未被吸附")


## 贴着障碍物右边界时应当吸上去，并给出那条辅助线。
func _check_snaps_to_edge(ctx: RefCounted) -> void:
	var obstacle: Rect2 = Rect2(200.0, 200.0, 72.0, 72.0)
	# 障碍物右边界 = 272；moving 的左边界停在 276，中间空出 4px —— 在默认半径 18 以内。
	# 吸附 = 把这 4px 的空隙合上，所以结果必须是 272（而不是原地不动的 276）。
	var moving: Rect2 = Rect2(276.0, 400.0, 72.0, 72.0)
	var result: Snap.Result = Snap.resolve(moving, [obstacle] as Array[Rect2])
	ctx.check(result.snapped, "邻近时发生吸附")
	ctx.near(result.position.x, 272.0, "左边界吸到障碍物右边界（4px 空隙合上）")
	ctx.check(result.guides_v.has(272.0), "回报了 x=272 的竖直辅助线")
	ctx.equal(result.guides_h.size(), 0, "纵向没对上时不画水平辅助线")


## X 与 Y 各自独立：横向能吸、纵向差得远，就只动 X。
func _check_axis_independence(ctx: RefCounted) -> void:
	var obstacle: Rect2 = Rect2(200.0, 200.0, 72.0, 72.0)
	var moving: Rect2 = Rect2(276.0, 900.0, 72.0, 72.0)
	var result: Snap.Result = Snap.resolve(moving, [obstacle] as Array[Rect2])
	ctx.near(result.position.x, 272.0, "横向被吸附")
	ctx.near(result.position.y, 900.0, "纵向纹丝不动")


## 同一输入必须得到同一结果（03 §4.2 的确定性纪律同样适用于交互）。
func _check_determinism(ctx: RefCounted) -> void:
	var obstacles: Array[Rect2] = [Rect2(200.0, 200.0, 72.0, 72.0), Rect2(204.0, 400.0, 72.0, 72.0)]
	var moving: Rect2 = Rect2(271.0, 202.0, 72.0, 72.0)
	var first: Snap.Result = Snap.resolve(moving, obstacles)
	var second: Snap.Result = Snap.resolve(moving, obstacles)
	ctx.check(first.position.is_equal_approx(second.position), "两次求解位置一致")
	ctx.equal(first.guides_v, second.guides_v, "两次求解竖直辅助线一致")
	ctx.equal(first.guides_h, second.guides_h, "两次求解水平辅助线一致")


## 半径两侧的对照实验：小数位要被原样保留，而一旦吸附，目标是**障碍物的边**，
## 不是某个「整齐的」坐标 —— 网格实现会在这里露馅（它会把两侧的结果都推到整数格点上）。
##
## 注意「半径外」不能只按上边到上边来挑：吸附是 3 对 3 条边（起 / 中 / 止）互相配的，
## 所以要让**九对边全部**超过半径，才算真的在半径外。
func _check_subpixel_preserved(ctx: RefCounted) -> void:
	var obstacle: Rect2 = Rect2(200.0, 200.0, 72.0, 72.0)
	# 障碍物三条水平边是 200 / 236 / 272；这里取 320.5，最近的差也有 48.5，稳稳在半径外。
	var far_y: float = 320.5

	var outside: Snap.Result = Snap.resolve(Rect2(Vector2(500.0, far_y), SIZE), [obstacle] as Array[Rect2])
	ctx.check(not outside.snapped, "半径外不发生吸附")
	ctx.near(outside.position.y, far_y, "半径外的小数坐标原样保留")

	var near_y: float = 200.0 + Snap.DEFAULT_RADIUS - 0.5
	var inside: Snap.Result = Snap.resolve(Rect2(Vector2(500.0, near_y), SIZE), [obstacle] as Array[Rect2])
	ctx.check(inside.snapped, "半径内发生吸附")
	ctx.near(inside.position.y, 200.0, "吸附目标是障碍物的边 200，而不是某个网格点")


## 连线时把线头吸到最近的接口上。
func _check_nearest_point(ctx: RefCounted) -> void:
	var points: Array[Vector2] = [Vector2(100.0, 100.0), Vector2(300.0, 300.0)]
	ctx.equal(Snap.nearest_point(Vector2(104.0, 102.0), points), 0, "取最近接口")
	ctx.equal(Snap.nearest_point(Vector2(290.0, 306.0), points), 1, "取另一个最近接口")
	ctx.equal(Snap.nearest_point(Vector2(900.0, 900.0), points), -1, "半径外返回 -1")
