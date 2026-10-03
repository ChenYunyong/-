## test_palette.gd
## 职责：校验 Palette 与 04_COLOR_SYSTEM.md §3 冻结表**逐字一致**，且是唯一取色入口。
## 所属系统：tests
## 依赖：test_context, test_files, Palette
## 禁止：本文件不得硬编码任何色值 —— 期望值一律从 docs/04 当场解析，
##       否则就等于把色值复制了第二份，反而破坏 04 §6「唯一来源」。

extends RefCounted

const TestFiles: GDScript = preload("res://tests/unit/test_files.gd")

const SPEC_PATH: String = "res://docs/04_COLOR_SYSTEM.md"
const SCRIPTS_ROOT: String = "res://scripts"
const EXPECTED_TOKEN_COUNT: int = 35
## §3 表格行形如：| `NAVY_900` | `#0F1B33` | 用途 | 来源 | ... |
const TABLE_ROW_PATTERN: String = "^\\|\\s*`([A-Z0-9_]+)`\\s*\\|\\s*`(#[0-9A-Fa-f]{6})`"
const BARE_COLOR_PATTERN: String = "Color\\(\\s*\"#"


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	ctx.begin_case("Palette · Token 表与 docs/04 §3 逐字一致")
	var spec: Array = _parse_spec_table()
	if not ctx.check(spec.size() == EXPECTED_TOKEN_COUNT, "docs/04 §3 应解析出 %d 个 Token，实际 %d" % [EXPECTED_TOKEN_COUNT, spec.size()]):
		return

	var names: Array[StringName] = Palette.token_names()
	ctx.equal(names.size(), EXPECTED_TOKEN_COUNT, "Palette.Key 的 Token 数")

	var palette: Palette = Palette.get_palette()
	ctx.check(palette != null, "palette.tres 应能加载")
	if palette == null:
		return
	ctx.equal(palette.colors.size(), EXPECTED_TOKEN_COUNT, "palette.tres 的条目数")

	for index: int in spec.size():
		var expected_name: String = spec[index][0]
		var expected_hex: String = spec[index][1]
		if index < names.size():
			ctx.equal(String(names[index]), expected_name, "第 %d 个 Token 名" % index)
		var actual: Color = Palette.get_color(index)
		ctx.equal(actual.to_html(false).to_upper(), expected_hex.trim_prefix("#"), "Token %s 的色值" % expected_name)

	_run_integrity_checks(ctx, palette)
	_run_degradation_checks(ctx, palette)
	_run_no_bare_color_check(ctx)


## Token 之间不得出现完全相同或肉眼难分的 Hex（04 §4.5）。
func _run_integrity_checks(ctx: RefCounted, palette: Palette) -> void:
	ctx.begin_case("Palette · Token 唯一性与解析")
	var seen: Dictionary = {}
	var missing: int = 0
	for key: int in Palette.Key.values():
		var color: Color = Palette.get_color(key)
		if color == Palette.MISSING_COLOR:
			missing += 1
			continue
		var hex: String = color.to_html(false)
		ctx.check(not seen.has(hex), "Token %s 的色值 %s 与 %s 重复" % [Palette.key_to_name(key), hex, seen.get(hex, "")])
		seen[hex] = Palette.key_to_name(key)
	ctx.equal(missing, 0, "解析失败的 Token 数")
	ctx.equal(seen.size(), EXPECTED_TOKEN_COUNT, "互不相同的色值数")


## 空数据 / 非法输入必须走 push_error 并降级，不得静默崩溃（02 §9、09 §2）。
func _run_degradation_checks(ctx: RefCounted, palette: Palette) -> void:
	ctx.begin_case("Palette · 空数据与非法输入")
	ctx.equal(Palette.get_color(-1), Palette.MISSING_COLOR, "未知枚举序号应返回 MISSING_COLOR")
	ctx.equal(Palette.get_color(EXPECTED_TOKEN_COUNT), Palette.MISSING_COLOR, "越界枚举序号应返回 MISSING_COLOR")
	ctx.equal(Palette.key_to_name(-1), &"", "越界序号的 Token 名应为空")

	var empty: Palette = Palette.new()
	ctx.equal(empty.resolve(Palette.Key.NAVY_800), Palette.MISSING_COLOR, "colors 为空时应返回 MISSING_COLOR")
	ctx.check(not empty.has_token(Palette.Key.NAVY_800), "空 colors 不应报告含该 Token")

	var wrong_type: Palette = Palette.new()
	wrong_type.colors = {&"NAVY_800": "not-a-color"}
	ctx.equal(wrong_type.resolve(Palette.Key.NAVY_800), Palette.MISSING_COLOR, "值类型不对时应返回 MISSING_COLOR")
	ctx.check(palette.has_token(Palette.Key.NAVY_800), "正式 palette.tres 应含 NAVY_800")


## 04 §4.9：除 palette.tres 外，任何脚本都不得写裸 Color("#......")。
func _run_no_bare_color_check(ctx: RefCounted) -> void:
	ctx.begin_case("Palette · 脚本内不得出现裸色值")
	var regex: RegEx = RegEx.new()
	regex.compile(BARE_COLOR_PATTERN)
	var offenders: Array[String] = []
	for path: String in TestFiles.collect_gd_files(SCRIPTS_ROOT):
		for line: String in TestFiles.code_lines(path):
			if regex.search(line) != null:
				offenders.append("%s: %s" % [path, line.strip_edges()])
	ctx.check(offenders.is_empty(), "以下脚本出现了裸色值：%s" % ", ".join(offenders))


## 直接解析 docs/04 §3 的表格，返回 [token 名, #RRGGBB] 的有序列表。
## 故意不缓存、不落副本 —— 文档改了测试立刻能发现。
func _parse_spec_table() -> Array:
	var rows: Array = []
	var file: FileAccess = FileAccess.open(SPEC_PATH, FileAccess.READ)
	if file == null:
		push_error("test_palette: 读不到 %s。" % SPEC_PATH)
		return rows
	var regex: RegEx = RegEx.new()
	regex.compile(TABLE_ROW_PATTERN)
	while not file.eof_reached():
		var line: String = file.get_line()
		var found: RegExMatch = regex.search(line)
		if found != null:
			rows.append([found.get_string(1), found.get_string(2).to_upper()])
	file.close()
	return rows
