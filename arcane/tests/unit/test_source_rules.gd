## test_source_rules.gd
## 职责：反向对照测试 —— 直接扫源码，把「靠自觉遵守」的硬规则变成会失败的断言。
## 所属系统：tests
## 依赖：无（只读文件）
## 禁止：本文件不得修改任何源码，只扫描与断言。
##
## 这些规则本来写在 02 / 03 / 04 里，但文档管不住手。每一条都配一个**反向对照**：
## 先拿一段人造的违规样本喂给扫描函数，确认它抓得到，再去扫真源码 —— 否则一个
## 「永远返回 0」的扫描器会让整套规则全绿，那比没有测试更糟。

extends RefCounted

const SCAN_ROOTS: PackedStringArray = ["res://scripts", "res://tests"]
## 02 §4：单文件不超过 300 行。
const MAX_FILE_LINES: int = 300
## 02 §4：单函数不超过 50 行。
const MAX_FUNC_LINES: int = 50
## 04 §7：颜色只能来自 Palette，裸色值只允许出现在调色板自己的实现里。
const PALETTE_IMPL: String = "res://scripts/data/palette.gd"
## 03 §1.1 R3：换场景只有 GameFlow 一家。
const SCENE_ROUTER: String = "res://scripts/core/game_flow.gd"
## 03 §6：全局 RNG 的唯一入口（只有「随机种子」这一次熵是合法的）。
const SEED_SOURCE: String = "res://scripts/core/run_state.gd"

## 豁免一：本文件是「规则的检查器」，必须把违规写法本身当数据写进来（常量表 + 人造样本）。
## 豁免范围仅限下面三项**模式扫描**；文件长度、函数长度、文件头三项照旧管着它自己。
const EXEMPT_FILES: PackedStringArray = ["res://tests/unit/test_source_rules.gd"]

## 豁免二只作用于**裸色值**这一项：test_palette.gd 要钉住 04 §7 的兜底色契约
## （MISSING_COLOR 必须是一眼认得出的洋红），这条断言只能用裸色值写 ——
## 拿 Palette 自己验 Palette 是循环论证。别的扫描（换场景 / 随机）照旧管着它。
const COLOR_EXEMPT_FILES: PackedStringArray = ["res://tests/unit/test_source_rules.gd",
	"res://tests/unit/test_palette.gd"]

## 裸色值的四种写法。`Color.` 之后接常量名（Color.BLACK 之类），
## 用 `Color.` + 大写字母来判，免得把 `Color(...)` 与 `Color8(...)` 漏掉。
const COLOR_MARKERS: PackedStringArray = ["Color(", "Color8("]
## 全局（非确定性）随机调用。带 `.` 接收者的是 RandomNumberGenerator 的方法，不算。
const RNG_MARKERS: PackedStringArray = ["randi(", "randf(", "randi_range(", "randf_range("]


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("test_source_rules")
	var files: PackedStringArray = _gd_files()
	ctx.check(files.size() >= 20, "扫到了源码文件（%d 个），不是空扫描" % files.size())
	_check_scanner_itself(ctx)
	_check_headers(ctx, files)
	_check_file_length(ctx, files)
	_check_function_length(ctx, files)
	_check_no_bare_colors(ctx, files)
	_check_single_scene_router(ctx, files)
	_check_rng_discipline(ctx, files)


## 反向对照：给扫描函数喂人造违规样本，确认它抓得住。
## 这一段失败意味着下面所有「0 处违规」的结论都不可信。
func _check_scanner_itself(ctx: RefCounted) -> void:
	var sample: String = "\n".join(PackedStringArray([
		"var a: Color = Color(1, 0, 0)",
		"var b := Color8(255, 0, 0)",
		"var c := Color.MAGENTA",
		"var d := randi() % 3",
		"var e := randf()",
		"var f := randi_range(1, 9)",
		"get_tree().change_scene_to_file(\"res://x.tscn\")",
		"generator.randomize()",
	]))
	ctx.equal(_count_color_markers(sample), 3, "扫描器抓得到三种裸色值写法")
	ctx.equal(_count_bare_rng_calls(sample), 3, "扫描器抓得到三种全局随机调用")
	ctx.check(_contains_code(sample, "change_scene_to_file"), "扫描器抓得到换场景调用")
	ctx.check(_contains_code(sample, "randomize("), "扫描器抓得到 randomize")
	# 反向对照的反面：带 `.` 接收者的 RNG 方法**不许**被误判。
	var seeded: String = "generator.randi_range(0, 9)\nrng.randf()\nrng.randi()"
	ctx.equal(_count_bare_rng_calls(seeded), 0, "带接收者的随机方法不算全局随机")
	# 注释里提到这些词也不许误判 —— 否则没人敢在注释里解释规则。
	var commented: String = "## 不得调用 change_scene_to_file()\n# 也不许 Color(1,0,0) 与 randi()"
	var commented_code: String = _code_only(commented.split("\n"))
	ctx.check(not _contains_code(commented_code, "change_scene_to_file"), "注释不算代码")
	ctx.equal(_count_color_markers(commented_code), 0, "注释里的裸色值不算违规")
	ctx.equal(_count_bare_rng_calls(commented_code), 0, "注释里的随机调用不算违规")


