## hit_button.gd
## 职责：把 Button 的**可点区域**按 06 §1 扩到命中下限 —— 只改拾取，不改视觉矩形。
## 所属系统：input
## 依赖：HitMinimum
## 禁止：本文件不得改 size / position / offset / custom_minimum_size / 主题覆盖 ——
##       那会改视觉，而 PREPARATION 的 CTA（64×20）已被像素探针逐值断言
##       （preparation_probe.gd 的 CTA_BOX 与「CTA 之外 GOLD_500 归零」两条）。
##
## 为什么命中区必须与视觉矩形解耦：
## 06 §7 实测反推的 CTA 亮色区块是 64×14，装不下中文按钮，实机取 64×20（06 §7.2 ①）。
## 而 06 §1 要求命中 ≥ 44×44 设备像素 —— 2× 下即 22 逻辑像素，20 差了 2px。
## 把按钮长到 24 逻辑像素会同时打红上面那两条像素断言，故只有两条路：
## 改规范（不属本卡），或让命中区大于视觉矩形。
## 后者正是任务书说的「显式命中矩形」：_has_point() 只参与 GUI 拾取，不参与绘制，
## 于是 hover / pressed 五态（06 §3）仍由按钮自己按原矩形画，像素证据一个像素都不动。
##
## 反面：这不是「让点击穿透到别处」。Godot 的 GUI 拾取自上而下问每个控件 has_point()，
## 本覆盖让按钮在自己矩形之外先接住那一圈，落点归属仍然是这一个控件。

class_name HitButton
extends Button


## Godot GUI 拾取与本控件自身的事件投递都经这里。
func _has_point(point: Vector2) -> bool:
	return hit_rect().has_point(point)


## 本控件此刻的可点矩形（局部坐标）。size 随布局变化，故每次现算，不缓存。
func hit_rect() -> Rect2:
	return HitMinimum.pad_rect(Rect2(Vector2.ZERO, size))
