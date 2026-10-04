# VB-03 Component Language Batch

Status: pending DSH review.

This batch turns the approved VB-02 component kit into formal 1x PNG slices and previews. It follows the asset pipeline as:

`assets/_review/pending/` -> `assets/_review/final/` -> user approval -> `assets/_approved/` -> integration.

## Contents

- `slices/`: review copy of all generated component PNGs.
- `../../../../ui/vb03_component_language/`: integration-ready copy of the same slices plus `asset_manifest.json`.
- `asset_manifest.json`: dimensions, nine-patch margins, token names, state semantics, and overflow checks.
- `vb03_component_atlas_preview.png`: all component slices in one preview sheet.
- `vb03_main_menu_preview.png`: MAIN MENU adjustment preview.
- `vb03_preparation_preview.png`: PREPARATION component placement preview.
- `vb03_combat_preview.png`: COMBAT hierarchy and bottom weapon bar preview.

## Required VB-03 Corrections

- Focus is light blue corner/thin-frame language using `BLUE_300`; selected stays gold-primary using `GOLD_500` / `GOLD_200`.
- Node type color stays small-area only: the 4x4 marker changes by type, while every node card keeps the same `NAVY_700` body and restrained `BROWN_600` border.
- No extra decorative panel stacking was added. The batch is a base component language; future polish should come from icons, weapons, enemies, FX, and backgrounds.

## Slice Rules

- Main panel frame: 3px decorative frame, 16px title bar.
- Secondary panel frame: 1px restrained card frame.
- Button state size: 64x20.
- Node card and inventory slot: 24x24.
- HUD block primary: 72x24; secondary: 48x20.
- Tooltip maximum width: 120px.
- Progress bar: 96x12.
- All colors are pulled from `assets/palette.tres` by token name in `generate_vb03_assets.py`.

## Overflow Checks

- MAIN MENU: logo remains inside the central identity zone; the right-lower info block is secondary and does not become a visual center; focus corners remain inside button frames.
- PREPARATION: left info, blueprint area, right detail, bottom inventory, and CTA each stay inside their named frame boundaries. CTA uses the accepted `x=246..310 / y=142..162` read from the UI spec.
- COMBAT: top HUD hierarchy separates primary `CORE/HEAT/WAVE` from secondary `NEXT`; the bottom bar contains weapon blocks only; NEXT stays a compact preview label.
