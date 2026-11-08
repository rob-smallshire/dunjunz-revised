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

FRAMES = 1500

# Sprites the revised game no longer has: &76, the word LEVEL, which only the
# cassette game's level-number screen drew.
REMOVED_SPRITES = {0x76}

# The memory the resident game occupies in play, searched for the timer reads.
ORIGINAL_GAME_RANGES = ((0x0400, 0x3000), (0x6E80, 0x8000))
REVISED_GAME_RANGES = ORIGINAL_GAME_RANGES


def game_over_address(labels):
    """Where the game-over path starts: the revised game labels it; the original's
    is the VDU 28 sequence and a loop's set-up (34 bytes) before restore_message_spaces."""
    if "game_over" in labels:
        return labels["game_over"]
    return labels["restore_message_spaces"] - 34


def record(disc_filepath, labels, game_ranges, script, frames):
    """The state at the start of each frame, up to frames frames or game over."""
    states = []
    with game_run(disc_filepath, labels, game_ranges) as run:
        states.append(run.state())
        for frame in range(frames):
            if not run.next_frame(script.keys_for(frame), game_over_address(labels)):
                states.append({"game over": frame.to_bytes(2, "little")})
                break
            states.append(run.state())
    return states


# Where each hero's map x and y lie in the "scratch" state block (both builds).
HERO_X_OFFSET = 0x10
HERO_Y_OFFSET = 0x15
HEROES = 4


def swap_back_frame(original):
    """The first frame at which the original swaps a hero's key back while they
    stand on the cell of their last swap (the bug the revised game fixes), or None.
    The comparison must stop before it."""
    swap_cells = [None] * HEROES
    for frame in range(1, len(original)):
        before, after = original[frame - 1], original[frame]
        if "hero_key" not in after:
            break
        for hero in range(HEROES):
            cell = (after["scratch"][HERO_X_OFFSET + hero], after["scratch"][HERO_Y_OFFSET + hero])
            held, now = before["hero_key"][hero], after["hero_key"][hero]
            if now != held:
                if held and now and swap_cells[hero] == cell:
                    return frame
                # A swap, or a pickup with no key held, remembers the cell; a key
                # used on a door or dropped at death (now 0) is not a swap.
                swap_cells[hero] = cell if now else None
            elif swap_cells[hero] != cell:
                swap_cells[hero] = None
    return None


def compared(original, revised, minimum_states):
    """Both recordings cut short before the original's first key swap back,
    checking that enough is left to compare."""
    cut = swap_back_frame(original)
    if cut is None:
        return original, revised
    assert cut >= minimum_states, f"only {cut} states before the original swaps a key back"
    return original[:cut], revised[:cut]


def first_difference(original, revised):
    for frame, (a, b) in enumerate(zip(original, revised)):
        if a.keys() != b.keys():
            return f"frame {frame}: {'game over' if 'game over' in b else 'play'} revised, the other originally"
        for name in a:
            if a[name] != b[name]:
                offset = next(i for i, (x, y) in enumerate(zip(a[name], b[name])) if x != y)
                return (f"frame {frame}: {name}+&{offset:X} is &{b[name][offset]:02X}, "
                        f"originally &{a[name][offset]:02X}")
    if len(original) != len(revised):
        return f"{len(original)} states originally, {len(revised)} revised"
    return None


@pytest.mark.parametrize("seed", [1, 2])
def test_revised_plays_as_the_original(disc_filepaths, seed):
    script = Script(seed=seed, magic=0)
    original = record(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                      ORIGINAL_GAME_RANGES, script, FRAMES)
    revised = record(REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"),
                     REVISED_GAME_RANGES, script, FRAMES)
    assert first_difference(*compared(original, revised, 500)) is None


def test_scripts_exercise_the_game(disc_filepaths):
    """The scripted play changes the heroes, the monsters and the screen, so
    that equivalence means something."""
    states = record(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                    ORIGINAL_GAME_RANGES, Script(seed=1, magic=0), 100)
    for name in ("scratch", "monster_x+1", "screen"):
        digests = {hashlib.sha1(s[name]).digest() for s in states}
        assert len(digests) > 10, name


def sprites(run):
    """Each sprite's width, height and data, read through the sprite tables."""
    labels = run.labels
    lo = run.peek(labels["sprite_addr_lo"], 120)
    hi = run.peek(labels["sprite_addr_hi"], 120)
    widths = run.peek(labels["sprite_widths"], 120)
    heights = run.peek(labels["sprite_heights"], 120)
    return [
        (widths[n], heights[n], run.peek(hi[n] << 8 | lo[n], widths[n] * heights[n]))
        for n in range(120)
    ]


def test_sprites_match_the_original(disc_filepaths):
    """Every sprite, drawn or not in the scripted play, is unchanged."""
    with game_run(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                  ORIGINAL_GAME_RANGES) as run:
        original = sprites(run)
    with game_run(REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"),
                  REVISED_GAME_RANGES) as run:
        revised = sprites(run)
    for n, (a, b) in enumerate(zip(original, revised)):
        if n in REMOVED_SPRITES:
            continue
        assert a == b, f"sprite &{n:02X}"
