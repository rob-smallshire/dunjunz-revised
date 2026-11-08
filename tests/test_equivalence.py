"""The revised game plays exactly as the original does.

Both builds are booted, started with every hero, and run frame by frame
with the same scripted keys and pinned randomness (see lockstep.py); the
game state and the screen must match at the start of every frame, with two
exceptions for fixes that change what is drawn:

- the comparison stops after the original's first swap of one key for
  another, after which the revised game draws and swaps keys differently;
- the trapdoors' cells are left out of the screen comparison, because the
  revised game redraws trapdoors at the start of a frame, not part way
  through, so a trapdoor something has just left is still blank at the
  frame's start.
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


HEROES = 4


def key_swap_frame(original):
    """The first state in which the original has swapped one key for another
    under a hero, or None. From the next frame the revised game differs: it
    leaves the dropped key undrawn while the hero is on it, and never swaps it
    back (the key swap fix; see test_fixes.py)."""
    for frame in range(1, len(original)):
        before, after = original[frame - 1], original[frame]
        if "hero_key" not in after:
            break
        for hero in range(HEROES):
            held, now = before["hero_key"][hero], after["hero_key"][hero]
            if held and now and held != now:
                return frame
    return None


def compared(original, revised, minimum_states):
    """Both recordings, up to and including the original's first key-for-key
    swap, checking that enough is left to compare."""
    swap = key_swap_frame(original)
    if swap is None:
        return original, revised
    assert swap + 1 >= minimum_states, f"only {swap + 1} states before the original's first key swap"
    return original[:swap + 1], revised[:swap + 1]


# Where the views' rooms lie in the "scratch+1" state block, and the views'
# corners on the screen (plot_at_cell).
VIEW_ROOM_OFFSET = 0xA0 - 1
VIEW_CORNERS = ((1, 1), (0x23, 1), (1, 0x67), (0x23, 0x67))
SCREEN_START = 0x3000
CELL_BYTES, CELL_ROWS = 4, 12


def trapdoor_screen_offsets(state):
    """The screen offsets (from SCREEN_START) of every trapdoor cell on show."""
    offsets = set()
    if "trapdoor_x" not in state:
        return offsets
    view_rooms = [state["scratch+1"][VIEW_ROOM_OFFSET + 2 * view] for view in range(4)]
    for x, y in zip(state["trapdoor_x"], state["trapdoor_y"]):
        room = (y & 0xF8) * 4 + (x & 0xF8)
        for view_room, (column, row) in zip(view_rooms, VIEW_CORNERS):
            if view_room != room:
                continue
            plot_x, plot_y = column + (x & 7) * CELL_BYTES, row + (y & 7) * CELL_ROWS
            for line in range(plot_y, plot_y + CELL_ROWS):
                for byte in range(plot_x, plot_x + CELL_BYTES):
                    offsets.add((line >> 3) * 640 + (line & 7) + byte * 8)
    return offsets


def masked_screen(state, offsets):
    screen = bytearray(state["screen"])
    for offset in offsets:
        screen[offset] = 0
    return {**state, "screen": bytes(screen)}


def first_difference(original, revised):
    for frame, (a, b) in enumerate(zip(original, revised)):
        if a.keys() != b.keys():
            return f"frame {frame}: {'game over' if 'game over' in b else 'play'} revised, the other originally"
        if "screen" in a:
            offsets = trapdoor_screen_offsets(a)
            a, b = masked_screen(a, offsets), masked_screen(b, offsets)
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
    for name in ("scratch+1", "monster_x+1", "screen"):
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
