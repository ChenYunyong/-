## web_export_smoke.gd
## 职责：Web 导出产物的**产物层**冒烟（09 §1 集成层）—— 独立进程跑，只读 `build/web/` 下的文件，
##       不启场景、不进 GameFlow：它证明的是「导出确实产出了这些东西、且 index.html 真的指着它们」，
##       **不**证明「浏览器里跑得起来」（本卡没有浏览器自动化，见文件末尾的验证边界）。
## 所属系统：tests（集成层，单独进程运行）
## 依赖：test_context
## 禁止：本文件不得引用 Autoload 标识符，也不得引用 class_name 全局 —— 它是 --script 入口，
##       在工程注册这些全局标识之前就被编译（同 run_tests.gd / input_smoke.gd 的约束）；
##       不得写入 / 删除 / 移动任何产物 —— 反向对照由**外部改坏产物 + 重跑本文件**完成，
##       本文件自己只读，保证「改坏前绿、改坏后红」的因果不被测试自己污染。
##
## 产物命名不是 `godot.js` / `godot.wasm`：Godot 按**导出路径的基名**命名，
## 导出到 `build/web/index.html` 就得到 `index.js` / `index.wasm` / `index.pck`。
## 本文件钉住的是**实测出来的**名字，而不是任务卡里那个猜测的名字。

extends SceneTree

const CONTEXT_PATH: String = "res://tests/unit/test_context.gd"
## 产物目录。导出预设里写的是相对路径 `build/web/index.html`，相对项目根解析 →
## `D:\GameDev\PixelFusion\build\web\`（该目录是到 E: 的联接，属 01 §11 的 E 盘产物层）。
const BUILD_DIR: String = "res://build/web"
const HTML_NAME: String = "index.html"
const PCK_NAME: String = "index.pck"
const LOG_PATH: String = "res://tests/output/web_export_smoke.log"
const TASK_LABEL: String = "S1-13（PET-57）/ PET-58 件 ④ Web 导出冒烟验证"

## 产物清单：文件名 + 最小合理体积（字节）+ 该下限的来由。
## 下限刻意压到实测值的 1/3 以下 —— 它要抓的是「文件没了 / 被截断 / 换成了别的东西」，
## 不是钉死一个精确体积（引擎或代码一变就会变成假红）。
const EXPECTED_PRODUCTS: Array[Dictionary] = [
	{"name": "index.html", "min_size": 1024, "why": "HTML 外壳（实测 5441）"},
	{"name": "index.js", "min_size": 100000, "why": "Emscripten 胶水（实测 358342）"},
	{"name": "index.wasm", "min_size": 10000000, "why": "引擎 wasm，量级数十 MB（实测 38347038）"},
	{"name": "index.pck", "min_size": 1, "why": "资源包，任务卡要求非 0 字节（PET-58 件 ④ 排除后实测 95712）"},
]

## index.html 文本里必须出现的引用。第 1 条是 <script> 标签（浏览器据此加载引擎）；
## 第 2、3 条在导出器内联的 GODOT_CONFIG.fileSizes 里 —— 那是引擎运行时的取件清单。
const REQUIRED_HTML_REFS: Array[String] = [
	"<script src=\"index.js\"></script>",
	"\"index.wasm\"",
	"\"index.pck\"",
]

## 任务卡要求 preset 的 Thread Support = true。配置项本身不算证据（09 §4），
## 故这里断言的是**产物文本**里的开关真的为 true —— 它是引擎决定要不要 pthread 的唯一依据。
const THREADS_MARKER: String = "const GODOT_THREADS_ENABLED = true;"

## 判别力自证用的假名字：它必须被判为「不存在」，否则存在性检查恒真。
const BOGUS_PRODUCT: String = "index_not_exported.wasm"

