"""No code runs off its end into data or into a gap.

The 1987 code relies in places on falling through from one routine into the
next. Moving code between modules can separate them: shrink_hero_sprites
once ended a module where the original fell through to &1C00, and ran into
the Chalice sprite's data instead, so the exit descent crashed. This reads
beebasm's listings and reports every instruction that is not an RTS, JMP,
RTI or BRK and is followed by data, or by a gap in the addresses.
"""

from __future__ import annotations

import re

from dunjunz_revised.build import REVISED_BUILD_DIRPATH

LINE = re.compile(r"^\s+([0-9A-F]{4})   ((?:[0-9A-F]{2} ?)+?)\s*(?:  ([A-Z]{3})\b(.*))?$")
ENDS = {"RTS", "JMP", "RTI", "BRK"}

# (listing, last label, mnemonic): instructions that are followed by data but never
# fall through, as in the 1987 code.
NEVER_FALL_THROUGH = {
    ("dunjunz", "next_queue_entry", "BNE"),     # always taken: the queue has a free entry
    ("title", "send_blank_vdu", "JSR"),         # OSCLI *RUN GAME, which never returns
    ("title", "black_colours", "JSR"),          # leave_title, which never returns
    ("title", "star_not_showing", "BNE"),       # always taken: X = 20
}


def instructions(listing_filepath):
    """(address, size, mnemonic or None for data, last label) for each emitted line."""
    rows, label = [], ""
    for line in listing_filepath.read_text().splitlines():
        if line.startswith("."):
            label = line[1:]
            continue
        match = LINE.match(line)
        if match:
            rows.append((int(match.group(1), 16), len(match.group(2).split()), match.group(3), label))
    return rows


def falls_off(stem):
    rows = instructions(REVISED_BUILD_DIRPATH / f"{stem}.lst")
    found = []
    for (address, size, mnemonic, label), (next_address, _, next_mnemonic, _) in zip(rows, rows[1:]):
        if mnemonic is None or mnemonic in ENDS or (stem, label, mnemonic) in NEVER_FALL_THROUGH:
            continue
        if next_mnemonic is None or next_address != address + size:
            found.append(f"{stem}: {mnemonic} at &{address:04X} (after .{label})")
    return found


def test_no_code_falls_off_its_end(disc_filepaths):
    assert falls_off("dunjunz") + falls_off("title") == []
