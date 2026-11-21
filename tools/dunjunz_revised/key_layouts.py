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

from dunjunz_revised.key_page_banner import BANNER_ROWS
from dunjunz_revised.page_text import text_bytes_asm

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


# The title's page of each layout's keys, in MODE 7 (40 columns, 25 rows), below the
# banner (key_page_banner.py). A teletext colour code takes a character cell, shown as
# a space, and colours the rest of its row, up to the next code; each row starts white.
TITLE_TEXTS_ASM_FILEPATH = LAYOUTS_ASM_FILEPATH.with_name("key_layout_texts.asm")
MODE_7_WIDTH = 40
MODE_7_ROWS = 25
TELETEXT_GREEN, TELETEXT_YELLOW, TELETEXT_WHITE = 0x82, 0x83, 0x87
HEADING_INDENT = 8                  # spaces before the header's colour code, clear of the banner
ACTION_COLOUR, KEY_COLOUR = TELETEXT_GREEN, TELETEXT_WHITE
# Each set's keys as they lie on the page: left beside right, and up over fire over
# down beside them, so that the directions sit as they point.
PAGE_ROWS = (("left", "right"), ("up", "fire"), ("down", "magic"))


def column_widths() -> tuple[int, int, int, int]:
    """The widths of the page's columns of actions and keys, left then right,
    the same in every layout."""
    keys = [keys for layout in LAYOUTS.values() for keys in layout]
    return (max(len(left) for left, _ in PAGE_ROWS),
            max(len(display_name(k[left])) for k in keys for left, _ in PAGE_ROWS),
            max(len(right) for _, right in PAGE_ROWS),
            max(len(display_name(k[right])) for k in keys for _, right in PAGE_ROWS))


def set_gaps(sets: int) -> list[int]:
    """The blank rows above, between and below the sets on the page, so that
    however many there are they spread over the rows between the header and
    the prompt: as even as can be, any rows over going between the sets
    first, then below them."""
    spare = MODE_7_ROWS - BANNER_ROWS - 2 - sets * len(PAGE_ROWS)    # less the header and prompt
    gaps = [spare // (sets + 1)] * (sets + 1)
    for index in [*range(1, sets), sets, 0][:spare % (sets + 1)]:
        gaps[index] += 1
    return gaps


def title_lines(players: int) -> list[str]:
    """The title's page of the keys for this many players, under the banner: its
    lines, teletext colour codes in them as characters, filling the screen. The
    header comes straight under the banner, indented clear of its graphics, the
    prompt, centred, is on the bottom row, and the sets spread out
    between (set_gaps). Each set's heading, in white (the colour
    a row starts in, so needing no code), begins its first row; then come
    columns of actions in ACTION_COLOUR and keys in KEY_COLOUR, each colour code
    standing in for the space before. The widest row, the Magic-User's cursor
    keys, fills all 40 columns."""
    action_width, key_width, right_action_width, _ = column_widths()
    gaps = set_gaps(players)
    lines = [" " * HEADING_INDENT + chr(TELETEXT_YELLOW) + f"{PLAYER_COUNT_NAMES[players].upper()} AT THE KEYBOARD"]
    lines += [""] * gaps[0]
    for number, keys in enumerate(LAYOUTS[players], 1):
        for row, (left, right) in enumerate(PAGE_ROWS):
            heading = f"KEY{number}" if row == 0 else " " * len(f"KEY{number}")
            lines.append(heading
                         + chr(ACTION_COLOUR) + f"{left:<{action_width}}"
                         + chr(KEY_COLOUR) + f"{display_name(keys[left]):<{key_width}}"
                         + chr(ACTION_COLOUR) + f"{right:<{right_action_width}}"
                         + chr(KEY_COLOUR) + display_name(keys[right]))
        lines += [""] * gaps[number]
    prompt = chr(TELETEXT_YELLOW) + "Press any key"
    lines.append(f"{prompt:^{MODE_7_WIDTH}}".rstrip())
    return lines


def text_asm(line: str, last: bool = False) -> str:
    """A line for print_text as beebasm (page_text.py): its codes and text, then
    a carriage return, unless the line fills the row, after which the cursor is
    already at the start of the next, or is the last of the page, whose carriage
    return would scroll it."""
    return text_bytes_asm(line.encode("latin-1") + (b"\r" if len(line) < MODE_7_WIDTH and not last else b""))


def title_texts_asm() -> str:
    """asm/defs/key_layout_texts.asm: each layout's page of keys for the title,
    zero-terminated text for OSASCI, and tables of where each page starts."""
    out = [
        "; ***************************************************************************************",
        "; The keyboard layouts, as the title shows them",
        ";",
        "; Written by tools/dunjunz_revised/key_layouts.py, where the layouts are kept; do not edit.",
        "; For N players (1-4), key_layout_texts_lo and _hi + N - 1 point at the page of keys the",
        "; title prints in MODE 7 under the banner (show_keys), for print_text (runs of spaces",
        "; as their lengths): teletext colour codes and text,",
        "; lines ended by carriage returns (OSASCI starts each new line), except a full row and",
        "; the last, which fills the screen's last row; the page ended by a zero.",
        ".key_layout_texts_lo",
        "    equb " + ", ".join(f"<key_layout_text_{n}" for n in sorted(LAYOUTS)),
        ".key_layout_texts_hi",
        "    equb " + ", ".join(f">key_layout_text_{n}" for n in sorted(LAYOUTS)),
    ]
    for players in sorted(LAYOUTS):
        lines = title_lines(players)
        assert BANNER_ROWS + len(lines) == MODE_7_ROWS, players
        out.append(f".key_layout_text_{players}")
        for number, line in enumerate(lines, 1):
            assert len(line) <= MODE_7_WIDTH, line
            assert '"' not in line
            out.append(text_asm(line, last=number == len(lines)))
        out.append("    equb 0")
    return "\n".join(out) + "\n"


def write_layouts_asm() -> None:
    for filepath, text in ((LAYOUTS_ASM_FILEPATH, layouts_asm()), (TITLE_TEXTS_ASM_FILEPATH, title_texts_asm())):
        if not filepath.exists() or filepath.read_text() != text:
            filepath.write_text(text)
