## data_registry.gd
## 职责：扫描 data/ 下的 .tres/.res，按「类别 → id」建索引，供各系统按 id 取数据。
## 所属系统：core
## 依赖：无（仅 Godot 内建 Resource / DirAccess）
## 禁止：本文件不得包含任何玩法逻辑与数值，也不得 preload 具体数据文件
##       （02_CODE_STANDARD.md §5：取数据只能经 DataRegistry）。

extends Node

## 允许被索引的数据类别，与 03_ARCHITECTURE.md §9 的 data/ 子目录一致。
const CATEGORIES: PackedStringArray = ["nodes", "weapons", "enemies", "waves"]
const DATA_ROOT: String = "res://data"
const RESOURCE_EXTENSIONS: PackedStringArray = [".tres", ".res"]

## 某个类别索引完成时触发。count 为该类别索引到的条目数（可为 0）。
signal category_loaded(category: StringName, count: int)

## category(StringName) -> { id(StringName) -> Resource }
var _index: Dictionary = {}
var _is_loaded: bool = false


func _ready() -> void:
	load_all()


## 重建全部类别的索引。重复调用安全。
## root_path 默认取正式数据根；测试用它指向 fixtures，避免污染 data/（09 §4）。
func load_all(root_path: String = DATA_ROOT) -> void:
	_index.clear()
	for category: String in CATEGORIES:
		_load_category(StringName(category), root_path)
	_is_loaded = true


## 是否已完成至少一次加载。
func is_loaded() -> bool:
	return _is_loaded


## 按类别与 id 取数据。不存在时 push_error 并返回 null（02 §9：不静默崩溃）。
func get_data(category: StringName, id: StringName) -> Resource:
	if not _index.has(category):
		push_error("DataRegistry: 未知类别 '%s'。" % category)
		return null
	var bucket: Dictionary = _index[category]
	if not bucket.has(id):
		push_error("DataRegistry: 类别 '%s' 中不存在 id '%s'。" % [category, id])
		return null
	return bucket[id] as Resource


## 某类别已索引的条目数。未知类别返回 0。
func count(category: StringName) -> int:
	if not _index.has(category):
		return 0
	var bucket: Dictionary = _index[category]
	return bucket.size()


## 某类别已索引的全部 id，按字典序排序（保证调用方拿到稳定顺序）。
func list_ids(category: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not _index.has(category):
		return ids
	var bucket: Dictionary = _index[category]
	for id: Variant in bucket.keys():
		ids.append(id as StringName)
	# 不能直接用 Array[StringName].sort()：StringName 的 `<` 比的是**驻留指针**而不是文本
	# （实测 &"beta" < &"alpha" 在同一进程内为 true），结果随驻留顺序漂移，
	# 与上面「按字典序」的承诺不符。故显式转 String 再比。
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return ids


## 扫描单个类别目录并建索引。目录缺失属合法「空数据」情形（09 §2），不算错误。
func _load_category(category: StringName, root_path: String) -> void:
	var bucket: Dictionary = {}
	var dir_path: String = "%s/%s" % [root_path, category]
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		_index[category] = bucket
		category_loaded.emit(category, 0)
		return
	for file_name: String in dir.get_files():
		var path: String = "%s/%s" % [dir_path, _strip_remap(file_name)]
		if not _has_resource_extension(path):
			continue
		_index_resource(bucket, path)
	_index[category] = bucket
	category_loaded.emit(category, bucket.size())


func _index_resource(bucket: Dictionary, path: String) -> void:
	var res: Resource = load(path) as Resource
	if res == null:
		push_error("DataRegistry: 无法加载数据资源 '%s'，已跳过。" % path)
		return
	var id_value: Variant = res.get(&"id")
	if id_value == null or String(id_value).is_empty():
		push_error("DataRegistry: 数据资源 '%s' 缺少 id 字段，已跳过。" % path)
		return
	var id: StringName = StringName(id_value)
	if bucket.has(id):
		push_error("DataRegistry: 类别内 id '%s' 重复（%s），后者被忽略。" % [id, path])
		return
	bucket[id] = res


func _has_resource_extension(path: String) -> bool:
	for ext: String in RESOURCE_EXTENSIONS:
		if path.ends_with(ext):
			return true
	return false


## 导出后的工程里目录项会带 .remap / .import 后缀，去掉才能 load 回原资源。
func _strip_remap(file_name: String) -> String:
	if file_name.ends_with(".remap"):
		return file_name.trim_suffix(".remap")
	if file_name.ends_with(".import"):
		return file_name.trim_suffix(".import")
	return file_name
