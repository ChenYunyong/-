## fonts.gd
## 职责：界面字体的唯一来源。
## 所属系统：data
## 依赖：无
## 禁止：本文件不得引用 Palette / 场景 —— 字体与颜色是两件事，各有各的唯一入口。
##
## PET-85：新工程**不带旧美术**，也就没有字体文件可带（旧工程 assets/fonts/ 只有一个 .gitkeep）。
## 但本作界面全是中文，而 Godot 内置默认字体不含 CJK 字形 —— 不解决这一条，
## 所有界面的中文都会变成空白方块。故此处用 SystemFont 取系统字体，**不引入任何二进制资源**：
##   · Windows：命中「Microsoft YaHei UI / Microsoft YaHei」；
##   · macOS：命中「PingFang SC」；Linux：命中「Noto Sans CJK SC」等；
##   · 都没有时 allow_system_fallback 会让引擎逐字形再找一次兜底字体。
## 判定标准是可验证的：tests/unit/test_fonts.gd 断言该字体真的含「奥」这个字形，
## 而不是「配置看起来对」。

class_name Fonts
extends RefCounted

## 候选字体族，按优先级排列。名字用系统里的真实家族名。
const CJK_FAMILIES: PackedStringArray = [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"Noto Sans CJK SC",
	"Source Han Sans SC",
	"PingFang SC",
	"Hiragino Sans GB",
	"WenQuanYi Micro Hei",
	"sans-serif",
]

## 缺字兜底字符。字体连它都画不出，说明整条字体链都不可用。
const PROBE_CHAR: String = "奥"

static var _cached: SystemFont = null


## 界面字体（带缓存）。同一个字体对象给整个 Theme 用，避免每个控件各建一份。
static func ui_font() -> SystemFont:
	if _cached != null:
		return _cached
	var font: SystemFont = SystemFont.new()
	font.font_names = CJK_FAMILIES
	# 逐字形兜底：某个家族缺字时，引擎继续在系统里找有该字形的字体。
	font.allow_system_fallback = true
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	# 像素风：不抗锯齿、不开 hinting 抖动，字形边缘保持硬边。
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	_cached = font
	return _cached


## 该字体能否画出目标字形。供启动自检与单测使用。
static func can_render(font: Font, probe: String = PROBE_CHAR) -> bool:
	if font == null or probe.is_empty():
		return false
	return font.has_char(probe.unicode_at(0))
