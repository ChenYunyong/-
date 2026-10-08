## boot_screen.gd
## 职责：启动自检 + 进主菜单。BOOT 是本工程唯一由引擎直接落地的场景。
## 所属系统：ui
## 依赖：Palette, Fonts, GameFlow, UiKit, ArcaneTheme
## 禁止：本文件不得自己 change_scene_to_file()（03 §1.1 R3）；不得吞掉自检失败（02 §9）；
##       不得开一局 —— 开新局是玩家在主菜单按「开始新一局」的动作（PET-90）。
##
## 自检三条，每条都是「资源在不在 / 画不画得出来」，不是「配置看起来对不对」：
##   1. 调色板资源能加载；
##   2. 界面主题资源能加载；
##   3. 系统字体真的能画出中文 —— 缺这一条，界面上所有中文都会变成空白方块。
##
## PET-90：落点由 EDITOR 改成 MAIN_MENU，并**去掉**这里的 RunState.start_run()。
## 启动就开局的话，主菜单上的「继续」会永远亮着 —— 那是在替玩家宣称「你有一局没打完」，
## 而玩家这一局根本还没开始。自检通过 = 机器能跑，不等于玩家已经开了一局。

extends Control

const THEME_PATH: String = "res://assets/ui/theme_main.tres"
const MESSAGE_RECT: Rect2 = Rect2(72.0, 144.0, 816.0, 120.0)


func _ready() -> void:
	var problem: String = _self_check()
	if not problem.is_empty():
		_show_problem(problem)
		return
	GameFlow.change_state(GameFlow.GameState.MAIN_MENU)


## 返回空串 = 全部通过；否则返回给玩家看的失败原因（已 tr()）。
func _self_check() -> String:
	if Palette.get_palette() == null:
		return tr("启动失败：调色板资源缺失或损坏。")
	if not ResourceLoader.exists(THEME_PATH):
		return tr("启动失败：界面主题资源缺失或损坏。")
	if not Fonts.can_render(Fonts.ui_font()):
		return tr("启动失败：界面字体无法显示中文。")
	return ""


## 失败就停在原地把原因写在脸上 —— 不静默失败，也不带着空白的界面往下走（02 §9）。
func _show_problem(message: String) -> void:
	var title: Label = UiKit.label(tr("启动自检未通过"), Rect2(72.0, 72.0, 816.0, 48.0),
		ArcaneTheme.TYPE_LABEL_DANGER)
	add_child(title)
	add_child(UiKit.wrapped_label(message, MESSAGE_RECT, ArcaneTheme.TYPE_LABEL_SECONDARY))
	push_error("BootScreen: %s" % message)
