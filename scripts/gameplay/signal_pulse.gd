## signal_pulse.gd
## 职责：一枚在途信号（FIRST PLAYABLE 2/4）—— 它正走哪条边、带着多少值、还剩几拍抵达。
## 所属系统：gameplay
## 依赖：无
## 禁止：本文件不得自己推进自己（没有 tick()）。仿真时间的唯一来源是 MachineRuntime 的节拍：
##       一枚脉冲若能自己走，同一份蓝图在不同帧率下就会跑出不同结果（03 §6 的确定性要求）；
##       不得带节点引用（只认 id）—— 脉冲的生命周期跨越多拍，握着节点引用会让「删节点」变成悬空指针问题。

class_name SignalPulse
extends RefCounted

## 出发节点 id。
var from_node_id: StringName = &""

## 目标节点 id。为空表示这枚脉冲还没定下家（Delay 节点收在手里的滞留态）。
var to_node_id: StringName = &""

## 携带的信号值。CORE 发出时为 MachineRuntime.BASE_PULSE_VALUE，Amplify 会把它乘大。
var value: float = 0.0

## 抵达前还剩几拍。≤ 0 表示本拍抵达。
var ticks_left: int = 0

## 走完全程需要几拍。进度由「还剩几拍」对它取比值得到，故两者必须一起设（见 MachineRuntime._make_pulse）。
var travel_ticks: int = 1


## 在途进度 0..1。06 §4 的连线是直线，故进度就是线段上的插值参数，UI 直接拿它算位置。
func progress() -> float:
	if travel_ticks <= 0:
		return 1.0
	return clampf(1.0 - float(ticks_left) / float(travel_ticks), 0.0, 1.0)
