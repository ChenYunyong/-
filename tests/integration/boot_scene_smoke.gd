## boot_scene_smoke.gd
## 职责：BOOT 场景的场景冒烟（09 §1）—— 独立实例化、校验成功 / 失败两条路径、重复进入不残留。
## 所属系统：tests（场景冒烟层，**单独进程**运行）
## 依赖：test_context, scenes/boot/boot.tscn, scenes/components/message_panel.tscn
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 run_tests.gd 的约束）；一律 load() + 经 /root 取节点。
##
## 为什么不挂进 run_tests.gd：BOOT 的成功路径会把真实 GameFlow 从 BOOT 推到 MAIN_MENU，
## 而 BOOT 是**不可回退**的启动态（ALLOWED_TRANSITIONS 里没有回到 BOOT 的边），
## 留在同一进程会污染 test_state_loop.gd 的「BOOT → MAIN_MENU」断言。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
const BOOT_CHECK_PATH: String = "res://scripts/ui/boot_check.gd"
const BOOT_SCENE_PATH: String = "res://scenes/boot/boot.tscn"
## 存在但类型不对的资源：用它触发「缺失或损坏」分支，整轮冒烟就不会有引擎级的加载报错
## （验收要求稳定态无报错）。「文件根本不存在」那条由 tests/unit/test_boot_check.gd 覆盖。
const WRONG_TYPE_PALETTE_PATH: String = "res://assets/ui/theme_main.tres"
const WRONG_TYPE_THEME_PATH: String = "res://assets/palette.tres"
const GAME_FLOW_PATH: String = "res://scripts/core/game_flow.gd"
const LOG_PATH: String = "res://tests/output/scene_smoke.log"

var _ctx: RefCounted = null
var _check: GDScript = null
var _scene: PackedScene = null
var _flow_script: GDScript = null
var _lines: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	_check = load(BOOT_CHECK_PATH)
	_scene = load(BOOT_SCENE_PATH)
	_flow_script = load(GAME_FLOW_PATH)

	# 顺序要紧：这条必须在任何 await 之前跑 —— Autoload 的 _ready 要等第一帧才结束，
	# 而它测的正是「数据索引还没就绪就实例化 BOOT」时会不会明确报错（见 BootCheck._check_registry）。
	_run_before_autoloads_ready_case()
	# 让出一帧，等 Autoload 就绪，之后的用例才是在真实启动条件下跑的。
	await process_frame

	await _run_failure_case("失败路径 · 调色板缺失或损坏", WRONG_TYPE_PALETTE_PATH, "", _check.MSG_PALETTE_MISSING)
	await _run_failure_case("失败路径 · 主题缺失或损坏", "", WRONG_TYPE_THEME_PATH, _check.MSG_THEME_MISSING)
	await _run_success_case()
	await _run_reentry_case()
	_finish()


## 启动顺序前置条件：Autoload 的 _ready 要等第一帧才跑完，此刻数据索引还是空的。
## 这个时点自检必须明确报「数据尚未加载完成」并停在 BOOT，而不是当成通过照常交棒 ——
## 否则 BOOT 会在注册表还空着的时候把状态推给 MAIN_MENU。
##
## 这里直接调 BootCheck 而不挂场景：此刻 root 还没进树，add_child() 不会派发 _ready
## （本文件头部注释记的实测结论），挂上去只会得到一个什么都没跑的哑节点，
## 断言就会变成「面板不可见 ⇒ 0 项」这种假通过。
func _run_before_autoloads_ready_case() -> void:
	_ctx.begin_case("BOOT 场景冒烟 · Autoload 就绪前的自检")
	var registry: Node = _autoload("DataRegistry")
	if not _ctx.check(registry != null, "DataRegistry Autoload 应存在"):
		return
	if not _ctx.check(not bool(registry.call(&"is_loaded")), "前置：此刻数据索引尚未就绪"):
		return

	var problems: PackedStringArray = _check.collect_problems()
	_ctx.equal(problems.size(), 1, "此时应恰好报 1 项")
	if problems.size() == 1:
		_ctx.equal(problems[0], _check.MSG_DATA_NOT_LOADED, "数据未就绪时的文案")

	var flow: Node = _autoload("GameFlow")
	if _ctx.check(flow != null, "GameFlow Autoload 应存在"):
		_ctx.check(bool(flow.call(&"is_state", _state(&"BOOT"))), "此刻仍应停在 BOOT")


