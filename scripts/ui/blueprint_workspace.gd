## blueprint_workspace.gd
## 职责：整备界面的蓝图工作区（FIRST PLAYABLE 1/4）—— 节点仓库拖出、画布网格吸附与连线、存 / 读；
##       外加战斗界面的**只读机器视图**（FIRST PLAYABLE 2/4）—— 把机器画出来、把运行时状态画成可见反馈。
## 所属系统：ui
## 依赖：Palette、BlueprintData / NodeData / ConnectionData、SignalPulse、MachineRuntime（只读，仅 VIEWER 角色）
## 禁止：不得判断任何原始输入事件类型 —— 拖放一律交给 Godot 原生 drag-and-drop
##       （_get_drag_data / _can_drop_data / _drop_data 都不接 InputEvent），
##       于是鼠标与触摸天然走同一条代码路径，03 §8「原始事件只在 input_normalizer.gd 翻译」不被破坏；
##       不得写任何字面色值（06 §10.7）；不得出现任何会自动推进的构造（Timer / _process，03 §2）——
##       机器由 MachineDriver 推进，本文件只画，不推；
##       不得实现信号传播 / 数值 / 战斗 / 类型校验 / 环路检测 / 删除 / 撤销 —— 传播与数值在
##       scripts/gameplay/machine_runtime.gd，校验属 S2-06 及以后。
##
## 一个脚本担三个角色（ALLOWED FILES 只给了两个界面文件，故不再拆新文件）：
##   Area.CANVAS    挂 RegionCenter —— 持有蓝图数据、画节点与连线、接收落点；
##   Area.WAREHOUSE 挂 RegionBottom —— 画 7 个仓库槽位、只提供拖拽源；
##   Area.VIEWER    挂 COMBAT 的 MachineView —— **只读**：不接拖放、不建图、不落盘，
##                  只把 combat_screen 交进来的蓝图与 MachineRuntime 画出来。
## 角色之间不必互相持有：仓库只产出拖拽载荷，落点判定全在画布一侧，载荷本身就是接口；
## 视图只读运行时的公开只读方法，也不是接口的另一半 —— 方向是单向的（仿真 → 视图）。
##
## 为什么用原生 drag-and-drop 而不是自己读事件：本仓库把「鼠标 / 触摸的分支」收在 InputNormalizer
## 一处（03 §8），而原生拖放不含任何来源分支，触摸端由引擎的 emulate_mouse_from_touch（工程默认开）
## 合成 —— 这正是「不另写一套输入」的最省实现。代价见交付报告的【偏离规范之处】。

class_name BlueprintWorkspace
extends Control

## 本节点的角色。三个值分别对应 .tscn 里的 BlueprintCanvas / NodeWarehouse / MachineView。
## VIEWER 追加在末尾：枚举值会被 .tscn 按整数写死（`area = 1`），插在中间会静默把仓库变成视图。
enum Area {
	CANVAS,
	WAREHOUSE,
	VIEWER,
}

## 06 §4 的节点卡记法。
const GRID: float = 24.0
const CARD: float = 24.0
const MARKER: float = 4.0
const PORT: float = 3.0
const SLOT_PITCH_MAX: float = 28.0
const SLOT_GAP_MIN: float = 1.0
const DRAG_ALPHA: float = 0.7
const LABEL_HEIGHT: float = 10.0
const LABEL_FONT_SIZE: int = 8
const MARKER_INSET: float = 2.0
## 火花（信号 / 占位弹丸）的边长。04 §3.10 要求 FX 三层（芯 / 体 / 描边），各占 1px 时最小就是 6×6。
const SPARK: float = 6.0
## 占位弹丸升起的高度（像素）。升到顶即消失，不留轨迹。
const SHOT_RISE: float = 48.0

