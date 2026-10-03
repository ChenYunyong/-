## combat_probe.gd
## 职责：COMBAT 战场 / 状态带分界与上沿的像素取证（09 §4）—— 证明 06 §8 的「上沿 1px NAVY_600 分隔、
##       底色 NAVY_800、横贯全宽」是**真的画在** y=135 这条线上，而不是「字段等于多少」。
## 所属系统：tests（09 §4 像素探针的 S1-08 用例模块）
## 依赖：Palette, assets/ui/theme_main.tres, scenes/combat/combat.tscn
## 禁止：不得加 --headless 运行（dummy 渲染驱动不产像素）；
##       不得写任何字面色值 —— 判据一律取自 Palette。
##
## 拆分理由：聚合入口 run_render_probes.gd 已用到 284/300 行（02 §4），
## 按 09 §4 v0.1.3 的先例把 S1-08 的用例拆成模块，聚合入口只留一次调用。
##
## 判别力（09 §4：每条断言都要能被一次「故意改坏」打红）：
##   反向对照一 —— 把状态带整体上移 4px，分界必须跟着移到 y=131、y=135 必须不再是上沿。
##                 量不到这个位移，就说明断言只是在「某处找一条深色线」，证明不了它落在 135。
##   反向对照二 —— 藏掉 StatusEdge，全图 NAVY_600 必须归零。
##   反向对照三 —— 藏掉 StatusFill，状态带内的 NAVY_800 必须归零。
##
## 分工：本探针只量**宽屏**（06 §8 的实测档）。窄屏折叠是布局问题，
## 由 tests/unit/test_combat.gd 与 tests/integration/combat_smoke.gd 覆盖。

extends RefCounted

const SCENE_PATH: String = "res://scenes/combat/combat.tscn"

## 画布 = 06 §1 的 320×180 基准，与布局常量同一坐标系，于是「第几个像素」可以直接读。
const CANVAS: Vector2i = Vector2i(320, 180)
const VIEWPORT: Vector2 = Vector2(320.0, 180.0)

## 06 §8 实测的分界：状态带 y 135–180。上沿占第 135 行，填充从第 136 行起、到第 179 行止。
const BAND_TOP: int = 135
const BAND_FILL_TOP: int = 136
const BAND_BOTTOM: int = 179
## 反向对照的位移量。
const SHIFT: float = 4.0

var _h: RefCounted = null
var _tree: SceneTree = null
var _theme: Theme = null
var _scene: Control = null
var _band_fill: Color = Color.BLACK
var _band_edge: Color = Color.BLACK


## 由聚合入口调用。harness 与 tree 都是借来的 —— 计数直接记在同一个 harness 上，
## 于是退出码与总计数不必两处维护。
func run(tree: SceneTree, harness: RefCounted, theme: Theme) -> void:
	_tree = tree
	_h = harness
	_theme = theme
	_band_fill = Palette.get_color(Palette.Key.NAVY_800)
	_band_edge = Palette.get_color(Palette.Key.NAVY_600)

	print("")
	print("=== 组 8：COMBAT 战场 / 状态带分界与上沿（06 §8 像素取证）===")
	print("  判据色：带上沿=NAVY_600%s 带底色=NAVY_800%s" % [
		_h.color_text(_band_edge), _h.color_text(_band_fill),
	])
	await _probe_band()
	await _probe_shift()
	await _probe_layers()


## 组 8：分界行、上沿厚度、带的四边与底色。
func _probe_band() -> void:
	_h.reset()
	var image: Image = await _open_scene()
	if image == null:
		return

	_assert_scanlines(image, BAND_TOP, "状态带上沿")
	# 上沿**只有 1px**：分界的上一行与下一行都不该是 NAVY_600。
	_h.check(_h.count_row(image, BAND_TOP - 1, 0, CANVAS.x, _band_edge) == 0,
		"分界上一行 y=%d 不得是 NAVY_600（上沿只占一行）" % (BAND_TOP - 1))
	_h.check(_h.count_row(image, BAND_FILL_TOP, 0, CANVAS.x, _band_edge) == 0,
		"分界下一行 y=%d 不得是 NAVY_600（上沿只占一行）" % BAND_FILL_TOP)
	# 「只有这一条」——整幅画面上别处不许再漏出 NAVY_600。
	_h.check(_count_all(image, _band_edge) == CANVAS.x,
		"整幅画面的 NAVY_600 应恰好等于这条上沿的长度 %d（实际 %d）" % [
			CANVAS.x, _count_all(image, _band_edge)])

	# 战场侧：状态带的两种色一点都不能越界到 y<135。
	_h.check(_count_range(image, 0, BAND_TOP, _band_fill) == 0,
		"战场区域（y 0–%d）内不得出现 NAVY_800（实际 %d）" % [
			BAND_TOP - 1, _count_range(image, 0, BAND_TOP, _band_fill)])
	# 状态带侧：NAVY_600 只在上沿那一行，带内其余部分不许再出现。
	_h.check(_count_range(image, BAND_FILL_TOP, CANVAS.y, _band_edge) == 0,
		"状态带体内（y %d–%d）不得出现 NAVY_600（实际 %d）" % [
			BAND_FILL_TOP, BAND_BOTTOM, _count_range(image, BAND_FILL_TOP, CANVAS.y, _band_edge)])

	# 06 §8：横贯全宽、贴到画面底，且左 / 下缘没有第三条描边（§8 只规定了上沿 1px）。
	_h.check(_h.count_col(image, 0, BAND_FILL_TOP, CANVAS.y, _band_fill) == CANVAS.y - BAND_FILL_TOP,
		"状态带左缘 x=0 应整列是 NAVY_800（左缘无描边）")
	_h.check(_h.count_col(image, CANVAS.x - 1, BAND_FILL_TOP, CANVAS.y, _band_fill) == CANVAS.y - BAND_FILL_TOP,
		"状态带右缘 x=%d 应整列是 NAVY_800（右缘无描边）" % (CANVAS.x - 1))
	_h.check(_h.count_row(image, BAND_BOTTOM, 0, CANVAS.x, _band_fill) == CANVAS.x,
		"状态带底边 y=%d 应整行是 NAVY_800（底缘无描边）" % BAND_BOTTOM)


