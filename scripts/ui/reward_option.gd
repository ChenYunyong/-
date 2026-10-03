## reward_option.gd
## 职责：REWARD 界面上**一个选项**的展示载体 —— 06 §9 要求的五项（图标 / 名称 / 类型 / 数值 / 特殊规则）
##       在这里各有字段，外加 06 §9「不足时以『跳过』补齐」那条补齐规则。
## 所属系统：ui
## 依赖：无
## 禁止：本文件**只**承载展示数据 —— 不得出现任何奖励数值计算、掉落池、稀有度权重
##       （全部属 Stage 4 的 S4-07）。Stage 4 会用 `RewardData`（Resource）提供真实数据，
##       届时由 reward_screen.gd 把它映射成本类实例；本文件在那之前与之后都不参与玩法计算。
##
## 为什么不是 Resource：03 §11 预留的扩展点是 `RewardData`（数据层，属 Stage 4）。
## 本类是 UI 侧的展示载体，只回答「这五项显示什么字」，二者职责不同，故意分开命名。

class_name RewardOption
extends RefCounted

## 选项类型。前三个沿用 06 §4 的类型标识语义（CORE / FUNCTION / WEAPON）；
## SKIP 是 06 §9 的「跳过」补齐项，**不是**一种节点类型。
enum Kind { CORE, FUNCTION, WEAPON, SKIP }

## 「跳过」补齐项的名称。06 §9 只给了这个词，未规定配色与图标 —— 见 RewardCard.icon_color()。
const SKIP_NAME_KEY: String = "跳过"

## 06 §9 的五个展示位。空串表示该字段不存在，界面上**整行隐藏**（06 §5 对空字段的同类规则），
## 不得显示 "N/A"。
var kind: Kind = Kind.SKIP
var name_key: String = ""
var type_key: String = ""
var value_key: String = ""
var rule_key: String = ""


func _init(option_kind: Kind = Kind.SKIP, display_name: String = "",
		display_type: String = "", display_value: String = "",
		display_rule: String = "") -> void:
	kind = option_kind
	name_key = display_name
	type_key = display_type
	value_key = display_value
	rule_key = display_rule


## 06 §9：选项不足时补的那个「跳过」。它只有名称，其余三项为空 —— 界面按「空字段整行隐藏」处理。
static func skip() -> RewardOption:
	return RewardOption.new(Kind.SKIP, SKIP_NAME_KEY, "", "", "")


## 本项是不是补齐出来的「跳过」。
func is_skip() -> bool:
	return kind == Kind.SKIP


## 06 §9：选项 3 个，不足时以「跳过」补齐。
## 多出来的选项直接丢弃 —— 本阶段界面固定三个位置（06 §9 没有「超过三个」的说法）。
## 传入空数组是合法输入（一行奖励都没有），得到三个「跳过」。
static func pad(options: Array[RewardOption], count: int) -> Array[RewardOption]:
	var filled: Array[RewardOption] = []
	for index: int in count:
		filled.append(options[index] if index < options.size() else skip())
	return filled
