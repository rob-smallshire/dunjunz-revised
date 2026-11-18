"""The README's animated title screen, docs/title-screen.gif, made from the game.

The title program, DUNJUNZ, twinkles up to three stars over the picture
until a key is pressed (twinkle_stars in asm/title.asm). Here its own
routines run in py65, on the revised picture as last built: each pass of
its loop starts a star one time in four (start_star) and moves every star
on a frame (advance_stars), and the screen after each pass is a frame of
the GIF, shown for as long as the next pass takes on a 2 MHz BBC Micro.

Only the random choices are made here instead of by the title: whether a
pass starts a star and at which free place, from a fixed seed, so the GIF
is the same every time. The title reads its randomness from the System
VIA's timer; the chosen place is put there for start_star to read. The
pauses that set the twinkle's pace are busy loops; they are counted, not
run, which makes the whole thing many times quicker.

The animation starts with no stars. After ANIMATION_SECONDS no more stars
start, and once the last has faded the GIF loops back to the start, so it
loops without a seam.

    uv run dr-title-gif          # after uv run dr-build
"""

from __future__ import annotations

import random
from pathlib import Path

from py65.devices.mpu6502 import MPU

from dunjunz_revised.build import PROJECT_DIRPATH, REVISED_BUILD_DIRPATH, read_labels
from dunjunz_revised.gif import animated_gif
from dunjunz_revised.png import PALETTE, mode2_pixels
from dunjunz_revised.title_picture import (
    BYTES_PER_CHARACTER_ROW, PICTURE_ADDRESS, SCREEN_END, SCREEN_HEIGHT, SCREEN_START, SCREEN_WIDTH,
)

TITLE_SCREEN_GIF_FILEPATH = PROJECT_DIRPATH / "docs" / "title-screen.gif"
PIXEL_WIDTH, PIXEL_HEIGHT = 4, 2        # each MODE 2 pixel, as title_png draws them
CLOCK_HZ = 2_000_000
SEED = 1987
ANIMATION_SECONDS = 12                  # then no new stars, and the GIF loops when the last fades
NEW_STAR_CHANCE = 4                     # twinkle_stars starts a star when timer bits 0-1 are 0
PLACES = 8                              # star_places_x and star_places_y
STARS = 3                               # star_showing
SYSTEM_VIA_T1C_L = 0xFE44               # read by twinkle_stars and start_star
OS_ZP_FA, OS_IRQ_A = 0xFA, 0xFC         # mixed into start_star's choice of place
RETURN_ADDRESS = 0xFFF0
STEP_LIMIT = 1_000_000
# Cycles for one outer pass of the pause in advance_stars (ldy #&FF; 255 x
# dey/bne; dex; bne): 2 + (255 x 5 - 1) + 2 + 3 = 1281; the last bne is not
# taken, one cycle fewer.
PAUSE_CYCLES_PER_PASS = 1281
# On a BBC Micro the MOS's interrupts take some of the time, and each pass
# also reads the timer and scans the keyboard (OSBYTE &7A), neither run here.
# Timing the title's passes in beebium (DFS 0.90), with 0 to 3 stars showing,
# a pass takes INTERRUPT_SCALE x its cycles here + PASS_OVERHEAD_CYCLES.
INTERRUPT_SCALE = 1.0475
PASS_OVERHEAD_CYCLES = 474


class Title:
    """DUNJUNZ and the revised picture, in py65."""

    def __init__(self, build_dirpath: Path = REVISED_BUILD_DIRPATH):
        self.labels = read_labels(build_dirpath, "title")
        self.memory = bytearray(0x10000)
        program = (build_dirpath / "Dunjunz").read_bytes()
        start = self.labels["dasmos_start"]
        self.memory[start:start + len(program)] = program
        picture = (build_dirpath / "Screen").read_bytes()
        self.memory[PICTURE_ADDRESS:PICTURE_ADDRESS + len(picture)] = picture
        self.mpu = MPU(memory=self.memory)
        self.pause = self.labels["star_pause_outer"]
        self.after_pause = self.labels["star_pause_inner"] + 6     # past dey, bne, dex, bne: the pla
        for star in range(STARS):
            self.memory[self.labels["star_showing"] + star] = 0  # as twinkle_stars starts

    def call(self, name: str) -> int:
        """Run a routine to its RTS, counting the pauses instead of running
        them; return its cycles."""
        mpu = self.mpu
        mpu.sp = 0xFD
        mpu.memory[0x01FE], mpu.memory[0x01FF] = (RETURN_ADDRESS - 1) & 0xFF, (RETURN_ADDRESS - 1) >> 8
        mpu.pc = self.labels[name]
        start = mpu.processorCycles
        counted = 0
        for _ in range(STEP_LIMIT):
            if mpu.pc == RETURN_ADDRESS:
                return mpu.processorCycles - start + counted
            if mpu.pc == self.pause:
                counted += mpu.x * PAUSE_CYCLES_PER_PASS - 1
                mpu.x = mpu.y = 0
                mpu.pc = self.after_pause
                continue
            mpu.step()
        raise RuntimeError(f"{name} did not return; PC &{mpu.pc:04X}")

    def stars_showing(self) -> int:
        return sum(self.memory[self.labels["star_showing"] + star] for star in range(STARS))

    def free_places(self) -> list[int]:
        return [place for place in range(PLACES) if self.memory[self.labels["star_places_x"] + place] < 0x80]

    def start_star(self, place: int) -> int:
        """start_star, at place: the timer reads as place, the rest of its mix as 0."""
        self.memory[SYSTEM_VIA_T1C_L] = place
        self.memory[OS_ZP_FA] = self.memory[OS_IRQ_A] = 0
        return self.call("start_star")

    def screen(self) -> bytes:
        return bytes(self.memory[SCREEN_START:SCREEN_END])


