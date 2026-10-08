## test_map_symbol.gd
## 职责：路线图节点上那 24×24 符号的验收 —— 两种类型符号、四种状态标记、短名与图例名。
## 所属系统：tests
## 依赖：MapModel, MapLayout, MapView, MapNodePainter, MapSymbolPainter, StrokePainter
## 禁止：本文件不得写入几何 / 颜色常量，只断言。
##
## 为什么从 test_map_paint 里拆出来：源码有 300 行上限，而 PET-93 给四态加了**形状标记**
## （§2.2 原话：不可达=锁 / 可选=类型符号 / 已走=勾 / 当前=定位三角）——
## 符号这一摊自己就够一条了。
##
## M02 要的是「各态同时有形状标记与填/边区别」：填与外圈在 test_map_paint 里量，
## 形状标记在这里量 —— 两条合起来才是那句话。

extends RefCounted

## 几何用「半径的倍数」表示，**模长一律 ≤1**，否则会画到圆外面去。
const KINDS: Array[MapModel.Kind] = [MapModel.Kind.BATTLE, MapModel.Kind.WORKSHOP]
const MARKS: Array[MapSymbolPainter.Mark] = [MapSymbolPainter.Mark.KIND,
	MapSymbolPainter.Mark.LOCK, MapSymbolPainter.Mark.CHECK, MapSymbolPainter.Mark.LOCATOR]
const MARK_NAMES: PackedStringArray = ["类型符号", "锁", "勾", "定位三角"]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_map_symbol")
	_check_frame(ctx)
	_check_kinds(ctx)
	_check_marks(ctx)
	_check_mark_matches_kind(ctx)
	_check_names(ctx)


## §2.2 的重复元素表：符号 24×24、线宽 2。
func _check_frame(ctx: RefCounted) -> void:
	ctx.equal(MapLayout.SYMBOL_RADIUS * 2.0, 24.0, "符号框 24×24")
	ctx.equal(MapSymbolPainter.SYMBOL_WIDTH, 2.0, "符号线宽 2")
	ctx.check(MapSymbolPainter.SYMBOL_WIDTH < StrokePainter.WIDTH,
		"符号比笔的默认线宽细一档（24px 的框里再压 3px 就糊了）")
	ctx.equal(MapSymbolPainter.Mark.size(), MapNodePainter.State.size(),
		"状态标记的档数 = 状态数（每个状态都有自己的那一档）")


## 两种节点的符号：都画得出来、都在半径内、而且彼此不是同一个图形。
func _check_kinds(ctx: RefCounted) -> void:
	var drawn: Dictionary = {}
	for kind: MapModel.Kind in KINDS:
		var paths: Array[Dictionary] = MapSymbolPainter.paths(kind, Vector2.ZERO,
			MapLayout.SYMBOL_RADIUS)
		if not ctx.check(not paths.is_empty(), "%s 有几何" % MapView.kind_text(kind)):
			continue
		_check_geometry(ctx, paths, "%s 的每一笔" % MapView.kind_text(kind))
		drawn[kind] = _flatten(paths)
	ctx.not_equal(drawn[MapModel.Kind.BATTLE], drawn[MapModel.Kind.WORKSHOP],
		"战斗与工坊不是同一个图形（符号 + 短名两重区分）")
	# 反向对照：同一个 kind 画两次当然一样 —— 证明上面那条比的是几何本身。
	ctx.equal(_flatten(MapSymbolPainter.paths(MapModel.Kind.BATTLE, Vector2.ZERO,
		MapLayout.SYMBOL_RADIUS)), drawn[MapModel.Kind.BATTLE], "反向对照：同一种 kind 画两次一致")


