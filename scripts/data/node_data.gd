## node_data.gd
## 职责：蓝图节点的静态数据 —— 三类节点（CORE / FUNCTION / WEAPON）的定义（03_ARCHITECTURE.md §4.1）。
## 所属系统：data
## 依赖：无（仅 Godot 内建 Resource）
## 禁止：本文件不得包含玩法逻辑、UI 或数值公式。端口数量、连线校验、环路检测属蓝图系统
##       （03 §4.2），不得下沉到数据类。

class_name NodeData
extends Resource

## 节点类型。顺序与 03_ARCHITECTURE.md §4.1 的表格逐字一致，**不得重排**：
## 枚举值会按整数落进 .tres，重排会静默改变既有数据文件的语义。
enum Kind {
	CORE,
	FUNCTION,
	WEAPON,
}

## 全局唯一标识，DataRegistry 的索引键（02 §5）。空值由 DataRegistry 判为非法并拒绝入库。
@export var id: StringName = &""

## 玩家可读名称。
@export var display_name: String = ""

## 节点类型。缺省取 FUNCTION：三类中语义最中性的一类，漏填时不会把节点
## 误当成能量源（CORE）或伤害出口（WEAPON）。
@export var kind: Kind = Kind.FUNCTION
