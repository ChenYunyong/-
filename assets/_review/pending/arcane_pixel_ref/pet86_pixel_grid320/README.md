# PET-86 Arcane Pixel Reference Grid320

Generated from the imagegen concept outputs, then reorganized onto the project art baseline grid.

Target art grid G: 320x180.

Pipeline:

1. GPT Image concept output as the sole concept source.
2. Crop concept art to 16:9.
3. Block-average into G = 320x180.
4. Remap each image to <=10 project tokens, avoiding near-token ramps.
5. On G, merge small 4-connected color components and run one 4-neighbor majority cleanup pass.
6. Save G art-grid PNGs for audit.
7. Scale G nearest-neighbor 2x to native 640x360.
8. Scale native files nearest-neighbor 2x to readable 1280x720.

Transition form: 寰呯敤鎴疯瀹? This pack does not design transitions, screen changes, or motion.

## Files

- 00_pixel_style_overview: style strip, palette, three card classes, four screen thumbnails.
- 01_main_menu: title/menu screen with night forest and castle backdrop.
- 02_parchment_route_map: parchment route selection with branching nodes.
- 03_book_card_placement: open-book card placement screen, free layout, no grid, snap highlight.
- 04_combat: automatic spell combat with fireball, ice/blue magic, lightning.

Each image has:

- *_artgrid_320x180.png
- *_native_640x360.png
- *_nearest2x_1280x720.png

## Pixel Metrics On Native 640x360

| File | Tokens Used | Adjacent Different Pairs | Near-Color Transition Density | Isolated Pixels | 2x2 Same-Color Blocks | Average Horizontal Run |
|---|---:|---:|---:|---:|---:|---:|
| 00_pixel_style_overview | 10 | 5.72% | 0% | 0% | 100% | 19.57px |
| 01_main_menu | 9 | 4.36% | 0% | 0% | 100% | 22.78px |
| 02_parchment_route_map | 9 | 3.48% | 0% | 0% | 100% | 30.84px |
| 03_book_card_placement | 10 | 4.51% | 0% | 0% | 100% | 20.73px |
| 04_combat | 10 | 5.26% | 0% | 0% | 100% | 22.54px |

## Scale-Block Detection On Native 640x360

- 01_main_menu: s=2: 100%; s=3: 82.86%; s=4: 82.07%; s=5: 68.77%; s=6: 68.25%; s=7: 56.88%; s=8: 58.14%; s=9: 49.33%; s=10: 48.09%
- 02_parchment_route_map: s=2: 100%; s=3: 86.18%; s=4: 86.28%; s=5: 73.19%; s=6: 72.8%; s=7: 62.06%; s=8: 62.11%; s=9: 52.29%; s=10: 53.04%
- 00_pixel_style_overview: s=2: 100%; s=3: 77.25%; s=4: 77.08%; s=5: 58.59%; s=6: 59.84%; s=7: 45.62%; s=8: 45.31%; s=9: 33.17%; s=10: 33.72%
- 03_book_card_placement: s=2: 100%; s=3: 81.26%; s=4: 82.12%; s=5: 66.81%; s=6: 65.05%; s=7: 53.37%; s=8: 53.39%; s=9: 43.17%; s=10: 44.7%
- 04_combat: s=2: 100%; s=3: 78.9%; s=4: 79.92%; s=5: 62.2%; s=6: 62.15%; s=7: 50.31%; s=8: 50.17%; s=9: 41.58%; s=10: 40.76%

## Art-Grid Component Diagnostics On G = 320x180

| File | Art Grid | Components | Components / 1000 px | Median Component | Largest Component |
|---|---|---:|---:|---:|---:|
| 00_pixel_style_overview | 320x180 | 181 | 3.14 | 90px | 33.57% |
| 01_main_menu | 320x180 | 116 | 2.01 | 80.5px | 16.72% |
| 02_parchment_route_map | 320x180 | 79 | 1.37 | 100px | 32.1% |
| 03_book_card_placement | 320x180 | 138 | 2.4 | 122px | 21.39% |
| 04_combat | 320x180 | 137 | 2.38 | 99px | 30.76% |

## Real-Size UI Probe

- 01_main_menu title ink height on native 640x360 ROI: 24px.
- This is >= 12px title height and >= 8px body-text baseline.
- G is 320x180, so 8px native body text equals 4 art-grid pixels; the grid can represent it.

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
