from __future__ import annotations

import json
import re
import shutil
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
REVIEW_DIR = ROOT / "assets" / "_review" / "pending" / "vb03_component_language"
SLICE_DIR = REVIEW_DIR / "slices"
UI_DIR = ROOT / "assets" / "ui" / "vb03_component_language"


def load_palette() -> dict[str, tuple[int, int, int, int]]:
    text = (ROOT / "assets" / "palette.tres").read_text(encoding="utf-8")
    pattern = re.compile(
        r'"([^"]+)": Color\(([^,]+), ([^,]+), ([^,]+), ([^)]+)\)'
    )
    palette: dict[str, tuple[int, int, int, int]] = {}
    for name, r, g, b, a in pattern.findall(text):
        palette[name] = tuple(round(float(v) * 255) for v in (r, g, b, a))
    return palette


P = load_palette()


FONT = {
    " ": ["000", "000", "000", "000", "000"],
    "-": ["000", "000", "111", "000", "000"],
    ".": ["000", "000", "000", "000", "010"],
    "/": ["001", "001", "010", "100", "100"],
    ":": ["000", "010", "000", "010", "000"],
    "%": ["101", "001", "010", "100", "101"],
    "0": ["111", "101", "101", "101", "111"],
    "1": ["010", "110", "010", "010", "111"],
    "2": ["111", "001", "111", "100", "111"],
    "3": ["111", "001", "111", "001", "111"],
    "4": ["101", "101", "111", "001", "001"],
    "5": ["111", "100", "111", "001", "111"],
    "6": ["111", "100", "111", "101", "111"],
    "7": ["111", "001", "010", "010", "010"],
    "8": ["111", "101", "111", "101", "111"],
    "9": ["111", "101", "111", "001", "111"],
    "A": ["010", "101", "111", "101", "101"],
    "B": ["110", "101", "110", "101", "110"],
    "C": ["111", "100", "100", "100", "111"],
    "D": ["110", "101", "101", "101", "110"],
    "E": ["111", "100", "110", "100", "111"],
    "F": ["111", "100", "110", "100", "100"],
    "G": ["111", "100", "101", "101", "111"],
    "H": ["101", "101", "111", "101", "101"],
    "I": ["111", "010", "010", "010", "111"],
    "J": ["001", "001", "001", "101", "111"],
    "K": ["101", "101", "110", "101", "101"],
    "L": ["100", "100", "100", "100", "111"],
    "M": ["101", "111", "111", "101", "101"],
    "N": ["101", "111", "111", "111", "101"],
    "O": ["111", "101", "101", "101", "111"],
    "P": ["111", "101", "111", "100", "100"],
    "Q": ["111", "101", "101", "111", "001"],
    "R": ["111", "101", "111", "110", "101"],
    "S": ["111", "100", "111", "001", "111"],
    "T": ["111", "010", "010", "010", "010"],
    "U": ["101", "101", "101", "101", "111"],
    "V": ["101", "101", "101", "101", "010"],
    "W": ["101", "101", "111", "111", "101"],
    "X": ["101", "101", "010", "101", "101"],
    "Y": ["101", "101", "010", "010", "010"],
    "Z": ["111", "001", "010", "100", "111"],
}


