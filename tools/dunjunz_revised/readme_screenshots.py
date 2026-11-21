"""Screenshots of the game for the README.

- The title's page of keys, for each number of keyboard players: boot the
  revised disc in beebium, choose it on the title, and capture the page
  that follows, with two of the banner's stars caught mid-twinkle:
  docs/key-page-N.png.
- The hero menu, with two keyboard players and two joysticks playing:
  docs/hero-menu.png. The keyboard players join by their fire keys, as
  players do. Beebium has no joystick, so the sticks' heroes are set in the
  menu's state, which 5 (sound on) then reprints.
- The game in play: four heroes on the 1987 keys, played by lockstep's
  scripted random walk, with the game's randomness pinned, so that every
  run gives the same picture: docs/in-play.png.

Run after a build, whenever the layouts, the page or the menu change
(`uv run dr-screenshots`).
"""

from __future__ import annotations

import re
from pathlib import Path

from dunjunz_revised.build import ASM_DIRPATH, REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH, read_labels
from dunjunz_revised.key_layouts import LAYOUTS
from dunjunz_revised.lockstep import Script, answer_title, game_run, hold_key, inkey_to_matrix
from dunjunz_revised.machines import MACHINES, launched

PROJECT_DIRPATH = Path(__file__).resolve().parents[2]
DOCS_DIRPATH = PROJECT_DIRPATH / "docs"
HERO_MENU_PNG_FILEPATH = DOCS_DIRPATH / "hero-menu.png"
IN_PLAY_PNG_FILEPATH = DOCS_DIRPATH / "in-play.png"
# The frame of scripted play shown: the heroes apart in four rooms, a key and a door in one.
IN_PLAY_SEED, IN_PLAY_FRAMES = 1, 150
GAME_RANGES = ((0x0400, 0x3000), (0x6E80, 0x8000))     # where lockstep pins the randomness
INKEY = {name: int(value, 16) for name, value in
         re.findall(r"^inkey_key_(\w+)\s*=\s*&([0-9a-f]{2})", (ASM_DIRPATH / "defs" / "constants.asm").read_text(), re.M)}
PLAYERS_KEYS = {1: 0xCF, 2: 0xCE, 3: 0xEE, 4: 0xED}          # INKEY numbers of 1-4
FIVE = inkey_to_matrix(0xEC)        # 5, INKEY -20: sound on, which reprints the menu
# Each star site's count of ticks when the page is printed, so that the first tick after
# shows the star left of the D at its largest and the one under the first un growing.
STAR_COUNTS = (2, 0, 30, 30, 30)
VIDEO_FRAME_SECONDS = 0.025         # less than a tick: the drawn stars reach the screen
HERO_ABSENT = 0x08B4
# The hero menu: the Ranger and the Magic-User join with the 2-player layout's sets of
# keys, KEY1 and KEY2; the Barbarian and the Fighter play with sticks 0 and 1, JOY1 and JOY2.
MENU_KEYBOARD_PLAYERS = 2
MENU_STICKS = {2: 0, 3: 1}          # hero: stick
# The menu's MODE 2 pixels are four times as wide as they are high, as on the screen.
PIXEL_WIDTH, PIXEL_HEIGHT = 4, 2


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


def capture_hero_menu(png_filepath: Path) -> None:
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    with launched(MACHINES["dfs226"]) as bbc:
        bbc.boot_disc(REVISED_DISC_FILEPATH)
        bbc.run_for_emulated_seconds(8)
        answer_title(bbc, inkey_to_matrix(PLAYERS_KEYS[MENU_KEYBOARD_PLAYERS]))
        bbc.debugger.run_to(labels["menu_key_loop"], timeout=120)
        bbc.run_for_emulated_seconds(0.5)
        for hero, keys in enumerate(LAYOUTS[MENU_KEYBOARD_PLAYERS]):
            fire = inkey_to_matrix(INKEY[keys["fire"]])
            bbc.keyboard.matrix_down(*fire)
            for _ in range(30):                 # held until the hero joins, as a reprint can miss a tap
                bbc.run_for_emulated_seconds(0.1)
                if bbc.memory.address.peek[HERO_ABSENT + hero] == 0:
                    break
            else:
                raise RuntimeError(f"hero {hero} never joined the menu")
            bbc.keyboard.matrix_up(*fire)
            bbc.run_for_emulated_seconds(0.3)
        for hero, stick in MENU_STICKS.items():
            bbc.memory.address.bus.write(labels["hero_stick"] + hero, bytes([stick]))
            bbc.memory.address.bus.write(HERO_ABSENT + hero, bytes([0]))
        hold_key(bbc, *FIVE)
        bbc.run_for_emulated_seconds(0.5)
        image = bbc.video.capture_frame().to_pil_image().convert("RGB")
    stretched(image).save(png_filepath)


def stretched(image):
    """A MODE 2 capture at the screen's proportions."""
    from PIL import Image
    return image.resize((image.width * PIXEL_WIDTH, image.height * PIXEL_HEIGHT), Image.NEAREST)


def capture_in_play(png_filepath: Path) -> None:
    labels = read_labels(REVISED_BUILD_DIRPATH, "dunjunz")
    script = Script(seed=IN_PLAY_SEED)
    with game_run(REVISED_DISC_FILEPATH, labels, GAME_RANGES) as run:
        for frame in range(IN_PLAY_FRAMES + 1):
            if not run.next_frame(script.keys_for(frame)):
                raise RuntimeError(f"the game ended at frame {frame}")
        run.bbc.run_for_emulated_seconds(0.02)          # the frame drawn reaches the screen
        stretched(run.bbc.video.capture_frame().to_pil_image().convert("RGB")).save(png_filepath)


def main() -> None:
    for players in sorted(LAYOUTS):
        png_filepath = key_page_png_filepath(players)
        capture_key_page(players, png_filepath)
        print(f"Wrote {png_filepath.relative_to(PROJECT_DIRPATH)}")
    capture_hero_menu(HERO_MENU_PNG_FILEPATH)
    print(f"Wrote {HERO_MENU_PNG_FILEPATH.relative_to(PROJECT_DIRPATH)}")
    capture_in_play(IN_PLAY_PNG_FILEPATH)
    print(f"Wrote {IN_PLAY_PNG_FILEPATH.relative_to(PROJECT_DIRPATH)}")


if __name__ == "__main__":
    main()
