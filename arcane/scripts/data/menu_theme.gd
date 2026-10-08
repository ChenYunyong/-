## menu_theme.gd
## 职责：主菜单屏的**配色唯一落点** —— 把「这一屏自己画的东西该是什么颜色」写成一张角色表，色值仍全部来自 Palette。
## 所属系统：data
## 依赖：Palette（唯一色值来源）、ContractTheme / ContractScreenTheme（材质角色不在本表）
## 禁止：本文件不得出现字面色值（04 §4.9）；不得引用节点 / 场景 / 绘制 —— 它只是一张查表；
##       不得定义玩法语义：哪个角色叫什么由使用方决定，这里只说「它取哪个 Token」。
##
## PET-93 屏④把这张表**收窄**了：旧版收的是「整屏底 / 入口板 / 设置板」三块板，
## 而 §3 把这三块的材质都划给了共用 Theme 层 —— 纸背四处统一走 GOLD_200
## （编辑器 / 地图 / 菜单 / 战斗纸框），深面板统一走 NAVY_800（§2.4 的 SETTINGS_PANEL）。
## 于是这一屏自己**画**出来的只剩按钮上的两笔状态装饰：悬停高光与焦点角标。
## 表变短了，不是丢了东西 —— 那三块板改由 ContractTheme / ContractScreenTheme 供给，
## 与屏①②③ 同一个来源，四屏的纸才真的是同一张纸。
##
## 表里刻意**没有**「哪一层必须比哪一层亮」这类断言 —— 材质深浅由 Theme 层定，
## 这里只有两个状态色，它们与底色之间是否够对比由 §3.2 的实测数字管（G04/G09）。

class_name MenuTheme
extends RefCounted

## 主菜单自己画的两笔「状态装饰」。**按用途命名，不按颜色命名**。
enum Role {
	## 焦点角标：四角 L（§1.1「BLUE_300；不能画完整金圈」）。
	FOCUS,
	## 悬停高光：材质上 / 左各 1px（§2.4、§3「材质上/左高光 GOLD_200」）。
	HIGHLIGHT,
}

## 角色 → Token。**这是这一屏唯一一处「哪个 Token 用在哪」的映射**。
##
## 为什么焦点必须是 BLUE_300 而不是金色：§1.1 末段要求 Focus 与 Selected 分得开，
## 而本屏的强主动作（开始新一局）本身就是**整面金**的 —— 金角标压在金底上等于没画。
## 两个语义色的 RGB 欧氏距离 §1.1 给了实测值 158.392（≥150，G09）。
const ROLE_TOKEN: Dictionary = {
	Role.FOCUS: Palette.Key.BLUE_300,
	Role.HIGHLIGHT: Palette.Key.GOLD_200,
}

## 角色缺登记时的兜底色。灰是「这里没设计过」的颜色，不是某一档色阶 ——
## 它一眼就不像刻意选的，于是漏配当场显形（与 Palette.MISSING_COLOR 同一条思路）。
const FALLBACK_TOKEN: Palette.Key = Palette.Key.GREY_500


## 取某个角色的颜色。**这是主菜单自己那两笔装饰唯一的取色入口**。
static func color(role: Role) -> Color:
	return Palette.get_color(token_of(role))


## 某个角色对应的 Token。测试用它核对「每个角色都登记过」。
static func token_of(role: Role) -> Palette.Key:
	var token: Variant = ROLE_TOKEN.get(role)
	return token if token != null else FALLBACK_TOKEN


## 表里登记了多少个角色。反向对照用：表被清空时「每个角色都查得到」会变成空真。
static func role_count() -> int:
	return ROLE_TOKEN.size()
