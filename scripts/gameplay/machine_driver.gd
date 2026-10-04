## machine_driver.gd
## 职责：把**渲染帧的真实间隔**换成固定节拍，喂给 MachineRuntime（03 §2 的固定步长累加器）。
## 所属系统：gameplay
## 依赖：MachineRuntime
## 禁止：本文件不得触碰 UI / Palette / 存档 / 输入；
##       不得自己实现玩法 —— 它只回答「什么时候推进」，「推进成什么样」全在 MachineRuntime；
##       不得用 Timer / create_timer 代替累加器（03 §2）：定时器的节拍会跟着帧率漂，
##       而固定步长累加器不论 60fps 还是 30fps 都推进同样的拍数，仿真结果才可复现。
##
## 为什么单独一个节点而不是写在 combat_screen.gd 里：固定节拍是**玩法的时间模型**（03 §2），
## 不是界面的事。放这里还有个实际好处 —— COMBAT 界面的源码检查用例明令禁止出现
## _process / TICK_RATE（那张表守的是「这一批没有提前实现玩法」），时间模型下沉到 gameplay
## 之后，那条禁令与「机器真的跑起来了」就不冲突了。

class_name MachineDriver
extends Node

## 一拍的秒数。由 MachineRuntime 的唯一节拍源派生，这里不另写一个 20。
const TICK_SECONDS: float = 1.0 / float(MachineRuntime.TICK_RATE)

## 单帧最多补跑的节拍数。卡帧后一次性补几百拍会让机器瞬移，而且补跑期间画面完全不动 ——
## 这不是性能优化而是正确性：宁可丢掉补不上的时间，也不要让仿真与画面脱节。
const MAX_CATCH_UP_TICKS: int = 5

## 受本驱动的机器。为 null 时 _process 什么都不做 ——
## 「本局没有机器」是正常情况（还没拖过 CORE），不该在这里报错。
var runtime: MachineRuntime = null

var _accumulator: float = 0.0


## 换一台机器跑（传 null 表示停下）。累加器一并归零 ——
## 换了机器还留着上一台的余量，新机器的第一拍会在换的瞬间立刻蹦出来。
func bind(machine: MachineRuntime) -> void:
	runtime = machine
	_accumulator = 0.0


## 每渲染帧累加一次，攒够一拍才推进。COMBAT 之外本节点不参与任何状态
## （运行时为 null），故离开战斗场景不需要额外的启停开关。
func _process(delta: float) -> void:
	if runtime == null:
		return
	_accumulator += delta
	var budget: int = 0
	while _accumulator >= TICK_SECONDS and budget < MAX_CATCH_UP_TICKS:
		_accumulator -= TICK_SECONDS
		runtime.tick()
		budget += 1
	if budget >= MAX_CATCH_UP_TICKS:
		_accumulator = 0.0
