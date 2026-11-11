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
        green, yellow = 2, 3
        assert bbc.memory.address.peek[labels["menu_sound_on_colour"]] == green
        assert bbc.memory.address.peek[labels["menu_sound_off_colour"]] == yellow   # OFF(6) highlighted


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


ABOVE, RIGHT, BELOW, LEFT = (0, -1), (1, 0), (0, 1), (-1, 0)


def call(run, label, x):
    """Call a game routine with X set, from the start of a frame, back to it."""
    cpu = run.bbc.cpu
    back = run.labels[UPDATE_GAME] - 1          # rts returns to update_game
    run.poke(0x100 + cpu.sp - 1, bytes([back & 0xFF, back >> 8]))
    cpu.sp -= 2
    cpu.x = x
    cpu.pc = run.labels[label]
    run.bbc.debugger.run_to(run.labels[UPDATE_GAME], timeout=60)


def wall_address_and_bit(run, x, y):
    return run.labels["room_walls"] + (y & 0xF8) * 4 + (x & 0xF8) + (y & 7), 0x80 >> (x & 7)


def is_wall(run, x, y):
    address, bit = wall_address_and_bit(run, x, y)
    return bool(run.peek(address, 1)[0] & bit)


def make_wall(run, x, y):
    address, bit = wall_address_and_bit(run, x, y)
    run.poke(address, bytes([run.peek(address, 1)[0] | bit]))


def drop_key_at_exit(build, keys_beside=0, walls_all_round=False):
    """The Ranger, carrying key 19, drops it as if at the exit. keys_beside of
    the open cells around them (in the order tried) first get keys 20, 18,...
    Return the open cells in order and where key 19 lands."""
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        x, y = run.peek(run.address("hero_x"), 1)[0], run.peek(run.address("hero_y"), 1)[0]
        cells = [(x + dx, y + dy) for dx, dy in (ABOVE, RIGHT, BELOW, LEFT)]
        if walls_all_round:
            for cell in cells:
                make_wall(run, *cell)
        open_cells = [cell for cell in cells if not is_wall(run, *cell)]
        for key, cell in zip((20, 18, 17, 16), open_cells[:keys_beside]):
            run.poke(run.address(f"key_x+{key}"), bytes([cell[0]]))
            run.poke(run.address(f"key_y+{key}"), bytes([cell[1]]))
        run.poke(run.address("hero_key"), bytes([19]))
        call(run, "drop_key", 0)
        landed = run.peek(run.address("key_x+19"), 1)[0], run.peek(run.address("key_y+19"), 1)[0]
        return cells, open_cells, landed


def test_a_key_dropped_at_the_exit_avoids_other_keys(disc_filepaths):
    _, open_cells, landed = drop_key_at_exit(revised(), keys_beside=1)
    assert len(open_cells) >= 2
    assert landed == open_cells[1]
    _, open_cells, landed = drop_key_at_exit(original(), keys_beside=1)
    assert landed == open_cells[0]                  # on top of key 20


def test_a_key_with_nowhere_to_go_is_lost_not_put_in_a_wall(disc_filepaths):
    _, _, landed = drop_key_at_exit(revised(), walls_all_round=True)
    assert landed == (OFF_MAP, OFF_MAP)
    cells, _, landed = drop_key_at_exit(original(), walls_all_round=True)
    assert landed == cells[3]                       # in the wall to the left
    _, open_cells, landed = drop_key_at_exit(revised(), keys_beside=4)
    assert landed == (OFF_MAP, OFF_MAP)


def stack_pointers_after_an_exit(build, frames=6):
    """Put the Ranger on the exit and record the stack pointer at the start of
    each frame, before and after they go down it."""
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        run.poke(run.address("hero_x"), run.peek(run.address("exit_x"), 1))
        run.poke(run.address("hero_y"), run.peek(run.address("exit_y"), 1))
        pointers = [run.bbc.cpu.sp]
        for _ in range(frames):
            run.next_frame(set())
            pointers.append(run.bbc.cpu.sp)
        assert run.peek(run.address("exit_busy"), 1)[0]     # going down
        return pointers


def test_leaving_by_the_exit_leaves_nothing_on_the_stack(disc_filepaths):
    pointers = stack_pointers_after_an_exit(revised())
    assert len(set(pointers)) == 1
    pointers = stack_pointers_after_an_exit(original())
    assert pointers[-1] == pointers[0] - 2                  # a return address left behind


SPR_BLANK = 0x15
SPR_DIGIT_0 = 0x1E
SPR_CROSS = 0x2A
SPR_POTION = 0x61
STEP_OUT_OF_PLAY = 0x63
RANGER, FIGHTER = 0, 3
DIRECTIONS = {1: ABOVE, 2: RIGHT, 3: BELOW, 4: LEFT}


def byte(run, name):
    return run.peek(run.address(name), 1)[0]


def set_byte(run, name, value):
    run.poke(run.address(name), bytes([value]))


def take_out_of_play(run, hero):
    """Leave hero as a skull where they stand, as remove_absent_heroes does."""
    set_byte(run, f"hero_direction+{hero}", 0)
    set_byte(run, f"hero_step+{hero}", STEP_OUT_OF_PLAY)
    set_byte(run, f"hero_frame+{hero}", 8)


