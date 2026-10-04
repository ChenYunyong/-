## blueprint_data.gd
## 职责：一张蓝图（有向图）的数据容器与序列化 —— 节点集合 + 连线集合，可落盘并原样重载
##       （03_ARCHITECTURE.md §4.2；09_TEST_STANDARD.md §3.2「保存后重载 → 结构完全一致」）。
## 所属系统：data
## 依赖：scripts/data/node_data.gd, scripts/data/connection_data.gd
## 禁止：本文件不得包含图算法与图校验 —— 环路、悬空端口、类型不匹配、断开子图
##       属蓝图系统的职责（03 §4.2），不得下沉到数据类。

class_name BlueprintData
extends Resource

## 蓝图的默认落盘目录。蓝图是玩家自己的产物、不是随包发布的静态配置，
## 故落 user:// 而非 res://data/（03 §9 的 data/ 只放 nodes|weapons|enemies|waves 四类静态数据）。
const DEFAULT_SAVE_DIR: String = "user://blueprints"

## 节点集合。用类型化数组：02 §2 禁止无类型 Array 作为跨系统接口。
@export var nodes: Array[NodeData] = []

## 连线集合（有向边，03 §4.2）。
@export var connections: Array[ConnectionData] = []


## 把本蓝图写入 path。返回是否成功；任一步失败都 push_error 并返回 false，不静默（02 §9）。
func save_to(path: String) -> bool:
	var dir_path: String = path.get_base_dir()
	if not dir_path.is_empty():
		var dir_err: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		# 目录已存在不是错误；其余错误才拦。
		if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
			push_error("BlueprintData: 无法创建目录 '%s'（错误 %d）。" % [dir_path, dir_err])
			return false
	var save_err: Error = ResourceSaver.save(self, path)
	if save_err != OK:
		push_error("BlueprintData: 无法写入 '%s'（错误 %d）。" % [path, save_err])
		return false
	return true


## 从 path 载入蓝图。文件不存在 / 无法解析 / 类型不符时返回 null 并 push_error，不崩溃（02 §9）。
##
## 用 CACHE_MODE_IGNORE 而非默认缓存：蓝图是**存档**，重载必须反映磁盘上的当前内容，
## 而不是同一会话里更早那次 load 留下的旧实例 —— 否则「改盘 → 重载」会拿到陈旧数据。
static func load_from(path: String) -> BlueprintData:
	if not ResourceLoader.exists(path):
		push_error("BlueprintData: 蓝图文件不存在 '%s'。" % path)
		return null
	var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		push_error("BlueprintData: 无法载入 '%s'。" % path)
		return null
	var blueprint: BlueprintData = res as BlueprintData
	if blueprint == null:
		push_error("BlueprintData: '%s' 不是 BlueprintData（实际类型 %s）。" % [path, res.get_class()])
		return null
	return blueprint
