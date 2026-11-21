"""The banner on the title's page of keys (tools/dunjunz_revised/key_page_banner.py):
the checked-in asm/defs/key_page_banner.asm is what the 1987 logo converts to.
"""

from __future__ import annotations

from dunjunz_revised.key_page_banner import (
    BANNER_ASM_FILEPATH,
    BANNER_ROWS,
    FIRE_COLOURS,
    MODE_7_WIDTH,
    banner_asm,
    banner_rows,
)


def test_the_banner_is_up_to_date():
    assert BANNER_ASM_FILEPATH.read_text() == banner_asm(banner_rows())


def test_the_banner_fills_its_rows_with_bytes_the_mos_writes_as_they_are():
    rows = banner_rows()
    assert len(rows) == BANNER_ROWS
    assert all(len(row) == MODE_7_WIDTH for row in rows)
    assert all(byte >= 0x80 for row in rows for byte in row)
    assert [row[0] for row in rows] == list(FIRE_COLOURS)
