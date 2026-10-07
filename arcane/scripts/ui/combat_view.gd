## combat_view.gd
## 职责：战斗屏左侧那块书页的画法 —— 丝线、已布下的卡（与编辑器同一个卡面）、刚打出去的那张。
## 所属系统：ui
## 依赖：CombatSim, BoardModel, CardData, CardFace, StrokePainter, CombatTheme
## 禁止：本文件不得出现裸色值（颜色一律经 CombatTheme 角色表）；不得直接 draw_line / draw_polyline
##       —— 线一律经 StrokePainter（与路线图、编辑器同一支笔）；
##       不得改模型、不得处理输入 —— 战斗屏没有玩家操作，这里只读状态、只落笔。
##
## 它**不持有任何战斗状态**：魔力、血量、施放队列都问 CombatSim（本局那一份在 CombatScreen 手里）。
## 于是「本波加成」这类数值不会在绘制层被复制一份、然后跟仿真里的那个悄悄对不上。
##
## 卡面刻意**复用编辑器的 CardFace**：玩家在仓库里认出的牌，落到战斗里还得是同一张。
## 这一屏不追求质感（PET-89 §2：明暗基调要等用户裁定），只要求「看得懂」。

class_name CombatView
extends Control

## 书页四周的留白（局部坐标）。
const PAGE_PADDING: float = 24.0
## 最大放大倍数。放大只会让卡变糊，不会多出信息 —— 一屏装得下就够了。
const MAX_SCALE: float = 1.0

var _sim: CombatSim = null
var _board: BoardModel = null
## 最近一次打出去的卡 id（空 = 还没打过）。画面上给它一圈金环 ——
## 那就是「这次施法的结果」落在书页上的样子，比一行文字更贴近玩家刚看到的东西。
var _fired: StringName = &""
var _scale: float = 1.0
var _offset: Vector2 = Vector2.ZERO


func setup(sim: CombatSim, board: BoardModel) -> void:
	_sim = sim
	_board = board
	_fired = &""
	queue_redraw()


## 记下刚打出去的那张卡。由 CombatScreen 在 cast_performed 里回调。
func note_cast(card_id: StringName) -> void:
	_fired = card_id
	queue_redraw()


func _draw() -> void:
	if _sim == null or _board == null or size.x <= 0.0 or size.y <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, size), CombatTheme.color(CombatTheme.Role.PAGE), true)
	# 之后一律在**书页坐标**里落笔：映射交给 CanvasItem 的变换，卡与笔宽一起等比缩放。
	_fit()
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))
	_paint_threads()
	_paint_cards()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ 映射

## 书页坐标 → 本控件坐标的等比映射。战斗屏不做交互，故只求「摆得开、看得懂」：
## 把整块书页的包围盒等比塞进画布。
func _fit() -> void:
	_scale = 1.0
	_offset = Vector2.ZERO
	if _board.cards().is_empty():
		return
	var box: Rect2 = _board_bounds()
	var padding: Vector2 = Vector2(PAGE_PADDING, PAGE_PADDING)
	var inner: Rect2 = Rect2(padding, (size - padding * 2.0).max(Vector2.ONE))
	var fit: Vector2 = inner.size / box.size.max(Vector2.ONE)
	_scale = minf(minf(fit.x, fit.y), MAX_SCALE)
	_offset = inner.position + (inner.size - box.size * _scale) * 0.5 - box.position * _scale


## 书页上所有卡的包围盒（含卡自己的尺寸，卡面也占地方）。
func _board_bounds() -> Rect2:
	var box: Rect2 = Rect2(_board.cards()[0].position, BoardModel.CARD_SIZE)
	for placed: BoardModel.PlacedCard in _board.cards():
		box = box.merge(Rect2(placed.position, BoardModel.CARD_SIZE))
	return box


# ------------------------------------------------------------------ 落笔

## 丝线：谁连到谁。战斗屏不做交互，故画成直线 —— 编辑器那条采样曲线是给「拖出来的手感」用的，
## 这里没有手感可言，直线反而更清楚地表达「这一条连得到 / 连不到」。
##
## 笔宽**除以缩放**：变换会把笔宽一起缩放，不除的话书页一缩小丝线就细得看不见。
func _paint_threads() -> void:
	var color: Color = CombatTheme.color(CombatTheme.Role.THREAD)
	for link: BoardModel.Link in _board.links():
		var from: BoardModel.PlacedCard = _board.find_card(link.from_uid)
		var to: BoardModel.PlacedCard = _board.find_card(link.to_uid)
		if from == null or to == null:
			continue
		StrokePainter.stroke_path(self,
			PackedVector2Array([centre_of(from), centre_of(to)]),
			color, StrokePainter.WIDTH / _scale, false)


## 卡面 → 金环。顺序固定：先牌面再环，于是环压在卡缘外侧、不会被卡面盖掉。
func _paint_cards() -> void:
	var fill: Color = CombatTheme.color(CombatTheme.Role.CARD_FILL)
	var ink: Color = CombatTheme.color(CombatTheme.Role.CARD_INK)
	for placed: BoardModel.PlacedCard in _board.cards():
		var data: CardData = placed.data()
		if data == null:
			continue
		CardFace.paint(self, data, placed.position, fill, ink)
		if _fired != &"" and data.id == _fired:
			StrokePainter.stroke_path(self,
				StrokePainter.rect_path(Rect2(placed.position, BoardModel.CARD_SIZE)),
				CombatTheme.color(CombatTheme.Role.CARD_FIRED),
				CardFace.BORDER_WIDTH_HOT / _scale, true)


## 一张卡的中心。丝线连的是卡心而不是接口 —— 战斗屏不画接口（接口是编辑器的交互件）。
static func centre_of(placed: BoardModel.PlacedCard) -> Vector2:
	return placed.position + BoardModel.CARD_SIZE * 0.5
