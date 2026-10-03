## test_files.gd
## 职责：测试用的只读文件工具（递归收集 .gd、读源码行）。
## 所属系统：tests
## 依赖：无
## 禁止：本文件不得写入任何路径 —— 只读。

extends RefCounted

const GD_EXTENSION: String = ".gd"


## 递归收集 root 下全部 .gd 的 res:// 路径，结果已排序。
static func collect_gd_files(root: String) -> Array[String]:
	var found: Array[String] = []
	_collect(root, found)
	found.sort()
	return found


## 读源码并剔除注释行 —— 注释里提到被禁写法不算违规。
static func code_lines(path: String) -> Array[String]:
	var kept: Array[String] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return kept
	while not file.eof_reached():
		var line: String = file.get_line()
		if not line.strip_edges().begins_with("#"):
			kept.append(line)
	file.close()
	return kept


static func _collect(dir_path: String, accumulator: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub_dir: String in dir.get_directories():
		_collect("%s/%s" % [dir_path, sub_dir], accumulator)
	for file_name: String in dir.get_files():
		if file_name.ends_with(GD_EXTENSION):
			accumulator.append("%s/%s" % [dir_path, file_name])
