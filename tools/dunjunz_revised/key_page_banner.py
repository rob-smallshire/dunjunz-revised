"""The banner across the top of the title's page of keys: the DUNJUNZ logo
from the 1987 title picture, in teletext mosaic graphics, shaded like fire.

The logo (the picture's red and white pixels above the heroes, without the
torch flames that reach up into it) is converted by the sextants package to
BANNER_ROWS rows of 40 cells, each row starting with its graphics colour
code, shaded from yellow at the top to magenta at the bottom. The
conversion is slow and needs sextants, so the result is checked in, as
asm/defs/key_page_banner.asm; `uv run dr-banner` remakes it.
"""

from __future__ import annotations

from pathlib import Path

from dunjunz_revised.title_picture import (
    PICTURE_ADDRESS,
    SCREEN_END,
    SCREEN_START,
    SCREEN_WIDTH,
    get_pixel,
)

PROJECT_DIRPATH = Path(__file__).resolve().parents[2]
PICTURE_FILEPATH = PROJECT_DIRPATH / "reference" / "disc" / "Screen"
BANNER_ASM_FILEPATH = PROJECT_DIRPATH / "asm" / "defs" / "key_page_banner.asm"

BANNER_ROWS = 7
MODE_7_WIDTH = 40
LOGO_BOTTOM_LINE = 88               # the logo lies above this line of the picture
LOGO_COLOURS = {1, 7}               # red, and the white of its highlights
SMALLEST_PART = 100                 # pixels: anything smaller is a torch flame
# MODE 2 pixels are four times as wide as they are high, on a 640 x 512 grid.
PIXEL_WIDTH, PIXEL_HEIGHT = 4, 2
SEXTANTS_PRESET = "art"

# Teletext graphics colours, from the top row down: yellow, red and magenta flames.
GRAPHICS_YELLOW, GRAPHICS_RED, GRAPHICS_MAGENTA = 0x93, 0x91, 0x95
FIRE_COLOURS = (GRAPHICS_YELLOW,) * 3 + (GRAPHICS_RED,) * 3 + (GRAPHICS_MAGENTA,)
GRAPHICS_COLOURS = range(0x91, 0x98)
BLACK_BACKGROUND, NEW_BACKGROUND, HOLD_GRAPHICS = 0x9C, 0x9D, 0x9E


def logo_pixels() -> set[tuple[int, int]]:
    """The logo's pixels in the 1987 picture, as (x, line)."""
    screen = bytearray(SCREEN_END - SCREEN_START)
    picture = PICTURE_FILEPATH.read_bytes()
    offset = PICTURE_ADDRESS - SCREEN_START
    screen[offset:offset + len(picture)] = picture
    lit = {(x, line) for line in range(LOGO_BOTTOM_LINE) for x in range(SCREEN_WIDTH)
           if get_pixel(screen, x, line) in LOGO_COLOURS}
    logo, seen = set(), set()
    for start in lit:
        if start in seen:
            continue
        part, stack = set(), [start]
        seen.add(start)
        while stack:
            x, line = stack.pop()
            part.add((x, line))
            for neighbour in ((x + dx, line + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                if neighbour in lit and neighbour not in seen:
                    seen.add(neighbour)
                    stack.append(neighbour)
        if len(part) >= SMALLEST_PART:
            logo |= part
    return logo


def logo_image():
    """The logo in red on black, cropped, at the picture's displayed aspect."""
    from PIL import Image
    pixels = logo_pixels()
    left, top = min(x for x, _ in pixels), min(line for _, line in pixels)
    width = max(x for x, _ in pixels) - left + 1
    height = max(line for _, line in pixels) - top + 1
    image = Image.new("RGB", (width * PIXEL_WIDTH, height * PIXEL_HEIGHT))
    for x, line in pixels:
        image.paste((255, 0, 0), ((x - left) * PIXEL_WIDTH, (line - top) * PIXEL_HEIGHT,
                                  (x - left + 1) * PIXEL_WIDTH, (line - top + 1) * PIXEL_HEIGHT))
    return image


def banner_rows() -> list[bytes]:
    """The banner: BANNER_ROWS rows of MODE_7_WIDTH bytes, each a graphics colour
    code and mosaic characters (with background and hold codes), every byte with
    bit 7 set, so that the MOS writes it to the screen as it is (MOS 1.20 swaps
    #, _ and pound signs in MODE 7, and &7F is DELETE)."""
    from sextants import api
    from sextants.options import Fit
    from sextants.presets import PRESETS
    preset = PRESETS[SEXTANTS_PRESET]
    fragment = api.convert_fragment(logo_image(), MODE_7_WIDTH, BANNER_ROWS, fit=Fit.STRETCH,
                                    preprocess=preset.preprocess, solve=preset.solve, progress=False)
    assert (fragment.width, fragment.height) == (MODE_7_WIDTH, BANNER_ROWS)
    rows = []
    for colour, row in zip(FIRE_COLOURS, fragment.rows()):
        assert row[0] == GRAPHICS_RED and not set(row[1:]) & set(GRAPHICS_COLOURS), row.hex()
        cells = bytes([colour]) + row[1:-1] + b" "                  # a space for the trailing reset
        rows.append(bytes(cell | 0x80 for cell in cells))
    return rows


def banner_asm(rows: list[bytes]) -> str:
    lines = [
        "; ***************************************************************************************",
        "; The banner across the top of the title's page of keys",
        ";",
        "; Written by tools/dunjunz_revised/key_page_banner.py (uv run dr-banner); do not edit.",
        "; The DUNJUNZ logo from the 1987 title picture in teletext mosaic graphics: seven full",
        "; rows of 40 cells, so the cursor moves from each to the next by itself, each row's",
        "; graphics colour code first, then a zero. Every byte has bit 7",
        "; set, so the MOS puts it on the screen as it is.",
        ".key_page_banner",
    ]
    for row in rows:
        lines.append("    equb " + ", ".join(f"&{cell:02x}" for cell in row))
    lines += ["    equb 0", ""]
    return "\n".join(lines)


def main() -> None:
    BANNER_ASM_FILEPATH.write_text(banner_asm(banner_rows()))
    print(f"Wrote {BANNER_ASM_FILEPATH.relative_to(PROJECT_DIRPATH)}")


if __name__ == "__main__":
    main()
