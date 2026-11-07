"""The revised game plays exactly as the original does.

Both builds are booted, started with every hero, and run frame by frame
with the same scripted keys and pinned randomness (see lockstep.py); the
game state and the screen must match at the start of every frame.
"""

from __future__ import annotations

import hashlib

import pytest

from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    read_labels,
)
from dunjunz_revised.lockstep import Script, game_run

FRAMES = 400

# The memory the resident game occupies in play, searched for the timer reads.
ORIGINAL_GAME_RANGES = ((0x0400, 0x3000), (0x6E80, 0x8000))
REVISED_GAME_RANGES = ORIGINAL_GAME_RANGES


def record(disc_filepath, labels, game_ranges, script, frames):
    states = []
    with game_run(disc_filepath, labels, game_ranges) as run:
        states.append(run.state())
        for frame in range(frames):
            run.next_frame(script.keys_for(frame))
            states.append(run.state())
    return states


def first_difference(original, revised):
    for frame, (a, b) in enumerate(zip(original, revised)):
        for name in a:
            if a[name] != b[name]:
                offset = next(i for i, (x, y) in enumerate(zip(a[name], b[name])) if x != y)
                return (f"frame {frame}: {name}+&{offset:X} is &{b[name][offset]:02X}, "
                        f"originally &{a[name][offset]:02X}")
    return None


@pytest.mark.parametrize("seed", [1, 2])
def test_revised_plays_as_the_original(disc_filepaths, seed):
    script = Script(seed=seed)
    original = record(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                      ORIGINAL_GAME_RANGES, script, FRAMES)
    revised = record(REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"),
                     REVISED_GAME_RANGES, script, FRAMES)
    assert first_difference(original, revised) is None


def test_scripts_exercise_the_game(disc_filepaths):
    """The scripted play changes the heroes, the monsters and the screen, so
    that equivalence means something."""
    states = record(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                    ORIGINAL_GAME_RANGES, Script(seed=1), 100)
    for name in ("scratch", "monster_x", "screen"):
        digests = {hashlib.sha1(s[name]).digest() for s in states}
        assert len(digests) > 10, name
