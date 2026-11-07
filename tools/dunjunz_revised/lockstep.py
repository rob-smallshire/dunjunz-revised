"""Run a build of the game frame by frame, with scripted keys and pinned
randomness, and read its state, so that two builds can be compared.

The game draws its random numbers from the System VIA's timer 1 (`lda
system_via_t1c_l`), which depends on timing, so a build whose code has moved
or changed speed would make different choices. GameRun patches every such
read in the game code into a `jsr` to a small linear-feedback shift
register in zero page (RNG_ADDRESS, which the game must leave alone), so
two builds that make the same calls get the same numbers.

State is read by label, through each build's own symbols, as blocks of
bytes (STATE_BLOCKS) that must keep their internal layout, plus the screen.
A block that is rearranged in the revised game needs its own entry here.

Keys are pressed on the keyboard matrix from the start of one frame
(update_game) to the start of the next.
"""

from __future__ import annotations

import contextlib
import random
from collections.abc import Iterator
from dataclasses import dataclass
from pathlib import Path

from dunjunz_revised.machines import MACHINES, Machine, launched

UPDATE_GAME = "update_game"
RNG_ADDRESS = 0x0060
RNG_SEED_ADDRESS = 0x006F
RNG_SEED = 0x5A
# lda seed : asl a : bcc + : eor #&1D : + sta seed : rts
RNG_CODE = bytes([0xA5, RNG_SEED_ADDRESS, 0x0A, 0x90, 0x02, 0x49, 0x1D, 0x85, RNG_SEED_ADDRESS, 0x60])
LDA_VIA_T1C_L = bytes([0xAD, 0x44, 0xFE])

SCREEN = (0x3000, 0x6E80)

# (label, length): blocks of game state compared between builds.
STATE_BLOCKS = (
    ("scratch", 0x100),              # page &0D: heroes, missiles, keys, views (per-level workspace)
    ("hero_max_missiles", 0xD0),     # &0B20-&0BEF: hero attributes, queue, monster hit points, scores
    ("room_walls", 0xD0),            # the wall map (its first bytes double as character 128)
    ("hero_damage_taken", 4),
    ("exit_saved_x", 0x10),          # the exit animation's state
    ("object_free_map", 0xD0),
    ("door_x", 0xC0),                # doors and keys
    ("hero_key", 0x1A),              # keys carried, dropped, door cells
    ("monster_x", 0x120),            # monsters
    ("object_x", 0x6F),              # objects and the exit
    ("sprite_widths", 0x78),         # changed by the exit animation
    ("sprite_heights", 0x78),
    ("level_number", 1),
    ("monster_start_hit_points", 1),
)

# Each hero's keys, as negative INKEY numbers from the workspace template:
# up, down, right, left, fire, then magic for heroes 0 and 1 (hero_magic_key).
HERO_KEYS = (
    (0xBF, 0xAF, 0x9E, 0xFF, 0x9F, 0xFE),   # Ranger: CAPS LOCK, SHIFT LOCK, Z, SHIFT, TAB; CTRL
    (0x86, 0xC6, 0x96, 0xA6, 0xD6, 0xB6),   # Magic-User: right, up, COPY, DELETE, down; RETURN
    (0xB9, 0x99, 0x97, 0x98, 0x9D),         # Barbarian: K , / . SPACE
    (0xAC, 0x9B, 0xDA, 0xCA, 0xC9),         # Fighter: G B I U O
)
# The number of `lda system_via_t1c_l` in the game: two in update_monsters,
# one in dissolve_chalice.
VIA_TIMER_READS = 3


def inkey_to_matrix(inkey: int) -> tuple[int, int]:
    """The keyboard matrix (row, column) of a negative INKEY number held as a byte."""
    internal = 0xFF - inkey
    return internal >> 4, internal & 0x0F


