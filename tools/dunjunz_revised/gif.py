"""Animated GIFs of frames of colour indices.

Each frame after the first is stored as the rectangle that holds its
changes, with the pixels it does not change left transparent, drawn over
the frame before (disposal 1), so a few small stars twinkling on a large
picture make a small file.
"""

from __future__ import annotations

import struct

MAX_CODES = 4096
LOOP_FOREVER = 0


def lzw_encode(pixels: bytes, min_code_size: int) -> bytes:
    """GIF's variable-length LZW, starting with a clear code and starting
    afresh with another whenever the 4096 codes run out."""
    clear, end = 1 << min_code_size, (1 << min_code_size) + 1
    out = bytearray()
    bits = bit_count = 0

    def emit(code: int, size: int) -> None:
        nonlocal bits, bit_count
        bits |= code << bit_count
        bit_count += size
        while bit_count >= 8:
            out.append(bits & 0xFF)
            bits >>= 8
            bit_count -= 8

    def fresh() -> dict[bytes, int]:
        return {bytes([n]): n for n in range(clear)}

    size = min_code_size + 1
    table, next_code = fresh(), end + 1
    emit(clear, size)
    current = b""
    for pixel in pixels:
        extended = current + bytes([pixel])
        if extended in table:
            current = extended
            continue
        emit(table[current], size)
        if next_code < MAX_CODES:
            table[extended] = next_code
            next_code += 1
            if next_code > 1 << size and size < 12:
                size += 1
        else:
            emit(clear, size)
            table, next_code, size = fresh(), end + 1, min_code_size + 1
        current = bytes([pixel])
    if current:
        emit(table[current], size)
    emit(end, size)
    if bit_count:
        out.append(bits & 0xFF)
    return bytes(out)


def sub_blocks(data: bytes) -> bytes:
    """Data as GIF sub-blocks of up to 255 bytes, with the empty one that ends them."""
    return b"".join(bytes([len(data[i:i + 255])]) + data[i:i + 255] for i in range(0, len(data), 255)) + b"\0"


def changed_box(before: bytes, after: bytes, width: int) -> tuple[int, int, int, int] | None:
    """The smallest (left, top, right, bottom) holding every pixel that differs, or None."""
    rows = [y for y in range(len(after) // width)
            if before[y * width:(y + 1) * width] != after[y * width:(y + 1) * width]]
    if not rows:
        return None
    top, bottom = rows[0], rows[-1] + 1
    columns = [x for x in range(width)
               if any(before[y * width + x] != after[y * width + x] for y in range(top, bottom))]
    return columns[0], top, columns[-1] + 1, bottom


def animated_gif(width: int, height: int, palette: list[tuple[int, int, int]],
                 frames: list[tuple[bytes, int]]) -> bytes:
    """An animated GIF, looping forever, of frames of colour indices into
    palette (at most 255 colours: one more index is kept for transparency),
    each shown for its delay in centiseconds. Consecutive frames that are
    the same must be merged by the caller."""
    assert len(palette) < 256
    transparent = len(palette)
    bits = max(1, (transparent).bit_length())       # the table holds 2 ** bits colours
    table = b"".join(bytes(colour) for colour in palette)
    table += bytes(3 * (2 ** bits) - len(table))
    min_code_size = max(2, bits)

    out = bytearray(b"GIF89a")
    out += struct.pack("<HHBBB", width, height, 0x80 | 0x70 | (bits - 1), 0, 0)
    out += table
    out += b"\x21\xFF\x0BNETSCAPE2.0\x03\x01" + struct.pack("<H", LOOP_FOREVER) + b"\0"
    previous = None
    for pixels, delay in frames:
        assert len(pixels) == width * height
        if previous is None:
            left, top, right, bottom = 0, 0, width, height
            image = pixels
        else:
            box = changed_box(previous, pixels, width)
            assert box is not None, "consecutive frames are the same"
            left, top, right, bottom = box
            image = bytes(
                pixels[y * width + x] if pixels[y * width + x] != previous[y * width + x] else transparent
                for y in range(top, bottom) for x in range(left, right))
        # Graphic control: disposal 1 (leave the frame in place), transparency on.
        out += b"\x21\xF9\x04" + struct.pack("<BHB", 0x04 | 0x01, delay, transparent) + b"\0"
        out += struct.pack("<BHHHHB", 0x2C, left, top, right - left, bottom - top, 0)
        out += bytes([min_code_size]) + sub_blocks(lzw_encode(image, min_code_size))
        previous = pixels
    out += b"\x3B"
    return bytes(out)
