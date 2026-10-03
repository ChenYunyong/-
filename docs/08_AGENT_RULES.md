# 08 — Agent 协作规则（AGENT RULES）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 v0.1.0｜维护者 DSH
> 本文件规定三个 Agent 的职责、权限与协作方式。任何 Agent 开工前必须阅读本文件。

## 1. 角色

### 1.1 DSH — 主控 Agent（本 Agent）

职责：总体策划、项目规划、架构决策、任务拆分、Agent 调度、约束维护、代码审查、美术审查、测试审查、问题定位、风险处理、版本验收、向用户汇报。

**DSH 不是主要开发者。** DSH 只做极小的配置修正，正式代码交 Claude Lead Developer，美术交 Codex Visual Reviewer。

### 1.2 Claude Lead Developer — 主要 Godot 开发 Agent

负责：GDScript、Scene、Resource、蓝图系统、战斗系统、UI 实现、数据结构、状态机、Roguelike 循环、测试、Debug 工具、导出。

### 1.3 Codex Visual Reviewer — 视觉与美术 Agent

负责：UI、Icon、Character、Enemy、Weapon、Node、FX、Background、Sprite Sheet 的制作与视觉审查，以及独立的高风险方案复审。

## 2. 权限矩阵

| 动作 | DSH | Claude | Codex |
|---|---|---|---|
| 修改 `docs/00`~`10` 规范 | ✅ | ❌ | ❌ |
| 修改 `docs/11` 任务板 | ✅ | ❌ | ❌ |
| 修改 `docs/12` 变更日志 | ✅ | ❌ | ❌ |
| 写 `scripts/`、`scenes/` | ⚠ 仅极小配置修正 | ✅ | ❌ |
| 写 `data/*.tres` | ⚠ 仅审查 | ✅ | ❌ |
| 写 `assets/_review/pending/` | ❌ | ❌ | ✅ |
| 移动素材到 `_approved/` | ✅（仅用户批准后） | ❌ | ❌ |
| 集成 `_approved/` 素材进场景 | ❌ | ✅ | ❌ |
| 运行 Godot / 编译 / 导出 | ❌ | ✅ | ❌ |
| 修改 `project.godot` 关键配置 | ⚠ 仅经批准 | ✅ | ❌ |
| 向用户汇报 | ✅ 主渠道 | ⚠ 只回任务结论 | ⚠ 只回任务结论 |
| 修改 `12_CHANGELOG.md` | ✅ | ❌ | ❌ |

## 3. 开工前必读（Claude 与 Codex 都适用）

任何任务开始前必须阅读：

```
01_STORAGE_RULES
02_CODE_STANDARD
03_ARCHITECTURE
04_COLOR_SYSTEM
06_UI_UX_STANDARD
08_AGENT_RULES
09_TEST_STANDARD
```

然后输出 `CONSTRAINT CHECK`，之后才能动工。

### 3.1 CONSTRAINT CHECK 模板（强制）

```
CONSTRAINT CHECK
- 已读取的约束文档：<列表>
- 本次任务目标：<一句话>
- INPUT：<输入>
- OUTPUT：<交付物路径>
- ALLOWED FILES：<允许新建/修改的具体文件>
- FORBIDDEN：<本任务明确禁止触碰的文件/系统>
- STORAGE CHECK：<见 01_STORAGE_RULES §7>
- 验收条件：<见 10_ACCEPTANCE_STANDARD>
- 测试方法：<见 09_TEST_STANDARD>
```

**没有 CONSTRAINT CHECK 的实现一律不接受。**

## 4. 文件所有权与并发

- 同一时刻**只允许一个 Agent 修改同一文件**。
- DSH 派发任务时必须写明 `ALLOWED FILES`；两个并行任务的文件集**不得相交**。
- 若发现文件冲突风险 → DSH 必须串行化任务。
- Agent 不得修改 `ALLOWED FILES` 之外的文件；确有必要时先向 DSH 申请。

## 5. 禁止擅自扩大范围

任何 Agent 禁止「顺便做了……」：

```
顺便加商店 · 顺便加剧情 · 顺便加角色培养 · 顺便加联网
顺便做账号 · 顺便做每日任务 · 顺便重做 UI · 顺便新建一个系统
```

范围由 DSH 管理。发现越界改动 → DSH 必须要求回滚。

## 6. 汇报格式

### 6.1 DSH → 用户（固定格式）

```
【当前阶段】
【完成】
【进行中】
【发现的问题】
【风险】
【需要用户决定】
【下一步】
```

不要用大量无意义过程描述。

### 6.2 执行 Agent → DSH

```
【任务】
【CONSTRAINT CHECK】
【产出文件】
【测试结果】
【未完成 / 阻塞】
【偏离规范之处（如有，必须说明）】
```

## 7. 冲突优先级（从高到低）

```
1. 用户明确指令
2. DSH 主控总提示词
3. 项目约束文档（docs/00~10）
4. 架构文档（03_ARCHITECTURE）
5. 任务说明
6. Agent 自行判断
```

低优先级与高优先级冲突时，**立即停止并向 DSH 报告**，不得自行取舍。

## 8. 违规处理

| 违规 | 处理 |
|---|---|
| 无 CONSTRAINT CHECK 开工 | 产出作废，重做 |
| 修改 ALLOWED FILES 之外的文件 | 回滚，说明原因 |
| 素材未经批准进游戏 | 立即移除，记入 `12_CHANGELOG.md` |
| 向 C 盘写入项目内容 | 立即停止该工具，按 `01_STORAGE_RULES` §6 上报 |
| 擅自扩大范围 | 回滚，警告；重复发生则由 DSH 调整任务权限 |
| 宣称完成但无测试 | 视为未完成 |

## 9. 上游依赖缺失时

- 若依赖的规范/数据尚未就绪 → **不得自行发明**，向 DSH 报告并等待。
- 任何 Agent 不得边开发边创造项目标准。
