"""The banner across the top of the title's page of keys: the DUNJUNZ logo
from the 1987 title picture, in teletext mosaic graphics, shaded like fire,
with white stars that twinkle around it, as on the title picture.

The logo (the picture's red and white pixels above the heroes, without the
torch flames that reach up into it) is converted by the sextants package to
BANNER_ROWS rows of 40 cells, each row starting with its graphics colour
code, shaded from yellow at the top to magenta at the bottom, and using no
hold or background codes, so that the stars' codes can go in any blank cell.

Each star has a site (STAR_SITES) in the blank cells around the logo: on
each of its rows, a code for white graphics, one for separated graphics
where there is room, the cells the star is drawn in, then the codes back to
contiguous graphics and to the row's colour, before the logo goes on. The
codes are part of the banner. The title draws the stars a frame at a time,
copying each site's STAR_WINDOW_WIDTH x STAR_WINDOW_HEIGHT window of cells
from the frames made here (show_keys).

The conversion is slow and needs sextants, so the result is checked in, as
asm/defs/key_page_banner.asm; `uv run dr-banner` remakes it.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from dunjunz_revised.page_text import text_bytes_asm
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

# Teletext codes. Graphics colours, from the top row down: yellow, red and magenta flames.
GRAPHICS_YELLOW, GRAPHICS_RED, GRAPHICS_MAGENTA, GRAPHICS_WHITE = 0x93, 0x91, 0x95, 0x97
CONTIGUOUS, SEPARATED = 0x99, 0x9A
FIRE_COLOURS = (GRAPHICS_YELLOW,) * 3 + (GRAPHICS_RED,) * 3 + (GRAPHICS_MAGENTA,)
SPACE = 0x20
# A mosaic cell's pixels, two across and three down, and the bit of each.
SEXTANT_BITS = {(0, 0): 0x01, (1, 0): 0x02, (0, 1): 0x04, (1, 1): 0x08, (0, 2): 0x10, (1, 2): 0x40}

# The stars' sizes: 1 a dot, 2 and 3 crosses with arms of one and two pixels,
# 4 the largest with a pixel in each angle too. A twinkle grows through them
# and shrinks back, a frame every STAR_TICK_CENTISECONDS.
STAR_FRAMES = 5                     # blank, then the four sizes
TWINKLE = (1, 2, 3, 4, 3, 2, 1)     # the sizes of a twinkle, frame by frame
STAR_TICK_CENTISECONDS = 3
STAR_WINDOW_WIDTH, STAR_WINDOW_HEIGHT = 3, 2


@dataclass(frozen=True)
class StarSite:
    """Where a star twinkles.

    top: its first row; rows: how many rows it is drawn on (1 or 2).
    white_column: the column of its white graphics code.
    first_cell, cells: the first cell it is drawn in, and how many across.
    restore_column: the code back to the logo's colour, or None at a row's end.
    separated: room for separated graphics: a code after the white, and one
        back to contiguous before the colour.
    window_column: the first column of the window the title copies.
    centre: the star's centre in pixels from the window's top left.
    largest: its largest size.
    period, first: ticks between its twinkles, and to its first.
    """

    top: int
    rows: int
    white_column: int
    first_cell: int
    cells: int
    restore_column: int | None
    separated: bool
    window_column: int
    centre: tuple[int, int]
    largest: int
    period: int
    first: int


STAR_SITES = (
    StarSite(top=3, rows=2, white_column=0, first_cell=2, cells=3, restore_column=5, separated=True,
             window_column=2, centre=(2, 2), largest=4, period=41, first=6),     # left of the D
    StarSite(top=4, rows=2, white_column=11, first_cell=13, cells=3, restore_column=16, separated=True,
             window_column=13, centre=(3, 2), largest=4, period=53, first=29),   # under the first un
    StarSite(top=4, rows=2, white_column=25, first_cell=27, cells=3, restore_column=30, separated=True,
             window_column=27, centre=(2, 3), largest=3, period=47, first=15),   # under the second un
    StarSite(top=0, rows=1, white_column=12, first_cell=14, cells=2, restore_column=16, separated=True,
             window_column=14, centre=(1, 1), largest=2, period=59, first=42),   # above the first un
    StarSite(top=2, rows=2, white_column=37, first_cell=38, cells=2, restore_column=None, separated=False,
             window_column=37, centre=(3, 3), largest=2, period=67, first=55),   # after the Z
)


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


def logo_rows() -> list[bytearray]:
    """The logo: BANNER_ROWS rows of MODE_7_WIDTH cells, each its row's colour
    code, then mosaic characters with bit 7 set (MOS 1.20 swaps #, _ and pound
    signs in MODE 7, and &7F is DELETE), blanks as spaces."""
    import dataclasses
    from sextants import api
    from sextants.options import Fit
    from sextants.presets import PRESETS
    preset = PRESETS[SEXTANTS_PRESET]
    solve = dataclasses.replace(preset.solve, use_hold=False, use_fill=False)
    fragment = api.convert_fragment(logo_image(), MODE_7_WIDTH, BANNER_ROWS, fit=Fit.STRETCH,
                                    preprocess=preset.preprocess, solve=solve, progress=False)
    assert (fragment.width, fragment.height) == (MODE_7_WIDTH, BANNER_ROWS)
    rows = []
    for colour, row in zip(FIRE_COLOURS, fragment.rows()):
        assert row[0] == GRAPHICS_RED and all(cell & 0x7F >= 0x20 for cell in row[1:-1]), row.hex()
        cells = [cell | 0x80 for cell in row[1:-1]]
        rows.append(bytearray([colour] + [SPACE if cell == 0xA0 else cell for cell in cells] + [SPACE]))
    return rows


def star_pixels(size: int, centre: tuple[int, int]) -> set[tuple[int, int]]:
    """A star's pixels at a size (0 none, 1 a dot, 2 and 3 crosses, 4 with its angles)."""
    if size == 0:
        return set()
    x, y = centre
    arm = {1: 0, 2: 1, 3: 2, 4: 2}[size]
    pixels = {(x + d, y) for d in range(-arm, arm + 1)} | {(x, y + d) for d in range(-arm, arm + 1)}
    if size == 4:
        pixels |= {(x + dx, y + dy) for dx in (-1, 1) for dy in (-1, 1)}
    return pixels


