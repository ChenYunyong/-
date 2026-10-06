# PET-86 Arcane Pixel Reference Redo

Generated from the imagegen concept outputs, then reorganized into a real coarse pixel grid instead of direct continuous-tone downsampling.

Pipeline:

1. Crop concept art to 16:9.
2. Block-average into a 160x90 working pixel grid.
3. Remap each image to <=16 project tokens.
4. Remove isolated single pixels by repeated 4-neighbor majority cleanup.
5. Scale nearest-neighbor to native 640x360.
6. Scale native files nearest-neighbor to readable 1280x720.

Transition form: 寰呯敤鎴疯瀹? This pack does not design transitions, screen changes, or motion.

## Files

- 00_pixel_style_overview: style strip, palette, three card classes, four screen thumbnails.
- 01_main_menu: title/menu screen with night forest and castle backdrop.
- 02_parchment_route_map: parchment route selection with branching nodes.
- 03_book_card_placement: open-book card placement screen, free layout, no grid, snap highlight.
- 04_combat: automatic spell combat with fireball, ice/blue magic, lightning.

Each image has:

- *_native_640x360.png
- *_nearest2x_1280x720.png

## Pixel Metrics On Native 640x360

| File | Tokens Used | Adjacent Different Pairs | Near-Color Transition Density | Isolated Pixels | 2x2 Same-Color Blocks | Average Horizontal Run |
|---|---:|---:|---:|---:|---:|---:|
| 00_pixel_style_overview | 8 | 6.91% | 0% | 0% | 86.1% | 15.81px |
| 01_main_menu | 8 | 4.47% | 0% | 0% | 91.33% | 21.22px |
| 02_parchment_route_map | 8 | 5.54% | 0% | 0% | 89.07% | 19.43px |
| 03_book_card_placement | 8 | 5.33% | 0% | 0% | 89.43% | 17.23px |
| 04_combat | 8 | 5.69% | 0% | 0% | 88.67% | 19.34px |

Acceptance lines requested by DSH:

- isolated pixels <= 0.5%
- 2x2 same-color blocks >= 80%
- average horizontal run >= 12px
- adjacent different pairs <= 8%
- near-color transition density <= 2%
- tokens used <= 16
- non-token pixels = 0 by construction

## Token Palette

- NAVY_900: #0F1B33
- NAVY_800: #172747
- NAVY_700: #273757
- NAVY_600: #2B3F6B
- NAVY_500: #374767
- BLUE_500: #77B7F7
- BLUE_400: #97C7F7
- BLUE_300: #B7D7F7
- BLUE_200: #C7D7F7
- BLUE_100: #D7E7F7
- BLUE_050: #E7EFF7
- BLUE_FX_600: #3EA6FF
- GOLD_600: #C79A4A
- GOLD_500: #F7C767
- GOLD_400: #F7B777
- GOLD_200: #FBDFA8
- WARM_300: #F7C7A7
- WARM_500: #ECB48C
- BROWN_700: #372727
- BROWN_600: #472727
- BROWN_500: #573737
- BROWN_450: #573727
- BROWN_400: #674737
- BROWN_300: #876757
- BROWN_200: #977777
- WHITE: #F7F7F7
- GREY_300: #C7CEDB
- GREY_500: #8A93A6
- BLACK: #000000
- RED_600: #8E1F2B
- RED_500: #D63B3B
- RED_400: #F06A6A
- ORANGE_600: #B4531A
- ORANGE_500: #F08A24
- ORANGE_300: #FFC46B

## Slice / Nine-Patch Notes

- Main menu: slice brass button frames as 9-patch; keep title art as static bitmap; split background into far castle, forest, foreground table/candle if animated later.
- Route map: parchment frame can be 9-patched; nodes should become separate 16-24px sprites; dotted route segments can be tiled.
- Book card placement: book/page frame can be 9-patched; cards should be separate sprites; snap glow should be a short-lived overlay sprite, not baked into cards.
- Combat: battlefield background can be layered; spell FX should be separate sprites using the 3-layer FX rule; bottom HUD panels and cards should be sliced separately.

Note: ability-card nine-element color identity is limited by the current 35-token palette. This pack uses available distinguishable token groups and icon/shape differences pending user/DSH palette expansion decision.
