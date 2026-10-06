## blueprint_workspace.gd
## 职责：整备界面的蓝图工作区（FIRST PLAYABLE 1/4）—— 节点仓库拖出、画布网格吸附与连线、存 / 读；
##       外加**选中与删改**（S2-05 补课）—— 选中节点 / 连线、删除（连带清掉挂在节点上的线）、
##       撤销栈、清空整张图，改动即落盘；
##       外加战斗界面的**只读机器视图**（FIRST PLAYABLE 2/4）—— 把机器画出来、把运行时状态画成可见反馈；
##       其中**开火反馈按武器种类分成三种形态**（PET-76：针 / 炸弹 / 锯 一眼能分开）；
##       外加把 REWARD 选中的奖励落到画布（S4-07 最小版，见 add_reward_node）。
## 所属系统：ui
## 依赖：Palette、Settings（只订阅语言变化，用于重画）、InputNormalizer / SemanticInput（仅归一指针，
##       用于选中）、BlueprintData / NodeData / ConnectionData、SignalPulse、MachineRuntime（只读，仅 VIEWER 角色）
## 禁止：不得判断任何原始输入事件类型 —— 拖放交给 Godot 原生 drag-and-drop
##       （_get_drag_data / _can_drop_data / _drop_data 都不接 InputEvent），
##       选中交给 gui_input **信号** + InputNormalizer.from_event（与 preparation_screen.gd 的窄屏
##       信息条同一条已批准路径：本文件不出现任何 InputEvent* 类型名），
##       于是鼠标与触摸天然走同一条代码路径，03 §8「原始事件只在 input_normalizer.gd 翻译」不被破坏；
##       键盘（Delete / Backspace / Ctrl+Z）**不在本文件** —— 它落在场景侧那两个按钮的
##       Button.shortcut 上（见 preparation.tscn），因此键位不必在本层再开一个出口；
##       不得写任何字面色值（06 §10.7）；不得出现任何会自动推进的构造（Timer / _process，03 §2）——
##       机器由 MachineDriver 推进，本文件只画，不推；
##       不得实现信号传播 / 数值 / 战斗 / 类型校验 / 环路检测 —— 传播与数值在
##       scripts/gameplay/machine_runtime.gd，校验属 S2-06 及以后（本卡明确不做）。
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

## 图或选中态变了。宿主界面（preparation_screen.gd）据此刷新三个动作按钮的可用性 ——
## 不订阅的话，「选中一个节点后删除按钮才可用」这件事就没有触发点：选中发生在画布内部的
## gui_input 与拖放里，宿主看不到。
signal blueprint_changed()

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
const SLOT_PITCH_MAX: float = 28.0
const SLOT_GAP_MIN: float = 1.0
const DRAG_ALPHA: float = 0.7
const LABEL_HEIGHT: float = 10.0
const LABEL_FONT_SIZE: int = 8
const MARKER_INSET: float = 2.0
## 火花（信号）的边长。04 §3.10 要求 FX 三层（芯 / 体 / 描边），各占 1px 时最小就是 6×6。
const SPARK: float = 6.0

## 三把武器的**开火形态**（PET-76 可读性）。给的是 FX 三层的**外框**尺寸，逐层内缩 1px。
##   针   → 3×8  细长的一条（外框内缩后只剩 1×6 的体）
##   炸弹 → 7×7  方块状的一团
##   锯   → 11×4 横扁的一条
## 三者的**长宽比**两两不同（0.4 / 1.0 / 2.8），于是静止的一帧里也读得出是哪把武器开的火。
## 颜色不承担这件事：04 §3.10 只给了**一套** FX 三层色（描边 NAVY_900 / 体 BLUE_FX_600 /
## 芯 BLUE_050），拿色相去分三把武器会变成第二套色语言，而 04 §3 的语义色是冻结的。
const CUE_NEEDLE: Vector2 = Vector2(3.0, 8.0)
const CUE_BOMB: Vector2 = Vector2(7.0, 7.0)
const CUE_SAW: Vector2 = Vector2(11.0, 4.0)

## 开火反馈从卡片上缘升起的高度（像素）。**刻意远小于一条穿过战场的弹道**：
## 「打到谁」由 combat_screen 画的弹道线负责（PET-76），这里只回答「哪把武器发动了」，
## 于是反馈贴在卡片上缘那一小段里，不会与弹道混成一片。
const CUE_RISE: float = 8.0

## VB-03 已批准节点卡切片（PET-77 接入）。固定 24×24，**直接当 Texture2D 用，不走 StyleBox** ——
## 九宫格是给「会被拉伸的框」用的，而卡片永远画在自己的 24×24 格子上，没有中间那一段要拉。
const CARD_SLICE_DIR: String = "res://assets/ui/vb03_component_language/"
const CARD_SLICE_NORMAL: Array[String] = [
	"ui_node_card_core_24.png",
	"ui_node_card_function_24.png",
	"ui_node_card_weapon_24.png",
]
## 选中态另有一张：卡片的三段式（底 / 描边 / 标识）整张换了色，不是叠一个环。
const CARD_SLICE_SELECTED: String = "ui_node_card_selected_24.png"

