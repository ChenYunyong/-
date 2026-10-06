## test_main_menu.gd
## 职责：MAIN_MENU 场景的**静态装配**是否落在 03 §1.1 / 06 §2.2 / §3 / §6 的规格上
##       （路由登记、面板三层几何、标题栏、按钮文案与 Disabled 态、无字面色值）。
## 所属系统：tests
## 依赖：test_context
## 禁止：本文件不得硬编码色值；不得依赖执行顺序。
##
## 分工：本用例只查「场景装配成了什么」，**不查交互**（进树后的路由、提示、像素）。
## 那些要真实 GameFlow 与渲染，归 tests/integration/main_menu_smoke.gd 独立进程。
## 这里用 instantiate() 但不入树 —— 不入树就不触发 _ready()，也就不会惊动 GameFlow。

extends RefCounted

const MENU_SCENE_PATH: String = "res://scenes/menu/main_menu.tscn"
const MENU_SCRIPT_PATH: String = "res://scripts/ui/main_menu.gd"
const TITLE_BAR_SCRIPT_PATH: String = "res://scripts/ui/panel_title_bar.gd"
const GAME_FLOW_SCRIPT_PATH: String = "res://scripts/core/game_flow.gd"
const THEME_SCRIPT_PATH: String = "res://scripts/data/palette_theme.gd"

## 06 §2.2：6px 外框 + 24px 内容边距（PET-80 前 3px + 12px）。
const EXPECTED_BODY_INSET: float = 30.0

## 06 §1 基准视口 **640×360**（PET-80 前 320×180）。13 §3.3 的「不得成为视觉中心」
## 需要一个可量的落点，本文件只用它的下半幅。
const REFERENCE_VIEWPORT: Vector2 = Vector2(640.0, 360.0)

## 06 §1 的安全区边界：基准尺寸各减一圈安全边距（PET-80 前 320−8 / 180−8）。
const SAFE_INSET: float = 16.0


func run(ctx: RefCounted, _tree: SceneTree) -> void:
	_run_route_checks(ctx)
	_run_source_checks(ctx)

	var resource: Resource = ResourceLoader.load(MENU_SCENE_PATH)
	if not ctx.check(resource is PackedScene, "main_menu.tscn 应能加载为 PackedScene"):
		return
	_run_structure_checks(ctx, resource)


## 场景必须由 GameFlow 的路由表指到，否则 03 §1.1 R3 的唯一路由来源就断在这条边上。
func _run_route_checks(ctx: RefCounted) -> void:
	ctx.begin_case("MAIN_MENU · 路由登记（03 §1.1 R3）")
	var flow_script: GDScript = load(GAME_FLOW_SCRIPT_PATH)
	if not ctx.check(flow_script != null, "game_flow.gd 应能加载"):
		return
	var route: Variant = flow_script.SCENE_ROUTES.get(flow_script.GameState.MAIN_MENU, null)
	if not ctx.check(route != null, "GameFlow 应登记 MAIN_MENU 的路由"):
		return
	ctx.equal(String(route["path"]), MENU_SCENE_PATH, "MAIN_MENU 路由路径")
	ctx.equal(String(route["task"]), "S1-06", "MAIN_MENU 路由归属任务")
	ctx.check(ResourceLoader.exists(MENU_SCENE_PATH), "路由指向的场景文件必须真实存在")


## 04 §6 / 06 §10.7：色值只能来自 Palette，脚本与场景都不得内嵌 Color(...)。
##
## 顺带钉一条编译检查：脚本编译失败时 .tscn 仍能实例化出节点，下面那些结构断言会**一片全绿**
## 而游戏里跑的是空脚本（S1-06 实测：全局类表缺 PanelTitleBar 时 main_menu.gd 编译不过，
## 本用例 497 条断言一声不响）。这条把「脚本挂了」从静默变成红。
func _run_source_checks(ctx: RefCounted) -> void:
	ctx.begin_case("MAIN_MENU · 无字面色值（06 §10.7）")
	for path: String in [MENU_SCRIPT_PATH, TITLE_BAR_SCRIPT_PATH, MENU_SCENE_PATH]:
		var source: String = FileAccess.get_file_as_string(path)
		if not ctx.check(not source.is_empty(), "%s 应能读取" % path):
			continue
		ctx.check(not source.contains("Color("), "%s 不得出现 Color(...) 字面量" % path)
	for path: String in [MENU_SCRIPT_PATH, TITLE_BAR_SCRIPT_PATH]:
		var script: GDScript = load(path)
		ctx.check(script != null and script.can_instantiate(), "%s 应能编译" % path)

	# 13 §3.1 / 任务卡：Logo 文案必须经翻译入口（无翻译表时原样返回，补表后中英可切换）。
	# 本文件 instantiate 而不入树，_ready() 不会跑，故这里查的是「接通了没有」——
	# 一条源码纪律断言，与上面那条 `Color(` 扫描同一种手法。
	ctx.begin_case("MAIN_MENU · Logo 文案经翻译入口（06 §11 / 13 §3.1）")
	ctx.check(FileAccess.get_file_as_string(MENU_SCRIPT_PATH).contains("_logo.text = translate_text(_logo.text)"),
		"Logo 文案应在 _ready() 里过一遍翻译入口")
	var menu_script: GDScript = load(MENU_SCRIPT_PATH)
	if ctx.check(menu_script != null, "main_menu.gd 应能加载"):
		ctx.equal(menu_script.translate_text("像素融合屋"), "像素融合屋",
			"没有翻译表时应原样返回原文（06 §11：中文原文即 key）")


