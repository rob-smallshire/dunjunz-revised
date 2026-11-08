"""Moving on to the next level gives the same state as the original.

The original resets the machine and reloads the whole game for every level;
the revised game stays resident and must reset everything that matters
itself. Both builds play part of level 1 with the same keys, leave it as if
a hero had survived, and must match at the start of level 2 and while it is
played, up to the first fixed case the original meets (see test_equivalence).

The original gives every survivor a point at each new level, which the
revised game does not (test_fixes.py); the revised run is given that point
just before it leaves level 1, so the scores match.
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


SPR_DIGIT_9 = 0x27
HEROES = 4


def give_the_1987_level_point(run):
    """Add a point to every hero's score, as the original's draw_status_panel
    does at each level (a hero reset for dying loses it again)."""
    for hero in range(HEROES):
        units = run.peek(run.address(f"hero_score_units+{hero}"), 1)[0]
        assert units != SPR_DIGIT_9, "the point would carry"
        run.poke(run.address(f"hero_score_units+{hero}"), bytes([units + 1]))


def record(disc_filepath, labels, game_ranges, next_level_label, script, level_point=False):
    states = []
    with game_run(disc_filepath, labels, game_ranges) as run:
        for frame in range(LEVEL_1_FRAMES):
            run.next_frame(script.keys_for(frame))
        if level_point:
            give_the_1987_level_point(run)
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
                     REVISED_GAME_RANGES, "next_level", script, level_point=True)
    assert first_difference(*compared(original, revised, 50)) is None