## PET-58 件 ④：pck 的**目录索引是明文路径串**，故可直接搜字节。
##
## 下列串是「非运行时目录被卷进包」的判据，一律**不带 `res://` 前缀** ——
## 索引里同一条路径会出现两种写法（`res://tests/x.gd` 与 remap 表里的 `tests/x.gd.remap`），
## 不带前缀的串两种都能命中，带前缀的只能命中前一种。
##
## 各条在本工程的可观测性（决定反向对照时谁会真的变红）：
##   build/web/       **可观测**。导出产物落在 res:// 内，一次 --import 会在 build/web/ 生成
##                    .import 旁挂文件，下一次导出就把上一轮的 png/import 一起包进来
##                    （PET-57 实测 pck 364340 → 388432，+24092，且逐轮增长）。
##   .godot/imported/ **可观测**。上一条那些 png 被导入后生成的 .ctex 缓存。
##   tests/           **可观测**。未排除时实测 75 条引用（.gd / .gdc / .gd.remap）。
##   tools/godot/     预防性。本工程 tools/ 下只有 3 个 .py（不是资源，本就不会被扫进来），
##                    真实的 tools/godot/editor_data/*.tres 只在 D:\GameDev\PixelFusion 存在，
##                    PET-57 在那里实测到 2 条 res://tools/ 引用（含用户既有的编辑器设置）。
##   docs/            预防性。.md 本就不被 all_resources 认作资源，排除是把策略写死。
##   assets/_review/  预防性。07_ASSET_PIPELINE 的送审暂存区，今天还没有素材进去。
const FORBIDDEN_PCK_MARKERS: PackedStringArray = [
	"build/web/",
	".godot/imported/",
	"tests/",
	"tools/godot/",
	"docs/",
	"assets/_review/",
]

## 排除**过头**比泄漏更糟 —— 它会把运行时真正要用的东西一起扫掉，而产物仍然「导出成功」。
## 故这一组必须仍然**出现**在 pck 里，作为「过滤只减了份量、没减功能」的正面证据。
##
## ⚠ 与任务卡的一处**受测事实修正**：卡里写「不得出现 `res://.godot/`」，但实测（Godot 4.7.1）
## 正确导出的 pck 里**必然**有 `res://.godot/exported/<N>/export-<md5>-<name>.scn`
## —— 那是导出器自己的转换产物（场景转 .scn、资源转 .res 后存这里，remap 表再指回原路径），
## **不是**本地缓存。一刀切禁 `res://.godot/` 会让断言在正确实现下也恒红。
## 故禁的是 `.godot/` 下**除 exported/ 外**的缓存面；`.godot/` 本来就不带前缀出现在索引里
## （见 FORBIDDEN_PCK_MARKERS 的说明），所以这里也用不带前缀的写法。
const REQUIRED_PCK_MARKERS: PackedStringArray = [
	"res://scripts/",                        # GDScript 本体
	"res://scenes/",                         # 场景源
	"res://.godot/exported/",                # 导出器的转换产物，必须留
	".godot/global_script_class_cache.cfg",  # 运行时靠它解析 class_name
	".godot/uid_cache.bin",
]
## 判别力自证用的假路径串：扫描函数必须判它「不存在」，否则上面那些「不得出现」恒真。
const BOGUS_PCK_MARKER: String = "res://definitely_not_packed_9f3a/"

## 本文件全部用例跑完应有的断言条数（PET-58 件 ④ 后实测 36）。少一条就说明某个用例中途没跑完 —— 见 _finish()。
const MIN_ASSERTIONS: int = 33

var _ctx: RefCounted = null
var _lines: Array[String] = []


func _initialize() -> void:
	_ctx = load(CONTEXT_PATH).new()
	var html: String = _read_text(BUILD_DIR.path_join(HTML_NAME))
	_check_products()
	_check_html_references(html)
	_check_pack_exclusions(_read_pck_bytes())
	_check_discrimination(html)
	_finish()


## 交付物 3 前半：四个产物都在，且体积合理。
func _check_products() -> void:
	_ctx.begin_case("Web 导出冒烟 · 产物存在且大小合理")
	if not _ctx.check(DirAccess.open(BUILD_DIR) != null, "产物目录应存在：%s" % BUILD_DIR):
		return
	for product: Dictionary in EXPECTED_PRODUCTS:
		var name: String = String(product["name"])
		var size: int = _size_of(BUILD_DIR.path_join(name))
		var floor_bytes: int = int(product["min_size"])
		if not _ctx.check(size >= 0, "%s 应存在（%s）" % [name, String(product["why"])]):
			continue
		_ctx.check(size >= floor_bytes,
			"%s 体积应 ≥ %d 字节（实际 %d）—— %s" % [name, floor_bytes, size, String(product["why"])])


