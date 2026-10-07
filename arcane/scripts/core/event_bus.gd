## event_bus.gd
## 职责：全局信号总线 —— 只承载跨系统事件，自身不持有任何状态（docs/03 §3）。
## 所属系统：core
## 依赖：无
## 禁止：本文件不得声明任何成员变量、不得读取任何游戏数据。

extends Node

## 顶层状态机完成一次切换时触发。参数取自 GameFlow.GameState；
## 此处用 int，以免总线反向依赖状态机实现（docs/03 §10 依赖方向）。
signal state_changed(from: int, to: int)

## 玩家在模块编辑器里改动了书页（放置 / 移动 / 连线 / 删除）时触发。
## 战斗仿真是**只读**卡牌的（docs/03 §4.3），故它只监听本信号做失效标记，不回写结构。
signal board_changed()

## 一局的进度发生变化（波次推进 / 本局结束）时触发。
signal run_progress_changed()