## 拖拽载荷的类型标签。
const PAYLOAD_NODE: StringName = &"node"
const PAYLOAD_CONNECT: StringName = &"connect"
## 端口名。端口数量与语义属蓝图系统（03 §4.2），本卡只用到一进一出。
const PORT_OUT: StringName = &"out"
const PORT_IN: StringName = &"in"

## 仓库清单：1×CORE / 3×FUNCTION / 3×WEAPON（本卡范围）。顺序即槽位顺序。
##
## function_kind 是 2/4 卡才加的一列：三个 FUNCTION 槽位在**卡片上长得一模一样**
## （06 §4 的类型标识只按 Kind 分三色，不分小类），分别全靠这一列 ——
## 拖出去的节点带的是哪种行为，就是从这里传下去的。CORE / WEAPON 没有可选项，一律 NONE。
const WAREHOUSE: Array[Dictionary] = [
	{"kind": NodeData.Kind.CORE, "name": "核心", "function_kind": NodeData.Function.NONE},
	{"kind": NodeData.Kind.FUNCTION, "name": "分流", "function_kind": NodeData.Function.SPLIT},
	{"kind": NodeData.Kind.FUNCTION, "name": "增幅", "function_kind": NodeData.Function.AMPLIFY},
	{"kind": NodeData.Kind.FUNCTION, "name": "延迟", "function_kind": NodeData.Function.DELAY},
	{"kind": NodeData.Kind.WEAPON, "name": "针", "function_kind": NodeData.Function.NONE},
	{"kind": NodeData.Kind.WEAPON, "name": "炸弹", "function_kind": NodeData.Function.NONE},
	{"kind": NodeData.Kind.WEAPON, "name": "锯", "function_kind": NodeData.Function.NONE},
]

@export var area: Area = Area.CANVAS

## 蓝图落盘路径。默认取 BlueprintData 登记的用户目录（03 §9），不在这里另抄一份路径。
## 测试会把它改到 user://test_blueprints —— 正式存档目录只能由玩家的游戏写。
var blueprint_path: String = BlueprintData.DEFAULT_SAVE_DIR.path_join("blueprint_01.tres")

## 画布：node_id -> 卡片在画布内的矩形。**位置是会话内的界面状态，不进 NodeData** ——
## 数据类只管图（节点 + 有向边），把布局塞进去会让存档的语义变成「界面快照」。
## 代价：重载后节点按数组顺序重新落格，玩家上次的摆位不留存（见交付报告）。
var _boxes: Dictionary = {}
var _blueprint: BlueprintData = null
## 新节点 id 的自增序号。见 _next_id 的防撞说明。
var _counter: int = 0
## 载入的节点还在等一个有效尺寸才能落格（见 _on_resized）。
var _awaiting_size: bool = false

## 仅 Area.VIEWER 用：由 combat_screen 交进来的机器运行时。为 null 时只画静态的图与连线。
## 它是**只读**引用 —— 本文件只调它的 pulses / is_lit / shot_age 这些取数方法，不调 tick()。
var runtime: MachineRuntime = null


func _ready() -> void:
	# 分区容器一律 MOUSE_FILTER_IGNORE（test_preparation 逐个断言），命中必须由本节点自己接住；
	# 分区的子节点不受父级 IGNORE 影响 —— 拾取先递归子节点，IGNORE 只挡它自己。
	mouse_filter = Control.MOUSE_FILTER_STOP
	_blueprint = BlueprintData.new()
	# 尺寸由 apply_layout_for 给，槽位与卡片都按 size 现算不缓存，故改尺寸只需重画。
	resized.connect(_on_resized)
	if area == Area.WAREHOUSE:
		return
	if area == Area.VIEWER:
		# 只读视图：图由 combat_screen 在它自己的 _ready 里交进来（那边已经读过一次盘），
		# 这里不重复读。整块不接触输入 —— COMBAT 期间玩家不操控任何东西（06 §10）。
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	_load_blueprint()


