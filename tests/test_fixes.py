"""The fixed bugs behave as fixed, and (where it is cheap to show) as the
original did not. See docs/bugs.md.
"""

from __future__ import annotations

from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    read_labels,
)
from dunjunz_revised.lockstep import SPACE, UPDATE_GAME, game_run, hold_key
from dunjunz_revised.machines import MACHINES, launched
from test_equivalence import ORIGINAL_GAME_RANGES, REVISED_GAME_RANGES

CTRL = 0xFE            # the Ranger's magic key
CURSOR_DOWN = 0xD6     # the Magic-User's fire key, internal key &29, below P's &37
P = 0xC8


def original():
    return ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"), ORIGINAL_GAME_RANGES


def revised():
    return REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"), REVISED_GAME_RANGES


def hits_in_frame(run, address, keys, stops=()):
    """Hold keys for one frame and count how often address is reached in it.
    Also report which of stops were reached."""
    run.set_keys(keys)
    debugger = run.bbc.debugger
    update_game = run.labels[UPDATE_GAME]
    count, reached = 0, set()
    breakpoints = [debugger.add_breakpoint(a) for a in {address, update_game, *stops}]
    try:
        first = True
        while True:
            debugger.run_and_wait_for_stop(timeout=60)
            pc = run.bbc.cpu.pc
            if pc == address:
                count += 1
            if pc in stops:
                reached.add(pc)
            if pc == update_game and not first:
                return count, reached
            first = False
    finally:
        for bp in breakpoints:
            bp.remove()


def heroes_moved_after_a_cast(build):
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        run.next_frame(set())
        run.next_frame({CTRL})                  # the Ranger casts
        return [hits_in_frame(run, labels["move_hero"], set())[0] for _ in range(4)]


def test_magic_does_not_stop_the_other_heroes(disc_filepaths):
    assert heroes_moved_after_a_cast(revised()) == [4, 4, 4, 4]
    assert heroes_moved_after_a_cast(original())[:3] == [1, 1, 1]


def pauses(build, keys):
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        run.next_frame(set())
        pause = run.bbc.debugger.add_breakpoint(labels["wait_pause_release"])
        try:
            run.set_keys(keys)
            # Stop at the pause, or else at the next frame's start.
            run.bbc.debugger.run_to(labels[UPDATE_GAME], skip_current=True, timeout=60)
            return run.bbc.cpu.pc == labels["wait_pause_release"]
        finally:
            pause.remove()


def test_pause_is_seen_while_a_lower_numbered_key_is_held(disc_filepaths):
    assert pauses(revised(), {P, CURSOR_DOWN})
    assert not pauses(original(), {P, CURSOR_DOWN})


def test_p_held_after_unpausing_does_not_pause_again(disc_filepaths):
    disc_filepath, labels, ranges = revised()
    with game_run(disc_filepath, labels, ranges) as run:
        run.next_frame(set())
        debugger = run.bbc.debugger
        run.set_keys({P})                       # pause...
        debugger.run_to(labels["wait_pause_release"], timeout=60)
        run.set_keys(set())                     # ...release...
        debugger.run_to(labels["wait_pause_press"], timeout=60)
        run.set_keys({P})                       # ...and press again, holding it
        debugger.run_to(labels["wait_resume_release"], timeout=60)
        run.bbc.run_for_emulated_seconds(0.5)   # held for half a second
        run.set_keys(set())                     # then released: play resumes, unpaused
        count, _ = hits_in_frame(run, labels["wait_pause_release"], set())
        assert count == 0


def test_game_over_wait_is_short(disc_filepaths):
    disc_filepath, labels, ranges = revised()
    with game_run(disc_filepath, labels, ranges) as run:
        run.bbc.cpu.pc = labels["game_over"]
        measurement = run.bbc.debugger.measure(labels["wait_vsync_game_over"], labels["vsync_game_over_done"], timeout=60)
        assert measurement.cycles < 3 * 40_000      # under three vsyncs at 2 MHz


def test_menu_shows_the_sound_off(disc_filepaths):
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with launched(MACHINES["dfs226"]) as bbc:
        bbc.run_for_emulated_seconds(3)
        bbc.disc.drive0.insert(REVISED_DISC_FILEPATH, write_protect=True)
        for command in ("*FX210,1", "*RUN DUNJUNZ"):
            bbc.keyboard.type(command + "\r")
            bbc.run_for_emulated_seconds(2)
        bp = bbc.debugger.add_breakpoint(labels["menu_sound_shown"])
        for _ in range(60):
            bbc.run_for_emulated_seconds(0.5)
            if bbc.cpu.pc == labels["menu_sound_shown"]:
                break
            bbc.debugger.run()
            hold_key(bbc, *SPACE)
        bp.remove()
        assert bbc.cpu.pc == labels["menu_sound_shown"]
        entry = bytes(bbc.memory.address.peek[labels["menu_text"] + 0x98:labels["menu_text"] + 0x9B])
        assert entry == b"OFF"
