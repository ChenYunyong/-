## palette.gd
## 职责：颜色 Token 的定义，以及全项目取色的唯一入口（04_COLOR_SYSTEM.md §6）。
## 所属系统：data
## 依赖：assets/palette.tres（唯一的色值事实来源）
## 禁止：本文件不得出现任何十六进制色值 —— 色值只允许存在于 palette.tres；
##       任何其它文件也不得写裸 Color("#......")（04 §1、§4.9）。

class_name Palette
extends Resource

## 调色板 Token。名称与 04_COLOR_SYSTEM.md §3 各表逐字一致，共 35 个。
## 顺序：§3.1 深色 UI → §3.2 蓝 → §3.3 金 → §3.4 暖 → §3.5 木 → §3.6 中性 → §3.7 红 → §3.8 橙。
enum Key {
	NAVY_900,
	NAVY_800,
	NAVY_700,
	NAVY_600,
	NAVY_500,
	BLUE_500,
	BLUE_400,
	BLUE_300,
	BLUE_200,
	BLUE_100,
	BLUE_050,
	BLUE_FX_600,
	GOLD_600,
	GOLD_500,
	GOLD_400,
	GOLD_200,
	WARM_300,
	WARM_500,
	BROWN_700,
	BROWN_600,
	BROWN_500,
	BROWN_450,
	BROWN_400,
	BROWN_300,
	BROWN_200,
	WHITE,
	GREY_300,
	GREY_500,
	BLACK,
	RED_600,
	RED_500,
	RED_400,
	ORANGE_600,
	ORANGE_500,
	ORANGE_300,
}

## 唯一色值来源。
const RESOURCE_PATH: String = "res://assets/palette.tres"

## Token 缺失时的返回值。品红是 Godot 惯例的错误指示色，不是调色板设计值，
## 目的是让漏配在画面上立刻显形，而不是悄悄退化成一个「看起来还行」的颜色。
const MISSING_COLOR: Color = Color.MAGENTA

## Token 名 -> Color。键名与 Key 枚举名逐字一致。
@export var colors: Dictionary = {}

static var _cached: Palette = null


## 取色调色板实例（带缓存）。加载失败时返回 null 并 push_error。
static func get_palette() -> Palette:
	if _cached != null:
		return _cached
	var loaded: Resource = ResourceLoader.load(RESOURCE_PATH)
	if loaded == null:
		push_error("Palette: 无法加载 '%s'。" % RESOURCE_PATH)
		return null
	_cached = loaded as Palette
	if _cached == null:
		push_error("Palette: '%s' 不是 Palette 资源。" % RESOURCE_PATH)
	return _cached


## 取色唯一入口。key 缺失或类型不对时 push_error 并返回 MISSING_COLOR（02 §9）。
##
## 注：形参类型必须写作 `Palette.Key` 而非裸 `Key` —— Godot 在 @GlobalScope 里
## 已有一个键盘用的全局 `Key` 枚举，裸写在跨脚本调用时会被解析成那个全局枚举
## （脚本内部的 `Key.values()` 却能正确指向本枚举，两者行为不一致）。
static func get_color(key: Palette.Key) -> Color:
	var palette: Palette = get_palette()
	if palette == null:
		return MISSING_COLOR
	return palette.resolve(key)


## 全部已登记的 Token 名，按枚举顺序。供测试校验与编辑器工具使用。
static func token_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: int in Key.values():
		names.append(key_to_name(key))
	return names


## 枚举序号 -> Token 名。序号非法时返回空 StringName。
static func key_to_name(key: int) -> StringName:
	var found: Variant = Key.find_key(key)
	if found == null:
		return &""
	return StringName(found)


## 实例侧取色。静态 get_color() 的落地实现，独立出来便于测试直接注入假数据。
func resolve(key: Palette.Key) -> Color:
	var token_name: StringName = key_to_name(key)
	if token_name == &"":
		push_error("Palette: 未知 Token 序号 %d。" % key)
		return MISSING_COLOR
	var value: Variant = _lookup(token_name)
	if value == null:
		push_error("Palette: palette.tres 缺少 Token '%s'。" % token_name)
		return MISSING_COLOR
	if not (value is Color):
		push_error("Palette: Token '%s' 的值不是 Color。" % token_name)
		return MISSING_COLOR
	return value as Color


## 本实例是否登记了该 Token（用于编辑器工具与测试）。
func has_token(key: Palette.Key) -> bool:
	return _lookup(key_to_name(key)) != null


## String 与 StringName 在 Dictionary 里是否同键取决于引擎版本，两把都试一次。
func _lookup(token_name: StringName) -> Variant:
	if colors.has(token_name):
		return colors[token_name]
	var as_string: String = String(token_name)
	if colors.has(as_string):
		return colors[as_string]
	return null
