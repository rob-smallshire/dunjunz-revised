"""The title and hero menu answer keys tapped as a player taps them.

The other tests hold a key from boot to the first frame. A held key is found
by the MOS's 100Hz keyboard scan, but a fresh press is found only through the
System VIA's keyboard interrupt. Booted with SHIFT+BREAK, DFS 2.26 and DNFS
1.20 *RUN !BOOT (the title) with interrupts disabled, the game inherited
that, and the menu waited in OSRDCH for a key that never came. Here each
key is pressed and released in turn.
"""

from __future__ import annotations

import pytest

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.lockstep import FIRE_KEYS, RETURN, SPACE, UPDATE_GAME, hold_key, inkey_to_matrix
from dunjunz_revised.machines import MACHINES, launched

TAB, CURSOR_DOWN = FIRE_KEYS[0], FIRE_KEYS[1]      # the fire keys of key sets 1 and 2
KEY_2 = inkey_to_matrix(0xCE)                         # on the title: two keyboard players
GREEN, YELLOW, BLACK = 2, 3, 0
HERO_LINE_COLOUR, HERO_LINE_ENTRY, HERO_LINE_BYTES = 3, 18, 25   # in each hero's line on the menu


def to_the_menu(bbc, labels, title_key):
    """Boot, answer the title with title_key, and run to the menu's wait for keys."""
    bbc.boot_disc(REVISED_DISC_FILEPATH)
    bbc.run_for_emulated_seconds(8)
    hold_key(bbc, *title_key)
    bbc.debugger.run_to(labels["menu_key_loop"], timeout=120)
    bbc.run_for_emulated_seconds(0.5)           # the menu waits for a key


def entries(bbc, labels):
    """Each hero's entry on the menu: NO, KEYn or JOYn."""
    peek = bbc.memory.address.peek
    starts = [labels["menu_hero_lines"] + hero * HERO_LINE_BYTES + HERO_LINE_ENTRY for hero in range(4)]
    return [bytes(peek[start:start + 4]).decode() for start in starts]


@pytest.mark.parametrize("machine_key", ["dfs090", "dfs226", "dnfs120"])
def test_menu_answers_tapped_keys(disc_filepaths, machine_key):
    """A key set's fire key takes the first free hero, and each further press
    the next, past the Fighter to nobody, as a stick's fire does."""
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with launched(MACHINES[machine_key]) as bbc:
        def tap(key):
            hold_key(bbc, *key)
            bbc.run_for_emulated_seconds(0.5)

        def ranger_colour():
            return bbc.memory.address.peek[labels["menu_hero_lines"] + HERO_LINE_COLOUR]

        to_the_menu(bbc, labels, SPACE)             # any other key: four keyboard players
        assert entries(bbc, labels) == ["NO  "] * 4   # every hero starts off
        assert ranger_colour() == GREEN
        tap(TAB)
        assert entries(bbc, labels) == ["KEY1", "NO  ", "NO  ", "NO  "]
        assert ranger_colour() == YELLOW            # the line of a hero who plays
        tap(TAB)
        assert entries(bbc, labels) == ["NO  ", "KEY1", "NO  ", "NO  "]
        assert ranger_colour() == GREEN
        tap(CURSOR_DOWN)                            # set 2 takes the first free hero
        assert entries(bbc, labels) == ["KEY2", "KEY1", "NO  ", "NO  "]
        for _ in range(3):                          # set 1 on past the Fighter...
            tap(TAB)
        assert entries(bbc, labels) == ["KEY2", "NO  ", "NO  ", "NO  "]   # ...to nobody

        tap(RETURN)
        bbc.debugger.run_to(labels[UPDATE_GAME], timeout=120)
        assert bbc.cpu.pc == labels[UPDATE_GAME]


def test_only_the_chosen_number_of_key_sets_can_join(disc_filepaths):
    """With two keyboard players chosen on the title, a third set's fire key
    (SPACE, in the 1987 layout) joins nobody."""
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with launched(MACHINES["dfs226"]) as bbc:
        def tap(key):
            hold_key(bbc, *key)
            bbc.run_for_emulated_seconds(0.5)

        to_the_menu(bbc, labels, KEY_2)
        tap(SPACE)
        assert entries(bbc, labels) == ["NO  "] * 4
        tap(CURSOR_DOWN)
        assert entries(bbc, labels) == ["KEY2", "NO  ", "NO  ", "NO  "]


def test_return_to_play_is_hidden_while_nobody_plays(disc_filepaths):
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    colour_address = labels["menu_space_colour"]
    with launched(MACHINES["dfs226"]) as bbc:
        def tap(key):
            hold_key(bbc, *key)
            bbc.run_for_emulated_seconds(0.5)

        to_the_menu(bbc, labels, SPACE)
        assert bbc.memory.address.peek[colour_address] == BLACK    # every hero starts off
        tap(RETURN)                                 # does nothing
        assert bbc.cpu.pc != labels[UPDATE_GAME]

        tap(TAB)                                    # the Ranger plays
        assert bbc.memory.address.peek[colour_address] == YELLOW
        for _ in range(4):                          # on past the Fighter, to nobody
            tap(TAB)
        assert bbc.memory.address.peek[colour_address] == BLACK
