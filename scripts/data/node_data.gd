## node_data.gd
## 职责：法术书的静态数据 —— 三类卡（核心卡 / 功能卡 / 能力卡）的定义（03_ARCHITECTURE.md §4.1）。
## 所属系统：data
## 依赖：无（仅 Godot 内建 Resource）
## 禁止：本文件不得包含玩法逻辑、UI 或数值公式。端口数量、连线校验、环路检测属蓝图系统
##       （03 §4.2），不得下沉到数据类。
##
## PET-82（MAGIC-01）把「搭电路」这层隐喻换成「法术书」，三类节点的词汇随用户 2026-10-06 直接给的
## 命名落成 **核心卡 / 能力卡 / 功能卡**（见本卡评论「命名纠正」）。**枚举取值一个都没动** ——
## 值按整数落进 .tres，动了旧存档就会静默变成别的东西：旧存档里的 `CORE` 读回来就是 `CORE`，
## `WEAPON` 读回来就是 `ABILITY`，同一批整数换了个名字。见 03 §4.1 与 02 §9 的降级口径。

class_name NodeData
extends Resource

## 节点类型。顺序与 03_ARCHITECTURE.md §4.1 的表格逐字一致，**不得重排**：
## 枚举值会按整数落进 .tres，重排会静默改变既有数据文件的语义。
##
## 三类卡：核心卡（法术书的心脏，持续产生魔力）/ 功能卡（决定「怎么打」）/
## 能力卡（决定「打出什么」，九系元素）。
enum Kind {
	CORE,
	FUNCTION,
	ABILITY,
}

## FUNCTION 类（功能卡）的具体类型 —— 用户 2026-10-06 直接给的八类。
## 对应 03 §4.1 给 FUNCTION 列的四件事：前三个（子弹数量 / 附魔 / 冷却）有实现，
## 其余五个**本期只登记名字与落盘位**，行为归「直通」（见下）。
##
## **不得重排，且前四个必须原地不动**：理由同 Kind。旧存档里 `SPLIT=1` / `AMPLIFY=2` /
## `DELAY=3` 落的就是这三个整数，重排会让玩家存下来的功能卡静默变成另一种功能 ——
## 而症状只是「打起来手感不一样」，几乎不可能被发现。
##
## NONE 排第一兼两用：既是缺省值，也是「不认识的行为」的兜底 —— 缺省走直通，不猜一种运算。
## 早期存档里的 FUNCTION 节点没有这个字段，载回后一律落到 NONE，行为是「原样转发」。
enum Function {
	NONE,
	BULLET_COUNT,
	ENCHANT,
	COOLDOWN,
	HASTE,
	SLOW,
	BURST,
	LOOP,
	ATTACK_SPEED,
}

## ABILITY 类（能力卡）的具体元素 —— 用户 2026-10-06 直接给的九系，顺序即用户列出的顺序。
## 与 AbilityData.Kind 逐项对应，**但刻意不复用那个枚举**：AbilityData 依赖本文件
## （它的 resolve() 收 NodeData），反过来引用它就成了循环依赖，而 GDScript 的类加载顺序
## 不会替我们解开这个环。两边的对应关系由 tests/unit/test_combat_damage.gd 逐项钉住 ——
## 改一边忘了另一边会当场转红。
## **不得重排**：理由同 Kind。
##
## NONE 排第一兼两用：既是缺省值，也是「这条记录根本没有这个字段」的落点 ——
## 本字段存在之前写下的存档（user://blueprints/*.tres）载回来就是 NONE，
## 由 AbilityData.resolve() 按 02 §9 降级，而不是崩在缺字段上。
enum Ability {
	NONE,
	METAL,
	WOOD,
	WATER,
	FIRE,
	EARTH,
	THUNDER,
	WIND,
	POISON,
	ICE,
}

## 全局唯一标识，DataRegistry 的索引键（02 §5）。空值由 DataRegistry 判为非法并拒绝入库。
@export var id: StringName = &""

## 玩家可读名称。
@export var display_name: String = ""

## 节点类型。缺省取 FUNCTION：三类中语义最中性的一类，漏填时不会把节点
## 误当成核心卡（CORE）或伤害出口（ABILITY）。
@export var kind: Kind = Kind.FUNCTION

## FUNCTION 节点的功能类型。**只对 kind == FUNCTION 有意义**：CORE 的行为由「按节拍自发脉冲」定死，
## ABILITY 的行为由「收到脉冲即施放」定死，两者都没有可选项。
##
## 为什么进数据类而不是留在界面：功能决定法术书跑出来是什么，而书要能从存档原样重建 ——
## 留在界面里的话，玩家拖出来的「子弹数量」重进场景就会退化成「直通」。
##
## **变量名保留 `function_kind` 不改**：它是 .tres 里的**字段名**，改名等于旧存档全部读不到这一列，
## 玩家的附魔 / 冷却会静默退化成直通。隐喻换的是词汇，不是存档格式（02 §9）。
@export var function_kind: Function = Function.NONE

## ABILITY 节点的元素种类。**只对 kind == ABILITY 有意义**：CORE 与 FUNCTION 都没有可选项，
## 一律 NONE —— 给非能力卡也写上元素，会让「这张是不是能力卡」有两个互相矛盾的答案。
##
## 为什么进数据类而不是留在界面：与 function_kind 同理 —— 元素决定这本书打出什么伤害，
## 而书要能从存档原样重建。由**法术书槽位**（blueprint_workspace.gd 的 WAREHOUSE 表）
## 在落节点时直接写入，不再靠显示名反查（那条路一见 I18N 就会全表落空）。
##
## **变量名保留 `weapon_kind` 不改**：理由同 function_kind —— 它是存档里的字段名。
## 名字里那个 "weapon" 是 PET-82 之前的遗留，换它的代价是旧存档整列读不到。
@export var weapon_kind: Ability = Ability.NONE
