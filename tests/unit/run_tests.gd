## run_tests.gd
## 职责：测试入口 —— 以 --script 方式运行全部用例，并按 09_TEST_STANDARD.md §6 输出报告。
## 所属系统：tests
## 依赖：tests/unit/test_context.gd, tests/unit/test_clock.gd
## 禁止：本文件不得直接使用 Autoload 单例标识符 —— --script 入口脚本在工程注册
##       Autoload 之前就被编译，裸写 EventBus / GameFlow 会直接编译失败。
##       用例脚本是运行时 load() 进来的，不受此限，但仍统一经 /root 取节点。

extends SceneTree

## 用例脚本与其测试层级（09 §1）。
const TEST_SCRIPTS: Array[Dictionary] = [
	{"path": "res://tests/unit/test_project_config.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_palette.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_game_flow.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_data_registry.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_settings.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_theme.gd", "layer": "unit"},
	{"path": "res://tests/integration/test_state_loop.gd", "layer": "integration"},
]

const LOG_PATH: String = "res://tests/output/unit_tests.log"
## R1 用例靠 --fixed-fps 把 600 秒模拟时间压进毫秒级；漏加该参数时的兜底上限。
const WALL_CLOCK_BUDGET_MS: int = 120_000

var clock: Node = null

var _context: RefCounted = null
var _lines: Array[String] = []
## layer -> {"passed": int, "failed": int}
var _layer_stats: Dictionary = {}


func _initialize() -> void:
	_context = load("res://tests/unit/test_context.gd").new()
	clock = Node.new()
	clock.set_script(load("res://tests/unit/test_clock.gd"))
	clock.name = "TestClock"
	get_root().add_child(clock)

	for entry: Dictionary in TEST_SCRIPTS:
		await _run_case_script(String(entry["path"]), String(entry["layer"]))
	_finish()


## R1 用例通过它决定「最多可以再跑多久真实时间」。
func wall_clock_budget_ms() -> int:
	return WALL_CLOCK_BUDGET_MS


func _run_case_script(path: String, layer: String) -> void:
	var passed_before: int = _context.passed
	var failed_before: int = _context.failed

	# 编译失败的脚本 load() 仍会返回非 null，必须用 can_instantiate() 才能识别；
	# 否则该用例会被静默跳过 —— 层级统计停在 0/0 却报「失败项：无」。
	var script: GDScript = load(path)
	if script == null or not script.can_instantiate():
		_context.begin_case(path)
		_context.check(false, "用例脚本无法加载或编译失败")
		_record_layer(layer, _context.passed - passed_before, _context.failed - failed_before)
		return
	var instance: RefCounted = script.new()
	if instance == null or not instance.has_method(&"run"):
		_context.begin_case(path)
		_context.check(false, "用例脚本缺少 run(ctx, tree)")
		_record_layer(layer, _context.passed - passed_before, _context.failed - failed_before)
		return

	await instance.run(_context, self)

	# 一个用例脚本至少要有一次断言；0 断言说明它根本没跑起来。
	if _context.passed - passed_before + _context.failed - failed_before == 0:
		_context.begin_case(path)
		_context.check(false, "用例脚本未产生任何断言")
	_record_layer(layer, _context.passed - passed_before, _context.failed - failed_before)


func _record_layer(layer: String, passed_delta: int, failed_delta: int) -> void:
	var stats: Dictionary = _layer_stats.get(layer, {"passed": 0, "failed": 0})
	stats["passed"] = int(stats["passed"]) + passed_delta
	stats["failed"] = int(stats["failed"]) + failed_delta
	_layer_stats[layer] = stats


func _finish() -> void:
	_emit_report()
	_write_log()
	for line: String in _lines:
		print(line)
	quit(0 if _context.failed == 0 else 1)


func _emit_report() -> void:
	var version: Dictionary = Engine.get_version_info()
	var window: Vector2i = DisplayServer.window_get_size()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：S1-A（PET-38）project.godot + Autoload + 六状态机 + Palette/Theme")
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [version["string"], window.x, window.y])
	_lines.append("- 单元测试：%s" % _format_layer("unit"))
	_lines.append("- 集成测试：%s" % _format_layer("integration"))
	_lines.append("- 手动场景：无（本批不产出 scenes/**，场景冒烟属 S1-05 起）")
	if _context.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _context.failures.size())
		for failure: String in _context.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\unit_tests.log")


func _format_layer(layer: String) -> String:
	var stats: Dictionary = _layer_stats.get(layer, {"passed": 0, "failed": 0})
	var passed: int = int(stats["passed"])
	var failed: int = int(stats["failed"])
	return "%d/%d" % [passed, passed + failed]


func _write_log() -> void:
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("run_tests: 无法写入 %s。" % LOG_PATH)
		return
	for line: String in _lines:
		file.store_line(line)
	file.close()
