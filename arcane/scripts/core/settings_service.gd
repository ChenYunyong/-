## settings_service.gd
## 职责：分辨率 / 音量 / 语言的运行时设置服务（docs/03 §3 的 Settings）。
## 所属系统：core
## 依赖：ProjectSettings（只读，用于取引擎侧默认值）、ConfigFile（语言偏好的落盘）
## 禁止：本文件不得含玩法逻辑；不得碰存档 —— 磁盘存档属 SaveService（03 §3），本批未实现；
##       语言偏好是**设置**不是存档：单独落在 user://settings.cfg。
##
## PET-85：本文件是**从旧工程原样带走的工程脚手架**（多语言机制是资产，见卡面「带走」表）。
## 语言列取自新工程的 assets/i18n/ui.csv（同样两个语言：zh_CN / en）。

extends Node

## 某项设置发生变化时触发。监听者用对应的 get_* 读取新值。
signal setting_changed(key: StringName)

const KEY_RESOLUTION: StringName = &"resolution"
const KEY_MASTER_VOLUME: StringName = &"master_volume"
const KEY_LOCALE: StringName = &"locale"

## 已支持的语言。取值就是 Godot 的 locale 名，与 assets/i18n/ui.csv 的语言列一一对应
## （project.godot 的 internationalization/locale/translations 登记它们的导入产物）。
const LOCALE_ZH_CN: String = "zh_CN"
const LOCALE_EN: String = "en"
const SUPPORTED_LOCALES: PackedStringArray = [LOCALE_ZH_CN, LOCALE_EN]

## 语言偏好的落盘位置。本文件只装设置，不装存档（见文件头）。
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "settings"
const FIELD_LOCALE: String = "locale"

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
	# 上次选择的语言覆盖引擎默认值（首次运行没有这份文件，保持系统语言）。
	_load_locale()


## 恢复为引擎侧默认值。**不含**上次选择的语言 —— 那份偏好只在 _load_locale() 里应用，
## 这样「恢复默认」与「读回玩家选择」是两件事，各自只有一个入口。
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
##
## persist = false（默认）只改进程内设置，**不落盘**：单测会在独立实例上反复调本函数做校验
## （tests/unit/test_settings.gd 明令「不得改动用户的显示/音频设置」），默认落盘等于让测试
## 把语言选择写进玩家偏好，还会连带影响同机上后跑的进程。玩家显式切换走 toggle_locale()。
func set_locale(value: String, persist: bool = false) -> void:
	if value.is_empty():
		push_error("Settings: 语言 key 不得为空，已忽略。")
		return
	if value == _locale:
		return
	_locale = value
	_apply_locale()
	if persist:
		_save_locale()
	_emit_changed(KEY_LOCALE)


## 在已支持的语言之间切换并落盘，返回切换后的 locale。
##
## **语言判断只在这里做**：场景层不得出现「当前是哪种语言」的分支（06 §11「文本必须走 key」），
## MAIN_MENU 的语言开关只调这一个入口。
func toggle_locale() -> String:
	set_locale(LOCALE_EN if _locale != LOCALE_EN else LOCALE_ZH_CN, true)
	return _locale


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


## 读回上次选择的语言。文件不存在 = 首次运行，不是错误（02 §9：先分清「没有」与「坏了」）。
func _load_locale() -> void:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SETTINGS_PATH)
	if error == ERR_FILE_NOT_FOUND:
		return
	if error != OK:
		push_error("Settings: 无法读取 %s（错误码 %d），本次沿用系统语言。" % [SETTINGS_PATH, error])
		return
	# 磁盘是外部输入，取值必须校验（02 §9）：设置文件可能被手改、或语言被下架。
	var saved: String = String(config.get_value(SETTINGS_SECTION, FIELD_LOCALE, ""))
	if saved.is_empty():
		return
	if not SUPPORTED_LOCALES.has(saved):
		push_error("Settings: 设置文件里的语言 '%s' 不在支持列表内，已忽略。" % saved)
		return
	if saved == _locale:
		return
	_locale = saved
	_apply_locale()


## 存盘失败不中断游戏（设置服务不该因为磁盘问题让游戏起不来）：报错，内存值保持不变。
func _save_locale() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.set_value(SETTINGS_SECTION, FIELD_LOCALE, _locale)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Settings: 无法写入 %s（错误码 %d），本次选择重启后不保留。" % [SETTINGS_PATH, error])


func _emit_changed(key: StringName) -> void:
	setting_changed.emit(key)
