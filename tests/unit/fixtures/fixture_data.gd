## fixture_data.gd
## 职责：测试专用数据资源 —— 只提供 DataRegistry 索引所需的 id 与一个字段。
## 所属系统：tests
## 依赖：无
## 禁止：本文件不得被 scripts/ 引用；它属于测试 fixtures，不是正式数据类。

extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
