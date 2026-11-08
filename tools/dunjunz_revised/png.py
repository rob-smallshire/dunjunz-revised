"""PNG images of MODE 2 pixels, in the default palette.

The game never changes the palette from MODE 2's default. Flashing colours
8-15 are drawn in their first colour, n-8.
"""

from __future__ import annotations

import struct
import zlib

# MODE 2's default palette, colours 0-7; 8-15 flash between colour n-8 and 15-n.
PALETTE = [
    (0, 0, 0), (255, 0, 0), (0, 255, 0), (255, 255, 0),
    (0, 0, 255), (255, 0, 255), (0, 255, 255), (255, 255, 255),
]


def mode2_pixels(byte: int) -> tuple[int, int]:
    """The logical colours of a MODE 2 byte's left and right pixels."""
    def colour(bits):
        return sum(((byte >> bit) & 1) << place for place, bit in enumerate(bits))
    return colour((1, 3, 5, 7)), colour((0, 2, 4, 6))   # bit 7 (left) and 6 (right) are colour bit 3


def png(rows: list[list[int]], pixel_width: int, pixel_height: int) -> bytes:
    """A PNG of rows of logical colours, each pixel pixel_width by pixel_height."""
    height = len(rows) * pixel_height
    width = (len(rows[0]) if rows else 0) * pixel_width
    raw = bytearray()
    for row in rows:
        line = bytearray([0])
        for colour in row:
            line.extend(bytes(PALETTE[colour & 7]) * pixel_width)
        raw.extend(line * pixel_height)

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body))

    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", max(width, 1), max(height, 1), 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw) if raw else b"\0\0\0\0", 9))
            + chunk(b"IEND", b""))
