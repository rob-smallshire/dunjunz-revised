"""Report the run-time address range and size of each module of the game.

    uv run dr-sizes

Assembles a copy of asm/dunjunz.asm with a label before and after each
INCLUDE, and reads the labels back from beebasm's symbol dump.
"""

from __future__ import annotations

import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from dunjunz_revised.build import ASM_DIRPATH, PROJECT_DIRPATH, find_beebasm, parse_labels

INCLUDE = re.compile(r'^INCLUDE "(asm/[^"]+)"\s*$')


@dataclass(frozen=True)
class Module:
    path: str
    start: int
    end: int

    @property
    def size(self) -> int:
        return self.end - self.start


def measure(top_filepath: Path = ASM_DIRPATH / "dunjunz.asm") -> list[Module]:
    paths = []
    marked = []
    for line in top_filepath.read_text().splitlines():
        m = INCLUDE.match(line)
        if m:
            n = len(paths)
            paths.append(m[1])
            marked += [f".sizes_start_{n}", line, f".sizes_end_{n}"]
        else:
            marked.append(line)
    with tempfile.TemporaryDirectory() as tmp_dirpath:
        source_filepath = Path(tmp_dirpath) / "sizes.asm"
        source_filepath.write_text("\n".join(marked) + "\n")
        result = subprocess.run(
            [find_beebasm(), "-i", str(source_filepath), "-do", str(Path(tmp_dirpath) / "sizes.ssd"), "-d"],
            cwd=PROJECT_DIRPATH, capture_output=True, text=True,
        )
    if result.returncode != 0:
        raise RuntimeError(result.stderr)
    symbols = parse_labels(result.stdout)
    return [Module(path, symbols[f"sizes_start_{n}"], symbols[f"sizes_end_{n}"]) for n, path in enumerate(paths)]


def main() -> None:
    total = 0
    for module in measure():
        print(f"&{module.start:04X}-&{module.end - 1:04X}  {module.size:5d}  {module.path}")
        total += module.size
    print(f"{'':11}  {total:5d}  in all")


if __name__ == "__main__":
    main()
