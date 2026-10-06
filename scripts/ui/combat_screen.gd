## combat_screen.gd
## 职责：COMBAT 场景 —— 06 §8 的战场（敌人推进区 + 机器示意区）+ 底部状态带（状态 / 预览的只读展示），
##       以及通往 REWARD / RESULT 的两个触发入口。
##       本批（FIRST PLAYABLE 4/4）把循环**闭合**：按 RunState 的当前波次建 CombatSimulation
##       （机器 + 这一波敌人 + 伤害结算）→ 交给 MachineDriver 按固定节拍推进 →
##       把敌人画进战场、把 CORE 血量与波次写进状态带读数；
##       本波清空时**非末波**推进波次并进 REWARD（选完奖励回 PREPARATION 继续改造机器），
##       **末波**清空即本局打完，直接进 RESULT。
##       本卡（PET-76）补上**可读反馈**，回答「哪把武器发动 → 打到谁 → 造成什么结果」：
##       武器卡片上缘按武器种类升起一枚开火反馈（三种形态见 BlueprintWorkspace 的 CUE_*）→
##       一条 1px 弹道连到被打中的敌人 → 命中点一枚 2×2 闪光、敌人身体抖 1px、血条真的变短 →
##       被打死时尸体外面多一圈 1px 描边。
##       这些**全部是读仿真的只读状态画出来的** —— 本文件不重算伤害、不重算选目标、不改任何数值，
##       于是「画得对不对」永远不会反过来影响「跑得对不对」。
## 所属系统：ui
## 依赖：Palette、Theme、GameFlow、RunState、CombatLayout、InputScreen、MachineRuntime、MachineDriver、
##       CombatSimulation、EnemyState、EnemyData、BlueprintWorkspace
## 禁止：本文件不得调用 change_scene_to_file() —— 场景路由只能由 GameFlow 落地（03 §1.1 R3）；
##       不得写任何字面色值（06 §10.7）—— 全部经 Palette；
##       不得判断任何原始输入事件类型（InputEventMouseButton 等）—— 输入一律经 InputScreen
##       归一后的语义事件（03 §8）；
##       不得自己持有节拍 / 累加器 / 计时构造 —— 时间模型属玩法（03 §2），归 MachineDriver；
##       本文件只负责「把谁交给它」「把结果写到哪个 Label 上」「把敌人画在哪」；
##       不得自己结算伤害 / 生成敌人 / 判死亡 —— 那些全在 CombatSimulation，
##       本文件只按它给的 progress / hp_ratio 换算屏幕位置，一个数值都不改；
##       不得自己判定 Overload（见底 / 哑火 / 回魔全在 MachineRuntime）—— 本场景只把 mana_changed
##       的绝对值印成读数，并按 overload_started / overload_ended 给 `魔力` 那一格换色
##       （分寸见 _show_overheat：**不加格、不加控件、不改几何**，06 §8.1 的五格冻结不动）；
##       不得出现任何需要玩家长按 / 连点的动作控件（00 §5 第 3 条交互硬规则、06 §8）——
##       这条带是状态与预览，COMBAT 阶段玩家不直接操控任何单位。

extends InputScreen

## 可读提示文案。三个出口的目标场景都已落地，这几句只在**路由故障**时出现（场景文件缺失 / 路径写错）。
const NOTICE_WAVE_CLEARED: String = "本波清空后将进入奖励场景（REWARD），该路由未就绪，本次留在战斗场景。"
const NOTICE_CORE_DESTROYED: String = "CORE 被摧毁后将进入结算场景（RESULT），该路由未就绪，本次留在战斗场景。"
## 末波清空走的是「本局打完」这条路，与 CORE 被摧毁同一个去处、但不是同一件事 ——
## 复用上面那句会把玩家引到「我的 CORE 炸了？」这个错误方向。
const NOTICE_FINAL_WAVE: String = "最后一波清空后将进入结算场景（RESULT），该路由未就绪，本次留在战斗场景。"
## Escape 出口的路由故障提示。与上一条分开：那条讲的是「CORE 被摧毁」，
## 而这里玩家按的是 Escape，提示说成 CORE 被摧毁会把人引到错误的方向。
const NOTICE_ESCAPE: String = "结算场景（RESULT）的路由未就绪，本次留在战斗场景。"
## 还没有机器可跑。这是**首次进游戏的正常情况**（玩家没拖过节点），不是错误，故只提示不报错。
const NOTICE_NO_MACHINE: String = "本局还没有法术书：先在整备界面拖出核心卡与能力卡并连好线，再开始战斗。"
## 有图但没有核心卡。给一句可读的解释，免得玩家对着不动的法术书猜是卡住了还是没接线。
const NOTICE_NO_CORE: String = "这本法术书里没有核心卡，不会有魔力流动 —— 补一张核心卡再开战。"

## 机器示意区的高度：24px 网格上的 2 行，贴战场下沿。上方的空档留给占位弹丸上升，
## 也留给敌人生成与推进区（PET-65）。
const MACHINE_VIEW_HEIGHT: float = 96.0

