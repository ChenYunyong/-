## capture_screens.gd
## 职责：六场景「同屏对照截图」取证工具（PET-77 验收要求 —— 每屏一组 640×360 原生 + 4× 最近邻放大）。
##       取的是根视口**真实画出来的**那一帧（同 blueprint_smoke 的取像方式），不是自己重画的示意图。
## 所属系统：tests（取证工具 —— 与 run_render_probes.gd 同类，故同样不挂进 run_tests.gd 常规回归）
## 依赖：六个 .tscn
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得引用 Autoload 标识符或 class_name 全局 —— 本文件是 --script 入口，
##       在工程注册这些全局之前就被编译（同 blueprint_smoke.gd 的理由），一律走 res:// 路径加载。
##
## 运行：**必须** `--resolution 640x360`，且**不得 headless**。
##   <godot> --path <repo> --resolution 640x360 --script res://tests/unit/capture_screens.gd -- --tag before
## 产物：tests/output/screens_<tag>_<key>.png（640×360 原生）
##       tests/output/screens_<tag>_<key>_4x.png（2560×1440，最近邻，不引入插值假色）
##
## PET-80：基准画布 320×180 → 640×360，故窗口尺寸随之翻倍、放大图也随之外框翻倍。
## ZOOM 保持 4×不变 —— 验收要的正是「4× 最近邻」下依然锐利这张证据。
##
## 为什么放大用 INTERPOLATE_NEAREST：05_ART_STYLE 规定像素风禁用线性过滤。
## 放大图只用于肉眼看轮廓，若用双线性会把「1px 描边」糊成灰边，反而看不出接入是否生效。

extends SceneTree

const OUT_DIR: String = "res://tests/output/"
## 06 §1 基准 640×360（PET-80 前 320×180）。窗口尺寸必须与之相等，
## 否则 content_scale 会整体缩放，截出来的不是原生帧。
const DESIGN: Vector2i = Vector2i(640, 360)
## 证据图的最近邻放大倍率。PET-80 起窗口是 2× 整数放大，故 4× 是叠在窗口之上的再放大 ——
## 放大图只作肉眼核对，不参与任何断言。
const ZOOM: int = 4
## 等两帧再取像：场景 _ready() 里的布局与首帧重绘要落地（同 blueprint_smoke._run_screenshot_case）。
const SETTLE_FRAMES: int = 2

## 六屏，顺序即游戏推进顺序（03 §1）。
const SCREENS: Array[Dictionary] = [
	# BOOT 需要先空挂一次才会停在屏幕上，理由见 _warmup()。
	{"key": "boot", "path": "res://scenes/boot/boot.tscn", "warmup": true},
	# BOOT 的**成功**路径自己就是一块 NAVY_900 底 + 一个隐藏的错误面板（实测：整帧只有一种颜色），
	# 没有任何主题控件可看。它唯一会画出控件的地方是**自检失败**时的错误面板
	# （MessagePanel → 主面板外框切片），故这里喂一个不存在的 palette 路径把那条分支驱动起来。
	# 正式资产本不该坏，不注入就永远拿不到这条分支的实测证据（同 boot_scene_smoke 的做法）。
	{"key": "boot_error", "path": "res://scenes/boot/boot.tscn",
		"inject": {"palette_path": "res://tests/unit/fixtures/missing_asset.tres"}},
	{"key": "main_menu", "path": "res://scenes/menu/main_menu.tscn"},
	{"key": "preparation", "path": "res://scenes/preparation/preparation.tscn"},
	{"key": "combat", "path": "res://scenes/combat/combat.tscn"},
	{"key": "reward", "path": "res://scenes/reward/reward.tscn"},
	{"key": "result", "path": "res://scenes/result/result.tscn"},
]

var _tag: String = "before"
var _failed: int = 0


func _initialize() -> void:
	_tag = _parse_tag()
	print("CAPTURE 环境：Godot %s / 渲染驱动 %s / 窗口 %s / tag=%s" % [
		Engine.get_version_info()["string"],
		RenderingServer.get_video_adapter_name(),
		str(DisplayServer.window_get_size()),
		_tag,
	])
	if DisplayServer.window_get_size() != DESIGN:
		print("!! 窗口不是 %s —— 必须用 --resolution 640x360 且不得 headless，否则截到的不是原生帧。" % str(DESIGN))
		quit(1)
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for screen: Dictionary in SCREENS:
		if bool(screen.get("warmup", false)):
			await _warmup(String(screen["path"]))
		await _capture(screen)

	print("")
	print("CAPTURE 结论：成功 %d / 失败 %d（tag=%s）" % [SCREENS.size() - _failed, _failed, _tag])
	quit(0 if _failed == 0 else 1)


