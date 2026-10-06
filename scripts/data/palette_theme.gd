## palette_theme.gd
## 职责：把 Palette 的 Color Token 与 VB-03 组件切片装配成全局 Theme
##       （04_COLOR_SYSTEM.md §7、06_UI_UX_STANDARD.md §2/§3、PET-77 接入）。
## 所属系统：data
## 依赖：Palette, assets/ui/vb03_component_language/**（已批准切片 + PET-73 备好的 StyleBoxTexture）
## 禁止：本文件不得出现任何字面色值 —— 一切颜色必须经 Palette.get_color()，
##       否则 palette.tres 就不再是唯一色值来源（04 §6）。
##       切片自带颜色属于**已批准素材**，不在此限：它们不是「在代码里写死像素色」，
##       而是引用 `assets/_approved/vb03_component_language/` 经用户批准的产物（07 §1）。

@tool
class_name PaletteTheme
extends Theme

## VB-03 已批准切片（PET-73 落盘）。PNG 的 `.import` 不承载九宫格边距，
## 故九宫格一律走这些 StyleBoxTexture 的 `texture_margin_*`；本文件只负责把它们接到控件属性上。
const SLICE_STYLEBOX_DIR: String = "res://assets/ui/vb03_component_language/styleboxes/"
const SB_BUTTON_NORMAL: String = "ui_button_primary_normal_64x20.stylebox.tres"
const SB_BUTTON_HOVER: String = "ui_button_primary_hover_64x20.stylebox.tres"
const SB_BUTTON_PRESSED: String = "ui_button_primary_pressed_64x20.stylebox.tres"
const SB_BUTTON_FOCUS: String = "ui_button_primary_focus_64x20.stylebox.tres"
const SB_BUTTON_DISABLED: String = "ui_button_primary_disabled_64x20.stylebox.tres"
## 06 §3 的 Selected 态（真实选中，非焦点）。Godot 的 Button 没有 selected 槽位，
## 故按 13 §10.1 的语义另立 ButtonSelected 变体承载它，见 _build_button_selected()。
const SB_BUTTON_SELECTED: String = "ui_button_primary_selected_64x20.stylebox.tres"
const SB_PANEL_FRAME_MAIN: String = "ui_panel_frame_main_96x64.stylebox.tres"
const SB_PANEL_FRAME_SECONDARY: String = "ui_panel_frame_secondary_64x40.stylebox.tres"
const SB_TOOLTIP_PANEL: String = "ui_tooltip_panel_120x64.stylebox.tres"
const SB_PROGRESS_BAR: String = "ui_progress_bar_blue_96x12.stylebox.tres"
const SB_OVERLAY_FOCUS: String = "ui_overlay_focus_32.stylebox.tres"
const SB_OVERLAY_SELECTED: String = "ui_overlay_selected_32.stylebox.tres"
const SB_OVERLAY_DISABLED: String = "ui_overlay_disabled_32.stylebox.tres"

## ProgressBar 的填充子矩形。切片是「满条预览」而非可复用的 track/fill 对：
## 轨道 = 其中的空轨道段（BROWN_600 外框 + NAVY_800 内里），填充 = 其中的蓝色段。
## 数值来自切片逐像素读数（96×12）：蓝色段占列 2..61、行 2..9。
const PROGRESS_FILL_REGION: Rect2 = Rect2(2, 2, 60, 8)

## 禁用遮罩的取样子矩形。切片 32×32 中部烘焙了一行示例内容（GREY_500，列 6..25、行 12），
## 九宫格的中心区会把那一行拉伸成横贯整层的灰带，故中心改取左上角这块**纯色** scrim。
const OVERLAY_DISABLED_REGION: Rect2 = Rect2(0, 0, 2, 2)

## 06 §1：基准 320×180，描边统一 1px，间距只用 4/8/12/16/24，像素角（直角）。
const BORDER_WIDTH: int = 1
const FRAME_BORDER_WIDTH: int = 3
const CONTENT_MARGIN: int = 4
const PANEL_CONTENT_MARGIN: int = 12
const PANEL_SECONDARY_CONTENT_MARGIN: int = 8
const BODY_FONT_SIZE: int = 8