## 本节点入树时尺寸还是 0 —— 落位由 preparation_screen 在 _ready() 之后调 apply_layout_for。
## 那之前载入的节点只能先记着，等尺寸到手再落格，否则会全部叠在 (0,0)。
func _on_resized() -> void:
	queue_redraw()
	if _awaiting_size and size.x > 0.0 and size.y > 0.0:
		_awaiting_size = false
		_relayout()


## 当前蓝图。只读用途：测试与后续系统（信号传播 / 校验）都从这里取，不另开访问路径。
func blueprint() -> BlueprintData:
	return _blueprint


## 丢弃内存里的图，重新从磁盘载入。测试用它把上一次实验的残留清干净。
func reload() -> void:
	_blueprint = BlueprintData.new()
	_boxes.clear()
	_counter = 0
	_awaiting_size = false
	_load_blueprint()
	queue_redraw()


func _draw() -> void:
	if area == Area.WAREHOUSE:
		_draw_warehouse()
		return
	_draw_connections()
	for node_id: StringName in _boxes:
		_draw_card(_boxes[node_id], _kind_of(node_id))
	_draw_effects()


## 仓库槽位：24×24（06 §4），底部仓库同样取 24×24。间距优先 28；
## 装不下时退到不重叠的最小间距并**少放几个** —— 底条在窄屏只有 180px 宽，
## 再被 CTA 占去 44px，7 个槽位几何上放不下，硬挤会叠在一起或压到 CTA 底下。
func _slot_layout() -> Dictionary:
	var count: int = WAREHOUSE.size()
	var pitch: float = SLOT_PITCH_MAX
	var shown: int = count
	if count > 1:
		pitch = minf(SLOT_PITCH_MAX, (size.x - CARD) / float(count - 1))
		if pitch < CARD + SLOT_GAP_MIN:
			pitch = CARD + SLOT_GAP_MIN
			shown = maxi(1, 1 + int((size.x - CARD) / pitch))
	return {"pitch": pitch, "shown": mini(shown, count)}


func _slot_rect(index: int) -> Rect2:
	var layout: Dictionary = _slot_layout()
	var block: float = CARD + LABEL_HEIGHT
	return Rect2(Vector2(index * float(layout["pitch"]), floorf((size.y - block) * 0.5)),
		Vector2(CARD, CARD))


## 落在哪个槽位上。命中区就是 24×24 的槽位本身 —— 24 逻辑像素在 2× 下 = 48 设备像素（06 §4）。
func _slot_at(at: Vector2) -> int:
	var shown: int = int(_slot_layout()["shown"])
	for index: int in shown:
		if _slot_rect(index).has_point(at):
			return index
	return -1


func _draw_warehouse() -> void:
	var font: Font = get_theme_default_font()
	var text_color: Color = Palette.get_color(Palette.Key.WHITE)
	var shown: int = int(_slot_layout()["shown"])
	for index: int in shown:
		var rect: Rect2 = _slot_rect(index)
		var entry: Dictionary = WAREHOUSE[index]
		_draw_card(rect, int(entry["kind"]))
		if font != null:
			# 名称不画在卡片上（06 §4：24px 放不下可读中文，名称归 Tooltip 与右侧详情面板）。
			# 仓库槽位底下这一行是本卡唯一的名称落点，用 §1 的正文字号下限 8px。
			draw_string(font, Vector2(rect.position.x, rect.end.y + LABEL_FONT_SIZE),
				String(entry["name"]), HORIZONTAL_ALIGNMENT_CENTER, CARD, LABEL_FONT_SIZE, text_color)


