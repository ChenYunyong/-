## test_i18n.gd
## 职责：PET-67 中英切换 —— 翻译表是否覆盖全部 UI 文案、注册是否生效、开关是否即时生效、
##       选择是否跨进程保留，以及场景层有没有偷偷长出「当前是哪种语言」的分支。
## 所属系统：tests
## 依赖：test_context, scripts/core/settings_service.gd, scripts/ui/main_menu.gd
## 禁止：本文件不得留下副作用 —— 它会真的实例化 MAIN_MENU 入树、也会真的写一次
##       user://settings.cfg（用完把原文件放回去、全局 locale 也还原）。
##       正因为它有副作用，它排在单元层最后（见 run_tests.gd 的登记行）。

extends RefCounted

const CSV_PATH: String = "res://assets/i18n/ui.csv"
const SETTINGS_SCRIPT_PATH: String = "res://scripts/core/settings_service.gd"
const MENU_SCRIPT_PATH: String = "res://scripts/ui/main_menu.gd"
const MENU_SCENE_PATH: String = "res://scenes/menu/main_menu.tscn"
const WORKSPACE_SCRIPT_PATH: String = "res://scripts/ui/blueprint_workspace.gd"

## 表头即列序。key 是**中文原文**（06 §11「文本必须走 key」的落地约定）。
const EXPECTED_HEADER: String = "keys,zh_CN,en"

## 场景里静态写的**占位**文案，两种语言下都读得通，不进翻译表：
##   前两条带数字，做成 key 只会得到一行永远匹配不上的死行，而它们的宿主脚本在 _ready() 里
##   必然用 tr(格式化 key) % n 覆盖掉（result_screen.gd:89-90），玩家看不到；
##   最后一条是语言开关自己 —— 两种语言下都要能认出「按哪个」，故中英并列写死。
const SCENE_PLACEHOLDER_TEXTS: PackedStringArray = [
	"坚持到第 1 波",
	"随机种子 0",
	"中 / EN",
]

## 开发者日志里的中文不面向玩家：它们是给看日志的人读的，翻成英文反而丢上下文。
## 判据是**同一行**出现下面任一个调用 —— 本项目的日志都是单行调用，格式串与调用同在一行。
const LOG_CALLS: PackedStringArray = ["push_error(", "push_warning(", "print(", "printerr("]

## 覆盖率的兜底门槛：扫描器一旦坏掉（比如目录遍历取不到文件），上面那些「没缺」的断言
## 会因为「什么都没扫到」而一片全绿。这条把它变成红。
const MIN_EXPECTED_LITERALS: int = 30


func run(ctx: RefCounted, tree: SceneTree) -> void:
	# 下面两条用例会真的改动玩家偏好（开关落盘）与全局 locale。快照取在**最前面** ——
	# 取在用例中间的话，用例自己写出来的文件会被当成「原本就有」，等于把副作用留在了机器上。
	var script: GDScript = load(SETTINGS_SCRIPT_PATH)
	var path: String = String(script.SETTINGS_PATH) if script != null else ""
	var snapshot: PackedByteArray = _read_file(path)
	var locale_before: String = TranslationServer.get_locale()

	var keys: Dictionary = _keys()
	_run_registration_case(ctx)
	_run_table_format_case(ctx)
	_run_coverage_case(ctx, keys)
	_run_no_branch_case(ctx)
	await _run_live_switch_case(ctx, tree)
	await _run_warehouse_label_case(ctx, tree)
	_run_persistence_case(ctx, tree, script, path)

	TranslationServer.set_locale(locale_before)
	_restore_file(path, snapshot)


