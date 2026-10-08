## contract_font.gd
## 职责：docs/14 §1「字号 / 行高」的字体度量层 —— 把系统字体的**实际**行高收进契约，
##       并给「按契约 rect 排不下」的几处英文文案收字距。四屏共用的唯一落点。
## 所属系统：data
## 依赖：Fonts（字体的唯一来源）
## 禁止：本文件不得写死字体族名 / 字体文件（那是 fonts.gd 与 PET-96 的作业面）、
##       不得改字号档位（那是 ContractTheme.FONT_*）、不得出现字面色值、不得新增 Palette.Key。
##
## 为什么必须有这一层：系统 CJK 首选（Microsoft YaHei 家族，见 fonts.gd）在 24 / 36 号上的
## ascent+descent 实测是 **33 / 49**，比 §1 表列的 **32 / 48** 各多 1px。§1 明写
## 「文字的实际 ascent+descent 必须 ≤ 表列行高」，而 G02 的 rect 容差**不豁免行高**。
## 不处理的话，任何一个 24 号的 Label 最小行盒都是 33，声明 32 的 rect 当场被顶高 1px
## （实测：主菜单浮层标题 320×32 → 320×33；编辑器屏标题同样 33）。
##
## 手法是 §1 允许的两种之一 ——「字体行距」：FontVariation 的 SPACING_TOP / SPACING_BOTTOM
## 各收 1，**字号一个都不动**，因此 G05 的「详情名 24 − 类型 16 = 8」不受影响，
## §1 表里的行高数字也不动。度量按实际取，不假设字体是哪一支 —— PET-96 换字体后
## 这一层照样成立（换完若度量变了，由 DSH 决定要不要复量，见本卡评论）。
##
## 第二件事是**字距**：英文文案在 24 号上有两处按契约 rect 放不下 ——
##   详情名 `Projectile Count` 实测宽 183 > 176（侵入门神关闭键框 3px）；
##   战斗标题 `AUTO CASTING` 实测宽 179 > 176。
## §1 要求「两种语言实际 shaping 后宽度须 ≤ 内容区」「按钮不省略、不缩字号」，
## 故收的是字距（每字 −1），不是字号，更不是截断。
##
## 必须是 @tool：唯一调用方 ArcaneTheme 是 @tool（编辑器加载 theme_main.tres 时就会走 _init）。

@tool
class_name ContractFont
extends RefCounted

## §1 的「字号 / 行高」对照表。它抄的是契约数字，**不是**从字体度量反推出来的。
const LINE_HEIGHT: Dictionary = {12: 20, 16: 24, 20: 28, 24: 32, 36: 48}
## 每侧收掉的字体行距（逻辑像素）。取 1：只有 24 / 36 两档超线（各 1px），收 1 即回线内，
## 且不会把字形的 ascent/descent 裁掉（24 号 ascent 26 → 25、descent 7 → 6）。
const LINE_TIGHTEN: int = 1
## 字距收紧量（逻辑像素 / 每字）。取 −1：`Projectile Count` 183 → 168（≤176）、
## `AUTO CASTING` 179 → 168（≤176），两处都留出 8px 余量。
const GLYPH_TIGHTEN: int = -1

static var _contracted: FontVariation = null
static var _tightened: FontVariation = null


## 行高已收进 §1 契约的界面字体。主题的 `default_font` 就是它。
static func contracted() -> FontVariation:
	if _contracted == null:
		_contracted = _variation(0)
	return _contracted


## 行高与**字距**都收过的字体。给「英文按契约 rect 排不下」的那两处（详情名 / 战斗标题）。
## 它是另一个 FontVariation 而**不是**改字距的全局默认 —— 契约只要求那两处收得下，
## 其它 24 号文字（屏标题、波次）没有超宽问题，不该跟着一起变紧。
static func tightened() -> FontVariation:
	if _tightened == null:
		_tightened = _variation(GLYPH_TIGHTEN)
	return _tightened


## 行距 + 字距两个偏移落到一个 FontVariation 上。base_font 由 fonts.gd 给，本文件不认字体族。
static func _variation(glyph_spacing: int) -> FontVariation:
	var font: FontVariation = FontVariation.new()
	font.base_font = Fonts.ui_font()
	font.set_spacing(TextServer.SPACING_TOP, -LINE_TIGHTEN)
	font.set_spacing(TextServer.SPACING_BOTTOM, -LINE_TIGHTEN)
	if glyph_spacing != 0:
		font.set_spacing(TextServer.SPACING_GLYPH, glyph_spacing)
	return font


## 该字号在契约里的行高。字号不在表里时返回 0 —— 调用方必须显式处理（02 §9）。
static func line_height_of(font_size: int) -> float:
	return float(LINE_HEIGHT.get(font_size, 0))


## 某个字体在某个字号上是否满足 §1 的行高上限。断言与工具共用这一条，免得两处各写一遍。
static func fits_line_height(font: Font, font_size: int) -> bool:
	var limit: float = line_height_of(font_size)
	if font == null or limit <= 0.0:
		return false
	return font.get_height(font_size) <= limit
