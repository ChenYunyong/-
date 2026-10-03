## test_boot_check.gd
## 职责：BOOT 启动自检的单元用例 —— 通过路径 + 每一条失败路径，并核对文案是中文可读。
## 所属系统：tests
## 依赖：test_context, scripts/ui/boot_check.gd
## 禁止：本文件不得依赖场景树里已经存在 BOOT 场景，也不得修改任何正式资产 ——
##       失败路径一律靠注入测试专用 fixture（09 §4：测试数据不得污染正式 data/）。

extends RefCounted

const BOOT_CHECK_PATH: String = "res://scripts/ui/boot_check.gd"
const MISSING_ASSET_PATH: String = "res://tests/unit/fixtures/missing_asset.tres"
const INCOMPLETE_PALETTE_PATH: String = "res://tests/unit/fixtures/palette_incomplete.tres"
## 一个存在但类型不对的资源：用来覆盖「主题不是 Theme」这条，而不是只覆盖「文件不存在」。
const WRONG_TYPE_PATH: String = "res://assets/palette.tres"

var _script: GDScript = null


func run(ctx: RefCounted, tree: SceneTree) -> void:
	# 自检的前置条件之一是 DataRegistry 已就绪，而 --script 模式下 Autoload 的 _ready
	# 要等第一帧才跑完。先让出一帧，否则这里测到的是「顺序错误」而不是被测逻辑。
	await tree.process_frame

	_script = load(BOOT_CHECK_PATH)
	if not ctx.check(_script != null and _script.can_instantiate(), "boot_check.gd 应能加载"):
		return

	_run_pass_path(ctx)
	_run_palette_failures(ctx)
	_run_theme_failures(ctx)
	_run_message_checks(ctx)


func _run_pass_path(ctx: RefCounted) -> void:
	ctx.begin_case("BootCheck · 通过路径")
	var problems: PackedStringArray = _collect()
	ctx.equal(problems.size(), 0, "正式资产下自检应无问题（实际：%s）" % ", ".join(problems))


func _run_palette_failures(ctx: RefCounted) -> void:
	ctx.begin_case("BootCheck · 调色板失败：缺失 / 不完整")
	var missing: PackedStringArray = _collect(MISSING_ASSET_PATH)
	ctx.equal(missing.size(), 1, "调色板路径不存在时应恰好报 1 项")
	if missing.size() == 1:
		ctx.equal(missing[0], _script.MSG_PALETTE_MISSING, "缺失调色板的文案")

	var incomplete: PackedStringArray = _collect(INCOMPLETE_PALETTE_PATH)
	ctx.check(incomplete.has(_script.MSG_PALETTE_INCOMPLETE),
		"调色板存在但 Token 不全时应报「缺少颜色定义」（实际：%s）" % ", ".join(incomplete))


func _run_theme_failures(ctx: RefCounted) -> void:
	ctx.begin_case("BootCheck · 主题失败：缺失 / 类型不对")
	var missing: PackedStringArray = _collect(_script.PALETTE_PATH, MISSING_ASSET_PATH)
	ctx.check(missing.has(_script.MSG_THEME_MISSING), "主题路径不存在时应报主题缺失")

	# 资源存在但不是 Theme（拿 palette.tres 冒充）—— 这一段必须与「文件不存在」分开跑，
	# 否则「类型不对」这条分支永远没有证据（09 §4 v0.1.1）。
	var wrong_type: PackedStringArray = _collect(_script.PALETTE_PATH, WRONG_TYPE_PATH)
	ctx.check(wrong_type.has(_script.MSG_THEME_MISSING), "路径存在但资源不是 Theme 时同样应报主题缺失")


## 06 §11 要求玩家可见文本走 tr()，且验收要求「中文、可读」—— 两条都在这里钉住。
func _run_message_checks(ctx: RefCounted) -> void:
	ctx.begin_case("BootCheck · 文案（tr() key + 中文可读）")
	var keys: PackedStringArray = [
		_script.MSG_TITLE,
		_script.MSG_PALETTE_MISSING,
		_script.MSG_PALETTE_INCOMPLETE,
		_script.MSG_THEME_MISSING,
		_script.MSG_DATA_NOT_LOADED,
	]
	for key: String in keys:
		ctx.check(not key.is_empty(), "文案 key 不得为空")
		ctx.check(_has_cjk(key), "文案 `%s` 应含中文，玩家才读得懂" % key)
		ctx.equal(tr(key), key, "无翻译表时 tr() 应原样返回中文原文（`%s`）" % key)


## 至少一个中日韩统一表意文字，即「这行字是中文」。
func _has_cjk(text: String) -> bool:
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		if code >= 0x4E00 and code <= 0x9FFF:
			return true
	return false


func _collect(palette_path: String = "", theme_path: String = "") -> PackedStringArray:
	var resolved_palette: String = palette_path if not palette_path.is_empty() else _script.PALETTE_PATH
	var resolved_theme: String = theme_path if not theme_path.is_empty() else _script.THEME_PATH
	return _script.collect_problems(resolved_palette, resolved_theme)
