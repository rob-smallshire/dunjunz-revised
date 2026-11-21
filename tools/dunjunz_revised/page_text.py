"""Text for the title's print_text (asm/title.asm), as beebasm.

print_text sends each byte to OSASCI, so a carriage return starts a new
line, except bytes 1 to MAX_SPACE_RUN, each of which prints that many
spaces: most of the bytes of the title's MODE 7 page would otherwise be
spaces. A zero ends the text.
"""

from __future__ import annotations

import re

MAX_SPACE_RUN = 12                  # below 13, the carriage return
SPACE_RUN = re.compile(rb" {2,}")


def packed(text: bytes) -> bytes:
    """Text with its runs of two or more spaces as their lengths."""
    assert not any(1 <= byte <= MAX_SPACE_RUN for byte in text)

    def run(match: re.Match) -> bytes:
        length = len(match.group())
        return bytes([MAX_SPACE_RUN] * (length // MAX_SPACE_RUN) + ([length % MAX_SPACE_RUN] if length % MAX_SPACE_RUN else []))

    return SPACE_RUN.sub(run, text)


def unpacked(text: bytes) -> bytes:
    """Packed text as print_text prints it."""
    return b"".join(b" " * byte if 1 <= byte <= MAX_SPACE_RUN else bytes([byte]) for byte in text)


def text_bytes_asm(text: bytes) -> str:
    """Text, packed, as an equb line: printable characters as strings, other
    bytes as numbers."""
    parts, characters = [], ""
    for byte in packed(text):
        if 0x20 <= byte < 0x7F and byte != ord('"'):
            characters += chr(byte)
            continue
        if characters:
            parts.append(f'"{characters}"')
            characters = ""
        parts.append(f"&{byte:02x}")
    if characters:
        parts.append(f'"{characters}"')
    return "    equb " + ", ".join(parts)