## 交付物 3 后半：index.html 的**文本**确实引用了 js / wasm / pck，且引用的体积与磁盘一致。
## 后半条把「文本里出现了某个字符串」升级成「文本与磁盘对得上」——
## 一个被截断成 0 字节的产物会在这里翻车，而不是只在体积断言上翻一次。
func _check_html_references(html: String) -> void:
	_ctx.begin_case("Web 导出冒烟 · index.html 文本确实引用产物")
	if not _ctx.check(not html.is_empty(), "%s 应可读且非空" % HTML_NAME):
		return
	for reference: String in REQUIRED_HTML_REFS:
		_ctx.check(html.contains(reference), "index.html 应引用 %s" % reference)
	_ctx.check(html.contains(THREADS_MARKER),
		"index.html 应写着 %s（preset 的 Thread Support 真的落到了产物上）" % THREADS_MARKER)

	_ctx.begin_case("Web 导出冒烟 · index.html 声明的体积与磁盘一致")
	var sizes: Dictionary = _declared_file_sizes(html)
	if not _ctx.check(not sizes.is_empty(), "index.html 的 GODOT_CONFIG.fileSizes 应可解析且非空"):
		return
	for declared_name: Variant in sizes:
		var name: String = String(declared_name)
		var declared: int = int(sizes[declared_name])
		var actual: int = _size_of(BUILD_DIR.path_join(name))
		if not _ctx.check(actual >= 0, "index.html 声明的 %s 应真的存在于产物目录" % name):
			continue
		_ctx.equal(actual, declared, "%s 的磁盘体积应与 index.html 声明的一致" % name)


## PET-58 件 ④：pck 里该有的在、不该有的不在。
##
## 「该有的在」不是凑数 —— 它和「不该有的不在」互相兜底：一个恒真的扫描会让前半组全红，
## 一个恒假的扫描会让后半组全红，两者都在就不可能同时全绿。这也顺带证明
## `export_presets.cfg` 的 exclude_filter 没把运行时资源误伤掉。
func _check_pack_exclusions(pck: PackedByteArray) -> void:
	_ctx.begin_case("Web 导出冒烟 · pck 不得卷入非运行时目录（PET-58 件 ④）")
	if not _ctx.check(pck.size() > 0,
			"%s 应可读且非空（目录索引是明文路径串，可直接搜字节）" % PCK_NAME):
		return
	for marker: String in FORBIDDEN_PCK_MARKERS:
		_ctx.check(not _pck_has_marker(pck, marker),
			"%s 的路径索引里不得出现 %s —— 该目录不是运行时资源" % [PCK_NAME, marker])
	for marker: String in REQUIRED_PCK_MARKERS:
		_ctx.check(_pck_has_marker(pck, marker),
			"%s 里仍应保留 %s —— 排除过头会打断运行时，不只是瘦身" % [PCK_NAME, marker])


## 判别力自证（09 §4）：存在性 / 引用 / 体积 / pck 路径四类断言各配一次「换了就该判假」的自检。
## 缺了这一段，上面全绿也可能只是因为检查函数恒真。
func _check_discrimination(html: String) -> void:
	_ctx.begin_case("Web 导出冒烟 · 断言的判别力（不是恒真）")
	_ctx.equal(_size_of(BUILD_DIR.path_join(BOGUS_PRODUCT)), -1,
		"不存在的产物名必须判为不存在 —— 否则存在性检查恒真")
	_ctx.check(not html.contains(BOGUS_PRODUCT), "index.html 不应引用不存在的产物名")
	_ctx.check(not html.contains("const GODOT_THREADS_ENABLED = false;"),
		"线程开关的断言必须能区分 true / false —— 否则上面那条只是「字符串在不在」")
	_ctx.check(not _pck_has_marker(_read_pck_bytes(), BOGUS_PCK_MARKER),
		"pck 扫描必须判「不存在的路径串」为不存在 —— 否则件 ④ 那组断言恒绿")


