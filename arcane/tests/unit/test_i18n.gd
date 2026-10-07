## test_i18n.gd
## 职责：国际化机制的验收 —— 语言表完整、源码里每一个 tr() 字面量都在表里、切换语言真的换字。
## 所属系统：tests
## 依赖：CardCatalog, Settings（经 /root 取）
## 禁止：本文件不得写入语言表，只断言。
##
## 最容易漏的一条是「源码里 tr 了一个表里没有的 key」：运行时它**不报错**，
## 只是原地显示中文 key，于是英文界面里冒出一行中文。所以这里反过来扫源码。

extends RefCounted

const CSV_PATH: String = "res://assets/i18n/ui.csv"
const ZH_PATH: String = "res://assets/i18n/ui.zh_CN.translation"
const EN_PATH: String = "res://assets/i18n/ui.en.translation"
## 语言表里至少要有这么多条 —— 防止文件被清空后「每条 key 都存在」这种空真断言全绿。
const MIN_ROWS: int = 60

## 从源码里抽 tr("...") 字面量时用的模式。translate( 覆盖 UiKit 里
## TranslationServer.translate() 的写法（静态函数里没有 tr()）。
const EXTRACT_PATTERNS: PackedStringArray = ["tr(\"", "translate(\""]


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("test_i18n")
	var table: Dictionary = _load_csv()
	_check_table(ctx, table)
	_check_registration(ctx)
	_check_source_literals(ctx, table)
	_check_table_keys(ctx, table)
	_check_locale_switch(ctx, tree, table)


## 解析 ui.csv。格式固定为 `keys,zh_CN,en`，每格都用双引号包着。
func _load_csv() -> Dictionary:
	var table: Dictionary = {}
	var text: String = FileAccess.get_file_as_string(CSV_PATH)
	if text.is_empty():
		return table
	var lines: PackedStringArray = text.split("\n")
	for index: int in lines.size():
		var line: String = lines[index].strip_edges()
		if line.is_empty() or index == 0:
			continue
		var fields: PackedStringArray = line.split("\",\"")
		if fields.size() != 3:
			continue
		table[_unquote(fields[0])] = {
			"zh_CN": _unquote(fields[1]),
			"en": _unquote(fields[2]),
		}
	return table


static func _unquote(field: String) -> String:
	return field.trim_prefix("\"").trim_suffix("\"")


func _check_table(ctx: RefCounted, table: Dictionary) -> void:
	ctx.check(table.size() >= MIN_ROWS, "语言表有 %d 条（≥%d）" % [table.size(), MIN_ROWS])
	var incomplete: PackedStringArray = PackedStringArray()
	for key: String in table:
		var row: Dictionary = table[key]
		if key.strip_edges().is_empty() or String(row["zh_CN"]).is_empty() or String(row["en"]).is_empty():
			incomplete.append(key)
	ctx.equal(incomplete.size(), 0,
		"每条 key 都有中文与英文" if incomplete.is_empty() else "残缺条目：%s" % ", ".join(incomplete))
	ctx.check(table.has("奥术蓝图"), "招牌屏的名字在表里")


## project.godot 必须登记两份翻译，且两份都能加载 —— 少一份就有一半界面是原样 key。
##
## 注意这里**不能**断言 get_message_count()：csv_translation 导入器的 compress=1 产出的是
## OptimizedTranslation，它把消息表压成了查找结构，get_message_count() 恒为 0
## （引擎自己也会打一句 "OptimizedTranslation does not store the message texts"）。
## 按条数断言会得到一条永远为假、却与「翻译是否可用」无关的红。真正的验证在
## _check_locale_switch：经 TranslationServer 查出来的字必须等于语言表里那一格。
func _check_registration(ctx: RefCounted) -> void:
	var registered: PackedStringArray = ProjectSettings.get_setting(
		"internationalization/locale/translations", PackedStringArray())
	ctx.check(registered.has(ZH_PATH), "登记了中文翻译")
	ctx.check(registered.has(EN_PATH), "登记了英文翻译")
	for locale: String in ["zh_CN", "en"]:
		var path: String = "res://assets/i18n/ui.%s.translation" % locale
		ctx.check(ResourceLoader.exists(path),
			"翻译资源已生成：%s（新克隆上先跑一次 --import）" % path.get_file())
		var translation: Translation = load(path)
		if not ctx.check(translation != null, "%s 可加载" % path.get_file()):
			continue
		ctx.equal(translation.locale, locale, "%s 自报的 locale 与文件名一致" % path.get_file())


