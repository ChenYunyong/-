## run_tests.gd
## 职责：测试入口 —— 以 --script 方式运行全部用例，并按 09_TEST_STANDARD.md §6 输出报告。
## 所属系统：tests
## 依赖：tests/unit/test_context.gd
## 禁止：本文件不得直接使用 Autoload 单例标识符 —— --script 入口脚本在工程注册
##       Autoload 之前就被编译，裸写 EventBus / GameFlow 会直接编译失败。
##       用例脚本是运行时 load() 进来的，不受此限，但仍统一经 /root 取节点。
##
## PET-85：本文件是**从旧工程原样带走的测试脚手架**，用例清单按新工程重写。
## 运行方式（在 arcane/ 工程根目录下）：
##   godot --headless --path . --script res://tests/unit/run_tests.gd -- --task "<任务号>"

extends SceneTree

## 用例脚本与其测试层级（09 §1）。顺序即执行顺序。
const TEST_SCRIPTS: Array[Dictionary] = [
	# 静态装配类：只看配置与资源，不入场景、不写 user://。
	{"path": "res://tests/unit/test_project_config.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_palette.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_source_rules.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_fonts.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_catalog.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_glyphs.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_i18n.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_layout.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_layout_p0.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_editor_state.gd", "layer": "unit"},
	# 纯逻辑类：不碰节点。
	{"path": "res://tests/unit/test_snap.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_board_model.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_combat_sim.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_combat_cards.gd", "layer": "unit"},
	# 战斗屏的版式与画法：§2.3 的几何表逐条对照，§3 的角色表逐条取色。
	{"path": "res://tests/unit/test_combat_layout.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_combat_paint.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_map_model.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_map_paint.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_map_layout.gd", "layer": "unit"},
	# 路线几何与节点符号：PET-93 给四态加了形状标记、给边加了绕开短名框的折线，
	# 于是各自从 test_map_paint 里分出来（源码有 300 行上限）。
	{"path": "res://tests/unit/test_map_symbol.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_map_route.gd", "layer": "unit"},
	# 奖励与本局账本：纯数据侧（选项的抽取 / 拿卡落到书页 / 加成进仿真），不碰节点。
	{"path": "res://tests/unit/test_reward.gd", "layer": "unit"},
	{"path": "res://tests/unit/test_game_flow.gd", "layer": "unit"},
	# 路线图屏要真的入树才验得了「点得动 / 重进复原」，但它在测试收尾时会 free 掉自己，
	# 不换 GameFlow 的状态（见文件头的禁止项），所以排在场景冒烟之前即可。
	{"path": "res://tests/integration/map_view_smoke.gd", "layer": "integration"},
	# 路线图屏装配后的**控件账**（§2.2 的 rect 上真的有控件、角色也对）：
	# 从 scene_smoke 里分出来 —— 那个文件已经顶到源码 300 行上限。
	{"path": "res://tests/integration/map_screen_smoke.gd", "layer": "integration"},
	# 战斗屏装配后的控件账（§2.3 的 rect 上真的有控件、卡链与结算键的角色也对）：
	# 同样是从 scene_smoke 里分出来的 —— 那里只数得下「有几个」，量不了真实的 rect。
	{"path": "res://tests/integration/combat_screen_smoke.gd", "layer": "integration"},
	# 主菜单屏同上：要入树才验得了四个入口与语言开关，但不换场景。
	{"path": "res://tests/integration/main_menu_smoke.gd", "layer": "integration"},
	# 场景冒烟要真的把场景入树，放在单元层之后。
	{"path": "res://tests/integration/scene_smoke.gd", "layer": "integration"},
	# 一局闭环的两条端到端：输（核心被摧毁 → 结算 → 回主菜单）与赢（一路打到通关 → 再来一局）。
	# 它们会真的启动一局并一路换屏，故各自在开头把状态机摆回 BOOT（同一个进程里只能启动一次）。
	{"path": "res://tests/integration/defeat_smoke.gd", "layer": "integration"},
	{"path": "res://tests/integration/full_run_smoke.gd", "layer": "integration"},
	# 一局完整循环（编辑器 → 战斗 → 奖励 → 路线图 → 编辑器）。**必须排在最后**：
	# 它假定自己是从「引擎刚起来」那一刻开始的，前面每个用例的场景断言也不能在它之后跑。
	{"path": "res://tests/integration/loop_smoke.gd", "layer": "integration"},
]

const LOG_PATH: String = "res://tests/output/unit_tests.log"

## 09 §6 报告的「任务」一行由运行期传入 —— 写死任务号会在下一批过期。
const DEFAULT_TASK_LABEL: String = "未指定（请用 -- --task \"<任务号> <标题>\" 传入）"

var _context: RefCounted = null
var _lines: Array[String] = []
var _task_label: String = DEFAULT_TASK_LABEL
## layer -> {"passed": int, "failed": int}
var _layer_stats: Dictionary = {}


func _initialize() -> void:
	_parse_args()
	# 先等两帧再跑用例。**不是**为了稳妥，是必须：
	# 以 --script 方式启动时，Autoload 节点在 _initialize() 这一刻已经挂在 root 下，但 root
	# 自己还没进树（Node.get_tree() 返回 null、Autoload 的 _ready() 也还没跑）。于是
	#   · GameFlow.owns_scene_routing() 读到 false（它靠 get_tree() 认自己）→ 路由断言全是假阴性；
	#   · Settings.get_locale() 读到空串（_ready() 还没执行）。
	# 等两帧之后的世界与「引擎正常启动一局」一致，用例才是在测真实的那个世界。
	await process_frame
	await process_frame
	_context = load("res://tests/unit/test_context.gd").new()
	for entry: Dictionary in TEST_SCRIPTS:
		await _run_case_script(String(entry["path"]), String(entry["layer"]))
	_finish()


## 只认 `--` 之后的用户参数；引擎自身的参数（--headless 等）不参与解析。
func _parse_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = 0
	while index < args.size():
		if args[index] == "--task" and index + 1 < args.size():
			_task_label = args[index + 1]
			index += 2
			continue
		index += 1


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
	_lines.append("TEST REPORT")
	_lines.append("- 任务：%s" % _task_label)
	_lines.append("- 环境：Godot %s / Windows / 工程 arcane" % version["string"])
	_lines.append("- 单元测试：%s" % _format_layer("unit"))
	_lines.append("- 集成测试：%s" % _format_layer("integration"))
	if _context.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _context.failures.size())
		for failure: String in _context.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：%s" % LOG_PATH)


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
