## main_menu.gd
## 职责：MAIN_MENU 场景 —— 占位主菜单（Logo / 开始 / 继续 / 设置 / 退出）+ 面板标题栏落地（06 §2.2、§6），
##       按 13 §3 的裁定把 Logo 区、左侧构图区、右下信息框三处定成可替换的结构位。
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、Settings、MessagePanel、PanelTitleBar、InputScreen
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得实现任何玩法或存档 —— 完整设置界面、退出逻辑、存档读写均属后续批次。
##       本卡只落**一个语言开关**（PET-67）：判断「当前是哪种语言」的分支只在 Settings 里
##       （见 Settings.toggle_locale()），本文件不得出现 "en" / "zh_CN" 这类字面语言名（06 §11）。
##
## 占位素材位（Codex 出稿后替换；位置与尺寸由场景定，脚本只碰 Logo 的文案）：
##   `LogoSlot`       顶部横条的 Logo 位（13 §3.1：职责是品牌识别，不做广告式大 Logo）。
##   `DecorationSlot` **左侧构图区**的可替换装饰位 —— 最终美术落进它的 `DecorationArt`。
## 将来替换为 工坊 / 核心机器 / 浮岛 等，**不得**擅自加主角或吉祥物（13 §2）。
##
## 右下角只剩一行版本 / 存档辅助信息（`VersionLabel`，13 §3.3：原 MENU PANEL 是开发说明框，
## 正式版或删或降级为版本号一类辅助信息，**不得形成新的视觉中心**）。

extends InputScreen

## 面板规格（06 §2.2）：3px 外框 + 内芯 12px 内容边距 = 15px。面板内的容器要缩进这么多，
## 才能落在内芯填充区上 —— 描边画在矩形内侧，外框那 3px 也要算进去。
## .tscn 里的 offset 只能是字面量，本常量与它对不上就是规格漂了；
## tests/unit/test_main_menu.gd 拿这个值去核对场景里的实际缩进，两边同源。
const PANEL_BODY_INSET: float = float(PaletteTheme.FRAME_BORDER_WIDTH + PaletteTheme.PANEL_CONTENT_MARGIN)

## 标题栏文案（传给 PanelTitleBar 组件）。Logo 与四个按钮的文案写在场景里 ——
## 静态 UI 文本放 .tscn，编辑器里能直接看到成品，也让「设置 / 退出 标注未实现」这件事
## 在点开场景时就一目了然（验收要求标注写在文案上，不是等玩家点下去再靠提示告知）。
## 中文原文即 key（06 §11）：翻译表 assets/i18n/ui.csv 的 keys 列就是这些原文，
## 补表时按原文查得到，不必回头改代码。
const TEXT_TITLE_BAR: String = "主菜单"

## 提示面板文案。
const NOTICE_TITLE: String = "尚未实现"
const NOTICE_DISMISS: String = "点击任意处关闭"
const NOTICE_PREPARATION: String = "整备场景（PREPARATION）的路由未就绪，本次留在主菜单。"
const NOTICE_SETTINGS: String = "设置界面属后续批次，尚未实现。"
const NOTICE_EXIT: String = "退出逻辑属后续批次，尚未实现。"

## Logo 文案（06 §11：中文原文即 tr() 的 key）。**文案写在场景里**
## —— 静态 UI 文本放 .tscn，编辑器里点开就能看到成品；这里只负责把它送进翻译入口。
## 写成静态函数是为了能被单测直接调用：本场景的用例 instantiate 而不入树，_ready() 不会跑。
## 走 TranslationServer 而不是 Object.tr()：静态函数里没有 tr() 可用（06 §11 的同一件事）。
static func translate_text(key: String) -> String:
	return String(TranslationServer.translate(key))


@onready var _backdrop: ColorRect = %Backdrop
@onready var _logo: Label = %Logo
@onready var _title_bar: PanelTitleBar = %TitleBar
@onready var _button_start: Button = %ButtonStart
@onready var _button_continue: Button = %ButtonContinue
@onready var _button_settings: Button = %ButtonSettings
@onready var _button_exit: Button = %ButtonExit
@onready var _button_lang: Button = %ButtonLang
@onready var _notice_panel: MessagePanel = %NoticePanel

## Logo 的原文 key。_ready() 时从控件读回来记下（唯一事实来源仍是 .tscn 里那行文本）——
## 切语言时要靠它把 text 复位回 key，见 _apply_locale_texts()。
var _logo_key: String = ""


