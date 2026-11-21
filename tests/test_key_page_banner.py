"""The banner on the title's page of keys (tools/dunjunz_revised/key_page_banner.py):
the checked-in asm/defs/key_page_banner.asm is what the 1987 logo converts to,
and its stars fit their sites.
"""

from __future__ import annotations

from dunjunz_revised.key_page_banner import (
    BANNER_ASM_FILEPATH,
    BANNER_ROWS,
    FIRE_COLOURS,
    MODE_7_WIDTH,
    STAR_FRAMES,
    STAR_SITES,
    banner_asm,
    banner_with_sites,
    star_frames,
)
from dunjunz_revised.page_text import packed, unpacked


def test_the_banner_is_up_to_date():
    rows = banner_with_sites()
    assert BANNER_ASM_FILEPATH.read_text() == banner_asm(rows, star_frames(rows))


def test_the_banner_fills_its_rows_with_bytes_the_mos_writes_as_they_are():
    """Every cell is a space, a teletext code or a mosaic character with bit 7
    set, and each row starts with its colour, or white for a star by the D."""
    rows = banner_with_sites()
    assert len(rows) == BANNER_ROWS
    assert all(len(row) == MODE_7_WIDTH for row in rows)
    assert all(cell == 0x20 or cell >= 0x80 for row in rows for cell in row)
    assert [row[0] for row in rows] == [colour if not any(site.white_column == 0 and site.top <= index < site.top + site.rows
                                                          for site in STAR_SITES) else 0x97
                                        for index, colour in enumerate(FIRE_COLOURS)]


def test_each_star_grows_and_differs_only_in_its_cells():
    """Each site's frames: blank first, as printed, then stars no smaller, and
    each changes only the site's own cells."""
    rows = banner_with_sites()
    for site, frames in zip(STAR_SITES, star_frames(rows)):
        assert len(frames) == STAR_FRAMES
        lit = [sum(bin(cell & 0x5F).count("1") for cell in frame if cell >= 0xA0) for frame in frames]
        assert lit[0] == lit_in_window(rows, site)
        assert lit == sorted(lit) and lit[1] > lit[0]


def lit_in_window(rows, site):
    return sum(bin(cell & 0x5F).count("1") for row in range(2)
               for cell in rows[site.top + row][site.window_column:site.window_column + 3] if cell >= 0xA0)


def test_page_text_packs_runs_of_spaces():
    text = b"KEY1" + bytes([0x82]) + b"up" + b" " * 2 + b"x" + b" " * 25 + b"y z"
    assert unpacked(packed(text)) == text
    assert len(packed(text)) < len(text)
