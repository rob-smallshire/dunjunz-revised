"""Render the game's sprites as an HTML table.

    uv run dr-sprites                 # the revised game: build/sprites-revised.html
    uv run dr-sprites --original      # the 1987 game: build/sprites-original.html

Boots the built disc in beebium, starts a game, and reads the 120 sprites
through the game's own tables (sprite_addr_lo/hi, sprite_widths,
sprite_heights) at the first frame of level 1, so what is shown is exactly
what plot_sprite draws. A sprite's data is row by row, each byte two MODE 2
pixels; it is drawn here in the default MODE 2 palette (the game never
changes it), each pixel twice as wide as it is tall, as on the screen.
Sprites whose data starts at a label are named after it. The level's wall
sprite is level 1's. Flashing colours 8-15 are shown in their first colour
and marked.
"""

from __future__ import annotations

import argparse
import base64
import html
from pathlib import Path

from dunjunz_revised.build import (
    BUILD_DIRPATH,
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    read_labels,
)
from dunjunz_revised.lockstep import game_run
from dunjunz_revised.png import mode2_pixels, png

SPRITE_COUNT = 120
GAME_RANGES = ((0x0400, 0x3000), (0x6E80, 0x8000))

PIXEL_WIDTH = 8          # a MODE 2 pixel drawn 8 by 4: twice as wide as tall
PIXEL_HEIGHT = 4


def read_sprites(run) -> list[tuple[int, int, int, bytes]]:
    """Each sprite's data address, width in bytes, height in rows and data,
    read through the game's sprite tables."""
    labels = run.labels
    lo = run.peek(labels["sprite_addr_lo"], SPRITE_COUNT)
    hi = run.peek(labels["sprite_addr_hi"], SPRITE_COUNT)
    widths = run.peek(labels["sprite_widths"], SPRITE_COUNT)
    heights = run.peek(labels["sprite_heights"], SPRITE_COUNT)
    sprites = []
    for n in range(SPRITE_COUNT):
        address = hi[n] << 8 | lo[n]
        sprites.append((address, widths[n], heights[n], run.peek(address, widths[n] * heights[n])))
    return sprites


def sprite_colours(width: int, height: int, data: bytes) -> list[list[int]]:
    rows = []
    for row in range(height):
        pixels = []
        for byte in data[row * width:(row + 1) * width]:
            pixels.extend(mode2_pixels(byte))
        rows.append(pixels)
    return rows


def sprite_names(labels: dict[str, int]) -> dict[int, str]:
    """Data address to label, for labels that look like sprite data."""
    names = {}
    for name, address in sorted(labels.items(), key=lambda item: item[0]):
        if "sprite" in name and not name.startswith(("plot_", "draw_", "sprite_addr", "sprite_widths",
                                                     "sprite_heights")):
            names.setdefault(address, name)
    return names


def render(title: str, sprites, names) -> str:
    cells = []
    for n, (address, width, height, data) in enumerate(sprites):
        rows = sprite_colours(width, height, data)
        flashing = any(colour >= 8 for row in rows for colour in row)
        image = base64.b64encode(png(rows, PIXEL_WIDTH, PIXEL_HEIGHT)).decode() if width and height else ""
        name = names.get(address, "")
        cells.append(
            f'<figure><div class="img">'
            + (f'<img src="data:image/png;base64,{image}" alt="sprite &amp;{n:02X}">' if image else "<i>empty</i>")
            + f'</div><figcaption><b>&amp;{n:02X}</b> {html.escape(name)}<br>'
            f'{width * 2}&times;{height} px at &amp;{address:04X}'
            + (" <em>flashing</em>" if flashing else "") + "</figcaption></figure>")
    return f"""<!doctype html>
<meta charset="utf-8">
<title>{html.escape(title)}</title>
<style>
body {{ font: 13px system-ui, sans-serif; background: #222; color: #ddd; margin: 16px; }}
main {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(150px, 1fr)); gap: 12px; }}
figure {{ margin: 0; padding: 8px; background: #333; border-radius: 4px; }}
.img {{ min-height: 40px; display: flex; align-items: center; justify-content: center;
        background: repeating-conic-gradient(#3a3a3a 0% 25%, #444 0% 50%) 0 0 / 16px 16px; }}
img {{ image-rendering: pixelated; }}
figcaption {{ margin-top: 6px; word-break: break-all; }}
em {{ color: #fc6; }}
</style>
<h1>{html.escape(title)}</h1>
<p>Sprite number, label, size in MODE 2 pixels, and data address. Black is drawn as black:
sprites are stored over the screen, not masked.</p>
<main>
{chr(10).join(cells)}
</main>
"""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--original", action="store_true", help="the 1987 game instead of the revised one")
    arguments = parser.parse_args()
    if arguments.original:
        disc_filepath, labels, which = ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"), "original"
    else:
        disc_filepath, labels, which = REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"), "revised"
    with game_run(disc_filepath, labels, GAME_RANGES) as run:
        sprites = read_sprites(run)
    output_filepath = BUILD_DIRPATH / f"sprites-{which}.html"
    output_filepath.write_text(render(f"Dunjunz sprites ({which})", sprites, sprite_names(labels)))
    print(f"Wrote {output_filepath}")


if __name__ == "__main__":
    main()
