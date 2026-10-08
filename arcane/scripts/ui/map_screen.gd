## map_screen.gd
## 职责：路线图屏 —— 装配羊皮卷上的标题 / 当前位置、MapView、底部提示与「继续 / 返回编辑器」。
## 所属系统：ui
## 依赖：MapModel, MapView, MapLayout, MapNodePainter, ContractTheme, RunState, GameFlow, UiKit
## 禁止：本文件不得自己换场景（R3）；不得自己生成路线图（在 RunState.map() / MapModel 里）；
##       不得自己算节点几何与命中（在 MapLayout / MapView 里）；不得出现裸色值。
##
## 版面**逐字**来自 docs/14 §2.2 的几何表：头栏 40（标题左、当前位置右对齐）→ 羊皮卷 928×392
## （含 8px 材质边带与 16 内容内缩）→ 12 → 动作条 56。所有 rect 都由 MapLayout 给，
## 本屏一颗控件都不自己摆 —— 摆位一律 `position = rect.position; size = rect.size`。
##
## 纸**面**本身不是这里的 Panel：材质角色归 Theme。这里铺的是 ContractTheme.TYPE_PAGE_BAND
## （与屏①的书页同一支），于是四屏的纸是同一张纸；MapView 落在同一个 rect 上，只负责纸上的画。
##
## 「点节点」与「继续」是两步，不是重复的两颗键：
##   点一下 80 设备像素的目标就当场跳走，误触的代价是整场战斗 + 一次换屏；
##   而 06 §1 又要求底部有「继续」。于是分工为 —— 点只负责**走到**那个节点
##   （MapModel.select，路线图当场多一道墨迹），「继续」才真的换屏。
##   没选之前「继续」是灰的，所以它任何时候都不会干出「凭空空跳」这件事。

extends Control

## 本次进入这一屏有没有选好下一站。它是**本次访问的界面状态**，不进 RunState ——
## 退出再进来，当前位置由模型复原，但「还没选」理应从零开始。
var _chosen: bool = false
var _view: MapView = null
var _status: Label = null
var _hint: Label = null
var _continue: Button = null


func _ready() -> void:
	# 顺序即层级：暗底 → 羊皮卷 → 图 → 文字 → 按钮。改顺序前先看每一层的注释。
	add_child(_decor(ContractTheme.TYPE_BACKDROP, Rect2(Vector2.ZERO, MapLayout.SCREEN)))
	add_child(_decor(ContractTheme.TYPE_PAGE_BAND, MapLayout.PAPER))

	_view = MapView.new()
	_view.position = MapLayout.PAPER.position
	_view.size = MapLayout.PAPER.size
	add_child(_view)
	_view.setup(RunState.map())
	_view.node_chosen.connect(_on_node_chosen)
	_view.node_rejected.connect(_on_node_rejected)

	# 标题与状态都落在**暗底**上（纸从 y=64 才开始），所以走暗底那一支墨色，不走纸面墨色。
	var title: Label = UiKit.label(tr("路线图"), MapLayout.TITLE_RECT)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)

	_status = UiKit.label("", MapLayout.STATUS_RECT, ContractTheme.TYPE_LABEL_BODY_MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_status)

	_hint = UiKit.label("", MapLayout.HINT_RECT, ContractTheme.TYPE_LABEL_BODY_MUTED)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hint)

	# 动作条右侧两颗。位置与尺寸整份取自 §2.2，不靠文字宽度推 —— 英文文案更长时那是会飘的。
	_continue = UiKit.button("继续", ContractTheme.TYPE_BUTTON_PAGE_PRIMARY, _on_continue)
	_continue.position = MapLayout.PRIMARY_RECT.position
	_continue.size = MapLayout.PRIMARY_RECT.size
	add_child(_continue)

	var back: Button = UiKit.button("返回编辑器", ContractTheme.TYPE_BUTTON_DARK_SECONDARY, _on_back)
	back.position = MapLayout.BACK_RECT.position
	back.size = MapLayout.BACK_RECT.size
	add_child(back)

	_refresh()


## 装饰层：契约的材质面板一律不吃鼠标 —— 手势必须落到 MapView 上，不能落在纸那几层。
func _decor(variation: StringName, rect: Rect2) -> Panel:
	var panel: Panel = UiKit.panel(variation, rect)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## 点亮的节点：模型已经走过去了（MapView 只在 select() 成功后发这个信号），
## 这里只记下「选好了」。真的换屏留给「继续」—— 理由见文件头。
func _on_node_chosen(_kind: MapModel.Kind) -> void:
	_chosen = true
	_refresh()


## 走不了的节点：给一句话说明，别的一个字节都不动 —— 模型那边 MapView 根本没碰。
func _on_node_rejected(state: MapNodePainter.State) -> void:
	var walked: bool = state == MapNodePainter.State.VISITED or state == MapNodePainter.State.CURRENT
	_hint.text = tr("这里已经走过了") if walked else tr("这个节点现在走不到")


## 战斗节点进战斗，工坊节点回编辑器调整书页。
func _on_continue() -> void:
	var here: MapModel.MapNode = RunState.map().current()
	if here.kind == MapModel.Kind.WORKSHOP:
		GameFlow.change_state(GameFlow.GameState.EDITOR)
		return
	GameFlow.change_state(GameFlow.GameState.COMBAT)


func _on_back() -> void:
	GameFlow.change_state(GameFlow.GameState.EDITOR)


func _refresh() -> void:
	var map: MapModel = RunState.map()
	_status.text = _status_text(map)
	_hint.text = _hint_text(map)
	_continue.disabled = not _chosen


## 顶部那行：当前位置。还没踏上第 0 层时如实说「还没出发」，而不是显示「第 0 层」。
func _status_text(map: MapModel) -> String:
	var here: MapModel.MapNode = map.current()
	if here == null:
		return tr("还没出发")
	return "%s%s · %s" % [tr("当前位置："), tr("第 %d 层") % (here.tier + 1),
		MapView.kind_text(here.kind)]


## 底部那句提示。选好了 > 走完了 > 默认 —— 「走完」优先于「选好了」是故意的：
## 最后一层的节点没有出边，选完就再也点不动任何东西，那句话才是玩家此刻的处境。
func _hint_text(map: MapModel) -> String:
	if map.is_finished():
		return tr("路线已走完")
	if _chosen:
		return tr("已选好下一站")
	return tr("点亮的节点可以前往")
