"""Every disc says which version it holds: the images' names, their titles
and the README on them (tools/dunjunz_revised/disc_files.py)."""

from __future__ import annotations

import pytest

from dunjunz_revised._version import __version__
from dunjunz_revised.build import REVISED_ADFS_DISC_FILEPATH, REVISED_BUILD_DIRPATH, REVISED_DISC_FILEPATH
from dunjunz_revised.disc_files import (
    ADFS_TITLE_LIMIT,
    DFS_TITLE_LIMIT,
    PROJECT_URL,
    README_FILENAME,
    README_WIDTH,
    acorn_text,
    adfs_title,
    dfs_title,
    disc_filename,
    readme_text,
    url_lines,
)
from dunjunz_revised.machines import MACHINES, launched

KEYS = [("Ranger", {"up": "CAPS LOCK", "down": "SHIFT LOCK", "magic": "CTRL"}),
        ("Barbarian", {"up": "K", "fire": "SPACE"})]


def test_image_filenames():
    assert disc_filename(".ssd", "2026.1") == "dunjunz-revised-v2026.1.ssd"
    assert disc_filename(".adl", "2027.12") == "dunjunz-revised-v2027.12.adl"


@pytest.mark.parametrize("version, title", [
    ("2026.1", "DUNJNZ2026.1"),
    ("2026.12", "DNJNZ2026.12"),
])
def test_dfs_title_drops_letters_to_fit(version, title):
    assert dfs_title(version) == title
    assert len(title) <= DFS_TITLE_LIMIT


@pytest.mark.parametrize("version, title", [
    ("2026.1", "Dunjunz Rev 2026.1"),
    ("2026.12", "Dunjunz Rev 2026.12"),
    ("2026.123", "Dunjunz 2026.123"),
])
def test_adfs_title_shortens_the_name_to_fit(version, title):
    assert adfs_title(version) == title
    assert len(title) <= ADFS_TITLE_LIMIT


def test_titles_too_long_are_refused():
    with pytest.raises(ValueError):
        dfs_title("2026.123")
    with pytest.raises(ValueError):
        adfs_title("2026.1234567")


def test_acorn_text_ends_lines_with_carriage_returns():
    assert acorn_text("A\nB\n") == b"A\rB\r"


def test_the_url_is_broken_to_fit():
    lines = url_lines()
    assert "".join(lines) == PROJECT_URL
    assert all(len(line) <= README_WIDTH for line in lines)


def test_readme_fits_mode_7_and_says_where_to_report_problems():
    text = readme_text(KEYS, "Copyright (c) someone.", "2026.1")
    lines = text.splitlines()
    assert lines[0] == "Dunjunz Revised 2026.1"
    assert all(len(line) <= README_WIDTH for line in lines)
    assert "".join(url_lines()) in "".join(lines[:12])
    assert "Report problems at" in lines
    assert "".join(lines[-len(url_lines()):]) == PROJECT_URL
    assert "  up CAPS LOCK      down SHIFT LOCK" in lines


def disc_files(image_filepath):
    """{name: bytes} of a built image, DFS or ADFS."""
    if image_filepath.suffix == ".ssd":
        from oaknut.dfs.dfs import DFS
        with DFS.from_file(image_filepath, read_only=True) as dfs:
            return dfs.title, {f.path.split(".", 1)[1]: bytes(f.read_bytes()) for f in (dfs.root / "$").iterdir()}
    from oaknut.adfs import ADFS
    with ADFS.from_file(image_filepath) as adfs:
        return adfs.title, {f.name: bytes(f.read_bytes()) for f in adfs.root.iterdir()}


def test_the_images_carry_the_version_and_the_same_files(disc_filepaths):
    assert REVISED_DISC_FILEPATH.name == disc_filename(".ssd")
    assert REVISED_ADFS_DISC_FILEPATH.name == disc_filename(".adl")
    dfs_disc_title, dfs = disc_files(REVISED_DISC_FILEPATH)
    adfs_disc_title, adfs = disc_files(REVISED_ADFS_DISC_FILEPATH)
    assert dfs_disc_title == dfs_title()
    assert adfs_disc_title == adfs_title()
    assert {n.upper(): data for n, data in dfs.items()} == {n.upper(): data for n, data in adfs.items()}
    assert dfs[README_FILENAME] == (REVISED_BUILD_DIRPATH / README_FILENAME).read_bytes()
    assert dfs[README_FILENAME].startswith(f"Dunjunz Revised {__version__}\r".encode())


def test_cat_and_type_show_the_version(disc_filepaths):
    with launched(MACHINES["dfs226"]) as bbc:
        bbc.run_for_emulated_seconds(3)
        bbc.disc.drive0.insert(REVISED_DISC_FILEPATH, write_protect=True)
        bbc.keyboard.type("*CAT\r")
        bbc.run_for_emulated_seconds(3)
        screen = bbc.video.screen_text().text
        assert dfs_title() in screen
        assert README_FILENAME in screen
        bbc.keyboard.type("CLS\r")
        bbc.run_for_emulated_seconds(1)
        bbc.keyboard.type(f"*TYPE {README_FILENAME}\r")
        bbc.run_for_emulated_seconds(15)
        assert "Report problems at" in bbc.video.screen_text().text
