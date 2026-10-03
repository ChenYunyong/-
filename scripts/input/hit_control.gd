## hit_control.gd
## 职责：把非 Button 的 Control 的**可点区域**按 06 §1 扩到命中下限 —— 只改拾取，不改视觉矩形。
## 所属系统：input
## 依赖：HitMinimum
## 禁止：本文件不得改 size / position / offset / custom_minimum_size —— 那会改视觉。
##
## 与 HitButton 的分工：Button 有自己的按下反馈（06 §3 五态），故单独一份；
## Control 没有，这份只负责把拾取矩形撑到下限。
## PREPARATION 窄屏的提示条就是 Control：apply_layout_for() 把它压到 16 逻辑像素高
## （preparation_layout.gd 的 INFO_BAR_HEIGHT），而窄屏下它整条就是「点一下看详情」的交互面。
## 那个 16 是布局常量、不归本卡改，所以同样是「视觉照旧，命中区补齐」。

class_name HitControl
extends Control


## Godot GUI 拾取与本控件自身的事件投递都经这里。
func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


## 本控件此刻的可点矩形（局部坐标）。size 随布局变化，故每次现算，不缓存。
func hit_rect() -> Rect2:
	return HitMinimum.pad_rect(Rect2(Vector2.ZERO, size))
