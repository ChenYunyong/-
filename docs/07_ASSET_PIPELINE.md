# 07 — 素材管线与审批制度（ASSET PIPELINE）

> 状态：`FROZEN-DRAFT`（待用户批准）｜版本 v0.1.0｜维护者 DSH｜执行 Codex Visual Reviewer
> **核心原则：任何正式素材均不得自动进入游戏。**

## 1. 唯一合法流程

```
Codex 制作
    ↓  产出落盘
assets/_review/pending/
    ↓  DSH 依 05_ART_STYLE / 04_COLOR_SYSTEM 检查规范
assets/_review/final/
    ↓  DSH 展示给用户（截图 + 清单 + 用途说明）
   【用户明确批准】
    ↓
assets/_approved/
    ↓  Claude Lead Developer 集成（改场景/资源引用）
游戏内可见
```

**任何跳步都是违规。**

## 2. 什么叫「用户明确批准」

用户必须说出以下之一（或等价明确表述）：

```
通过 · 批准 · 用这一版 · 采用 · 可以进游戏
```

以下**不算**批准：

- 沉默
- 「还行」「看着不错」「先这样吧」
- 「你决定」
- 用户只是在讨论方向

未获批准 → 素材停在 `_review/final/`，不得集成。

## 3. 目录与命名

```
assets/
├─ _review/
│  ├─ pending/     # Codex 产出，DSH 未检查
│  └─ final/       # DSH 已检查，等待用户批准
├─ _approved/      # 用户已批准，可集成
├─ characters/ enemies/ nodes/ weapons/ effects/ ui/ backgrounds/ fonts/
└─ palette.tres
```

命名规则（全小写 snake_case + 用途后缀）：

```
<类别>_<主体>_<变体>_<尺寸>.png

ui_panel_frame_main_48.png
char_girl_idle_32.png
enemy_slime_walk_24.png
node_core_base_48.png
weapon_arc_coil_icon_24.png
fx_heat_burst_01_32.png
bg_floating_isle_day_320x180.png
```

禁止：中文文件名、空格、大写、`final`/`new`/`v2`/`最终版` 之类的版本垃圾名（版本由 Git 管理）。

## 4. 格式与导入设置

| 项 | 规定 |
|---|---|
| 位图 | PNG（8-bit RGBA），禁止 JPG / WebP 作为像素素材 |
| 导入过滤 | Godot 导入必须设为 **Nearest**（禁用 Filter / Mipmap） |
| 缩放 | 素材按 1x 像素基准产出，禁止预先放大 |
| 源文件 | 源文件（`.aseprite` / `.kra` / `.psd`）放 `assets/_review/pending/` 同级 `_src/`，**不进版本库**（体积），或存 `D:\GameDev\PixelFusion\assets\_src\` |
| 切片 | Sprite Sheet 必须附帧数据（`.json`），并可从命名推断行/列 |
| 字体 | 像素字体需确认授权允许商用与嵌入；授权不明一律不用 |

## 5. 审批记录表（每次提交追加一行）

| 批次 | 日期 | 提交人 | 内容 | 路径 | DSH 检查 | 用户批准 | 集成状态 |
|---|---|---|---|---|---|---|---|
| A-000 | 2026-10-03 | — | Stage 0 无素材 | — | — | — | — |

## 6. Codex 的权限边界

Codex Visual Reviewer：

✅ 可以做：UI、Icon、Character、Enemy、Weapon、Node、FX、Background、Sprite Sheet、调色板建议稿。

❌ 禁止做：

- 战斗逻辑、游戏规则、代码架构、编译
- Godot 场景逻辑与 `.tscn` 结构改动
- 自动替换游戏内全部资源
- 直接把素材放进 `assets/characters|enemies|...` 等正式目录

Codex 的一切产出一律先落 `assets/_review/pending/`。

## 7. 素材审查清单（DSH 提交用户前必查）

```
[ ] 文件落在正确的 _review 目录，命名合规
[ ] 尺寸符合 05_ART_STYLE §2
[ ] 像素对齐，无插值模糊
[ ] 颜色全部来自 04_COLOR_SYSTEM Token
[ ] 单素材调色板 ≤12 色
[ ] 与三张参考图气质一致（无黑名单倾向）
[ ] 提供了用途说明与集成目标（哪张场景/哪个资源）
[ ] 已附截图（便于用户在 Multica 中直接查看）
[ ] 已说明「未批准不得集成」
```

## 8. 交付给用户的形式

- 素材本体以 `--attachment` 形式附在 Multica 评论中（不要给不可点击的本地路径）。
- 同时提供一张**预览合成图**（把该批次素材拼在一张图上），降低用户审阅成本。
- 文字说明保持精简：批次号 / 内容 / 用途 / 待批准项。

## 9. 占位素材（Stage 1-4）

在 Stage 5 之前，允许使用占位素材，但必须：

- 放在 `assets/_review/pending/` 或显式标记 `placeholder_` 前缀。
- 用纯色块 / 简笔形状，禁止使用网上来源不明的图片。
- 绝不进入 `_approved/`。