## 敌人推进区的绘制参数。**全部是表现层的事** —— 玩法侧的推进用归一化 progress
## （见 EnemyState），改这里的数不会改变任何一局的胜负。
##
## 坐标以**战场局部坐标**为准：敌人层铺满战场且原点与战场重合（_place_machine_view 保证），
## 于是「第几个像素」可以直接读，像素取证不必再换算一次。
const ENEMY_BAND_TOP: float = 64.0
## 一条道占的高度：标签 10px + 身体最长 8px。两条道 = 48px。
const ENEMY_ROW_HEIGHT: float = 48.0
## 标签基线在一条道内的偏移，身体顶边在道内的偏移。
const ENEMY_LABEL_BASELINE: float = 16.0
const ENEMY_BODY_TOP: float = 20.0
const ENEMY_LABEL_FONT_SIZE: int = 16
## 敌人层与机器示意区之间留的缝：贴太近会让最后一条道看起来像压在机器上。
const ENEMY_BAND_GAP: float = 12.0
## 两种敌人的身体边长。Slime 大（慢、血多），Runner 小（快、血少）——
## 用尺寸区分而不是再加一组颜色，是因为 04 §3.7 已把红色定成「危险」语义色，
## 在同一个语义里再拆两种红只会让人以为是两种危险等级。
const ENEMY_SLIME_SIZE: float = 16.0
const ENEMY_RUNNER_SIZE: float = 12.0
## HP 条的厚度与它离身体顶边的缝（条画在身体**上方**，落在战场底色上而不是压在身上）。
const ENEMY_HP_HEIGHT: float = 4.0
const ENEMY_HP_GAP: float = 6.0

## ── 可读反馈（PET-76）──────────────────────────────────────────────────────
## 13 §5：FIRST PLAYABLE 只要求玩家看清「哪把武器发动 → 攻击谁 → 造成什么结果」，
## 少量 命中闪光 / 弹道 / 状态提示 即可，**不得**堆巨量粒子 / 全屏闪光 / 大面积特效 / 伤害数字。
## 于是这里只有三样东西（枪口反馈在 BlueprintWorkspace 画），且全是**表现层**的事 ——
## 改这些数不改变任何一局的胜负。
##
## 命中闪光是一枚 2×2 的点，存活 3 拍。**不扩散、不放大**：它要回答的是「这一下打在这只身上」，
## 扩散成一团就会盖住敌人 8×8 的身体色，反而看不出是哪一只挨了打。
const IMPACT_SIZE: float = 4.0
const IMPACT_TICKS: int = 3
## 受击抖动：命中当拍起把身体上下抖 1px，抖 3 拍（奇偶交替，见 _hit_shake_of）。
##
## 用**抖动**而不是「把整只闪白」当主要的受击信号：敌人身体本身就是 04 §3.7 的危险红，
## 整只闪白的那一帧里「这是哪只敌人、还剩多少血」全被吃掉。白光只留 2×2 那么一点，
## 既给出命中点，又不遮盖体型与体色。
const HIT_SHAKE_TICKS: int = 3
## 击杀描边相对尸体的外扩量（像素）。
const KILL_MARK_GROW: float = 2.0

@onready var _backdrop: ColorRect = %Backdrop
@onready var _battlefield: Control = %Battlefield
@onready var _enemy_layer: Control = %EnemyLayer
@onready var _machine_view: BlueprintWorkspace = %MachineView
@onready var _driver: MachineDriver = %MachineDriver
@onready var _status_bar: Control = %StatusBar
@onready var _status_fill: ColorRect = %StatusFill
@onready var _status_edge: ColorRect = %StatusEdge
@onready var _notice_label: Label = %NoticeLabel

## 读数区的**权重分层**落在场景里（标题明暗 + 读数字号），不在这里 —— 它是静态装配，
## 归 tests/unit/test_combat.gd 钉。分层口径（13 §5「不要让五块 HUD 像五个同等级菜单按钮」
## 与 06 §8.1 的五格冻结取交集）：
##   一级 = `波次` / `CORE` / `魔力` —— 正是 §5 点名的一级 `WAVE` · `CORE / HP` · `HEAT`
##          （PET-82 把 `HEAT` 那一格换成了 `魔力`，层级与格数一动不动）；
##   二级 = `能力位` / `队列` —— §8.1 冻结的五格里，§5 的一级没有点到的就剩这两个。
## 注意 §5 的二级是 `GOLD` / `NEXT`，那两块**不在** §8.1 的五格内，故本卡不把它们塞进来 ——
## 见交付说明里向 DSH 提的结构问题。
##
## 06 §8.1 的 `魔力` 读数格（PET-82：原 `热量`）。取的是读数块里那个叫 `Value` 的 Label。
## **不能**给这个 Label 挂 unique_name：5 个读数块的 Value 同名，`%Value` 只会命中其中一个，
## 而各用例正是按名字 `Value` 逐块找它的。故唯一名挂在读数块（`Mana`）上，再往下走一级。
@onready var _mana_value: Label = %Mana.get_node(^"Value") as Label

## 06 §8.1 的 `CORE` 读数格。同 `_mana_value` 的理由：唯一名挂在读数块（`Core`）上，再往下走一级。
## **这一格的语义没变**：它量的是玩家基地的血量（敌人漏过来就掉），
## 与 NodeData 里那个「信号源」曾经共用 CORE 这个词是巧合 —— 信号源已改叫核心卡（PET-82），
## 而这一格照旧。把两件事都改叫魔力会让人以为「魔力掉光 = 本局失败」，那是两回事。
@onready var _core_value: Label = %Core.get_node(^"Value") as Label

## 06 §8.1 的 `波次` 读数格。同上：唯一名挂在读数块（`Wave`）上，再往下走一级。
@onready var _wave_value: Label = %Wave.get_node(^"Value") as Label

## `魔力` 格的标题。过载时连标题一起换色 —— 只换读数的话，在一条五格同形的带里
## 那点色差读不出「这一格进了另一个状态」。
@onready var _mana_caption: Label = %Mana.get_node(^"Caption") as Label

## 06 §8.1 的 `能力位` 读数格（PET-82：原 `能量`）。同上：唯一名挂在读数块（`AbilitySlots`）上，
## 再往下走一级。见 _show_ability_slots 说明它为什么不再是原来那个恒为 0% 的死格子。
@onready var _ability_slots_value: Label = %AbilitySlots.get_node(^"Value") as Label

