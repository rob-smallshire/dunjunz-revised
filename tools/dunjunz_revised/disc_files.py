"""The names, titles and README that say which version a disc holds.

Every one is derived from the version (_version.py, kept by
bump-my-version), so someone with only the image file, or only a *CAT on
the machine, can tell which version it is:

- the images are named for it: dunjunz-revised-v2026.1.ssd (DFS) and
  dunjunz-revised-v2026.1.adl (ADFS);
- the disc titles carry it. A DFS title holds 12 characters, so the name
  is shortened step by step until name and version fit ("DUNJNZ2026.1",
  then "DNJNZ2026.12" from 2026.10). An ADFS root title holds 19, which
  ADFS's *CAT shows first ("Dunjunz Rev 2026.1"). With no room at all a
  ValueError is raised, never a silent truncation;
- the disc carries a README, which *TYPE shows: the version, the project's
  address, how to start and play the game (the keys read from the game's
  own tables, so they cannot drift), and the instructions ("How to play")
  and the copyright message from the repository's README.md.

There is no separate version file or LICENSE on the disc. A DFS catalogue
holds 31 files, and the game's 30 (!BOOT, Dunjunz, Screen, GAME, Setup and
Level1-25) leave room for the README alone. The version is in the titles,
and the copyright message is in the README (the repository has no licence:
see README.md).
"""

from __future__ import annotations

import re
import textwrap

import oaknut.codecs  # noqa: F401  (registers the "acorn" codec)

from dunjunz_revised._version import __version__

DISC_STEM = "dunjunz-revised"
GAME_NAME = "Dunjunz Revised"
PROJECT_URL = "https://github.com/rob-smallshire/dunjunz-revised"

DFS_TITLE_LIMIT = 12
ADFS_TITLE_LIMIT = 19
# Name forms, tried in order with the version after them until one fits.
DFS_TITLE_NAMES = ("DUNJUNZ ", "DUNJUNZ", "DUNJNZ", "DNJNZ")
ADFS_TITLE_NAMES = ("Dunjunz Revised ", "Dunjunz Rev ", "Dunjunz ")

README_FILENAME = "README"
README_WIDTH = 39               # a MODE 7 *TYPE never wraps
DFS_CATALOGUE_LIMIT = 31


def disc_filename(suffix: str, version: str = __version__) -> str:
    """The image's filename: dunjunz-revised-v2026.1.ssd for ".ssd"."""
    return f"{DISC_STEM}-v{version}{suffix}"


def _title(names: tuple[str, ...], limit: int, version: str) -> str:
    for name in names:
        title = f"{name}{version}"
        if len(title) <= limit:
            return title
    raise ValueError(f"no title of at most {limit} characters holds version {version}")


def dfs_title(version: str = __version__) -> str:
    """The DFS disc title, at most 12 characters: "DUNJNZ2026.1"."""
    return _title(DFS_TITLE_NAMES, DFS_TITLE_LIMIT, version)


def adfs_title(version: str = __version__) -> str:
    """The ADFS root title, at most 19 characters: "Dunjunz Rev 2026.1"."""
    return _title(ADFS_TITLE_NAMES, ADFS_TITLE_LIMIT, version)


def acorn_text(text: str) -> bytes:
    """Text as the BBC Micro's *TYPE wants it: Acorn characters, each line
    ended by a carriage return."""
    return text.replace("\n", "\r").encode("acorn")


def url_lines(url: str = PROJECT_URL, width: int = README_WIDTH) -> list[str]:
    """The URL on as few lines as fit the width, broken after a slash."""
    lines = [""]
    for part in re.findall(r"[^/]*/|[^/]+$", url):
        if lines[-1] and len(lines[-1]) + len(part) > width:
            lines.append("")
        lines[-1] += part
    if any(len(line) > width for line in lines):
        raise ValueError(f"{url} has a part too long for {width} columns")
    return lines


def key_name(inkey_name: str) -> str:
    """A key's name as on the keyboard, from its inkey_key_ constant's:
    caps_lock is CAPS LOCK, right is the cursor key."""
    words = (inkey_name.replace("full_stop", ".").replace("semicolon", ";")
             .replace("comma", ",").replace("slash", "/"))
    if words in ("up", "down", "left", "right"):
        return f"CURSOR {words.upper()}"
    return words.replace("_", " ").upper()


def hero_key_lines(hero_keys: list[tuple[str, dict[str, str]]]) -> list[str]:
    """Each hero's keys, two to a line: hero_keys is (hero, {action: key})."""
    lines = []
    for hero, keys in hero_keys:
        lines.append(f"{hero}:")
        pairs = [f"{action} {key}" for action, key in keys.items()]
        for left, right in zip(pairs[::2], pairs[1::2] + [""]):
            lines.append(f"  {left:<18}{right}".rstrip())
    return lines


def copyright_text(readme_markdown: str) -> str:
    """The repository README's "Credits and copyright" section, as plain
    text: no Markdown emphasis, and (c) for the copyright sign, which MODE 7
    cannot show."""
    return markdown_section(readme_markdown, "Credits and copyright").replace("*", "").replace("©", "(c)")


def markdown_section(readme_markdown: str, heading: str) -> str:
    """A "## heading" section of the repository README, without its heading."""
    match = re.search(rf"^## {re.escape(heading)}\n(.*?)(?=^## |\Z)", readme_markdown, re.M | re.S)
    if match is None:
        raise ValueError(f"README.md has no {heading} section")
    return match.group(1).strip()