## 06 §4：底色 NAVY_700、外框 1px BROWN_600、左上 4×4 类型标识、左右各一个 3×3 端口。
func _draw_card(rect: Rect2, kind: int) -> void:
	draw_rect(rect, Palette.get_color(Palette.Key.NAVY_700), true)
	draw_rect(rect, Palette.get_color(Palette.Key.BROWN_600), false, 1.0)
	draw_rect(Rect2(rect.position + Vector2(MARKER_INSET, MARKER_INSET), Vector2(MARKER, MARKER)),
		_kind_color(kind), true)
	var port_color: Color = Palette.get_color(Palette.Key.BROWN_300)
	var port_y: float = rect.position.y + (CARD - PORT) * 0.5
	draw_rect(Rect2(Vector2(rect.position.x, port_y), Vector2(PORT, PORT)), port_color, true)
	draw_rect(Rect2(Vector2(rect.end.x - PORT, port_y), Vector2(PORT, PORT)), port_color, true)


func _kind_color(kind: int) -> Color:
	match kind:
		NodeData.Kind.CORE:
			return Palette.get_color(Palette.Key.GOLD_400)
		NodeData.Kind.WEAPON:
			return Palette.get_color(Palette.Key.ORANGE_500)
		_:
			return Palette.get_color(Palette.Key.BLUE_400)


func _draw_connections() -> void:
	var color: Color = Palette.get_color(Palette.Key.BLUE_300)
	for link: ConnectionData in _blueprint.connections:
		if not (_boxes.has(link.from_node_id) and _boxes.has(link.to_node_id)):
			continue
		draw_line(_anchor(_boxes[link.from_node_id], false), _anchor(_boxes[link.to_node_id], true),
			color, 1.0)


## 输出锚点在卡片右缘、输入锚点在左缘，都取纵向中点（06 §4：输出在右、输入在左）。
func _anchor(box: Rect2, is_input: bool) -> Vector2:
	var y: float = box.position.y + CARD * 0.5
	return Vector2(box.position.x if is_input else box.end.x, y)


## 拖动预览：06 §4 要求拖动时 70% 半透明。
func _make_preview(kind: int) -> Control:
	var preview := Control.new()
	preview.size = Vector2(CARD, CARD)
	preview.modulate.a = DRAG_ALPHA
	_add_swatch(preview, Vector2.ZERO, Vector2(CARD, CARD), Palette.get_color(Palette.Key.NAVY_700))
	_add_swatch(preview, Vector2(MARKER_INSET, MARKER_INSET), Vector2(MARKER, MARKER), _kind_color(kind))
	return preview


func _add_swatch(parent: Control, at: Vector2, box: Vector2, color: Color) -> void:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.position = at
	swatch.size = box
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(swatch)


func _get_drag_data(at: Vector2) -> Variant:
	if area == Area.WAREHOUSE:
		var index: int = _slot_at(at)
		if index < 0:
			return null
		var entry: Dictionary = WAREHOUSE[index]
		set_drag_preview(_make_preview(int(entry["kind"])))
		return {
			"type": PAYLOAD_NODE,
			"kind": int(entry["kind"]),
			"name": String(entry["name"]),
			"function_kind": int(entry["function_kind"]),
		}
	# 只读视图不接拖放：COMBAT 期间蓝图不可编辑（03 §4.3）。
	if area != Area.CANVAS:
		return null
	# 画布：按住一张卡片就是「从它的输出端口拉一根线出去」。
	# 抓取面取整张卡片而不是 3×3 的端口方块 —— 06 §1 的触摸下限是 24 逻辑像素（2× 下 48 设备像素），
	# 3×3 的方块在触摸端抓不住，端口的 3×3 只作视觉标记（同「视觉矩形 vs 命中矩形」的既有做法）。
	var node_id: StringName = _card_at(at)
	if String(node_id).is_empty():
		return null
	set_drag_preview(_make_preview(_kind_of(node_id)))
	return {"type": PAYLOAD_CONNECT, "from": node_id}


func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if area != Area.CANVAS or typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	if payload.get("type", &"") == PAYLOAD_NODE:
		return true
	var target: StringName = _card_at(at)
	return not String(target).is_empty() and target != StringName(payload.get("from", &""))