## 两块区域容器，下标即 CombatLayout.Region。顺序必须与场景里的节点顺序一致。
var _regions: Array[Control] = []
var _is_narrow: bool = false

## 本局正在跑的仿真。没有机器时为 null —— 此时战场上什么都不画（敌人生成也归它管）。
var _simulation: CombatSimulation = null

## 绘制用的判据色。在 _ready() 里从 Palette 取一次（06 §10.7：色值只有一个来源）。
var _slime_color: Color = Color.BLACK
var _runner_color: Color = Color.BLACK
var _hp_missing: Color = Color.BLACK
var _hp_fill: Color = Color.BLACK
var _enemy_label_color: Color = Color.BLACK

## 可读反馈（PET-76）的判据色。同上面几个：在 _ready() 里从 Palette 取一次（06 §10.7）。
var _tracer_color: Color = Color.BLACK
var _impact_color: Color = Color.BLACK
var _kill_color: Color = Color.BLACK

## 这一拍开火的武器（按 ability_cast 到达的顺序）。由 _on_simulation_ticked 消费后清空 ——
## 开火那一刻还不知道打中了谁，故**先记下、后配对**，而不是在回调里就地画一根弹道。
var _fired: Array[StringName] = []

## 在途弹道：{from, to, age}。age 到 MachineRuntime.SHOT_TICKS 即消失。
var _tracers: Array[Dictionary] = []

## 命中闪光：{at, age}。age 到 IMPACT_TICKS 即消失。
var _impacts: Array[Dictionary] = []

## 受击抖动：EnemyState → 已抖拍数。
##
## **键就是 EnemyState 本身，不用 get_instance_id()**：RefCounted 一旦释放，它的 id 会被
## 下一个对象复用，新生成的敌人于是可能继承上一只的旧血量 —— 症状是「刚出场就掉血」，
## 一根凭空出现的弹道，而且只在特定的帧序下复现。用对象本身当键则顺便持有一份引用，
## 旧对象在退场那一拍被清掉之前不会被释放，复用无从发生。
var _hit_shake: Dictionary = {}

## 每只敌人**上一拍结束时**的血量，键同 _hit_shake。命中取证的全部依据就是它：
## 这一拍比上一拍少，就是这一拍挨了打（见 _note_hits）。
var _hp_before: Dictionary = {}


func _ready() -> void:
	# 底色全部取自 Palette —— 场景里那几个 ColorRect 不带 color 字面量（06 §10.7）。
	# 06 §8：状态带底色 NAVY_800、上沿 1px NAVY_600 分隔。用两块纯色 ColorRect 而不是 Panel 变体，
	# 是因为 §8 只给这一条上沿；主题里最接近的 PanelCore 是**四边**各 1px NAVY_600，
	# 套上去会在带的下沿与左右两侧多出三条 §8 没规定的描边。
	_backdrop.color = Palette.get_color(Palette.Key.NAVY_900)
	_status_fill.color = Palette.get_color(Palette.Key.NAVY_800)
	_status_edge.color = Palette.get_color(Palette.Key.NAVY_600)
	# 敌人用 04 §3.7 的「危险」红：Slime 取暗调（大面积底色）、Runner 取亮调（图标级）。
	# HP 条按同一条规则拆两段：缺失段 RED_600、已损段 RED_500。小号名字用 GREY_300（正文色），
	# 战场底是全屏的 NAVY_900，对比度足够，不必再加描边层。
	_slime_color = Palette.get_color(Palette.Key.RED_600)
	_runner_color = Palette.get_color(Palette.Key.RED_500)
	_hp_missing = Palette.get_color(Palette.Key.RED_600)
	_hp_fill = Palette.get_color(Palette.Key.RED_500)
	_enemy_label_color = Palette.get_color(Palette.Key.GREY_300)
	# 可读反馈（PET-76）。弹道取 FX 体色（04 §3.10：它和机器视图里的火花是同一类东西 ——
	# 一次「事件」，不是一种「物体」）；命中闪光取 WHITE（整幕 COMBAT 里只有它会画白，
	# Label 的正文色是 BLUE_100）；击杀描边取 FX 芯色，与尸体自身的红拉开最大的明度差。
	_tracer_color = Palette.get_color(Palette.Key.BLUE_FX_600)
	_impact_color = Palette.get_color(Palette.Key.WHITE)
	_kill_color = Palette.get_color(Palette.Key.BLUE_050)
	# 06 §8.1 硬规则 1 明写「**分格之后才允许**分别套 Heat 橙 / Energy 蓝」——
	# 这两格既已分格（硬规则 1 的另一半是不得合并），就把语义色落上：
	# `能力位` 取 BLUE_300（04 §3.8 的蓝组：能量 / 激活语义），`魔力` 的常态色在
	# _show_overload(false) 里给（它与过载态是同一个取色入口，不在这里另写一份）。
	_ability_slots_value.add_theme_color_override(&"font_color", Palette.get_color(Palette.Key.BLUE_300))
	# 敌人的重绘挂在敌人层的 draw 信号上：绘制命令必须落在**这一层**上，
	# 落在本节点上会被 Backdrop 与机器视图盖住（父节点先于子节点绘制）。
	_enemy_layer.draw.connect(_draw_enemies)
	_regions = [_battlefield, _status_bar]
	_notice_label.visible = false
	# 折叠由可用区尺寸驱动，不用计时器、也不轮询（03 §2）。
	resized.connect(_on_resized)
	apply_layout_for(size)
	# 布局先落定（示意区要先有尺寸才能给节点落格），再建机器。
	reload_machine()


