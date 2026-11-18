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
    read_labels,
)
from dunjunz_revised.lockstep import RETURN, SPACE, hold_key, switch_on_heroes
from dunjunz_revised.machines import MACHINES, launched

GAME_FILENAMES = ("Dun1", "Coder", "Dunjunz")


def test_original_reassembly_matches_original(disc_filepaths):
    for name in GAME_FILENAMES:
        assert (ORIGINAL_BUILD_DIRPATH / name).read_bytes() == (REFERENCE_DIRPATH / name).read_bytes()


@pytest.mark.skipif(not REVISED_MUST_MATCH_ORIGINAL, reason="the revised game has diverged")
def test_revised_matches_original(disc_filepaths):
    for name in GAME_FILENAMES:
        assert (REVISED_BUILD_DIRPATH / name).read_bytes() == (REFERENCE_DIRPATH / name).read_bytes()


def run_until(bbc, address, seconds, start_key=None):
    """Run until address, tapping start_key (if any) every half second: SPACE
    starts the 1987 game, RETURN the revised one's hero menu. The game scans
    the matrix (OSBYTE &7A and &81) rather than reading the buffer, so typed
    keys are not seen."""
    bp = bbc.debugger.add_breakpoint(address)
    try:
        for _ in range(int(seconds / 0.5)):
            bbc.run_for_emulated_seconds(0.5)
            if bbc.cpu.pc == address:
                return True
            bbc.debugger.run()
            if start_key is not None:
                hold_key(bbc, *start_key)
        return False
    finally:
        bp.remove()


@pytest.mark.parametrize("build", ["original", "revised"])
def test_boots_into_play_on_dfs_0_90(disc_filepaths, build):
    if build == "original":
        disc_filepath, labels = ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game")
    else:
        disc_filepath, labels = REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    update_game = labels["update_game"]
    with launched(MACHINES["dfs090"]) as bbc:
        bbc.boot_disc(disc_filepath)
        switch_on_heroes(bbc, labels)           # the revised game's heroes start off
        start_key = SPACE if build == "original" else RETURN
        assert run_until(bbc, update_game, 120, start_key), f"PC &{bbc.cpu.pc:04X}"