## 选中辉光的落笔位置：卡片**外侧** 1px。06 §2.1 把 BLUE_300 定为选中态判据色（四边整圈），
## 画在卡片边长上会把卡片自己那圈 BROWN_600 描边盖掉 —— 两种状态要能同时读出来。
## 连线的命中走廊半宽。1px 的线在触摸端抓不住，所以要一条走廊；但也不能再宽：
## 网格步长只有 24px，走廊一宽就会把「点空白处取消选中」整个吃掉。卡片永远优先于连线。
const LINK_HIT: float = 8.0
## 撤销栈的深度上限（本卡只要求一步，多步是顺带做的）。见 _push_history 的快照说明。
const HISTORY_MAX: int = 20

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
##
## weapon_kind 同理是武器槽位的那一列：三张武器槽在卡片上也长得一模一样，
## 「拖出去的是针还是锯」只由这一列决定。**这是它的唯一来源** —— 从前是拿中文显示名
## 反查武器，那样一见 I18N 就整表落空（WeaponData.BY_DISPLAY_NAME 已删）。
## 非武器槽位一律 NONE：给它们也写上武器种类，会让「这是不是武器」有两个互相矛盾的答案。
const WAREHOUSE: Array[Dictionary] = [
	{"kind": NodeData.Kind.CORE, "name": "核心",
		"function_kind": NodeData.Function.NONE, "weapon_kind": NodeData.WeaponKind.NONE},
	{"kind": NodeData.Kind.FUNCTION, "name": "分流",
		"function_kind": NodeData.Function.SPLIT, "weapon_kind": NodeData.WeaponKind.NONE},
	{"kind": NodeData.Kind.FUNCTION, "name": "增幅",
		"function_kind": NodeData.Function.AMPLIFY, "weapon_kind": NodeData.WeaponKind.NONE},
	{"kind": NodeData.Kind.FUNCTION, "name": "延迟",
		"function_kind": NodeData.Function.DELAY, "weapon_kind": NodeData.WeaponKind.NONE},
	{"kind": NodeData.Kind.WEAPON, "name": "针",
		"function_kind": NodeData.Function.NONE, "weapon_kind": NodeData.WeaponKind.NEEDLE},
	{"kind": NodeData.Kind.WEAPON, "name": "炸弹",
		"function_kind": NodeData.Function.NONE, "weapon_kind": NodeData.WeaponKind.BOMB},
	{"kind": NodeData.Kind.WEAPON, "name": "锯",
		"function_kind": NodeData.Function.NONE, "weapon_kind": NodeData.WeaponKind.SAW},
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
## 选中态：至多一个有效。&"" / -1 表示没有选中。连线的下标会随数组增删而失效，
## 故每一处改动连线数组的地方都必须同时清理它（本文件里都收敛在 _clear_selection 上）。
var _selected_node: StringName = &""
var _selected_link: int = -1
## 撤销栈：每项是一次改动**之前**的快照。快照的代价随图的规模走，不随改动种类走 ——
## 反向操作则每多一种改法就要多写一条反向路径，漏写一条就是一次静默的错误撤销。
var _history: Array[Dictionary] = []
## 载入的节点还在等一个有效尺寸才能落格（见 _on_resized）。
var _awaiting_size: bool = false

## 切片纹理缓存（路径 → Texture2D）。见 _texture()。
var _textures: Dictionary = {}

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
	# 仓库槽位名要经 tr() 出字（06 §11），而 draw_string 画的是**当时那种语言**的成品 ——
	# 切了语言不重画，那 7 个标签就一直停在旧译文上（S4-07 实测：英文态下仍是中文）。
	# 订阅的是「设置项变了」这个事实，判的是 key，不是「现在是哪种语言」——
	# 本文件因此不含任何语言分支（06 §11）。
	Settings.setting_changed.connect(_on_setting_changed)
	if area == Area.WAREHOUSE:
		return
	if area == Area.VIEWER:
		# 只读视图：图由 combat_screen 在它自己的 _ready 里交进来（那边已经读过一次盘），
		# 这里不重复读。整块不接触输入 —— COMBAT 期间玩家不操控任何东西（06 §10）。
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	_load_blueprint()
	# 选中：按下经 gui_input **信号**进本文件，再交给 InputNormalizer 归一 —— 本文件因此只认
	# POINTER_PRESS 这个语义动作，不认「按的是鼠标还是手指」（03 §8）。
	# **不调 accept_event()**：本文件只记选中、不改图，事件该继续上浮给宿主
	# （点画布也该能关掉提示面板），拦下来是多余的。
	gui_input.connect(_on_canvas_gui_input)


## 本节点入树时尺寸还是 0 —— 落位由 preparation_screen 在 _ready() 之后调 apply_layout_for。
## 那之前载入的节点只能先记着，等尺寸到手再落格，否则会全部叠在 (0,0)。
func _on_resized() -> void:
	queue_redraw()
	if _awaiting_size and size.x > 0.0 and size.y > 0.0:
		_awaiting_size = false
		_relayout()


## 语言变了就重画。只认 KEY_LOCALE 一个 key —— 别的设置项（音量之类）与画面无关，
## 跟着重画只是白费一次绘制。
func _on_setting_changed(key: StringName) -> void:
	if key == Settings.KEY_LOCALE:
		queue_redraw()


## 当前蓝图。只读用途：测试与后续系统（信号传播 / 校验）都从这里取，不另开访问路径。
func blueprint() -> BlueprintData:
	return _blueprint


## 丢弃内存里的图，重新从磁盘载入。测试用它把上一次实验的残留清干净。
func reload() -> void:
	_blueprint = BlueprintData.new()
	_boxes.clear()
	_counter = 0
	_awaiting_size = false
	# 撤销栈与选中态都是**本次会话**的状态，跟着重载一起清空：留着上一次实验的栈，
	# 下一次撤销会把上一张图整张搬回来 —— 那比撤不动更难理解。
	_history.clear()
	_selected_node = &""
	_selected_link = -1
	_load_blueprint()
	queue_redraw()


func _draw() -> void:
	if area == Area.WAREHOUSE:
		_draw_warehouse()
		return
	_draw_connections()
	for node_id: StringName in _boxes:
		_draw_card(_boxes[node_id], _kind_of(node_id))
	_draw_selection()
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
				warehouse_label(entry), HORIZONTAL_ALIGNMENT_CENTER, CARD, LABEL_FONT_SIZE, text_color)


