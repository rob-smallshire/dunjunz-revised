"""The README's animated title screen, made by running the title's star
code in py65 (tools/dunjunz_revised/title_animation.py)."""

from __future__ import annotations

import io

from PIL import Image, ImageSequence

from dunjunz_revised.build import TITLE_SCREEN_PNG_FILEPATH
from dunjunz_revised.title_animation import (
    TITLE_SCREEN_GIF_FILEPATH,
    Title,
    title_animation,
    twinkle,
)


def test_counting_the_pauses_is_the_same_as_running_them(disc_filepaths):
    """Stars started and advanced with the pauses counted end with the same
    screen, registers and cycles as with the pauses run."""
    counted, run = Title(), Title()
    run.pause = None                                    # run every pause
    for place in (3, 5):
        assert counted.start_star(place) == run.start_star(place)
        for _ in range(8):
            assert counted.call("advance_stars") == run.call("advance_stars")
            assert counted.screen() == run.screen()
            assert (counted.mpu.a, counted.mpu.x, counted.mpu.y) == (run.mpu.a, run.mpu.x, run.mpu.y)


def test_the_twinkle_ends_where_it_starts(disc_filepaths):
    """The last star fades before the end, so the GIF loops without a seam."""
    passes = twinkle()
    assert passes[-1][0] == Title().screen()
    assert any(screen != passes[-1][0] for screen, _ in passes)


def test_the_readme_animation_is_up_to_date(disc_filepaths):
    """uv run dr-title-gif has been run since the picture last changed."""
    assert TITLE_SCREEN_GIF_FILEPATH.read_bytes() == title_animation()


def test_the_animation_is_the_title_picture_with_stars(disc_filepaths):
    gif = Image.open(io.BytesIO(TITLE_SCREEN_GIF_FILEPATH.read_bytes()))
    assert gif.info["loop"] == 0                        # forever
    frames = [frame.convert("RGB") for frame in ImageSequence.Iterator(gif)]
    picture = Image.open(TITLE_SCREEN_PNG_FILEPATH).convert("RGB")
    assert frames[0].tobytes() == picture.tobytes()     # no stars at first
    assert len(frames) > 100