## 载入工作区落盘的蓝图，重建机器并交给 MachineDriver。_ready() 与「换蓝图后重进战斗」都走这一个入口。
##
## 没有机器不是异常：玩家可能一次都没进过整备界面。三种情况各给一句可读提示，
## 而不是让画面沉默 —— 沉默在验收时和「跑起来了但没画出来」完全分不开。
func reload_machine() -> void:
	_machine_view.reload()
	_driver.bind(null)
	_simulation = null
	# 反馈账簿跟着仿真一起清零：上一局的弹道与闪光若留着，新一局的头几拍会凭空多出几笔
	# 指向不存在的敌人的线，而那几拍恰好是玩家确认「这一局跑起来了」的时刻。
	_fired.clear()
	_tracers.clear()
	_impacts.clear()
	_hit_shake.clear()
	_hp_before.clear()
	_notice_label.visible = false
	# COMBAT 永远属于某一局：没有进行中的一局就先开一局。波次读数与「末波清空 → RESULT」
	# 都靠 RunState 那一份进度，而本场景是全项目**唯一**读它的玩法场景 —— 开局放在这里，
	# 就不必让主菜单 / 整备两处各记一次（那两个场景不在本卡范围内）。
	# 上一局在 COMBAT 里结束时已经 end_run()，故这里同时兼顾「再来一局」与「回主菜单后再开」。
	if not RunState.is_active():
		RunState.start_run()
	var wave: int = RunState.current_wave()
	_show_wave(wave)
	_show_mana(MachineRuntime.MANA_MAX)
	_show_overload(false)
	_show_core_hp(CombatSimulation.CORE_MAX_HP)
	_show_ability_slots(null)
	# 读数归零之后必须重画一次敌人层：上一局的尸体否则会留在屏幕上，
	# 直到本局第一次 tick 才被擦掉 —— 那一段空白里玩家会以为新一局「有敌人但不动」。
	_enemy_layer.queue_redraw()
	var blueprint: BlueprintData = _machine_view.blueprint()
	if blueprint == null or blueprint.nodes.is_empty():
		_show_notice(NOTICE_NO_MACHINE)
		return
	# 图由工作区持有并绘制（06 §8 / 03 §4.3：蓝图在 COMBAT 是只读的），仿真只借用它建索引。
	var simulation := CombatSimulation.new(blueprint, wave)
	_simulation = simulation
	var machine: MachineRuntime = simulation.machine()
	_machine_view.runtime = machine
	machine.mana_changed.connect(_show_mana)
	# 过载提示的来源：这两个信号是**一次状态变化的通知**，不是每拍心跳
	# （test_mana.gd 已把「过载期间不得反复广播」钉住），故这里按事件换色即可，
	# 不必每拍比对 mana() 去推状态 —— 那会把本场景变成第二个判定过载的地方。
	machine.overload_started.connect(_on_overload_started)
	machine.overload_ended.connect(_on_overload_ended)
	# 重绘挂在本拍推进之后，而不是每帧无条件重画：机器不动时画面就一个像素都不重画。
	machine.ticked.connect(_machine_view.queue_redraw)
	# 开火与命中要画在**同一帧**里（见 _on_ability_cast / _on_simulation_ticked）：
	# 前者只记下本拍开了火的武器，真正的绘制等本拍全部推进完再一起做。
	machine.ability_cast.connect(_on_ability_cast)
	simulation.ticked.connect(_on_simulation_ticked)
	simulation.core_hp_changed.connect(_show_core_hp)
	# 胜负由仿真判定，出口仍走本场景既有的两个语义入口（03 §1.1 R2 只认这两条边）。
	# 这样 REWARD / RESULT 的路由前置条件（场景是否就绪）依然只在这一处判断。
	simulation.wave_cleared.connect(on_wave_cleared)
	simulation.run_failed.connect(on_core_destroyed)
	_driver.bind_combat(simulation)
	_show_ability_slots(blueprint)
	if not machine.has_core():
		_show_notice(NOTICE_NO_CORE)


## 06 §8.1 的 `魔力` 读数。取整数百分比 —— 读数格只有三位宽（`100%`），小数会被挤掉。
func _show_mana(mana: float) -> void:
	_mana_value.text = "%d%%" % roundi(mana)


## 06 §8.1 的 `能力位` 读数：`已装能力卡 / 能力位总数`，例如 `1/3`。
##
## PET-82 之前这一格叫 `能量`，**整局恒为 0%**（todo R8 的原话就是「一个永远不动的读数」）——
## 一个从不变化的格子读起来不像状态，像坏掉的控件。本卡把它接到一个真实存在的量上：
## 玩家的法术书装了几张能力卡。只做三件事，没有任何新系统：
##   · 分母 = WAREHOUSE 里 kind 为能力卡的槽位数（法术书**本来就有**三张能力卡槽）；
##   · 分子 = 蓝图里 kind 为能力卡的节点数（玩家**本来就能**拖出来）；
##   · 两者都在既有数据里，不新增任何字段、不新增任何玩法。
##
## 取 `1/3` 而不是 `33%`：波次那一格已经用了「当前/总数」这种读法，同一块读数带上
## 两种「部分/整体」的写法会让人以为它们量的不是一回事；而 `1/3` 直接说出「还空着两格」，
## 百分比说不出这句话。
##
## 说明：本波之内它是常量（COMBAT 里图是只读的），**跨波才变** ——
## 这不违背 R8 的诉求：那个诉求是「格子里得有一个真的量」，而不是「每拍都要跳一下」。
## 每拍都在动的是 `魔力` 那一格，两格分工不同。
func _show_ability_slots(blueprint: BlueprintData) -> void:
	_ability_slots_value.text = "%d/%d" % [ability_slot_used(blueprint), ability_slot_capacity()]