## 仓库槽位底下那行标签的文本（06 §11：文本走 key，key 即中文原文）。
##
## tr() 在这里、而不是在 _draw_warehouse 的调用点上：换成 draw_string(..., tr(...), ...)
## 也跑得通，但那样测试只能靠扫源码才问得出「翻译了没」；收成一个纯函数之后，
## 「切到英文时这 7 个标签读出什么」当场就能断言（见 test_i18n.gd 的同名用例）。
static func warehouse_label(entry: Dictionary) -> String:
	return String(TranslationServer.translate(String(entry["name"])))


## 06 §4 的节点卡：底色 NAVY_700、外框 1px BROWN_600、左上 4×4 类型标识、左右各一个端口 ——
## 这四件事**全部烘焙在已批准的 24×24 切片里**，故本函数只把切片贴上去，不再逐笔画。
## 这也正是 06 §10.7「不得写死像素色」想要的结果：卡片的颜色从此只在切片里有一份。
func _draw_card(rect: Rect2, kind: int) -> void:
	draw_texture_rect(_card_texture(kind), rect, false)


## 类型 → 切片文件的映射。下标与 NodeData.Kind 同序（CORE / FUNCTION / WEAPON），
## 越界或认不出的取值落到 FUNCTION 那一张 —— 与 _kind_color() 的兜底方向一致，
## 「认不出」在任何一处都不得变成一种新的类型。
func _card_file(kind: int) -> String:
	if kind < 0 or kind >= CARD_SLICE_NORMAL.size():
		return CARD_SLICE_NORMAL[NodeData.Kind.FUNCTION]
	return CARD_SLICE_NORMAL[kind]


## 切片纹理缓存。`load()` 本身有资源缓存，但**每张卡每帧调一次 load()** 仍要走一遍查找，
## 而仓库一行 7 张卡 + 画布上任意张都会经过这里。视图每帧重画，故缓存一次。
func _card_texture(kind: int) -> Texture2D:
	return _texture(CARD_SLICE_DIR + _card_file(kind))


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path)
	return _textures[path]


func _kind_color(kind: int) -> Color:
	match kind:
		NodeData.Kind.CORE:
			return Palette.get_color(Palette.Key.GOLD_400)
		NodeData.Kind.WEAPON:
			return Palette.get_color(Palette.Key.ORANGE_500)
		_:
			return Palette.get_color(Palette.Key.BLUE_400)


## 连线一律 1px（06 §4）；**选中的那条**换成 BLUE_050 并加粗到 2px。
## 只换颜色不够：320×180 上 1px 的线，两个蓝之间的差别读不出来，而「这条线现在可以删」
## 正是本卡要交付的信息。
func _draw_connections() -> void:
	var color: Color = Palette.get_color(Palette.Key.BLUE_300)
	var picked: Color = Palette.get_color(Palette.Key.BLUE_050)
	for index: int in _blueprint.connections.size():
		var link: ConnectionData = _blueprint.connections[index]
		if not (_boxes.has(link.from_node_id) and _boxes.has(link.to_node_id)):
			continue
		var selected: bool = index == _selected_link
		draw_line(_anchor(_boxes[link.from_node_id], false), _anchor(_boxes[link.to_node_id], true),
			picked if selected else color, 2.0 if selected else 1.0)


