## combat_view.gd
## 职责：战斗屏战场（COMBAT_FIELD 896×280）的画法 —— 玩家核心（装置）、敌群、一次施法的弹道与伤害读数。
## 所属系统：ui
## 依赖：CombatLayout（包络与派生量）、CombatTheme（角色表）、StrokePainter（唯一的笔）、
##       Fonts（真字体）、ContractTheme（字号档）
## 禁止：本文件不得出现裸色值（颜色一律经 CombatTheme 角色表）；不得直接 draw_line / draw_polyline
##       —— 线一律经 StrokePainter（与路线图、编辑器同一支笔）；
##       不得画卡、不得画连线（C01：卡牌连接大图占比 = 0，那是编辑器的活儿）；
##       不得改模型、不得处理输入 —— 战斗屏没有玩家操作，这里只落笔。
##
## PET-93 屏③：这一层从「书页回放」改成**可观察的战场**。旧版把整张书页（卡与丝线）等比缩进画布，
## 于是战斗屏看上去只是编辑器的另一个视角；契约要的是「战场面积占安全区 ≥50%」且里面看得见
## 装置、敌群与一次施法反馈。卡链下移到尾栏，由 combat_chain 承担。
##
## 这一层**不持有任何战斗状态**：它只知道「最近一次施法落了多少伤害」这一个数，
## 而那个数是 CombatScreen 从 cast_performed 里转手过来的真值。血量、魔力、波次都不在这里 ——
## 一旦在这里留一份副本，它和仿真里的那个迟早会对不上，而症状只是「显示得不太对」。
##
## §2.3 原话：「此处弹道仅要求既有施法事件的视觉落点」—— 它是 cast_performed 那个**既有事件**
## 落在画面上的位置，不是新技能。故这里只画一条连线，不带任何动画 / 转场（动画形式本轮不定）。

class_name CombatView
extends Control

## 敌群那团东西的半径。§2.3 给的 288×156 是**美术包络**，不是形状本身：
## 形状取直径 112 的圆团，四周留出正式美术会占的边。
const ENEMY_RADIUS: float = 56.0
## 实体轮廓的画法。§3 只给敌群写了「轮廓 2px」，装置沿用同一个数 —— 两者是同一类
## 「无素材兜底实体轮廓」，同一屏里不该出现两种粗细。
const OUTLINE_WIDTH: float = 2.0
## 装置中间那颗菱形法力核的半径。
const CORE_GEM: float = 12.0
## 危险标记（朝上的小三角）的半边长与它在敌群上的落点系数。
const DANGER_SIZE: float = 8.0
const DANGER_AT: float = 0.62
## 伤害读数与敌群之间的缝（§1 间距系统里最小那一档）。
const DAMAGE_GAP: float = 4.0
## 圆用多少段折线逼近。笔只画折线（draw_arc 是另一套端点口径，不在这里混用）。
const CIRCLE_SEGMENTS: int = 32
## 丝线的底与芯（§3「4 + 2px」）。
const BOLT_BASE_WIDTH: float = 4.0
const BOLT_CORE_WIDTH: float = 2.0

## 最近一次落下的那一段伤害（0 = 本波还没放过）。C04：一帧只显最近的真实事件，故只留一个数。
var _damage: int = 0


# ------------------------------------------------------------------ 状态

## 重置到「本波还没放过法术」。换波时调 —— 上一波的弹道不该留在新一波的画面上。
func reset() -> void:
	_damage = 0
	queue_redraw()


## 记下刚落下的一段伤害。一次施放可能发多段（子弹 / 连发），这里收的是**最后落下的那一段** ——
## 与尾栏那行结果用的是同一个数，两处不会各说各话。
func note_cast(damage: int) -> void:
	_damage = maxi(damage, 0)
	queue_redraw()


# ------------------------------------------------------------------ 落笔

## 战场底与它的 1px 普通边由 ContractScreenTheme 的 PanelSunk 铺（§3：面板框走 Theme 变体），
## 这里只画底上的东西 —— 于是这一层永远压在底槽之上，也不会把圆角与那条边盖掉。
func _draw() -> void:
	_paint_core()
	_paint_enemy()
	if _damage > 0:
		_paint_bolt()
		_paint_damage()


