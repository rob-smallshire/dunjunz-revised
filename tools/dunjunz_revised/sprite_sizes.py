"""Each sprite's width and height, as the game in memory would plot it.

The 1987 release keeps two tables of 120 bytes, sprite_widths and
sprite_heights, which the exit animation changes as a hero shrinks. The
revised game works the size out (sprite_size): the sprite numbers where the
size changes (sprite_size_first), the size from each (sprite_size_width,
sprite_size_height), and the shrinking hero's sprites (shrink_first,
shrink_steps, shrink_rows). Either way this gives the sizes plot_sprite
would use now. peek(address, length) reads the machine's memory.
"""

from __future__ import annotations

from collections.abc import Callable

SPRITE_COUNT = 120
SHRINKING_SPRITES = 7       # base + 1 to base + 7


def sprite_sizes(peek: Callable[[int, int], bytes], labels: dict[str, int]) -> list[tuple[int, int]]:
    if "sprite_widths" in labels:
        widths = peek(labels["sprite_widths"], SPRITE_COUNT)
        heights = peek(labels["sprite_heights"], SPRITE_COUNT)
        return list(zip(widths, heights))
    changes = labels["sprite_size_width"] - labels["sprite_size_first"]
    firsts = peek(labels["sprite_size_first"], changes)
    widths = peek(labels["sprite_size_width"], changes)
    heights = peek(labels["sprite_size_height"], changes)
    shrink_first, shrink_steps, shrink_rows = (peek(labels[name], 1)[0]
                                               for name in ("shrink_first", "shrink_steps", "shrink_rows"))
    sizes = []
    for sprite in range(SPRITE_COUNT):
        change = max(i for i, first in enumerate(firsts) if first <= sprite)
        width, height = widths[change], heights[change]
        if shrink_steps and 0 <= sprite - shrink_first < SHRINKING_SPRITES:
            width, height = width - shrink_steps, height - shrink_rows
        sizes.append((width, height))
    return sizes