## 选中态：整张卡片换成 `ui_node_card_selected_24`（GOLD_500 外圈 + GOLD_200 内圈，
## 见 13 §10.1 三修之一「Selected = GOLD 主强调」）。至多画一件。
## VIEWER 角色不画 —— COMBAT 期间没有选中这回事（06 §10：战斗里玩家不操控任何东西）。
##
## 这里从前画的是卡片**外侧** 1px 整圈 BLUE_300 —— 那是 13 §10.1 明令不得混用的**焦点**色
## （「键盘 / 指针指到这儿了」），拿它表达「这一项被真正选中了」会让两种语义在画面上同形。
## BLUE_300 仍留在 Theme 的 PanelSelected 变体上，供将来真正的焦点态使用，只是不再冒充选中。
##
## 类型标识要补回来：选中片是一张**通用**的选中示意，它左上那 4×4 是 GOLD_400（CORE 色），
## 直接贴上去会把武器 / 功能节点一律画成核心色。故选中片之上再按真实 kind 盖一枚 4×4 标识。
func _draw_selection() -> void:
	if area != Area.CANVAS:
		return
	if String(_selected_node).is_empty() or not _boxes.has(_selected_node):
		return
	var box: Rect2 = _boxes[_selected_node]
	draw_texture_rect(_texture(CARD_SLICE_DIR + CARD_SLICE_SELECTED), box, false)
	draw_rect(Rect2(box.position + Vector2(MARKER_INSET, MARKER_INSET), Vector2(MARKER, MARKER)),
		_kind_color(_kind_of(_selected_node)), true)


## 输出锚点在卡片右缘、输入锚点在左缘，都取纵向中点（06 §4：输出在右、输入在左）。
func _anchor(box: Rect2, is_input: bool) -> Vector2:
	var y: float = box.position.y + CARD * 0.5
	return Vector2(box.position.x if is_input else box.end.x, y)


## 拖动预览：06 §4 要求拖动时 70% 半透明。预览就是**被拖走的那张卡本身** ——
## 逐块拼一张近似的（旧做法）会在拖起来的一瞬间露出「跟原位长得不一样」的破绽。
func _make_preview(kind: int) -> Control:
	var preview := TextureRect.new()
	preview.texture = _card_texture(kind)
	preview.size = Vector2(CARD, CARD)
	preview.modulate.a = DRAG_ALPHA
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return preview


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
			"weapon_kind": int(entry["weapon_kind"]),
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
		var weapon_kind: int = int(payload.get("weapon_kind", NodeData.WeaponKind.NONE))
		_add_node(int(payload["kind"]), String(payload["name"]), at, function_kind, weapon_kind)
		return
	if not _connect(StringName(payload.get("from", &"")), _card_at(at)):
		return
	queue_redraw()


## 落一个节点。function_kind / weapon_kind 都有缺省值：不带这两项信息的调用方
## （旧测试、将来的程序化建图）拿到的是「直通」与 NONE，不会因为少传一个参数就落出一个
## 行为随机 / 武器种类随机的节点 —— NONE 由 WeaponData.resolve() 按 02 §9 降级成 Needle。
func _add_node(kind: int, display_name: String, at: Vector2,
		function_kind: int = NodeData.Function.NONE,
		weapon_kind: int = NodeData.WeaponKind.NONE) -> void:
	_push_history()
	var node := NodeData.new()
	node.id = _next_id(kind)
	node.display_name = display_name
	node.kind = kind
	node.function_kind = function_kind
	node.weapon_kind = weapon_kind
	_blueprint.nodes.append(node)
	_boxes[node.id] = _snapped(at)
	_after_change()


## 把一项奖励落到画布（S4-07 最小版：三选一**真的生效**）。返回落下的节点，没落则 null。
##
## 三列类型**原样取自载荷**，载荷又取自 WAREHOUSE 那一行 —— 本函数不按显示名 / 文案反推类型，
## 也不认识「核心 / 炸弹」这些名字：它只认那份载荷。PET-70 刚删掉按显示名反查那条路，
## 在这里重开一次等于把玩家选的东西悄悄换成别的。
##
## 落点是画布内**第一个空闲格**（行优先，自左上起），确定、可复现，且**不覆盖任何既有节点**
## （03 §6：随机只能来自 RunState，而这里连随机都不需要）。
## 落完立即经既有 _save_blueprint() 落盘，故重进场景 / 重启游戏都还在。
##
## 画布填满时**不落**并返回 null（02 §9 的降级路径）：宁可少给一个节点，
## 也不能把玩家的图覆盖掉 —— 前者只是奖励没拿到，后者是把人做好的机器拆了。
func add_reward_node(reward: Dictionary) -> NodeData:
	if area != Area.CANVAS or reward.is_empty():
		return null
	var cell: Rect2 = _first_free_cell()
	if cell.size.x <= 0.0:
		return null
	_add_node(int(reward["kind"]), String(reward["name"]),
		cell.position + Vector2(CARD, CARD) * 0.5,
		int(reward["function_kind"]), int(reward["weapon_kind"]))
	return _blueprint.nodes[_blueprint.nodes.size() - 1]


