"""Build Dunjunz Revised.

Two stages:

- The baseline. The reassembled 1987 disc release in asm/original/ (taken
  from the acornaeology disassembly) is assembled, every file it saves is
  checked byte-for-byte against the original disc's in reference/disc/, and
  build/dunjunz-original.ssd boots it (it needs DFS 0.90). Its behaviour,
  minus the bugs, is what the revised game must keep.
- The revised game: asm/dunjunz.asm and asm/title.asm, written to
  build/dunjunz-revised.ssd. While REVISED_MUST_MATCH_ORIGINAL is set, the
  revised sources are still a rearrangement of the original and must
  assemble to the same bytes.

The revised sources INCLUDE each other by paths from the project root, so
beebasm runs there, and their SAVEs go into a disc image (-do) rather than
into the working directory; the files are read back out of it.

    uv run dr-build
"""

from __future__ import annotations

import ast
import hashlib
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

from dunjunz_revised._version import __version__

PROJECT_DIRPATH = Path(__file__).resolve().parents[2]
ASM_DIRPATH = PROJECT_DIRPATH / "asm"
ORIGINAL_ASM_DIRPATH = ASM_DIRPATH / "original"
REFERENCE_DIRPATH = PROJECT_DIRPATH / "reference" / "disc"
BUILD_DIRPATH = PROJECT_DIRPATH / "build"
ORIGINAL_BUILD_DIRPATH = BUILD_DIRPATH / "original"
ORIGINAL_DISC_FILEPATH = BUILD_DIRPATH / "dunjunz-original.ssd"

REVISED_BUILD_DIRPATH = BUILD_DIRPATH / "revised"
REVISED_DISC_FILEPATH = BUILD_DIRPATH / "dunjunz-revised.ssd"

ORIGINAL_DISC_TITLE = "DUNJUNZ 1987"


def disc_title(version: str) -> str:
    """A DFS title (at most 12 characters) for a version: 2026.1 gives
    "DUNJUNZ 26.1". The full name is on the title screen and in !BOOT."""
    year, n = version.split(".")
    title = f"DUNJUNZ {int(year) % 100:02d}.{n}"
    assert len(title) <= 12, title
    return title


REVISED_DISC_TITLE = disc_title(__version__)

# The beebasm sources of the revised game and the files each SAVEs.
REVISED_SOURCES = {
    "dunjunz.asm": ("GAME", "Setup"),
    "title.asm": ("Dunjunz",),
}

# Load and exec addresses with &FFFF in the top half load into, and run in, the
# I/O processor when a second processor is present.
IO_PROCESSOR = 0xFFFF0000
REVISED_MUST_MATCH_ORIGINAL = False

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


def parse_labels(text: str) -> dict[str, int]:
    """Parse beebasm's symbol dump, a list of dict literals such as
    [{'start':6400L,...}], into one name-to-address mapping."""
    dump = text[text.index("[{"):text.rindex("}]") + 2]
    scopes = ast.literal_eval(re.sub(r"(\d+)L\b", r"\1", dump))
    return {name: address for scope in scopes for name, address in scope.items()}


def read_labels(build_dirpath: Path, source_stem: str) -> dict[str, int]:
    """The labels of a source as last built into build_dirpath."""
    return parse_labels((build_dirpath / f"{source_stem}.labels").read_text())


def find_beebasm() -> str:
    beebasm = shutil.which("beebasm")
    if beebasm is None:
        raise FileNotFoundError("beebasm not found on PATH")
    return beebasm


def assemble(source_filepath: Path, output_dirpath: Path) -> None:
    """Assemble a source with beebasm, its SAVEd files landing in output_dirpath."""
    output_dirpath.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(
        [find_beebasm(), "-i", str(source_filepath), "-v",
         "-d", "-labels", f"{source_filepath.stem}.labels"],
        cwd=output_dirpath,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"beebasm failed on {source_filepath.name}:\n{result.stdout}\n{result.stderr}")


def assemble_to_disc(source_filepath: Path, saved_filenames: tuple[str, ...], output_dirpath: Path) -> None:
    """Assemble a source from the project root, its SAVEs going to a scratch
    disc image, and copy the saved files out of the image into output_dirpath."""
    from oaknut.dfs.dfs import DFS

    output_dirpath.mkdir(parents=True, exist_ok=True)
    scratch_filepath = output_dirpath / f"{source_filepath.stem}.ssd"
    scratch_filepath.unlink(missing_ok=True)
    result = subprocess.run(
        [find_beebasm(), "-i", str(source_filepath.relative_to(PROJECT_DIRPATH)),
         "-do", str(scratch_filepath.relative_to(PROJECT_DIRPATH)), "-v",
         "-d", "-labels", str((output_dirpath / f"{source_filepath.stem}.labels").relative_to(PROJECT_DIRPATH))],
        cwd=PROJECT_DIRPATH,
        capture_output=True,
        text=True,
    )
    (output_dirpath / f"{source_filepath.stem}.lst").write_text(result.stdout)
    if result.returncode != 0:
        raise RuntimeError(f"beebasm failed on {source_filepath.name}:\n{result.stderr}")
    with DFS.from_file(scratch_filepath) as dfs:
        for saved_filename in saved_filenames:
            (output_dirpath / saved_filename).write_bytes(bytes(dfs.path(f"$.{saved_filename}").read_bytes()))
    scratch_filepath.unlink()