## 反向扫源码：代码里 tr 过的每一个字面量都必须在表里。
func _check_source_literals(ctx: RefCounted, table: Dictionary) -> void:
	# 先做反向对照：抽词函数对一段人造代码必须抽得出这两条 key。
	var sample: String = "var a := str(\"丙\")\npush_error(tr(\"甲\"))\nTranslationServer.translate(\"乙\")"
	var extracted: PackedStringArray = _extract_keys(sample)
	ctx.equal(extracted.size(), 2, "反向对照：抽词函数抓得到 tr() 与 translate() 两种写法")
	ctx.check(extracted.has("甲") and extracted.has("乙"), "反向对照：抽出来的就是那两条 key")
	ctx.check(not extracted.has("丙"), "反向对照：不把 str() 误当成 tr()")

	var missing: PackedStringArray = PackedStringArray()
	var seen: Dictionary = {}
	for path: String in _gd_files("res://scripts"):
		for key: String in _extract_keys(_code_only(path)):
			if seen.has(key):
				continue
			seen[key] = true
			if not table.has(key):
				missing.append("%s(%s)" % [path.get_file(), key])
	ctx.check(seen.size() >= 20, "扫到了 %d 个 tr() 字面量，不是空扫描" % seen.size())
	ctx.equal(missing.size(), 0,
		"每个 tr() 字面量都在语言表里" if missing.is_empty() else "表里没有：%s" % ", ".join(missing))


## 动态取 key 的那批（卡名 / 效果 / 元素名 / 功能名 / 卡面标记）同样必须查得到 ——
## 它们不是字面量，静态扫不到，只能挨个查表。
func _check_table_keys(ctx: RefCounted, table: Dictionary) -> void:
	var missing: PackedStringArray = PackedStringArray()
	for card: CardData in CardCatalog.all():
		for key: String in [card.name_key, card.effect_key, CardCatalog.mark_key(card),
				CardCatalog.type_label_key(card), CardCatalog.kind_label_key(card)]:
			if not table.has(key):
				missing.append("%s(%s)" % [card.id, key])
	ctx.equal(missing.size(), 0,
		"卡表引用的文案都在语言表里" if missing.is_empty() else "缺卡牌文案：%s" % ", ".join(missing))


## 切换语言必须真的换字 —— 而且换出来的字必须**等于语言表里那一格**，
## 不是「不等于中文」这种弱断言（那连一份只翻了一半的表都能骗过去）。
## 结束后把语言恢复原样：后面的用例里有按中文文案找控件的。
func _check_locale_switch(ctx: RefCounted, tree: SceneTree, table: Dictionary) -> void:
	var settings: Node = tree.root.get_node_or_null(^"Settings")
	if not ctx.check(settings != null, "Settings 单例存在，可测语言切换"):
		return
	var original: String = settings.get_locale()
	var rows: PackedStringArray = PackedStringArray(["奥术蓝图", "开始战斗", "卡片 %d · 丝线 %d"])
	for locale: String in ["zh_CN", "en"]:
		settings.set_locale(locale, false)
		ctx.equal(TranslationServer.get_locale(), locale, "切到 %s 后 TranslationServer 跟着换" % locale)
		ctx.equal(settings.get_locale(), locale, "语言选择被记下")
		for key: String in rows:
			if not ctx.check(table.has(key), "语言表里有 %s" % key):
				continue
			ctx.equal(TranslationServer.translate(key), String(table[key][locale]),
				"[%s] 「%s」查出来的字与语言表一致" % [locale, key])
	# persist = false：测试不得把语言选择写进玩家的 user://settings.cfg。
	if original.is_empty():
		# get_locale() 空串 = 跟随系统，而 set_locale() 会拒绝空串（02 §9），故走引擎入口还回去。
		TranslationServer.set_locale(original)
	else:
		settings.set_locale(original, false)
	ctx.equal(TranslationServer.get_locale(), original, "测试结束后语言恢复原样")


# ---------------------------------------------------------------- 扫描工具

func _gd_files(root: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return found
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = "%s/%s" % [root, entry]
		if dir.current_is_dir():
			found.append_array(_gd_files(full))
		elif entry.ends_with(".gd"):
			found.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return found


func _code_only(path: String) -> String:
	var kept: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.is_empty() and not trimmed.begins_with("#"):
			kept.append(line)
	return "\n".join(kept)


## 抽出 tr("...") / translate("...") 里的字面量。要求 `tr(` 前面不是标识符字符，
## 免得把 `str("...")` 也算进来。
static func _extract_keys(code: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for pattern: String in EXTRACT_PATTERNS:
		var from: int = 0
		while true:
			var at: int = code.find(pattern, from)
			if at < 0:
				break
			var start: int = at + pattern.length()
			if not _is_call_boundary(code, at):
				from = start
				continue
			var stop: int = code.find("\"", start)
			if stop < 0:
				break
			found.append(code.substr(start, stop - start))
			from = stop + 1
	return found


static func _is_call_boundary(code: String, at: int) -> bool:
	if at == 0:
		return true
	# 只看「是不是标识符字符」：`TranslationServer.translate(` 前面的点必须放行，
	# 而 `str("...")` 前面的 s 必须拦下。
	var before: String = code[at - 1]
	return not (before >= "a" and before <= "z") and not (before >= "A" and before <= "Z") \
		and before != "_" and not (before >= "0" and before <= "9")