# How each README table in "How to play" reads on the disc, one entry a row: the tables
# are too wide for 39 columns. Keyed by the table's header row.
TABLE_ROWS = {
    ("Hero", "Weapon", "In flight", "Damage", "Armour", "Magic"):
        lambda hero, weapon, flight, damage, armour, magic:
            f"{hero}: {weapon}, {flight} in flight, damage {damage}, armour {armour}, "
            + ("no magic." if magic == "none" else f"magic {magic}."),
    ("Object", "What it does", "Points"):
        lambda thing, does, points:
            " ".join(part for part in (f"{thing}:", f"{does}." if does else "",
                                       f"{points} points." if points.isdigit() else
                                       f"Scores {points}." if points else "") if part),
}


def table_rows(block: str) -> list[str]:
    """A Markdown table as one entry a row, as TABLE_ROWS has it."""
    rows = [[cell.strip() for cell in line.strip().strip("|").split("|")] for line in block.splitlines()]
    header, rule, *rows = rows
    if not all(set(cell) <= {"-", ":"} for cell in rule):
        raise ValueError(f"not a Markdown table: {block!r}")
    try:
        row_text = TABLE_ROWS[tuple(header)]
    except KeyError:
        raise ValueError(f"no disc form for the README table {header}") from None
    return [row_text(*row) for row in rows]


def how_to_play_lines(readme_markdown: str, width: int = README_WIDTH) -> list[str]:
    """The repository README's "How to play" section as plain text: each
    subheading in capitals, emphasis in quotes, paragraphs wrapped, and
    each row of a table an entry whose further lines are indented."""
    lines = []
    for block in re.split(r"\n\s*\n", markdown_section(readme_markdown, "How to play")):
        block = re.sub(r"\*(.+?)\*", r'"\1"', block.strip())    # emphasis, as quotes
        if re.search(r"`|\]\(|<|_", block):
            raise ValueError(f"Markdown the disc README cannot show: {block!r}")
        if block.startswith("### "):
            lines += [block[4:].upper(), ""]
        elif block.startswith("|"):
            for entry in table_rows(block):
                lines += textwrap.wrap(entry, width, subsequent_indent="  ", break_on_hyphens=False)
            lines += [""]
        else:
            lines += wrap([block], width)
    return lines


def wrap(paragraphs: list[str], width: int = README_WIDTH) -> list[str]:
    lines = []
    for paragraph in paragraphs:
        lines += textwrap.wrap(" ".join(paragraph.split()), width, break_on_hyphens=False) + [""]
    return lines


def readme_text(layouts: list[dict], how_to_play: list[str], copyright: str, version: str = __version__) -> str:
    """The disc's README, every line at most README_WIDTH characters."""
    lines = [f"{GAME_NAME} {version}", ""]
    lines += wrap([
        "A revised version of Dunjunz, the four-player dungeon game by Julian "
        "Avis, published by Bug-Byte for the BBC Micro in 1986 and 1987.",
    ])
    lines += url_lines() + [""]
    lines += ["STARTING", ""]
    lines += wrap([
        "SHIFT-BREAK boots this disc. On another filing system (a network "
        "file server too), copy its files and *RUN DUNJUNZ. The game needs "
        "PAGE at &1C00 or lower. The ADFS disc is for a Master or a Master "
        "Compact.",
    ])
    lines += ["THE TITLE", ""]
    lines += wrap([
        "Press 1-4 for the number of players sharing the keyboard, or fire "
        "on a joystick if everyone plays with a stick. Any other key gives "
        "four, with the 1987 keys. Each player at the keyboard has a set of "
        "keys, KEY1 to KEY4, from the layout for that many players, shown "
        "before the game loads.",
    ])
    lines += ["THE HERO MENU", ""]
    lines += wrap([
        "Every player joins by pressing fire, on their joystick or their set "
        "of keys. A press takes the first free hero, and each further press "
        "the next, past the Fighter to nobody. 5 and 6 turn the sound on and "
        "off. RETURN starts the game.",
    ])
    lines += ["KEYS", ""]
    for layout in layouts:
        lines += [f"{layout['title'].upper()}:"]
        lines += hero_key_lines([(f"KEY{n}", keys) for n, keys in enumerate(layout["sets"], 1)]) + [""]
    lines += wrap([
        "With four players the keys are the 1987 heroes': KEY1 the "
        "Ranger's, KEY2 the Magic-User's, KEY3 the Barbarian's and KEY4 the "
        "Fighter's. Only the Ranger and the Magic-User cast magic. P pauses "
        "and resumes. Hold ESCAPE for half a second to end the game.",
        "When the game ends, R plays again with the same heroes and keys: "
        "within ten seconds of game over, or after the ending. Any other key "
        "goes back to the title.",
    ])
    lines += ["JOYSTICKS", ""]
    lines += wrap([
        "With SPItFIRE on a Master Compact, up to four sticks; otherwise two "
        "on the analogue port, or a Compact's own joystick port. A hero on "
        "a stick plays with the stick alone. Hold fire and a direction "
        "together for half a second to cast magic.",
    ])
    lines += ["HOW TO PLAY", "=" * len("HOW TO PLAY"), ""] + how_to_play    # over its own headings
    lines += ["COPYRIGHT", ""]
    lines += wrap(copyright.split("\n\n"))
    lines += ["Report problems at"] + url_lines()
    for line in lines:
        if len(line) > README_WIDTH:
            raise ValueError(f"README line longer than {README_WIDTH}: {line!r}")
    return "\n".join(lines) + "\n"
