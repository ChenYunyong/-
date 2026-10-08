# 奥术蓝图 / Arcane Blueprint

全新 Godot 工程（PET-85 NEW-01）。旧工程留在仓库根目录，**冻结**，只作参考 —— 本工程不引用它任何一个文件。

## 一、怎么跑

```bash
# 工程根目录：arcane/
godot --headless --path . --import                    # 新克隆必须先跑一次，生成 *.translation 与导入缓存
godot --path .                                        # 双击 project.godot 等价：落地 boot → 自检 → 主菜单
godot --headless --path . --script res://tests/unit/run_tests.gd -- --task "任务号"
godot --path . --script res://tools/capture_main_menu.gd # 像素证据（**不要**加 --headless）
godot --path . --script res://tools/capture_editor.gd # 像素证据（**不要**加 --headless）
```

`tools/capture_editor.gd` 会用**真鼠标事件**走一遍「点卡位 → 拖卡 → 连线」，把实测数字打到 stdout，
并在 `tests/output/` 落下两张截图。它是证据采集，不是测试 —— 判定在 `tests/` 里。
`tools/capture_main_menu.gd` 同路数：走启动路径落在主菜单，截常态 / 打开设置 / 按过语言开关三张。

## 二、带过来了什么 / 没带什么（PET-85 允许清单）

带过来：

| 项 | 落点 |
| --- | --- |
| Windows + Web 导出预设 | `export_presets.cfg`（产物名与排除项按新工程改过） |
| 测试脚手架 + 冒烟骨架 | `tests/`，用例清单按新工程重写（旧工程的用例全部不带） |
| Palette + `palette.tres` 单一出处机制 | `scripts/data/palette.gd` + `assets/palette.tres` |
| i18n 机制（`ui.csv` + `tr()` + 语言开关） | `assets/i18n/ui.csv` + `scripts/core/settings_service.gd` |
| 06 §1/§5 的边距、间距系统、命中尺寸、证据标准 | 见下方对照表与 `scripts/editor/editor_layout.gd` |

没带（按卡面要求，一律不带）：全部场景、全部 UI 布局、全部玩法数据与枚举、旧主题与切图、旧美术。

## 三、UI 尺寸：原值 → 新值

基准口径由 DSH 在 2026-10-06 的 PET-85 评论中裁定，覆盖卡面原先写的 640×360 / 3×。
新数**不是把旧表乘一个倍数**得来的：以 06 §1 的参考单位（边距 8、间距 4/8/12/16/24、标题栏 16）
为唯一依据，在 960×540 上重新推了一遍 —— 所以下表里 1.5 倍的项与不成 1.5 倍的项混在一起。

| 项 | 旧值（旧工程 @640×360） | 新值（arcane @960×540） | 出处 / 推导 |
| --- | --- | --- | --- |
| 画布 viewport | 640×360 | **960×540** | DSH 裁定 |
| 窗口 | 1920×1080 | **1920×1080（不变）** | DSH 裁定 |
| 整数放大 | 3×（1920÷640） | **2×**（1920÷960） | `stretch/scale_mode="integer"` |
| 安全边距 | 16（`preparation_layout.SAFE_INSET`） | **24**（`EditorLayout.MARGIN`） | 06 §1 的 8 参考单位 |
| 分区间距 | 16（`reward/result_layout.GAP`） | **24**（`EditorLayout.GAP`） | 06 §1 间距系统 |
| 描边 | 2（`palette_theme.BORDER_WIDTH`） | **3**（`ArcaneTheme.BORDER_WIDTH`） | 参考单位 |
| 木框描边 | 6（`palette_theme.FRAME_BORDER_WIDTH`） | **9**（`ArcaneTheme.FRAME_BORDER_WIDTH`） | 参考单位 |
| 正文号 | 16（`palette_theme.BODY_FONT_SIZE`） | **24**（`ArcaneTheme.BODY_FONT_SIZE`） | 参考单位 |
| 面板标题栏高 | 32（`palette_theme.TITLE_BAR_HEIGHT`） | **48**（`ArcaneTheme.TITLE_BAR_HEIGHT`） | 06 §2.2 的 16 参考单位 |
| 节点卡 | 48×48（`blueprint_workspace.CARD`） | **72×72**（`BoardModel.CARD_SIZE`） | 06 §4 的 24 参考单位 |
| **有没有网格** | 有：`GRID=48`、`SLOT_PITCH_MAX=56` | **没有**：坐标原样保存，`PLACE_STEP=24` 只是「试放落点」的候选步长，不量化任何坐标 | 用户 2026-10-06：「不要搞格子」 |
| 卡牌仓库条 | 588×96（`preparation_layout.WAREHOUSE_RECT`） | **912×96**（`EditorLayout.TRAY_SIZE`） | 960 − 24×2 = 912；高 = 木框 9×2 + 卡位 72 + 呼吸 6 |

960×540 上的分区账（`tests/unit/test_layout.gd` 逐条断言）：

```
24 + 72(顶栏) + 24 + 276(书页 672×276 | 详情 216×276) + 24 + 96(仓库) + 24 = 540
24 + 672 + 24 + 216 + 24 = 960
```

### 触摸命中 ≥44 设备像素

设备像素 = 逻辑像素 × 2（窗口 1920÷视口 960），即逻辑下限 22px。本工程最小的可点目标：

| 目标 | 逻辑 | 设备 |
| --- | --- | --- |
| 顶栏按钮（`UiKit.button_height()` = 24 正文 + 12×2 内边距） | 48 | 96 |
| 仓库卡位 `TRAY_CHIP_SIZE` | 72 | 144 |
| 卡片接口命中半径 `PORT_HIT_RADIUS`（直径） | 32 | 64 |

## 四、一条硬约束：颜色只能来自 Token

任何 `scripts/` 下的文件都不许出现裸色值（`Color(...)` / `Color8(...)` / `Color.常量`），
唯一落点是 `scripts/data/palette.gd`。`tests/unit/test_source_rules.gd` 会直接扫源码把这条钉死，
并且先拿人造违规样本做反向对照 —— 一个「永远返回 0」的扫描器比没有测试更糟。

## 五、本卡不做的事

**界面之间的切换 / 转场 / 动效一律不设计**（用户 2026-10-06：「以后再定」）。
本卡只到「每个屏自己站得住」为止，屏与屏之间的过场留给后续卡。

`13 §2`：不新增主角 / 吉祥物 / 同伴 / 剧情角色。
`13 §10.1` 三条修订照办：Focus 与 Selected 语义分开、类型色只用于小块面积、不加堆叠装饰。