def place_star(rows: list[bytearray], site: StarSite, size: int) -> None:
    """Draw a site's star at a size into its cells, which must hold all of it."""
    pixels = star_pixels(size, site.centre)
    drawn = set()
    for row in range(site.rows):
        for cell in range(site.cells):
            column = site.first_cell + cell
            window_x = (column - site.window_column) * 2
            lit = {(window_x + dx, row * 3 + dy): bit for (dx, dy), bit in SEXTANT_BITS.items()
                   if (window_x + dx, row * 3 + dy) in pixels}
            drawn |= set(lit)
            rows[site.top + row][column] = (0xA0 | sum(lit.values())) if lit else SPACE
    assert drawn == pixels, (site, size)


def banner_with_sites() -> list[bytearray]:
    """The banner as printed: the logo with every star site's codes, its stars
    not showing. A site's cells and codes must all be blank in the logo."""
    rows = logo_rows()
    for site in STAR_SITES:
        for row in range(site.rows):
            cells = rows[site.top + row]
            codes = {site.white_column: GRAPHICS_WHITE}
            if site.separated:
                codes[site.white_column + 1] = SEPARATED
            if site.restore_column is not None:
                colour = FIRE_COLOURS[site.top + row]
                if site.separated:
                    codes[site.restore_column] = CONTIGUOUS
                    codes[site.restore_column + 1] = colour
                else:
                    codes[site.restore_column] = colour
            for column in set(codes) | set(range(site.first_cell, site.first_cell + site.cells)):
                assert column == 0 or cells[column] == SPACE, (site, row, column)
            for column, code in codes.items():
                cells[column] = code
    return rows


