"""The title picture, Screen, as the revised disc carries it.

The 1987 picture is changed at build time, not on the BBC:

- "Press any key" is recoloured from red to yellow, so it stands out from
  the credits above it.
- "Revised" and the version are drawn in red on the bottom row, in a small
  font in the style of the picture's own lettering (its 1, e, i, s and v
  are copied from it). The 1987 file stops short of the bottom row, so the
  revised one is longer, running to the end of screen memory.
"""

from __future__ import annotations

SCREEN_START = 0x3000
SCREEN_END = 0x8000
PICTURE_ADDRESS = 0x3280        # where Screen loads
SCREEN_WIDTH = 160              # MODE 2 pixels
BYTES_PER_CHARACTER_ROW = 640

RED, YELLOW = 1, 3

# The lines of "Press any key", descenders included.
PRESS_ANY_KEY_LINES = range(230, 239)
# The centre of the credits ("By", "Julian Avis", "(c) Bug Byte 1987" and
# "Press any key"), in MODE 2 pixels, which the version line shares.
CREDITS_CENTRE_X = 87
VERSION_TOP_LINE = 249          # six lines, on the bottom character row (248-255)

# Glyphs six lines high, "#" for a pixel. Lower case has a four-line x-height.
GLYPHS = {
    "R": ("##.", "#.#", "#.#", "##.", "#.#", "#.#"),
    "d": ("..#", "..#", ".##", "#.#", "#.#", ".##"),
    "e": ("...", "...", ".#.", "###", "#..", ".##"),
    "i": ("#", ".", "#", "#", "#", "#"),
    "s": ("...", "...", ".##", "#..", ".#.", "##."),
    "v": ("...", "...", "#.#", "#.#", ".#.", ".#."),
    "0": (".#.", "#.#", "#.#", "#.#", "#.#", ".#."),
    "1": ("#", "#", "#", "#", "#", "#"),
    "2": ("##.", "..#", "..#", ".#.", "#..", "###"),
    "3": ("##.", "..#", ".#.", "..#", "..#", "##."),
    "4": ("#..", "#.#", "#.#", "###", "..#", "..#"),
    "5": ("###", "#..", "##.", "..#", "..#", "##."),
    "6": (".#.", ".#.", "#..", "###", "#.#", "###"),
    "7": ("###", "..#", ".#.", ".#.", "#..", "#.."),
    "8": (".#.", "#.#", ".#.", "#.#", "#.#", ".#."),
    "9": ("###", "#.#", "###", "..#", ".#.", ".#."),
    ".": (".", ".", ".", ".", ".", "#"),
    " ": ("..", "..", "..", "..", "..", ".."),
}
GLYPH_GAP = 1


def screen_offset(x: int, line: int) -> int:
    """The offset from SCREEN_START of the byte holding pixel x of a line."""
    return (line >> 3) * BYTES_PER_CHARACTER_ROW + (line & 7) + (x >> 1) * 8


def pixel_mask(x: int) -> int:
    """The bits of a MODE 2 byte that hold pixel x: bits 7, 5, 3, 1 for the
    left pixel, 6, 4, 2, 0 for the right."""
    return 0xAA if x % 2 == 0 else 0x55


def colour_bits(x: int, colour: int) -> int:
    """Colour as the bits of pixel x within its byte."""
    shift = 1 if x % 2 == 0 else 0
    return sum(((colour >> bit) & 1) << (2 * bit + shift) for bit in range(4))


def get_pixel(screen: bytearray, x: int, line: int) -> int:
    byte = screen[screen_offset(x, line)]
    shift = 1 if x % 2 == 0 else 0
    return sum(((byte >> (2 * bit + shift)) & 1) << bit for bit in range(4))


def set_pixel(screen: bytearray, x: int, line: int, colour: int) -> None:
    offset = screen_offset(x, line)
    screen[offset] = (screen[offset] & ~pixel_mask(x) & 0xFF) | colour_bits(x, colour)


def text_width(text: str) -> int:
    return sum(len(GLYPHS[c][0]) for c in text) + GLYPH_GAP * (len(text) - 1)


def draw_text(screen: bytearray, text: str, left: int, top: int, colour: int) -> None:
    x = left
    for c in text:
        glyph = GLYPHS[c]
        for row, pixels in enumerate(glyph):
            for column, pixel in enumerate(pixels):
                if pixel == "#":
                    set_pixel(screen, x + column, top + row, colour)
        x += len(glyph[0]) + GLYPH_GAP


def version_line(version: str) -> str:
    return f"Revised {version}"


def revised_picture(original: bytes, version: str) -> bytes:
    """The 1987 Screen file, recoloured and with the version, to load at
    PICTURE_ADDRESS and run to SCREEN_END."""
    screen = bytearray(SCREEN_END - SCREEN_START)
    start = PICTURE_ADDRESS - SCREEN_START
    screen[start:start + len(original)] = original

    for line in PRESS_ANY_KEY_LINES:
        for x in range(SCREEN_WIDTH):
            colour = get_pixel(screen, x, line)
            assert colour in (0, RED), f"unexpected colour {colour} at ({x}, {line})"
            if colour == RED:
                set_pixel(screen, x, line, YELLOW)

    text = version_line(version)
    left = CREDITS_CENTRE_X - text_width(text) // 2
    assert left >= 0 and left + text_width(text) <= SCREEN_WIDTH, text
    draw_text(screen, text, left, VERSION_TOP_LINE, RED)
    return bytes(screen[start:])
