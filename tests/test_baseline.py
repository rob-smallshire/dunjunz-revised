"""The baseline and the revised game, as built, boot into play.

While build.REVISED_MUST_MATCH_ORIGINAL holds, the revised sources must
assemble to the original files.
"""

from __future__ import annotations

import pytest

from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REFERENCE_DIRPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    REVISED_MUST_MATCH_ORIGINAL,
)
from dunjunz_revised.machines import MACHINES, launched

UPDATE_GAME = 0x1CC0   # the frame update, reached once play starts
GAME_FILENAMES = ("Dun1", "Coder", "Dunjunz")


def test_original_reassembly_matches_original(disc_filepaths):
    for name in GAME_FILENAMES:
        assert (ORIGINAL_BUILD_DIRPATH / name).read_bytes() == (REFERENCE_DIRPATH / name).read_bytes()


@pytest.mark.skipif(not REVISED_MUST_MATCH_ORIGINAL, reason="the revised game has diverged")
def test_revised_matches_original(disc_filepaths):
    for name in GAME_FILENAMES:
        assert (REVISED_BUILD_DIRPATH / name).read_bytes() == (REFERENCE_DIRPATH / name).read_bytes()


def hold_space(bbc, seconds=0.1):
    """Hold SPACE on the keyboard matrix. The game scans the matrix (OSBYTE
    &7A and &81) rather than reading the buffer, so typed keys are not seen."""
    bbc.keyboard.key_down(" ")
    bbc.run_for_emulated_seconds(seconds)
    bbc.keyboard.key_up(" ")


def run_until(bbc, address, seconds, press_space=False):
    bp = bbc.debugger.add_breakpoint(address)
    try:
        for _ in range(int(seconds / 0.5)):
            bbc.run_for_emulated_seconds(0.5)
            if bbc.cpu.pc == address:
                return True
            bbc.debugger.run()
            if press_space:
                hold_space(bbc)
        return False
    finally:
        bp.remove()


@pytest.mark.parametrize("disc_filepath", [ORIGINAL_DISC_FILEPATH, REVISED_DISC_FILEPATH], ids=["original", "revised"])
def test_boots_into_play_on_dfs_0_90(disc_filepaths, disc_filepath):
    with launched(MACHINES["dfs090"]) as bbc:
        bbc.boot_disc(disc_filepath)
        assert run_until(bbc, UPDATE_GAME, 120, press_space=True), f"PC &{bbc.cpu.pc:04X}"
