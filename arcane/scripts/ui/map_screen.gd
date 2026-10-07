## map_screen.gd
## 职责：路线图屏 —— 装配羊皮卷上的小标题 / 当前位置、MapView、底部提示与「继续 / 返回编辑器」。
## 所属系统：ui
## 依赖：MapModel, MapView, MapLayout, MapNodePainter, RunState, GameFlow, UiKit, ArcaneTheme
## 禁止：本文件不得自己换场景（R3）；不得自己生成路线图（在 RunState.map() / MapModel 里）；
##       不得自己算节点几何与命中（在 MapLayout / MapView 里）；不得出现裸色值。
##
## 「点节点」与「继续」是两步，不是重复的两颗键：
##   点一下 48 设备像素的目标就当场跳走，误触的代价是整场战斗 + 一次换屏；
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
	# 羊皮卷先落地，标题与当前位置写在它上面（后加的子节点画在上面）。
	_view = MapView.new()
	_view.position = MapLayout.parchment().position
	_view.size = MapLayout.parchment().size
	add_child(_view)
	_view.setup(RunState.map())
	_view.node_chosen.connect(_on_node_chosen)
	_view.node_rejected.connect(_on_node_rejected)

	add_child(UiKit.label(tr("路线图"), MapLayout.title_rect(), ArcaneTheme.TYPE_LABEL_INK_TITLE))
	_status = UiKit.label("", MapLayout.status_rect(), ArcaneTheme.TYPE_LABEL_INK)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_status)

	_hint = UiKit.label("", MapLayout.bottom_hint_rect(), ArcaneTheme.TYPE_LABEL_SECONDARY)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hint)

	# 底部动作条右端往左排：主动作在最右，次级键隔一个间距跟在它左边。
	var bar: Rect2 = MapLayout.bottom_bar()
	_continue = UiKit.button("继续", ArcaneTheme.TYPE_BUTTON_PRIMARY, _on_continue)
	add_child(_continue)
	var left_of_continue: float = UiKit.place_right(_continue, bar, bar.end.x)
	var back: Button = UiKit.button("返回编辑器", ArcaneTheme.TYPE_BUTTON_SECONDARY, _on_back)
	add_child(back)
	UiKit.place_right(back, bar, left_of_continue - MapLayout.GAP)

	_refresh()


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