## 06 §2.2：面板标题栏高度 16px。数值放在 Theme 侧是因为标题栏尺寸属面板规格，
## 由组件场景（scenes/components/panel_title_bar.tscn）在 _ready() 里取用，
## 避免同一个 16 在 Theme 与场景里各写一份。
const TITLE_BAR_HEIGHT: int = 16

## 主面板框的九宫格边距。**刻意不等于 asset_manifest.json 的 `[3, 16, 3, 3]`** —— 依据见 _frame_slice()。
##   左 = 3px 木质外框 + 1px GOLD_200 左高光；
##   上 = 3px 木质外框 + 16px 标题栏。
const FRAME_MARGIN_LEFT: int = FRAME_BORDER_WIDTH + 1
const FRAME_MARGIN_TOP: int = FRAME_BORDER_WIDTH + TITLE_BAR_HEIGHT

## 次级框 / Tooltip 的九宫格边距，比 manifest 的 `[1, 1, 1, 1]` 各多一列 / 一行，理由同上：
## 这两种切片都是「1px 描边 + 1px 高光」，manifest 把高光那一条漏在了中心区里。
const THIN_FRAME_MARGIN_LEFT: int = 2
const THIN_FRAME_MARGIN_TOP: int = 2

## Theme 类型变体名。S1-06 起的场景用 theme_type_variation 引用它们。
const TYPE_PANEL_FRAME: StringName = &"PanelFrame"
const TYPE_PANEL_CORE: StringName = &"PanelCore"
const TYPE_PANEL_SECONDARY: StringName = &"PanelSecondary"
## 06 §2.1 v0.1.4 第三层「高光」：必须有可被场景引用的落点。
const TYPE_PANEL_HIGHLIGHT: StringName = &"PanelHighlight"
const TYPE_PANEL_SELECTED: StringName = &"PanelSelected"
## 06 §2.2 的硬阴影落点，机制说明见 _build_panel_shadow()。
const TYPE_PANEL_SHADOW: StringName = &"PanelShadow"
## 06 §2.2 的面板标题栏：底色 NAVY_700 + 底部 1px GOLD_600 分隔线。
## S1-05 复核登记的待办 —— 该规格此前在 Theme 与 scenes/** 都没有落点，S1-06 补上。
const TYPE_PANEL_TITLE_BAR: StringName = &"PanelTitleBar"
const TYPE_BUTTON_SECONDARY: StringName = &"ButtonSecondary"
const TYPE_LABEL_SECONDARY: StringName = &"LabelSecondary"
const TYPE_LABEL_DANGER: StringName = &"LabelDanger"
## PET-77：Button 的 Selected 态（真实选中）。与 Focus 语义分开（13 §10.1 三修之一）。
const TYPE_BUTTON_SELECTED: StringName = &"ButtonSelected"
## PET-77：Tooltip 面板（06 §5，最大宽度 120px）。
const TYPE_TOOLTIP_PANEL: StringName = &"TooltipPanel"
## PET-77：叠加层 —— 焦点 / 选中 / 禁用。Godot 的 Button 自带 focus 样式槽，
## 这三个变体服务的是**任意 Control**（节点卡、槽位、自定义控件）需要叠一层状态提示的场合。
const TYPE_OVERLAY_FOCUS: StringName = &"FocusOverlay"
const TYPE_OVERLAY_SELECTED: StringName = &"SelectedOverlay"
const TYPE_OVERLAY_DISABLED: StringName = &"DisabledOverlay"

const BASE_TYPE_PANEL: StringName = &"Panel"
const BASE_TYPE_BUTTON: StringName = &"Button"
const BASE_TYPE_LABEL: StringName = &"Label"


func _init() -> void:
	apply_palette()


## 重建全部主题样式。可在 palette.tres 变更后重跑；本函数只读 Palette，不缓存色值。
func apply_palette() -> void:
	default_font_size = BODY_FONT_SIZE
	_build_button()
	_build_button_secondary()
	_build_button_selected()
	_build_panels()
	_build_panel_highlight()
	_build_panel_shadow()
	_build_panel_title_bar()
	_build_tooltip_panel()
	_build_progress_bar()
	_build_overlays()
	_build_labels()


