## message_panel.gd
## 职责：带 06 §2.2 硬阴影的面板 —— 外框 / 内芯之上再叠一层独立的 PanelShadow，并提供标题 / 正文落点。
## 所属系统：ui
## 依赖：Theme 的 PanelFrame / PanelShadow 变体（颜色由 Theme 从 Palette 装配）
## 禁止：本文件不得写任何字面色值（06 §10.7）；
##       不得自己画阴影 —— 硬阴影必须是那层独立叠层，面板自身不带阴影（06 §2.2 v0.1.5 甲案）。

class_name MessagePanel
extends Control

@onready var _title: Label = %Title
@onready var _message: Label = %Message


## 显示标题 + 若干行正文。两个参数都是 tr() 的 key（06 §11），本文件不拼中文原文。
func show_message(title_key: String, message_keys: PackedStringArray) -> void:
	_title.text = tr(title_key)
	var lines: PackedStringArray = []
	for key: String in message_keys:
		lines.append("· %s" % tr(key))
	_message.text = "\n".join(lines)
	visible = true
