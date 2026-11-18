"""The end of the game, loaded only once play is over, still ends it as in 1987.

The revised game keeps its victory sequence and game-over message in the file
Setup, after the level set-up code, and loads them over the code for play
when the game ends (load_ending). The game-over screen is compared with the
1987 release's in test_game_over.py. Here the victory is: both builds start
level 1, are told it is level 25 with the Ranger at the Chalice, and with the
Ranger's view turned to the Chalice's room so that the sparkles and the
Chalice are drawn in it (compared as the Chalice starts to dissolve: which
bytes dissolve depends on the MOS's interrupts as well as the System VIA's
timer, so differs from run to run, in 1987 as now), and with level 25's ending text put where
level 25 keeps it, in its wall and object-free maps (the two builds keep
level 1's maps differently in bytes play never reads); each plays the
sequence and prints the ending text, and their screens must match
once they wait for a key. Loading the end must leave the screen on show as it
was, and put back the font, its WRCHV handler and the sprite tables as
assembled (the end carries copies; play code lies over the font). The bell's envelope must be
exactly 8: the 1987 release set it with a stale Y.
"""

from __future__ import annotations

from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    read_labels,
)
from dunjunz_revised.lockstep import ENDING_VIA_TIMER_READS, SCREEN, game_run
from test_equivalence import ORIGINAL_GAME_RANGES, REVISED_GAME_RANGES

LAST_LEVEL = 25
CHALICE_X, CHALICE_Y = 0x1A, 4
CHALICE_ROOM = 0x18             # (y AND &F8) x 4 + (x AND &F8): the room's offset in room_walls
JSR_OSRDCH = bytes([0x20, 0xE0, 0xFF])
BELL_ENVELOPE = 0x0264         # the MOS's bell envelope byte, set with OSBYTE &D4
VICTORY_BELL_ENVELOPE = 8
WORKSPACE = (0x0F00, 0x1700)    # the filing system's absolute workspace, borrowed by the game
VICTORY_SECONDS = 600
TEXT_OFFSET = 0x3A              # the ending text's place in each map
TEXT_BYTES = 0x8C               # in the wall map; the object-free map's ends with a zero
LEVEL_WALLS_OFFSET = 0xE0       # level_walls in a level file
LEVEL_OBJECT_FREE_MAP_OFFSET = 0x1B0


def reach_the_chalice(run):
    labels = run.labels
    run.poke(labels["level_number"], bytes([LAST_LEVEL]))
    run.poke(labels["hero_door_x"], bytes([CHALICE_X]))
    run.poke(labels["hero_door_y"], bytes([CHALICE_Y]))
    run.poke(labels["view_room"], bytes([CHALICE_ROOM]))
    if "render_all" in labels:      # the revised game draws only what changes: draw the view afresh
        run.poke(labels["render_all"], bytes([1]))
    level = (REVISED_BUILD_DIRPATH / f"Level{LAST_LEVEL}").read_bytes()
    walls_text = level[LEVEL_WALLS_OFFSET + TEXT_OFFSET:][:TEXT_BYTES]
    message_start = LEVEL_OBJECT_FREE_MAP_OFFSET + TEXT_OFFSET
    message = level[message_start:level.index(0, message_start) + 1]
    run.poke(labels["room_walls"] + TEXT_OFFSET, walls_text)
    run.poke(labels["object_free_map"] + TEXT_OFFSET, message)


def run_to(run, address, seconds):
    run.bbc.debugger.run_to(address, timeout=seconds)
    assert run.bbc.cpu.pc == address, f"&{address:04X} not reached; PC &{run.bbc.cpu.pc:04X}"


def key_wait(run, after_label):
    """The address of the victory's `jsr osrdch`, the first after after_label."""
    start = run.labels[after_label]
    return start + run.peek(start, 0x100).index(JSR_OSRDCH)


def screen(run):
    return run.peek(SCREEN[0], SCREEN[1] - SCREEN[0])


def original_victory_screens():
    labels = read_labels(ORIGINAL_BUILD_DIRPATH, "game")
    with game_run(ORIGINAL_DISC_FILEPATH, labels, ORIGINAL_GAME_RANGES) as run:
        reach_the_chalice(run)
        run_to(run, labels["dissolve_chalice"], VICTORY_SECONDS)
        ring = screen(run)
        assert run.peek(BELL_ENVELOPE, 1)[0] == VICTORY_BELL_ENVELOPE, "the bell's envelope was set with a stale Y"
        run_to(run, key_wait(run, "start_victory"), VICTORY_SECONDS)
        return ring, screen(run)


RING_CELLS = [(x, y) for x in range(CHALICE_X - 1, CHALICE_X + 3) for y in range(CHALICE_Y - 1, CHALICE_Y + 3)
              if not (CHALICE_X <= x <= CHALICE_X + 1 and CHALICE_Y <= y <= CHALICE_Y + 1)]


def ring_area(screen_bytes):
    """The bytes of the twelve cells of the ring round the Chalice's four, in the
    Ranger's view (turned to the Chalice's room, at corner byte 1, row 1). The
    four are not compared: level 1 has no Chalice there, and what shows in
    them is the view's old walls in 1987 and the floor in the revised game."""
    return bytes(screen_bytes[(line >> 3) * 640 + (line & 7) + column * 8]
                 for x, y in RING_CELLS
                 for line in range(1 + (y & 7) * 12, 13 + (y & 7) * 12)
                 for column in range(1 + (x & 7) * 4, 5 + (x & 7) * 4))


def assert_same(original, revised, when):
    differences = [i for i in range(len(original)) if original[i] != revised[i]]
    assert differences == [], \
        f"{when}: {len(differences)} bytes differ, the first at &{SCREEN[0] + differences[0]:04X}"


def test_the_victory_matches_the_original(disc_filepaths):
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with game_run(REVISED_DISC_FILEPATH, labels, REVISED_GAME_RANGES) as run:
        reach_the_chalice(run)
        run_to(run, labels["start_victory"], 10)
        before = screen(run)
        run_to(run, labels["ending_victory"], 60)
        assert screen(run) == before, "loading the end changed the screen"
        stored = (REVISED_BUILD_DIRPATH / "Setup").read_bytes()[
            labels["setup_end"] - labels["setup_start"] + labels["font_overlay_end"] - labels["font_overlay_start"]:]
        assert run.peek(labels["ending_start"], len(stored)) == stored
        for image, start, end in (("ending_font_image", "font_start", "font_end"),
                                  ("ending_tables_image", "sprite_addr_lo", "sprite_tables_end")):
            length = labels[end] - labels[start]
            assert run.peek(labels[start], length) == run.peek(labels[image], length), \
                f"loading the end did not put back {start} to {end} as assembled"
        assert run.pin_randomness(seed=False) == ENDING_VIA_TIMER_READS
        run_to(run, labels["dissolve_chalice"], VICTORY_SECONDS)
        ring = screen(run)
        assert run.peek(BELL_ENVELOPE, 1)[0] == VICTORY_BELL_ENVELOPE, "the bell's envelope was set with a stale Y"
        run_to(run, key_wait(run, "ending_victory"), VICTORY_SECONDS)
        text = screen(run)
    original_ring, original_text = original_victory_screens()
    assert_same(ring_area(original_ring), ring_area(ring), "with the ring round the Chalice")
    assert_same(original_text, text, "with the ending text")
