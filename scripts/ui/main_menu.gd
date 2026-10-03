## main_menu.gd
## 职责：MAIN_MENU 场景 —— 占位主菜单（Logo / 开始 / 继续 / 设置 / 退出）+ 面板标题栏落地（06 §2.2、§6）。
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、MessagePanel、PanelTitleBar、InputScreen
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得实现任何玩法或存档 —— 设置界面、退出逻辑、存档读写均属后续批次。
##
## 占位素材位（Codex 出稿后替换，位置尺寸由场景定，脚本不引用）：ArtSkyIsland / ArtGirl / ArtCat。

extends InputScreen

## 面板规格（06 §2.2）：3px 外框 + 内芯 12px 内容边距 = 15px。面板内的容器要缩进这么多，
## 才能落在内芯填充区上 —— 描边画在矩形内侧，外框那 3px 也要算进去。
## .tscn 里的 offset 只能是字面量，本常量与它对不上就是规格漂了；
## tests/unit/test_main_menu.gd 拿这个值去核对场景里的实际缩进，两边同源。
const PANEL_BODY_INSET: float = float(PaletteTheme.FRAME_BORDER_WIDTH + PaletteTheme.PANEL_CONTENT_MARGIN)

## 标题栏文案（传给 PanelTitleBar 组件）。Logo 与四个按钮的文案写在场景里 ——
## 静态 UI 文本放 .tscn，编辑器里能直接看到成品，也让「设置 / 退出 标注未实现」这件事
## 在点开场景时就一目了然（验收要求标注写在文案上，不是等玩家点下去再靠提示告知）。
## 本阶段没有翻译表，中文原文即 tr() 的 key（06 §11），日后补表不必回头改代码。
const TEXT_TITLE_BAR: String = "主菜单"

## 提示面板文案。
const NOTICE_TITLE: String = "尚未实现"
const NOTICE_DISMISS: String = "点击任意处关闭"
const NOTICE_PREPARATION: String = "整备场景（PREPARATION）的路由未就绪，本次留在主菜单。"
const NOTICE_SETTINGS: String = "设置界面属后续批次，尚未实现。"
const NOTICE_EXIT: String = "退出逻辑属后续批次，尚未实现。"

@onready var _backdrop: ColorRect = %Backdrop
@onready var _title_bar: PanelTitleBar = %TitleBar
@onready var _button_start: Button = %ButtonStart
@onready var _button_continue: Button = %ButtonContinue
@onready var _button_settings: Button = %ButtonSettings
@onready var _button_exit: Button = %ButtonExit
@onready var _notice_panel: MessagePanel = %NoticePanel


func _ready() -> void:
	# 全屏底色取自 Palette —— 场景里那个 ColorRect 不带 color 字面量（06 §10.7）。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	_title_bar.set_title_key(TEXT_TITLE_BAR)
	# 按钮文案与「继续」的 disabled = true 都在场景里给（见 main_menu.tscn），
	# 「继续」另外**不接** pressed：本批不存在存档（11 §8「存档格式与槽位数量」尚未规划），
	# Disabled 态（06 §3 五态之一）就是它的全部含义，不进任何 code path。
	_button_start.pressed.connect(_on_start_pressed)
	_button_settings.pressed.connect(_on_settings_pressed)
	_button_exit.pressed.connect(_on_exit_pressed)
	# 06 §1：四个按钮的命中区补齐到触摸下限。四个按钮在场景里都是 90×20（主菜单面板的内芯宽度
	# 减去左右各 15px 边距），高度差 2 逻辑像素 —— 见 hit_button.gd 说明为何不能靠改 size 补。
	# 「继续」当前 disabled、不是可交互元素，一并装上只是让本场景不留例外（它将来会启用）。
	for button: Button in [_button_start, _button_continue, _button_settings, _button_exit]:
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


## 显示提示。key 为 tr() 的原文 key（同上，暂无翻译表）。
func _show_notice(message_key: String) -> void:
	_notice_panel.show_message(NOTICE_TITLE, PackedStringArray([message_key, NOTICE_DISMISS]))


## Escape 在 MAIN_MENU 里**不做事**：它是 03 §1 状态图的入口态，
## ALLOWED_TRANSITIONS 里没有任何一条边回到它，也就没有「上一态」可退。
## 按 Escape 若强行退出应用，那是「退出逻辑」，属后续批次（见 NOTICE_EXIT）。
## 提示面板的关闭由 InputScreen._handle_notice() 统一处理，本场景不必再写 _input。
func _on_back_requested() -> bool:
	return false