## 玩家核心：§2.3 明说它是**装置**（美术包络，不可点击，也不画成新主角）。
## 体 NAVY_800 + 框 GOLD_600 + 中间一颗 BLUE_100 的菱形核 —— §3 那三色逐字。
func _paint_core() -> void:
	var rect: Rect2 = _local(CombatLayout.CORE_DEVICE)
	draw_rect(rect, CombatTheme.color(CombatTheme.Role.CORE_BODY), true)
	StrokePainter.stroke_path(self, StrokePainter.rect_path(rect),
		CombatTheme.color(CombatTheme.Role.CORE_FRAME), OUTLINE_WIDTH, true)
	StrokePainter.stroke_path(self, _diamond(rect.get_center(), CORE_GEM),
		CombatTheme.color(CombatTheme.Role.CORE_INK), OUTLINE_WIDTH, true)


## 敌群：本波模型只有「敌群 HP」这一项，故这里**只画一个包络，不画个体**，
## 而且轮廓不随血量变化（§2.3 原话：「战斗模型若仅有敌群 HP，轮廓只表达敌群」）。
## 体 BROWN_400 + 轮廓 GREY_300 2px + 危险标记 RED_400（§3 的敌人无素材兜底那一行）。
func _paint_enemy() -> void:
	var centre: Vector2 = _enemy_centre()
	draw_circle(centre, ENEMY_RADIUS, CombatTheme.color(CombatTheme.Role.ENEMY_BODY))
	StrokePainter.stroke_path(self, _circle(centre, ENEMY_RADIUS),
		CombatTheme.color(CombatTheme.Role.ENEMY_OUTLINE), OUTLINE_WIDTH, true)
	var at: Vector2 = centre + Vector2(ENEMY_RADIUS * DANGER_AT, -ENEMY_RADIUS * DANGER_AT)
	StrokePainter.stroke_path(self, PackedVector2Array([
		at + Vector2(0.0, -DANGER_SIZE),
		at + Vector2(DANGER_SIZE, DANGER_SIZE),
		at + Vector2(-DANGER_SIZE, DANGER_SIZE),
	]), CombatTheme.color(CombatTheme.Role.ENEMY_DANGER), OUTLINE_WIDTH, true)


## 一次施法的落点：从装置心到敌群心的一条丝线（§3：NAVY_600 底 4px + BLUE_400 芯 2px，
## 与地图上那两支同源）。先底后芯，于是那一线在深底上也读得出。
func _paint_bolt() -> void:
	var points: PackedVector2Array = PackedVector2Array([_core_centre(), _enemy_centre()])
	StrokePainter.stroke_path(self, points,
		CombatTheme.color(CombatTheme.Role.BOLT_BASE), BOLT_BASE_WIDTH, false)
	StrokePainter.stroke_path(self, points,
		CombatTheme.color(CombatTheme.Role.BOLT_CORE), BOLT_CORE_WIDTH, false)


## 伤害读数：一帧**只有一个**，而且只画最近那一次真实事件（C04）。位置由敌群包络推出来 ——
## 不新增版面常量：它紧贴敌群左上缘、落在那个美术包络**里面**（§4 的「遮挡」账里，它算 FX 不算实体）。
## 字号取正文档 16（§1 没有给这一行定档：它是读数，不是装饰，故不取 caption）。
func _paint_damage() -> void:
	var font: Font = Fonts.ui_font()
	if font == null:
		return
	var centre: Vector2 = _enemy_centre()
	var at: Vector2 = Vector2(centre.x - ENEMY_RADIUS, centre.y - ENEMY_RADIUS - DAMAGE_GAP)
	draw_string(font, at, str(_damage), HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		ContractTheme.FONT_BODY, CombatTheme.color(CombatTheme.Role.FIELD_INK))


# ------------------------------------------------------------------ 几何

## 某个包络在**战场局部坐标**里的 rect（版式表给的是屏坐标，战场是屏内一层）。
static func _local(rect: Rect2) -> Rect2:
	return Rect2(CombatLayout.to_local(rect.position), rect.size)


static func _core_centre() -> Vector2:
	return _local(CombatLayout.CORE_DEVICE).get_center()


static func _enemy_centre() -> Vector2:
	return _local(CombatLayout.ENEMY_PRESENTATION).get_center()


## 折线逼近的圆。笔只画折线，因此圆也必须是一条折线 —— 这样圆与其它笔画同宽同圆角。
static func _circle(centre: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for index: int in CIRCLE_SEGMENTS:
		var angle: float = TAU * float(index) / float(CIRCLE_SEGMENTS)
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


## 菱形（法力核）。四个顶点，闭合 —— 装置上的那一点蓝。
static func _diamond(centre: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([centre + Vector2(0.0, -radius), centre + Vector2(radius, 0.0),
		centre + Vector2(0.0, radius), centre + Vector2(-radius, 0.0)])
