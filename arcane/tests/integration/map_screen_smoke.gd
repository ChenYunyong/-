## map_screen_smoke.gd
## 职责：路线图屏**装配之后**的控件账 —— §2.2 的每一条 rect 上都真的有控件，角色也对。
## 所属系统：tests
## 依赖：TreeProbe, MapLayout, MapView, ContractTheme
## 禁止：本文件不得按下任何按钮 —— 「继续 / 返回」会真的换屏，把 GameFlow 留给后面的用例收拾。
##
## 为什么单独立一条而不是写进 scene_smoke：那个文件已经顶到源码的 300 行上限。
## 而「常量对常量」在 test_map_layout 里比过之后还剩一件事没量 —— **控件的真实 rect**。
## Button 的最小尺寸 = 文字 + 内边距，主题的内边距一旦偏大，引擎会把控件顶得比表列值宽：
## 那时常量表全绿，而动作条上那两颗键已经压到一起了（编辑器那边 24 → 28 就是这么发生的）。
## 这一屏尤其要量 —— 两颗键之间只剩 16。
##
## 入树才量得到：position / size 要等 _ready() 摆完，get_global_rect() 才有意义。

extends RefCounted

const TreeProbe = preload("res://tests/tree_probe.gd")

const SCREEN_PATH: String = "res://scenes/map.tscn"
## G02 的原话：误差 ≤1 逻辑像素。
const TOLERANCE: float = 1.0


func run(ctx: RefCounted, tree: SceneTree) -> void:
	ctx.begin_case("map_screen_smoke")
	var packed: PackedScene = load(SCREEN_PATH)
	if not ctx.check(packed != null, "%s 可加载" % SCREEN_PATH):
		return
	var screen: Control = packed.instantiate()
	tree.root.add_child(screen)
	await tree.process_frame
	_check_widgets(ctx, screen)
	_check_buttons(ctx, screen)
	screen.queue_free()
	await tree.process_frame
	# queue_free 之后 screen 已经是**悬空引用**，再点它的方法就是拿已释放的实例当活人用。
	# 顺序不能反：is_instance_valid 先判，or 的短路才护得住后面那一下。
	var gone: bool = not is_instance_valid(screen) or not screen.is_inside_tree()
	ctx.check(tree.root.get_child_count() > 0 and gone, "用完就自己撤了，树里不留这一屏")


## 纸、图、三行字各自落在 §2.2 给它们的 rect 上。
func _check_widgets(ctx: RefCounted, screen: Control) -> void:
	var view: MapView = null
	for node: Node in TreeProbe.find_all(screen, "MapView"):
		view = node as MapView
	if ctx.check(view != null, "屏里有一张 MapView"):
		ctx.check(_within(view.get_global_rect(), MapLayout.PAPER, TOLERANCE),
			"图铺满整张羊皮卷（实为 %s）" % view.get_global_rect())
	ctx.equal(TreeProbe.count_of(screen, "Panel"), 2, "两层装饰面板：暗底 + 羊皮卷（多一层就是谁又铺了一块）")
	ctx.equal(TreeProbe.count_of(screen, "Label"), 3, "三行字：标题 / 当前位置 / 底部提示")
	for row: Array in [["标题", MapLayout.TITLE_RECT], ["当前位置", MapLayout.STATUS_RECT],
			["提示", MapLayout.HINT_RECT]]:
		var wanted: Rect2 = row[1]
		var label: Label = _label_at(screen, wanted.position)
		if ctx.check(label != null, "%s 摆在 §2.2 的 %s 上" % [row[0], wanted]):
			ctx.check(_within(Rect2(label.position, label.size), wanted, TOLERANCE),
				"%s 的框就是表列值 %s（实为 %s）" % [row[0], wanted, Rect2(label.position, label.size)])


## 动作条右侧两颗键：rect 与角色都要对。
##
## 间距用**真 rect** 量一次：§2.2 说两颗键相距 16，而控件只要宽出去 1px 就会把那 16 吃掉一点 ——
## 两个表列值之间的差永远是 16，拿常量减常量是量不出这件事的。
func _check_buttons(ctx: RefCounted, screen: Control) -> void:
	var buttons: Array[Button] = []
	for node: Node in TreeProbe.find_all(screen, "Button"):
		buttons.append(node as Button)
	var declared: Array = [
		["返回编辑器", MapLayout.BACK_RECT, ContractTheme.TYPE_BUTTON_DARK_SECONDARY],
		["继续", MapLayout.PRIMARY_RECT, ContractTheme.TYPE_BUTTON_PAGE_PRIMARY],
	]
	ctx.equal(buttons.size(), declared.size(), "动作条两颗键：返回编辑器 + 继续（数到 %d）"
		% buttons.size())
	var found: Dictionary = {}
	for item: Array in declared:
		var wanted: Rect2 = item[1]
		var hits: int = 0
		for button: Button in buttons:
			if not _within(button.get_global_rect(), wanted, TOLERANCE):
				continue
			hits += 1
			found[item[0]] = button
			ctx.equal(button.theme_type_variation, item[2], "%s 走 %s 那一支（实际 %s）"
				% [item[0], item[2], button.theme_type_variation])
		ctx.equal(hits, 1, "%s：§2.2 的 %s 上有且只有一个真控件（数到 %d）%s"
			% [item[0], wanted, hits, "" if hits == 1 else "；屏上实为 %s" % _rect_list(buttons)])
	if found.size() < declared.size():
		return
	var back: Rect2 = (found["返回编辑器"] as Button).get_global_rect()
	var next: Rect2 = (found["继续"] as Button).get_global_rect()
	ctx.near(next.position.x - back.end.x, 16.0, "两颗键实测间距 16（§2.2）")
	ctx.check(back.position.x < next.position.x, "返回在左、继续在右")
	ctx.check(not (back.position.x < next.end.x and next.position.x < back.end.x
			and back.position.y < next.end.y and next.position.y < back.end.y),
		"两颗键不重叠")
	ctx.check(MapLayout.ACTIONS.encloses(back) and MapLayout.ACTIONS.encloses(next),
		"两颗键都在动作条里")


## 按下某个落点找那个 Label。三行字各占一条表列 rect，落点即身份。
func _label_at(root: Node, position: Vector2) -> Label:
	for node: Node in TreeProbe.find_all(root, "Label"):
		var label: Label = node
		if label.position.is_equal_approx(position):
			return label
	return null


## 屏上按钮的真实 rect，一行报全 —— 打回时要能一眼看出控件跑到哪去了。
static func _rect_list(buttons: Array[Button]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for button: Button in buttons:
		parts.append(str(button.get_global_rect()))
	return ", ".join(parts)


## 两个矩形四边都在容差内 —— G02 的原话是「误差 ≤1 逻辑像素」。
static func _within(a: Rect2, b: Rect2, tolerance: float) -> bool:
	return absf(a.position.x - b.position.x) <= tolerance \
		and absf(a.position.y - b.position.y) <= tolerance \
		and absf(a.size.x - b.size.x) <= tolerance \
		and absf(a.size.y - b.size.y) <= tolerance
