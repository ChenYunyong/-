## map_screen.gd
## 职责：路线图屏 —— 装配标题 / 提示 / MapView / 图例 / 返回按钮，并把节点的选择结果接到状态机。
## 所属系统：ui
## 依赖：MapModel, MapView, RunState, GameFlow, UiKit, ArcaneTheme
## 禁止：本文件不得自己换场景（R3）；不得自己生成路线图（在 RunState.map() / MapModel 里）。

extends Control

const TITLE_RECT: Rect2 = Rect2(24.0, 24.0, 912.0, 48.0)
const HINT_RECT: Rect2 = Rect2(24.0, 80.0, 912.0, 30.0)
const VIEW_RECT: Rect2 = Rect2(24.0, 120.0, 912.0, 320.0)
const LEGEND_RECT: Rect2 = Rect2(24.0, 444.0, 600.0, 72.0)
const BACK_ANCHOR: Rect2 = Rect2(24.0, 444.0, 912.0, 72.0)

var _view: MapView = null
var _hint: Label = null


func _ready() -> void:
	var title: Label = UiKit.label(tr("选择路线"), TITLE_RECT, ArcaneTheme.TYPE_LABEL_ACCENT)
	add_child(title)

	_hint = UiKit.label("", HINT_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY)
	add_child(_hint)

	_view = MapView.new()
	_view.position = VIEW_RECT.position
	_view.size = VIEW_RECT.size
	add_child(_view)
	_view.setup(RunState.map())
	_view.node_chosen.connect(_on_node_chosen)

	# 图例：节点的两种颜色各是什么意思。节点里那个字（战 / 工）也一并说明。
	var legend: Label = UiKit.label("%s · %s" % [tr("战斗"), tr("工坊")], LEGEND_RECT,
		ArcaneTheme.TYPE_LABEL_SECONDARY)
	legend.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(legend)

	var back: Button = UiKit.button("返回编辑器", ArcaneTheme.TYPE_BUTTON_SECONDARY, _on_back)
	add_child(back)
	UiKit.place_right(back, BACK_ANCHOR, BACK_ANCHOR.end.x)

	_refresh()


## 战斗节点进战斗，工坊节点回编辑器调整书页。
func _on_node_chosen(kind: MapModel.Kind) -> void:
	if kind == MapModel.Kind.WORKSHOP:
		GameFlow.change_state(GameFlow.GameState.EDITOR)
		return
	GameFlow.change_state(GameFlow.GameState.COMBAT)


func _on_back() -> void:
	GameFlow.change_state(GameFlow.GameState.EDITOR)


func _refresh() -> void:
	var map: MapModel = RunState.map()
	if map.is_finished():
		_hint.text = tr("已通过")
	elif map.current_id() < 0:
		_hint.text = tr("下一层可选")
	else:
		var here: MapModel.MapNode = map.current()
		_hint.text = tr("第 %d 层") % (here.tier + 1)