def star_frames(rows: list[bytearray]) -> list[list[bytes]]:
    """Each site's window, frame by frame (blank, then the four sizes, those
    over the site's largest held at it): STAR_WINDOW_HEIGHT rows of
    STAR_WINDOW_WIDTH cells as they are to be on the screen."""
    frames = []
    for site in STAR_SITES:
        site_frames = []
        for size in range(STAR_FRAMES):
            drawn = [bytearray(row) for row in rows]
            place_star(drawn, site, min(size, site.largest))
            site_frames.append(b"".join(
                bytes(drawn[site.top + row][site.window_column:site.window_column + STAR_WINDOW_WIDTH])
                for row in range(STAR_WINDOW_HEIGHT)))
        frames.append(site_frames)
    return frames


def banner_asm(rows: list[bytearray], frames: list[list[bytes]]) -> str:
    window_bytes = STAR_WINDOW_WIDTH * STAR_WINDOW_HEIGHT
    site_bytes = STAR_FRAMES * window_bytes
    assert len(STAR_SITES) * site_bytes <= 0x100            # star_frames is indexed by X
    lines = [
        "; ***************************************************************************************",
        "; The banner across the top of the title's page of keys, and its twinkling stars",
        ";",
        "; Written by tools/dunjunz_revised/key_page_banner.py (uv run dr-banner); do not edit.",
        "; The DUNJUNZ logo from the 1987 title picture in teletext mosaic graphics: seven full",
        "; rows of 40 cells, so the cursor moves from each to the next by itself, each row's",
        "; graphics colour code first, with the codes of the stars' sites; text for print_text",
        "; (runs of spaces as their lengths), mosaic characters with bit 7 set, so that the MOS",
        "; puts them on the screen as they are; then a zero.",
        ".key_page_banner",
    ]
    lines += [text_bytes_asm(bytes(row)) for row in rows]
    lines += [
        "    equb 0",
        "",
        f"STAR_SITES = {len(STAR_SITES)}",
        f"STAR_TICK_CENTISECONDS = {STAR_TICK_CENTISECONDS}",
        f"STAR_WINDOW_WIDTH = {STAR_WINDOW_WIDTH}",
        f"STAR_WINDOW_BYTES = {window_bytes}",
        f"TWINKLE_FRAMES = {len(TWINKLE)}",
        "; Where each site's window is on the screen.",
        ".star_screen_lo",
        "    equb " + ", ".join(f"LO(mode_7_screen + {site.top * MODE_7_WIDTH + site.window_column})"
                                for site in STAR_SITES),
        ".star_screen_hi",
        "    equb " + ", ".join(f"HI(mode_7_screen + {site.top * MODE_7_WIDTH + site.window_column})"
                                for site in STAR_SITES),
        "; The ticks between each site's twinkles; and each site's count of ticks, which",
        "; show_keys moves on each tick, back to 0 at the period: it twinkles from 0 to",
        "; TWINKLE_FRAMES - 1.",
        ".star_periods",
        "    equb " + ", ".join(str(site.period) for site in STAR_SITES),
        ".star_counts",
        "    equb " + ", ".join(str(site.period - site.first) for site in STAR_SITES),
        "; Where each site's frames start in star_frames.",
        ".star_site_frames",
        "    equb " + ", ".join(str(index * site_bytes) for index in range(len(STAR_SITES))),
        "; The frames of a twinkle, as offsets in a site's frames.",
        ".twinkle_frames",
        "    equb " + ", ".join(str(size * window_bytes) for size in TWINKLE),
        "; Each site's window, frame by frame: blank, a dot, two crosses, and the largest with",
        "; its angles, each held at the site's largest; the cells by rows, as on the screen.",
        ".star_frames",
    ]
    for site, site_frames in zip(STAR_SITES, frames):
        for size, frame in enumerate(site_frames):
            lines.append("    equb " + ", ".join(f"&{cell:02x}" for cell in frame)
                         + f"  ; Row {site.top}, column {site.window_column}: size {size}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    rows = banner_with_sites()
    BANNER_ASM_FILEPATH.write_text(banner_asm(rows, star_frames(rows)))
    print(f"Wrote {BANNER_ASM_FILEPATH.relative_to(PROJECT_DIRPATH)}")


if __name__ == "__main__":
    main()
