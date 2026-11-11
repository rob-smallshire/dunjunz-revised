"""Joysticks: SPItFIRE's four, or two on the analogue port.

Beebium emulates neither SPItFIRE nor the ADC, so these tests run the game
with a fake SPItFIRE in sideways RAM (tests/fake_spitfire.py). The players
join on the hero menu by pressing fire, then play: the stick's directions
and fire act as the hero's keys, and fire held with a direction for
magic_hold_frames casts magic. Without SPItFIRE, two sticks on the analogue
port do the same.
"""

from __future__ import annotations

import pytest

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.lockstep import SPACE, UPDATE_GAME, hold_key
from dunjunz_revised.machines import MACHINES, launched
from fake_spitfire import DOWN, FIRE, RIGHT, Fake, machine_with_fake, twin_twins

RTS = 0x60
NO_STICK = 0xFF
DIRECTION_RIGHT = 3
FRAME_SECONDS = 3 / 50                      # a frame every three vsyncs
SWITCH_MAGIC = 0x02
MAGIC_HOLD_FRAMES = 8


@pytest.fixture(scope="module")
def labels(disc_filepaths):
    return read_labels(REVISED_BUILD_DIRPATH, "dunjunz")


def to_menu(bbc, labels, before_menu=None):
    """Boot to the title, call before_menu (to set up the fake's OSBYTE hook,
    after the BREAK that reset BYTEV), and go on to the hero menu."""
    bbc.boot_disc(REVISED_DISC_FILEPATH)
    bbc.run_for_emulated_seconds(8)
    if before_menu is not None:
        before_menu()
    hold_key(bbc, *SPACE)
    bbc.debugger.run_to(labels["menu_key_loop"], timeout=120)
    bbc.run_for_emulated_seconds(0.5)


def entries(bbc, labels) -> list[bytes]:
    """Each hero's entry on the menu: KEYS, NO or JOYn."""
    start = labels["menu_hero_entries"]
    return [bytes(bbc.memory.address.peek[start + 7 * hero:start + 7 * hero + 4]) for hero in range(4)]


def spitfire_line(bbc, labels) -> bytes:
    line = labels["menu_spitfire_line"]
    return bytes(bbc.memory.address.peek[line:line + 19])


def press_fire(fake: Fake, stick: int, sticks: int = 4) -> None:
    """Press and release fire on one stick, as SPItFIRE's switch bytes."""
    switches = [0] * sticks
    switches[stick] = FIRE
    fake.set_switches(switches)
    fake.bbc.run_for_emulated_seconds(0.2)
    fake.set_switches([0] * sticks)
    fake.bbc.run_for_emulated_seconds(0.2)


def start_play(bbc, labels) -> None:
    hold_key(bbc, *SPACE)
    bbc.debugger.run_to(labels[UPDATE_GAME], timeout=120)


def peek(bbc, labels, label: str, length: int = 4) -> bytes:
    return bytes(bbc.memory.address.peek[labels[label]:labels[label] + length])


def spitfire_menu(fake: Fake, labels) -> None:
    fake.as_spitfire(*twin_twins())
    to_menu(fake.bbc, labels, before_menu=fake.hook_osbyte)


def test_spitfire_sticks_join_with_fire(labels):
    with machine_with_fake() as fake:
        spitfire_menu(fake, labels)
        bbc = fake.bbc
        assert spitfire_line(bbc, labels) == b"SPITFIRE STICKS: 4 "
        assert peek(bbc, labels, "stick_usable") == bytes([1, 1, 1, 1])
        assert entries(bbc, labels) == [b"KEYS"] * 4

        press_fire(fake, 0)                     # joystick 1 takes the Ranger
        assert entries(bbc, labels) == [b"JOY1", b"KEYS", b"KEYS", b"KEYS"]
        press_fire(fake, 2)                     # joystick 3 takes the next free hero
        assert entries(bbc, labels) == [b"JOY1", b"JOY3", b"KEYS", b"KEYS"]
        press_fire(fake, 2)                     # and moves on, leaving the Magic-User on keys
        assert entries(bbc, labels) == [b"JOY1", b"KEYS", b"JOY3", b"KEYS"]
        press_fire(fake, 2)
        press_fire(fake, 2)                     # past the Fighter: nobody
        assert entries(bbc, labels) == [b"JOY1", b"KEYS", b"KEYS", b"KEYS"]
        assert peek(bbc, labels, "hero_stick") == bytes([0, NO_STICK, NO_STICK, NO_STICK])

        start_play(bbc, labels)
        assert bbc.memory.address.peek[labels["read_controls"]] != RTS


