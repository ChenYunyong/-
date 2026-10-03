## test_clock.gd
## 职责：把引擎推进的模拟时间累加起来，供 R1 用例断言「停留 N 秒不自动推进」。
## 所属系统：tests
## 依赖：无
## 禁止：本文件不得读取真实时间 —— 必须用引擎给每帧的 delta，
##       这样 --fixed-fps 下才可复现（09_TEST_STANDARD.md §4「禁止依赖真实时间」）。

extends Node

var elapsed: float = 0.0
var last_delta: float = 0.0
var frames: int = 0


func _process(delta: float) -> void:
	elapsed += delta
	last_delta = delta
	frames += 1
