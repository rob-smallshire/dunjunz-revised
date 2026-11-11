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
  own tables, so they cannot drift), and the copyright message from the
  repository's README.md.

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
    words = inkey_name.replace("full_stop", ".").replace("comma", ",").replace("slash", "/")
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
    match = re.search(r"^## Credits and copyright\n(.*?)(?=^## |\Z)", readme_markdown, re.M | re.S)
    if match is None:
        raise ValueError("README.md has no Credits and copyright section")
    return match.group(1).strip().replace("*", "").replace("©", "(c)")


def wrap(paragraphs: list[str], width: int = README_WIDTH) -> list[str]:
    lines = []
    for paragraph in paragraphs:
        lines += textwrap.wrap(" ".join(paragraph.split()), width) + [""]
    return lines


def readme_text(hero_keys: list[tuple[str, dict[str, str]]], copyright: str,
                version: str = __version__) -> str:
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
    lines += ["THE HERO MENU", ""]
    lines += wrap([
        "Keys 1-4 switch a hero in or out. Fire on a joystick joins with "
        "that stick; pressing it again moves the stick on to the next hero. "
        "5 and 6 turn the sound on and off. SPACE starts the game.",
    ])
    lines += ["KEYS", ""]
    lines += hero_key_lines(hero_keys) + [""]
    lines += wrap([
        "Only the Ranger and the Magic-User cast magic. P pauses and "
        "resumes. Hold ESCAPE for half a second to end the game.",
    ])
    lines += ["JOYSTICKS", ""]
    lines += wrap([
        "With SPItFIRE on a Master Compact, up to four sticks; otherwise two "
        "on the analogue port, or a Compact's own joystick port. A hero on "
        "a stick can still use their keys. Hold fire and a direction "
        "together for half a second to cast magic.",
    ])
    lines += ["COPYRIGHT", ""]
    lines += wrap(copyright.split("\n\n"))
    lines += ["Report problems at"] + url_lines()
    for line in lines:
        if len(line) > README_WIDTH:
            raise ValueError(f"README line longer than {README_WIDTH}: {line!r}")
    return "\n".join(lines) + "\n"
