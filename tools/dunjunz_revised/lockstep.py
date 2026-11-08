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
    ("scratch", 0x100),              # the per-level workspace: heroes, missiles, keys, views
    ("hero_max_missiles", 4),        # hero attributes and counters
    ("hero_magic_delay", 2),
    ("magic_kill_count", 2),
    ("returning_hero_queue", 5),
    ("next_trapdoor", 1),
    ("monster_hit_points", 31),
    ("hero_missile_damage", 4),
    ("missile_damage", 12),
    ("trapdoor_x", 8),
    ("trapdoor_y", 8),
    ("hero_score_hundreds", 4),
    ("hero_score_tens", 4),
    ("hero_score_units", 4),
    ("hero_score_thousands", 4),
    ("hero_score_ten_thousands", 4),
    ("room_walls", 0xC9),            # the wall map, map_bytes long (its first bytes double as character 128)
    ("hero_damage_taken", 4),
    ("exit_saved_x", 0x10),          # the exit animation's state
    ("object_free_map", 0xC9),
    ("door_x+1", 20),                # doors and keys, entries 1-20 (entry 0 is never used)
    ("door_y+1", 20),
    ("door_sprite+1", 20),
    ("key_x+1", 20),
    ("key_y+1", 20),
    ("hero_key", 5),                 # keys carried and dropped, doors bumped
    ("hero_key_dropped", 5),
    ("hero_door_x", 5),
    ("hero_door_y", 5),
    ("monster_x+1", 30),             # the monsters, entries 1-30 (31-40 are scratch)
    ("monster_y+1", 30),             
    ("monster_sprite+1", 30),        
    ("monster_frame+1", 30),         
    ("monster_offset_x+1", 30),      
    ("monster_offset_y+1", 30),      
    ("monster_step+1", 30),          
    ("object_x", 0x5D),              # objects and the exit: x, y and type, 31 entries each
    ("sprite_widths", 0x78),         # changed by the exit animation
    ("sprite_heights", 0x78),
    ("level_number", 1),
    ("monster_start_hit_points", 1),
)

# State at fixed addresses, defined with = rather than as labels, so absent
# from beebasm's symbol dump.
FIXED_ADDRESSES = {
    "hero_score_ten_thousands": 0x08B0,
}

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
    occasional firing and, rarely, magic. Comparisons with the original use no
    magic, since casting it plays differently now (the other heroes go on
    moving while it recharges)."""

    seed: int = 1
    hold_frames: int = 6
    magic: float = 0.02         # chance per frame that a hero with magic casts it

    def keys_for(self, frame: int) -> set[int]:
        rng = random.Random(self.seed * 1_000_003 + frame // self.hold_frames)
        keys = set()
        for hero_keys in HERO_KEYS:
            choice = rng.randrange(6)
            if choice < 4:
                keys.add(hero_keys[choice])
            if rng.random() < 0.3:
                keys.add(hero_keys[4])
            if len(hero_keys) > 5 and rng.random() < self.magic:
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

    def pin_randomness(self, seed: bool = True) -> int:
        """Patch every `lda system_via_t1c_l` in the game into `jsr` RNG_ADDRESS,
        and (unless seed is false) seed the generator."""
        self.poke(RNG_ADDRESS, RNG_CODE)
        if seed:
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

    def next_frame(self, keys: set[int], game_over_address: int | None = None) -> bool:
        """Hold keys and run to the start of the next frame, or to
        game_over_address if given and reached first: return whether the game
        is still being played."""
        self.set_keys(keys)
        stop = self.bbc.debugger.add_breakpoint(game_over_address) if game_over_address is not None else None
        try:
            self.bbc.debugger.run_to(self.labels[UPDATE_GAME], skip_current=True, timeout=60)
        finally:
            if stop is not None:
                stop.remove()
        self.frame += 1
        return self.bbc.cpu.pc == self.labels[UPDATE_GAME]

    def address(self, name: str) -> int:
        """The address of a label, a fixed address, or "label+N"."""
        label, _, offset = name.partition("+")
        base = self.labels[label] if label in self.labels else FIXED_ADDRESSES[label]
        return base + (int(offset) if offset else 0)

    def end_level(self, label: str) -> None:
        """Leave the level as if a hero had survived it, by jumping to label (the
        build's way on to the next level), and run to the next level's first frame.
        A build that reloads itself for each level loses the randomness patches, so
        they are made again, keeping the generator's state."""
        self.set_keys(set())
        self.bbc.cpu.pc = self.labels[label]
        self.bbc.debugger.run_to(self.labels[UPDATE_GAME], timeout=120)
        self.pin_randomness(seed=False)
        self.frame += 1

    def state(self) -> dict[str, bytes]:
        state = {label: self.peek(self.address(label), length) for label, length in STATE_BLOCKS}
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