## 02：每个 .gd 必须有文件头，且写明职责 / 所属系统 / 依赖 / 禁止。
func _check_headers(ctx: RefCounted, files: PackedStringArray) -> void:
	var missing: PackedStringArray = PackedStringArray()
	for path: String in files:
		var head: String = "\n".join(_head_lines(path, 8))
		for field: String in ["职责：", "所属系统：", "依赖：", "禁止："]:
			if not head.contains("## %s" % field):
				missing.append("%s 缺 %s" % [path.get_file(), field])
	ctx.equal(missing.size(), 0, _note("所有文件都有完整文件头", "缺文件头：%s", missing))


func _check_file_length(ctx: RefCounted, files: PackedStringArray) -> void:
	var over: PackedStringArray = PackedStringArray()
	for path: String in files:
		var count: int = _lines(path).size()
		if count > MAX_FILE_LINES:
			over.append("%s(%d)" % [path.get_file(), count])
	ctx.equal(over.size(), 0, _note("没有文件超过 %d 行" % MAX_FILE_LINES, "超长文件：%s", over))


## 02 §4：单函数不超过 50 行。函数体 = 从签名行到下一个顶层声明之前。
func _check_function_length(ctx: RefCounted, files: PackedStringArray) -> void:
	var offenders: PackedStringArray = PackedStringArray()
	var longest: int = 0
	for path: String in files:
		for span: Array in _function_spans(_lines(path)):
			longest = maxi(longest, int(span[1]))
			if int(span[1]) > MAX_FUNC_LINES:
				offenders.append("%s::%s(%d)" % [path.get_file(), span[0], span[1]])
	ctx.check(longest > 0, "确实解析到了函数（最长 %d 行）" % longest)
	ctx.equal(offenders.size(), 0, _note("没有函数超过 %d 行" % MAX_FUNC_LINES, "超长函数：%s", offenders))


## 04 §7：除调色板实现外，任何文件都不许出现裸色值。
func _check_no_bare_colors(ctx: RefCounted, files: PackedStringArray) -> void:
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in files:
		if path == PALETTE_IMPL or COLOR_EXEMPT_FILES.has(path):
			continue
		var hits: int = _count_color_markers(_code_only(_lines(path)))
		if hits > 0:
			offenders.append("%s(%d)" % [path.get_file(), hits])
	ctx.equal(offenders.size(), 0, _note("除 palette.gd 外没有裸色值", "裸色值：%s", offenders))
	# 调色板自己必须是例外，否则说明扫描条件写反了。
	ctx.check(_count_color_markers(_code_only(_lines(PALETTE_IMPL))) > 0,
		"palette.gd 里确实有裸色值（它是唯一落点）")


## 03 §1.1 R3：全项目只有 GameFlow 能换场景。
func _check_single_scene_router(ctx: RefCounted, files: PackedStringArray) -> void:
	var offenders: PackedStringArray = PackedStringArray()
	for path: String in files:
		if path == SCENE_ROUTER or EXEMPT_FILES.has(path):
			continue
		if _contains_code(_code_only(_lines(path)), "change_scene_to_file"):
			offenders.append(path.get_file())
	ctx.equal(offenders.size(), 0,
		_note("只有 game_flow.gd 调用 change_scene_to_file()", "越权换场景：%s", offenders))
	ctx.check(_contains_code(_code_only(_lines(SCENE_ROUTER)), "change_scene_to_file"),
		"game_flow.gd 确实是那个唯一调用点")