## 法术书有几个能力位。分母取自 WAREHOUSE **本身**，不在这里写死一个 3 ——
## 写死的话，哪天仓库加减一张能力卡槽，画面会继续印 `1/3`，而玩家手里已经有四张槽。
static func ability_slot_capacity() -> int:
	var total: int = 0
	for entry: Dictionary in BlueprintWorkspace.WAREHOUSE:
		if int(entry["kind"]) == NodeData.Kind.ABILITY:
			total += 1
	return total


## 这本法术书已经装了几张能力卡。蓝图为空（首次进游戏）时为 0。
static func ability_slot_used(blueprint: BlueprintData) -> int:
	if blueprint == null:
		return 0
	var used: int = 0
	for node: NodeData in blueprint.nodes:
		if node.kind == NodeData.Kind.ABILITY:
			used += 1
	return used


## Overload 的可辨识提示（PET-66 遗留项：过载当时在画面上只表现为「魔力 0% 然后涨回去」，
## 与「法术书没接好、压根不施放」在静帧里分不开）。06 §8.1 把这条带冻结成 5 个只读读数块，
## 故这里**不加格子、不加控件、不改任何几何** —— 只给已有的 `魔力` 那一格换色：
##   常态   → 读数 ORANGE_500（04 §3.8「Heat 条、高温」）+ 标题留在正文色
##   过载中 → 标题与读数一起转 ORANGE_300（「爆炸、过热高光」）—— 标题从冷色转暖橙，
##            在一条五格同形的带里一眼能挑出「这一格不在常态」。
##
## 为什么不用 ORANGE_600（它的名字就叫「Overheat 临界」）：在 NAVY_800 带底上只有 2.93:1，
## 04 §3.7 的对比度硬约束不允许拿它当小号文字（RED_500 的 3.21:1 已被判不合格）。
## 因此「更亮」而不是「更深」才是这块底上可用的过载信号。
##
## 取色写成静态纯函数：颜色与状态的对应关系可以脱离场景树单测，
## 不必为了断言一行取色去真跑一次过载（那要几百拍）。
static func mana_readout_color(overloaded: bool) -> Color:
	return Palette.get_color(Palette.Key.ORANGE_300 if overloaded else Palette.Key.ORANGE_500)


func _on_overload_started() -> void:
	_show_overload(true)


func _on_overload_ended() -> void:
	_show_overload(false)


## 切到 / 切回过载态。标题在常态下**移除**覆写而不是写回正文色 ——
## 正文色是 Theme 的事（06 §10.7 一处定义），这里只表达「这一格现在不一样」。
func _show_overload(overloaded: bool) -> void:
	_mana_value.add_theme_color_override(&"font_color", mana_readout_color(overloaded))
	if overloaded:
		_mana_caption.add_theme_color_override(&"font_color", mana_readout_color(true))
	else:
		_mana_caption.remove_theme_color_override(&"font_color")


## 06 §8.1 的 `CORE` 读数。同样是整数百分比（§8.1 硬规则 2：CORE 用百分比，不用自然语言状态词）。
## CORE_MAX_HP 取 100，故血量本身就是百分比，这里不做第二次换算。
func _show_core_hp(core_hp: float) -> void:
	_core_value.text = "%d%%" % roundi(core_hp)


## 06 §8.1 的 `波次` 读数：`当前/总数`。
##
## 06 §8.1 的表里这一格写的是 `1/1` —— 那是「一局只有一波」时期冻结的**占位值**。
## 本卡一局三波，按表里的同一形状拼成 `n/3`：形状不变（读两条数字），内容不再是死的。
## 总数取 RunState.TOTAL_WAVES，不在这里另写一个 3（两处一旦漂开就会拼出 `2/3` 打第 4 波这种读数）。
func _show_wave(current: int) -> void:
	_wave_value.text = "%d/%d" % [current, RunState.TOTAL_WAVES]


## 当前是否处于 06 §7.1 的折叠布局。
func is_narrow_layout() -> bool:
	return _is_narrow


## 按给定可用区尺寸落一次布局。宽屏走 06 §8 的实测值，窄屏走 §7.1 的折叠规则。
##
## 折叠只改变**布局**：不碰 GameFlow、不发信号、不改任何状态
## （06 §7.1 末条「折叠只改变布局，不改变任何玩法规则与状态流」）。
## 因此本函数可以在测试里被显式调用，不必真去改窗口尺寸。
func apply_layout_for(viewport_size: Vector2) -> void:
	_is_narrow = CombatLayout.is_narrow(viewport_size)
	var rects: Array[Rect2] = CombatLayout.narrow_rects(viewport_size) if _is_narrow \
		else CombatLayout.wide_rects()
	for index: int in _regions.size():
		_place(_regions[index], rects[index])
	_place_machine_view(rects[CombatLayout.Region.BATTLEFIELD])


## 机器示意区贴战场**下沿**（06 §8：CORE 运行、武器执行全部可见、可读）。
## 贴下沿而不是铺满：上方的空档正是占位弹丸上升的地方，也是后续卡片敌人生成区的位置。
func _place_machine_view(battlefield: Rect2) -> void:
	var height: float = minf(MACHINE_VIEW_HEIGHT, battlefield.size.y)
	_place(_machine_view, Rect2(battlefield.position.x, battlefield.end.y - height,
		battlefield.size.x, height))
	# 敌人层铺满战场、原点与战场重合 —— 绘制坐标于是与战场坐标是同一套，
	# 「第几像素」可以直接读（像素取证的判据依赖这一点）。
	_place(_enemy_layer, Rect2(Vector2.ZERO, battlefield.size))