## 文件字节数。不存在或打不开返回 -1（区别于「存在但为 0 字节」）。
func _size_of(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var size: int = int(file.get_length())
	file.close()
	return size


## pck 整包按字节读出（文件头是 `GDPC` 魔数，目录索引就在前半段）。
##
## 走**字节**而不是先转 String：pck 里混着二进制载荷，
## `get_string_from_ascii()` 实测在第一个 NUL 处就截断了（转换后只剩几十字节），
## 于是每条「不得出现」都恒绿 —— 一个恒真的空扫描。字节比较没有这个失真。
func _read_pck_bytes() -> PackedByteArray:
	var file: FileAccess = FileAccess.open(BUILD_DIR.path_join(PCK_NAME), FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(int(file.get_length()))
	file.close()
	return bytes


## 在整包字节里找一段 ASCII 路径串。
##
## 用原生 `PackedByteArray.find()`（底层是 memchr）逐个跳候选位置，而不是在 GDScript 里
## 逐字节 for —— 反向对照时包有 3.6 MB，逐字节循环会慢到让冒烟变成一次等待。
## 首字节命中后再比末字节、最后才进内层循环，绝大多数候选在第一跳就被排除。
func _pck_has_marker(pck: PackedByteArray, marker: String) -> bool:
	var pattern: PackedByteArray = marker.to_ascii_buffer()
	var length: int = pattern.size()
	if length == 0:
		return true
	var last_start: int = pck.size() - length
	if last_start < 0:
		return false
	var head: int = pattern[0]
	var tail: int = pattern[length - 1]
	var at: int = pck.find(head, 0)
	while at >= 0 and at <= last_start:
		if pck[at + length - 1] == tail:
			var matched: bool = true
			for offset: int in range(1, length - 1):
				if pck[at + offset] != pattern[offset]:
					matched = false
					break
			if matched:
				return true
		at = pck.find(head, at + 1)
	return false


## 读文本文件。读不到返回空串。
func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


## 从 index.html 里取出导出器内联的 GODOT_CONFIG（引擎的加载参数逐字写在这个 JSON 里）。
## 取不到或不是字典时返回空字典 —— 调用方据此判红，而不是猜一个默认值糊过去。
func _declared_file_sizes(html: String) -> Dictionary:
	const MARKER: String = "const GODOT_CONFIG = "
	var start: int = html.find(MARKER)
	if start < 0:
		return {}
	var end: int = html.find("\n", start)
	if end < 0:
		return {}
	var line: String = html.substr(start + MARKER.length(), end - start - MARKER.length()).strip_edges()
	if line.ends_with(";"):
		line = line.substr(0, line.length() - 1)
	var parsed: Variant = JSON.parse_string(line)
	if not parsed is Dictionary:
		return {}
	var sizes: Variant = (parsed as Dictionary).get("fileSizes")
	return sizes if sizes is Dictionary else {}


## 本文件**不覆盖**的部分，写在这里而不是留在人脑里：
## 产物齐全 + index.html 引用正确 ≠ 浏览器里跑得起来。本卡没有浏览器自动化，
## 因此「BOOT 场景出现 / 能点到 MAIN_MENU」必须由人按下面的清单在真浏览器里确认：
##   1. 用**带 COOP/COEP 响应头**的本地服务打开 index.html（threads 模式需要 cross-origin isolation）；
##      注意本次导出 `progressive_web_app/enabled=false`，GODOT_CONFIG 里**没有** serviceWorker 键，
##      即引擎自带的 service-worker 兜底路径不会生效 —— 响应头只能由服务器给。
##   2. 打开后确认无 "The following features required to run Godot projects on the Web are missing" 提示。
##   3. 确认 BOOT 场景出现（数据校验通过），并自动路由到 MAIN_MENU。
##   4. 在 MAIN_MENU 点得到「开始」→ PREPARATION。
func _finish() -> void:
	# 覆盖度下限：某个用例中途返回会让后面的断言**一条都不跑**，而报告仍然是「失败项：无」——
	# 那不是通过，是没跑（同 input_smoke.gd / test_state_loop.gd 的 MIN_ASSERTIONS）。
	_ctx.begin_case("Web 导出冒烟 · 覆盖度下限")
	_ctx.check(_ctx.total() >= MIN_ASSERTIONS,
		"断言条数应 ≥ %d（实际 %d）—— 低于此数说明有用例中途没跑完" % [MIN_ASSERTIONS, _ctx.total()])

	var version: Dictionary = Engine.get_version_info()
	_lines.append("TEST REPORT")
	_lines.append("- 任务：%s" % TASK_LABEL)
	_lines.append("- 环境：Godot %s / Windows / 窗口 %dx%d" % [
		version["string"], DisplayServer.window_get_size().x, DisplayServer.window_get_size().y,
	])
	_lines.append("- 单元测试：见 unit_tests.log")
	_lines.append("- 集成测试：见 unit_tests.log")
	_lines.append("- 产物冒烟：%d/%d" % [_ctx.passed, _ctx.passed + _ctx.failed])
	_lines.append("- 手动场景：无（本文件只读产物，不启场景；浏览器侧留给人工清单）")
	if _ctx.failures.is_empty():
		_lines.append("- 失败项：无")
	else:
		_lines.append("- 失败项：%d 条" % _ctx.failures.size())
		for failure: String in _ctx.failures:
			_lines.append("    · %s" % failure)
	_lines.append("- 输出文件：D:\\GameDev\\PixelFusion\\tests\\output\\web_export_smoke.log")

	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_error("web_export_smoke: 无法写入 %s。" % LOG_PATH)
	else:
		for line: String in _lines:
			file.store_line(line)
		file.close()
	for line: String in _lines:
		print(line)
	quit(0 if _ctx.failed == 0 else 1)
