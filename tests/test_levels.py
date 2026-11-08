"""Moving on to the next level gives the same state as the original.

The original resets the machine and reloads the whole game for every level;
the revised game stays resident and must reset everything that matters
itself. Both builds play part of level 1 with the same keys, leave it as if
a hero had survived, and must match at the start of level 2 and while it is
played, up to the original's first key-for-key swap (see test_equivalence).
"""

from __future__ import annotations

from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    read_labels,
)
from dunjunz_revised.lockstep import Script, game_run
from test_equivalence import ORIGINAL_GAME_RANGES, REVISED_GAME_RANGES, compared, first_difference

LEVEL_1_FRAMES = 150
LEVEL_2_FRAMES = 200


def record(disc_filepath, labels, game_ranges, next_level_label, script):
    states = []
    with game_run(disc_filepath, labels, game_ranges) as run:
        for frame in range(LEVEL_1_FRAMES):
            run.next_frame(script.keys_for(frame))
        run.end_level(next_level_label)
        states.append(run.state())
        for frame in range(LEVEL_2_FRAMES):
            run.next_frame(script.keys_for(LEVEL_1_FRAMES + frame))
            states.append(run.state())
    return states


def test_second_level_matches_the_original(disc_filepaths):
    script = Script(seed=3, magic=0)
    original = record(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                      ORIGINAL_GAME_RANGES, "to_next_level", script)
    revised = record(REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"),
                     REVISED_GAME_RANGES, "next_level", script)
    assert first_difference(*compared(original, revised, 50)) is None
