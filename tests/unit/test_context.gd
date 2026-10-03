## test_context.gd
## 职责：最小断言收集器 —— 让每条用例产出明确的 pass/fail，而不是靠 print（09_TEST_STANDARD.md §4）。
## 所属系统：tests
## 依赖：无
## 禁止：本文件不得引用任何被测实现，否则断言本身就不再可信。

extends RefCounted

var passed: int = 0
var failed: int = 0
var failures: Array[String] = []

var _case: String = ""


## 标记后续断言所属的用例名。
func begin_case(case_name: String) -> void:
	_case = case_name


## 条件为真则记一次通过，否则记一次失败。返回条件本身，便于串联。
func check(condition: bool, what: String) -> bool:
	if condition:
		passed += 1
	else:
		failed += 1
		failures.append("%s :: %s" % [_case, what])
	return condition


## 相等断言。
func equal(actual: Variant, expected: Variant, what: String) -> bool:
	return check(actual == expected, "%s（期望 %s，实际 %s）" % [what, expected, actual])


## 不等断言。
func not_equal(actual: Variant, unexpected: Variant, what: String) -> bool:
	return check(actual != unexpected, "%s（不应等于 %s）" % [what, unexpected])


## 累计断言总数。
func total() -> int:
	return passed + failed