## BOOT 的成功路径在 `_ready()` 里就把 GameFlow 推离 BOOT —— GameFlow 随即换掉当前场景，
## 于是「挂上去、等两帧、取像」拿到的其实是 MAIN_MENU：实测 boot 与 main_menu 两张图**逐字节相同**，
## 也就是说按原写法 BOOT 这一屏根本没被取到过，交上去会变成拿同一张图冒充两屏。
##
## 取真帧的办法借 BOOT 自己的守卫（`boot_screen._hand_off_to_game_flow()` 里的
## `if not GameFlow.is_state(BOOT): return`）：先空挂一次，让状态被推走（这一帧丢掉、不存），
## 再正式挂第二次 —— 此时 GameFlow 已不是 BOOT，交棒被拒，BOOT 画面就停在屏幕上，可以安稳取像。
## 全程只走场景自己的公开逻辑，不改任何场景代码，也不碰 GameFlow 的内部字段。
func _warmup(path: String) -> void:
	var packed: PackedScene = load(path)
	if packed == null:
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		return
	root.add_child(scene)
	for _i: int in SETTLE_FRAMES:
		await process_frame
	root.remove_child(scene)
	scene.free()
	await process_frame


## 逐屏取像：实例化 → 挂到 /root → 等重绘 → 取根视口纹理 → 存原生图与 4× 最近邻放大图。
func _capture(entry: Dictionary) -> void:
	var key: String = String(entry["key"])
	var path: String = String(entry["path"])
	var packed: PackedScene = load(path)
	if packed == null:
		print("[FAIL] %s：%s 加载失败" % [key, path])
		_failed += 1
		return
	var scene: Node = packed.instantiate()
	if scene == null:
		print("[FAIL] %s：实例化失败" % key)
		_failed += 1
		return
	# 注入式入口（如 BOOT 的失败分支）：必须在 add_child（即 _ready()）之前落定。
	var inject: Dictionary = entry.get("inject", {})
	for prop: String in inject:
		scene.set(StringName(prop), inject[prop])
	root.add_child(scene)
	for _i: int in SETTLE_FRAMES:
		await process_frame

	var image: Image = root.get_texture().get_image()
	if image == null:
		print("[FAIL] %s：取不到根视口渲染结果（是否误加了 --headless？）" % key)
	else:
		_save(image, key)

	root.remove_child(scene)
	scene.free()
	await process_frame


## 存两张：原生帧 + 最近邻放大帧。放大帧的每个像素都是原生帧的整块复制，不引入新颜色。
func _save(image: Image, key: String) -> void:
	var native_path: String = OUT_DIR + "screens_%s_%s.png" % [_tag, key]
	var zoom_path: String = OUT_DIR + "screens_%s_%s_%dx.png" % [_tag, key, ZOOM]
	var native_ok: bool = image.save_png(native_path) == OK

	var big: Image = Image.new()
	big.copy_from(image)
	big.resize(image.get_width() * ZOOM, image.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	var zoom_ok: bool = big.save_png(zoom_path) == OK

	# 原生帧必须是设计尺寸 —— 否则「同屏对照」的两张图不同基准，比较无意义。
	var size_ok: bool = image.get_width() == DESIGN.x and image.get_height() == DESIGN.y
	if native_ok and zoom_ok and size_ok:
		print("[OK] %s：%s（%dx%d）+ %s（%dx%d）" % [
			key, native_path, image.get_width(), image.get_height(),
			zoom_path, big.get_width(), big.get_height(),
		])
	else:
		print("[FAIL] %s：native=%s zoom=%s 原生尺寸=%dx%d（应为 %dx%d）" % [
			key, str(native_ok), str(zoom_ok), image.get_width(), image.get_height(), DESIGN.x, DESIGN.y,
		])
		_failed += 1


## `--` 之后的 `--tag <值>`；缺省 before，便于「接入前 / 接入后」两组产物不互相覆盖。
func _parse_tag() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		if args[index] == "--tag" and index + 1 < args.size():
			return args[index + 1]
	return "before"