## 四种状态标记：形状两两不同，且各自都是一组画得出来的线。
## 这一条是 M02「形状标记」那一半的算术版 —— 「四态都不同形」不是目视结论。
func _check_marks(ctx: RefCounted) -> void:
	var drawn: Dictionary = {}
	for mark: MapSymbolPainter.Mark in MARKS:
		var paths: Array[Dictionary] = MapSymbolPainter.mark_paths(mark, MapModel.Kind.BATTLE,
			Vector2.ZERO, MapLayout.SYMBOL_RADIUS)
		if not ctx.check(not paths.is_empty(), "%s 有几何" % MARK_NAMES[mark]):
			continue
		_check_geometry(ctx, paths, "%s 的每一笔" % MARK_NAMES[mark])
		drawn[mark] = _flatten(paths)
	ctx.equal(drawn.size(), MARKS.size(), "四种标记各画得出来")
	var same: PackedStringArray = PackedStringArray()
	for one: int in MARKS.size():
		for other: int in range(one + 1, MARKS.size()):
			if drawn[MARKS[one]] == drawn[MARKS[other]]:
				same.append("%s↔%s" % [MARK_NAMES[one], MARK_NAMES[other]])
	ctx.equal(same.size(), 0,
		"四种标记两两不同形" if same.is_empty() else "形状撞车：%s" % "; ".join(same))
	# 反向对照：同一档标记画两次当然一样 —— 上面那条比的确实是几何。
	ctx.equal(_flatten(MapSymbolPainter.mark_paths(MapSymbolPainter.Mark.LOCK,
		MapModel.Kind.BATTLE, Vector2.ZERO, MapLayout.SYMBOL_RADIUS)), drawn[MapSymbolPainter.Mark.LOCK],
		"反向对照：同一档标记画两次一致")


## KIND 那一档不是新图形，就是节点自己的类型符号 —— 可选态仍然看得出这是战斗还是工坊。
func _check_mark_matches_kind(ctx: RefCounted) -> void:
	for kind: MapModel.Kind in KINDS:
		ctx.equal(_flatten(MapSymbolPainter.mark_paths(MapSymbolPainter.Mark.KIND, kind,
			Vector2.ZERO, MapLayout.SYMBOL_RADIUS)),
			_flatten(MapSymbolPainter.paths(kind, Vector2.ZERO, MapLayout.SYMBOL_RADIUS)),
			"KIND 标记 = %s 本来的符号" % MapView.kind_text(kind))
	# 换个 kind，KIND 那一档要跟着换 —— 否则上面那条可以被一个常量糊过去。
	ctx.not_equal(_flatten(MapSymbolPainter.mark_paths(MapSymbolPainter.Mark.KIND,
		MapModel.Kind.BATTLE, Vector2.ZERO, MapLayout.SYMBOL_RADIUS)),
		_flatten(MapSymbolPainter.mark_paths(MapSymbolPainter.Mark.KIND, MapModel.Kind.WORKSHOP,
			Vector2.ZERO, MapLayout.SYMBOL_RADIUS)),
		"KIND 标记跟着节点类型变")


## 文字是图形之外的第二重区分：两种类型、四种状态的词两两不同。
func _check_names(ctx: RefCounted) -> void:
	ctx.not_equal(MapView.kind_text(MapModel.Kind.BATTLE), MapView.kind_text(MapModel.Kind.WORKSHOP),
		"两种节点的短名不同")
	var names: Dictionary = {}
	for state: MapNodePainter.State in MapNodePainter.State.size():
		names[MapView.state_text(state)] = true
	ctx.equal(names.size(), 4, "四种状态的说明各是一个词")
	# 反向对照：四种状态各自用哪一档标记也必须不同 —— 名字不同但标记相同等于只有一半编码。
	var marks: Dictionary = {}
	for state: MapNodePainter.State in MapNodePainter.State.size():
		marks[MapNodePainter.STATE_MARK[state]] = true
	ctx.equal(marks.size(), 4, "四种状态各用一档不同的形状标记")


# ---------------------------------------------------------------- 工具

## 每一笔至少两点、坐标有限、**整条线都在符号半径内**。
func _check_geometry(ctx: RefCounted, paths: Array[Dictionary], what: String) -> void:
	var bad: int = 0
	for path: Dictionary in paths:
		if path["points"].size() < 2:
			bad += 1
		for point: Vector2 in path["points"]:
			if not (is_finite(point.x) and is_finite(point.y)) \
					or point.length() > MapLayout.SYMBOL_RADIUS:
				bad += 1
	ctx.equal(bad, 0, "%s 都在符号半径内、至少两点" % what)


## 二维几何展开成一串坐标，用来直接比较两组图形是不是同一个。
static func _flatten(paths: Array[Dictionary]) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for path: Dictionary in paths:
		points.append_array(path["points"] as PackedVector2Array)
	return points
