"""The keyboard layouts: the keys each player sharing the keyboard plays with.

The title asks how many players share the keyboard (1-4); the layout for that
many has one set of keys for each, and each set joins the hero menu by its
fire key, taking whichever hero its player chooses. Every set has a magic
key, used only when its hero is the Ranger or the Magic-User. The 4-player
layout is the 1987 keys, each 1987 hero's set, with magic added for the
Barbarian's and the Fighter's. The design and the reasons for each layout
are in docs/enhancements.md.

This is the one place the layouts are written. The build writes them into
asm/defs/key_layouts.asm, as beebasm macros that emit them as tables, for
the hero menu (the fire keys) and Setup (the whole sets); keys are named by
their inkey_key_ constants in asm/defs/constants.asm.
"""

from __future__ import annotations

from pathlib import Path

ACTIONS = ("up", "down", "left", "right", "fire", "magic")
MAX_PLAYERS = 4
# Setup copies a set into the hero's key slots, whose tables lie in this order in
# the workspace (hero_key_up to hero_key_fire), then the magic key.
SLOT_ORDER = ("up", "down", "right", "left", "fire", "magic")


def key_set(up: str, down: str, left: str, right: str, fire: str, magic: str) -> dict[str, str]:
    return dict(up=up, down=down, left=left, right=right, fire=fire, magic=magic)


RANGER_1987 = key_set("caps_lock", "shift_lock", "shift", "z", "tab", "ctrl")
MAGIC_USER_1987 = key_set("right", "up", "delete", "copy", "down", "return")
BARBARIAN_1987 = key_set("k", "comma", "full_stop", "slash", "space", "l")
FIGHTER_1987 = key_set("g", "b", "u", "i", "o", "j")

LAYOUTS: dict[int, tuple[dict[str, str], ...]] = {
    1: (key_set("k", "m", "z", "x", "l", "space"),),
    2: (key_set("r", "d", "a", "s", "t", "c"),
        key_set("k", "m", "b", "n", "semicolon", "space")),
    3: (MAGIC_USER_1987, BARBARIAN_1987, FIGHTER_1987),
    4: (RANGER_1987, MAGIC_USER_1987, BARBARIAN_1987, FIGHTER_1987),
}
# Keys the hero menu reads for itself, which no set may fire with.
MENU_KEYS = ("return", "5", "6")

LAYOUTS_ASM_FILEPATH = Path(__file__).resolve().parents[2] / "asm" / "defs" / "key_layouts.asm"


PLAYER_COUNT_NAMES = {1: "One player", 2: "Two players", 3: "Three players", 4: "Four players"}
ARROWS = {"up": "↑", "down": "↓", "left": "←", "right": "→"}


def display_name(key: str) -> str:
    """A key as the keyboard labels it, for the disc's README (MODE 7 has no
    arrows): CAPS LOCK, CURSOR UP, ;."""
    from dunjunz_revised.disc_files import key_name
    return key_name(key)


def markdown_name(key: str) -> str:
    """A key as the keyboard labels it, for README.md: the cursor keys as
    arrows."""
    return ARROWS.get(key, display_name(key))


def named_layouts(name=display_name) -> list[dict]:
    """Each layout, its sets' keys named by name: [{players, title, sets:
    [{action: name}]}], for the READMEs."""
    return [dict(players=players, title=PLAYER_COUNT_NAMES[players],
                 sets=[{action: name(keys[action]) for action in ACTIONS} for keys in LAYOUTS[players]])
            for players in sorted(LAYOUTS)]


def constant(key: str) -> str:
    return f"inkey_key_{key}"


def layouts_asm() -> str:
    """asm/defs/key_layouts.asm: macros that emit the layouts as the menu's and
    Setup's tables."""
    fire_rows = []
    for set_index in range(MAX_PLAYERS):
        entries = [constant(LAYOUTS[players][set_index]["fire"]) if set_index < players else "0"
                   for players in range(1, MAX_PLAYERS + 1)]
        fire_rows.append(f"    equb {', '.join(entries)}  ; Set {set_index + 1}, in the layouts for 1-4 players")
    set_rows = []
    for players in range(1, MAX_PLAYERS + 1):
        for set_index in range(MAX_PLAYERS):
            if set_index < players:
                keys = LAYOUTS[players][set_index]
                entries = [constant(keys[action]) for action in SLOT_ORDER]
                note = f"{players} player{'s' if players > 1 else ''}, set {set_index + 1}"
            else:
                entries = ["0"] * len(SLOT_ORDER)
                note = f"{players} player{'s' if players > 1 else ''}: no set {set_index + 1}"
            set_rows.append(f"    equb {', '.join(entries)}  ; {note}")
    return "\n".join([
        "; ***************************************************************************************",
        "; The keyboard layouts",
        ";",
        "; Written by tools/dunjunz_revised/key_layouts.py, where the layouts are kept; do not edit.",
        "; Each macro emits one table, where it is used.",
        "",
        "; The fire key of set S (0-3) of the layout for N players (1-4), at 4 S + N - 1; 0 where",
        "; the layout has no set S. The hero menu polls these (poll_key_sets).",
        "MACRO KEY_LAYOUT_FIRE_KEYS",
        *fire_rows,
        "ENDMACRO",
        "",
        "; Set S (0-3) of the layout for N players (1-4), at 6 (4 (N - 1) + S): the up, down,",
        "; right, left and fire keys, in the order of the hero key tables (hero_key_up to",
        "; hero_key_fire), then magic; 0s where the layout has no set S. Setup copies a hero's",
        "; set into their slots (apply_key_sets).",
        f"KEY_SET_BYTES = {len(SLOT_ORDER)}",
        "MACRO KEY_LAYOUT_SETS",
        *set_rows,
        "ENDMACRO",
        "",
    ])


def write_layouts_asm() -> None:
    text = layouts_asm()
    if not LAYOUTS_ASM_FILEPATH.exists() or LAYOUTS_ASM_FILEPATH.read_text() != text:
        LAYOUTS_ASM_FILEPATH.write_text(text)
