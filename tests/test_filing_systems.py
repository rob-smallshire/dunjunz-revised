"""The revised game loads its levels under each filing system configuration.

Each machine boots BASIC, selects the disc filing system and runs the title;
the game starts level 1, then moves on to level 2 (as if a hero survived),
which loads Setup and Level2 again with the game's workspace handed back to
the filing system and claimed again. Level 2's wall map must be the file's.
"""

from __future__ import annotations

import pytest

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.lockstep import SPACE, hold_key, switch_on_heroes
from dunjunz_revised.machines import MACHINES, launched

MACHINE_KEYS = [
    "dfs090", "dfs098", "dnfs120", "dnfs302", "dfs226",
    "dnfs120_econet", "dfs226_anfs418", "dfs226_nfs365", "dfs226_copro",
    "bplus", "bplus128",
]
MAP_BYTES = 0xC9
LEVEL_WALLS_OFFSET = 0xE0       # level_walls in the level file


def run_to(bbc, address, seconds, press_space=False):
    bp = bbc.debugger.add_breakpoint(address)
    try:
        for _ in range(int(seconds / 0.5)):
            bbc.run_for_emulated_seconds(0.5)
            if bbc.cpu.pc == address:
                return True
            bbc.debugger.run()
            if press_space:
                hold_key(bbc, *SPACE)
        return False
    finally:
        bp.remove()


@pytest.mark.parametrize("machine_key", MACHINE_KEYS)
def test_levels_load(disc_filepaths, machine_key):
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with launched(MACHINES[machine_key]) as bbc:
        bbc.run_for_emulated_seconds(3)
        bbc.disc.drive0.insert(REVISED_DISC_FILEPATH, write_protect=True)
        bbc.keyboard.type("*DISC\r")
        bbc.run_for_emulated_seconds(1)
        bbc.keyboard.type("*RUN DUNJUNZ\r")
        bbc.run_for_emulated_seconds(3)     # let the typing finish before SPACE is held
        switch_on_heroes(bbc, labels)
        assert run_to(bbc, labels["update_game"], 120, press_space=True), \
            f"level 1 not reached; PC &{bbc.cpu.pc:04X}"
        bbc.cpu.pc = labels["next_level"]
        assert run_to(bbc, labels["update_game"], 60), f"level 2 not reached; PC &{bbc.cpu.pc:04X}"
        assert bbc.memory.address.peek[0x08BC] == 2
        walls = bytes(bbc.memory.address.peek[labels["room_walls"]:labels["room_walls"] + MAP_BYTES])
        level2 = (REVISED_BUILD_DIRPATH / "Level2").read_bytes()
        expected = level2[LEVEL_WALLS_OFFSET:LEVEL_WALLS_OFFSET + MAP_BYTES]
        # The first eight bytes double as character 128's definition, which text overwrites.
        assert walls[8:] == expected[8:]


def test_refuses_a_page_too_high(disc_filepaths):
    """With DFS and ADFS, PAGE is &1F00: the title says the game cannot run, and
    returns, rather than let the game overwrite private workspace."""
    with launched(MACHINES["dfs226_adfs130"]) as bbc:
        bbc.run_for_emulated_seconds(3)
        bbc.disc.drive0.insert(REVISED_DISC_FILEPATH, write_protect=True)
        bbc.keyboard.type("*RUN DUNJUNZ\r")
        bbc.run_for_emulated_seconds(4)
        text = bbc.video.screen_text().text.replace("\n", "")
        assert "needs PAGE at &1C00 or below" in text
        assert text.rstrip().endswith(">")
