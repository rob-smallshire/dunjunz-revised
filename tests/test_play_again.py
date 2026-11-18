"""Playing again from the end of a game (asm/ending/ending.asm).

After game over, R within ten seconds starts a new game at once, with the
same choices: no title, no hero menu, the same heroes on the same sticks or
sets of keys, and the same number of keyboard players. Any other key, or
none, loads the title as before.
"""

from __future__ import annotations

import time

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.key_layouts import LAYOUTS, SLOT_ORDER
from dunjunz_revised.lockstep import game_run, hold_key, inkey_to_matrix
from test_equivalence import REVISED_GAME_RANGES
from test_key_layouts import INKEY

R = inkey_to_matrix(0xCC)
HERO_ABSENT, KEYBOARD_PLAYERS, PLAY_AGAIN_FLAG, LEVELS_STARTED = 0x08B4, 0x08BF, 0x08B8, 0x08BC


def peek(bbc, address, length=1):
    return bytes(bbc.memory.address.peek[address:address + length])


def run_to_first_of(bbc, addresses, seconds=120):
    """Run until any of addresses is reached; return which."""
    breakpoints = [bbc.debugger.add_breakpoint(address) for address in addresses]
    try:
        bbc.debugger.run()
        deadline = time.monotonic() + seconds
        while bbc.debugger.is_running and time.monotonic() < deadline:
            time.sleep(0.01)
        return bbc.cpu.pc
    finally:
        for breakpoint in breakpoints:
            breakpoint.remove()


def to_game_over(run, labels):
    """As if every hero had died: on to the game-over message's prompt."""
    run.bbc.cpu.pc = labels["game_over"]
    run.bbc.debugger.run_to(labels["show_play_again_done"], timeout=60)
    run.bbc.run_for_emulated_seconds(0.5)           # the keys are flushed, and the wait begins


def test_r_after_game_over_plays_again_with_the_same_choices(disc_filepaths):
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with game_run(REVISED_DISC_FILEPATH, labels, REVISED_GAME_RANGES) as run:
        bbc = run.bbc
        choices = peek(bbc, HERO_ABSENT, 4), peek(bbc, labels["hero_stick"], 4), peek(bbc, KEYBOARD_PLAYERS)
        to_game_over(run, labels)
        hold_key(bbc, *R, seconds=0.3)
        reached = run_to_first_of(bbc, [labels["hero_menu"], labels["update_game"]])
        assert reached == labels["update_game"], "the hero menu ran"
        assert (peek(bbc, HERO_ABSENT, 4), peek(bbc, labels["hero_stick"], 4), peek(bbc, KEYBOARD_PLAYERS)) == choices
        assert peek(bbc, LEVELS_STARTED)[0] == 1                     # level 1, afresh
        assert peek(bbc, PLAY_AGAIN_FLAG)[0] == 0                    # once only
        players = choices[2][0]
        for hero, stick in enumerate(choices[1]):                    # each set's keys, in its hero's slots
            keys = LAYOUTS[players][stick & 3]
            assert [peek(bbc, labels[f"hero_key_{action}"] + hero)[0] for action in SLOT_ORDER[:5]] == \
                [INKEY[keys[action]] for action in SLOT_ORDER[:5]]


def test_no_key_after_game_over_goes_back_to_the_title(disc_filepaths):
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    title_labels = read_labels(REVISED_BUILD_DIRPATH, "title")
    with game_run(REVISED_DISC_FILEPATH, labels, REVISED_GAME_RANGES) as run:
        bbc = run.bbc
        to_game_over(run, labels)
        bbc.debugger.run_to(title_labels["twinkle_loop"], timeout=120)   # ten seconds on
        assert bbc.cpu.pc == title_labels["twinkle_loop"]
        assert peek(bbc, PLAY_AGAIN_FLAG)[0] == 0