## 03 §6：随机必须可复现 —— 全局 RNG 一律禁用；RandomNumberGenerator 必须显式播种；
## `randomize()` 只允许出现在「为整局抽一个种子」的那一处。
func _check_rng_discipline(ctx: RefCounted, files: PackedStringArray) -> void:
	var global_rng: PackedStringArray = PackedStringArray()
	var unseeded: PackedStringArray = PackedStringArray()
	var randomized: PackedStringArray = PackedStringArray()
	for path: String in files:
		if EXEMPT_FILES.has(path):
			continue
		var code: String = _code_only(_lines(path))
		var bare: int = _count_bare_rng_calls(code)
		if bare > 0:
			global_rng.append("%s(%d)" % [path.get_file(), bare])
		if code.contains("RandomNumberGenerator") and not code.contains(".seed ="):
			unseeded.append(path.get_file())
		if code.contains("randomize(") and path != SEED_SOURCE:
			randomized.append(path.get_file())
	ctx.equal(global_rng.size(), 0, _note("没有全局随机调用", "全局随机：%s", global_rng))
	ctx.equal(unseeded.size(), 0, _note("每个 RandomNumberGenerator 都显式播种", "未播种：%s", unseeded))
	ctx.equal(randomized.size(), 0, _note("randomize() 只出现在 run_state.gd", "越权 randomize：%s", randomized))
	ctx.check(_code_only(_lines(SEED_SOURCE)).contains("randomize("), "run_state.gd 是那个唯一熵源")


# ---------------------------------------------------------------- 扫描工具

## 递归收集所有 .gd。排序后返回，保证报告顺序稳定。
func _gd_files() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for root: String in SCAN_ROOTS:
		_collect(root, found)
	var sorted: Array = Array(found)
	sorted.sort()
	return PackedStringArray(sorted)


func _collect(dir_path: String, into: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_collect(full, into)
		elif entry.ends_with(".gd"):
			into.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func _lines(path: String) -> PackedStringArray:
	var text: String = FileAccess.get_file_as_string(path)
	return text.split("\n") if not text.is_empty() else PackedStringArray()


func _head_lines(path: String, count: int) -> PackedStringArray:
	var all: PackedStringArray = _lines(path)
	return all.slice(0, mini(count, all.size()))


## 去掉整行注释与空行，把剩下的拼回一段文本 —— 所有「算不算违规」的判断都基于它。
func _code_only(lines: PackedStringArray) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in lines:
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


func _contains_code(code: String, needle: String) -> bool:
	return code.contains(needle)


## 数裸色值。`Color.` 后面跟大写字母才算（Color.BLACK / Color.TRANSPARENT），
## 免得把 `Color(` 与 `Color8(` 重复计一次。
func _count_color_markers(code: String) -> int:
	var total: int = 0
	for marker: String in COLOR_MARKERS:
		total += code.count(marker)
	total += _count_prefixed_constant(code, "Color.")
	return total


## `Color.` + 大写字母，且排除 `Color.Color` 这种已计入项。
func _count_prefixed_constant(code: String, prefix: String) -> int:
	var total: int = 0
	var from: int = 0
	var at: int = code.find(prefix, from)
	while at >= 0:
		var after: int = at + prefix.length()
		if after < code.length() and _is_upper(code[after]):
			total += 1
		from = after
		at = code.find(prefix, from)
	return total


## 数全局随机调用：`randi(` 之类前面**不是** `.` 的才算。
## `generator.randi_range(0, 9)` 是带接收者的实例方法，合法。
func _count_bare_rng_calls(code: String) -> int:
	var total: int = 0
	for marker: String in RNG_MARKERS:
		var from: int = 0
		while true:
			var at: int = code.find(marker, from)
			if at < 0:
				break
			var before: String = code[at - 1] if at > 0 else ""
			if before != ".":
				total += 1
			from = at + marker.length()
	return total


## 违规列表为空就给「合格」的说法，否则把违规项列出来 —— 失败信息必须能直接定位。
static func _note(ok_message: String, bad_format: String, offenders: PackedStringArray) -> String:
	if offenders.is_empty():
		return ok_message
	return bad_format % ", ".join(offenders)


static func _is_upper(character: String) -> bool:
	return character >= "A" and character <= "Z"


## 解析函数体长度。返回 [[函数名, 行数], ...]。
## 顶层声明的判据是「行首不是空白」—— GDScript 里函数体必然缩进，够用了。
func _function_spans(lines: PackedStringArray) -> Array:
	var spans: Array = []
	var name: String = ""
	var start: int = -1
	var end: int = -1
	for index: int in lines.size():
		var line: String = lines[index]
		var trimmed: String = line.strip_edges()
		var top_level: bool = not line.is_empty() and not line.begins_with(" ") and not line.begins_with("\t")
		if top_level and (trimmed.begins_with("func ") or trimmed.begins_with("static func ")):
			if start >= 0:
				spans.append([name, end - start + 1])
			name = trimmed.split("(")[0].replace("static ", "").replace("func ", "")
			start = index
			end = index
		elif start >= 0 and top_level:
			spans.append([name, end - start + 1])
			name = ""
			start = -1
		elif start >= 0 and not trimmed.is_empty():
			end = index
	if start >= 0:
		spans.append([name, end - start + 1])
	return spans