## 06 §3 的按钮五态，底色/描边/高光一律来自已批准切片（PET-77 接入）。
##
## 文字色仍走 Palette：切片只画底与边，不承载文字。
## Focus 与 Selected 的分工见 _build_button_selected()（13 §10.1 三修之一）。
func _build_button() -> void:
	set_color(&"font_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_hover_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_pressed_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_focus_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.NAVY_900))
	set_color(&"font_disabled_color", BASE_TYPE_BUTTON, Palette.get_color(Palette.Key.GREY_500))
	set_stylebox(&"normal", BASE_TYPE_BUTTON, _slice(SB_BUTTON_NORMAL, CONTENT_MARGIN))
	set_stylebox(&"hover", BASE_TYPE_BUTTON, _slice(SB_BUTTON_HOVER, CONTENT_MARGIN))
	set_stylebox(&"pressed", BASE_TYPE_BUTTON, _slice(SB_BUTTON_PRESSED, CONTENT_MARGIN))
	set_stylebox(&"disabled", BASE_TYPE_BUTTON, _slice(SB_BUTTON_DISABLED, CONTENT_MARGIN))
	set_stylebox(&"focus", BASE_TYPE_BUTTON, _slice(SB_BUTTON_FOCUS, CONTENT_MARGIN))


## 13 §10.1 三修之一：Focus 与 Selected 是两种语义，不得混用。
##   Focus（上文的 `focus` 槽）= BLUE_300 细框 —— 「键盘/指针指到这儿了」，随焦点来去。
##   Selected（本变体）        = GOLD 主强调 —— 「这一项被真正选中了」，是一种**状态**。
## 因此 Selected 不映射到 focus 槽，而是另立 ButtonSelected 变体：常态即选中外观，
## 与指针是否悬停无关；悬停/按下不改变它，否则选中态会被误读成一次悬停反馈。
## 焦点环仍由 focus 槽提供，于是「选中 + 有焦点」两个信息可同时读出。
func _build_button_selected() -> void:
	set_type_variation(TYPE_BUTTON_SELECTED, BASE_TYPE_BUTTON)
	for state: StringName in [&"normal", &"hover", &"pressed"]:
		set_stylebox(state, TYPE_BUTTON_SELECTED, _slice(SB_BUTTON_SELECTED, CONTENT_MARGIN))
	set_stylebox(&"focus", TYPE_BUTTON_SELECTED, _slice(SB_BUTTON_FOCUS, CONTENT_MARGIN))
	set_stylebox(&"disabled", TYPE_BUTTON_SELECTED, _slice(SB_BUTTON_DISABLED, CONTENT_MARGIN))


## 06 §3 辅助按钮：底色 NAVY_700，描边 NAVY_600，文字 GREY_300。
func _build_button_secondary() -> void:
	set_type_variation(TYPE_BUTTON_SECONDARY, BASE_TYPE_BUTTON)
	var text: Color = Palette.get_color(Palette.Key.GREY_300)
	var box: StyleBoxFlat = _button_box(Palette.Key.NAVY_700, Palette.Key.NAVY_600)
	for state: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_focus_color"]:
		set_color(state, TYPE_BUTTON_SECONDARY, text)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		set_stylebox(state, TYPE_BUTTON_SECONDARY, box)


## 06 §2.2：主面板 = 3px 木质外框；内芯 = NAVY_800 + 1px NAVY_600；
## 次级面板（面板内卡片）= NAVY_800 + 1px BROWN_600。
func _build_panels() -> void:
	set_type_variation(TYPE_PANEL_FRAME, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_FRAME, _frame_slice())

	set_type_variation(TYPE_PANEL_CORE, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_CORE, _panel_box(Palette.Key.NAVY_800, Palette.Key.NAVY_600))

	set_type_variation(TYPE_PANEL_SECONDARY, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_SECONDARY, _thin_frame_slice(SB_PANEL_FRAME_SECONDARY,
		PANEL_SECONDARY_CONTENT_MARGIN))


## 06 §5 Tooltip 面板：最大宽度 120px（切片尺寸即 120×64）。
## 只落样式与落点；tooltip 的出现延迟 / 翻转 / 字段裁剪规则属交互层，不在 Theme 里。
func _build_tooltip_panel() -> void:
	set_type_variation(TYPE_TOOLTIP_PANEL, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_TOOLTIP_PANEL, _thin_frame_slice(SB_TOOLTIP_PANEL,
		PANEL_SECONDARY_CONTENT_MARGIN))


## ProgressBar —— 切片是「满条预览」，一张图同时画了轨道与填充，没有独立的 track / fill 两张素材，
## 故两槽都从这张图里裁：
##   background = 整张但 **draw_center = false**，只落四条边 → 得到 1px BROWN_600 的轨道框，
##                框内透出面板底色（NAVY_800），正是切片里轨道的颜色；
##   fill       = 同一张图上蓝色那一段（region_rect），带顶部 BLUE_100 高光与右缘 BLUE_300。
## 若 background 直接 draw_center = true，中心区会把烘焙的蓝段一起拉伸 → 永远是一条满蓝。
##
## **本批没有消费者**：六个场景里没有任何 ProgressBar 控件（见交付说明）。这里只落 Theme 落点，
## 使切片不再悬空；等 IN_COMBAT 的读数条规划出来即可直接引用。
func _build_progress_bar() -> void:
	var track: StyleBoxTexture = _slice(SB_PROGRESS_BAR, 0)
	track.draw_center = false
	set_stylebox(&"background", &"ProgressBar", track)
	set_stylebox(&"fill", &"ProgressBar", _cropped_slice(SB_PROGRESS_BAR, PROGRESS_FILL_REGION, 0))


## 叠加层三件套：焦点（BLUE_300 细框 + 角标，13 §10.1）、选中（GOLD 主强调）、禁用（暗色遮罩）。
## 三者都是给**任意 Control** 叠一层状态提示用的 —— 承载控件本身长什么样由它自己的样式决定。
##
## 禁用片自带 alpha（整层 96/255 的黑罩），故三者都 draw_center：遮挡程度由素材的透明度决定，
## Theme 不再乘第二层 alpha，免得两处各调一半、谁都调不准。
##
## **本批没有消费者**：六个场景把「焦点 / 选中 / 禁用」表达成了控件**自身的状态样式**
## （按钮五态、节点卡三态），没有一处是在已有控件上再叠一层半透明片。同上，只落落点。
func _build_overlays() -> void:
	set_type_variation(TYPE_OVERLAY_FOCUS, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_OVERLAY_FOCUS, _slice(SB_OVERLAY_FOCUS, 0))
	set_type_variation(TYPE_OVERLAY_SELECTED, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_OVERLAY_SELECTED, _slice(SB_OVERLAY_SELECTED, 0))
	set_type_variation(TYPE_OVERLAY_DISABLED, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_OVERLAY_DISABLED,
		_cropped_slice(SB_OVERLAY_DISABLED, OVERLAY_DISABLED_REGION, 0))


## 取一张已批准切片的 StyleBoxTexture，并叠加统一的内容边距。
##
## `duplicate()` 是必须的：`load()` 走资源缓存，同一路径拿到的是**同一个实例**，
## 就地改 content_margin 会顺着缓存污染其它引用方（且改动可能被编辑器存回 .tres）。
## 内容边距由 Theme 决定而非素材决定 —— 素材只描述九宫格边界，不描述版面缩进。
func _slice(file_name: String, content_margin: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = (load(SLICE_STYLEBOX_DIR + file_name) as StyleBoxTexture).duplicate()
	box.content_margin_left = float(content_margin)
	box.content_margin_top = float(content_margin)
	box.content_margin_right = float(content_margin)
	box.content_margin_bottom = float(content_margin)
	return box


## 再取一次同一张切片，但用 region_rect 只截其中一块。用于「一张图里画了两件东西」的场合
## （满条预览切出填充段、带示例内容的遮罩切出纯色块）。
func _cropped_slice(file_name: String, region: Rect2, content_margin: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = _slice(file_name, content_margin)
	box.region_rect = region
	return box


## 06 §2.2 主面板框。
##
## 切片自上而下是：[0..2] 3px 木质外框 → [3..18] 16px 标题栏（NAVY_700 + 底边 1px GOLD_600）
## → [19..] NAVY_800 内芯；自左而右是：[0] BROWN_500 → [1..2] BROWN_600 → [3] GOLD_200 左高光
## → [4..] 内芯。九宫格的边距必须**正好盖住描边 + 高光 / 标题栏**这两段，
## 才能让它们原样落在面板边缘；落进中心区的那一列 / 行会被整条拉伸。
##
## asset_manifest.json 的 nine_patch 写的是 `[3, 16, 3, 3]`：左少了高光那 1 列，上少了外框那 3 行。
## 上边距按 16 渲染时，标题栏底下那条 1px 金线会被拉成 **3 行**（实测 y21..23 各 114px），
## 违反 06 §1「描边统一 1px」；按 19 渲染时金线恰好 1 行（y18）。左同理：按 3 渲染时
## GOLD_200 高光会从 1px 糊成数 px。故此处按像素结构取值，并在交付说明里报备该出入。
##
## 内容上边距同步取 19：标题栏是**框的一部分**，内容不该压在它上面。
func _frame_slice() -> StyleBoxTexture:
	var box: StyleBoxTexture = _slice(SB_PANEL_FRAME_MAIN, PANEL_CONTENT_MARGIN)
	box.texture_margin_left = float(FRAME_MARGIN_LEFT)
	box.texture_margin_top = float(FRAME_MARGIN_TOP)
	box.content_margin_top = float(FRAME_MARGIN_TOP)
	return box


## 次级面板框 / Tooltip：切片是「1px 描边 + 1px 高光」，九宫格边距同理各取 2 / 1，
## 不能照抄 manifest 的 1 / 1 —— 那会把高光那一列 / 行留在中心区里拉伸成一条糊带。
func _thin_frame_slice(file_name: String, content_margin: int) -> StyleBoxTexture:
	var box: StyleBoxTexture = _slice(file_name, content_margin)
	box.texture_margin_left = float(THIN_FRAME_MARGIN_LEFT)
	box.texture_margin_top = float(THIN_FRAME_MARGIN_TOP)
	return box


## 06 §2.1 第三层「高光」。本层是叠在内芯之上的装饰层，只画 1px 描边、不填中心
## （draw_center = false），场景把它当作 Panel 的 theme_type_variation 叠在外框内沿即可。
## BLUE_300 按 DSH 裁定**始终留在 Theme**，不随外框素材化移交。
##
## **边数（v0.1.6，Codex 裁定）：两者不得共用同一套边数。**
##   GOLD_200 静态内高光 → 仅上边 + 左边。材质受光有方向性，与 05 §3「光源方向统一为左上」
##                          一致；四边整圈会退化成「无方向的金色描边框」。
##   BLUE_300 选中辉光   → 四边整圈。状态提示而非材质受光，密集蓝图网格上需包围式轮廓才读得稳。
## 两种几何必须分开落笔：共用一条路径会让改高光时连带削掉选中态的包围轮廓，削弱其可发现性。
func _build_panel_highlight() -> void:
	set_type_variation(TYPE_PANEL_HIGHLIGHT, BASE_TYPE_PANEL)
	var warm: StyleBoxFlat = _highlight_box(Palette.Key.GOLD_200)
	warm.border_width_right = 0
	warm.border_width_bottom = 0
	set_stylebox(&"panel", TYPE_PANEL_HIGHLIGHT, warm)

	set_type_variation(TYPE_PANEL_SELECTED, BASE_TYPE_PANEL)
	set_stylebox(&"panel", TYPE_PANEL_SELECTED, _highlight_box(Palette.Key.BLUE_300))


## 06 §2.2 的「右下 1px NAVY_900 硬阴影（不模糊）」落点。
##
## 为什么不用 StyleBoxFlat.shadow_*（实测证据见 tests/unit/run_render_probes.gd 组 1，
## gl_compatibility / forward_plus / mobile 三个后端结果一致）：
##   shadow_size = 0             → 一个阴影像素都不画，且与 shadow_offset 无关；
##   shadow_size = 1, offset(1,1) → 紧贴右下确有 1px 纯 NAVY_900，但其外仍多出 1px 50% 透明的羽化带。
## 引擎只暴露 shadow_color / shadow_size / shadow_offset 三个开关，没有关闭羽化的手段，
## 而 shadow_size 同时决定「有没有阴影」和「羽化带多宽」，两者无法解耦。
## 因此改用 border + expand_margin：右下各 1px NAVY_900 描边，再用 expand_margin 推到矩形外侧。
## 实测该组合的羽化像素数为 0 —— 既满足「1px」也满足「不模糊」。
func _build_panel_shadow() -> void:
	set_type_variation(TYPE_PANEL_SHADOW, BASE_TYPE_PANEL)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Palette.get_color(Palette.Key.NAVY_900)
	box.border_width_left = 0
	box.border_width_top = 0
	box.border_width_right = BORDER_WIDTH
	box.border_width_bottom = BORDER_WIDTH
	box.expand_margin_right = float(BORDER_WIDTH)
	box.expand_margin_bottom = float(BORDER_WIDTH)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.shadow_size = 0
	set_stylebox(&"panel", TYPE_PANEL_SHADOW, box)


## 06 §2.2 面板标题栏的配色：底色 NAVY_700、**底边** 1px GOLD_600 分隔线、其余三边为 0。
##
## 分隔线画在 stylebox 的 border_bottom 上 —— Godot 的 stylebox 描边画在矩形**内侧**，
## 于是「高度 16px 的标题栏」里第 16 行就是那条金线，而不是「16px 之外再加 1px」。
## 规范只给了两个数值、没写两者的包含关系，本批按「总计 16px」实现，并在交付说明里报备复核。
##
## 内容边距清零：本变体只服务标题栏组件（一个 Panel + 手工定位的 Label），不需要容器语义；
## 留着 _panel_box() 的 12px 默认值，将来一旦被塞进容器就会把最小尺寸凭空撑高。
func _build_panel_title_bar() -> void:
	set_type_variation(TYPE_PANEL_TITLE_BAR, BASE_TYPE_PANEL)
	var box: StyleBoxFlat = _panel_box(Palette.Key.NAVY_700, Palette.Key.GOLD_600)
	box.border_width_left = 0
	box.border_width_top = 0
	box.border_width_right = 0
	box.border_width_bottom = BORDER_WIDTH
	box.content_margin_left = 0.0
	box.content_margin_top = 0.0
	box.content_margin_right = 0.0
	box.content_margin_bottom = 0.0
	set_stylebox(&"panel", TYPE_PANEL_TITLE_BAR, box)


## 高光层的**整圈**基底盒：四边各 1px 描边，不填中心，颜色只来自 Palette。
## 仅 `PanelSelected` 直接使用它；`PanelHighlight` 另需把右/下两边清零，见 _build_panel_highlight()。
func _highlight_box(token: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Palette.get_color(token)
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.shadow_size = 0
	return box


## 正文用 BLUE_100（04 §5.1 在 NAVY_800 上 11.75:1，首选）；
## 次要文字 GREY_300（06 §5）；危险小号文字 RED_400（04 §3.7）。
func _build_labels() -> void:
	set_color(&"font_color", BASE_TYPE_LABEL, Palette.get_color(Palette.Key.BLUE_100))
	set_type_variation(TYPE_LABEL_SECONDARY, BASE_TYPE_LABEL)
	set_color(&"font_color", TYPE_LABEL_SECONDARY, Palette.get_color(Palette.Key.GREY_300))
	set_type_variation(TYPE_LABEL_DANGER, BASE_TYPE_LABEL)
	set_color(&"font_color", TYPE_LABEL_DANGER, Palette.get_color(Palette.Key.RED_400))


func _button_box(fill: Palette.Key, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = _panel_box(fill, border)
	box.content_margin_left = CONTENT_MARGIN
	box.content_margin_top = CONTENT_MARGIN
	box.content_margin_right = CONTENT_MARGIN
	box.content_margin_bottom = CONTENT_MARGIN
	return box


## 06 §1：像素直角、无抗锯齿。
## 本盒**不设任何 shadow_\* 配置** —— 06 §2.2 v0.1.5 起面板自身不带阴影，硬阴影由
## TYPE_PANEL_SHADOW 叠层单独承载（见 _build_panel_shadow()）。此前这里残留的三行
## shadow_color / shadow_size / shadow_offset 是 S1-A 早期方案的遗迹，实测全部无效
## （shadow_size = 0 时引擎一个阴影像素都不画），留着只会被误读成「面板自带阴影」。
func _panel_box(fill: Palette.Key, border: Palette.Key) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.get_color(fill)
	box.border_color = Palette.get_color(border)
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	box.content_margin_left = PANEL_CONTENT_MARGIN
	box.content_margin_top = PANEL_CONTENT_MARGIN
	box.content_margin_right = PANEL_CONTENT_MARGIN
	box.content_margin_bottom = PANEL_CONTENT_MARGIN
	return box