func _run_structure_checks(ctx: RefCounted, packed: PackedScene) -> void:
	ctx.begin_case("MAIN_MENU · 面板三层与占位素材位")
	var menu: Node = packed.instantiate()
	if not ctx.check(menu != null, "main_menu.tscn 应能实例化"):
		return

	var panel: Control = _find(menu, "MenuPanel")
	if not ctx.check(panel != null, "应有 MenuPanel 容器"):
		menu.free()
		return

	_check_panel_layers(ctx, panel)
	_check_body_inset(ctx, panel)

	ctx.check(_find(menu, "TitleBar") != null, "菜单面板内应有标题栏组件")
	ctx.check(_find(menu, "NoticePanel") != null, "应有提示面板（「未实现」提示的落点）")

	_check_slots(ctx, menu)
	_check_buttons(ctx, menu)
	menu.free()


## 13 §3 对 MAIN_MENU 的三处结构裁定 + §2 的角色禁令，落成节点级断言：
##   §3.1 Logo 区强化成清晰的品牌位；§3.2 左侧构图区可保留、但只能当**可替换的装饰位**；
##   §3.3 右下信息框降级为版本 / 提示一类的辅助信息。
## 反向那半同样要钉：ArtSkyIsland / ArtGirl / ArtCat 是照参考图摆的三个具象物件
## （浮岛 / 少女 / 猫咪），13 §2 禁的「据参考图确立主角 / 猫咪吉祥物」唯一可能的来路就是它们。
func _check_slots(ctx: RefCounted, menu: Node) -> void:
	var theme_script: GDScript = load(THEME_SCRIPT_PATH)
	var panel: Control = _find(menu, "MenuPanel")

	for gone: String in ["ArtSkyIsland", "ArtGirl", "ArtCat"]:
		ctx.check(_find(menu, gone) == null,
			"%s 应已拆除（13 §2：不得据参考图确立主角 / 猫咪吉祥物）" % gone)

	var logo_slot: Control = _find(menu, "LogoSlot")
	if ctx.check(logo_slot != null, "应有 Logo 位 LogoSlot（13 §3.1）"):
		ctx.check(logo_slot is TextureRect, "LogoSlot 应是可替换的贴图位，而不是画死的形状")

	var slot: Control = _find(menu, "DecorationSlot")
	if ctx.check(slot != null, "应有左侧构图区 DecorationSlot（13 §3.2：构图区可保留）"):
		ctx.equal(slot.theme_type_variation, theme_script.TYPE_PANEL_CORE,
			"装饰位应落在既有面板变体上（本卡不新增控件样式）")
		var art: Control = _find(slot, "DecorationArt")
		if ctx.check(art != null, "装饰位内应有可替换的贴图位 DecorationArt"):
			ctx.check(art is TextureRect and art.get_parent() == slot, "DecorationArt 应是铺满装饰位的贴图位")
		# 06 §1：16px 安全区（PET-80 前 8px），左右分区不得互相压叠（13 §3：保留左右空间分区）。
		ctx.check(slot.offset_left >= SAFE_INSET and slot.offset_top >= SAFE_INSET,
			"装饰位应留在 16px 安全区内（实得 %.0f, %.0f）" % [slot.offset_left, slot.offset_top])
		ctx.check(slot.offset_right <= REFERENCE_VIEWPORT.x - SAFE_INSET
			and slot.offset_bottom <= REFERENCE_VIEWPORT.y - SAFE_INSET,
			"装饰位应留在 16px 安全区内（实得 %.0f, %.0f）" % [slot.offset_right, slot.offset_bottom])
		if panel != null:
			ctx.check(slot.offset_right <= panel.offset_left,
				"左侧构图区不得压到中央主菜单（右缘 %.0f ≤ 面板左缘 %.0f）" % [
					slot.offset_right, panel.offset_left])

	var version: Label = _find(menu, "VersionLabel")
	if ctx.check(version != null, "右下应有辅助信息位 VersionLabel（13 §3.3）"):
		ctx.equal(version.theme_type_variation, theme_script.TYPE_LABEL_SECONDARY,
			"辅助信息必须取次级文字色（13 §3.3：不得成为新的视觉中心）")
		ctx.check(not version.text.is_empty(), "辅助信息不得是空文本")
		ctx.equal(version.horizontal_alignment, HORIZONTAL_ALIGNMENT_RIGHT, "辅助信息应贴右下角")
		ctx.check(version.offset_top > REFERENCE_VIEWPORT.y * 0.5, "辅助信息应在下半幅，不得上浮到画面中心")
		if panel != null:
			ctx.check(version.offset_left >= panel.offset_right,
				"辅助信息应在菜单面板之外（左缘 %.0f ≥ 面板右缘 %.0f）" % [
					version.offset_left, panel.offset_right])


