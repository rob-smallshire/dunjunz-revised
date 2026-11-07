"""Build Dunjunz Revised.

For now the build has one stage, the baseline: it assembles the reassembled
1987 disc release in asm/original/ (taken from the acornaeology disassembly),
checks every file it saves byte-for-byte against the files of the original
disc in reference/disc/, and writes build/dunjunz-original.ssd, an 80-track
disc that boots the original game (which needs DFS 0.90). The baseline is the
fixed point the revised game is measured against: its behaviour, minus the
bugs, is what the revised game must keep.

    uv run dr-build
"""

from __future__ import annotations

import hashlib
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

PROJECT_DIRPATH = Path(__file__).resolve().parents[2]
ASM_DIRPATH = PROJECT_DIRPATH / "asm"
ORIGINAL_ASM_DIRPATH = ASM_DIRPATH / "original"
REFERENCE_DIRPATH = PROJECT_DIRPATH / "reference" / "disc"
BUILD_DIRPATH = PROJECT_DIRPATH / "build"
ORIGINAL_BUILD_DIRPATH = BUILD_DIRPATH / "original"
ORIGINAL_DISC_FILEPATH = BUILD_DIRPATH / "dunjunz-original.ssd"

ORIGINAL_DISC_TITLE = "DUNJUNZ 1987"

# The beebasm sources of the original release and the files each SAVEs.
ORIGINAL_SOURCES = {
    "game.asm": ("Dun1", "Coder"),
    "title.asm": ("Dunjunz",),
}


@dataclass(frozen=True)
class DiscFile:
    name: str
    load_address: int
    exec_address: int


# The Model B side of the 1987 disc, as the original game uses it, with the
# load and execution addresses in its catalogue. The Editor and Default are
# left out: the revised game does not use the level file format they write.
ORIGINAL_DISC_FILES = (
    DiscFile("Dunjunz", 0x26C0, 0x2700),
    DiscFile("Coder", 0x5000, 0x5000),
    DiscFile("Dun1", 0x2000, 0x2000),
    DiscFile("Screen", 0x3280, 0x3280),
    DiscFile("Stones", 0x6E80, 0x6E80),
    *(DiscFile(f"Level{n}", 0x6B00, 0x6B00) for n in range(1, 25)),
)


def find_beebasm() -> str:
    beebasm = shutil.which("beebasm")
    if beebasm is None:
        raise FileNotFoundError("beebasm not found on PATH")
    return beebasm


def assemble(source_filepath: Path, output_dirpath: Path) -> None:
    """Assemble a source with beebasm, its SAVEd files landing in output_dirpath."""
    output_dirpath.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [find_beebasm(), "-i", str(source_filepath), "-v"],
        cwd=output_dirpath,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"beebasm failed on {source_filepath.name}:\n{result.stdout}\n{result.stderr}")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def build_original() -> Path:
    """Reassemble the original release, verify it, and write its disc."""
    if ORIGINAL_BUILD_DIRPATH.exists():
        shutil.rmtree(ORIGINAL_BUILD_DIRPATH)
    for source_filename, saved_filenames in ORIGINAL_SOURCES.items():
        assemble(ORIGINAL_ASM_DIRPATH / source_filename, ORIGINAL_BUILD_DIRPATH)
        for saved_filename in saved_filenames:
            built = (ORIGINAL_BUILD_DIRPATH / saved_filename).read_bytes()
            reference = (REFERENCE_DIRPATH / saved_filename).read_bytes()
            if built != reference:
                raise RuntimeError(
                    f"{saved_filename} does not match the original: "
                    f"{sha256(built)} != {sha256(reference)}"
                )

    # !BOOT is a copy of Dunjunz, *RUN by boot option 2. A *EXEC !BOOT
    # (option 3) would leave the !BOOT file open while Coder copies the game
    # over the DFS's file buffers, and the game never reaches play.
    dunjunz = ORIGINAL_DISC_FILES[0]
    boot = DiscFile("!BOOT", dunjunz.load_address, dunjunz.exec_address)
    write_disc(
        ORIGINAL_DISC_FILEPATH,
        ORIGINAL_DISC_TITLE,
        2,
        [(boot, REFERENCE_DIRPATH / dunjunz.name)]
        + [(f, REFERENCE_DIRPATH / f.name) for f in ORIGINAL_DISC_FILES],
    )
    return ORIGINAL_DISC_FILEPATH


def write_disc(
    disc_filepath: Path,
    title: str,
    boot_option: int,
    files: list[tuple[DiscFile, Path]],
) -> None:
    """Write an 80-track single-sided DFS disc."""
    from oaknut.dfs.dfs import DFS
    from oaknut.dfs.formats import ACORN_DFS_80T_SINGLE_SIDED

    disc_filepath.parent.mkdir(parents=True, exist_ok=True)
    disc_filepath.unlink(missing_ok=True)
    with DFS.create_file(disc_filepath, ACORN_DFS_80T_SINGLE_SIDED, title=title, boot_option=boot_option) as dfs:
        for disc_file, source_filepath in files:
            dfs.path(f"$.{disc_file.name}").write_bytes(
                source_filepath.read_bytes(),
                load_address=disc_file.load_address,
                exec_address=disc_file.exec_address,
            )


def build() -> list[Path]:
    return [build_original()]


def main() -> None:
    try:
        disc_filepaths = build()
    except (RuntimeError, FileNotFoundError) as e:
        print(e, file=sys.stderr)
        sys.exit(1)
    for disc_filepath in disc_filepaths:
        print(f"Built {disc_filepath.relative_to(PROJECT_DIRPATH)}")


if __name__ == "__main__":
    main()
