"""Measure how long a frame of play takes, in the 1987 game and the revised one.

    uv run dr-frame-time                  # 300 frames of scripted play, seed 1
    uv run dr-frame-time --frames 600 --seed 6

The game starts a frame every three vertical syncs (play_level), 120,000
cycles at 2 MHz, but a frame of four heroes in play usually takes longer
than that, so the frame's own work sets the game's pace: a slower frame is a
slower game. Both builds play the same scripted keys (as the equivalence
tests do, without magic) and the cycles from one update_game to the next
are counted. Compare the medians before and after a change to the drawing
or the frame.
"""

from __future__ import annotations

import argparse

from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    ORIGINAL_DISC_FILEPATH,
    REVISED_BUILD_DIRPATH,
    REVISED_DISC_FILEPATH,
    read_labels,
)
from dunjunz_revised.lockstep import UPDATE_GAME, Script, game_run

GAME_RANGES = ((0x0400, 0x3000), (0x6E80, 0x8000))


def frame_cycles(disc_filepath, labels, seed: int, frames: int) -> list[int]:
    """The cycles between the starts of successive frames of scripted play."""
    script = Script(seed=seed, magic=0)
    with game_run(disc_filepath, labels, GAME_RANGES) as run:
        debugger = run.bbc.debugger
        cycles = []
        last = debugger.cycle_count
        for frame in range(frames):
            run.set_keys(script.keys_for(frame))
            debugger.run_to(labels[UPDATE_GAME], skip_current=True, timeout=30)
            if run.bbc.cpu.pc != labels[UPDATE_GAME]:
                break                           # game over
            now = debugger.cycle_count
            cycles.append(now - last)
            last = now
        return cycles


def summary(cycles: list[int]) -> str:
    ordered = sorted(cycles)
    return (f"{len(ordered)} frames: median {ordered[len(ordered) // 2]:,}, "
            f"90% {ordered[int(len(ordered) * 0.9)]:,}, max {ordered[-1]:,} cycles")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--frames", type=int, default=300)
    parser.add_argument("--seed", type=int, default=1)
    arguments = parser.parse_args()
    original = frame_cycles(ORIGINAL_DISC_FILEPATH, read_labels(ORIGINAL_BUILD_DIRPATH, "game"),
                            arguments.seed, arguments.frames)
    revised = frame_cycles(REVISED_DISC_FILEPATH, read_labels(REVISED_BUILD_DIRPATH, "dunjunz"),
                           arguments.seed, arguments.frames)
    print(f"1987:    {summary(original)}")
    print(f"revised: {summary(revised)}")
    median = sorted(revised)[len(revised) // 2] / sorted(original)[len(original) // 2]
    print(f"revised median frame: {median:.0%} of 1987's")


if __name__ == "__main__":
    main()