def missile_at_a_skull(build):
    """The Fighter lies as a skull where they start, and a missile in slot 0
    flies into their cell from an open cell beside it (the cell it starts in
    is not tested, so it may hold a hero). Return its direction
    after the frame (0 if it stopped), where it is, and the skull's cell."""
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        x, y = byte(run, f"hero_x+{FIGHTER}"), byte(run, f"hero_y+{FIGHTER}")
        direction, (dx, dy) = next((d, step) for d, step in DIRECTIONS.items()
                                   if not is_wall(run, x - step[0], y - step[1]))
        take_out_of_play(run, FIGHTER)
        set_byte(run, "missile_x", x - dx)
        set_byte(run, "missile_y", y - dy)
        set_byte(run, "missile_direction", direction)
        run.next_frame(set())
        return byte(run, "missile_direction"), (byte(run, "missile_x"), byte(run, "missile_y")), (x, y)


def test_a_missile_flies_through_a_skull(disc_filepaths):
    direction, at, skull = missile_at_a_skull(revised())
    assert direction and at == skull
    direction, at, skull = missile_at_a_skull(original())
    assert direction == 0


def ranger_on_a_cross(run, object_type=SPR_CROSS):
    """Put the Ranger on level 1's first Cross of Resurrection, made object_type."""
    types = run.peek(run.address("object_type"), 31)
    cross = types.index(SPR_CROSS)
    set_byte(run, f"object_type+{cross}", object_type)
    set_byte(run, "hero_x", byte(run, f"object_x+{cross}"))
    set_byte(run, "hero_y", byte(run, f"object_y+{cross}"))
    return cross


def score(run, hero):
    return [byte(run, f"hero_score_{digit}+{hero}") - SPR_DIGIT_0
            for digit in ("thousands", "hundreds", "tens", "units")]


def test_a_cross_with_nobody_to_bring_back_stays(disc_filepaths):
    disc_filepath, labels, ranges = revised()
    with game_run(disc_filepath, labels, ranges) as run:
        cross = ranger_on_a_cross(run)
        for _ in range(3):
            run.next_frame(set())
        assert byte(run, f"object_x+{cross}") != OFF_MAP
        assert score(run, RANGER) == [0, 0, 0, 0]
        take_out_of_play(run, FIGHTER)                      # the Fighter falls...
        set_byte(run, "returning_hero_queue", FIGHTER + 1)  # ...and waits for a Cross
        run.next_frame(set())
        assert byte(run, f"object_x+{cross}") == OFF_MAP
        assert score(run, RANGER) == [0, 0, 1, 0]
        assert byte(run, f"hero_offset_x+{FIGHTER}") == 0xFF    # coming back
    disc_filepath, labels, ranges = original()
    with game_run(disc_filepath, labels, ranges) as run:
        cross = ranger_on_a_cross(run)
        run.next_frame(set())
        assert byte(run, f"object_x+{cross}") == OFF_MAP     # wasted
        assert score(run, RANGER) == [0, 0, 1, 0]


def health_from_a_potion(build):
    """The Ranger, with a score of 0000, drinks a potion."""
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        ranger_on_a_cross(run, SPR_POTION)
        run.next_frame(set())
        return byte(run, "hero_health_tens") - SPR_DIGIT_0, byte(run, "hero_health_units") - SPR_DIGIT_0


def test_a_potion_never_leaves_00_health(disc_filepaths):
    assert health_from_a_potion(revised()) == (1, 1)
    assert health_from_a_potion(original()) == (0, 0)


def cast_with_health_too_low(build):
    """The Ranger, on 3 health, casts magic (cost 6) with a live monster in
    their room. Return the monster's sprite and the Ranger's score after."""
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        for _ in range(15):                                 # the monsters emerge
            run.next_frame(set())
        sprites = run.peek(run.address("monster_sprite+1"), 30)
        monster = 1 + next(n for n, sprite in enumerate(sprites) if sprite < SPR_BLANK)
        set_byte(run, f"monster_x+{monster}", byte(run, "hero_x"))
        set_byte(run, f"monster_y+{monster}", byte(run, "hero_y"))
        set_byte(run, "hero_health_tens", SPR_DIGIT_0)
        set_byte(run, "hero_health_units", SPR_DIGIT_0 + 3)
        before = score(run, RANGER)
        run.next_frame({CTRL})
        assert byte(run, "hero_direction") == 0             # the cost killed the Ranger
        return byte(run, f"monster_sprite+{monster}"), before, score(run, RANGER)


def test_a_caster_killed_by_the_cost_casts_nothing(disc_filepaths):
    sprite, before, after = cast_with_health_too_low(revised())
    assert sprite < SPR_BLANK and after == before
    sprite, before, after = cast_with_health_too_low(original())
    assert sprite >= SPR_BLANK and after != before         # dying


def score_on_the_next_level(build, next_level_label):
    """The Ranger scores 0005 on level 1 and survives it."""
    disc_filepath, labels, ranges = build
    with game_run(disc_filepath, labels, ranges) as run:
        set_byte(run, "hero_score_units", SPR_DIGIT_0 + 5)
        run.end_level(next_level_label)
        return score(run, RANGER)


def test_a_survivor_keeps_their_score_at_the_next_level(disc_filepaths):
    assert score_on_the_next_level(revised(), "next_level") == [0, 0, 0, 5]
    assert score_on_the_next_level(original(), "to_next_level") == [0, 0, 0, 6]
