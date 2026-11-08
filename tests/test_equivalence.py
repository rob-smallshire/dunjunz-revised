"""The revised game plays exactly as the original does.

Both builds are booted, started with every hero, and run frame by frame
with the same scripted keys and pinned randomness (see lockstep.py); the
game state and the screen must match at the start of every frame, with two
exceptions for fixes that change what is drawn:

- the comparison stops at the first fixed case the original meets
  (FIXED_CASES): a swap of one key for another, after which the revised game
  draws and swaps keys differently; a missile stopping at a skull; a Cross
  taken with nobody to bring back; a potion leaving 00 health;
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
MISSILES = 12
OBJECTS = 31

# Offsets in the "scratch+1" state block, the same in both builds.
HERO_X, HERO_Y, HERO_DIRECTION = 0x0F, 0x14, 0x19
MISSILE_X, MISSILE_Y, MISSILE_DIRECTION = 0x3F, 0x4B, 0x57
HERO_HEALTH_TENS, HERO_HEALTH_UNITS = 0x8F, 0x94
# Offsets in the "object_x" state block: x, y, then type.
OBJECT_X, OBJECT_Y, OBJECT_TYPE = 0, OBJECTS, 2 * OBJECTS
OFF_MAP = 0xFF
SPR_DIGIT_0, SPR_CROSS, SPR_POTION = 0x1E, 0x2A, 0x61


def states_to_key_swap(before, after):
    """The original swaps one key for another under a hero. The revised game
    differs from the next frame: it leaves the dropped key undrawn while the
    hero is on it, and never swaps it back (test_fixes.py)."""
    return any(held and now and held != now for held, now in zip(before["hero_key"], after["hero_key"]))


def a_missile_stops_at_a_skull(before, after):
    """A missile stops in the cell of a hero out of play, where the revised
    game lets it fly on: one in flight, or one fired into it this frame."""
    b, a = before["scratch+1"], after["scratch+1"]
    skulls = {(a[HERO_X + h], a[HERO_Y + h]) for h in range(HEROES) if a[HERO_DIRECTION + h] == 0}
    for slot in range(MISSILES):
        cell = a[MISSILE_X + slot], a[MISSILE_Y + slot]
        moved = b[MISSILE_DIRECTION + slot] or cell != (b[MISSILE_X + slot], b[MISSILE_Y + slot])
        if moved and not a[MISSILE_DIRECTION + slot] and cell in skulls:
            return True
    return False


def taken(before, after, object_type):
    b, a = before["object_x"], after["object_x"]
    return any(a[OBJECT_TYPE + n] == object_type and b[OBJECT_X + n] != OFF_MAP and a[OBJECT_X + n] == OFF_MAP
               for n in range(OBJECTS))


def a_cross_is_wasted(before, after):
    """A Cross is taken with nobody waiting; the revised game leaves it."""
    return taken(before, after, SPR_CROSS) and not any(1 <= entry <= HEROES for entry in before["returning_hero_queue"])


def a_potion_gives_00(before, after):
    """A potion is drunk and a hero is left on 00; the revised game gives 11."""
    a = after["scratch+1"]
    return taken(before, after, SPR_POTION) and any(
        a[HERO_HEALTH_TENS + h] == a[HERO_HEALTH_UNITS + h] == SPR_DIGIT_0 for h in range(HEROES))


# (test, states to keep after the frame in which the test is first true): the
# fixed cases the comparisons stop at, up to and including the state that still
# matches.
FIXED_CASES = (
    (states_to_key_swap, 1),
    (a_missile_stops_at_a_skull, 0),
    (a_cross_is_wasted, 0),
    (a_potion_gives_00, 0),
)


def states_before_a_fix(original):
    """How many of the original's states come before a fixed case makes the
    revised game differ, or None if it never meets one."""
    for frame in range(1, len(original)):
        before, after = original[frame - 1], original[frame]
        if "hero_key" not in after:
            break
        for test, keep in FIXED_CASES:
            if test(before, after):
                return frame + keep
    return None


def compared(original, revised, minimum_states):
    """Both recordings, up to the first fixed case the original meets,
    checking that enough is left to compare."""
    states = states_before_a_fix(original)
    if states is None:
        return original, revised
    assert states >= minimum_states, f"only {states} states before a fixed case"
    return original[:states], revised[:states]


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


# Seed 2, used before, has heroes die early: a missile is fired into a skull
# at frame 193, after which the revised game differs by design.
@pytest.mark.parametrize("seed", [1, 6])
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


DESCENT_FRAMES = 40


def record_descent(disc_filepath, labels, game_ranges):
    """The Ranger put on the exit at the first frame, then the state at the
    start of each frame while they go down it (20 frames) and after."""
    states = []
    with game_run(disc_filepath, labels, game_ranges) as run:
        run.poke(run.address("hero_x"), run.peek(run.address("exit_x"), 1))
        run.poke(run.address("hero_y"), run.peek(run.address("exit_y"), 1))
        states.append(run.state())
        for _ in range(DESCENT_FRAMES):
            run.next_frame(set())
            states.append(run.state())
    return states


def test_exit_descent_matches_the_original(disc_filepaths):
    original = record_descent(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                              ORIGINAL_GAME_RANGES)
    revised = record_descent(REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"),
                             REVISED_GAME_RANGES)
    assert first_difference(original, revised) is None
