## map_parchment.gd
## 职责：羊皮卷纸面的程序化绘制 —— 纸上那层**纤维**（M04 的兜底纹样，全部由 Token 现画）。
## 所属系统：roguelike（绘制辅助）
## 依赖：Palette（唯一色值来源）、StrokePainter（唯一的笔）
## 禁止：本文件不得出现裸色值；不得引入任何贴图 / 字体资源 —— 美术到位前一律现画（06 §10 规则 7）。
##
## **纸面本身不在这里画。** §3 把「羊皮纸面 GOLD_200 / 纸边 8px 边带 WARM_500」定成材质角色，
## 材质角色归 Theme —— 那一层由 ContractTheme.TYPE_PAGE_BAND 铺（与屏①的书页同一支），
## 于是四屏的纸是同一张纸。这里只管纸上那点纤维。
##
## 与旧版最大的差别：**拿掉了暗角、折痕与卷角**。旧版用 WARM_300 当纸面、由外向内压一圈圈暗边，
## 而 §3 规定 WARM_300 / WARM_500 只许出现在 8px 边带里、纸面必须是 GOLD_200 ——
## 那三样装饰留在纸上就直接违反取色契约，所以不是「简化」而是「搬走」。
##
## 地形插画（山脉 / 河流 / 罗盘）是 P1-2 等正式美术的事。在那之前按 §4 M04 给一层**不抢信息**
## 的兜底：极淡的横向纤维，且避开 MapLayout.protected_rects() 划出的每一个保护区。
## 纤维的位置由行列号算出来，**不用随机**（03 §6）—— 同一张纸每次画得一模一样，测试才量得住。

class_name MapParchment
extends RefCounted

## §3「纸纹 / 地图装饰墨」：BROWN_300，alpha ≤ 0.08。0.06 取在上界之下还留一档余量 ——
## 而保护区里干脆一根不画（0 ≤ 文字框下要求的 0.03）。
const FIBER_ALPHA: float = 0.06
## 纤维的行距 / 段长 / 同段距 / 线宽。稀疏到「退开一步才看得出是纸」为止。
const FIBER_ROW_STEP: float = 34.0
const FIBER_LENGTH: float = 12.0
const FIBER_STEP: float = 46.0
const FIBER_WIDTH: float = 1.0
## 奇数行错开半个节拍。不错开就排成了网格，而纸上不该有网格。
const FIBER_STAGGER: float = 0.5
## 行列从一个内缩起算，免得纤维正好压在纸缘（也就压在 8px 边带）上。
const FIBER_INSET: float = 9.0


## 纸面的颜色。§3 把它定成 GOLD_200 —— 这里给个名字，
## 好让「状态在纸面上读不读得出来」这类断言有一个稳定的取值处，而不是各写各的 Token。
static func paper_color() -> Color:
	return Palette.get_color(Palette.Key.GOLD_200)


## 纸上所有纤维的矩形（**纸内局部坐标**）。几何与绘制分开：测试量的是这一份，
## 真机上画的也是这一份，不会各算各的。
##
## zones 是 §4 M04 的保护区，落在里面的纤维**根本不生成** —— 过滤放在这里而不是放在 paint()，
## 于是「装饰没进保护区」这条断言断的就是真机画出来的那一组。
static func fibers(rect: Rect2, zones: Array[Rect2]) -> Array[Rect2]:
	var result: Array[Rect2] = []
	var rows: int = int((rect.size.y - FIBER_INSET * 2.0) / FIBER_ROW_STEP)
	for row: int in rows:
		var y: float = rect.position.y + FIBER_INSET + float(row) * FIBER_ROW_STEP
		var offset: float = FIBER_STEP * FIBER_STAGGER if row % 2 == 1 else 0.0
		var columns: int = int((rect.size.x - FIBER_INSET * 2.0 - offset) / FIBER_STEP)
		for column: int in columns:
			var x: float = rect.position.x + FIBER_INSET + offset + float(column) * FIBER_STEP
			var fiber: Rect2 = Rect2(x, y, FIBER_LENGTH, FIBER_WIDTH)
			if not _blocked(fiber, zones):
				result.append(fiber)
	return result


## 把纤维交给笔。这是本文件唯一碰 CanvasItem 的地方。
static func paint(target: CanvasItem, rect: Rect2, zones: Array[Rect2]) -> void:
	var ink: Color = Palette.get_color(Palette.Key.BROWN_300)
	ink.a = FIBER_ALPHA
	for fiber: Rect2 in fibers(rect, zones):
		StrokePainter.stroke_path(target,
			PackedVector2Array([fiber.position, Vector2(fiber.end.x, fiber.position.y)]),
			ink, FIBER_WIDTH, false)


## 纤维是否落在保护区里。按**矩形相交**判，不按端点判：一根横穿保护区边角的纤维两端都在外面，
## 只端点判定会把它放过去 —— 而 M04 要的正是「装饰让路」。
static func _blocked(fiber: Rect2, zones: Array[Rect2]) -> bool:
	for zone: Rect2 in zones:
		if fiber.position.x < zone.end.x and zone.position.x < fiber.end.x \
				and fiber.position.y < zone.end.y and zone.position.y < fiber.end.y:
			return true
	return false
