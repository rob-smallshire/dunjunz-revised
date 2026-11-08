"""The title: its star animation and its picture.

The star animation draws the same frames as the 1987 release.

The star frame pointers were literal bytes for the frames' original address,
&2A00. Code added to the title moved the frames, and each star was drawn from
the bytes before its frame: a band of code above a misplaced star. The
pointers are now computed from star_frame_data; this checks they still point
at the original frames.

The picture is the 1987 one with "Press any key" in yellow and the version
drawn in on the bottom row (title_picture.py).
"""

from __future__ import annotations

from dunjunz_revised._version import __version__
from dunjunz_revised.build import (
    ORIGINAL_BUILD_DIRPATH,
    REFERENCE_DIRPATH,
    REVISED_BUILD_DIRPATH,
    TITLE_SCREEN_PNG_FILEPATH,
    read_labels,
)
from dunjunz_revised.title_picture import (
    GLYPHS,
    PICTURE_ADDRESS,
    PRESS_ANY_KEY_LINES,
    RED,
    SCREEN_START,
    SCREEN_WIDTH,
    VERSION_TOP_LINE,
    YELLOW,
    get_pixel,
    title_png,
    version_line,
)

TITLE_LOAD_ADDRESS = 0x26C0
FRAMES = 7
FRAME_BYTES = 7 * 28


def star_frames(build_dirpath):
    labels = read_labels(build_dirpath, "title")
    image = (build_dirpath / "Dunjunz").read_bytes()

    def byte(address):
        return image[address - TITLE_LOAD_ADDRESS]

    frames = []
    for frame in range(FRAMES):
        address = byte(labels["star_frames_lo"] + frame) | byte(labels["star_frames_hi"] + frame) << 8
        offset = address - TITLE_LOAD_ADDRESS
        frames.append(image[offset:offset + FRAME_BYTES])
    return frames


def test_star_frames_match_the_original(disc_filepaths):
    original = star_frames(ORIGINAL_BUILD_DIRPATH)
    assert all(len(frame) == FRAME_BYTES for frame in original)
    assert star_frames(REVISED_BUILD_DIRPATH) == original


def screens():
    """The 1987 and revised pictures as whole screens, from &3000."""
    def screen(data):
        image = bytearray(0x5000)
        start = PICTURE_ADDRESS - SCREEN_START
        image[start:start + len(data)] = data
        return image
    return screen((REFERENCE_DIRPATH / "Screen").read_bytes()), screen((REVISED_BUILD_DIRPATH / "Screen").read_bytes())


def line_colours(screen, line):
    return [get_pixel(screen, x, line) for x in range(SCREEN_WIDTH)]


def test_the_picture_is_the_original_with_press_any_key_yellow(disc_filepaths):
    original, revised = screens()
    for line in range(VERSION_TOP_LINE):
        before, after = line_colours(original, line), line_colours(revised, line)
        if line in PRESS_ANY_KEY_LINES:
            assert RED in before
            assert after == [YELLOW if colour == RED else colour for colour in before], line
        else:
            assert after == before, line


def test_the_picture_shows_the_version_in_red(disc_filepaths):
    _, revised = screens()
    text = version_line(__version__)
    assert __version__ in text
    lit = sum(row.count("#") for c in text for row in GLYPHS[c])
    colours = [c for line in range(VERSION_TOP_LINE, 256) for c in line_colours(revised, line)]
    assert set(colours) == {0, RED}
    assert colours.count(RED) == lit


def test_every_digit_has_a_glyph():
    assert set("0123456789.") <= set(GLYPHS)


def test_the_readme_picture_is_the_revised_title_screen(disc_filepaths):
    assert TITLE_SCREEN_PNG_FILEPATH.read_bytes() == title_png((REVISED_BUILD_DIRPATH / "Screen").read_bytes())