func _run_failure_case(label: String, palette_path: String, theme_path: String, expected: String) -> void:
	_ctx.begin_case("BOOT 场景冒烟 · %s" % label)
	var flow: Node = _autoload("GameFlow")
	var screen: Node = _mount(palette_path, theme_path)
	await process_frame
	await process_frame

	var panel: Node = _find(screen, "ErrorPanel")
	if not _ctx.check(panel != null, "错误面板应存在"):
		_unmount(screen)
		return
	_ctx.check(bool(panel.get(&"visible")), "自检失败时错误面板必须可见")

	var title: Label = _find(panel, "Title") as Label
	var message: Label = _find(panel, "Message") as Label
	if _ctx.check(title != null and message != null, "标题与正文应存在"):
		_ctx.equal(title.text, tr(_check.MSG_TITLE), "标题应走 tr() 显示中文")
		_ctx.check(message.text.contains(tr(expected)), "正文应含 `%s`（实际：%s）" % [tr(expected), message.text])
		_ctx.check(_has_cjk(title.text) and _has_cjk(message.text), "屏幕上的提示必须是中文")

	_ctx.check(bool(flow.call(&"is_state", _state(&"BOOT"))), "自检失败时状态必须停在 BOOT")
	_unmount(screen)


func _run_success_case() -> void:
	_ctx.begin_case("BOOT 场景冒烟 · 校验成功路径")
	var flow: Node = _autoload("GameFlow")
	var screen: Node = _mount("", "")
	await process_frame
	await process_frame

	_ctx.equal(_visible_problems(screen).size(), 0, "正式资产下不应有校验问题")
	var panel: Node = _find(screen, "ErrorPanel")
	if _ctx.check(panel != null, "错误面板应存在"):
		_ctx.check(not bool(panel.get(&"visible")), "校验通过时错误面板不得显示")
	_ctx.check(bool(flow.call(&"is_state", _state(&"MAIN_MENU"))), "校验通过后状态应切到 MAIN_MENU")
	_unmount(screen)


## 09 §2 第 7 类：重新进入场景。BOOT 已经交棒，再实例化一次不得重复推进、也不得留下节点。
func _run_reentry_case() -> void:
	_ctx.begin_case("BOOT 场景冒烟 · 重复进入不残留")
	var flow: Node = _autoload("GameFlow")
	var base: int = root.get_child_count()

	var first: Node = _mount("", "")
	await process_frame
	_unmount(first)
	_ctx.check(not is_instance_valid(first), "第一次实例化的 BOOT 应已释放")
	_ctx.equal(root.get_child_count(), base, "释放后不应残留节点")

	var second: Node = _mount("", "")
	await process_frame
	await process_frame
	_ctx.equal(root.get_child_count(), base + 1, "重复进入后不应出现额外节点")
	_ctx.check(bool(flow.call(&"is_state", _state(&"MAIN_MENU"))), "非 BOOT 态下不得再推进状态")
	_unmount(second)
	_ctx.equal(root.get_child_count(), base, "第二次释放后同样不应残留")


## 挂载一个 BOOT 实例；两个路径留空表示用场景自带的正式资产。
func _mount(palette_path: String, theme_path: String) -> Node:
	var screen: Node = _scene.instantiate()
	if not palette_path.is_empty():
		screen.set(&"palette_path", palette_path)
		_ctx.check(screen.get(&"palette_path") == palette_path, "注入的 palette_path 应生效")
	if not theme_path.is_empty():
		screen.set(&"theme_path", theme_path)
		_ctx.check(screen.get(&"theme_path") == theme_path, "注入的 theme_path 应生效")
	root.add_child(screen)
	return screen


func _unmount(screen: Node) -> void:
	if screen.get_parent() != null:
		screen.get_parent().remove_child(screen)
	screen.free()


## 按名字找节点。刻意不用 `%` 唯一名：ErrorPanel 是嵌套子场景的实例，
## 唯一名的作用域挂在 owner 上，跨子场景边界时语义容易出意外；按名字搜是确定的。
func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


## 屏幕上实际显示的文案（读自控件，不是重算一遍自检）。
func _visible_problems(screen: Node) -> PackedStringArray:
	var panel: Node = _find(screen, "ErrorPanel")
	if panel == null or not bool(panel.get(&"visible")):
		return PackedStringArray()
	var message: Label = _find(panel, "Message") as Label
	if message == null or message.text.is_empty():
		return PackedStringArray()
	var problems: PackedStringArray = []
	for line: String in message.text.split("\n"):
		if not line.is_empty():
			problems.append(line.trim_prefix("· "))
	return problems


func _has_cjk(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _state(name: String) -> int:
	return int(_flow_script.GameState[name])


func _autoload(singleton_name: String) -> Node:
	return root.get_node_or_null(NodePath(singleton_name))


func _finish() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：S1-05（PET-39）BOOT 场景 + 数据校验 + 失败提示")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 场景冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：BOOT 校验成功 · BOOT 校验失败（调色板/主题）· BOOT 重复进入")
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\scene_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("boot_scene_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
