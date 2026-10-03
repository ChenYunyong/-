## panel_title_bar.gd
## 职责：06 §2.2 的面板标题栏 —— 高度 16px、底色 NAVY_700、底部 1px GOLD_600 分隔线。
## 所属系统：ui
## 依赖：Theme 的 PanelTitleBar 变体（配色由 Theme 从 Palette 装配）
## 禁止：本文件不得写任何字面色值（06 §10.7）；
##       不得自行决定高度或配色 —— 高度取自 PaletteTheme.TITLE_BAR_HEIGHT（06 §2.2），
##       配色一律由 Theme 变体给出，场景与脚本都不得覆盖。

class_name PanelTitleBar
extends Panel

## 标题文本只走 tr() key（06 §11），本文件不拼中文原文。空串 = 只有分隔线的空标题栏。
const DEFAULT_TITLE_KEY: String = ""

## 当前标题的 tr() key。
var _title_key: String = DEFAULT_TITLE_KEY

@onready var _title: Label = %Title


func _ready() -> void:
	# 高度是规范值而非场景里随手写的数：唯一来源是 Theme 侧常量，改规范只改一处。
	custom_minimum_size.y = float(PaletteTheme.TITLE_BAR_HEIGHT)
	_title.text = tr(_title_key)


## 设置标题。title_key 是 tr() 的 key，不是中文原文。
## 父场景在自己的 _ready() 里调用本函数时，本组件的 _ready() 可能已经跑过 —— 故这里直接写 Label。
func set_title_key(title_key: String) -> void:
	_title_key = title_key
	_title.text = tr(title_key)


## 屏幕上实际显示的标题文本。供测试读取渲染结果，而不是重算一遍。
func get_title_text() -> String:
	return _title.text