def verify_against_reference(built_dirpath: Path, filenames) -> None:
    for filename in filenames:
        built = (built_dirpath / filename).read_bytes()
        reference = (REFERENCE_DIRPATH / filename).read_bytes()
        if built != reference:
            first = next((i for i, (a, b) in enumerate(zip(built, reference)) if a != b), min(len(built), len(reference)))
            raise RuntimeError(
                f"{filename} does not match the original: first difference at offset &{first:04X} "
                f"({len(built)} bytes built, {len(reference)} original)"
            )


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


LEVEL_FILE_ADDRESS = 0x6B00
LEVEL_FILE_LENGTH = 0x2B0
STONES_LEVEL_25_OFFSET = 0x6B00 - 0x6680    # Stones loads at &6680; level 25 is its end


def decrypt_level(data: bytes) -> bytes:
    """A 1987 level file as the game uses it: each byte XORed with the low
    byte of its address at &6B00."""
    assert len(data) == LEVEL_FILE_LENGTH
    return bytes(b ^ ((LEVEL_FILE_ADDRESS + i) & 0xFF) for i, b in enumerate(data))


def write_revised_levels(output_dirpath: Path) -> list[DiscFile]:
    """Levels 1-25, unencrypted, as LevelN files. Level 25 comes from the end of Stones."""
    files = []
    for n in range(1, 26):
        if n == 25:
            stones = (REFERENCE_DIRPATH / "Stones").read_bytes()
            encrypted = stones[STONES_LEVEL_25_OFFSET:STONES_LEVEL_25_OFFSET + LEVEL_FILE_LENGTH]
        else:
            encrypted = (REFERENCE_DIRPATH / f"Level{n}").read_bytes()
        (output_dirpath / f"Level{n}").write_bytes(decrypt_level(encrypted))
        files.append(DiscFile(f"Level{n}", IO_PROCESSOR | LEVEL_FILE_ADDRESS, IO_PROCESSOR | LEVEL_FILE_ADDRESS))
    return files


def build_revised() -> Path:
    """Assemble the revised game and write its disc."""
    if REVISED_BUILD_DIRPATH.exists():
        shutil.rmtree(REVISED_BUILD_DIRPATH)
    for source_filename, saved_filenames in REVISED_SOURCES.items():
        assemble_to_disc(ASM_DIRPATH / source_filename, saved_filenames, REVISED_BUILD_DIRPATH)
        if REVISED_MUST_MATCH_ORIGINAL:
            verify_against_reference(REVISED_BUILD_DIRPATH, saved_filenames)

    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    title_labels = read_labels(REVISED_BUILD_DIRPATH, "title")
    title = DiscFile("Dunjunz", IO_PROCESSOR | title_labels["dasmos_start"], IO_PROCESSOR | title_labels["title_start"])
    files = [
        (DiscFile("!BOOT", title.load_address, title.exec_address), REVISED_BUILD_DIRPATH / "Dunjunz"),
        (title, REVISED_BUILD_DIRPATH / "Dunjunz"),
        (DiscFile("Screen", IO_PROCESSOR | 0x3280, IO_PROCESSOR | 0x3280), REFERENCE_DIRPATH / "Screen"),
        (DiscFile("GAME", IO_PROCESSOR | labels["game_file_start"], IO_PROCESSOR | labels["startup"]),
         REVISED_BUILD_DIRPATH / "GAME"),
        (DiscFile("Setup", IO_PROCESSOR | labels["setup_start"], IO_PROCESSOR | labels["setup_level"]),
         REVISED_BUILD_DIRPATH / "Setup"),
    ]
    files += [(f, REVISED_BUILD_DIRPATH / f.name) for f in write_revised_levels(REVISED_BUILD_DIRPATH)]
    write_disc(REVISED_DISC_FILEPATH, REVISED_DISC_TITLE, 2, files)
    return REVISED_DISC_FILEPATH


def build() -> list[Path]:
    return [build_original(), build_revised()]


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
