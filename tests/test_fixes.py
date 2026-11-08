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
OFF_MAP = 0xFF        # a key x or y off the map
SPR_KEY = 0x1B
RANGER_STANDING = 0x02  # the Ranger's sprite while standing at the start of level 1
PLOT_X = 0x70           # plot_x, then plot_y
SPRITE_NUMBER = 0x7A


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


def ranger_on_a_key(run):
    """Give the Ranger key 19 and put key 20 under them, the only key on their
    cell (level 1 has key 4 under the Ranger's start). Return their cell."""
    x = run.peek(run.address("hero_x"), 1)
    y = run.peek(run.address("hero_y"), 1)
    for key in range(1, 20):
        if (run.peek(run.address(f"key_x+{key}"), 1), run.peek(run.address(f"key_y+{key}"), 1)) == (x, y):
            run.poke(run.address(f"key_x+{key}"), bytes([OFF_MAP]))
            run.poke(run.address(f"key_y+{key}"), bytes([OFF_MAP]))
    run.poke(run.address("hero_key"), bytes([19]))
    run.poke(run.address("key_x+19"), bytes([OFF_MAP]))
    run.poke(run.address("key_y+19"), bytes([OFF_MAP]))
    run.poke(run.address("key_x+20"), x)
    run.poke(run.address("key_y+20"), y)
    return x, y


def keys_carried_on_a_key(build, frames=12):
    """Put the Ranger, carrying a key, on another; stand still, and list the
    key they carry at each frame. Also say whether key 19 ends up on their cell."""
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        x, y = ranger_on_a_key(run)
        carried = []
        for _ in range(frames):
            run.next_frame(set())
            carried.append(run.peek(run.address("hero_key"), 1)[0])
        key_19_here = (run.peek(run.address("key_x+19"), 1), run.peek(run.address("key_y+19"), 1)) == (x, y)
        return carried, key_19_here


def test_standing_on_a_key_swaps_once(disc_filepaths):
    carried, key_19_here = keys_carried_on_a_key(revised())
    assert carried == [20] * len(carried)
    assert key_19_here
    carried, _ = keys_carried_on_a_key(original())
    assert carried.count(19) > 1 and carried.count(20) > 1    # back and forth


def test_a_dropped_key_is_not_drawn_over_the_hero(disc_filepaths):
    """After the swap, the key left under the Ranger is not plotted where the
    Ranger is drawn, so the hero does not flicker with it."""
    disc_filepath, labels, ranges = revised()
    with game_run(disc_filepath, labels, ranges) as run:
        ranger_on_a_key(run)
        for _ in range(3):
            run.next_frame(set())
        debugger = run.bbc.debugger
        breakpoints = [debugger.add_breakpoint(labels["plot_sprite"]), debugger.add_breakpoint(labels[UPDATE_GAME])]
        plots, frames = [], 0
        try:
            while frames < 4:
                debugger.run_and_wait_for_stop(timeout=60)
                if run.bbc.cpu.pc == labels[UPDATE_GAME]:
                    frames += 1
                else:
                    sprite, x, y = run.peek(SPRITE_NUMBER, 1)[0], *run.peek(PLOT_X, 2)
                    plots.append((sprite, x, y))
        finally:
            for bp in breakpoints:
                bp.remove()
        ranger = {(x, y) for sprite, x, y in plots if sprite == RANGER_STANDING}
        assert ranger
        assert not [p for p in plots if p[0] == SPR_KEY and p[1:] in ranger]


def plots_per_frame(run, frames):
    """Each frame's sprite plots, as (sprite, plot_x, plot_y) in order."""
    labels = run.labels
    debugger = run.bbc.debugger
    breakpoints = [debugger.add_breakpoint(labels["plot_sprite"]), debugger.add_breakpoint(labels[UPDATE_GAME])]
    result = [[]]                       # from the current frame's start
    try:
        while True:
            debugger.run_and_wait_for_stop(timeout=60)
            if run.bbc.cpu.pc == labels[UPDATE_GAME]:
                if len(result) == frames:
                    return result
                result.append([])
            else:
                result[-1].append((run.peek(SPRITE_NUMBER, 1)[0], *run.peek(PLOT_X, 2)))
    finally:
        for bp in breakpoints:
            bp.remove()


def put_trapdoors_under_the_ranger(run):
    x = run.peek(run.address("hero_x"), 1)
    y = run.peek(run.address("hero_y"), 1)
    saved = run.peek(run.address("trapdoor_x"), 8), run.peek(run.address("trapdoor_y"), 8)
    run.poke(run.address("trapdoor_x"), x * 8)
    run.poke(run.address("trapdoor_y"), y * 8)
    return saved


def test_a_hero_on_a_trapdoor_is_drawn_over_it(disc_filepaths):
    disc_filepath, labels, ranges = revised()
    with game_run(disc_filepath, labels, ranges) as run:
        put_trapdoors_under_the_ranger(run)
        for _ in range(3):
            run.next_frame(set())
        for frame in plots_per_frame(run, 4):
            ranger = {(x, y) for sprite, x, y in frame if sprite == RANGER_STANDING}
            assert ranger
            last = {}
            for sprite, x, y in frame:
                last[(x, y)] = sprite
            assert all(last[place] == RANGER_STANDING for place in ranger)


def test_a_trapdoor_a_hero_stands_on_stays_shut(disc_filepaths):
    """With every trapdoor under the Ranger, none of the 30 monsters waiting to
    emerge at the start does, and the Ranger is not hurt; once the trapdoors
    are back, they emerge."""
    disc_filepath, labels, ranges = revised()
    with game_run(disc_filepath, labels, ranges) as run:
        health = run.peek(run.address("hero_health_tens"), 1), run.peek(run.address("hero_health_units"), 1)
        saved_x, saved_y = put_trapdoors_under_the_ranger(run)
        for _ in range(10):
            run.next_frame(set())
        assert set(run.peek(run.address("monster_x+1"), 30)) == {OFF_MAP}
        assert (run.peek(run.address("hero_health_tens"), 1), run.peek(run.address("hero_health_units"), 1)) == health
        run.poke(run.address("trapdoor_x"), saved_x)
        run.poke(run.address("trapdoor_y"), saved_y)
        for _ in range(10):
            run.next_frame(set())
        emerged = run.peek(run.address("monster_x+1"), 30)
        assert OFF_MAP not in emerged