func _ready() -> void:
	# 全屏底色取自 Palette —— 场景里那个 ColorRect 不带 color 字面量（06 §10.7）。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	# Logo 与标题栏的文案是**脚本赋的值**，切语言时必须重刷（见 _apply_locale_texts()）。
	# 场景里那四个按钮的文案不用管 —— 它们的 text 全程是原文 key，引擎自己按 locale 出字。
	_logo_key = _logo.text
	_apply_locale_texts()
	# 语言开关：真正的语言判断在 Settings 里，本场景只转发一次点击。
	Settings.setting_changed.connect(_on_setting_changed)
	_button_lang.pressed.connect(_on_language_pressed)
	# 按钮文案与「继续」的 disabled = true 都在场景里给（见 main_menu.tscn），
	# 「继续」另外**不接** pressed：本批不存在存档（11 §8「存档格式与槽位数量」尚未规划），
	# Disabled 态（06 §3 五态之一）就是它的全部含义，不进任何 code path。
	_button_start.pressed.connect(_on_start_pressed)
	_button_settings.pressed.connect(_on_settings_pressed)
	_button_exit.pressed.connect(_on_exit_pressed)
	# 06 §1：按钮的命中区补齐到触摸下限。四个菜单按钮在场景里都是 90×20（主菜单面板的内芯宽度
	# 减去左右各 15px 边距），高度差 2 逻辑像素 —— 见 hit_button.gd 说明为何不能靠改 size 补。
	# 「继续」当前 disabled、不是可交互元素，一并装上只是让本场景不留例外（它将来会启用）。
	for button: Button in [_button_start, _button_continue, _button_settings, _button_exit, _button_lang]:
		install_hit_minimum(button)
	# 提示面板可点任意处关闭；键盘导航从「开始」起步（它是最上面一个可用按钮）。
	register_dismissible_notice(_notice_panel)
	register_focus_root(_button_start)


## 「开始」：请求进入 PREPARATION（03 §1 状态图 MAIN_MENU → PREPARATION）。
##
## S1-07 落地后这条路由已经通了，正常情况直接放行。这里仍然先查路由是否就绪，
## 而不是闭眼调用 change_state()：状态与场景由同一个提交点落地（03 §1.1 R3），
## GameFlow 对未实现的路由只打印一行、并不改变状态（见 game_flow.gd 的 _route_to_scene），
## 直接请求不会崩，但玩家那边看到的是「按了没反应」—— 那正是验收不接受的静默无效。
## 查的是 GameFlow 自己登记的 SCENE_ROUTES（唯一路由来源），不在这里另抄一份路径。
## 它现在守的是真正的路由故障（场景文件缺失 / 路径写错），而不是「尚未实现」。
func _on_start_pressed() -> void:
	var target_path: String = GameFlow.get_scene_path_for(GameFlow.GameState.PREPARATION)
	if target_path.is_empty() or not ResourceLoader.exists(target_path):
		_show_notice(NOTICE_PREPARATION)
		return
	GameFlow.change_state(GameFlow.GameState.PREPARATION)


func _on_settings_pressed() -> void:
	_show_notice(NOTICE_SETTINGS)


func _on_exit_pressed() -> void:
	_show_notice(NOTICE_EXIT)


## 语言开关：只转发给 Settings —— 「现在是哪种语言、该切到哪种」不属场景层的判断（06 §11）。
## 切换后信号回路会把文案重刷一遍，界面立刻变，不需要重启、也不需要重进场景。
func _on_language_pressed() -> void:
	Settings.toggle_locale()


## 设置变化 → 与文案有关的是语言。这里判的是**设置项的 key**，不是「当前是哪种语言」：
## 分辨率 / 音量改了不碰文案，语言改了才重刷。
func _on_setting_changed(key: StringName) -> void:
	if key == Settings.KEY_LOCALE:
		_apply_locale_texts()


## 把随语言变化的文案重新落到控件上。_ready() 与语言切换各跑一次。
##
## 为什么不能只赋一次：Logo 与标题栏的 text 是**脚本赋的值**，而赋值写进去的是「当时那种语言的
## 成品」；切回来时 text 里剩下的是上一次的译文，翻译入口再也找不到 key（06 §11：中文原文即 key）。
## 场景里静态写的那些按钮文案不在此列 —— 它们的 text 从头到尾都是原文 key，引擎按 locale 出字。
##
## Logo 那两行刻意分写：第二行必须原样留在源码里 —— tests/unit/test_main_menu.gd 有一条源码纪律
## 断言直接查 `_logo.text = translate_text(_logo.text)` 这个字符串（该用例 instantiate 而不入树，
## _ready() 不跑，只能查源码）。合并成一行会让那条断言失去落点。
func _apply_locale_texts() -> void:
	_logo.text = _logo_key
	_logo.text = translate_text(_logo.text)
	_title_bar.set_title_key(TEXT_TITLE_BAR)


## 显示提示。key 为 tr() 的原文 key（06 §11）。
func _show_notice(message_key: String) -> void:
	_notice_panel.show_message(NOTICE_TITLE, PackedStringArray([message_key, NOTICE_DISMISS]))


## Escape 在 MAIN_MENU 里**不做事**：它是 03 §1 状态图的入口态，
## ALLOWED_TRANSITIONS 里没有任何一条边回到它，也就没有「上一态」可退。
## 按 Escape 若强行退出应用，那是「退出逻辑」，属后续批次（见 NOTICE_EXIT）。
## 提示面板的关闭由 InputScreen._handle_notice() 统一处理，本场景不必再写 _input。
func _on_back_requested() -> bool:
	return false
