# 04 — 颜色系统（COLOR SYSTEM）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 v0.1.0｜维护者 DSH（协同 Codex Visual Reviewer）
> 冻结规则：本表在用户批准后即冻结。**新增/修改颜色必须经 DSH 检查；涉及整体视觉改变的必须再交用户确认。**

## 1. 第一原则

正式项目**禁止**到处随手写 `Color("#xxxxxx")`。所有颜色必须来自统一 Palette，并按语义命名引用。

```gdscript
# 正确
var panel_bg: Color = Palette.get_color(Palette.Key.DEEP_NAVY)

# 禁止
var panel_bg := Color("#141a2e")
```

## 2. 冻结调色板 v0.1.0

> 依据：三张参考图（Reference A 开始界面 / B 蓝图整备 / C 自动战斗）。
> 下列 hex 为 **v0.1.0 基准值**，用于开发期占位；Codex 在 Stage 5 依据正式参考图做像素级校准后，经用户批准可发布 v0.2.0。

### 2.1 深色 UI — Deep Navy

| Token | Hex | 用途 | UI | Character | FX |
|---|---|---|---|---|---|
| `NAVY_900` | `#0B1020` | 全屏最底层背景、遮罩 | ✅ | ❌ | ❌ |
| `NAVY_800` | `#141A2E` | 主面板底色 | ✅ | ❌ | ❌ |
| `NAVY_700` | `#1E2740` | 节点背景、信息框 | ✅ | ❌ | ❌ |
| `NAVY_600` | `#2A3554` | 面板描边、分隔线 | ✅ | ⚠ 仅描边 | ❌ |

### 2.2 蓝色 — Sky / Energy Blue

| Token | Hex | 用途 | UI | Character | FX |
|---|---|---|---|---|---|
| `BLUE_500` | `#3E8BFF` | 主要能量色、蓝图基调 | ✅ | ✅ | ✅ |
| `BLUE_400` | `#5FA8FF` | 连接线、激活状态 | ✅ | ✅ | ✅ |
| `BLUE_300` | `#8FC7FF` | 高光、hover 辉光 | ✅ | ✅ | ✅ |
| `BLUE_100` | `#D6EBFF` | 文字/图标高光 | ✅ | ✅ | ✅ |

### 2.3 黄铜 / 金色 — Warm Gold / Brass

| Token | Hex | 用途 | UI | Character | FX |
|---|---|---|---|---|---|
| `GOLD_600` | `#8A6A2F` | 按钮按下态、暗边 | ✅ | ✅ | ❌ |
| `GOLD_500` | `#C9A227` | 主要按钮、边框 | ✅ | ✅ | ⚠ 仅火花 |
| `GOLD_400` | `#E3C05A` | 机械结构、强调信息 | ✅ | ✅ | ✅ |
| `GOLD_200` | `#F6E3A8` | 高光、选中态 | ✅ | ✅ | ✅ |

### 2.4 木质 — Workshop Brown

| Token | Hex | 用途 | UI | Character | FX |
|---|---|---|---|---|---|
| `BROWN_700` | `#3A2A1E` | 工坊阴影、外框暗部 | ✅ | ✅ | ❌ |
| `BROWN_500` | `#6B4A2F` | 工坊外框、木质结构 | ✅ | ✅ | ❌ |
| `BROWN_300` | `#A87A4F` | 木质高光 | ✅ | ✅ | ❌ |

### 2.5 红色 — Combat Red（严格限定）

| Token | Hex | 用途 | UI | Character | FX |
|---|---|---|---|---|---|
| `RED_600` | `#8E1F2B` | HP 缺失部分、危险底色 | ✅ | ✅ | ✅ |
| `RED_500` | `#D63B3B` | HP、伤害数字、警告 | ✅ | ✅ | ✅ |

**限制**：红色**只**用于 HP / 危险 / 伤害 / 警告。禁止作为装饰色、禁止用于普通按钮、禁止用于 Logo 主体。

### 2.6 橙色 — Heat Orange

| Token | Hex | 用途 | UI | Character | FX |
|---|---|---|---|---|---|
| `ORANGE_600` | `#B4531A` | Overheat 临界 | ✅ | ✅ | ✅ |
| `ORANGE_500` | `#F08A24` | Heat 条、高温 | ✅ | ✅ | ✅ |
| `ORANGE_300` | `#FFC46B` | 爆炸、过热高光 | ✅ | ✅ | ✅ |

### 2.7 中性色

| Token | Hex | 用途 |
|---|---|---|
| `WHITE` | `#FFFFFF` | 纯高光（谨慎，像素风中少用纯白） |
| `GREY_300` | `#C7CEDB` | 主要正文文字 |
| `GREY_500` | `#8A93A6` | 次要文字、禁用文字 |
| `BLACK` | `#000000` | 仅用于像素描边/透明底合成 |

## 3. 色彩硬规则

1. 正式颜色**必须**在本文件中登记（Token + Hex + 用途 + 可用域）。
2. 每个颜色必须有**语义名**，禁止 `color_1`、`blue2` 之类。
3. 必须标明是否可用于 `UI` / `Character` / `FX`。
4. **不允许随意增加近似色**（同一色相 10° 内不得出现两个 Token）。
5. 新增颜色流程：提出 → DSH 检查（是否真的必要 / 能否复用现有 Token）→ 记入 `12_CHANGELOG.md`。
6. 涉及整体视觉改变的，必须再交**用户确认**。
7. `assets/palette.tres` 的 Token 名必须与本文表格**逐字一致**。
8. 任何 PR/任务中出现裸 `Color("#...")` 一律打回，除非是 `palette.gd` 内的定义处。

## 4. 文字对比度要求

- 正文文字与背景对比度 **≥ 4.5:1**（WCAG AA）。
- 大号标题 **≥ 3:1**。
- 禁止用 `BLUE_500` 作为 `NAVY_800` 上的正文文字（对比不足），必须用 `BLUE_100` / `GREY_300`。
- 红/橙/绿不得作为**唯一**状态区分手段（色盲），必须同时有图标或形状差异。

## 5. `assets/palette.tres` 规范（Stage 1 实现）

Stage 0 仅冻结 schema，**不创建可能损坏的资源文件**。

Stage 1 由 Claude Lead Developer 实现：

```
scripts/data/palette.gd      # class_name Palette extends Resource
    - enum Key { ... 与 §2 表格逐字一致 ... }
    - @export var colors: Dictionary[Key, Color]
    - static func get_color(key: Key) -> Color

assets/palette.tres          # 唯一的颜色事实来源
```

强制要求：

- 所有色值只在 `palette.tres` 中出现一次。
- `Palette.get_color()` 是取色唯一入口。
- Editor 中修改 `palette.tres` 后，全项目表现必须同步变化。
- 禁止在 `.tscn` 中直接写十六进制颜色（Theme 必须引用 Palette）。

## 6. 主题（Theme）规则

- 全局 `Theme` 资源引用 Palette Token，不在控件上零散覆盖颜色。
- 允许的局部覆盖场景：HP 条变色、Heat 条变色、禁用态 —— 且必须用 Token。
- 禁止为「好看」临时调一个色再忘记登记。

## 7. 变更记录

| 版本 | 日期 | 变更 | 批准 |
|---|---|---|---|
| v0.1.0 | 2026-10-03 | 建立初始冻结调色板（依据三张参考图） | 待用户批准 |
