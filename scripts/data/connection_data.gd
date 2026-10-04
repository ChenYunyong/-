## connection_data.gd
## 职责：蓝图连线（有向边）的数据 —— 从源节点的出端口指向目标节点的入端口（03_ARCHITECTURE.md §4.2）。
## 所属系统：data
## 依赖：无（仅 Godot 内建 Resource）
## 禁止：本文件不得包含玩法逻辑与图算法。环路检测、悬空端口、类型不匹配、断开子图
##       属蓝图系统的校验职责（03 §4.2），不得下沉到数据类。

class_name ConnectionData
extends Resource

## 源节点 id。方向为 from → to，与 03 §4.2「Connection 为有向边」一致。
@export var from_node_id: StringName = &""

## 源节点的出端口名。端口名与数量由节点类型决定，本数据类不校验其合法性。
@export var from_port: StringName = &""

## 目标节点 id。
@export var to_node_id: StringName = &""

## 目标节点的入端口名。
@export var to_port: StringName = &""