func _drop_data(at: Vector2, data: Variant) -> void:
	var payload: Dictionary = data
	if payload.get("type", &"") == PAYLOAD_NODE:
		var function_kind: int = int(payload.get("function_kind", NodeData.Function.NONE))
		_add_node(int(payload["kind"]), String(payload["name"]), at, function_kind)
		return
	if not _connect(StringName(payload.get("from", &"")), _card_at(at)):
		return
	queue_redraw()


## 落一个节点。function_kind 有缺省值：不带行为信息的调用方（旧测试、将来的程序化建图）
## 拿到的是「直通」，不会因为少传一个参数就落出一个行为随机的节点。
func _add_node(kind: int, display_name: String, at: Vector2,
		function_kind: int = NodeData.Function.NONE) -> void:
	var node := NodeData.new()
	node.id = _next_id(kind)
	node.display_name = display_name
	node.kind = kind
	node.function_kind = function_kind
	_blueprint.nodes.append(node)
	_boxes[node.id] = _snapped(at)
	_save_blueprint()
	queue_redraw()


## 落点吸附到 24px 网格（06 §4），并以落点为卡片中心；再夹回画布内，免得卡片被拖出可视区。
func _snapped(at: Vector2) -> Rect2:
	var grid := Vector2(GRID, GRID)
	var top_left: Vector2 = (at - Vector2(CARD, CARD) * 0.5).snapped(grid)
	var limit: Vector2 = (size - Vector2(CARD, CARD)).max(Vector2.ZERO)
	top_left.x = clampf(top_left.x, 0.0, floorf(limit.x / GRID) * GRID)
	top_left.y = clampf(top_left.y, 0.0, floorf(limit.y / GRID) * GRID)
	return Rect2(top_left, Vector2(CARD, CARD))


## 新节点 id。序号只增不减且从「当前节点数」起算，加上类型前缀，
## 不会与存档里既有的 id 撞车（既有 id 是同一套规则生成的，序号必 ≤ 节点数）。
func _next_id(kind: int) -> StringName:
	_counter += 1
	return StringName("%s_%d" % [String(NodeData.Kind.find_key(kind)).to_lower(), _counter])


func _card_at(at: Vector2) -> StringName:
	for node_id: StringName in _boxes:
		if (_boxes[node_id] as Rect2).has_point(at):
			return node_id
	return &""


func _kind_of(node_id: StringName) -> int:
	for node: NodeData in _blueprint.nodes:
		if node.id == node_id:
			return node.kind
	return NodeData.Kind.FUNCTION


## 连线：任意两个不同节点之间的一条有向边。06 §4.2 的端口语义是「输出 → 输入」。
##
## 本卡**不做**类型校验与环路检测（S2-06），但自环与重复边直接挡掉：前者会画出一条零长度的线，
## 后者会让同一个 ConnectionData 存两份 —— 两条都不是「校验」，是数据完整性。
##
## 成功即落盘（与 _add_node 对称）：让「改图」和「存盘」绑在同一个动作里，
## 调用方不必记得补一次保存 —— 漏补的那条边会在重进场景后凭空消失。
func _connect(from_id: StringName, to_id: StringName) -> bool:
	if String(from_id).is_empty() or String(to_id).is_empty() or from_id == to_id:
		return false
	for link: ConnectionData in _blueprint.connections:
		if link.from_node_id == from_id and link.to_node_id == to_id:
			return false
	var link := ConnectionData.new()
	link.from_node_id = from_id
	link.from_port = PORT_OUT
	link.to_node_id = to_id
	link.to_port = PORT_IN
	_blueprint.connections.append(link)
	_save_blueprint()
	return true


func _save_blueprint() -> void:
	_blueprint.save_to(blueprint_path)


## 载入存档。文件不存在是**首次进游戏的正常情况**，故先查存在性 ——
## BlueprintData.load_from 对缺失文件会 push_error，直接调会在干净环境里刷一条假错误。
func _load_blueprint() -> void:
	if not ResourceLoader.exists(blueprint_path):
		return
	var loaded: BlueprintData = BlueprintData.load_from(blueprint_path)
	if loaded == null:
		return
	_blueprint = loaded
	_counter = _blueprint.nodes.size()
	_awaiting_size = size.x <= 0.0 or size.y <= 0.0
	if _awaiting_size:
		return
	_relayout()
	queue_redraw()


