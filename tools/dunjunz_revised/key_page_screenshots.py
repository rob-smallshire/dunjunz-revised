"""Screenshots of the title's page of keys, for the README.

For each number of keyboard players, boot the revised disc in beebium,
choose it on the title, and capture the page of keys that follows, with two
of the banner's stars caught mid-twinkle: docs/key-page-N.png. Run after a
build, whenever the layouts or the page change (`uv run dr-key-pages`).
"""

from __future__ import annotations

from pathlib import Path

from dunjunz_revised.build import REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.key_layouts import LAYOUTS
from dunjunz_revised.lockstep import inkey_to_matrix
from dunjunz_revised.machines import MACHINES, launched

PROJECT_DIRPATH = Path(__file__).resolve().parents[2]
DOCS_DIRPATH = PROJECT_DIRPATH / "docs"
PLAYERS_KEYS = {1: 0xCF, 2: 0xCE, 3: 0xEE, 4: 0xED}          # INKEY numbers of 1-4
# Each star site's count of ticks when the page is printed, so that the first tick after
# shows the star left of the D at its largest and the one under the first un growing.
STAR_COUNTS = (2, 0, 30, 30, 30)
VIDEO_FRAME_SECONDS = 0.025         # less than a tick: the drawn stars reach the screen


def key_page_png_filepath(players: int) -> Path:
    return DOCS_DIRPATH / f"key-page-{players}.png"


def capture_key_page(players: int, png_filepath: Path) -> None:
    labels = read_labels(REVISED_BUILD_DIRPATH, "title")
    with launched(MACHINES["dfs226"]) as bbc:
        bbc.boot_disc(REVISED_DISC_FILEPATH)
        bbc.debugger.run_to(labels["twinkle_loop"], timeout=120)
        bbc.debugger.run()
        key = inkey_to_matrix(PLAYERS_KEYS[players])
        bbc.keyboard.matrix_down(*key)
        bbc.debugger.run_to(labels["keys_printed"], timeout=60)
        bbc.keyboard.matrix_up(*key)
        bbc.memory.address.bus.write(labels["star_counts"], bytes(STAR_COUNTS))
        bbc.debugger.run_to(labels["twinkle_stars_7"], timeout=10)
        bbc.debugger.run_to(labels["wait_for_page_key"], timeout=10)
        bbc.run_for_emulated_seconds(VIDEO_FRAME_SECONDS)
        bbc.video.capture_frame().save_png(png_filepath)


def main() -> None:
    for players in sorted(LAYOUTS):
        png_filepath = key_page_png_filepath(players)
        capture_key_page(players, png_filepath)
        print(f"Wrote {png_filepath.relative_to(PROJECT_DIRPATH)}")


if __name__ == "__main__":
    main()
