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

## WEAPON 节点的具体武器种类。与 WeaponData.Kind 逐项对应，**但刻意不复用那个枚举**：
## WeaponData 依赖本文件（它的 resolve() 收 NodeData），反过来引用它就成了循环依赖，
## 而 GDScript 的类加载顺序不会替我们解开这个环。两边的对应关系由
## tests/unit/test_combat_damage.gd 逐项钉住 —— 改一边忘了另一边会当场转红。
## **不得重排**：理由同 Kind。
##
## NONE 排第一兼两用：既是缺省值，也是「这条记录根本没有这个字段」的落点 ——
## 本字段存在之前写下的存档（user://blueprints/*.tres）载回来就是 NONE，
## 由 WeaponData.resolve() 按 02 §9 降级，而不是崩在缺字段上。
enum WeaponKind {
	NONE,
	NEEDLE,
	BOMB,
	SAW,
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

## WEAPON 节点的武器种类。**只对 kind == WEAPON 有意义**：CORE 与 FUNCTION 都没有可选项，
## 一律 NONE —— 给非武器节点也写上武器种类，会让「这是不是武器」有两个互相矛盾的答案。
##
## 为什么进数据类而不是留在界面：与 function_kind 同理 —— 武器种类决定这台机器打出什么伤害，
## 而机器要能从存档原样重建。由**仓库槽位**（blueprint_workspace.gd 的 WAREHOUSE 表）
## 在落节点时直接写入，不再靠显示名反查（那条路一见 I18N 就会全表落空）。
@export var weapon_kind: WeaponKind = WeaponKind.NONE
