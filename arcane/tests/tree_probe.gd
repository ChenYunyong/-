## tree_probe.gd
## 职责：测试用的节点查找小工具 —— 在子树里按**脚本类名**找节点、计数。
## 所属系统：tests
## 依赖：无（只认 Node 与引擎内建类）
## 禁止：本文件不得断言、不得引用被测实现的行为 —— 它只回答「树里有没有、有几个」。
##
## 为什么不能直接用 get_class()：它返回的是**引擎类名**（Control / Node / Button），
## 认不出 class_name 声明出来的脚本类（BoardView / CardChip / MapView），
## 而场景冒烟要数的恰恰是后者。脚本类名走 Script.get_global_name()。
##
## 用法（不要加 class_name，免得进游戏工程的全局命名空间）：
##   const TreeProbe = preload("res://tests/tree_probe.gd")

extends RefCounted


## 子树里的全部后代（不含 root 自己）。
static func descendants(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	_collect(root, found)
	return found


static func _collect(node: Node, found: Array[Node]) -> void:
	for child: Node in node.get_children():
		found.append(child)
		_collect(child, found)


## 某种类型 / 脚本类名的节点（"CardChip" / "BoardView" / "Button" …）。
static func find_all(root: Node, kind: String) -> Array[Node]:
	var found: Array[Node] = []
	for node: Node in descendants(root):
		if matches(node, kind):
			found.append(node)
	return found


static func count_of(root: Node, kind: String) -> int:
	return find_all(root, kind).size()


## 一个节点算不算 kind。先看脚本类名，再看引擎类名 —— 两者命中其一即可。
static func matches(node: Node, kind: String) -> bool:
	return script_class(node) == kind or node.get_class() == kind


## class_name 声明出来的脚本类名；节点没挂脚本、或脚本没有 class_name 时返回空串。
static func script_class(node: Node) -> String:
	var script: Script = node.get_script()
	if script == null:
		return ""
	return String(script.get_global_name())
