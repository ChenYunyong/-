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

## FUNCTION 类的具体行为，对应 03 §4.1 给 FUNCTION 列的四件事（分流 / 延时 / 放大；条件判断未实现）。
## **不得重排**：理由同 Kind。
##
## NONE 排第一兼两用：既是缺省值，也是「不认识的行为」的兜底 —— 缺省走直通，不猜一种运算。
## 早期存档里的 FUNCTION 节点没有这个字段，载回后一律落到 NONE，行为是「原样转发」。
enum Function {
	NONE,
	SPLIT,
	AMPLIFY,
	DELAY,
}

## 全局唯一标识，DataRegistry 的索引键（02 §5）。空值由 DataRegistry 判为非法并拒绝入库。
@export var id: StringName = &""

## 玩家可读名称。
@export var display_name: String = ""

## 节点类型。缺省取 FUNCTION：三类中语义最中性的一类，漏填时不会把节点
## 误当成能量源（CORE）或伤害出口（WEAPON）。
@export var kind: Kind = Kind.FUNCTION

## FUNCTION 节点的行为。**只对 kind == FUNCTION 有意义**：CORE 的行为由「按节拍自发脉冲」定死，
## WEAPON 的行为由「收到脉冲即开火」定死，两者都没有可选项。
##
## 为什么进数据类而不是留在界面：行为决定机器跑出来是什么，而机器要能从存档原样重建 ——
## 留在界面里的话，玩家拖出来的「分流」重进场景就会退化成「直通」。
@export var function_kind: Function = Function.NONE