## 画布内第一个空闲格（行优先）。尺寸取不到或一格都放不下时返回零矩形。
##
## 上限按 `size - CARD` 算，与 _snapped 的夹取同式：格子必须整张卡都落在画布内，
## 否则最后一行 / 最后一列会有一半在画布外。
func _first_free_cell() -> Rect2:
	var limit: Vector2 = (size - Vector2(CARD, CARD)).max(Vector2.ZERO)
	var columns: int = int(floorf(limit.x / GRID)) + 1
	var rows: int = int(floorf(limit.y / GRID)) + 1
	for row: int in rows:
		for column: int in columns:
			var cell := Rect2(Vector2(float(column), float(row)) * GRID, Vector2(CARD, CARD))
			if not _is_occupied(cell):
				return cell
	return Rect2()


## 这一格是否已被占用。Rect2.intersects() 对**只贴边**的两张卡返回 false，
## 故相邻两格（中心距 24px）不算重叠 —— 正是 06 §4 网格该有的语义。
func _is_occupied(cell: Rect2) -> bool:
	for node_id: StringName in _boxes:
		if (_boxes[node_id] as Rect2).intersects(cell):
			return true
	return false


## 落点吸附到 24px 网格（06 §4），并以落点为卡片中心；再夹回画布内，免得卡片被拖出可视区。
func _snapped(at: Vector2) -> Rect2:
	var grid := Vector2(GRID, GRID)
	var top_left: Vector2 = (at - Vector2(CARD, CARD) * 0.5).snapped(grid)
	var limit: Vector2 = (size - Vector2(CARD, CARD)).max(Vector2.ZERO)
	top_left.x = clampf(top_left.x, 0.0, floorf(limit.x / GRID) * GRID)
	top_left.y = clampf(top_left.y, 0.0, floorf(limit.y / GRID) * GRID)
	return Rect2(top_left, Vector2(CARD, CARD))


## 新节点 id：类型前缀 + 全局自增序号。序号起点由 _max_ordinal() 从**既有 id** 里取，
## 且逐个跳过已占用的 id —— 见那两处的说明。
func _next_id(kind: int) -> StringName:
	var prefix: String = String(NodeData.Kind.find_key(kind)).to_lower()
	var candidate: StringName = &""
	var taken: bool = true
	while taken:
		_counter += 1
		candidate = StringName("%s_%d" % [prefix, _counter])
		taken = _has_id(candidate)
	return candidate


## 既有 id 里出现过的最大序号。**不能取节点数**（删改之前就是这么写的）：
## 删掉中间几个节点后节点数会小于既有序号，新节点于是拿到一个**已经在用**的 id ——
## 而 _boxes 是按 id 索引的，撞车等于两张卡悄悄共用一格：其中一张再也点不到，也就删不掉。
## 手改过的存档可能压根不按本文件的命名规则，故这里只作起点，真正的保证在 _next_id 的跳过上。
func _max_ordinal() -> int:
	var highest: int = 0
	for node: NodeData in _blueprint.nodes:
		var text: String = String(node.id)
		var cut: int = text.rfind("_")
		if cut < 0:
			continue
		var tail: String = text.substr(cut + 1)
		if tail.is_valid_int():
			highest = maxi(highest, tail.to_int())
	return highest


func _has_id(node_id: StringName) -> bool:
	for node: NodeData in _blueprint.nodes:
		if node.id == node_id:
			return true
	return false


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
	# 快照压在 append **之前**，且压在全部回绝之后：被回绝的那一次没有改动任何东西，
	# 记进撤销栈只会让玩家按一次 Ctrl+Z 却什么都没变。
	_push_history()
	_blueprint.connections.append(link)
	_after_change()
	return true


func _save_blueprint() -> void:
	_blueprint.save_to(blueprint_path)


## 一次改动收尾：落盘 + 重画 + 通知宿主。三件事必须绑在一起发生 ——
## 落盘漏一次，重进场景就少一个节点；通知漏一次，三个动作按钮的可用性就停在旧状态上。
func _after_change() -> void:
	_save_blueprint()
	queue_redraw()
	blueprint_changed.emit()


