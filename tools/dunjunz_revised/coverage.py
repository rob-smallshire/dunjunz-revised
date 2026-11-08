"""Find the revised game's instructions that never run in play.

    uv run python -m dunjunz_revised.coverage [FRAMES] [SEEDS ...]

Boots the revised disc on DFS 0.90, starts a game with every hero and, from
the first frame, puts a breakpoint on every instruction of the resident game
(from beebasm's listing). Each breakpoint is removed the first time it is
hit. The game is played with scripted keys for FRAMES frames per seed, moved
on a level once, and taken to game over. The instructions never reached are
reported as runs, under the label before each run.

An instruction never reached is a candidate for removal, not a verdict: the
scripted play cannot reach every path (victory, for one), so each run must
be judged by reading the code.
"""

from __future__ import annotations

import re
import sys
from bisect import bisect_right

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.lockstep import Script, game_run

LISTING_LINE = re.compile(r"^\s+([0-9A-F]{4})\s+((?:[0-9A-F]{2} ){1,3})\s*([A-Z]{3})\b")
# The resident game's regions (see asm/dunjunz.asm).
REGIONS = ((0x0400, 0x0700), (0x0900, 0x0D00), (0x0F00, 0x1700), (0x1C00, 0x3000), (0x6E80, 0x8000))


def instruction_addresses() -> list[int]:
    addresses = set()
    for line in (REVISED_BUILD_DIRPATH / "dunjunz.lst").read_text().splitlines():
        m = LISTING_LINE.match(line)
        if m:
            address = int(m[1], 16)
            if any(lo <= address < hi for lo, hi in REGIONS):
                addresses.add(address)
    return sorted(addresses)


class Coverage:
    def __init__(self, run, addresses):
        self.run = run
        self.bbc = run.bbc
        self.pending = {}
        for address in addresses:
            self.pending[address] = self.bbc.debugger.add_breakpoint(address)

    def run_to(self, stop_addresses: tuple[int, ...], keys: set[int] | None = None) -> int:
        """Run until one of stop_addresses, recording and removing coverage
        breakpoints met on the way, and return the address stopped at."""
        if keys is not None:
            self.run.set_keys(keys)
        stops = [self.bbc.debugger.add_breakpoint(a) for a in stop_addresses]
        try:
            while True:
                self.bbc.debugger.run_and_wait_for_stop(timeout=120)
                pc = self.bbc.cpu.pc
                if pc in self.pending:
                    self.pending.pop(pc).remove()
                if pc in stop_addresses:
                    return pc
        finally:
            for stop in stops:
                stop.remove()


def report(missed: list[int], labels: dict[str, int]) -> None:
    by_address = sorted((a, n) for n, a in labels.items() if not n.startswith("sizes_"))
    starts = [a for a, _ in by_address]
    runs = []
    for address in missed:
        if runs and address - runs[-1][-1] <= 3:
            runs[-1].append(address)
        else:
            runs.append([address])
    for run in runs:
        i = bisect_right(starts, run[0]) - 1
        label, base = (by_address[i][1], by_address[i][0]) if i >= 0 else ("?", 0)
        print(f"&{run[0]:04X}-&{run[-1]:04X} {len(run):3d} instructions  {label}+{run[0] - base}")


def main() -> None:
    frames = int(sys.argv[1]) if len(sys.argv) > 1 else 1500
    seeds = [int(s) for s in sys.argv[2:]] or [1, 2, 3]
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    remaining = set(instruction_addresses())
    total = len(remaining)
    for seed in seeds:
        script = Script(seed=seed)
        with game_run(REVISED_DISC_FILEPATH, labels, ((0x0400, 0x3000), (0x6E80, 0x8000))) as run:
            coverage = Coverage(run, sorted(remaining))
            update_game, game_over = labels["update_game"], labels["game_over"]
            stops = (update_game, game_over)
            ended = False
            for frame in range(frames):
                try:
                    if coverage.run_to(stops, script.keys_for(frame)) == game_over:
                        ended = True
                        break
                except Exception:
                    run.bbc.debugger.stop()
                    print(f"seed {seed}: stuck at frame {frame}, PC &{run.bbc.cpu.pc:04X}", flush=True)
                    raise
            if not ended:
                run.set_keys(set())
                run.bbc.cpu.pc = labels["next_level"]
                for frame in range(200):
                    if coverage.run_to(stops, script.keys_for(frames + frame)) == game_over:
                        ended = True
                        break
            if not ended:
                run.bbc.cpu.pc = game_over
            coverage.run_to((labels["wait_vsync_game_over"],))
            remaining = set(coverage.pending)
            print(f"seed {seed}: {total - len(remaining)} of {total} instructions run"
                  f"{' (game over in play)' if ended else ''}", flush=True)
    report(sorted(remaining), labels)


if __name__ == "__main__":
    main()
