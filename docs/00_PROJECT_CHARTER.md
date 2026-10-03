# 00 — 项目章程（PROJECT CHARTER）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 v0.1.0｜冻结日 2026-10-03｜维护者 DSH
> 本文件是 PixelFusion 的最高层契约。与本文件冲突的任务说明、代码、素材一律以本文件为准（优先级见 `08_AGENT_RULES.md` §7）。

## 1. 项目身份

| 项目 | 值 |
|---|---|
| 中文名 | 像素融合屋 |
| 英文名 / 代号 | PixelFusion |
| 类型 | 像素风 Roguelike · 自动战斗 · 蓝图构筑 |
| 引擎 | **Godot 4.x Stable** |
| 语言 | **GDScript**（静态类型优先） |
| 目标平台 | 双端：Desktop（Windows 优先）+ Mobile（触摸） |
| Web 版本 | Godot **Web Export**（不是 HTML/JS 重写） |
| 正式项目路径 | `D:\GameDev\PixelFusion` |
| 临时目录 | `D:\Temp\PixelFusion` |
| 构建输出 | `D:\GameDev\PixelFusion\build` |
| 测试输出 | `D:\GameDev\PixelFusion\tests\output` |
| 开发文档 | `D:\GameDev\PixelFusion\docs` |

## 2. 一句话定义

玩家坐在浮空岛工坊里，像工程师一样搭建一条自动战斗流水线（**蓝图**），然后亲手按下「开始战斗」，观察自己设计的机器把敌人成批粉碎。

## 3. 核心体验支柱

1. **构筑即决策** — 所有乐趣压力在 PREPARATION 阶段释放：节点摆放、连线、资源分配。
2. **观察即反馈** — COMBAT 阶段玩家不操作角色，只观察机器的运行结果，并从中读懂自己蓝图的对错。
3. **失败可归因** — 战败必须能被玩家解释成「我某个节点/连线/配比错了」，而不是「随机数搞我」。
4. **温暖精致** — 日式 Q 版幻想工坊气质：浮空岛、机械、蓝图、暖光，清爽不堆料。

## 4. 核心循环

```
MAIN_MENU → PREPARATION →（玩家点击「开始战斗」）→ COMBAT → REWARD → PREPARATION → … → RESULT
```

- PREPARATION：**时间停止**，敌人不存在，不战斗、不发射、不扣血。整个主屏服务于蓝图配置。
- COMBAT：蓝图主界面让位，战斗画面占据主区域。敌人生成、推进，CORE 运行，武器执行，Heat 计算。
- REWARD：结算本波奖励，玩家选择后回到 PREPARATION 重新整理机器。

## 5. 三条不可动摇的交互硬规则

1. 进入 PREPARATION 后 **永远等待玩家**；禁止自动倒计时、自动开怪、自动开始下一波。
2. 只有 `PREPARATION → COMBAT` 由玩家点击「开始战斗」触发。
3. COMBAT 阶段玩家不直接操控单位；玩家的一切影响都必须在进入战斗前已经写进蓝图。

## 6. 技术基线（不可协商）

- 引擎：Godot 4.x Stable；语言：GDScript。
- **禁止**：C#、Unity、Unreal、Electron、GDExtension、以 HTML/JS 作为正式游戏主体、不必要的第三方框架、付费插件。
- 数据与逻辑分离：武器 / 节点 / 敌人 / 波次数值走 Godot `Resource`（`.tres`），不得写死在逻辑里。
- 跨系统通信走 Signal / EventBus。
- 双端输入（键鼠 + 触摸）从 Stage 1 起就必须同时可用，不得「先做 PC 以后再补手机」。

## 7. 开发阶段路线图

| 阶段 | 名称 | 交付物 | 退出条件 |
|---|---|---|---|
| **Stage 0** | PROJECT FOUNDATION | `docs/00`~`12` 全部约束文档 + STORAGE GATE | **用户明确批准** |
| Stage 1 | PROJECT SKELETON | Boot→Menu→Preparation→Combat→Reward→Preparation 完整状态循环（允许占位图） | 用户验收状态机可跑通 |
| Stage 2 | BLUEPRINT BASE | 蓝图工作区：节点放置、连接、删除、存档数据结构 | 验收蓝图编辑闭环 |
| Stage 3 | CORE / FUNCTION / WEAPON | 三类节点 + 信号传播与执行顺序 | 验收信号在生产环境可预测 |
| Stage 4 | COMBAT LAYER | 敌人、战斗、波次、Heat、Energy | 验收完整一局可玩 |
| Stage 5 | ART REPLACEMENT | Codex 正式素材逐批替换（逐批用户审批） | 用户批准每批素材 |

阶段不得跳级。任何 Agent 不得提前实现后续阶段内容。

## 8. 范围边界

### 8.1 本期包含
蓝图构筑 · 自动战斗 · 波次推进 · 奖励选择 · 节点/武器/敌人数据驱动 · 双端输入 · 存档（本地）。

### 8.2 明确不包含（无需讨论，禁止实现）

商店 · 剧情/对话系统 · 角色养成 · 联机 · 账号系统 · 每日任务 · 成就 · 云存档 · 排行榜 · 内购 · 关卡编辑器 · 模组支持 · 多语言（先只做简体中文，但文本必须走 key，不得硬编码在场景里）。

任何 Agent 不得以「顺便做了」的形式引入以上内容（见 `08_AGENT_RULES.md` §5）。

## 9. 变更控制

- 本文档的任何修改必须由 DSH 记录进 `12_CHANGELOG.md`，并在注释中说明「改了什么 / 为什么 / 影响哪些文档」。
- 涉及**整体视觉方向、玩法循环、技术基线**的修改，必须重新提交用户确认。
- 已冻结文档在用户批准前不得被下游任务当作「已生效」引用。

## 10. 决策权

| 决策 | 决定者 |
|---|---|
| 项目方向、视觉方向、是否批准素材、是否验收阶段 | **用户** |
| 架构、任务拆分、目录规范、冲突仲裁、范围管理 | DSH |
| 实现细节（在规范内） | Claude Lead Developer |
| 视觉素材制作 | Codex Visual Reviewer |

## 11. 成功标准（Stage 1 结束时的最低标准）

- 从启动到 RESULT 的完整状态循环可在编辑器与导出包中跑通。
- PREPARATION 永不自动推进；COMBAT 只能由玩家点击进入。
- 拔掉任何一张占位图，游戏仍不崩溃。
- 全部文档与代码通过 `09_TEST_STANDARD.md` 的完成定义。
