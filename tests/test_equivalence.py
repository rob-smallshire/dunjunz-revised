"""The revised game plays exactly as the original does.

Both builds are booted, started with every hero, and run frame by frame
with the same scripted keys and pinned randomness (see lockstep.py); the
game state and the screen must match at the start of every frame, with two
exceptions for fixes that change what is drawn:

- the comparison stops at the first fixed case the original meets
  (FIXED_CASES): a swap of one key for another, after which the revised game
  draws and swaps keys differently; a missile stopping at a skull; a Cross
  taken with nobody to bring back; a potion leaving 00 health; a dead
  hero's key dropped under the skull, where the revised game puts it beside;
- the trapdoors' cells are left out of the screen comparison, because the
  revised game redraws trapdoors at the start of a frame, not part way
  through, so a trapdoor something has just left is still blank at the
  frame's start; and so are the cells of heroes out of play, whose
  sparkles and skull the revised game draws every frame, under the heroes
  in play, each sprite a frame sooner, and of keys and objects on or beside
  a hero, which are drawn under the heroes at the start of a frame.
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
from dunjunz_revised.sprite_sizes import sprite_sizes
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
HERO_OFFSET_X, HERO_OFFSET_Y = 0x29, 0x2F
MISSILE_X, MISSILE_Y, MISSILE_DIRECTION = 0x3F, 0x4B, 0x57
# Offsets in the "object_x" state block: x, y, then type.
OBJECT_X, OBJECT_Y, OBJECT_TYPE = 0, OBJECTS, 2 * OBJECTS
OFF_MAP = 0xFF


def states_to_key_swap(before, after):
    """The original swaps one key for another under a hero. The revised game
    differs from the next frame: it leaves the dropped key undrawn while the
    hero is on it, and never swaps it back (test_fixes.py)."""
    return any(held and now and held != now for held, now in zip(before["hero_key"], after["hero_key"]))


# (test, states to keep after the frame in which the test is first true): the
# fixed cases the comparisons stop at, up to and including the state that still
# matches.
FIXED_CASES = (
    (states_to_key_swap, 1),
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


def cell_screen_offsets(state, cells):
    """The screen offsets (from SCREEN_START) of the given map cells, where on show."""
    offsets = set()
    view_rooms = [state["scratch+1"][VIEW_ROOM_OFFSET + 2 * view] for view in range(4)]
    for x, y in cells:
        room = (y & 0xF8) * 4 + (x & 0xF8)
        for view_room, (column, row) in zip(view_rooms, VIEW_CORNERS):
            if view_room != room:
                continue
            plot_x, plot_y = column + (x & 7) * CELL_BYTES, row + (y & 7) * CELL_ROWS
            for line in range(plot_y, plot_y + CELL_ROWS):
                for byte in range(plot_x, plot_x + CELL_BYTES):
                    offsets.add((line >> 3) * 640 + (line & 7) + byte * 8)
    return offsets


def masked_cells(state):
    """The cells whose drawing the revised game changes on purpose: the
    trapdoors, redrawn at the start of a frame, not part way through; the
    heroes out of play, whose sparkles and skull are drawn every frame, under
    the heroes in play, each sprite a frame sooner; and keys and objects on or
    beside a hero, now drawn under the heroes at the start of a frame, so a
    hero on one covers it, and one a hero has just left is still blank."""
    if "trapdoor_x" not in state:
        return []
    s = state["scratch+1"]
    absent = [(s[HERO_X + h], s[HERO_Y + h]) for h in range(HEROES) if s[HERO_DIRECTION + h] == 0]
    heroes = [(s[HERO_X + h], s[HERO_Y + h]) for h in range(HEROES)]
    objects = state["object_x"]
    things = list(zip(state["key_x+1"], state["key_y+1"])) + list(
        zip(objects[OBJECT_X:OBJECT_X + OBJECTS], objects[OBJECT_Y:OBJECT_Y + OBJECTS]))
    near = [(x, y) for x, y in things
            if any(abs(x - hx) <= 1 and abs(y - hy) <= 1 for hx, hy in heroes)]
    return list(zip(state["trapdoor_x"], state["trapdoor_y"])) + absent + near


def footprint(x, y, offset_x, offset_y):
    """The cells a sprite at cell (x, y) covers: the cell, and the next one along
    while it steps (a non-zero offset, negative from &80)."""
    cells = {(x, y)}
    if offset_x:
        cells.add((x + (-1 if offset_x >= 0x80 else 1), y))
    if offset_y:
        cells.add((x, y + (-1 if offset_y >= 0x80 else 1)))
    return cells


def things_on_show(state):
    """Each thing on the board, by name, with the cells it covers: floor items
    (trapdoors, objects, keys, heroes out of play) and creatures' images
    (heroes in play, missiles, monsters, with the cell a step reaches into)."""
    s = state["scratch+1"]
    things = {("trapdoor", n): {cell} for n, cell in enumerate(zip(state["trapdoor_x"], state["trapdoor_y"]))}
    objects = state["object_x"]
    things.update({("object", n): {(x, y)} for n, (x, y) in enumerate(
        zip(objects[OBJECT_X:OBJECT_X + OBJECTS], objects[OBJECT_Y:OBJECT_Y + OBJECTS])) if x != OFF_MAP})
    things.update({("key", n): {(x, y)} for n, (x, y) in enumerate(zip(state["key_x+1"], state["key_y+1"]))
                   if x != OFF_MAP})
    for h in range(HEROES):
        x, y = s[HERO_X + h], s[HERO_Y + h]
        if s[HERO_DIRECTION + h]:
            things[("hero", h)] = footprint(x, y, s[HERO_OFFSET_X + h], s[HERO_OFFSET_Y + h])
        elif x != OFF_MAP:
            things[("hero", h)] = {(x, y)}
    things.update({("missile", m): {(s[MISSILE_X + m], s[MISSILE_Y + m])} for m in range(MISSILES)
                   if s[MISSILE_DIRECTION + m]})
    things.update({("monster", n): footprint(x, y, ox, oy) for n, (x, y, ox, oy) in enumerate(zip(
        state["monster_x+1"], state["monster_y+1"], state["monster_offset_x+1"], state["monster_offset_y+1"]))
        if x != OFF_MAP})
    return things


def crowded_cells(state, previous=None):
    """The cells where two or more things meet, taking each thing's cells now
    and in the frame before together (so one leaving a cell as another arrives
    counts). The revised game draws such a cell as one picture, each thing
    see-through over those behind; 1987 drew them in turn, solid, the last
    drawn hiding the rest, or rubbed one out over another. A cell where one
    thing is, or was, must look as it did."""
    if "trapdoor_x" not in state:
        return []
    things = things_on_show(state)
    if previous is not None and "trapdoor_x" in previous:
        for name, cells in things_on_show(previous).items():
            things[name] = things.get(name, set()) | cells
    seen, crowded = set(), set()
    for cells in things.values():
        crowded |= seen & cells
        seen |= cells
    return list(crowded)


def view_rooms(state):
    return [state["scratch+1"][VIEW_ROOM_OFFSET + 2 * view] for view in range(4)]


def heroes_on_show(state):
    s = state["scratch+1"]
    return [cell for h in range(HEROES) if s[HERO_DIRECTION + h]
            for cell in footprint(s[HERO_X + h], s[HERO_Y + h], s[HERO_OFFSET_X + h], s[HERO_OFFSET_Y + h])]


def masked_screen(state, offsets):
    screen = bytearray(state["screen"])
    for offset in offsets:
        screen[offset] = 0
    return {**state, "screen": bytes(screen)}


# Bytes of the "scratch+1" state block left differently by the revised game's
# drawing: cell_x, cell_y and cell_room (0-3), scratch values that plotting
# leaves behind (render draws after play, not as it goes); and
# previous_offset_x and previous_offset_y (7, 8), which it no longer keeps.
UNKEPT_STATE = tuple(("scratch+1", offset) for offset in (0, 1, 2, 3, 7, 8))


def without_unkept_state(state):
    blocks = {name: bytearray(state[name]) for name, _ in UNKEPT_STATE if name in state}
    for name, offset in UNKEPT_STATE:
        if name in blocks:
            blocks[name][offset] = 0
    return {**state, **{name: bytes(block) for name, block in blocks.items()}}


def first_difference(original, revised):
    previous = None
    for frame, (a, b) in enumerate(zip(original, revised)):
        if a.keys() != b.keys():
            return f"frame {frame}: {'game over' if 'game over' in b else 'play'} revised, the other originally"
        a, b = without_unkept_state(a), without_unkept_state(b)
        if "screen" in a:
            # Crowded cells now and in the frame before (a thing just gone, a key
            # picked up from under a hero, say), and the heroes' cells when a view
            # changes room (1987 drew a hero moved before the change a frame late).
            cells = masked_cells(a) + crowded_cells(a, previous)
            if previous and "scratch+1" in previous:
                if view_rooms(previous) != view_rooms(a):
                    cells += heroes_on_show(a)
            previous = a
            offsets = cell_screen_offsets(a, cells)
            a, b = masked_screen(a, offsets), masked_screen(b, offsets)
        for name in a:
            if a[name] != b[name]:
                offset = next(i for i, (x, y) in enumerate(zip(a[name], b[name])) if x != y)
                return (f"frame {frame}: {name}+&{offset:X} is &{b[name][offset]:02X}, "
                        f"originally &{a[name][offset]:02X}")
    if len(original) != len(revised):
        return f"{len(original)} states originally, {len(revised)} revised"
    return None


@pytest.mark.parametrize("seed", [1, 2, 6])
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
    sizes = sprite_sizes(run.peek, labels)
    return [(w, h, run.peek(hi[n] << 8 | lo[n], w * h)) for n, (w, h) in enumerate(sizes)]


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
