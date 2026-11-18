"""The plotter, run on its own in py65 (sixtyfive.py), against a model.

Each sprite is plotted at several places, on a screen holding a pattern, and
the screen must come out as the model says: the sprite copied over what was
there, row by row, in the MODE 2 layout of 640-byte character rows. This
runs in a second or two, and counts cycles, so it is where the plotter is
worked on.
"""

from __future__ import annotations

import random

import pytest

from dunjunz_revised.sprite_sizes import sprite_sizes
from dunjunz_revised.sixtyfive import SCREEN_END, SCREEN_START, GameImage

SPRITE_COUNT = 120
PLOT_X, PLOT_Y, SPRITE_NUMBER = 0x70, 0x71, 0x7A
PLACES = ((1, 1), (0x23, 0x67), (0x10, 0x2B), (0x40, 0x0E), (0x07, 0xA4))


@pytest.fixture(scope="module")
def image(disc_filepaths):
    return GameImage.revised()


def screen_offset(column: int, line: int) -> int:
    return (line >> 3) * 640 + (line & 7) + column * 8


def sprite(image, number):
    address = image.peek(image.address(f"sprite_addr_hi+{number}"))[0] << 8 | image.peek(
        image.address(f"sprite_addr_lo+{number}"))[0]
    width, height = sprite_sizes(image.peek, image.labels)[number]
    return width, height, image.peek(address, width * height)


def patterned_screen(image, seed):
    pattern = random.Random(seed).randbytes(SCREEN_END - SCREEN_START)
    image.poke(SCREEN_START, pattern)
    return bytearray(pattern)


def plot(image, number, column, line):
    image.poke(PLOT_X, bytes([column, line]))
    image.poke(SPRITE_NUMBER, bytes([number]))
    return image.call("plot_sprite")


def solid(screen, width, height, data, column, line):
    for row in range(height):
        for byte in range(width):
            screen[screen_offset(column + byte, line + row)] = data[row * width + byte]


@pytest.mark.parametrize("place", PLACES)
def test_every_sprite_is_plotted_solid(image, place):
    column, line = place
    for number in range(SPRITE_COUNT):
        width, height, data = sprite(image, number)
        if column + width > 80 or line + height > 200:
            continue
        expected = patterned_screen(image, number)
        plot(image, number, column, line)
        solid(expected, width, height, data, column, line)
        assert image.peek(SCREEN_START, SCREEN_END - SCREEN_START) == bytes(expected), f"sprite &{number:02X}"


def test_cycles_per_cell_sprite(image):
    """Report what a 4 x 12 sprite costs to plot (the hero facing up)."""
    cycles = plot(image, 1, 1, 1)
    print(f"plot_sprite, a 4 x 12 sprite: {cycles} cycles")
    assert cycles > 0


def see_through(screen, width, height, data, column, line):
    for row in range(height):
        for byte in range(width):
            offset = screen_offset(column + byte, line + row)
            sprite_byte = data[row * width + byte]
            screen[offset] = sum((sprite_byte & mask) if sprite_byte & mask else (screen[offset] & mask)
                                 for mask in (0xAA, 0x55))


@pytest.mark.parametrize("place", PLACES)
def test_every_sprite_is_plotted_see_through(image, place):
    """Four bytes wide: black is see-through. Any other width: solid."""
    column, line = place
    for number in range(SPRITE_COUNT):
        width, height, data = sprite(image, number)
        if column + width > 80 or line + height > 200:
            continue
        expected = patterned_screen(image, number)
        image.poke(PLOT_X, bytes([column, line]))
        image.poke(SPRITE_NUMBER, bytes([number]))
        image.call("plot_see_through")
        (see_through if width == 4 else solid)(expected, width, height, data, column, line)
        assert image.peek(SCREEN_START, SCREEN_END - SCREEN_START) == bytes(expected), f"sprite &{number:02X}"


def test_cycles_see_through(image):
    image.poke(PLOT_X, bytes([1, 1]))
    image.poke(SPRITE_NUMBER, bytes([1]))
    cycles = image.call("plot_see_through")
    print(f"plot_see_through, a 4 x 12 sprite: {cycles} cycles")
    assert cycles > 0