def test_a_stick_moves_its_hero(labels):
    with machine_with_fake() as fake:
        spitfire_menu(fake, labels)
        bbc = fake.bbc
        press_fire(fake, 1)                     # joystick 2 takes the Ranger
        start_play(bbc, labels)
        fake.set_switches([0, RIGHT, 0, 0])
        bbc.run_for_emulated_seconds(1)
        assert bbc.memory.address.peek[labels["hero_direction"]] == DIRECTION_RIGHT


def test_fire_and_a_direction_held_cast_magic(labels):
    with machine_with_fake() as fake:
        spitfire_menu(fake, labels)
        bbc = fake.bbc
        press_fire(fake, 0)                     # joystick 1 takes the Ranger
        start_play(bbc, labels)
        fake.set_switches([FIRE | DOWN, 0, 0, 0])
        bp = bbc.debugger.add_breakpoint(labels["cast_magic"])
        bbc.debugger.run_to(labels["cast_magic"], timeout=60)
        bp.remove()
        assert bbc.cpu.pc == labels["cast_magic"]
        assert bbc.memory.address.peek[labels["control_bits"]] & SWITCH_MAGIC
        assert bbc.memory.address.peek[labels["magic_charge"]] == MAGIC_HOLD_FRAMES - 1


def test_a_short_press_of_fire_and_a_direction_casts_nothing(labels):
    with machine_with_fake() as fake:
        spitfire_menu(fake, labels)
        bbc = fake.bbc
        press_fire(fake, 0)
        start_play(bbc, labels)
        bp = bbc.debugger.add_breakpoint(labels["cast_magic"])
        fake.set_switches([FIRE | DOWN, 0, 0, 0])
        bbc.run_for_emulated_seconds(4 * FRAME_SECONDS)
        fake.set_switches([0, 0, 0, 0])
        bbc.run_for_emulated_seconds(1)
        assert bbc.cpu.pc != labels["cast_magic"]
        bp.remove()


def test_spitfire_not_ready_offers_no_sticks(labels):
    with machine_with_fake() as fake:
        identify, summary, describe = twin_twins()
        identify = identify[:4] + bytes([0x01])         # status: no workspace
        fake.as_spitfire(identify, summary, describe)
        to_menu(fake.bbc, labels, before_menu=fake.hook_osbyte)
        bbc = fake.bbc
        assert spitfire_line(bbc, labels) == b"SPITFIRE:CTRL-BREAK"
        assert bbc.memory.address.peek[labels["read_controls"]] == RTS
        assert peek(bbc, labels, "stick_usable") == bytes(4)


@pytest.mark.parametrize("flags, text", [
    (0x02, b"SPITFIRE NO REPLY  "),
    (0x04 | 0x08, b"SPITFIRE STICKS OFF"),      # the first flag set is the one shown
    (0x08, b"SPITFIRE: *FX16,4  "),
])
def test_spitfire_says_why_it_is_not_ready(labels, flags, text):
    with machine_with_fake() as fake:
        identify, summary, describe = twin_twins()
        fake.as_spitfire(identify[:4] + bytes([flags]), summary, describe)
        to_menu(fake.bbc, labels, before_menu=fake.hook_osbyte)
        assert spitfire_line(fake.bbc, labels) == text


def test_analogue_sticks_without_spitfire(labels):
    with machine_with_fake() as fake:
        fake.as_analogue_port()
        to_menu(fake.bbc, labels, before_menu=fake.hook_osbyte)
        bbc = fake.bbc
        assert spitfire_line(bbc, labels) == b" " * 19       # nothing said of SPItFIRE
        assert peek(bbc, labels, "stick_usable") == bytes([1, 1, 0, 0])
        fake.set_fire(0x02)                     # joystick 2's fire
        bbc.run_for_emulated_seconds(0.2)
        fake.set_fire(0)
        bbc.run_for_emulated_seconds(0.2)
        assert entries(bbc, labels) == [b"JOY2", b"KEYS", b"KEYS", b"KEYS"]

        start_play(bbc, labels)
        fake.set_axes([0x8000, 0x8000, 0x1000, 0x8000])     # joystick 2's X low: right
        bbc.run_for_emulated_seconds(1)
        assert bbc.memory.address.peek[labels["hero_direction"]] == DIRECTION_RIGHT


def test_keyboard_play_reads_no_sticks(labels):
    with launched(MACHINES["dfs226"]) as bbc:
        to_menu(bbc, labels)
        start_play(bbc, labels)
        assert bbc.memory.address.peek[labels["read_controls"]] == RTS
        assert peek(bbc, labels, "control_bits") == bytes(4)
