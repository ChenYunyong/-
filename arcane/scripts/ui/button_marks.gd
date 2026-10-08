## button_marks.gd
## 职责：按钮上的两笔**状态装饰** —— 悬停的上/左 1px 高光、焦点的四角 L 角标（§2.4 + §1.1）。
## 所属系统：ui
## 依赖：BoardStatePainter（四角 L 的唯一画法）、StrokePainter（笔的定义不在这里）
## 禁止：本文件不得出现裸色值（两个颜色都由调用方给）；不得改变宿主按钮的矩形与布局；
##       不得自己判断语言 / 玩法状态 —— 它只读宿主的那三个内建状态位。
##
## 为什么挂在**子控件**上而不是 StyleBox：StyleBoxFlat 一个状态只有一支 border_color，
## 画不出「只有四角」的 L。子节点画在父控件之后（引擎保证，与 IconButton 同一条理由），
## 于是角标压在按钮底与文字之上，而它自己不参与宿主的尺寸协商 —— Button 不是 Container，
## 子控件的最小尺寸不会上报给它。§2.4 原话「Focus 加四角 L 而不改变按钮布局」就是这一条。
##
## 为什么两个状态由一个控件画：两者都是「画在按钮上、不算按钮内容」的装饰，
## 分成两个控件就要挂两次、摆两次、还要各自判一次可见性。合起来后每个按钮只挂一个子节点。
##
## 状态判据收在 marks_for() 这个**纯函数**里：真机上的 hover / press 在 headless 下按不出来，
## 把真值表拿出来才能被断言（_draw() 里那三行只是把它接到引擎状态上）。

class_name ButtonMarks
extends Control

## 悬停高光的厚度。§2.4「Hover 保留边框并加上/左 1px 高光」。
const HIGHLIGHT_WIDTH: float = 1.0
## 高光内缩 1：「保留边框」= 那 1px 的常态边框仍在，高光落在它**里面**一格。
const HIGHLIGHT_INSET: float = 1.0
## marks_for() 的位标志。
const MARK_NONE: int = 0
const MARK_HIGHLIGHT: int = 1
const MARK_FOCUS: int = 2

## 两笔装饰的颜色。由调用方从角色表取（本文件不认识 Palette），因此**不给默认值** ——
## 给一个默认色就等于在「角色表」之外又多了一处色值来源，而它还是看不见的那一处。
var focus_color: Color
var highlight_color: Color
## 焦点角标下面那道 NAVY_600 暗底（§3「亮纸上的控件加 NAVY_600 暗底」）。
## alpha = 0 表示这一层不画：深色入口上 BLUE_300 / NAVY_800 = 9.930（§3.2）本来就够，
## 多垫一圈反而把角标画糊。哪些按钮需要，由调用方按「它是不是落在亮底上」决定。
var focus_under: Color

var _host: Button = null


## 该画哪几笔。悬停与按下互斥 —— §2.4 把两者列成两个状态，按下时那一下由 Theme 的按下态
## （内容下移 2 + 内嵌暗边）负责，再叠一道亮高光就把「按下」画成「抬起」了。
static func marks_for(hovered: bool, focused: bool, pressed: bool) -> int:
	var marks: int = MARK_NONE
	if hovered and not pressed:
		marks |= MARK_HIGHLIGHT
	if focused:
		marks |= MARK_FOCUS
	return marks


## 给一颗按钮挂上装饰层。返回挂上去的控件，调用方不必自己保存 —— 它跟着宿主一起生死。
static func attach(host: Button, focus: Color, highlight: Color, under: Color) -> ButtonMarks:
	var node: ButtonMarks = ButtonMarks.new()
	node.focus_color = focus
	node.highlight_color = highlight
	node.focus_under = under
	# 装饰层不吃指针事件：它铺满宿主，否则会把宿主自己的点击全挡掉。
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(node)
	node._host = host
	# 全铺宿主。必须用 set_anchors_and_offsets_preset —— 只设 anchors 会保留旧 offset，
	# 子控件尺寸不会跟着宿主走（IconButton 的 _surface 踩过同一条）。
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 三个状态位都没有变更信号，只能挂在能代表它们变化的信号上。鼠标与焦点那四个是现成的；
	# visibility_changed 是给「藏起来的时候焦点丢了」这种情形兜底的 —— 不重画的话，
	# 下次显形时画面上留的是上一次的角标（CanvasItem 会重放已记录的绘制命令）。
	host.focus_entered.connect(node.queue_redraw)
	host.focus_exited.connect(node.queue_redraw)
	host.mouse_entered.connect(node.queue_redraw)
	host.mouse_exited.connect(node.queue_redraw)
	host.button_down.connect(node.queue_redraw)
	host.button_up.connect(node.queue_redraw)
	host.visibility_changed.connect(node.queue_redraw)
	return node


## 当前该画哪几笔（测试与采集工具用它读状态，不在 _draw() 里另算一遍）。
func marks() -> int:
	if _host == null:
		return MARK_NONE
	return marks_for(_host.is_hovered(), _host.has_focus(), _host.is_pressed())


## 这一层的焦点角标要不要垫暗底。与 marks() 同一条口径：读状态而不在 _draw() 里另算。
func paints_focus_under() -> bool:
	return focus_under.a > 0.0


func _draw() -> void:
	var flags: int = marks()
	if flags & MARK_HIGHLIGHT:
		_paint_highlight()
	if flags & MARK_FOCUS:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		# 四角 L 全工程只有一处画法：§2.4 只说「加四角 L」，尺寸沿用 §1.1 那一行
		# （内缩 1 / 臂 12 / 线宽 2）。按钮与卡片共用同一条，角标在四屏里长得一样。
		# 落在亮底 / 金底上的按钮另垫一道 NAVY_600 暗底（§3），否则 BLUE_300 只有 1.057:1。
		if paints_focus_under():
			BoardStatePainter.paint_focus_backed(self, rect, focus_color, focus_under)
		else:
			BoardStatePainter.paint_focus(self, rect, focus_color)


## 上 / 左各一条 1px 高光。用填矩形而不是笔触：1px 的线在 2× 下要不糊只有整数矩形给得了，
## 而材质高光在工程里本来就是填充层（ContractTheme.TYPE_PAGE_HILIGHT 同一条）。
func _paint_highlight() -> void:
	var inner: float = HIGHLIGHT_INSET
	var width: float = maxf(size.x - inner * 2.0, 0.0)
	var height: float = maxf(size.y - inner * 2.0, 0.0)
	draw_rect(Rect2(Vector2(inner, inner), Vector2(width, HIGHLIGHT_WIDTH)), highlight_color)
	draw_rect(Rect2(Vector2(inner, inner), Vector2(HIGHLIGHT_WIDTH, height)), highlight_color)
