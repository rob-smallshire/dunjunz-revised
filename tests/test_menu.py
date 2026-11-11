"""The title and hero menu answer keys tapped as a player taps them.

The other tests hold SPACE from boot to the first frame. A held key is found
by the MOS's 100Hz keyboard scan, but a fresh press is found only through the
System VIA's keyboard interrupt. Booted with SHIFT+BREAK, DFS 2.26 and DNFS
1.20 *RUN !BOOT (the title) with interrupts disabled, the game inherited
that, and the menu waited in OSRDCH for a key that never came. Here each
key is pressed and released in turn.
"""

from __future__ import annotations

import pytest

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.lockstep import SPACE, UPDATE_GAME, hold_key, inkey_to_matrix
from dunjunz_revised.machines import MACHINES, launched

KEY_1 = inkey_to_matrix(0xCF)       # INKEY -49


@pytest.mark.parametrize("machine_key", ["dfs090", "dfs226", "dnfs120"])
def test_menu_answers_tapped_keys(disc_filepaths, machine_key):
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    entry_address = labels["menu_hero_entries"]   # the Ranger's KEYS/NO/JOYn

    with launched(MACHINES[machine_key]) as bbc:
        def ranger_entry():
            return bytes(bbc.memory.address.peek[entry_address:entry_address + 4])

        def tap(key):
            hold_key(bbc, *key)
            bbc.run_for_emulated_seconds(0.5)

        bbc.boot_disc(REVISED_DISC_FILEPATH)
        bbc.run_for_emulated_seconds(8)
        tap(SPACE)                                  # leave the title
        bbc.debugger.run_to(labels["menu_key_loop"], timeout=120)
        bbc.run_for_emulated_seconds(0.5)           # the menu waits for a key

        tap(KEY_1)
        assert ranger_entry() == b"NO  "
        tap(KEY_1)
        assert ranger_entry() == b"KEYS"

        tap(SPACE)
        bbc.debugger.run_to(labels[UPDATE_GAME], timeout=120)
        assert bbc.cpu.pc == labels[UPDATE_GAME]
