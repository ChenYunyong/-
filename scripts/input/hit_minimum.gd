## hit_minimum.gd
## 职责：06_UI_UX_STANDARD.md §1 的触摸命中下限 —— 常量与「把实测矩形扩到下限」的纯矩形算术。
## 所属系统：input
## 依赖：无
## 禁止：本文件不得引用任何场景 / 控件类型 / 视口 —— 它只做矩形运算，
##       这样命中区能在没有视口、没有渲染的单元测试里被直接量测（09 §4）。

class_name HitMinimum
extends RefCounted

## 06 §1：触摸目标最小命中尺寸 **44×44 设备像素（物理）**。
const MIN_TOUCH_DEVICE_PX: float = 44.0
## 06 §1 / 03 §8：双端最小缩放 **≥ 2×**（640×360）。设备像素 = 逻辑像素 × 缩放。
const MIN_SCALE: float = 2.0
## 由上两条推出：2× 下 44 设备像素 = **22 逻辑像素**。这是硬下限。
const HARD_MIN_LOGICAL: float = MIN_TOUCH_DEVICE_PX / MIN_SCALE
## 06 §1 点名的设计值：最小交互元素 **24 逻辑像素**（2× 下 = 48 设备像素 ≥ 44）。
## 本层按这个更严的值执行 —— 22 只是「刚好达标」，24 才是规范自己写下的那个数。
const DESIGN_MIN_LOGICAL: float = 24.0

## 本层执行的命中下限（逻辑像素）。
static func required_size() -> Vector2:
	return Vector2(DESIGN_MIN_LOGICAL, DESIGN_MIN_LOGICAL)

## 某逻辑尺寸在给定缩放下折合多少设备像素。单位换算的唯一处，报告与断言都读它。
static func device_px(logical_size: Vector2, scale: float = MIN_SCALE) -> Vector2:
	return logical_size * scale

## 某逻辑尺寸是否已达标（两轴都要达标 —— 命中区是二维的，只有宽度够不算数）。
static func meets(logical_size: Vector2) -> bool:
	var need: Vector2 = required_size()
	return logical_size.x >= need.x and logical_size.y >= need.y

## 把实测矩形**按中心**扩到下限之上；已达标的原样返回。
## 只算矩形，不碰控件 —— 调用方决定这个矩形拿去做什么（局部 _has_point 外扩，或量测上报）。
static func pad_rect(rect: Rect2) -> Rect2:
	var need: Vector2 = required_size()
	var size: Vector2 = Vector2(maxf(rect.size.x, need.x), maxf(rect.size.y, need.y))
	var grow: Vector2 = (size - rect.size) * 0.5
	return Rect2(rect.position - grow, size)
