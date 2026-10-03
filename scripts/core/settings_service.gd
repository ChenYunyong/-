## settings_service.gd
## 职责：分辨率 / 音量 / 语言的运行时设置服务（03_ARCHITECTURE.md §3 的 Settings）。
## 所属系统：core
## 依赖：ProjectSettings（只读，用于取引擎侧默认值）
## 禁止：本文件不得含玩法逻辑，也不得自行持久化 ——
##       磁盘存档属 SaveService（03 §3），本批未实现，故此处只做进程内设置。

extends Node

## 某项设置发生变化时触发。监听者用对应的 get_* 读取新值。
signal setting_changed(key: StringName)

const KEY_RESOLUTION: StringName = &"resolution"
const KEY_MASTER_VOLUME: StringName = &"master_volume"
const KEY_LOCALE: StringName = &"locale"

const AUDIO_BUS_MASTER: StringName = &"Master"
## 音量域的闭区间。1.0 = 无衰减，0.0 = 静音（映射到 VOLUME_DB_SILENT）。
const VOLUME_LINEAR_MIN: float = 0.0
const VOLUME_LINEAR_MAX: float = 1.0
const VOLUME_DB_SILENT: float = -80.0

## 窗口默认尺寸取自 project.godot，避免在此另立一个数值。
const PROJECT_WINDOW_WIDTH_SETTING: String = "display/window/size/window_width_override"
const PROJECT_WINDOW_HEIGHT_SETTING: String = "display/window/size/window_height_override"

var _resolution: Vector2i = Vector2i.ZERO
var _master_volume: float = VOLUME_LINEAR_MAX
var _locale: String = ""


## 注意：Settings 是 Autoload，_init() 里读 ProjectSettings 在 --script 模式下
## 可能早于工程设置就绪，因此初始化放在 _ready()。
func _ready() -> void:
	reset_to_defaults()


## 恢复为引擎侧默认值。
func reset_to_defaults() -> void:
	_resolution = _read_default_resolution()
	_master_volume = VOLUME_LINEAR_MAX
	_locale = TranslationServer.get_locale()
	_apply_volume()
	_apply_locale()


## 当前窗口分辨率。
func get_resolution() -> Vector2i:
	return _resolution


## 设置窗口分辨率。非正数会被拒绝并保持原值（02 §9：外部输入必须校验范围）。
func set_resolution(value: Vector2i) -> void:
	if value.x <= 0 or value.y <= 0:
		push_error("Settings: 非法分辨率 %s，已忽略。" % value)
		return
	if value == _resolution:
		return
	_resolution = value
	_emit_changed(KEY_RESOLUTION)


## 主音量，线性 0.0–1.0。
func get_master_volume() -> float:
	return _master_volume


## 设置主音量。越界值钳制到合法区间而非报错，避免 UI 抖动导致设置被拒。
func set_master_volume(value: float) -> void:
	var clamped: float = clampf(value, VOLUME_LINEAR_MIN, VOLUME_LINEAR_MAX)
	if is_equal_approx(clamped, _master_volume):
		return
	_master_volume = clamped
	_apply_volume()
	_emit_changed(KEY_MASTER_VOLUME)


## 当前语言 key。空串表示跟随系统。
func get_locale() -> String:
	return _locale


## 设置语言 key。空串会被拒绝并保持原值。
func set_locale(value: String) -> void:
	if value.is_empty():
		push_error("Settings: 语言 key 不得为空，已忽略。")
		return
	if value == _locale:
		return
	_locale = value
	_apply_locale()
	_emit_changed(KEY_LOCALE)


func _read_default_resolution() -> Vector2i:
	var width: int = int(ProjectSettings.get_setting(PROJECT_WINDOW_WIDTH_SETTING, 0))
	var height: int = int(ProjectSettings.get_setting(PROJECT_WINDOW_HEIGHT_SETTING, 0))
	return Vector2i(width, height)


func _apply_volume() -> void:
	var bus_index: int = AudioServer.get_bus_index(AUDIO_BUS_MASTER)
	if bus_index < 0:
		push_error("Settings: 找不到音频总线 '%s'。" % AUDIO_BUS_MASTER)
		return
	var db: float = VOLUME_DB_SILENT if _master_volume <= VOLUME_LINEAR_MIN else linear_to_db(_master_volume)
	AudioServer.set_bus_volume_db(bus_index, db)


func _apply_locale() -> void:
	TranslationServer.set_locale(_locale)


func _emit_changed(key: StringName) -> void:
	setting_changed.emit(key)