@dataclass(frozen=True)
class Script:
    """Which keys each hero holds in each frame: a seeded random walk with
    occasional firing and, rarely, magic."""

    seed: int = 1
    hold_frames: int = 6

    def keys_for(self, frame: int) -> set[int]:
        rng = random.Random(self.seed * 1_000_003 + frame // self.hold_frames)
        keys = set()
        for hero_keys in HERO_KEYS:
            choice = rng.randrange(6)
            if choice < 4:
                keys.add(hero_keys[choice])
            if rng.random() < 0.3:
                keys.add(hero_keys[4])
            if len(hero_keys) > 5 and rng.random() < 0.02:
                keys.add(hero_keys[5])
        return keys


class GameRun:
    def __init__(self, bbc, labels: dict[str, int], game_ranges: tuple[tuple[int, int], ...]):
        self.bbc = bbc
        self.labels = labels
        self.game_ranges = game_ranges
        self.held: set[int] = set()
        self.frame = 0

    def peek(self, address: int, length: int) -> bytes:
        return bytes(self.bbc.memory.address.peek[address:address + length])

    def poke(self, address: int, data: bytes) -> None:
        self.bbc.memory.address.bus.write(address, data)

    def pin_randomness(self) -> int:
        """Patch every `lda system_via_t1c_l` in the game into `jsr` RNG_ADDRESS."""
        self.poke(RNG_ADDRESS, RNG_CODE)
        self.poke(RNG_SEED_ADDRESS, bytes([RNG_SEED]))
        jsr = bytes([0x20, RNG_ADDRESS & 0xFF, RNG_ADDRESS >> 8])
        patched = 0
        for start, end in self.game_ranges:
            memory = self.peek(start, end - start)
            offset = memory.find(LDA_VIA_T1C_L)
            while offset >= 0:
                self.poke(start + offset, jsr)
                patched += 1
                offset = memory.find(LDA_VIA_T1C_L, offset + 1)
        return patched

    def set_keys(self, keys: set[int]) -> None:
        keyboard = self.bbc.keyboard
        for inkey in self.held - keys:
            keyboard.matrix_up(*inkey_to_matrix(inkey))
        for inkey in keys - self.held:
            keyboard.matrix_down(*inkey_to_matrix(inkey))
        self.held = set(keys)

    def next_frame(self, keys: set[int]) -> None:
        """Hold keys and run to the start of the next frame."""
        self.set_keys(keys)
        self.bbc.debugger.run_to(self.labels[UPDATE_GAME], skip_current=True, timeout=60)
        self.frame += 1

    def state(self) -> dict[str, bytes]:
        state = {label: self.peek(self.labels[label], length) for label, length in STATE_BLOCKS}
        state["screen"] = self.peek(SCREEN[0], SCREEN[1] - SCREEN[0])
        return state


def hold_key(bbc, row: int, column: int, seconds: float = 0.1) -> None:
    bbc.keyboard.matrix_down(row, column)
    bbc.run_for_emulated_seconds(seconds)
    bbc.keyboard.matrix_up(row, column)


SPACE = inkey_to_matrix(0x9D)


@contextlib.contextmanager
def game_run(
    disc_filepath: Path,
    labels: dict[str, int],
    game_ranges: tuple[tuple[int, int], ...],
    machine: Machine = MACHINES["dfs090"],
    boot_seconds: float = 120,
) -> Iterator[GameRun]:
    """Boot a disc, start a game with every hero, and stop at the first frame."""
    with launched(machine) as bbc:
        bbc.boot_disc(disc_filepath)
        update_game = labels[UPDATE_GAME]
        bp = bbc.debugger.add_breakpoint(update_game)
        try:
            for _ in range(int(boot_seconds / 0.5)):
                bbc.run_for_emulated_seconds(0.5)
                if bbc.cpu.pc == update_game:
                    break
                bbc.debugger.run()
                hold_key(bbc, *SPACE)
            else:
                raise RuntimeError(f"never reached play; PC &{bbc.cpu.pc:04X}")
        finally:
            bp.remove()
        run = GameRun(bbc, labels, game_ranges)
        patched = run.pin_randomness()
        if patched != VIA_TIMER_READS:
            raise RuntimeError(f"found {patched} System VIA timer reads to pin, not {VIA_TIMER_READS}")
        yield run