func _on_resized() -> void:
	apply_layout_for(size)


## 本波清空 → 两条路（03 §1.1 R2：COMBAT 的出边只有 REWARD 与 RESULT）。
##
## **非末波**：记下进度（RunState.advance_wave，`波次` 读数下一次进本场景就 +1），进 REWARD。
## 玩家选完奖励回 PREPARATION，蓝图原样保留，可以继续改造机器 —— 循环就在这里闭合。
## **末波**：本局打完，进 RESULT（不是 REWARD：打完最后一波还给「三选一」，
## 选完回整备却已经没有下一波可打，那一步是空转）。
##
## 先查路由就绪、再推进波次：路由没通时不能把进度算进去，否则玩家会「白丢一波」。
func on_wave_cleared() -> void:
	if RunState.is_final_wave():
		if not _is_route_ready(GameFlow.GameState.RESULT):
			_show_notice(NOTICE_FINAL_WAVE)
			return
		_end_run()
		return
	if not _is_route_ready(GameFlow.GameState.REWARD):
		_show_notice(NOTICE_WAVE_CLEARED)
		return
	RunState.advance_wave()
	GameFlow.change_state(GameFlow.GameState.REWARD)


## CORE 被摧毁 → RESULT（03 §1.1 R2）。走 request_end_run() 这个语义入口 ——
## R3 把它定为「→ RESULT」的**唯一**合法通道，故这里不绕道 change_state()。
func on_core_destroyed() -> void:
	if not _is_route_ready(GameFlow.GameState.RESULT):
		_show_notice(NOTICE_CORE_DESTROYED)
		return
	_end_run()


## 本局结束：先让 RunState 收尾（它保留**结束时的波次**给 RESULT 显示），再走 R3 的唯一通道。
##
## 收尾这一步不能省：下次进 COMBAT 时会靠 `not is_active()` 判断「该开新的一局了」，
## 少了它，玩家从 RESULT 回主菜单再开局就会接着上一局的波次打（甚至一进去就结算）。
func _end_run() -> void:
	if RunState.is_active():
		RunState.end_run()
	GameFlow.request_end_run()


## Escape：从 COMBAT 退出本局 → RESULT（03 §1 状态图 COMBAT → RESULT）。
##
## 与 on_core_destroyed() 同一个出口、同一个语义入口 request_end_run()（R3 定的唯一通道）。
## COMBAT 在状态图里只有 REWARD / RESULT 两条出边，而 REWARD 的入边被 R2 锁死为「本波清空」
## 这一件事 —— 玩家按 Escape 时并没有清空本波，故「返回」在这里只能是「结束本局」。
## Stage 1 的 COMBAT 没有真实战斗（Stage 1 禁令），也就不存在「误按 Escape 丢掉一整局」的代价。
##
## 留给 Stage 2+：那时 COMBAT 会有暂停菜单，Escape 应先开暂停而不是直接结束本局 ——
## 届时应把这里改成「打开暂停」，并由暂停菜单里的显式按钮走 request_end_run()。
##
## 本场景**不登记 focus root**：06 §8 规定状态带全部为只读 Label、不得新增按钮，
## 没有可导航的控件，方向键在这里本来就无事可做（也不该有事可做）。
func _on_back_requested() -> bool:
	if not _is_route_ready(GameFlow.GameState.RESULT):
		_show_notice(NOTICE_ESCAPE)
		return true
	_end_run()
	return true


## 目标场景是否已就绪。查的是 GameFlow 自己登记的 SCENE_ROUTES（唯一路由来源），
## 不在这里另抄一份路径；待 S1-09 / S1-10 落地、场景文件存在后，本判断自动放行，无需回头改这里。
## 直接请求也不会崩，但 GameFlow 的提交点先落状态再路由、对缺失的场景只打印一行 ——
## 玩家那边看到的是「发生了又没发生」，那正是验收不接受的静默无效。
func _is_route_ready(state: int) -> bool:
	var target_path: String = GameFlow.get_scene_path_for(state)
	return not target_path.is_empty() and ResourceLoader.exists(target_path)


## 显示可读提示。**刻意不用 MessagePanel 模态面板**：06 §10.3 禁止 COMBAT 期间弹出需要
## 玩家即时反应的模态窗口，而这条提示只是告知「出口还没做好」，不该打断对战场运行结果的观察。
## key 为 tr() 的原文 key（暂无翻译表，06 §11）。
func _show_notice(message_key: String) -> void:
	_notice_label.text = tr(message_key)
	_notice_label.visible = true


## 把这一拍的敌人画到战场上。挂在 EnemyLayer 的 draw 信号上 —— 绘制命令必须落在**那一层**，
## 落在本节点上会被 Backdrop 与机器视图盖住（父节点先于子节点绘制）。
##
## 不读真实时间、不读帧数：位置只由 progress 与 tick 决定，于是同一拍画出来逐像素相同
## （像素取证要求取样可复现）。
func _draw_enemies() -> void:
	if _simulation == null:
		return
	var band_bottom: float = _machine_view.position.y - ENEMY_BAND_GAP
	if band_bottom - ENEMY_BAND_TOP < ENEMY_ROW_HEIGHT * float(CombatSimulation.LANES):
		# 战场被压得太矮（06 §7.1 折叠到极端尺寸）：宁可这一档不画，也不要把两条道糊成一团 ——
		# 糊在一起时「敌人在哪条道上」反而看不出，比空着更糟。
		return
	var tick: int = _simulation.tick_index()
	# 顺序即层次：弹道在敌人**之下**（它从武器飞过来，末端被身体挡住才像「打进去」），
	# 命中闪光在敌人**之上**（它标的就是身体上那一点）。反过来画，两者都会被身体吃掉。
	_draw_tracers()
	for enemy: EnemyState in _simulation.enemies():
		_draw_enemy(enemy, tick)
	_draw_impacts()


