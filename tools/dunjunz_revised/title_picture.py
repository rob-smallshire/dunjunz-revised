"""The title picture, Screen, as the revised disc carries it.

The 1987 picture is changed at build time, not on the BBC:

- "Press any key" is replaced by the choice of keyboard players, in two
  lines of yellow, so it stands out from the credits above it: "Press 1-4
  for keyboard players" and "or fire for joysticks only" (the title also
  takes any other key as 4, the 1987 keys).
- "Revised" and the version are drawn in red on the bottom row.
- Both are drawn in a small font in the style of the picture's own
  lettering: its 1, a, c, e, i, k, n, P, r, s, t, v and y are copied from
  it, and the other letters drawn to match. The 1987 file stops short of the bottom row, so the
  revised one is longer, running to the end of screen memory.

title_png renders the picture as the README shows it (without the stars,
which the title program twinkles on it at run time).
"""

from __future__ import annotations

from dunjunz_revised.png import mode2_pixels, png

SCREEN_START = 0x3000
SCREEN_END = 0x8000
PICTURE_ADDRESS = 0x3280        # where Screen loads
SCREEN_WIDTH = 160              # MODE 2 pixels
SCREEN_HEIGHT = 256
BYTES_PER_CHARACTER_ROW = 640

RED, YELLOW = 1, 3

# The lines of "Press any key", descenders included, which the prompt replaces.
PRESS_ANY_KEY_LINES = range(230, 239)
# The prompt: the top line of each of its lines, which have descenders two
# lines below the glyphs' six, so they end at 246, clear of the version.
PROMPT = ("Press 1-4 for keyboard players", "or fire for joysticks only")
PROMPT_TOP_LINES = (229, 239)
# The centre of the credits ("By", "Julian Avis", "(c) Bug Byte 1987" and
# "Press any key"), in MODE 2 pixels, which the version line shares.
CREDITS_CENTRE_X = 87
VERSION_TOP_LINE = 249          # six lines, on the bottom character row (248-255)

# Glyphs six lines high, "#" for a pixel. Lower case has a four-line x-height;
# descenders add two lines below.
GLYPHS = {
    "R": ("##.", "#.#", "#.#", "##.", "#.#", "#.#"),
    "d": ("..#", "..#", ".##", "#.#", "#.#", ".##"),
    "e": ("...", "...", ".#.", "###", "#..", ".##"),
    "P": ("##.", "#.#", "#.#", "##.", "#..", "#.."),
    "a": ("...", "...", ".##", "#.#", "#.#", "###"),
    "b": ("#..", "#..", "##.", "#.#", "#.#", "##."),
    "c": ("..", "..", ".#", "#.", "#.", ".#"),
    "f": (".#", "#.", "##", "#.", "#.", "#."),
    "j": (".#", "..", ".#", ".#", ".#", ".#", ".#", "#."),
    "k": ("#..", "#..", "#.#", "##.", "#.#", "#.#"),
    "l": ("#", "#", "#", "#", "#", "#"),
    "n": ("...", "...", "#..", "##.", "#.#", "#.#"),
    "o": ("...", "...", ".#.", "#.#", "#.#", ".#."),
    "p": ("...", "...", "##.", "#.#", "#.#", "##.", "#..", "#.."),
    "r": ("..", "..", ".#", "#.", "#.", "#."),
    "t": ("#.", "##", "#.", "#.", "#.", "#."),
    "y": ("...", "...", "#.#", "#.#", "#.#", ".##", "..#", ".#."),
    "-": ("..", "..", "..", "##", "..", ".."),
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
    """The 1987 Screen file with the prompt and the version, to load at
    PICTURE_ADDRESS and run to SCREEN_END."""
    screen = bytearray(SCREEN_END - SCREEN_START)
    start = PICTURE_ADDRESS - SCREEN_START
    screen[start:start + len(original)] = original

    for line in PRESS_ANY_KEY_LINES:
        for x in range(SCREEN_WIDTH):
            colour = get_pixel(screen, x, line)
            assert colour in (0, RED), f"unexpected colour {colour} at ({x}, {line})"
            set_pixel(screen, x, line, 0)
    for text, top in zip(PROMPT, PROMPT_TOP_LINES):
        draw_centred(screen, text, top, YELLOW)

    draw_centred(screen, version_line(version), VERSION_TOP_LINE, RED)
    return bytes(screen[start:])


def draw_centred(screen: bytearray, text: str, top: int, colour: int) -> None:
    """Draw text centred under the credits."""
    left = CREDITS_CENTRE_X - text_width(text) // 2
    assert left >= 0 and left + text_width(text) <= SCREEN_WIDTH, text
    draw_text(screen, text, left, top, colour)


def title_png(picture: bytes) -> bytes:
    """A PNG of a picture loaded at PICTURE_ADDRESS (the screen above it
    black), each MODE 2 pixel 4 by 2 so that it has the BBC's proportions."""
    screen = bytearray(SCREEN_END - SCREEN_START)
    start = PICTURE_ADDRESS - SCREEN_START
    screen[start:start + len(picture)] = picture
    rows = [[colour for x in range(0, SCREEN_WIDTH, 2)
             for colour in mode2_pixels(screen[screen_offset(x, line)])]
            for line in range(SCREEN_HEIGHT)]
    return png(rows, 4, 2)
