## boot_check.gd
## 职责：BOOT 启动自检 —— 只读校验启动所依赖的调色板 / 主题 / 数据索引是否可用。
## 所属系统：ui（BOOT 场景的表现层；自检本身只读，不改动任何被校验对象）
## 依赖：Palette, DataRegistry
## 禁止：本文件不得修复或写入任何被校验对象，也不得切换状态 / 场景 —— 它只回答「能不能启动」。

class_name BootCheck
extends RefCounted

## 正式资产路径。调色板路径直接引用 Palette 的常量，避免同一路径出现两处事实来源（04 §6）。
const PALETTE_PATH: String = Palette.RESOURCE_PATH
const THEME_PATH: String = "res://assets/ui/theme_main.tres"

## 玩家可见文案。本阶段没有翻译表，中文原文即 tr() 的 key ——
## 日后接 .csv 翻译只要补表，不必回头改代码（06 §11：文本必须走 tr()）。
const MSG_PALETTE_MISSING: String = "启动失败：调色板资源缺失或损坏。"
const MSG_PALETTE_INCOMPLETE: String = "启动失败：调色板缺少必要的颜色定义。"
const MSG_THEME_MISSING: String = "启动失败：界面主题资源缺失或损坏。"
const MSG_DATA_NOT_LOADED: String = "启动失败：游戏数据尚未加载完成。"
const MSG_TITLE: String = "无法启动"


## 启动自检。返回 tr() key 列表，空数组 = 通过。
## 两个路径可注入：正式资产本不该坏，失败分支只有靠注入损坏路径才测得到（09 §4）。
static func collect_problems(palette_path: String = PALETTE_PATH, theme_path: String = THEME_PATH) -> PackedStringArray:
	var problems: PackedStringArray = []
	_check_palette(palette_path, problems)
	_check_theme(theme_path, problems)
	_check_registry(problems)
	return problems


## 调色板是全项目唯一的色值来源（04 §6）。它坏了，之后每个场景都会画错颜色。
static func _check_palette(path: String, problems: PackedStringArray) -> void:
	var palette: Palette = ResourceLoader.load(path) as Palette
	if palette == null:
		problems.append(MSG_PALETTE_MISSING)
		return
	var missing: PackedStringArray = []
	for key: Palette.Key in Palette.Key.values():
		if not palette.has_token(key):
			missing.append(String(Palette.key_to_name(key)))
	if not missing.is_empty():
		problems.append(MSG_PALETTE_INCOMPLETE)
		# 「缺的是哪个 Token」属开发者信息，进日志即可，不进玩家文案。
		print("BootCheck: palette.tres 缺少 Token：%s" % ", ".join(missing))


## 主题必须真的装配得出来，否则每个场景都要退回引擎默认样式（06 §10.7）。
static func _check_theme(path: String, problems: PackedStringArray) -> void:
	if not (ResourceLoader.load(path) is Theme):
		problems.append(MSG_THEME_MISSING)


## BOOT 的职责之一是把数据加载完再交棒（03 §1 的 BOOT 关口）。
## 这条是启动顺序的前置条件：它拦的是「Autoload 尚未就绪就实例化 BOOT」这类顺序错误 ——
## 实测在 --script 模式下，_initialize() 里同步挂载场景就会命中（见 tests/integration/boot_scene_smoke.gd）。
static func _check_registry(problems: PackedStringArray) -> void:
	if not DataRegistry.is_loaded():
		problems.append(MSG_DATA_NOT_LOADED)