# ─────────────────────── 选中与删改（S2-05 补课）───────────────────────
#
# 为什么「选中」与「执行」分成两步：触摸端没有右键菜单，一个手势只能有一件事。
# 若点一下就删，那么拖动节点、点空白处、误触边缘全都是删机器 —— 而 06 §10.4 要的是
# 破坏性操作必须可挽回（二次确认或撤销）。分两步之后，「点」永远是安全的，
# 破坏只发生在按了删除按钮之后，而删除本身还进撤销栈。
#
# 为什么选中态不进 BlueprintData：与 _boxes 同理 —— 它是界面状态，不是图的一部分。
# 进存档的话，「上次选中了哪个节点」会被持久化，重进游戏时三个按钮的可用性就由存档决定，
# 而不是由玩家眼前的画面决定。


## 画布上的按下：只改选中，不改图。位置直接可用 —— 实测 godot 交给 gui_input 的事件，
## 鼠标与触摸都**已经换算成控件局部坐标**（探针：视口 (162,70) 落在 (100,10) 的控件上，
## 归一后读到 (62,60)），与 _boxes 同一坐标系，不必再减一次 global_position。
func _on_canvas_gui_input(event: InputEvent) -> void:
	if area != Area.CANVAS:
		return
	var semantic: SemanticInput = InputNormalizer.from_event(event)
	if semantic == null or semantic.action != SemanticInput.Action.POINTER_PRESS:
		return
	select_at(semantic.position)


## 点选。卡片优先于连线（见 _link_at 的说明），两样都没点到就取消选中 ——
## 没有「点空白处取消」这条路，选中态就没有出口。
func select_at(at: Vector2) -> void:
	var node_id: StringName = _card_at(at)
	if not String(node_id).is_empty():
		_set_selection(node_id, -1)
		return
	_set_selection(&"", _link_at(at))


## 改选中并广播。宿主（preparation_screen）据此刷新三个动作按钮的可用性 ——
## 不广播的话「选中之后删除按钮才可用」这件事就没有触发点：选中发生在画布内部，
## 宿主看不到，而 03 §2 又不许轮询。
func _set_selection(node_id: StringName, link: int) -> void:
	if _selected_node == node_id and _selected_link == link:
		return
	_selected_node = node_id
	_selected_link = link
	queue_redraw()
	blueprint_changed.emit()


func _clear_selection() -> void:
	_set_selection(&"", -1)


## 命中的连线下标，没有则 -1。走廊半宽 LINK_HIT：1px 的线在触摸端抓不住，必须有一条走廊。
##
## 调用点**已经先查过卡片**，所以这里不必再给卡片让路；走廊 8px 也正因此不能再宽 ——
## 网格步长只有 24px，走廊再宽就会把两张卡之间那点空隙吃光，「点空白处取消选中」随之失效。
func _link_at(at: Vector2) -> int:
	for index: int in _blueprint.connections.size():
		var link: ConnectionData = _blueprint.connections[index]
		if not (_boxes.has(link.from_node_id) and _boxes.has(link.to_node_id)):
			continue
		var from: Vector2 = _anchor(_boxes[link.from_node_id], false)
		var to: Vector2 = _anchor(_boxes[link.to_node_id], true)
		if _distance_to_segment(at, from, to) <= LINK_HIT:
			return index
	return -1


## 点到线段的最短距离。两端锚点重合时退化成点距 —— 不这么写，span 是零向量，
## 除法会得到 NaN，比较恒为 false，那条线就永远选不中（而它恰恰是最该能删的自环状残线）。
func _distance_to_segment(point: Vector2, a: Vector2, b: Vector2) -> float:
	var span: Vector2 = b - a
	var length_squared: float = span.length_squared()
	if length_squared <= 0.0:
		return point.distance_to(a)
	var t: float = clampf((point - a).dot(span) / length_squared, 0.0, 1.0)
	return point.distance_to(a + span * t)


## 当前选中的节点 id；没选中节点时空串。
func selected_node_id() -> StringName:
	return _selected_node


## 当前选中的连线下标；没选中连线时 -1。
func selected_link_index() -> int:
	return _selected_link


## 有没有选中东西。宿主据此决定「删除」按钮可不可用（06 §10.4：不可用的操作要看得出来）。
func has_selection() -> bool:
	return not String(_selected_node).is_empty() or _selected_link >= 0


## 图里有没有内容。宿主据此决定「清空」按钮可不可用 —— 空图再清一次是空操作，
## 留着可点只会让人怀疑自己点错了。
func has_content() -> bool:
	return not _blueprint.nodes.is_empty() or not _blueprint.connections.is_empty()


## 还能不能撤销。宿主据此决定「撤销」按钮可不可用。
func can_undo() -> bool:
	return not _history.is_empty()


## 删除当前选中。没选中就是什么都没发生，返回 false —— 不记一次什么都不改的「撤销」。
func delete_selection() -> bool:
	if not String(_selected_node).is_empty():
		return delete_node(_selected_node)
	if _selected_link >= 0:
		return delete_connection(_selected_link)
	return false