## 翻译表得先在 project.godot 里登记，引擎才认得这两种语言（03 §3 的 Settings 只负责选哪一种）。
func _run_registration_case(ctx: RefCounted) -> void:
	ctx.begin_case("I18N · 翻译表注册（project.godot）")
	var registered: PackedStringArray = PackedStringArray(
		ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray()))
	ctx.equal(registered.size(), 2, "应登记中英两份翻译资源")
	for path: String in registered:
		ctx.check(ResourceLoader.exists(path), "登记的翻译资源必须真实存在：%s" % path)

	var loaded: PackedStringArray = TranslationServer.get_loaded_locales()
	ctx.check(loaded.has("zh_CN") and loaded.has("en"), "两种语言都应加载（实得 %s）" % str(loaded))

	TranslationServer.set_locale("en")
	ctx.equal(TranslationServer.translate("主菜单"), "MAIN MENU", "en 下应取到英文译文")
	TranslationServer.set_locale("zh_CN")
	ctx.equal(TranslationServer.translate("主菜单"), "主菜单", "zh_CN 列的原文即 key，应原样返回")


## 表体是数据文件，格式错了不会报错、只会静默少几条译文，故逐行钉住。
func _run_table_format_case(ctx: RefCounted) -> void:
	ctx.begin_case("I18N · 表体格式（keys,zh_CN,en）")
	var rows: Array = _parse_csv()
	if not ctx.check(rows.size() >= 2, "翻译表应至少有表头 + 一行数据"):
		return
	ctx.equal(String(rows[0][0]), EXPECTED_HEADER, "表头即列序")

	var seen: Dictionary = {}
	for index: int in range(1, rows.size()):
		var line_number: int = index + 1
		var fields: PackedStringArray = rows[index]
		if not ctx.check(fields.size() == 3, "第 %d 行应有 3 列（实得 %d）" % [line_number, fields.size()]):
			continue
		var key: String = fields[0]
		ctx.check(not key.is_empty(), "第 %d 行的 key 不得为空" % line_number)
		ctx.equal(fields[1], key, "第 %d 行的 zh_CN 列必须与 key 逐字相同（06 §11）" % line_number)
		ctx.check(not fields[2].is_empty(), "第 %d 行缺 en 译文" % line_number)
		ctx.check(not seen.has(key), "key 不得重复：`%s`" % key)
		seen[key] = true
	ctx.check(seen.size() >= MIN_EXPECTED_LITERALS, "表里的 key 数量（实得 %d）" % seen.size())


## 覆盖率的正面判据：scripts / scenes 里**任何含中文的字面量**都得能在表里查到。
##
## 为什么不只扫 `tr("字面量")`：本项目的 key 大多不是写在调用点的字面量，而是常量或
## 运行时拼出来的（`tr(NOTICE_SETTINGS)`、`label.text = tr(text_key)`、`RewardOption.new(..., "核心", ...)`），
## 只认调用点会漏掉一大片。反过来按「含中文的字面量」全扫，漏网的只有开发者日志（下面排除）。
func _run_coverage_case(ctx: RefCounted, keys: Dictionary) -> void:
	ctx.begin_case("I18N · 翻译表覆盖全部 UI 文案（06 §11）")
	var files: Array[String] = []
	_collect_files("res://scripts", ".gd", files)
	_collect_files("res://scenes", ".tscn", files)
	ctx.check(files.size() >= 40, "应扫到 scripts / scenes 下的全部文件（实得 %d）" % files.size())

	var found: Dictionary = {}
	var missing: Array[String] = []
	for path: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for index: int in lines.size():
			var line: String = lines[index]
			if _is_log_line(line):
				continue
			for literal: String in _literals(line):
				if not _has_cjk(literal):
					continue
				found[literal] = true
				if keys.has(literal) or SCENE_PLACEHOLDER_TEXTS.has(literal):
					continue
				missing.append("%s:%d `%s`" % [path.get_file(), index + 1, literal])

	ctx.check(missing.is_empty(), "含中文的字面量都应能在表里查到（缺 %d 条：%s）" % [
		missing.size(), ", ".join(PackedStringArray(missing))])
	ctx.check(found.size() >= MIN_EXPECTED_LITERALS, "扫描应真的取到文案（实得 %d 条）" % found.size())

	# 豁免项一旦从场景里消失就该删掉，否则它会一直替一条早不存在的文案打掩护。
	for exempt: String in SCENE_PLACEHOLDER_TEXTS:
		ctx.check(found.has(exempt), "豁免的占位文案 `%s` 应真实存在，否则该豁免已过期" % exempt)


