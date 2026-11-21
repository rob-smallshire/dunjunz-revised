"""README.md is README.md.j2 rendered (tools/dunjunz_revised/generate_readme.py).

An edit made to README.md instead of the template, or a change to what the
template is filled with, such as the keyboard layouts, without a build,
fails here: run uv run dr-readme (or dr-build) and commit both.
"""

from __future__ import annotations

from dunjunz_revised.generate_readme import README_FILEPATH, readme_markdown
from dunjunz_revised.key_layouts import LAYOUTS, markdown_name
from dunjunz_revised.readme_screenshots import HERO_MENU_PNG_FILEPATH, key_page_png_filepath


def test_the_readme_is_the_template_rendered():
    assert README_FILEPATH.read_text() == readme_markdown()


def test_the_readme_shows_every_layout():
    """Each layout's page of keys, its keys spelt out in the screenshot's alt text."""
    text = README_FILEPATH.read_text()
    for players, sets in LAYOUTS.items():
        assert key_page_png_filepath(players).exists(), players
        assert f'src="docs/{key_page_png_filepath(players).name}"' in text, players
        for number, keys in enumerate(sets, 1):
            spelt = ", ".join(f"{action} {markdown_name(keys[action])}"
                              for action in ("up", "down", "left", "right", "fire", "magic"))
            assert f"KEY{number}: {spelt}." in text, (players, number)


def test_the_readme_shows_the_hero_menu():
    assert HERO_MENU_PNG_FILEPATH.exists()
    assert f'src="docs/{HERO_MENU_PNG_FILEPATH.name}"' in README_FILEPATH.read_text()
