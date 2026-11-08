"""The game-over message looks as it did, but with the full stop after YOU ALL.

Both builds start level 1 and jump to the game-over path, as if every hero
had died; once the message is printed (at wait_vsync_game_over) their
screens must match, except for the character cell of the full stop, which
the 1987 release lost because the message's bytes doubled as counters.
This also exercises wrch_handler, which now defines character 128 with
VDU 23 instead of writing MOS 1.20's character definitions directly.
"""

from __future__ import annotations

from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    read_labels,
)
from dunjunz_revised.lockstep import SCREEN, game_run
from test_equivalence import ORIGINAL_GAME_RANGES, REVISED_GAME_RANGES

# The original's game-over path has no label: it is the VDU 28 sequence (30
# bytes) and the loop's set-up (4 bytes) before restore_message_spaces.
ORIGINAL_GAME_OVER_BEFORE_LABEL = 34
FULL_STOP_ROW, FULL_STOP_COLUMN = 10, 7     # text position of the full stop in "YOU ALL.", lines double-spaced
CHARACTER_ROW_BYTES, CHARACTER_BYTES = 640, 32  # a MODE 2 character is 4 bytes x 8 rows


def game_over_screen(disc_filepath, labels, game_ranges, game_over_address):
    with game_run(disc_filepath, labels, game_ranges) as run:
        run.bbc.cpu.pc = game_over_address
        run.bbc.debugger.run_to(labels["wait_vsync_game_over"], timeout=60)
        return run.peek(SCREEN[0], SCREEN[1] - SCREEN[0])


def test_game_over_message(disc_filepaths):
    original_labels = read_labels(ORIGINAL_BUILD_DIRPATH, "game")
    revised_labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    original = game_over_screen(ORIGINAL_DISC_FILEPATH, original_labels, ORIGINAL_GAME_RANGES,
                                original_labels["restore_message_spaces"] - ORIGINAL_GAME_OVER_BEFORE_LABEL)
    revised = game_over_screen(REVISED_DISC_FILEPATH, revised_labels, REVISED_GAME_RANGES,
                               revised_labels["game_over"])
    cell = FULL_STOP_ROW * CHARACTER_ROW_BYTES + FULL_STOP_COLUMN * CHARACTER_BYTES
    full_stop = range(cell, cell + CHARACTER_BYTES)
    differences = [i for i in range(len(original)) if original[i] != revised[i] and i not in full_stop]
    assert differences == [], f"{len(differences)} bytes differ, the first at &{SCREEN[0] + differences[0]:04X}"
    assert any(revised[i] for i in full_stop), "no full stop after YOU ALL"
    assert not any(original[i] for i in full_stop)