## 删一个节点，**连带删掉挂在它身上的每一条线**（本卡明确要求）。
##
## 只删节点不删线的话，存档里会留下一条指向不存在节点的边：数据合法、画面上什么都不显示 ——
## 这是最难查的一类坏数据，因为没有任何一处会报错，只有等到信号传播（S2-06 之后）踩上去才炸。
## 线的两端都要查：from 是它、to 也是它，少查一端就漏一半。
func delete_node(node_id: StringName) -> bool:
	if String(node_id).is_empty() or not _has_id(node_id):
		return false
	_push_history()
	var kept_links: Array[ConnectionData] = []
	for link: ConnectionData in _blueprint.connections:
		if link.from_node_id != node_id and link.to_node_id != node_id:
			kept_links.append(link)
	_blueprint.connections = kept_links
	var kept_nodes: Array[NodeData] = []
	for node: NodeData in _blueprint.nodes:
		if node.id != node_id:
			kept_nodes.append(node)
	_blueprint.nodes = kept_nodes
	_boxes.erase(node_id)
	_clear_selection()
	_after_change()
	return true


func delete_connection(index: int) -> bool:
	if index < 0 or index >= _blueprint.connections.size():
		return false
	_push_history()
	_blueprint.connections.remove_at(index)
	_clear_selection()
	_after_change()
	return true


## 清空整张图。**二次确认不在这里** —— 那是界面的交互（按钮改文案、再点一次才算数），
## 归 preparation_screen.gd；本函数是确认之后的那一下，只做数据。
##
## 清空仍然先压一次快照，于是它也能撤销：06 §10.4 把「二次确认」与「撤销」并列为两条路，
## 这里两条都有 —— 因为「清空」是唯一一个一次能毁掉整张图的动作，代价不对称。
func clear_blueprint() -> bool:
	if not has_content():
		return false
	_push_history()
	var no_nodes: Array[NodeData] = []
	var no_links: Array[ConnectionData] = []
	_blueprint.nodes = no_nodes
	_blueprint.connections = no_links
	_boxes.clear()
	_clear_selection()
	_after_change()
	return true


## 撤销一步：把整张图换成改动**之前**的那一份快照。
##
## 为什么是快照而不是反向操作：放置 / 连线 / 删除 / 清空四种改法各要一条反向路径，
## 其中删节点那条还得把**被连带删掉的线**一并还原 —— 漏还原一条就是一次静默的错误撤销，
## 玩家看到的是「撤销完我的线少了一根」，而这类 bug 不会报错、只会慢慢被发现。
## 快照法把这个坑从「每条反向路径都要写对」压缩成「只有 _snapshot / _restore 一处要写对」。
##
## 代价诚实写明：每一份快照都是整张图的一份拷贝，栈深 HISTORY_MAX 份。
## 本卡的图是几十个节点量级，代价可忽略；真到了上千节点，该换的是增量记录，不是撤销本身。
func undo() -> bool:
	if _history.is_empty():
		return false
	_restore(_history.pop_back())
	_clear_selection()
	_after_change()
	return true


## 一份**改动之前**的图与摆位。节点 / 连线是 Resource，必须 duplicate() ——
## 存引用的话，_add_node 往数组里 append 的那一下会让「之前」的快照也一起多出一个节点，
## 撤销就成了空操作（而删除走的是重建数组，反而看不出问题：这种一半对一半错最难发现）。
func _snapshot() -> Dictionary:
	var nodes: Array[NodeData] = []
	for node: NodeData in _blueprint.nodes:
		nodes.append(node.duplicate() as NodeData)
	var links: Array[ConnectionData] = []
	for link: ConnectionData in _blueprint.connections:
		links.append(link.duplicate() as ConnectionData)
	return {
		"nodes": nodes,
		"connections": links,
		"boxes": _boxes.duplicate(),
		"counter": _counter,
	}


func _push_history() -> void:
	_history.append(_snapshot())
	# 深度上限：撤到几十步以前的那张图不是玩家要的，而每一份快照都是一整张图。
	while _history.size() > HISTORY_MAX:
		_history.pop_front()


func _restore(snapshot: Dictionary) -> void:
	var nodes: Array[NodeData] = snapshot["nodes"]
	var links: Array[ConnectionData] = snapshot["connections"]
	_blueprint.nodes = nodes
	_blueprint.connections = links
	# 摆位不进存档，但快照里要带上：撤销之后卡片回到原来那一格。
	# 不带的话 _restore 只能退回按数组顺序重排，玩家看到的是「撤销把整张图重摆了一遍」。
	_boxes = snapshot["boxes"]
	# 序号也一起回退。它只增不减本身不会撞车，但回退之后新节点会填回被删掉的那个号，
	# 于是「撤销一次再放一个同类节点」拿到的 id 与撤销前完全一致 —— 可复现，测试才好钉。
	_counter = int(snapshot["counter"])
	queue_redraw()


