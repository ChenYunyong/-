## menu_theme.gd
## 职责：主菜单屏的**配色唯一落点** —— 把「这个位置该是什么颜色」写成一张角色表，色值仍全部来自 Palette。
## 所属系统：data
## 依赖：Palette（唯一色值来源）
## 禁止：本文件不得出现字面色值（04 §4.9）；不得引用节点 / 场景 / 绘制 —— 它只是一张查表；
##       不得定义玩法语义：哪个角色叫什么由使用方决定，这里只说「它取哪个 Token」。
##
## 为什么单开一张表（PET-90 §4，与 combat_theme.gd 同一条理由）：用户对书页明暗
## （亮羊皮页 vs 当前深蓝）**还没裁定**，主菜单的底色正是要跟着一起翻的那一层。
## 画面做成中性的、可替换的：所有颜色都经这张表取值，裁定之后改这张表就能整体切换，
## 不必回到 main_menu_screen 里去找哪一处用了哪个 Token。
##
## 表里刻意**没有**「哪一层必须比哪一层亮」这类断言 —— 那是裁定之后才成立的事。
##
## 表里只收**这一屏自己画的东西**（整屏底 + 两块板）。标题、说明文字、按钮与它们的外框
## 不在这里：那几类由 ArcaneTheme 的类型变体定（06 §7：不在控件上零散覆盖颜色），
## 与 combat_theme 的分工逐字相同。

class_name MenuTheme
extends RefCounted

## 主菜单上的颜色角色。**按用途命名，不按颜色命名** ——
## 叫 NAVY_900 的话，换浅色基调时这张表会变成一份自相矛盾的说明书。
enum Role {
	## 整屏底色。
	BACKDROP,
	## 四个入口背后的那块板。
	MENU_PLATE,
	## 设置面板的底（「设置」按下才出现）。
	SETTINGS_PLATE,
}

## 角色 → Token。**这是整屏唯一一处「哪个 Token 用在哪」的映射**。
##
## 取值理由（同族内拉开，避免同用途近似色 —— 04 §4.4）：
##   底色 NAVY_900 是画布上最深的一档；入口板 NAVY_800 压在它上面才浮得起来；
##   设置板 NAVY_700 再亮一档 —— 它是「按出来的那一层」，比常驻的入口板更靠近玩家。
##   这三档深浅关系直接沿用编辑器的书页 / 卡片 / 顶栏，主菜单才不像另一个游戏。
const ROLE_TOKEN: Dictionary = {
	Role.BACKDROP: Palette.Key.NAVY_900,
	Role.MENU_PLATE: Palette.Key.NAVY_800,
	Role.SETTINGS_PLATE: Palette.Key.NAVY_700,
}

## 角色缺登记时的兜底色。灰是「这里没设计过」的颜色，不是某一档色阶 ——
## 它一眼就不像刻意选的，于是漏配当场显形（与 Palette.MISSING_COLOR 同一条思路）。
const FALLBACK_TOKEN: Palette.Key = Palette.Key.GREY_500


## 取某个角色的颜色。**这是主菜单唯一的取色入口**。
static func color(role: Role) -> Color:
	return Palette.get_color(token_of(role))


## 某个角色对应的 Token。测试用它核对「每个角色都登记过」。
static func token_of(role: Role) -> Palette.Key:
	var token: Variant = ROLE_TOKEN.get(role)
	return token if token != null else FALLBACK_TOKEN


## 表里登记了多少个角色。反向对照用：表被清空时「每个角色都查得到」会变成空真。
static func role_count() -> int:
	return ROLE_TOKEN.size()