## 06 §11：场景层只转发点击，不判断「现在是哪种语言」。
## 与 test_main_menu.gd 那条 `Color(` 扫描同一种手法 —— 查源码纪律，而不是查有没有某个 if。
func _run_no_branch_case(ctx: RefCounted) -> void:
	ctx.begin_case("I18N · 场景层不得出现语言分支（06 §11）")
	var source: String = FileAccess.get_file_as_string(MENU_SCRIPT_PATH)
	var offenders: Array[String] = []
	var lines: PackedStringArray = source.split("\n")
	for index: int in lines.size():
		for literal: String in _literals(lines[index]):
			if literal == "en" or literal == "zh_CN":
				offenders.append("%s:%d" % [MENU_SCRIPT_PATH.get_file(), index + 1])
	ctx.check(offenders.is_empty(),
		"main_menu.gd 不得出现字面语言名（%s）" % ", ".join(PackedStringArray(offenders)))
	ctx.check(source.contains("Settings.toggle_locale()"), "语言开关应只调 Settings.toggle_locale()")


## 验收第一条：切了就得**当场**变，不重启、也不重进场景。
##
## 断言的是控件上真读得回来的文本：Logo 与标题栏是脚本赋的值，提示面板正文是
## MessagePanel 走 tr() 落的值 —— 三处都真经过了翻译入口，而不是把 key 拿去再翻一遍。
func _run_live_switch_case(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("I18N · 开关即时生效（不重启）")
	var settings: Node = _autoload(tree, "Settings")
	if not ctx.check(settings != null, "Settings Autoload 应存在"):
		return
	var packed: PackedScene = ResourceLoader.load(MENU_SCENE_PATH)
	if not ctx.check(packed is PackedScene, "main_menu.tscn 应能加载"):
		return

	var menu: Node = packed.instantiate()
	tree.root.add_child(menu)
	await tree.process_frame
	await tree.process_frame

	settings.call(&"set_locale", "zh_CN")
	await tree.process_frame
	ctx.equal(settings.call(&"get_locale"), "zh_CN", "前置：先回到中文")
	_check_menu_texts(ctx, menu, false)

	var language: Button = _find(menu, "ButtonLang") as Button
	if not ctx.check(language != null, "主菜单应有语言开关 ButtonLang"):
		_release(menu)
		return

	language.emit_signal(&"pressed")
	await tree.process_frame
	await tree.process_frame
	ctx.equal(settings.call(&"get_locale"), "en", "按一次开关应切到英文")
	_check_menu_texts(ctx, menu, true)

	language.emit_signal(&"pressed")
	await tree.process_frame
	await tree.process_frame
	ctx.equal(settings.call(&"get_locale"), "zh_CN", "再按一次应切回中文")
	_check_menu_texts(ctx, menu, false)

	_release(menu)


## english 为真时期望全英文，为假时期望全中文。
func _check_menu_texts(ctx: RefCounted, menu: Node, english: bool) -> void:
	var logo: Label = _find(menu, "Logo") as Label
	if ctx.check(logo != null, "应有 Logo"):
		ctx.equal(logo.text, "PixelFusion" if english else "PixelFusion / 像素融合屋", "Logo 文案随语言切换")

	var title_bar: Node = _find(menu, "TitleBar")
	if ctx.check(title_bar != null and title_bar.has_method(&"get_title_text"), "应有标题栏"):
		ctx.equal(String(title_bar.call(&"get_title_text")), "MAIN MENU" if english else "主菜单",
			"标题栏文案随语言切换")

	_check_notice_texts(ctx, menu, english)


## 提示面板是玩家真能读到的一段：切到英文后弹出来的提示也必须整条是英文。
func _check_notice_texts(ctx: RefCounted, menu: Node, english: bool) -> void:
	var notice: Control = _find(menu, "NoticePanel") as Control
	var button: Button = _find(menu, "ButtonSettings") as Button
	if not ctx.check(notice != null and button != null, "应有提示面板与『设置』按钮"):
		return

	button.emit_signal(&"pressed")
	ctx.check(notice.visible, "『设置』应弹出提示")
	var message: Label = _find(notice, "Message") as Label
	if ctx.check(message != null, "提示面板应有正文"):
		if english:
			ctx.check(message.text.contains("not implemented yet"),
				"英文下提示正文应是英文（实际：%s）" % message.text)
			ctx.check(not _has_cjk(message.text),
				"英文下提示正文不得残留中文（实际：%s）" % message.text)
		else:
			ctx.check(_has_cjk(message.text), "中文下提示正文应是中文（实际：%s）" % message.text)
	_dismiss(menu)


## S4-07 的 R5：仓库槽位名要经 tr()，且**切了语言要重画**。
##
## 两件事缺一不可：只 tr() 不重画，英文态下那 7 个标签仍然停在中文（实测就是这样 ——
## draw_string 画的是**当时那种语言**的成品，不重画就一直是旧译文）；只重画不 tr()，
## 重画一百次也还是中文。故一条断言管**取字**、一条断言管**重画**。
func _run_warehouse_label_case(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("I18N · 仓库槽位名（S4-07 R5：tr() + 切语言重画）")
	var workspace_script: GDScript = load(WORKSPACE_SCRIPT_PATH)
	var settings: Node = _autoload(tree, "Settings")
	if not ctx.check(workspace_script != null and settings != null,
			"blueprint_workspace.gd 与 Settings 应能加载"):
		return
	var slots: Array = workspace_script.WAREHOUSE

	TranslationServer.set_locale("zh_CN")
	for entry: Dictionary in slots:
		var key: String = String(entry["name"])
		ctx.equal(workspace_script.warehouse_label(entry), key,
			"zh_CN 下槽位名应原样返回 key（%s）" % key)

	# 正面判据是「取到了英文」，不是「等于某个我抄下来的英文串」—— 抄一份英文，
	# 表里改词时两边就一起错。故判据是：不含中文、非空、且确实与 key 不同。
	TranslationServer.set_locale("en")
	var translated: int = 0
	for entry: Dictionary in slots:
		var key: String = String(entry["name"])
		var label: String = workspace_script.warehouse_label(entry)
		ctx.check(not label.is_empty(), "en 下槽位名不得为空（%s）" % key)
		ctx.check(not _has_cjk(label), "en 下槽位名不得残留中文（%s → %s）" % [key, label])
		if label != key:
			translated += 1
	ctx.equal(translated, slots.size(),
		"7 个槽位名都应取到英文译文（实得 %d 个；缺行的话切了语言也还是中文）" % translated)
	TranslationServer.set_locale("zh_CN")

	# 重画：工作区必须订阅「语言变了」。_draw 只在重画时跑，没有别的机制会替它补上。
	var warehouse: Control = workspace_script.new()
	warehouse.set(&"area", workspace_script.Area.WAREHOUSE)
	tree.root.add_child(warehouse)
	await tree.process_frame
	ctx.check(settings.is_connected(&"setting_changed", Callable(warehouse, &"_on_setting_changed")),
		"仓库应订阅 Settings.setting_changed（切语言后要重画）")
	_release(warehouse)

	# 「怎么做到的」层面的两条钉子：取字只能经 warehouse_label()，重画只认语言这一个 key。
	var source: String = FileAccess.get_file_as_string(WORKSPACE_SCRIPT_PATH)
	ctx.check(source.contains("warehouse_label(entry)"),
		"_draw_warehouse 应经 warehouse_label() 取字，而不是直接画 entry[\"name\"]")
	ctx.check(source.contains("key == Settings.KEY_LOCALE"),
		"重画只应认语言这一个设置项（别的设置项与画面无关）")


## 验收第二条：选过的语言，重启后还在。
##
## 「重启」在这里落成「另一个全新实例的 _ready()」—— 它与真实启动走同一条路径
## （reset_to_defaults() → _load_locale()），不需要真的再起一个进程。
## 全程在独立实例上做，改动由 run() 在最后统一还原。
func _run_persistence_case(ctx: RefCounted, tree: SceneTree, script: GDScript, path: String) -> void:
	ctx.begin_case("I18N · 选择跨进程保留（user://settings.cfg）")
	if not ctx.check(script != null, "settings_service.gd 应能加载"):
		return

	var first: Node = _spawn(tree, script)
	first.call(&"set_locale", "en", true)
	ctx.equal(first.call(&"get_locale"), "en", "落盘前内存值应为 en")
	_release(first)
	ctx.check(FileAccess.file_exists(path), "切换语言应写出 %s" % path)

	var second: Node = _spawn(tree, script)
	ctx.equal(second.call(&"get_locale"), "en", "新实例（等价于重启）应读回上次选择")
	_release(second)

	# 磁盘是外部输入，取值必须校验（02 §9）：认不出的语言要挡在门外，而不是照单全收。
	_write_locale(path, script, "fr")
	var third: Node = _spawn(tree, script)
	ctx.not_equal(third.call(&"get_locale"), "fr", "磁盘上认不出的语言应被忽略")
	_release(third)


func _spawn(tree: SceneTree, script: GDScript) -> Node:
	var node: Node = script.new()
	node.name = "SettingsUnderTest"
	tree.root.add_child(node)
	return node


func _release(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.free()


func _dismiss(menu: Node) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.pressed = true
	menu.call(&"_input", event)


func _autoload(tree: SceneTree, singleton_name: String) -> Node:
	return tree.root.get_node_or_null(NodePath(singleton_name))


func _find(node: Node, node_name: String) -> Node:
	return node.find_child(node_name, true, false)


# --- 翻译表读写 ---------------------------------------------------------------

func _keys() -> Dictionary:
	var out: Dictionary = {}
	var rows: Array = _parse_csv()
	for index: int in range(1, rows.size()):
		var fields: PackedStringArray = rows[index]
		if fields.size() == 3:
			out[fields[0]] = true
	return out


## 字段一律带引号解析：表里有逗号与全角标点，不带引号会被 CSV 切错。
func _parse_csv() -> Array:
	var rows: Array = []
	for line: String in FileAccess.get_file_as_string(CSV_PATH).split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue
		var fields: PackedStringArray = PackedStringArray()
		for field: String in trimmed.split("\",\""):
			fields.append(field.trim_prefix("\"").trim_suffix("\""))
		rows.append(fields)
	return rows


func _read_file(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(path)


func _restore_file(path: String, snapshot: PackedByteArray) -> void:
	if snapshot.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("test_i18n: 无法还原 %s，本次运行可能留下副作用。" % path)
		return
	file.store_buffer(snapshot)
	file.close()


func _write_locale(path: String, script: GDScript, value: String) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(String(script.SETTINGS_SECTION), String(script.FIELD_LOCALE), value)
	config.save(path)


# --- 源码扫描 -----------------------------------------------------------------

## 取一行里所有字符串字面量。遇到**引号外**的 `#` 即停 —— 行尾注释里的引号不算代码，
## 整行注释因此自然返回空表，调用方不必另外判注释。
func _literals(line: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var index: int = 0
	while index < line.length():
		var code: int = line.unicode_at(index)
		if code == 0x23:
			break
		if code != 0x22:
			index += 1
			continue
		index += 1
		var text: String = ""
		while index < line.length():
			var inner: int = line.unicode_at(index)
			if inner == 0x5C:
				text += line.substr(index, 2)
				index += 2
				continue
			if inner == 0x22:
				break
			text += line[index]
			index += 1
		out.append(text)
		index += 1
	return out


func _is_log_line(line: String) -> bool:
	for call: String in LOG_CALLS:
		if line.contains(call):
			return true
	return false


## 中日韩统一表意文字 + 中文标点 + 全角标点。中文原文即 key，故「含这些字符」就是「面向玩家的文案」。
## 半角的 `·`（U+00B7）、`×`、`→` 不算 —— 它们出现在本就两种语言通读的串里（版本号、纯符号拼接）。
func _has_cjk(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if (code >= 0x4E00 and code <= 0x9FFF) or (code >= 0x3400 and code <= 0x4DBF) \
				or (code >= 0x3000 and code <= 0x303F) or (code >= 0xFF00 and code <= 0xFFEF):
			return true
	return false


func _collect_files(dir_path: String, suffix: String, out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full: String = dir_path.path_join(name)
			if dir.current_is_dir():
				_collect_files(full, suffix, out)
			elif name.ends_with(suffix):
				out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