## 重载后按数组顺序重新落格。位置不进 NodeData，故这里只能给出确定性的默认摆位。
func _relayout() -> void:
	_boxes.clear()
	var columns: int = maxi(1, int(floorf(size.x / GRID)))
	for index: int in _blueprint.nodes.size():
		var node: NodeData = _blueprint.nodes[index]
		if String(node.id).is_empty():
			continue
		var cell := Vector2(float(index % columns), float(index / columns)) * GRID
		var limit: Vector2 = (size - Vector2(CARD, CARD)).max(Vector2.ZERO)
		cell.x = minf(cell.x, floorf(limit.x / GRID) * GRID)
		cell.y = minf(cell.y, floorf(limit.y / GRID) * GRID)
		_boxes[node.id] = Rect2(cell, Vector2(CARD, CARD))


## COMBAT 只读视图（Area.VIEWER）的可见反馈 —— 卡片要求的「信号经过节点 / 连线时必须有可见变化」：
##   · 在途信号   → 连线上的火花，位置由 pulse.progress() 插值；
##   · 节点被点亮 → 卡片描边闪一下 BLUE_050（窗口由 MachineRuntime.FLASH_TICKS 定）；
##   · 武器开火   → 卡片上缘升起一枚占位弹丸（存活期由 MachineRuntime.SHOT_TICKS 定）。
##
## 本函数**只读** runtime，一个仿真状态都不改 —— 视图与仿真是单向的，
## 于是「画得对不对」永远不会反过来影响「跑得对不对」。位置一律由节拍序号算出，不读真实时间（03 §6）。
func _draw_effects() -> void:
	if runtime == null:
		return
	for pulse: SignalPulse in runtime.pulses():
		if not (_boxes.has(pulse.from_node_id) and _boxes.has(pulse.to_node_id)):
			continue
		var from: Vector2 = _anchor(_boxes[pulse.from_node_id], false)
		var to: Vector2 = _anchor(_boxes[pulse.to_node_id], true)
		_draw_spark(from.lerp(to, pulse.progress()))
	for node_id: StringName in _boxes:
		var box: Rect2 = _boxes[node_id]
		if runtime.is_lit(node_id):
			draw_rect(box, Palette.get_color(Palette.Key.BLUE_050), false, 1.0)
		var age: int = runtime.shot_age(node_id)
		if age >= 0:
			_draw_spark(Vector2(box.position.x + CARD * 0.5, box.position.y - _rise(age)))


## 占位弹丸从武器卡片上缘垂直升起；升到 SHOT_RISE 时恰好用完 MachineRuntime.SHOT_TICKS 拍，随即消失。
func _rise(age: int) -> float:
	return SHOT_RISE * float(age + 1) / float(MachineRuntime.SHOT_TICKS)


## 信号与弹丸画成同一个东西：04 §3.10 的 FX 三层结构（芯 BLUE_050 / 体 BLUE_FX_600 / 描边 NAVY_900）。
## 三层缺一不可，故最小尺寸就是 6×6 —— 这正合意：类型标识讲「这是什么节点」，
## 火花讲「此刻这里有事发生」，后者本就该更亮眼。
func _draw_spark(center: Vector2) -> void:
	var box := Rect2((center - Vector2(SPARK, SPARK) * 0.5).floor(), Vector2(SPARK, SPARK))
	draw_rect(box, Palette.get_color(Palette.Key.NAVY_900), true)
	draw_rect(box.grow(-1.0), Palette.get_color(Palette.Key.BLUE_FX_600), true)
	draw_rect(box.grow(-2.0), Palette.get_color(Palette.Key.BLUE_050), true)