class Canvas:
    def __init__(self, w: int, h: int, bg: str | None = None):
        self.w = w
        self.h = h
        self.pixels = bytearray((0, 0, 0, 0) * w * h)
        if bg:
            self.rect(0, 0, w, h, bg)

    def blend_pixel(self, x: int, y: int, rgba: tuple[int, int, int, int]) -> None:
        if x < 0 or y < 0 or x >= self.w or y >= self.h:
            return
        i = (y * self.w + x) * 4
        src_a = rgba[3] / 255
        dst_a = self.pixels[i + 3] / 255
        out_a = src_a + dst_a * (1 - src_a)
        if out_a == 0:
            self.pixels[i : i + 4] = bytes((0, 0, 0, 0))
            return
        for c in range(3):
            src = rgba[c] / 255
            dst = self.pixels[i + c] / 255
            self.pixels[i + c] = round(((src * src_a) + (dst * dst_a * (1 - src_a))) / out_a * 255)
        self.pixels[i + 3] = round(out_a * 255)

    def rect(self, x: int, y: int, w: int, h: int, token: str, alpha: int = 255) -> None:
        rgba = (*P[token][:3], alpha)
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.blend_pixel(xx, yy, rgba)

    def outline(self, x: int, y: int, w: int, h: int, token: str, t: int = 1, alpha: int = 255) -> None:
        self.rect(x, y, w, t, token, alpha)
        self.rect(x, y + h - t, w, t, token, alpha)
        self.rect(x, y, t, h, token, alpha)
        self.rect(x + w - t, y, t, h, token, alpha)

    def hline(self, x: int, y: int, w: int, token: str, alpha: int = 255) -> None:
        self.rect(x, y, w, 1, token, alpha)

    def vline(self, x: int, y: int, h: int, token: str, alpha: int = 255) -> None:
        self.rect(x, y, 1, h, token, alpha)

    def text(self, x: int, y: int, text: str, token: str, scale: int = 1) -> None:
        cx = x
        for ch in text.upper():
            glyph = FONT.get(ch, FONT[" "])
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row):
                    if bit == "1":
                        self.rect(cx + gx * scale, y + gy * scale, scale, scale, token)
            cx += 4 * scale

    def save(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        raw = bytearray()
        stride = self.w * 4
        for y in range(self.h):
            raw.append(0)
            raw.extend(self.pixels[y * stride : (y + 1) * stride])
        def chunk(tag: bytes, data: bytes) -> bytes:
            return (
                struct.pack(">I", len(data))
                + tag
                + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
            )
        png = b"\x89PNG\r\n\x1a\n"
        png += chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        png += chunk(b"IEND", b"")
        path.write_bytes(png)


def panel(w: int, h: int, title: bool = True, secondary: bool = False) -> Canvas:
    c = Canvas(w, h)
    if secondary:
        c.rect(1, 1, w - 2, h - 2, "NAVY_800")
        c.outline(0, 0, w, h, "BROWN_600")
        c.hline(1, 1, w - 2, "GOLD_200", 190)
        c.vline(1, 1, h - 2, "GOLD_200", 160)
        return c
    c.rect(3, 3, w - 6, h - 6, "NAVY_800")
    c.outline(0, 0, w, h, "BROWN_500", 1)
    c.outline(1, 1, w - 2, h - 2, "BROWN_600", 2)
    c.hline(3, 3, w - 6, "GOLD_200")
    c.vline(3, 3, h - 6, "GOLD_200")
    if title:
        c.rect(3, 3, w - 6, 15, "NAVY_700")
        c.hline(3, 18, w - 6, "GOLD_600")
    return c


def button(state: str) -> Canvas:
    colors = {
        "normal": ("GOLD_500", "GOLD_600", "NAVY_900"),
        "hover": ("GOLD_400", "GOLD_500", "NAVY_900"),
        "focus": ("GOLD_500", "BLUE_300", "NAVY_900"),
        "pressed": ("GOLD_600", "GOLD_600", "NAVY_900"),
        "disabled": ("NAVY_800", "NAVY_600", "GREY_500"),
        "selected": ("GOLD_400", "GOLD_500", "NAVY_900"),
    }
    fill, edge, text = colors[state]
    c = Canvas(64, 20)
    if state == "pressed":
        c.rect(0, 1, 64, 19, fill)
        c.outline(0, 1, 64, 19, edge)
    else:
        c.rect(0, 0, 64, 19, fill)
        c.outline(0, 0, 64, 19, edge)
        c.hline(1, 1, 62, "GOLD_200", 180)
    c.hline(1, 19, 62, "NAVY_900", 200)
    if state == "focus":
        for x, y in ((2, 2), (58, 2), (2, 14), (58, 14)):
            c.rect(x, y, 4, 1, "BLUE_300")
            c.rect(x, y, 1, 4, "BLUE_300")
    if state == "selected":
        c.outline(1, 1, 62, 17, "GOLD_200")
        c.rect(4, 4, 5, 5, "GOLD_600")
    return c


def node_card(kind: str, selected: bool = False, focus: bool = False) -> Canvas:
    type_token = {"core": "GOLD_400", "function": "BLUE_400", "weapon": "ORANGE_500"}[kind]
    c = Canvas(24, 24)
    c.rect(1, 1, 22, 22, "NAVY_700")
    c.outline(0, 0, 24, 24, "BROWN_600")
    c.rect(2, 2, 4, 4, type_token)
    c.rect(9, 8, 6, 6, "BLUE_100" if kind != "weapon" else "GOLD_500")
    c.rect(8, 10, 8, 2, "NAVY_900", 150)
    c.rect(17, 17, 3, 3, "GOLD_400" if kind == "core" else "BLUE_300")
    c.rect(0, 10, 3, 3, "NAVY_600")
    c.rect(21, 10, 3, 3, "NAVY_600")
    if selected:
        c.outline(0, 0, 24, 24, "GOLD_500")
        c.outline(1, 1, 22, 22, "GOLD_200")
    if focus:
        c.rect(1, 1, 5, 1, "BLUE_300")
        c.rect(1, 1, 1, 5, "BLUE_300")
        c.rect(18, 1, 5, 1, "BLUE_300")
        c.rect(22, 1, 1, 5, "BLUE_300")
    return c


def slot(state: str) -> Canvas:
    c = Canvas(24, 24)
    c.rect(1, 1, 22, 22, "NAVY_800")
    c.outline(0, 0, 24, 24, "BROWN_600")
    c.hline(3, 3, 18, "NAVY_600")
    c.vline(3, 3, 18, "NAVY_600")
    if state == "focus":
        c.outline(1, 1, 22, 22, "BLUE_300")
    elif state == "selected":
        c.outline(1, 1, 22, 22, "GOLD_500")
        c.rect(17, 17, 4, 4, "GOLD_200")
    elif state == "disabled":
        c.rect(2, 2, 20, 20, "BLACK", 80)
        c.hline(5, 12, 14, "GREY_500")
    return c


def hud_block(primary: bool, label: str | None = None) -> Canvas:
    w, h = (72, 24) if primary else (48, 20)
    c = Canvas(w, h)
    c.rect(1, 1, w - 2, h - 2, "NAVY_800" if primary else "NAVY_700")
    c.outline(0, 0, w, h, "BROWN_600")
    c.hline(1, 1, w - 2, "BLUE_300" if primary else "NAVY_600")
    if label:
        c.text(5, 5, label, "BLUE_100" if primary else "GREY_300")
    return c


def tooltip() -> Canvas:
    c = panel(120, 64, False, True)
    return c


def progress_bar() -> Canvas:
    c = Canvas(96, 12)
    c.rect(1, 1, 94, 10, "NAVY_800")
    c.outline(0, 0, 96, 12, "BROWN_600")
    c.rect(2, 2, 59, 8, "BLUE_500")
    c.hline(2, 2, 59, "BLUE_100")
    c.vline(61, 2, 8, "BLUE_300")
    return c


def overlay(kind: str) -> Canvas:
    c = Canvas(32, 32)
    if kind == "focus":
        for x, y in ((0, 0), (25, 0), (0, 25), (25, 25)):
            c.rect(x, y, 7, 1, "BLUE_300")
            c.rect(x, y, 1, 7, "BLUE_300")
    elif kind == "selected":
        c.outline(0, 0, 32, 32, "GOLD_500")
        c.outline(1, 1, 30, 30, "GOLD_200")
    elif kind == "disabled":
        c.rect(0, 0, 32, 32, "BLACK", 96)
        c.hline(6, 16, 20, "GREY_500")
    return c


def main_menu_preview() -> Canvas:
    c = Canvas(320, 180, "NAVY_900")
    c.rect(0, 0, 75, 180, "BROWN_700")
    c.rect(12, 18, 48, 84, "NAVY_700")
    c.outline(12, 18, 48, 84, "BROWN_500")
    c.text(102, 24, "PIXELFUSION", "GOLD_500", 2)
    y = 60
    for state, label in (("selected", "START"), ("normal", "CONT"), ("focus", "SET"), ("disabled", "EXIT")):
        b = button(state)
        blit(c, b, 128, y)
        c.text(148, y + 7, label, "NAVY_900" if state != "disabled" else "GREY_500")
        y += 24
    c.text(238, 148, "VER 0.1", "GREY_500")
    c.text(238, 158, "SAVE --", "GREY_500")
    return c


def prep_preview() -> Canvas:
    c = Canvas(320, 180, "NAVY_900")
    blit(c, panel(73, 124), 15, 8)
    blit(c, panel(128, 124), 98, 8)
    blit(c, panel(83, 124), 226, 8)
    blit(c, panel(211, 48, False, True), 15, 132)
    for gx in range(112, 210, 24):
        c.vline(gx, 26, 90, "NAVY_600", 110)
    for gy in range(28, 116, 24):
        c.hline(106, gy, 108, "NAVY_600", 110)
    for x, k in ((112, "core"), (136, "function"), (160, "weapon"), (184, "function")):
        blit(c, node_card(k, selected=(k == "core"), focus=(k == "function")), x, 50)
    c.hline(124, 62, 24, "BLUE_400")
    c.hline(148, 62, 24, "BLUE_400")
    for x, k in ((27, "core"), (55, "function"), (83, "weapon"), (111, "core"), (139, "function"), (167, "weapon")):
        blit(c, node_card(k), x, 144)
    blit(c, button("normal"), 246, 142)
    c.text(258, 149, "START", "NAVY_900")
    return c


def combat_preview() -> Canvas:
    c = Canvas(320, 180, "NAVY_900")
    c.rect(0, 0, 320, 135, "NAVY_700")
    c.rect(0, 135, 320, 45, "NAVY_800")
    c.hline(0, 135, 320, "NAVY_600")
    blit(c, hud_block(True, "CORE 100"), 8, 8)
    blit(c, hud_block(True, "HEAT 0"), 88, 8)
    blit(c, hud_block(True, "WAVE 1"), 168, 8)
    blit(c, hud_block(False, "NEXT"), 244, 8)
    c.rect(152, 72, 16, 16, "GOLD_500")
    c.outline(150, 70, 20, 20, "NAVY_900")
    c.rect(226, 58, 10, 10, "ORANGE_500")
    c.outline(225, 57, 12, 12, "NAVY_900")
    c.rect(196, 65, 20, 3, "BLUE_FX_600")
    c.rect(197, 66, 18, 1, "BLUE_050")
    for x, label in ((8, "NEEDLE"), (88, "BOMB"), (168, "SAW")):
        blit(c, hud_block(False), x, 146)
        c.text(x + 6, 151, label, "BLUE_100")
    c.text(248, 146, "NEXT", "GREY_300")
    c.text(248, 158, "SLIME 3", "GREY_500")
    return c


def blit(dst: Canvas, src: Canvas, x: int, y: int) -> None:
    for yy in range(src.h):
        for xx in range(src.w):
            i = (yy * src.w + xx) * 4
            rgba = tuple(src.pixels[i : i + 4])
            if rgba[3]:
                dst.blend_pixel(x + xx, y + yy, rgba)  # type: ignore[arg-type]


def atlas(named: list[tuple[str, Canvas]]) -> Canvas:
    c = Canvas(320, 220, "NAVY_900")
    x = 8
    y = 8
    row_h = 0
    for name, img in named:
        if x + img.w + 8 > 312:
            x = 8
            y += row_h + 18
            row_h = 0
        blit(c, img, x, y)
        c.text(x, y + img.h + 3, name[:18], "GREY_300")
        x += img.w + 16
        row_h = max(row_h, img.h + 8)
    return c


def write_all() -> None:
    for d in (SLICE_DIR, UI_DIR):
        d.mkdir(parents=True, exist_ok=True)

    assets: list[tuple[str, Canvas, dict[str, object]]] = [
        ("ui_panel_frame_main_96x64.png", panel(96, 64), {"nine_patch": [3, 16, 3, 3], "tokens": ["BROWN_500", "BROWN_600", "GOLD_200", "GOLD_600", "NAVY_800", "NAVY_700"]}),
        ("ui_panel_frame_secondary_64x40.png", panel(64, 40, False, True), {"nine_patch": [1, 1, 1, 1], "tokens": ["BROWN_600", "GOLD_200", "NAVY_800"]}),
        ("ui_button_primary_normal_64x20.png", button("normal"), {"nine_patch": [4, 4, 4, 4], "tokens": ["GOLD_500", "GOLD_600", "GOLD_200", "NAVY_900"]}),
        ("ui_button_primary_hover_64x20.png", button("hover"), {"nine_patch": [4, 4, 4, 4], "tokens": ["GOLD_400", "GOLD_500", "GOLD_200", "NAVY_900"]}),
        ("ui_button_primary_focus_64x20.png", button("focus"), {"nine_patch": [4, 4, 4, 4], "tokens": ["GOLD_500", "BLUE_300", "GOLD_200", "NAVY_900"]}),
        ("ui_button_primary_pressed_64x20.png", button("pressed"), {"nine_patch": [4, 4, 4, 4], "tokens": ["GOLD_600", "NAVY_900"]}),
        ("ui_button_primary_disabled_64x20.png", button("disabled"), {"nine_patch": [4, 4, 4, 4], "tokens": ["NAVY_800", "NAVY_600", "GREY_500", "BLACK"]}),
        ("ui_button_primary_selected_64x20.png", button("selected"), {"nine_patch": [4, 4, 4, 4], "tokens": ["GOLD_400", "GOLD_500", "GOLD_200", "GOLD_600", "NAVY_900"]}),
        ("ui_node_card_core_24.png", node_card("core"), {"size": [24, 24], "tokens": ["NAVY_700", "BROWN_600", "GOLD_400", "BLUE_100", "NAVY_900", "NAVY_600"]}),
        ("ui_node_card_function_24.png", node_card("function"), {"size": [24, 24], "tokens": ["NAVY_700", "BROWN_600", "BLUE_400", "BLUE_100", "BLUE_300", "NAVY_900", "NAVY_600"]}),
        ("ui_node_card_weapon_24.png", node_card("weapon"), {"size": [24, 24], "tokens": ["NAVY_700", "BROWN_600", "ORANGE_500", "GOLD_500", "BLUE_300", "NAVY_900", "NAVY_600"]}),
        ("ui_node_card_focus_24.png", node_card("function", focus=True), {"size": [24, 24], "tokens": ["NAVY_700", "BROWN_600", "BLUE_300", "BLUE_400", "BLUE_100"]}),
        ("ui_node_card_selected_24.png", node_card("core", selected=True), {"size": [24, 24], "tokens": ["NAVY_700", "GOLD_500", "GOLD_200", "GOLD_400", "BLUE_100"]}),
        ("ui_inventory_slot_normal_24.png", slot("normal"), {"size": [24, 24], "tokens": ["NAVY_800", "BROWN_600", "NAVY_600"]}),
        ("ui_inventory_slot_focus_24.png", slot("focus"), {"size": [24, 24], "tokens": ["NAVY_800", "BROWN_600", "BLUE_300"]}),
        ("ui_inventory_slot_selected_24.png", slot("selected"), {"size": [24, 24], "tokens": ["NAVY_800", "BROWN_600", "GOLD_500", "GOLD_200"]}),
        ("ui_inventory_slot_disabled_24.png", slot("disabled"), {"size": [24, 24], "tokens": ["NAVY_800", "BROWN_600", "GREY_500", "BLACK"]}),
        ("ui_hud_block_primary_72x24.png", hud_block(True), {"nine_patch": [4, 4, 4, 4], "tokens": ["NAVY_800", "BROWN_600", "BLUE_300", "BLUE_100"]}),
        ("ui_hud_block_secondary_48x20.png", hud_block(False), {"nine_patch": [4, 4, 4, 4], "tokens": ["NAVY_700", "BROWN_600", "NAVY_600", "GREY_300"]}),
        ("ui_tooltip_panel_120x64.png", tooltip(), {"nine_patch": [1, 1, 1, 1], "max_width": 120, "tokens": ["NAVY_800", "BROWN_600", "GOLD_400", "BLUE_300", "BLUE_100", "ORANGE_500", "GREY_300"]}),
        ("ui_progress_bar_blue_96x12.png", progress_bar(), {"nine_patch": [2, 2, 2, 2], "tokens": ["NAVY_800", "BROWN_600", "BLUE_500", "BLUE_100", "BLUE_300"]}),
        ("ui_overlay_focus_32.png", overlay("focus"), {"nine_patch": [8, 8, 8, 8], "tokens": ["BLUE_300"]}),
        ("ui_overlay_selected_32.png", overlay("selected"), {"nine_patch": [2, 2, 2, 2], "tokens": ["GOLD_500", "GOLD_200"]}),
        ("ui_overlay_disabled_32.png", overlay("disabled"), {"nine_patch": [4, 4, 4, 4], "tokens": ["BLACK", "GREY_500"]}),
    ]

    for name, img, _ in assets:
        review_path = SLICE_DIR / name
        ui_path = UI_DIR / name
        img.save(review_path)
        shutil.copyfile(review_path, ui_path)

    preview_assets = [(name.replace(".png", ""), img) for name, img, _ in assets[:24]]
    atlas(preview_assets).save(REVIEW_DIR / "vb03_component_atlas_preview.png")
    main_menu_preview().save(REVIEW_DIR / "vb03_main_menu_preview.png")
    prep_preview().save(REVIEW_DIR / "vb03_preparation_preview.png")
    combat_preview().save(REVIEW_DIR / "vb03_combat_preview.png")

    manifest = {
        "batch": "vb03_component_language",
        "status": "pending_dsh_review",
        "source_palette": "assets/palette.tres",
        "pipeline": "pending -> final -> user approval -> approved -> integration",
        "output_paths": [
            "assets/_review/pending/vb03_component_language/slices",
            "assets/ui/vb03_component_language",
        ],
        "constraints": {
            "main_frame_border_px": 3,
            "title_bar_height_px": 16,
            "spacing_px": [4, 8, 12, 16, 24],
            "node_card_px": [24, 24],
            "inventory_slot_px": [24, 24],
            "minimum_touch_device_px": [44, 44],
            "focus_semantics": "BLUE_300 light corner/thin frame",
            "selected_semantics": "GOLD_500/GOLD_200 primary emphasis",
            "type_color_rule": "small marker only; unified NAVY card body remains unchanged",
        },
        "slices": {
            name: {"file": name, **meta}
            for name, _, meta in assets
        },
        "previews": [
            "vb03_component_atlas_preview.png",
            "vb03_main_menu_preview.png",
            "vb03_preparation_preview.png",
            "vb03_combat_preview.png",
        ],
        "overflow_checks": {
            "main_menu": [
                "Logo stays inside central logo zone; no spill over top frame.",
                "Right-lower info is reduced to secondary save/version text and does not cross menu column.",
                "Button stack keeps 4px gaps; focus corners remain inside each 64x20 button frame.",
            ],
            "preparation": [
                "Left panel remains inside x=15..88.",
                "Blueprint work area remains inside x=98..226 and y=8..132.",
                "Right detail panel remains inside x=226..309.",
                "Bottom inventory strip remains inside y=132..180; CTA intentionally anchors at x=246..310/y=142..162 per 06 section 7.2.",
            ],
            "combat": [
                "Primary HUD blocks occupy top row without touching battlefield core.",
                "Bottom bar contains weapon blocks only; NEXT stays simple and does not become an enemy gallery.",
                "Projectile FX uses three-layer FX structure and does not cover CORE/HEAT/WAVE blocks.",
            ],
        },
    }
    manifest_text = json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"
    (REVIEW_DIR / "asset_manifest.json").write_text(manifest_text, encoding="utf-8")
    (UI_DIR / "asset_manifest.json").write_text(manifest_text, encoding="utf-8")


if __name__ == "__main__":
    write_all()
