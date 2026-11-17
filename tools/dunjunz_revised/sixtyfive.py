"""Run the game's routines on their own, in py65, without booting a BBC Micro.

    image = GameImage.revised()             # the last build of the revised game
    cycles = image.call("plot_sprite")      # run a routine to its RTS

GAME is put at &1C00, where it loads, and the parts stored in it at &3000,
&3400 and &3800 are copied to &0400, &0900 and &0F00, as startup does (see
asm/dunjunz.asm), so the plotter, the sprite tables and the sprites are in
place. Nothing else is set up: no MOS, no level, an empty screen (the stored
copies at &3000-&3FFF are cleared, as the hero menu clears the screen). A
routine that calls the MOS cannot be run like this. This is for working on a
routine quickly: checking what it writes, and counting its cycles, against a
model in Python, many times faster than a whole game in beebium.
"""

from __future__ import annotations

from pathlib import Path

from py65.devices.mpu6502 import MPU

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, read_labels

GAME_ADDRESS = 0x1C00
# (stored at, copied to, length): startup's copies (asm/dunjunz.asm).
STORED_PARTS = ((0x3000, 0x0400, 0x0300), (0x3400, 0x0900, 0x0400), (0x3800, 0x0F00, 0x0800))
SCREEN_START, SCREEN_END = 0x3000, 0x6E80
RETURN_ADDRESS = 0xFFF0                 # a routine's RTS comes back here
STEP_LIMIT = 2_000_000


class GameImage:
    def __init__(self, game: bytes, labels: dict[str, int]):
        self.labels = labels
        self.memory = bytearray(0x10000)
        self.memory[GAME_ADDRESS:GAME_ADDRESS + len(game)] = game
        for stored, address, length in STORED_PARTS:
            self.memory[address:address + length] = self.memory[stored:stored + length]
        self.clear_screen()
        self.mpu = MPU(memory=self.memory)

    @classmethod
    def revised(cls, build_dirpath: Path = REVISED_BUILD_DIRPATH) -> GameImage:
        return cls((build_dirpath / "GAME").read_bytes(), read_labels(build_dirpath, "dunjunz"))

    def address(self, name: str) -> int:
        label, _, offset = name.partition("+")
        return self.labels[label] + (int(offset, 0) if offset else 0)

    def clear_screen(self) -> None:
        self.memory[SCREEN_START:SCREEN_END] = bytes(SCREEN_END - SCREEN_START)

    def peek(self, address: int, length: int = 1) -> bytes:
        return bytes(self.memory[address:address + length])

    def poke(self, address: int, data: bytes) -> None:
        self.memory[address:address + len(data)] = data

    def call(self, name: str, a: int = 0, x: int = 0, y: int = 0) -> int:
        """Run the routine at label name until it returns; return its cycles."""
        mpu = self.mpu
        mpu.a, mpu.x, mpu.y = a, x, y
        mpu.sp = 0xFF
        return_to = RETURN_ADDRESS - 1      # an RTS adds one
        mpu.memory[0x01FF] = return_to >> 8
        mpu.memory[0x01FE] = return_to & 0xFF
        mpu.sp = 0xFD
        mpu.pc = self.address(name)
        start = mpu.processorCycles
        for _ in range(STEP_LIMIT):
            if mpu.pc == RETURN_ADDRESS:
                return mpu.processorCycles - start
            mpu.step()
        raise RuntimeError(f"{name} did not return; PC &{mpu.pc:04X}")