## 一只敌人身体在敌人层坐标系里的矩形。**绘制与命中取证共用这一个换算** ——
## 两处各写一份的话，弹道的落点与屏幕上那块红迟早会错开，而症状只是「线没打中」。
func _body_rect(enemy: EnemyState) -> Rect2:
	var data: EnemyData = enemy.data
	if data == null:
		return Rect2()
	var body: float = ENEMY_SLIME_SIZE if data.kind == EnemyData.Kind.SLIME else ENEMY_RUNNER_SIZE
	# 右 → 左：progress 0 在战场右缘，1 在左缘（CORE 那一侧）。
	var left: float = lerpf(_enemy_layer.size.x - body, 0.0, enemy.progress)
	var top: float = ENEMY_BAND_TOP + float(enemy.lane) * ENEMY_ROW_HEIGHT + ENEMY_BODY_TOP
	return Rect2(left, top, body, body)


## 这一拍该把这只敌人的身体向下 / 向上偏几像素。没在抖就是 0。
##
## 奇偶交替（1px 下、-1px 上、再 1px 下）—— **不读随机数**：抖动只是「刚挨了一下」的视觉标记，
## 用了随机数，同一份蓝图在不同机器上就画不出同一张截图，像素取证再也没法比对（03 §6）。
## 偏移量固定 ±1px：敌人在一条 24px 高的道里只占 8px，抖更多会跨道，读起来像换了条道。
func _hit_shake_of(enemy: EnemyState) -> float:
	if not _hit_shake.has(enemy):
		return 0.0
	return 1.0 if int(_hit_shake[enemy]) % 2 == 0 else -1.0


## 在途弹道：一根 1px 的线，从开火那张卡片的上缘连到被打中的敌人的身体中心。
## 线宽取 1px 且不开抗锯齿（默认值）—— 抗锯齿会让边缘像素变成半透明的过渡色，
## 于是「这根线是什么颜色」在取色时变得没有确切答案。
func _draw_tracers() -> void:
	for tracer: Dictionary in _tracers:
		_enemy_layer.draw_line(tracer["from"], tracer["to"], _tracer_color, 2.0)


## 命中点的一枚短促闪光。画在敌人**之上**（在 _draw_enemy 之后调用），
## 否则会被敌人身体整个盖住 —— 而它要标的正是身体上挨打的那一点。
func _draw_impacts() -> void:
	for impact: Dictionary in _impacts:
		var at: Vector2 = impact["at"]
		_enemy_layer.draw_rect(Rect2(
			(at - Vector2(IMPACT_SIZE, IMPACT_SIZE) * 0.5).floor(),
			Vector2(IMPACT_SIZE, IMPACT_SIZE)), _impact_color)


func _draw_enemy(enemy: EnemyState, tick: int) -> void:
	var data: EnemyData = enemy.data
	if data == null:
		return
	var rect: Rect2 = _body_rect(enemy)
	var color: Color = _slime_color if data.kind == EnemyData.Kind.SLIME else _runner_color
	var age: int = enemy.death_age(tick)
	if age >= 0:
		_draw_vanishing(rect, age, color)
		return
	# 受击抖动只抖**身体**：血条与名字留在原地 —— 它们要回答的是「还剩多少、这是什么」，
	# 跟着一起抖只会让这两件事在抖动的那几拍里更难读。
	var shaken := rect
	shaken.position.y += _hit_shake_of(enemy)
	_enemy_layer.draw_rect(shaken, color)
	_draw_health(enemy, rect.position.x, rect.position.y, rect.size.x)
	_draw_name(data.display_name, rect.position.x, rect.size.x,
		ENEMY_BAND_TOP + float(enemy.lane) * ENEMY_ROW_HEIGHT)


## 死亡后的占位消失动画：绕中心收缩到 1px，VANISH_TICKS 拍后被仿真移除。
## 用**收缩**而不是淡出 —— 320×180 的像素画里半透明只会得到一团糊块，
## 而「缩掉了」在一张静止的截图里也读得出是在消失。
##
## PET-76 在尸体外面套一圈 1px 描边（04 §3.10 的 FX 芯色），把「被打死了」与「挨了一下」分开：
## 受击是身体**里面**多一枚 2×2 的白点，击杀是身体**外面**多一圈框 —— 内点 / 外框，
## 形状不同，于是在一张静止的截图里也分得开，不必靠颜色去猜。
func _draw_vanishing(rect: Rect2, age: int, color: Color) -> void:
	var center: Vector2 = rect.get_center()
	var side: float = maxf(rect.size.x * (1.0 - float(age) / float(CombatSimulation.VANISH_TICKS)), 1.0)
	var body := Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side))
	_enemy_layer.draw_rect(body, color)
	_enemy_layer.draw_rect(body.grow(KILL_MARK_GROW), _kill_color, false, 2.0)


## 武器开火 → 只**记下**这一拍开了火的武器，不在这里画。
##
## 此刻本拍还没结算完（ability_cast 是在 machine.tick() 里发的，伤害结算挂在同一条链上），
## 于是这一刻还不知道打中了谁。等 simulation.ticked（本拍全部推进完毕）再一起画，
## 「哪把武器发动」与「打到谁」才会出现在**同一帧**里，而不是一先一后。
func _on_ability_cast(ability_id: StringName) -> void:
	_fired.append(ability_id)


