## snap.gd
## 职责：磁性吸附几何 —— 把正在拖动的矩形吸附到附近矩形的边 / 中线上，并回报该画哪几条辅助线。
## 所属系统：editor（纯几何，无状态、无节点、无 Palette 依赖）
## 依赖：无
## 禁止：本文件不得量化坐标。**本工程没有网格**（用户 2026-10-06：「不要搞格子」）——
##       吸附只在「附近确有另一张卡」时发生，附近没有东西时坐标必须**原样返回**。
##       任何把坐标四舍五入到固定步长的写法都违反本作的核心交互，见 tests/unit/test_snap.gd。

class_name Snap
extends RefCounted

## 吸附半径（960×540 画布上的逻辑像素）。卡片 72px 宽，半径取其 1/4 ——
## 近到「显然是想要对齐」才吸，不会把自由摆放变成隐形网格。
const DEFAULT_RADIUS: float = 18.0

## 一次吸附求解的结果。
class Result:
	extends RefCounted
	## 求解后的矩形位置。
	var position: Vector2 = Vector2.ZERO
	## 命中的竖直辅助线 x 坐标（画在画布坐标系里）。
	var guides_v: Array[float] = []
	## 命中的水平辅助线 y 坐标。
	var guides_h: Array[float] = []
	## 是否发生了吸附（x 或 y 任一被拉动）。
	var snapped: bool = false

	func _init(start: Vector2) -> void:
		position = start


## 求解磁性吸附。
##
## moving 是拖动中的矩形（当前位置），obstacles 是画布上其它卡片的矩形。
## 返回的 Result.position 是最终应当落到的位置：X 与 Y **各自独立**求解 ——
## 「左边对齐了但纵向还差一点」应当只吸 X，不该被一并拽走。
static func resolve(moving: Rect2, obstacles: Array[Rect2], radius: float = DEFAULT_RADIUS) -> Result:
	var result: Result = Result.new(moving.position)
	var best_x: Dictionary = _best_axis(moving, obstacles, radius, true)
	var best_y: Dictionary = _best_axis(moving, obstacles, radius, false)
	if not best_x.is_empty():
		result.position.x = moving.position.x + float(best_x["delta"])
		result.guides_v.append(float(best_x["line"]))
		result.snapped = true
	if not best_y.is_empty():
		result.position.y = moving.position.y + float(best_y["delta"])
		result.guides_h.append(float(best_y["line"]))
		result.snapped = true
	return result


## 单轴求解。horizontal = true 时解 X 轴（比较左 / 中 / 右三对边），false 时解 Y 轴。
## 返回空字典 = 该轴附近没有可吸的目标。
##
## 三对边各自算一个候选位移，取**绝对值最小**的那个；并列时取先遇到的（障碍物顺序稳定，
## 因此同一输入永远得到同一结果 —— 03 §4.2 要求传播确定性，交互也照同一条纪律走）。
static func _best_axis(moving: Rect2, obstacles: Array[Rect2], radius: float, horizontal: bool) -> Dictionary:
	var best: Dictionary = {}
	var moving_edges: Array[float] = _edges(moving, horizontal)
	for obstacle: Rect2 in obstacles:
		var obstacle_edges: Array[float] = _edges(obstacle, horizontal)
		for source: float in moving_edges:
			for target: float in obstacle_edges:
				var delta: float = target - source
				if absf(delta) > radius:
					continue
				if best.is_empty() or absf(delta) < absf(float(best["delta"])):
					best = {"delta": delta, "line": target}
	return best


## 一个矩形在某轴上的三条参考边：起始边 / 中线 / 结束边。
static func _edges(rect: Rect2, horizontal: bool) -> Array[float]:
	if horizontal:
		return [rect.position.x, rect.position.x + rect.size.x * 0.5, rect.position.x + rect.size.x]
	return [rect.position.y, rect.position.y + rect.size.y * 0.5, rect.position.y + rect.size.y]


## 在给定点附近找最近的接口（连线时把线头吸到接口上）。
## 找不到返回 -1。points 是接口在画布坐标系里的位置。
static func nearest_point(point: Vector2, points: Array[Vector2], radius: float = DEFAULT_RADIUS) -> int:
	var best_index: int = -1
	var best_distance: float = radius
	for index: int in points.size():
		var distance: float = point.distance_to(points[index])
		if distance <= best_distance:
			best_distance = distance
			best_index = index
	return best_index


## 把两个矩形之间的吸附判定做成一次问答 —— UI 层在拖动时每帧调用。
## 分开导出是为了让「哪些矩形算障碍」这条策略留在调用方（当前拖动的那张卡必须排除）。
static func rect_of(position: Vector2, size: Vector2) -> Rect2:
	return Rect2(position, size)
