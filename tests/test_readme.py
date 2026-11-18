"""README.md is README.md.j2 rendered (tools/dunjunz_revised/generate_readme.py).

An edit made to README.md instead of the template, or a change to what the
template is filled with, such as the keyboard layouts, without a build,
fails here: run uv run dr-readme (or dr-build) and commit both.
"""

from __future__ import annotations

from dunjunz_revised.generate_readme import README_FILEPATH, readme_markdown
from dunjunz_revised.key_layouts import LAYOUTS, markdown_name


def test_the_readme_is_the_template_rendered():
    assert README_FILEPATH.read_text() == readme_markdown()


def test_the_readme_shows_every_layout():
    text = README_FILEPATH.read_text()
    for players, sets in LAYOUTS.items():
        for number, keys in enumerate(sets, 1):
            row = " | ".join([f"KEY{number}"] + [markdown_name(keys[action])
                             for action in ("up", "down", "left", "right", "fire", "magic")])
            assert f"| {row} |" in text, (players, number)