## 本拍推进完毕：先把上一拍画的东西变老、清掉过期的，再按本拍的掉血情况补上新的记录。
func _on_simulation_ticked() -> void:
	_age_feedback()
	_note_hits()
	_enemy_layer.queue_redraw()


## 反馈的存活期一律按**拍数**算，不按帧（03 §6）：帧率高低只决定你看到其中几帧，
## 不决定一根弹道在几拍之后消失 —— 同一份蓝图在任何机器上取样都得到同一张图。
func _age_feedback() -> void:
	_tracers = _aged(_tracers, MachineRuntime.SHOT_TICKS)
	_impacts = _aged(_impacts, IMPACT_TICKS)
	for enemy: Variant in _hit_shake.keys():
		var age: int = int(_hit_shake[enemy]) + 1
		if age >= HIT_SHAKE_TICKS:
			_hit_shake.erase(enemy)
		else:
			_hit_shake[enemy] = age


## 把记录表里每条的 age 加一，丢掉活到头的那几条。表很小（同屏最多几笔），重建比原地删简单。
func _aged(records: Array[Dictionary], life: int) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for record: Dictionary in records:
		record["age"] = int(record["age"]) + 1
		if int(record["age"]) < life:
			kept.append(record)
	return kept


## 本拍谁挨了打 —— 全部依据就是**血量比上一拍少**。
##
## 为什么不去问仿真「谁打了谁」：选目标的规则（单体打最靠前的、范围打全部、近战只打贴脸的）
## 全在 CombatSimulation 里，在 UI 里再实现一遍就是第二份真相 —— 两份一旦漂开，
## 画面上会出现一根指向**错**敌人的弹道，而那正是本卡要治的病。
## 观测式的代价是「哪把武器打的」只能配对（见下），这是本卡明确接受的取舍。
func _note_hits() -> void:
	var fired: Array[StringName] = _fired
	_fired = []
	var hits: Array[EnemyState] = []
	var alive: Dictionary = {}
	for enemy: EnemyState in _simulation.enemies():
		alive[enemy] = true
		var before: float = _hp_before.get(enemy, enemy.hp)
		if enemy.hp < before:
			hits.append(enemy)
		_hp_before[enemy] = enemy.hp
	# 退场的敌人连键一起清掉。不清的话这份表会随每一波单调变长，更要紧的是**留着旧键有害** ——
	# 见 _hit_shake 上关于「对象当键」的那段。
	for enemy: Variant in _hp_before.keys():
		if not alive.has(enemy):
			_hp_before.erase(enemy)
	if hits.is_empty():
		return
	# 配对：本拍第 i 个掉血的敌人，配本拍第 i 把开火的武器（取模）。
	# 这是**表现层的配对**，不是伤害归属的重算 —— 一发炸弹打中三只时武器只有一把、
	# 命中点有三个，三根弹道于是全部从那一张卡出发，恰恰就是画面该说的话。
	for index: int in hits.size():
		var target: EnemyState = hits[index]
		var at: Vector2 = _body_rect(target).get_center()
		_impacts.append({"at": at, "age": 0})
		_hit_shake[target] = 0
		if fired.is_empty():
			continue
		var box: Rect2 = _machine_view.card_rect(fired[index % fired.size()])
		if box.size.x <= 0.0:
			# 开火的武器在视图里没有卡片（未落格 / 已被删掉）。画不出起点就不画这根线 ——
			# 从 (0,0) 拉一根到敌人身上的线会让玩家以为机器接错了。
			continue
		_tracers.append({"from": _muzzle_point(box), "to": at, "age": 0})


## 武器卡片上缘中点，换算到**敌人层坐标系**。
##
## MachineView 与 EnemyLayer 是战场下的两个兄弟，且敌人层原点与战场重合，
## 故「机器视图局部坐标 + 机器视图在战场里的位置」就是敌人层坐标。
## 这个换算留在本文件而不是 BlueprintWorkspace：知道这两层是兄弟的是**本场景的装配**，
## 工作区不该知道自己被摆在哪儿 —— 它在整备界面里是另一个位置。
func _muzzle_point(box: Rect2) -> Vector2:
	return _machine_view.position + Vector2(
		box.position.x + BlueprintWorkspace.CARD * 0.5, box.position.y)


## HP 条：画在身体**上方**那条缝里，落在战场底色上而不是压在身上（压在深红身体上分不出深浅）。
## 两段色取 04 §3.7 对 HP 条的规定：缺失段 RED_600、已损段 RED_500。
func _draw_health(enemy: EnemyState, left: float, body_top: float, body: float) -> void:
	var top: float = body_top - ENEMY_HP_GAP - ENEMY_HP_HEIGHT
	_enemy_layer.draw_rect(Rect2(left, top, body, ENEMY_HP_HEIGHT), _hp_missing)
	_enemy_layer.draw_rect(Rect2(left, top, body * enemy.hp_ratio(), ENEMY_HP_HEIGHT), _hp_fill)


## 名字标签。以身体中心对齐后再**夹进战场**：敌人刚出场时贴着右缘，
## 不夹的话名字有一截在画外 —— 而那正是玩家第一次需要认出它是 Slime 还是 Runner 的时刻。
func _draw_name(text: String, left: float, body: float, row_top: float) -> void:
	var font: Font = get_theme_default_font()
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		ENEMY_LABEL_FONT_SIZE).x
	var label_x: float = clampf(left + body * 0.5 - width * 0.5, 0.0, _enemy_layer.size.x - width)
	_enemy_layer.draw_string(font, Vector2(label_x, row_top + ENEMY_LABEL_BASELINE), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, ENEMY_LABEL_FONT_SIZE, _enemy_label_color)


## 把区域贴到矩形上。区域都是场景根下的普通 Control（非容器），故直接给位置与尺寸。
func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
