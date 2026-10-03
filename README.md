# PixelFusion / 像素融合屋

像素风 Roguelike · 自动战斗 · 蓝图构筑 —— Godot 4.x Stable + GDScript

## 快速索引

| 想了解 | 看这个 |
|---|---|
| 项目是什么、目标、范围、阶段 | `docs/00_PROJECT_CHARTER.md` |
| 存储规则 / C 盘禁令 / STORAGE GATE | `docs/01_STORAGE_RULES.md` |
| 代码怎么写（GDScript 规范） | `docs/02_CODE_STANDARD.md` |
| 系统怎么组织（状态机 / Autoload / 目录） | `docs/03_ARCHITECTURE.md` |
| 颜色 Token（冻结） | `docs/04_COLOR_SYSTEM.md` |
| 像素风规范 | `docs/05_ART_STYLE.md` |
| UI 数值与布局 | `docs/06_UI_UX_STANDARD.md` |
| 素材审批流程 | `docs/07_ASSET_PIPELINE.md` |
| 三个 Agent 的职责与权限 | `docs/08_AGENT_RULES.md` |
| 测试要求 | `docs/09_TEST_STANDARD.md` |
| 验收标准与阶段门 | `docs/10_ACCEPTANCE_STANDARD.md` |
| 任务清单与阶段拆解 | `docs/11_TASK_BOARD.md` |
| 改了什么 | `docs/12_CHANGELOG.md` |

## 当前状态

**STAGE 0 — PROJECT FOUNDATION**：约束文档已完成，等待用户批准。
**未进入正式开发。** 在用户明确批准 Stage 0 之前，禁止编写正式游戏代码。

## 三条不可动摇的规则

1. **禁止写入 C 盘**（项目内容一律在 `D:\GameDev\PixelFusion` / `D:\Temp\PixelFusion`）。
2. **PREPARATION 永不自动推进**，只能由玩家点击「开始战斗」进入 COMBAT。
3. **任何正式素材未经用户明确批准，不得进入游戏。**

## 路径

```
正式项目     D:\GameDev\PixelFusion
临时/缓存    D:\Temp\PixelFusion
构建输出     D:\GameDev\PixelFusion\build
测试输出     D:\GameDev\PixelFusion\tests\output
文档         D:\GameDev\PixelFusion\docs
```