## 载入存档。文件不存在是**首次进游戏的正常情况**，故先查存在性 ——
## BlueprintData.load_from 对缺失文件会 push_error，直接调会在干净环境里刷一条假错误。
func _load_blueprint() -> void:
	if not ResourceLoader.exists(blueprint_path):
		return
	var loaded: BlueprintData = BlueprintData.load_from(blueprint_path)
	if loaded == null:
		return
	_blueprint = loaded
	_counter = _max_ordinal()
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
##   · 武器开火   → 卡片上缘升起一枚**按武器种类定形**的开火反馈（存活期由 MachineRuntime.SHOT_TICKS 定）。
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
			_draw_shot_cue(box, _weapon_kind_of(node_id), age)


## 某个节点的武器种类。非武器 / 认不出的取值一律 WeaponKind.NONE ——
## 调用方据此落到 NEEDLE 那一档，与 WeaponData.resolve() 的降级方向一致。
func _weapon_kind_of(node_id: StringName) -> int:
	for node: NodeData in _blueprint.nodes:
		if node.id == node_id:
			return node.weapon_kind
	return NodeData.WeaponKind.NONE


## 开火反馈的外框尺寸：三把武器各一种形态（见 CUE_* 的说明）。**纯函数** ——
## 「三把真的分得开」这条可以脱离场景树单测，不必为了量一个尺寸去真跑一场战斗。
func fire_cue_size(weapon_kind: int) -> Vector2:
	match weapon_kind:
		NodeData.WeaponKind.BOMB:
			return CUE_BOMB
		NodeData.WeaponKind.SAW:
			return CUE_SAW
		_:
			return CUE_NEEDLE


## 某把武器开火第 age 拍的反馈外框在卡片坐标系里的位置：**下缘**贴卡片上缘，整块随拍数往上抬，
## 抬到 CUE_RISE 为止。
##
## 下缘贴卡片、而不是以卡片上缘为中点：中点对齐时外框有一半压在卡片上，八拍里那半截会盖住
## 卡片自己的描边与类型色，看起来像卡片在闪 —— 而这条反馈要回答的是「这张卡开火了」，
## 盖住卡片反而把这个答案抹掉。抬高之后外框**始终整块落在卡片上方的空档里**（y < 卡片上缘）。
##
## 横向以卡片中点对齐：三把武器的宽度不同，用左上角对齐会让「哪张卡在开火」在宽窄之间看起来像偏了。
func shot_cue_rect(box: Rect2, weapon_kind: int, age: int) -> Rect2:
	var cue: Vector2 = fire_cue_size(weapon_kind)
	var rise: float = CUE_RISE * float(age + 1) / float(MachineRuntime.SHOT_TICKS)
	var left: float = box.position.x + CARD * 0.5 - cue.x * 0.5
	return Rect2(Vector2(left, box.position.y - rise - cue.y).floor(), cue)


func _draw_shot_cue(box: Rect2, weapon_kind: int, age: int) -> void:
	_draw_fx(shot_cue_rect(box, weapon_kind, age))


## 节点卡片在**本控件坐标系**里的矩形（VIEWER 侧的弹道要从这里出发）。
## 没有这张卡（未落格 / 已删除）时返回零矩形 —— 调用方据此跳过，而不是把线画到 (0,0)。
func card_rect(node_id: StringName) -> Rect2:
	return _boxes.get(node_id, Rect2())


## 信号火花：04 §3.10 的 FX 三层结构（芯 BLUE_050 / 体 BLUE_FX_600 / 描边 NAVY_900）。
## 三层缺一不可，故最小尺寸就是 6×6 —— 这正合意：类型标识讲「这是什么节点」，
## 火花讲「此刻这里有事发生」，后者本就该更亮眼。
func _draw_spark(center: Vector2) -> void:
	_draw_fx(Rect2((center - Vector2(SPARK, SPARK) * 0.5).floor(), Vector2(SPARK, SPARK)))


## 04 §3.10 的 FX 三层：描边 NAVY_900 / 体 BLUE_FX_600 / 芯 BLUE_050，逐层内缩 1px。
## 薄到放不下某一层时**跳过那一层**，而不是把外框撑大 —— 撑大会把三把武器的形态差别抹平，
## 而形态正是它们唯一的区分手段（见 CUE_* 的说明）。
func _draw_fx(rect: Rect2) -> void:
	draw_rect(rect, Palette.get_color(Palette.Key.NAVY_900), true)
	var body: Rect2 = rect.grow(-1.0)
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		return
	draw_rect(body, Palette.get_color(Palette.Key.BLUE_FX_600), true)
	var core: Rect2 = body.grow(-1.0)
	if core.size.x <= 0.0 or core.size.y <= 0.0:
		return
	draw_rect(core, Palette.get_color(Palette.Key.BLUE_050), true)