## 06 §2.1：外框 / 内芯 / 高光三层必须各自有 Theme 变体落点；内芯与外框内沿对齐，
## 高光层叠在内芯上（同框），硬阴影同样贴满整个面板矩形（右下 1px 由 expand_margin 推到矩形外）。
func _check_panel_layers(ctx: RefCounted, panel: Control) -> void:
	var theme_script: GDScript = load(THEME_SCRIPT_PATH)
	var expected: Dictionary = {
		"Shadow": theme_script.TYPE_PANEL_SHADOW,
		"Frame": theme_script.TYPE_PANEL_FRAME,
		"Core": theme_script.TYPE_PANEL_CORE,
		"Highlight": theme_script.TYPE_PANEL_HIGHLIGHT,
	}
	for layer_name: String in expected:
		var layer: Control = _find(panel, layer_name)
		if not ctx.check(layer != null, "菜单面板应有 %s 层" % layer_name):
			continue
		ctx.equal(layer.theme_type_variation, expected[layer_name], "%s 层的 Theme 变体" % layer_name)

	var frame: Control = _find(panel, "Frame")
	var core: Control = _find(panel, "Core")
	var highlight: Control = _find(panel, "Highlight")
	if frame == null or core == null or highlight == null:
		return

	var border: float = float(theme_script.FRAME_BORDER_WIDTH)
	for offset_name: String in ["offset_left", "offset_top", "offset_right", "offset_bottom"]:
		ctx.equal(frame.get(offset_name), 0.0, "外框 %s 应贴齐面板矩形" % offset_name)
	ctx.equal(core.offset_left, border, "内芯左边缩进 = 外框描边宽")
	ctx.equal(core.offset_top, border, "内芯上边缩进 = 外框描边宽")
	ctx.equal(core.offset_right, -border, "内芯右边缩进 = 外框描边宽")
	ctx.equal(core.offset_bottom, -border, "内芯下边缩进 = 外框描边宽")
	ctx.equal(highlight.offset_left, core.offset_left, "高光层与内芯同框（第三层叠在内芯上）")
	ctx.equal(highlight.offset_bottom, core.offset_bottom, "高光层与内芯同框（第三层叠在内芯上）")


## .tscn 里的 offset 只能是字面量，这里拿脚本按 Theme 常量算出的缩进来核对它 ——
## 两边一旦漂开，规格就不再是「一处定义」。
func _check_body_inset(ctx: RefCounted, panel: Control) -> void:
	var body: Control = _find(panel, "Body")
	if not ctx.check(body != null, "菜单面板内应有 Body 容器"):
		return
	var menu_script: GDScript = load(MENU_SCRIPT_PATH)
	ctx.equal(menu_script.PANEL_BODY_INSET, EXPECTED_BODY_INSET, "内容缩进 = 6px 外框 + 24px 边距（06 §2.2）")
	ctx.equal(body.offset_left, EXPECTED_BODY_INSET, "Body 左边缩进")
	ctx.equal(body.offset_top, EXPECTED_BODY_INSET, "Body 上边缩进")
	ctx.equal(body.offset_right, -EXPECTED_BODY_INSET, "Body 右边缩进")
	ctx.equal(body.offset_bottom, -EXPECTED_BODY_INSET, "Body 下边缩进")


## 「继续」Disabled、「设置 / 退出」标注未实现，都是验收里点名的**可见**结果，
## 故断言的是场景里写死的文案与状态，而不是脚本里有没有对应分支。
func _check_buttons(ctx: RefCounted, menu: Node) -> void:
	var start: Button = _find(menu, "ButtonStart")
	var resume: Button = _find(menu, "ButtonContinue")
	var settings: Button = _find(menu, "ButtonSettings")
	var quit: Button = _find(menu, "ButtonExit")
	if not ctx.check(start != null and resume != null and settings != null and quit != null,
			"四个按钮都应存在"):
		return

	ctx.equal(start.text, "开始", "开始按钮文案")
	ctx.equal(resume.text, "继续", "继续按钮文案")
	ctx.check(resume.disabled, "「继续」必须为 Disabled（无存档可续，06 §3 / 11 §8）")
	ctx.check(not start.disabled, "「开始」不得为 Disabled")
	ctx.check(settings.text.contains("未实现"), "「设置」文案应标注未实现（实际：%s）" % settings.text)
	ctx.check(quit.text.contains("未实现"), "「退出」文案应标注未实现（实际：%s）" % quit.text)

	var logo: Label = _find(menu, "Logo")
	if ctx.check(logo != null, "应有 Logo 占位"):
		ctx.check(not logo.text.is_empty(), "Logo 占位不得是空文本")


## 只找本场景自己拥有的节点：子场景（标题栏 / 提示面板）内部的同名节点不算。
func _find(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, true)
