"""A fake SPItFIRE (tests/fake_spitfire.asm) in a beebium Model B.

Beebium emulates neither SPItFIRE nor the analogue-to-digital converter. The
fake is a sideways ROM in a RAM slot: it answers OSWORD &3F as SPItFIRE does
(mode 1), and OSBYTE &80 either with SPItFIRE's switch bytes (mode 1) or as
an analogue port (mode 2). Its configuration is in its own bank, written
through beebium while the bank is not paged in, so it takes none of the
game's memory.
"""

from __future__ import annotations

import contextlib
import dataclasses
from collections.abc import Iterator

from dunjunz_revised.build import BUILD_DIRPATH, PROJECT_DIRPATH, assemble, parse_labels
from dunjunz_revised.machines import MACHINES, launched

FAKE_SLOT = 12
FAKE_SOURCE_FILEPATH = PROJECT_DIRPATH / "tests" / "fake_spitfire.asm"
FAKE_BUILD_DIRPATH = BUILD_DIRPATH / "fake_spitfire"

MODE_OFF, MODE_SPITFIRE, MODE_ANALOGUE = 0, 1, 2

BYTEV = 0x020A
BYTEV_EXTENDED = 0xFF0F                    # the extended vector entry for BYTEV (vector 5)
BYTEV_EXTENDED_TABLE = 0x0D9F + 3 * 5      # its address and ROM number

# SPItFIRE's descriptions (its guide, "The OSWORD &3F block").
PORT_A, PORT_B = 0x00, 0x80
SECOND_HANDSET = 0x40
TWIN = 4                                   # port type 3BT: a Delta 3B Twin
KIND_STICK = 1
XY_READINGS, DIRECTIONS = 1, 2

FIRE, LEFT, DOWN, UP, RIGHT = 0x01, 0x10, 0x20, 0x40, 0x80


def twin_twins() -> tuple[bytes, bytes, bytes]:
    """Reasons 0, 1 and 2's answers for two Delta 3B Twins, on ports A and
    B: four sticks."""
    identify = bytes([1, 0x00, 0x03, 0x01, 0])            # API 1, ROM 0.03, joystick module, ready
    allocation = [PORT_A | TWIN, PORT_A | SECOND_HANDSET | TWIN,
                  PORT_B | TWIN, PORT_B | SECOND_HANDSET | TWIN]
    summary = bytes([4, TWIN, TWIN, *allocation, 0])
    describe = b"".join(bytes([a, KIND_STICK, XY_READINGS | DIRECTIONS, 1]) for a in allocation)
    return identify, summary, describe


@dataclasses.dataclass
class Fake:
    bbc: object
    labels: dict[str, int]

    def _write(self, label: str, data: bytes) -> None:
        self.bbc.memory.region(f"bank_{FAKE_SLOT}").bus.write(self.labels[label], bytes(data))

    def as_spitfire(self, identify: bytes, summary: bytes, describe: bytes) -> None:
        self._write("fake_identify", identify)
        self._write("fake_summary", summary)
        self._write("fake_describe", describe)
        self._write("fake_mode", bytes([MODE_SPITFIRE]))

    def as_analogue_port(self) -> None:
        self.set_fire(0)
        self.set_axes([0x8000] * 4)
        self._write("fake_mode", bytes([MODE_ANALOGUE]))

    def set_switches(self, switches: list[int]) -> None:
        """SPItFIRE's switch bytes for joysticks 1-4."""
        self._write("fake_switches", bytes(switches))

    def set_fire(self, fire: int) -> None:
        """ADVAL(0)'s low byte on an analogue port."""
        self._write("fake_fire", bytes([fire]))

    def set_axes(self, axes: list[int]) -> None:
        """ADVAL(1)-(4) on an analogue port."""
        self._write("fake_axes", b"".join(value.to_bytes(2, "little") for value in axes))

    def hook_osbyte(self) -> None:
        """Point BYTEV at the fake's OSBYTE hook, through the MOS's extended
        vector, keeping the old BYTEV for it to pass calls on to."""
        memory = self.bbc.memory.address.bus
        self._write("fake_old_bytev", bytes(memory[BYTEV:BYTEV + 2]))
        hook = self.labels["byte_hook"]
        memory.write(BYTEV_EXTENDED_TABLE, bytes([hook & 0xFF, hook >> 8, FAKE_SLOT]))
        memory.write(BYTEV, BYTEV_EXTENDED.to_bytes(2, "little"))


def fake_rom() -> tuple[bytes, dict[str, int]]:
    assemble(FAKE_SOURCE_FILEPATH, FAKE_BUILD_DIRPATH)
    rom = (FAKE_BUILD_DIRPATH / "fake_spitfire.rom").read_bytes()
    labels = parse_labels((FAKE_BUILD_DIRPATH / "fake_spitfire.labels").read_text())
    return rom, labels


@contextlib.contextmanager
def machine_with_fake(machine_key: str = "dfs226") -> Iterator[Fake]:
    """A Model B with the fake in sideways RAM, not yet configured (so it
    answers nothing until a test says what it is). Boot it with a BREAK,
    such as boot_disc's, so that the MOS finds the ROM."""
    rom, labels = fake_rom()
    machine = dataclasses.replace(MACHINES[machine_key], ram_slots=(FAKE_SLOT,))
    with launched(machine) as bbc:
        bbc.memory.region(f"bank_{FAKE_SLOT}").bus.write(0x8000, rom)
        yield Fake(bbc, labels)