def character_row_pixels(screen: bytes, row: int) -> bytes:
    """The GIF's pixels (colour indices, 0-7) of a character row of the screen."""
    lines = []
    for line in range(8):
        pixels = bytearray()
        for column in range(SCREEN_WIDTH // 2):
            for colour in mode2_pixels(screen[row * BYTES_PER_CHARACTER_ROW + column * 8 + line]):
                pixels += bytes([colour & 7]) * PIXEL_WIDTH        # flashing colours as their first
        lines.append(bytes(pixels) * PIXEL_HEIGHT)
    return b"".join(lines)


def twinkle(seed: int = SEED, seconds: float = ANIMATION_SECONDS) -> list[tuple[bytes, int]]:
    """The screens of the twinkle, pass by pass, with each pass's cycles:
    from the picture with no stars until, after seconds, the last star has
    faded and the screen is the picture again."""
    title, chance = Title(), random.Random(seed)
    passes, cycles_so_far = [], 0
    while True:
        cycles = 0
        starting = cycles_so_far < seconds * CLOCK_HZ
        if starting and chance.randrange(NEW_STAR_CHANCE) == 0 and title.stars_showing() < STARS:
            cycles += title.start_star(chance.choice(title.free_places()))
        cycles += title.call("advance_stars")
        cycles = round(cycles * INTERRUPT_SCALE) + PASS_OVERHEAD_CYCLES
        cycles_so_far += cycles
        passes.append((title.screen(), cycles))
        if not starting and title.stars_showing() == 0:
            return passes


def title_animation(seed: int = SEED, seconds: float = ANIMATION_SECONDS) -> bytes:
    passes = twinkle(seed, seconds)
    # Each screen shows until the next pass has drawn the next: for as long as
    # that pass takes. The last, the picture again, shows for as long as the
    # first pass takes, as the GIF loops back to it.
    shown_cycles = [cycles for _, cycles in passes[1:]] + [passes[0][1]]
    frames, rows, previous_screen, elapsed = [], None, None, 0
    for (screen, _), cycles in zip(passes, shown_cycles):
        if rows is None:
            rows = [character_row_pixels(screen, row) for row in range(SCREEN_HEIGHT // 8)]
        else:
            for row in range(SCREEN_HEIGHT // 8):
                span = slice(row * BYTES_PER_CHARACTER_ROW, (row + 1) * BYTES_PER_CHARACTER_ROW)
                if screen[span] != previous_screen[span]:
                    rows[row] = character_row_pixels(screen, row)
        previous_screen = screen
        # Delays in centiseconds, rounded so that they add up to the time taken.
        delay = round((elapsed + cycles) * 100 / CLOCK_HZ) - round(elapsed * 100 / CLOCK_HZ)
        elapsed += cycles
        pixels = b"".join(rows)
        if frames and frames[-1][0] == pixels:
            frames[-1] = (pixels, frames[-1][1] + delay)
        else:
            frames.append((pixels, delay))
    if len(frames) > 1 and frames[-1][0] == frames[0][0]:       # the picture again, at the end
        last = frames.pop()
        frames[0] = (frames[0][0], frames[0][1] + last[1])
    return animated_gif(SCREEN_WIDTH * PIXEL_WIDTH, SCREEN_HEIGHT * PIXEL_HEIGHT, PALETTE, frames)


def main() -> None:
    gif = title_animation()
    if not TITLE_SCREEN_GIF_FILEPATH.exists() or TITLE_SCREEN_GIF_FILEPATH.read_bytes() != gif:
        TITLE_SCREEN_GIF_FILEPATH.write_bytes(gif)
        print(f"Wrote {TITLE_SCREEN_GIF_FILEPATH.relative_to(PROJECT_DIRPATH)}")
    else:
        print(f"{TITLE_SCREEN_GIF_FILEPATH.relative_to(PROJECT_DIRPATH)} is up to date")


if __name__ == "__main__":
    main()