## 反向对照一：状态带整体上移 4px，分界必须跟着走。
## 这条把「探针读的是确切那一行」和「那条线确实由状态带的位置决定」一起钉死：
## 若探针只是在某处找一条深色线，位移之后它仍然会绿。
func _probe_shift() -> void:
	_h.check(_scene != null, "应有已装载的 COMBAT 场景")
	if _scene == null:
		return
	var bar: Control = _scene.find_child("StatusBar", true, false) as Control
	if not _h.check(bar != null, "场景应有 StatusBar 容器"):
		return

	var origin: Vector2 = bar.position
	bar.position = Vector2(origin.x, origin.y - SHIFT)
	var image: Image = (await _h.settle())["image"]
	if image == null:
		return
	_assert_scanlines(image, BAND_TOP - int(SHIFT), "反向对照：状态带上移 4px 后")
	_h.check(_h.count_row(image, BAND_TOP, 0, CANVAS.x, _band_edge) == 0,
		"反向对照：上移后原来的 y=%d 不该再有 NAVY_600" % BAND_TOP)
	_h.check(_count_range(image, CANVAS.y - int(SHIFT), CANVAS.y, _band_fill) == 0,
		"反向对照：上移后画面最底部 %d 行不该再有 NAVY_800（带已经跟着走了）" % int(SHIFT))
	bar.position = origin


## 反向对照二 / 三：藏掉上沿 → 判据色归零；藏掉底色 → 带内 NAVY_800 归零。
## 归零失败就说明组 8 数到的像素并非来自这两层，本组没有判别力。
func _probe_layers() -> void:
	if _scene == null:
		return
	var edge: Node = _scene.find_child("StatusEdge", true, false)
	var fill: Node = _scene.find_child("StatusFill", true, false)
	if not _h.check(edge != null and fill != null, "场景应有 StatusEdge 与 StatusFill 两层"):
		return

	edge.set(&"visible", false)
	var control: Image = (await _h.settle())["image"]
	if control == null:
		return
	_h.check(_count_all(control, _band_edge) == 0,
		"反向对照：藏掉上沿后全图 NAVY_600 应归零（实际 %d）" % _count_all(control, _band_edge))
	edge.set(&"visible", true)

	fill.set(&"visible", false)
	control = (await _h.settle())["image"]
	if control == null:
		return
	_h.check(_count_range(control, BAND_FILL_TOP, CANVAS.y, _band_fill) == 0,
		"反向对照：藏掉底色后带内 NAVY_800 应归零（实际 %d）" % _count_range(control, BAND_FILL_TOP, CANVAS.y, _band_fill))
	# 上沿与底色是两层：藏掉底色不该把上沿一起带走，否则「1px 分隔」这条就无从谈起。
	_h.check(_h.count_row(control, BAND_TOP, 0, CANVAS.x, _band_edge) == CANVAS.x,
		"反向对照：藏掉底色后上沿仍应是整条 %d px" % CANVAS.x)
	fill.set(&"visible", true)


## 「第 y 行整行都是 wanted」——分界行与反向对照后的新分界行共用同一条断言。
func _assert_scanlines(image: Image, edge_row: int, label: String) -> void:
	_h.check(_h.count_row(image, edge_row, 0, CANVAS.x, _band_edge) == CANVAS.x,
		"%s：第 %d 行应是整条 %d px 的 NAVY_600" % [label, edge_row, CANVAS.x])
	_h.check(_h.count_col(image, CANVAS.x / 2, edge_row, edge_row + 1, _band_edge) == 1,
		"%s：任一列在第 %d 行应恰好 1 个 NAVY_600（上沿厚 1px）" % [label, edge_row])


## 把 combat.tscn 挂上画布、按 320×180 落一次布局，再取像素。
## 显式调 apply_layout_for 而不是依赖画布尺寸推断 —— 探针要证的是「布局画在哪」，
## 折叠与否这件事已由 test_combat.gd 单独覆盖，这里把它钉死在宽屏档。
func _open_scene() -> Image:
	var packed: PackedScene = load(SCENE_PATH)
	if not _h.check(packed != null, "combat.tscn 应能加载"):
		return null
	_h.set_canvas_size(CANVAS)
	_scene = packed.instantiate()
	_scene.theme = _theme
	_h.adopt(_scene)
	await _h.settle()
	_scene.size = VIEWPORT
	_scene.call(&"apply_layout_for", VIEWPORT)
	return (await _h.settle())["image"]


func _count_all(image: Image, wanted: Color) -> int:
	return _count_range(image, 0, image.get_size().y, wanted)


## 逐行累计判据色像素数。[from_y, to_y) 半开区间。
func _count_range(image: Image, from_y: int, to_y: int, wanted: Color) -> int:
	var total: int = 0
	for y: int in range(from_y, to_y):
		total += _h.count_row(image, y, 0, image.get_size().x, wanted)
	return total
