## event_bus.gd
## 职责：全局信号总线 —— 只承载跨系统事件，自身不持有任何状态。
## 所属系统：core
## 依赖：无
## 禁止：本文件不得声明任何成员变量、不得读取任何游戏数据（03_ARCHITECTURE.md §3）。

extends Node

## 顶层状态机完成一次切换时触发（03_ARCHITECTURE.md §1.1 R4）。
## 参数取自 GameFlow.GameState；此处用 int 以免 bus 反向依赖状态机实现。
signal state_changed(from: int, to: int)
